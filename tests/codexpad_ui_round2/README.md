# Native reading validation, round 2

Branch: `codex/ui-round2`. Baseline: `781f5e3` (the delivered round-1 branch).
The original design brief's second stage covers conversation code blocks,
per-file Diff and file previews. Runtime, RPC and authentication remain outside
this UI verification.

## Build and fixture boundaries

The existing `iSH` simulator scheme and `iSHUITests` compile the actual SwiftUI
reading views. The device package continues to use the existing `iSH-ARM64`
target and `.github/workflows/arm64-ios-unsigned.yml`. No new project target
or architecture is introduced by the UI tests.

All tests launch `--codexpad-demo --codexpad-demo-reading`. Fixture callbacks
answer locally through the existing file/navigation controls; no model call,
authenticated RPC or guest command is made by these reading tests. They do
not establish real filesystem/server availability.

## Targeted profiles

- `11-inch-light`: native Changes, Files and conversation code; actual Diff
  known +4/−2 statistics/line text, fold/unfold and raw unsupported fallback;
  code-file line numbers (visual screenshot review, not a VoiceOver gutter);
  directory/file/back/parent/refresh callbacks; plain/binary/truncated states;
  tap Copy, paste into the real composer and assert the expected raw code.
- `11-inch-dark`: the same reading scenarios and controls in dark appearance.
- `11-inch-narrow-XXL`: a real measured 600-point Demo-only hosting container
  combined with accessibility XXL text, checking reachable tabs, scrolling,
  Diff fold/unfold, code and file states, and panel dismissal. Raw clipboard
  round trips run in the two standard profiles. This is a simulated content container,
  not proof of physical Stage Manager resizing.

The workflow's separate `foundation-reading` job compiles/runs the actual
Foundation parser and lexer regression inputs when they change. When those
exact five inputs match `35f92d0`, it records reuse of the 285 passing assertions
from run `37639514789` instead of rerunning the suite. All native profiles require
this verified source check before the UI build. Round-1 model/send/stop tests are retained
in the file but not selected by this workflow.

The authoritative fixture root is `/root/workspace/reading-demo`.
`Sources/Welcome.swift` and the conversation Swift block contain the exact
UTF-8 text `// 你好 👋\nlet greeting = "Hello, iPad"\nprint(greeting)\n`.
The verified standard runs tap Copy in both views, use the native keyboard
assistant Paste button into the existing composer, and assert the exact value,
including the final newline. Context-menu Paste was not verified.
The conversation copy ID is `codexpad.timeline.reading-code.code.1`; the file
code control is `codexpad.file-preview-code-copy`. The temporary fixture paste
is then deleted without sending it. No paid inference occurs.

Files scenarios use the existing directory/file/back/parent/refresh controls.
Binary content disables copy; `empty.txt` displays the empty state; `large.txt`
keeps the real 200 KB preview notice and **Copy preview** label. The truncated
fixture is not scrolled through its thousands of lines. Standard profiles
capture plain-text, empty and binary previews as well as code and truncation;
the narrow profile concentrates its screenshots on conversation code, Changes
and raw fallback, code preview, and truncation.

In GitHub Actions, choose **CodexPad native UI round 2** → **Run workflow**,
select `codex/ui-round2` and the `profile` input. `all` selects the three
profiles; a single profile restricts execution to that scenario. `standard-failed`
rechecks only light/dark. `current-fixes` adds only `testRoundTwoNarrowPreview`
at 600pt/XXL to those standard profiles, checking the changed text preview
without repeating the already-passed narrow Diff/code/navigation sequence. Parent
coordination controls push, dispatch and any failed-only retry.

The initial light attempt crashed in the existing guest `do_uname` hostname
copy (`__strcpy_chk` overflow) before the workspace appeared. Later UI jobs
set and verify a short hostname only on their ephemeral macOS runner, recording
it in the artifact. The production kernel remains unchanged. Demo isolates
UI callbacks from paid model/RPC actions; the App's pre-existing background
guest boot still runs and is outside this reading verification.

The first narrow screenshot exposed a blank 200 KB SwiftUI Text layer despite
passing state assertions. The plain-text reader now wraps a read-only native
UITextView in SwiftUI so TextKit lays out the visible viewport, with the complete
source available for selection/copy. Plain preview tests read its actual value;
large preview tests require the expected prefix, a reachable viewport and a
native screenshot. Line wrapping and actual visible text still require screenshot
review, rather than inferring them from a passing value assertion.

## Evidence and current status

The macOS GitHub Actions results are complete. Windows remains the editing and
artifact-review environment; no native build or simulator ran on Windows.

| Check | Source | Recorded result |
| --- | --- | --- |
| Actual Foundation parser/lexer/preview regressions | `35f92d0` | [Run 37639514789](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37639514789): **285 assertions, 0 failures** |
| Final Foundation verification | `eb774f9` | [Run 37726564902, job 113145968540](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37726564902/job/113145968540): **passed** exact five-input comparison and reused the above result; the suite was not rerun |
| ARM64 unsigned package | `1ce2def` | [Run 37724252949](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37724252949): **passed** |
| Dark full reading flow and changed narrow TextKit preview | `1ce2def` | [Run 37724250214](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37724250214): **passed** |
| Final light full reading flow | `eb774f9` | [Run 37726564902, job 113146082126](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37726564902/job/113146082126): **passed** |

Native validation used **iPad Pro 11-inch (M5), iOS 26.5 and Xcode 26.6
(17F113)**. Standard profiles used a 1210 × 834-point window. The narrow
profile used a measured 600-point Demo content container and accessibility XXL
text; it is not physical Stage Manager evidence. App files are identical between
`1ce2def` and `eb774f9`; later commits changed the test driver only.

The initial narrow full flow passed, but its screenshot exposed the blank
200 KB reader described above. After the TextKit fix, the changed narrow preview
test passed and its new native screenshot was reviewed with the body visibly
rendered. Current dark screenshots also visibly show conversation code,
per-file Diff and code-file line numbers. State assertions alone were not used
to dismiss the earlier blank-rendering defect.

Each artifact records tested source, Xcode version, simulator, appearance,
content size and explicit Demo mode. `state` in the selected simulator record
is a preboot selection snapshot, not the screenshot's execution state.
Native XCTest screenshots and assertions supply execution evidence.

Launch failures retain the actual failure screen and App state/accessibility
tree before XCTest terminates the App. The workflow also collects relevant
recent simulator/host `.ips` and `.crash` reports when available. An empty
crash manifest or SpringBoard screenshot does not establish the exit cause;
the previous round's initial `NotRunning` cause remained undetermined.

Physical iPad behavior, hardware keyboards, dynamic Stage Manager resizing,
real server connectivity, RPC/filesystem operations and ARM64 runtime stability
remain separate unverified conditions. This workflow does not operate the
connected iPad.

## Independent acceptance follow-up

Review of delivered source `dd5a1d6` found no blocking round-two regression.
A non-blocking code-copy feedback issue was fixed by resetting `copied` when
the view disappears, alongside cancellation of its feedback timer. The actual
clipboard operation is unchanged. This small follow-up passed `git diff --check`;
native tests/build were not rerun, and the existing unsigned package remains
the validated `1ce2def` build without this follow-up. Include it in the next
UI-stage native build rather than repeating the full reading suite now.

The model's unconditional application of a file/directory RPC result after
navigation is an inherited risk already present in `781f5e3`, rather than a
round-two regression. Large code/raw-Diff rendering at accessibility XXL also
remains unverified; similarity to the corrected plain-text issue is not proof
of a reproduced defect.
