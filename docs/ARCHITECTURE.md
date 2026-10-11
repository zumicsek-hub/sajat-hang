# Prototype architecture and limitations

## Implemented scope

This is Phase 1 of the agreed phone-speaker-first, entirely on-device design. The Flutter UI is runnable on the web as an explicitly non-audio preview. Only iOS has a native audio implementation. Android is a generated application shell and is intentionally treated as unsupported for live audio until Oboe is integrated.

The recording tab is a transparent roadmap screen. Recording, playback, export and ML are not implemented. There is no cloud endpoint, telemetry SDK, account system, speech recognition, TTS or voice conversion.

## Live data path

`Built-in microphone -> AVAudioEngine input -> SHAudioUnit -> main mixer -> built-in speaker`

The custom AUAudioUnit pulls mono Float32 input and invokes the header-only C++ Processor inside its render block. Flutter sends commands and scalar status over `hu.sajathang/audio`; PCM is never sent to Dart. Buffers and filter coefficients are prepared outside rendering. The render block performs no allocation, locks, logging, file I/O, networking, Objective-C message dispatch or Dart callbacks. C++ atomics connect controls/meters to rendering. Native lifecycle/configuration handling runs on the main thread.

Flutter polls scalar telemetry/heartbeat at 10 Hz. A processor watchdog latches mute if heartbeat updates stop for 1.5 seconds of processed frames. UI meters are RMS dBFS, not calibrated SPL, therapy scores, or measured acoustic gain. Native microphone permission and graph startup are asynchronous, with a generation token preventing a cancelled start from completing later.

## Current DSP, in order

1. Reject non-finite audio, clamp input to normalized Float32 bounds.
2. First-order 75 Hz high-pass.
3. Optional broad 3 kHz / Q 0.8 / +1.5 dB peaking EQ, smoothly crossfaded.
4. Envelope-based 2:1 compressor above -24 dBFS; 15 ms attack / 180 ms release, no makeup gain.
5. Smoothed manual gain 0..6 dB (capped at 4.5 dB when clarity EQ is on), approximately 100 ms smoothing. Starts muted, no auto-unmute.
6. Hard sample-peak clamp at -2 dBFS. This is an emergency ceiling, NOT a polished lookahead limiter or acoustic exposure limit. Intersample peaks are not measured.
7. Parallel Goertzel tonal heuristic over 1024-sample windows, bins 500–8000 Hz. Four high-dominance windows while output is active latch silence. Can miss off-bin/broadband feedback and can false-trigger on sustained sounds. Not AEC/adaptive feedback cancellation.

Not yet implemented: intelligent AGC, noise reduction, de-essing, dereverberation, soft-knee dynamics, true-peak limiting, rate changes, prosody modification. Deliberately no noise gate. Improvements require speech-quality comparisons, not just adding processing stages.

## State and failures

`idle -> permission/start -> running muted -> running audible -> muted/stopped`

Faults latch in the native processor and cannot be cleared by unmuting. Stop destroys the engine; the next Start recreates it muted. UI Stop can supersede a pending Start. Interruptions, backgrounding, route changes and engine configuration changes stop the session without automatic recovery. Native app-lifecycle handling is independent of Flutter. The prototype does not support background audio.

`status/heartbeat` returns running, muted, fault, input/output RMS, profile, sampleRate, bufferMs, reportedIoMs and reason. `reportedIoMs` is only the OS-reported inputLatency + outputLatency. No acoustic round-trip measurement exists in the app.

Settings use NSUserDefaults for gain/profile only. No audio is persisted. A future recording module must use protected local storage, exclude audio from backup, retain originals and require explicit export. Review the privacy manifest before any distribution, including required-reason API declarations for preferences.

## iOS build

Local Flutter plugin `packages/voice_audio`, Objective-C++ implementation, CocoaPods integration, iOS deployment target 15.0. CocoaPods is intentionally used for this prototype; no Swift Package manifest is supplied for the plugin. Generated Flutter app has standard registrant wiring. C++17 required. No Apple SDK compiler is available on the development Windows machine, so native compilation is an outstanding gate.

## Next recording milestone

Add a mutually exclusive recording state and native file writer on a worker path. Keep raw audio local and unchanged; benchmark a pinned/licensed DeepFilterNet model/runtime on the iPhone 16e, verify export/conversion equivalence, process bounded overlapping chunks, and compare against the original. Measure runtime, temperature, peak memory, identity preservation and Hungarian consonant retention. Never silently substitute cloud inference. No model has been downloaded, bundled or claimed to work yet.

## References checked during preparation

- Flutter platform channels: https://docs.flutter.dev/platform-integration/platform-channels
- Apple session preferences: https://developer.apple.com/library/archive/qa/qa1631/_index.html
- AU render block: https://developer.apple.com/documentation/audiotoolbox/auaudiounit/internalrenderblock
- Android Oboe guidance: https://developer.android.com/games/sdk/oboe/low-latency-audio
- DeepFilterNet upstream: https://github.com/Rikorose/DeepFilterNet
- EU software classification: https://health.ec.europa.eu/latest-updates/update-mdcg-2019-11-rev1-qualification-and-classification-software-regulation-eu-2017745-and-2025-06-17_en
