# Validation record — 2026-09-21

Environment: Windows x64, Flutter 3.44.1, Dart 3.12.1, Microsoft C++ toolchain 14.50.35717. This document records software checks, not clinical or iPhone performance validation.

| Check | Result |
|---|---|
| Flutter static analysis | PASS — no issues found |
| Flutter automated tests | PASS — 4 tests |
| C++ compilation with warnings treated as errors | PASS — MSVC C++17, /W4 /WX /O2 |
| C++ DSP test executable | PASS — mute, peak bound, watchdog latch, non-finite input, tone latch, quiet audio |
| Windows DSP verification script | PASS |
| Flutter release web build with local renderer resources | PASS |
| Browser visual inspection | PASS — desktop live/settings screens, clear preview labelling, disabled live Start |
| 390×844, 200% text across all three tabs | PASS — automated widget layout test |
| Xcode/iOS compilation | NOT RUN — no Mac available |
| Physical iPhone audio, latency and feedback tests | NOT RUN |
| Android native audio | NOT IMPLEMENTED |
| Recording and ML | NOT IMPLEMENTED |
| Clinical intelligibility or identity validation | NOT RUN |

The tests caught a large-text header overflow and a Material/ListTile layering issue; both were fixed before the final passing test run. A missing optional icon-font warning was resolved and the release web build completed again without that warning.

The default Windows Flutter batch wrapper stalled in this environment. Validation used the installed Flutter tool snapshot through its bundled Dart runtime with tool-state directories redirected to the workspace. The default CMake Visual Studio generator encountered a duplicate Path/PATH environment issue; direct MSVC compilation and the supplied `tools/check_dsp.ps1` both passed. CMake configuration is supplied for other environments but is not claimed as passed here.

No audio recordings were collected. No model was downloaded. No account, cloud service or deployment was created. The localhost preview is a temporary local server, not a public website.

## 2026-09-22 — remote build preparation

Added a manual Codemagic workflow for pinned Flutter dependencies, analysis, Flutter tests, Apple Clang DSP tests and unsigned iPhone compilation. No signing or publishing is configured. Remote execution is pending a connected source repository and Codemagic account; no successful iOS build is claimed.
