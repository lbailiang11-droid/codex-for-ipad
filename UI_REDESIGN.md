# CodexPad native UI redesign

Date: 2026-10-07. Branch: `codex/ui-round1`.

## Baseline and scope

This branch starts at `a11f8db8b862af400d6c11876a9fe8fc4d849b58`
from `codex/fix-arm64-rev16`, retaining the installed R2 ARM64 fixes and
cloud terminal icon. The original checkout is retained in `work/codexpad-fix`.
No applicable on-disk AGENTS.md was found in the checkout or its parent chain;
the user's instructions in the conversation apply.

The supplied brief is a design reference. Its reference branch
`exp/codexpad-on-arm64` is older than the selected repair baseline.

Round 1 covers theme, navigation/sidebar, conversation, composer, collapsible
activity output, and window adaptation. Diff highlighting, code-preview
enhancements, settings and the complete feature center are later phases.
The production runtime, RPC, authentication, account/model data, storage,
approval decisions and ARM64 integration are outside this round's changes.

## Visual rules

- Fog white canvas `#F4F5F7`, white reading surface, ink `#20242C`.
- Graphite canvas `#15181E`, surface `#1E222A`, ink `#E8ECF3`.
- Blue accent `#315FDB` / `#8AA9FF`; explicit labels/icons accompany status.
- Semantic system fonts and SF Symbols, selectable text, 44-point touch areas.
- Spacing follows 8/12/16/24 points; rounded controls 12 points, panels 18 points.
- User messages have a quiet tinted surface. Assistant prose uses open spacing.
  Long completed activity output can collapse; failures/running activity remain
  visible and approval/question actions remain usable.
- Composer text, model/reasoning choices and send/stop form one panel. Existing
  availability, selection, keyboard shortcuts and touch/desktop focus rules apply.

## Window policy

Measure the outer workspace with GeometryReader before navigation or inspector
columns consume width. Never use UIScreen.main.bounds for workspace decisions.

- Under 900 points, compact size class, or accessibility Dynamic Type: prioritize
  conversation; thread browser is a sheet.
- 900–1279 points: sidebar (260–320, ideal 288) and conversation. This is the
  default 11-inch landscape arrangement. Workbench opens on demand in a sheet.
- At least 1280 points, with regular readable layout: workbench can use a native
  inspector (300–400, ideal 330). It starts closed.
- Plan, Changes, Files and Runtime retain their real existing model/actions.
- Settings/feature-center presentation and original shortcuts remain available.

## Native validation

Windows has no Xcode or Apple simulator. The original ARM64 workflow targets
`iSH-ARM64`, Release, iphoneos, with code signing disabled. Its connection
regression runs on macOS. Native UI screenshots use the same SwiftUI sources
with an explicitly isolated `--codexpad-demo` scene; they do not establish
real login, guest-runtime health or model inference.

Validation results, workflow run URLs, source commit and native screenshots are
recorded below after execution. Screenshot coverage is intended to include
11-inch portrait/landscape, light/dark, narrower workspace, larger type, panel
presentation, output expansion and visible approval actions. Physical iPad
control is deferred while another task uses the device.

### Executed so far

- Inspected target branch/commit, clean original checkout, SwiftUI files,
  project/schemes, existing ARM64 workflow and demo entry point.
- `git diff --check`: passed for the initial UI edits.
- Live GitHub verification: baseline ARM64 run `35712515741` succeeded for
  `a11f8db8b862af400d6c11876a9fe8fc4d849b58`.
- Calculated contrast against the reading surface: light ink 15.55:1,
  secondary 5.45:1, blue 5.54:1, waiting 5.35:1; dark ink 13.45:1,
  secondary 7.22:1, blue 6.98:1, waiting 8.55:1. Disabled system controls and
  final rendering still require the native review.
- Independent source review corrected stale presentation bindings and retained
  a stable navigation container across width changes.
