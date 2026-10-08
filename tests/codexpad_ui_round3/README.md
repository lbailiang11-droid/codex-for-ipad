# CodexPad native auxiliary-page verification (round 3)

Branch: `codex/ui-round3`. Baseline: `6db21ce` (accepted round 2).

Native tests are in `app/UITests/UITests.m`. Workflow:
`.github/workflows/ipados-ui-round3.yml`, using the existing `iSH` scheme,
`iSHUITests` target, `macos-26`, and an available 11-inch iPad simulator.
The source commit, selected runtime, Xcode version, appearance, content size,
and preboot selection state are recorded with every artifact. The actual
XCTest assertions and screenshots provide execution evidence; the preboot
selection JSON does not describe the eventual execution state.

## Economical profile selection

The first push touching the round-3 workflow, CodexPad UI source, or native
UITests on `codex/ui-round3` runs one three-job matrix. Manual `profile` inputs
are `all`, `light`, `light-remaining`, `light-requests`, `dark`, `narrow`,
`dark-narrow`, `remaining`, `closeout`, `dark-visual`, and `narrow-visual`;
use a single failed profile for any necessary retry instead of repeating
passed jobs.
`dark-narrow` runs those two jobs together after the remaining light flow passes,
without concurrency cancellation between separate workflow runs on this branch.

- `light` / `testRoundThreeLight`: Settings touch-mode and show-all bindings;
  Settings-to-Feature-Center handoff; actual catalog search, detail, Back,
  no-match state, retained JSON draft, and Done; Desktop input selection and focus restoration after
  Settings, toolbar Feature Center, and Settings-to-Feature-Center handoff;
  structured question choice and its actual constructed answer payload;
  approval decline; empty Plan/Changes/Files and workbench close; then separate
  starting, connecting, offline, and welcome launches. Welcome creates one
  Demo thread and verifies the real empty conversation and disabled Send.
- `dark` / `testRoundThreeDark`: the same auxiliary forms, binding and focus
  regressions, pending question/approval flow, and empty Changes. It does not
  relaunch all four state variants.
- `light-remaining` / `testRoundThreeLightRemaining`: targeted continuation
  after the recorded light prefix passed at `8751898`. It checks the actual
  no-match title and Clear search button, search clearing, Desktop focus,
  question/approval, empty workbench and four state launches. It does not
  repeat the accepted Settings/search/detail prefix. The full dark profile
  still requires the final retained JSON draft equality. This continuation
  is reported alongside the partial light run, not as a passed full light job.
- `light-requests` / `testRoundThreeLightRequestsRemaining`: continues after
  the actual no-match clearing and three Desktop focus checks passed in
  run `37743091835`. It covers pending question/approval, empty workbench and
  state launches. `remaining` runs this continuation plus full dark/narrow
  in one matrix. Pending-request tests dismiss the actual iPad keyboard,
  retain the real draft, and find the ScrollView containing request controls;
  the recorded 49pt firstMatch failure was the keyboard prediction row.
- `narrow` / `testRoundThreeNarrowAccessibility`: an actual measured
  600-point hosting container with accessibility-extra-extra-large Dynamic
  Type, Settings/Feature Center navigation, pending question/approval, empty
  Changes, and workbench close. It omits the already-covered Desktop focus
  sub-flow and additional state launches.

The 285 round-2 parser/lexer assertions, native copy/paste, file reading,
full send/stop, and general kernel test matrices are not selected here.
Existing tests remain present. A measured Demo hosting container verifies a
narrow layout; it is not proof of physical Stage Manager or Split View.

The actual Feature Center uses `codexpad.feature-search` (TextField),
`codexpad.feature-search-clear`, and `codexpad.feature-close`. In a compact
layout, `codexpad.feature-back` presents a catalog sheet without discarding
the selected detail; `codexpad.feature-browser-back` closes that browser. The
standard profiles make a real edit, record the actual JSON editor draft,
and require it to survive this navigation. The test does not require a
retained detail to disappear.

## Fixture and production boundaries

