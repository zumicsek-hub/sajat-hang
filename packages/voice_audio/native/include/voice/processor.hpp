#pragma once
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>

namespace voice {
// Single render-thread owner. Only methods explicitly using atomics are callable
// from the control thread. No allocation, locks, I/O or platform calls in process.
class Processor final {
 public:
  static constexpr std::size_t window = 1024;
  static constexpr float ceiling = 0.794328235f;  // -2 dBFS sample peak, not SPL.
  enum Fault : uint32_t { none = 0, tonalFeedback = 1, watchdog = 2, invalidAudio = 3 };

  void prepare(double sampleRate) noexcept {  // engine MUST be stopped
    rate_ = std::clamp(sampleRate, 16000.0, 96000.0);
    hp_ = static_cast<float>(std::exp(-2.0 * pi * 75.0 / rate_));
    attack_ = static_cast<float>(std::exp(-1.0 / (0.015 * rate_)));
    release_ = static_cast<float>(std::exp(-1.0 / (0.180 * rate_)));
    smoothing_ = static_cast<float>(1.0 - std::exp(-1.0 / (0.100 * rate_)));
    // Fixed 1.5 dB broad peaking EQ, enabled only for the clarity profile.
    const double a = std::pow(10.0, 1.5 / 40.0);
    const double w = 2.0 * pi * 3000.0 / rate_;
    const double alpha = std::sin(w) / (2.0 * 0.8);
    const double a0 = 1.0 + alpha / a;
    b0_ = static_cast<float>((1.0 + alpha * a) / a0);
    b1_ = static_cast<float>(-2.0 * std::cos(w) / a0);
    b2_ = static_cast<float>((1.0 - alpha * a) / a0);
    a1_ = b1_;
    a2_ = static_cast<float>((1.0 - alpha / a) / a0);
    binCount_ = 0;
    for (int k = 1; k < static_cast<int>(window / 2); ++k) {
      const double f = k * rate_ / window;
      if (f >= 500.0 && f <= 8000.0 && binCount_ < coefficients_.size()) {
        coefficients_[binCount_++] = static_cast<float>(2.0 * std::cos(2.0 * pi * k / window));
      }
    }
    previousIn_ = previousHp_ = envelope_ = gain_ = z1_ = z2_ = 0;
    eqMix_ = 0;
    windowPosition_ = 0;
    tonalWindows_ = 0;
    windowEnergy_ = 0;
    q1_.fill(0); q2_.fill(0);
    fault_.store(none);
    muted_.store(true);
    inputLevel_.store(0); outputLevel_.store(0);
    seenHeartbeat_ = heartbeat_.load();
    remainingFrames_ = static_cast<uint64_t>(rate_ * 1.5);
  }

  void setGainDb(float db) noexcept {
    gainDb_.store(std::isfinite(db) ? std::clamp(db, 0.0f, 6.0f) : 0.0f);
  }
  void setClarity(bool enabled) noexcept { clarity_.store(enabled); }
  void setMuted(bool muted) noexcept { muted_.store(muted); }
  void heartbeat() noexcept { heartbeat_.fetch_add(1, std::memory_order_relaxed); }
  float inputLevel() const noexcept { return inputLevel_.load(); }
  float outputLevel() const noexcept { return outputLevel_.load(); }
  uint32_t fault() const noexcept { return fault_.load(); }
  bool muted() const noexcept { return muted_.load() || fault() != none; }