- Native ARM64 Release build for `9e50bb61ec922b76f5c6e5d28e2ecd97e2113812`:
  [run 37615636404](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37615636404),
  **success**. The existing RPC connection regressions passed, device target
  compiled, the rootfs BusyBox was verified as ARM aarch64, and IPA packaging
  succeeded. This does not establish long-duration physical-device stability.
- Native UI/screenshots for that same source:
  [run 37615582283](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37615582283),
  narrow container and accessibility XXL passed in attempt 1; dark passed
  in attempt 2. The original matrix retains its light failure.
- Light's keyboard screenshot proved that a newly prepended chat placed the
  target row below the sidebar List's visible area. The test was corrected
  to scroll that native List rather than toggling an already-visible sidebar.
  [Focused light run 37621843912](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37621843912)
  **passed**, including actual conversation-header change, draft retention,
  focus recovery, approval dismissal and completed-output expansion/collapse.
- That focused verification is at `4e9358733031b1a5acd9f6dee69a4ae080ba65b4`;
  only XCTest/workflow changed. `git diff --exit-code 9e50bb6..4e93587 -- app/CodexPad`
  passed with no application-source differences, so the ARM64 package and
  prior three profile results apply to identical UI code. No extra ARM64 or
  passed-profile rerun was required.
- Initial standard light/dark launches failed before UI interaction. Dark's
  native failure attachment records `NotRunning`, without a surviving UI tree
  or identified crash cause. Subsequent passes do not establish startup or
  physical-runtime stability.
- Native original PNGs, source/run context and SHA-256 are retained in the task's
  `outputs/CodexPad-UI-Round1/screenshots/index.json`; delivery report and unsigned
  package are alongside it. The simulator is iPad Pro 11-inch (M5), iOS 26.5;
  results are explicitly isolated native Demo evidence.

### Evidence limits

Simulator demo results must be labeled separately from physical-device results.
Real Stage Manager resizing, external keyboard, touch focus and approval RPC
effects remain unverified until exercised in the production app. Existing
connection and empty-thread-resume defects remain separate from UI scope.


## Round 3 — auxiliary screens and states

Date: 2026-10-08. Branch: `codex/ui-round3`; baseline `6db21ce` after
independent round-two acceptance. The previous UI and repair worktrees are
retained. The one-line copy-feedback reset from acceptance is included.

This stage covers Settings, the complete Feature Center, first launch,
connecting/offline, no thread/conversation/plan/changes/files/runtime messages,
errors, questions and approvals. Settings/catalog surfaces use the existing
semantic colors, system type, clear groups, 44pt controls and wrapping values.
The Feature Center measures its available container and retains a single
navigation identity across width changes. Panel handoff waits for native
Settings dismissal; composer focus returns after the final panel closes.

Production bindings, account/model data, request parameters, destructive
confirmation, choices, runtime/RPC/authentication and file access remain the
existing implementation. UI fixture state is explicitly selected using
`--codexpad-demo --codexpad-demo-auxiliary`. The only model addition is local
Demo question handling built from the same answers object; no fixture answer
is sent to a server. Existing background guest boot still runs in Demo.

Native acceptance targets the existing iSH simulator scheme on macOS and the
existing iSH-ARM64 unsigned workflow. It focuses on Settings/Feature Center
navigation and search, closing/focus, actual option submission and approval
resolution, state visibility, and a measured 600pt/AX XXL container. Phase-two
Foundation inputs and reading scenarios are unchanged and are not rerun.
Actual acceptance is recorded below and in `tests/codexpad_ui_round3/README.md`.
Physical iPad installation/execution, live account/server operations, hardware
keyboards, dynamic Stage Manager/Split View and long connection stability remain
unverified. Implementing this stage does not operate the connected iPad.

### Round-three executed results

- Current application/package source `8751898` passed ARM64 Release and the
  existing RPC connection regressions in [37733906776](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37733906776).
  The unsigned package has not been signed or installed.
- Light acceptance combines recorded successful prefix assertions from
  failed run `37733903968`, successful NoResults/focus assertions from failed
  run `37743091835`, and the successful remaining request/workbench/state
  flow in [37745345364](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37745345364).
  The two failed Light runs retain their actual conclusions.