All new tests launch `--codexpad-demo --codexpad-demo-auxiliary` and explicit
`--codexpad-touch-mode`. The narrow profile also uses the existing
`--codexpad-demo-width=600` argument. State launches add exactly one of:

```
--codexpad-demo-state-starting
--codexpad-demo-state-connecting
--codexpad-demo-state-offline
--codexpad-demo-state-welcome
```

The auxiliary fixture supplies real model types with explicit Demo data: a
long workspace path and account label, empty Plan/Changes/Files, one error
banner, question `question-aux` with question ID `reading-mode`, and command
approval `approval-aux`. The UI selects `Detailed notes` through the real menu,
checks the shared freeform binding, and submits through the actual action.
The Demo answer guard records the actual `answers` JSON built before that
guard; the UI test requires the real receipt to contain `reading-mode`,
`Detailed notes`, and `answers`. It never inserts an expected receipt.

Approval actions retain the existing choices and Demo guard. The test
requires the real pending card to disappear after decline; protocol payload
preservation must also be assessed in the source diff. This is not a live
app-server response assertion. No model turn, account login, model refresh,
folder picker, file write, or Retry action is invoked. In particular,
`retryConnection` remains a live path without a Demo guard, so offline
verification checks its visible enabled control without tapping it.

The AppDelegate's existing background guest boot remains active in the
simulator. The job sets only the ephemeral macOS runner HostName to
`codexpad-ui`, and records that it fits the existing 65-byte guest uname field.
This inherited CI condition does not repair or identify an iPad connection
fault and does not change the production kernel.

## Native evidence and failure handling

Screenshots are original `XCUIScreen.mainScreen.screenshot` attachments,
exported from the actual xcresult alongside manifests. They are not generated
mockups or HTML renders. A failed control lookup also preserves the live
accessibility hierarchy and screen. The workflow retains simulator process
logs and relevant crash reports on failure. An empty crash manifest does not
establish why an app exited. Visual review must still inspect text wrapping,
clipping, contrast, long paths, and action visibility in the original images.

## Executed acceptance — 2026-10-08

Application and device-package source: `8751898dd39fe2a2be076d5d647c4f0d2771020c`.
Later `7c54a78`, `5b5faf6`, and `3c18db0` only change the XCTest driver,
workflow selection and documentation. The final comparison of `app/CodexPad`
and `iSH.xcodeproj` against the package source has no differences.

| Actual check | Result |
| --- | --- |
| ARM64 Release / existing RPC regressions | [37733906776](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37733906776) passed; rootfs BusyBox is ELF64 ARM aarch64; IPA is unsigned |
| Light prefix | [37733903968](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37733903968) remains failed; error dismissal, switches, handoff, search/detail and actual JSON edit passed before the decorative NoResults Image lookup failed |
| Light middle | [37743091835](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37743091835) remains failed; actual no-result clearing and three focus/draft assertions passed before the driver selected the keyboard prediction ScrollView |
| Light remaining requests/states | [37745345364](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37745345364), job 113205395723, passed in 170.176 seconds with 0 failures |
| Full dark Round 3 flow | Same run, job 113205396118, passed in 310.435 seconds with 0 failures; includes final edited JSON draft equality |
| Full measured 600pt / AX XXL flow | [37747566003](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37747566003), source `3c18db0`, job 113213441514, passed in 254.293 seconds with 0 failures; `focus:NO` does not test focus restoration or an edited JSON draft |

Light acceptance combines the recorded prefix, middle and remaining flow on
identical application source. It does not relabel either failed Light run as
a successful full job. Six actual test failures remain in the local failure
history. Old-head run `37747356564` was cancelled before the build/test step,
which GitHub records as skipped, and is excluded from acceptance.

The final narrow retry scrolls the real catalog List before requiring the
searched row to be hittable. Its earlier failure established only that the
row existed but was not hittable without attempting to scroll; it did not
identify a production layout fault. No production change was made for it.