  void process(const float* input, float* output, std::size_t frames) noexcept {
    if (!input || !output || frames == 0) return;
    const auto beat = heartbeat_.load(std::memory_order_relaxed);
    if (beat != seenHeartbeat_) {
      seenHeartbeat_ = beat;
      remainingFrames_ = static_cast<uint64_t>(rate_ * 1.5);
    }
    if (frames >= remainingFrames_) { remainingFrames_ = 0; fault_.store(watchdog); }
    else remainingFrames_ -= frames;
    const bool clarity = clarity_.load();
    // Combined steady-state gain + EQ maximum is capped at 6 dB.
    const float gainDb = std::min(gainDb_.load(), clarity ? 4.5f : 6.0f);
    const float target = std::pow(10.0f, gainDb / 20.0f);
    double inputEnergy = 0, outputEnergy = 0;
    for (std::size_t i = 0; i < frames; ++i) {
      float x = input[i];
      if (!std::isfinite(x)) { x = 0; fault_.store(invalidAudio); }
      x = std::clamp(x, -1.0f, 1.0f);
      inputEnergy += x * x;
      const float high = x - previousIn_ + hp_ * previousHp_;
      previousIn_ = x; previousHp_ = high;
      const float eq = b0_ * high + z1_;
      z1_ = b1_ * high - a1_ * eq + z2_;
      z2_ = b2_ * high - a2_ * eq;
      eqMix_ += smoothing_ * ((clarity ? 1.0f : 0.0f) - eqMix_);
      const float signal = high + eqMix_ * (eq - high);
      const float magnitude = std::abs(signal);
      const float coeff = magnitude > envelope_ ? attack_ : release_;
      envelope_ = coeff * envelope_ + (1 - coeff) * magnitude;
      constexpr float threshold = 0.063095734f; // -24 dBFS, 2:1 above threshold
      const float compression = envelope_ > threshold ? std::sqrt(threshold / envelope_) : 1.0f;
      if (muted()) { gain_ = 0; }
      else { gain_ += smoothing_ * (target - gain_); }
      float y = std::clamp(signal * compression * gain_, -ceiling, ceiling);
      detectTone(x, gain_ > 0.05f);
      if (muted()) y = 0; // A latched fault silences the same render block.
      output[i] = y;
      outputEnergy += y * y;
    }
    inputLevel_.store(static_cast<float>(std::sqrt(inputEnergy / frames)));
    outputLevel_.store(static_cast<float>(std::sqrt(outputEnergy / frames)));
  }

 private:
  void detectTone(float x, bool outputEnabled) noexcept {
    windowEnergy_ += x * x;
    for (std::size_t b = 0; b < binCount_; ++b) {
      const float q = x + coefficients_[b] * q1_[b] - q2_[b];
      q2_[b] = q1_[b]; q1_[b] = q;
    }
    if (++windowPosition_ != window) return;
    double dominant = 0;
    for (std::size_t b = 0; b < binCount_; ++b) {
      const double p = q1_[b]*q1_[b] + q2_[b]*q2_[b] - coefficients_[b]*q1_[b]*q2_[b];
      dominant = std::max(dominant, p);
      q1_[b] = q2_[b] = 0;
    }
    const double ratio = windowEnergy_ > 1e-12 ? 2.0 * dominant / (window * windowEnergy_) : 0;
    // Heuristic, NOT a validated acoustic feedback canceller. Can false-trigger
    // on whistles/voiced sounds and miss feedback. Never rely on it for safety.
    if (outputEnabled && ratio > 0.55 && windowEnergy_ / window > 1e-5) ++tonalWindows_;
    else tonalWindows_ = 0;
    if (tonalWindows_ >= 4) fault_.store(tonalFeedback);
    windowPosition_ = 0; windowEnergy_ = 0;
  }

  static constexpr double pi = 3.14159265358979323846;
  static_assert(std::atomic<float>::is_always_lock_free, "Requires lock-free float atomics");
  static_assert(std::atomic<uint32_t>::is_always_lock_free, "Requires lock-free integer atomics");
  double rate_ = 48000;
  float hp_ = 0, attack_ = 0, release_ = 0, smoothing_ = 0;
  float b0_ = 1, b1_ = 0, b2_ = 0, a1_ = 0, a2_ = 0;
  float previousIn_ = 0, previousHp_ = 0, envelope_ = 0, gain_ = 0, eqMix_ = 0;
  float z1_ = 0, z2_ = 0;
  std::array<float, 512> coefficients_{}, q1_{}, q2_{};
  std::size_t binCount_ = 0, windowPosition_ = 0;
  unsigned tonalWindows_ = 0;
  double windowEnergy_ = 0;
  uint32_t seenHeartbeat_ = 0;
  uint64_t remainingFrames_ = 0;
  std::atomic<float> gainDb_{0}, inputLevel_{0}, outputLevel_{0};
  std::atomic<bool> clarity_{false}, muted_{true};
  std::atomic<uint32_t> fault_{none}, heartbeat_{0};
};
} // namespace voice
