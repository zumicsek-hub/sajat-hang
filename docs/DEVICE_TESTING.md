> 2026-10-13: A 0.2.0 felvételi mód és Windows-változat friss leírása: [FELVETEL_HU.md](FELVETEL_HU.md). Az alábbi eredeti leírás a korábbi élő prototípusra vonatkozik.

# iPhone 16e device validation

Target supplied by the user: iPhone 16e, reported iOS 26.5.2. Record the actual OS/build from Settings when testing. No iPhone measurements or Xcode build results exist yet.

## Before involving users

1. Compile the native target in Xcode and run the C++ tests with Apple Clang. Resolve compiler or audio-graph issues before proceeding.
2. Use a physical phone with no Bluetooth, USB or wired audio connected. Keep the speaker away from ears, start with low hardware volume, and have Stop immediately available.
3. Test with a developer and a recorded speech source first. The tonal detector is a heuristic, not a certified feedback-protection system. Do not deliberately increase volume until loud feedback occurs.
4. Have a speech-language therapist review the protocol before testing with people with dysarthria. Obtain informed consent; this prototype does not record participants.

## Functional checklist

- [ ] First launch defaults to Hungarian; EN/HU switches all user-facing screens.
- [ ] Denied microphone permission produces an actionable message and no output.
- [ ] Start requests permission only after a deliberate tap.
- [ ] Every start is muted; microphone meter responds while output remains zero.
- [ ] Enable sound gradually fades output in. Mute silences output immediately.
- [ ] Stop immediately works on all tabs, including during startup.
- [ ] Double tapping Start does not create a second engine.
- [ ] Gain/profile persist after restart, but running/unmuted state never persists.
- [ ] Phone lock, Home, Control Center and an incoming call stop audio. Returning never restarts it automatically.
- [ ] Connecting/disconnecting another audio device stops the session. Unsupported output is never used silently.
- [ ] Backgrounding during permission/engine startup does not activate sound later.
- [ ] Suspending the Flutter controller while native rendering continues causes a latched mute after about 1.5 s of audio frames. A stopped debugger also stopping rendering is not a valid watchdog test.
- [ ] Protection cannot be cleared by Enable sound. Stop/Start is required.
- [ ] VoiceOver announces buttons and session state; 200% text remains usable.
- [ ] No hard gate removes quiet consonants or phrase endings.

## Acoustic latency (release/profile build)

The settings screen reports the negotiated I/O buffer and OS input+output latency. Neither is a measured acoustic round trip, and they must not be added blindly to derive one.

Use an external two-channel measurement recorder/interface: channel A captures a reference stimulus near the phone microphone, channel B captures the phone loudspeaker. Use a short broadband probe at low gain; separate or account for direct acoustic leakage. Cross-correlate the input reference and processed output, correct for known propagation distance, and repeat with speech-like probes. Do not use a feedback-prone sustained test tone.

Run at least 100 valid probes per configuration. Report median, p95 and maximum, together with dropped/invalid observations. Record phone/OS, app commit, route, sample rate, buffer, gain, profile, hardware volume, placement and ambient noise. Repeat after 30 minutes. Target: p95 <50 ms on the built-in route; no guarantee is made until measured. Also ask whether delayed self-voice is distracting.

## Useful acoustic gain and quality

Keep reference speech and microphone position fixed. At a fixed listener position, compare app off versus app on using the same external meter/recorder. Document phone orientation, distance, room and volume. Determine whether useful improvement exists at conservative settings; stop at the first sign of instability.

Compare original, amplification-only and processed speech in a later controlled harness. Include both loudness-matched and realistic-level comparisons. Ask listeners to transcribe Hungarian sentences and rate effort; ask speakers/familiar listeners about voice identity and comfort. Do not infer benefit from a louder meter or better ASR alone. The current prototype does not include a bypass or research recorder.

## Sustained operation

- [ ] 30–60 minutes without audible dropouts; log device heat and battery delta manually.
- [ ] Test quiet room, ordinary household noise, reflective room, handheld and tabletop positions.
- [ ] Characterize false protection trips and missed feedback with controlled low-level signals.
- [ ] Use Instruments to profile callback time; target callback work comfortably below each buffer deadline.
- [ ] Network inspection confirms no app audio transfer. Inspect app files to confirm live audio is not saved.

## Release gates

This is a developer feasibility build, not ready for unsupervised assistive use. No clinical efficacy claim, no <50 ms badge, and no public distribution before device validation, usability evaluation and intended-use/regulatory review. Inadequate gain before feedback is a reason to change microphone/speaker placement requirements, not to raise the software cap.

## Results template

| Field | Result |
|---|---|
| Date / tester / app revision | |
| Phone / OS build | |
| Route / placement / distances | |
| Sample rate / buffer | |
| Hardware volume / gain / profile | |
| Latency median / p95 / max | |
| Stable useful acoustic gain | |
| Dropouts / false protection trips | |
| Heat / battery / duration | |
| Intelligibility / identity / comfort observations | |
| Pass, fail, or investigation needed | |