Original PNGs, manifests, per-run sources and SHA-256 are retained under the
task's `outputs/CodexPad-UI-Round3`, alongside `VALIDATION.md`,
`native-validation.json`, `failure-history.json`, and `package.json`.
Windows has no Xcode; the build and native interaction results above were
executed by macOS CI. The unchanged five Foundation inputs were compared,
so the previous 285 parser/lexer assertions were not repeated.
Physical iPad, live login/provider data, long-running connection behavior,
real approval RPCs, and hardware keyboard shortcuts remain unverified here.

## External visual review closeout

After `9832b9d`, external review of the original screenshots identified two
display defects despite the successful interaction tests: the Settings title
was absent, and the category icon overran its fixed 22pt slot at AX XXL.
Settings now explicitly uses the native inline title. Feature icons use a
body-relative scaled font, natural size and a scaled minimum column width;
the title and method fonts retain their original Dynamic Type behavior.

Manual `closeout` runs the existing complete Light flow plus the focused
`dark-visual` and `narrow-visual` tests. These record initial, scrolled and
reopened Settings, the real filtered result with the keyboard visible, and
actual detail navigation. Native title presence/geometry is checked, while
pixel-level icon overlap and title appearance still require original PNG
review. Missing-title failures preserve the screen and accessibility tree.
The new application source requires a fresh ARM64 package. No parser,
kernel or unrelated UI suites are added to this closeout.

### Executed closeout — 2026-10-08

Application, native tests and the new ARM64 package use the same source:
`4f47705f7c7ebc7f4c2fb186e93d9263c164a7ae`, based on `9832b9d`.
Only two production UI files changed: `CodexSettingsView.swift` and
`CodexFeatureCenterView.swift`. The native closeout matrix
[37755287303](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37755287303)
completed successfully.

| Actual check | Result and retained artifact |
| --- | --- |
| Complete Light / `testRoundThreeLight` | Job `113238218395`, 449.981 seconds, 1 test and 0 failures; artifact `11539949649` |
| Focused dark / `testRoundThreeVisualFixDark` | Job `113238218329`, 161.987 seconds and 0 failures; artifact `11540362289` |
| Focused measured 600pt / AX XXL / `testRoundThreeVisualFixNarrow` | Job `113238218054`, 186.663 seconds and 0 failures; artifact `11540690889` |
| Fresh ARM64 Release / existing RPC regressions | [37755287453](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37755287453), job `113238218024`, passed; artifact `11540285044`, unsigned IPA build `805` |

This is a successful complete Light run for the new source, rather than the
earlier segmented Light acceptance. The dark and narrow checks in this new
matrix are focused visual-fix flows, not full Round 3 regressions. No extra
parser/lexer or general kernel suites were selected.

Twenty-six original PNGs are retained: 16 Light, 5 focused dark and 5 focused
narrow. Every copied image matches the exported raw bytes and SHA-256.
Original-image review confirmed the Settings title in Light, and the title
in initial/reopened Settings for both other profiles. Both settings headers
have less empty space than the previous screenshots. The AX XXL result row
shows the complete category icon inside the card, separate from `List`,
while the existing enlarged body type is retained. The actual Done close,
reopen and Settings-to-Feature-Center navigation passed their native tests.

Two image limits remain explicit. The focused dark initial and named
`settings-scrolled` PNGs are byte-identical, so those two images alone do
not prove content movement. The native title assertion after the actual
Form scroll to the Feature Center entry passed; the narrow scrolled image
also visibly changes from Input mode to Model while retaining the title.
The focused dark search image keeps the keyboard visible and shows the
complete icon and `List`, but the rest of the row is below the keyboard;
the AX XXL search image shows the whole result row. AX geometry checks do
not replace this original-pixel review.

Previous delivery evidence and failed history remain under
`outputs/CodexPad-UI-Round3`. New evidence, `VALIDATION.md`,
`native-validation.json`, screenshot manifests/hashes and `package.json`
are saved separately under `outputs/CodexPad-UI-Round3-Visual-Fix`.
The new IPA is unsigned and has not been installed. Physical iPad execution,
live login/RPC/file permissions, hardware keyboard, dynamic Stage Manager
and long connection stability remain unverified.