- The full dark auxiliary flow passed in that same final matrix, including
  actual edited-JSON retention, panel handoff/focus, questions and approvals.
- The measured 600pt / accessibility XXL flow passed in
  [37747566003](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37747566003)
  at `3c18db0`. This profile retains `focus:NO`: it does not prove focus
  restoration or an edited-JSON draft in the narrow container.
- Later commits only refine native test targeting and profile selection:
  exact NoResults text/action roles, the native switch track, real keyboard
  dismissal with draft preservation, request ancestors, and catalog scrolling.
  Final application/project comparison against the package source is empty;
  no duplicate ARM64 build or round-two Foundation test run was required.
- Six actual failed tests and an old-head run cancelled before build/test
  remain recorded. Native originals, source/run context and per-image hashes
  are retained in the task's `outputs/CodexPad-UI-Round3` delivery directory.

These are isolated native Demo results. Live account/server actions, real
Files permissions, physical Stage Manager/Split View, hardware keyboard,
the inspector above 1280pt and long connection stability remain unverified.

## Round 3 — external visual review closeout

Date: 2026-10-08. Branch: `codex/ui-round3`; baseline `9832b9d`;
application/test/package source
`4f47705f7c7ebc7f4c2fb186e93d9263c164a7ae`.

Review of the original Round 3 screenshots identified two visible defects
despite the earlier interaction passes: Settings had no visible title and
excess header space, and the AX XXL feature category icon overflowed its
22pt slot, clipping at the left and covering the beginning of `List`.
Settings now explicitly selects the native inline navigation title. The
feature category icon uses body-relative scaled type, its natural size and
a scaled minimum column width. Existing title/method/body Dynamic Type
styles and real operation bindings are retained. Only
`CodexSettingsView.swift` and `CodexFeatureCenterView.swift` changed in
production; RPC, authentication, permissions, storage, parser and kernel
code did not change. The UIKit-internal cause of the old missing automatic
title is still not established.

### Executed closeout results

- Native matrix [37755287303](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37755287303)
  passed on the same source. Complete Light, job `113238218395`, passed in
  449.981 seconds with 1 test and 0 failures, artifact `11539949649`. This
  supplies the previously missing single complete Light success record.
- Focused dark, job `113238218329`, passed in 161.987 seconds with 0 failures,
  artifact `11540362289`; focused measured 600pt / AX XXL, job
  `113238218054`, passed in 186.663 seconds with 0 failures, artifact
  `11540690889`. These check title lifecycle and real catalog/detail
  navigation for the two visual fixes, not full dark/narrow regressions.
- Fresh ARM64 Release [37755287453](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37755287453),
  job `113238218024`, passed along with the existing RPC regressions.
  Artifact `11540285044` contains the new unsigned build `805` IPA. It has
  not been signed or installed.
- All 26 original PNGs (16 Light, 5 dark, 5 narrow) are retained with raw-byte
  and SHA-256 matches. Original-pixel review confirms the Settings title
  in Light and both focused profiles, reduced header blank space, and an
  intact AX XXL feature icon separated from `List`. Large body text remains
  enlarged. Actual Done close/reopen and Settings-to-Feature-Center actions
  passed the native interaction assertions.

The dark initial and named `settings-scrolled` PNGs are byte-identical and
do not independently prove content movement. The title check after the
actual Form traversal to the Feature Center entry passed, and the narrow
scrolled image visibly changes from Input mode to Model with its title
still visible. The focused dark keyboard screenshot fully shows the icon
and `List` but covers subsequent row text; the narrow keyboard screenshot
shows the complete result row. These evidence limits are preserved rather
than inferred away from passing AX assertions.

Prior delivery and failure history remain intact. New originals, hashes,
report and package metadata are in the task's separate
`outputs/CodexPad-UI-Round3-Visual-Fix` directory. No extra parser/lexer or
general kernel matrix was run. No physical iPad was operated. Live login,
real RPC/file permissions, hardware keyboard, dynamic Stage Manager and
long connection stability remain unverified.

