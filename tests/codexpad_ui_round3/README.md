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
are `all`, `light`, `dark`, `narrow`, and `dark-narrow`; use a single failed profile for any
necessary retry instead of repeating passed jobs.
`dark-narrow` runs those two jobs together after the full light flow passes,
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

Status at preparation: **native tests and ARM64 build have not run**. Windows
has no Xcode, so local source/workflow checks do not substitute for compiling
or executing these tests. Record actual runs, sources, conclusions, original
PNG review, and any remaining limitations in the delivery report after CI.
Physical iPad, live login/provider data, long-running connection behavior,
real approval RPCs, and hardware keyboard shortcuts remain unverified here.
