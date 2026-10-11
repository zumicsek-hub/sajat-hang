#include "voice/processor.hpp"
#include <array>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <random>

void require(bool value, const char* message) {
  if (!value) { std::cerr << "FAIL: " << message << '\n'; std::exit(1); }
}
int main() {
  voice::Processor dsp;
  std::array<float, 256> in{}, out{};
  dsp.prepare(48000);
  in.fill(0.2f);
  dsp.process(in.data(), out.data(), out.size());
  for (auto x : out) require(x == 0, "starts muted");
  dsp.setMuted(false);
  dsp.setGainDb(100);
  std::mt19937 random(7);
  std::uniform_real_distribution<float> noise(-1, 1);
  for (int block = 0; block < 400; ++block) {
    for (auto& x : in) x = noise(random);
    dsp.heartbeat();
    dsp.process(in.data(), out.data(), out.size());
    for (auto x : out) require(std::isfinite(x) && std::abs(x) <= voice::Processor::ceiling, "bounded output");
  }
  require(dsp.fault() == 0, "broadband noise does not latch tonal fault");
  require(dsp.outputLevel() > 0, "unmuted signal flows");
  dsp.setMuted(true);
  dsp.process(in.data(), out.data(), out.size());
  for (auto x : out) require(x == 0, "mute applies immediately");

  dsp.prepare(48000); dsp.setMuted(false);
  for (int block = 0; block < 290; ++block) dsp.process(in.data(), out.data(), out.size());
  require(dsp.fault() == voice::Processor::watchdog, "lost controller heartbeat latches mute");
  dsp.heartbeat(); dsp.setMuted(false);
  dsp.process(in.data(), out.data(), out.size());
  for (auto x : out) require(x == 0, "heartbeat cannot clear a latched fault");

  dsp.prepare(48000); dsp.setMuted(false);
  in[0] = std::numeric_limits<float>::quiet_NaN();
  dsp.process(in.data(), out.data(), out.size());
  require(dsp.fault() == voice::Processor::invalidAudio, "NaN fails closed");
  for (auto x : out) require(x == 0, "invalid audio mutes entire output");

  dsp.prepare(48000); dsp.setMuted(false);
  uint64_t sample = 0;
  for (int block = 0; block < 80; ++block) {
    for (auto& x : in) x = 0.05f * static_cast<float>(std::sin(2 * 3.141592653589793 * 3000 * sample++ / 48000));
    dsp.heartbeat(); dsp.process(in.data(), out.data(), out.size());
  }
  require(dsp.fault() == voice::Processor::tonalFeedback, "sustained narrow tone latches protection");

  // Very soft speech-like noise must not be gated to silence.
  dsp.prepare(48000); dsp.setMuted(false); dsp.setGainDb(6);
  for (int block = 0; block < 80; ++block) {
    for (auto& x : in) x = noise(random) * 0.0001f;
    dsp.heartbeat(); dsp.process(in.data(), out.data(), out.size());
  }
  require(dsp.outputLevel() > 0.00001f, "quiet audio is preserved");
  require(dsp.fault() == 0, "quiet audio does not trigger protection");
  std::cout << "PASS: mute, output ceiling, heartbeat, NaN, tone latch, quiet audio\n";
}