## Window acceptance after the three implementation rounds

Date: 2026-10-08. Branch: `codex/ui-round4`; baseline: `c600b2d`.
The brief has no predefined fourth implementation round. This stage checks
the remaining large-window inspector/sheet transitions, composer draft/focus
and reading position using one targeted native Demo flow. Earlier 11-inch
runs never crossed the 1280pt inspector threshold. Production UI and runtime
remain unchanged unless new evidence establishes a defect. The existing
build 805 IPA can be reused while App/project sources match `4f47705`.

The test plan, actual staged results and evidence limits are in
`tests/codexpad_ui_round4/README.md`, separately from physical-device,
real Stage Manager, hardware-keyboard and long-connection validation.

Three recorded native attempts established the workbench transitions and
Done input, corrected two test-driver assumptions, then reproduced a real
reading defect: after physically returning to earlier content, Latest was
absent. The first paragraph was visible at y=233 while the last was below
the viewport at y=1468. The follow state had not paused; the exact old
preference callback failure was not instrumented.

The only production change is now `CodexConversationView.swift`: iOS 18+
uses public scroll geometry and phase callbacks, with a Bool end threshold
and both event orders handled. Actual user scrolling away pauses following;
idle content growth, resize and programmatic movement do not do so alone.
iOS 17 retains the original fallback and deployment target, and remains
unverified. Native reading-only run `37770366433` at `b84a29f` passed:
1 test, 0 failures, 188.974 seconds. Original pixels show reachable Latest
across landscape/portrait/landscape and the complete final paragraph after
an actual Latest tap. Actual toolbar Hide followed by App-level typing also
passed; five original PNGs and frame/AX records are retained.

That Hide image exposed a separate first-line input clip despite its complete
three-line AX value. `01b3002` removes only composer `.lineSpacing(4)` and uses
one targeted Hide/input check, rather than rerunning the passed reading or
prior UI matrices. The system body font, multiline range, binding, focus and
send/stop semantics remain intact. The exact native intrinsic/content-height
cause is not claimed established. Final ARM64 Release run `37772887105`
at `01b3002` and its existing RPC regressions passed; the unsigned build805
package has not been signed or installed. RPC/runtime/permissions are unchanged.

The first input-only run `37772879090` failed its 10-second pre-workbench
actual-value wait in 86.282 seconds. Later original AX text exactly equals
the expected 40-character draft; the original PNG shows the first line intact.
The Hide path was not reached. `1cc46ad` changes only the two input-value
timeouts to 30 seconds, preserving exact equality and actual interaction.
App/project sources still match the final package, so no extra ARM64 build
is dispatched. Original failure provenance and evidence are retained.

Retry `37775371303` / `1cc46ad` failed before typing in 103.079 seconds at
the 10-second landscape readiness wait. Later original frames and pixels
show the correct real 1376x1032 landscape workspace. `762fbeb` extends only
Round4 readiness bounds to 30 seconds and logs actual frames, retaining
strict dimensions and real input conditions. No production layout change
or repeated ARM64 build is justified by this readiness failure.

Final targeted input run `37777595828` / test source `762fbeb` passed:
1 test, 0 failures, 110.388 seconds, artifact `11551007137`. Its App/project
trees match package source `01b3002`. Both original images show all three
lines, including the complete suffix after toolbar Hide, without first-line
clipping or covered model/send controls. Actual App-level typing and draft
retention passed without retapping the composer after the panel closed.

All seventeen original PNGs and frame/AX records retain exact bytes and
SHA-256 matches; the five failed runs remain failed. Source identities stay
separate: previous window/Done assertions, b84a29f reading, final01b3002
input/package. There was no single full latest-source Round4 flow. The full
GitHub artifacts and local PNG/text/context/log evidence are preserved.
Physical iPad, iOS17 fallback, hardware keyboard, real Stage Manager/Split
View, streaming content and live login/files/approvals/connections remain
outside this simulator acceptance. No physical device or desktop was controlled.
