# Native UI validation, round 1

Baseline: `a11f8db8b862af400d6c11876a9fe8fc4d849b58`.

The device package continues to use the existing `iSH-ARM64` target and
`.github/workflows/arm64-ios-unsigned.yml`. The screenshot workflow uses the
existing `iSH` simulator scheme, `iSHUITests`, and the same SwiftUI files in
`libiSHApp`. `--codexpad-demo` is an existing explicit, isolated data fixture;
these screenshots do not prove an ARM64 guest, authenticated RPC, or model run.

The upstream reference is
`j0shua-SYSON/codex-for-ipad/main/.github/workflows/ipados-ui.yml` and its
`app/UITests/UITests.m`. This fork did not contain the upstream UI workflow or
its UI tests at the selected baseline. Its local `UITests.m` was empty.
No applicable filesystem `AGENTS.md` was found in this worktree or ancestors.

## Isolated native demonstration

Demo branches implement create/resume/send/stop/approval. They are isolated
by the existing `demoMode` guard; real RPC paths are unchanged. A long bilingual
conversation, fenced long code, 24-line completed command output, long model
name, and a separate `--codexpad-demo-approval` scenario are available.

`--codexpad-demo-width=600` centers the actual hosting view at 600 points,
only when `--codexpad-demo` is also present. The root measures this real
container. Screenshots explicitly identify it as a simulated 600-point
content container. Real Split View and Stage Manager remain unverified.

Tests use native accessibility identifiers for workspace, sidebar, threads,
new-thread, composer, model-picker, reasoning-picker, send, toggle-workbench,
workbench, terminal, return-to-workspace, close-workbench, thread-search and
stop. Thread rows use stable `codexpad.thread.<actual thread ID>` identifiers;
the test verifies the actual `codexpad.conversation-title` header after
creation and selection. Existing approval labels locate real controls; no
test-only buttons are added.

## Evidence

The macOS workflow records Xcode version, selected simulator identity,
appearance, content size, screenshot orientation, tested source commit, and
XCTest screenshots in the xcresult. It exports PNG attachments and simulator
logs on failure. Tests assert actual buttons and typed input; screenshot
existence alone is not a test pass.

Matrix: 11-inch landscape/portrait in light/dark, portrait at accessibility
XXL text, and a 600-point container. Workbench closed/open screenshots are
captured separately. Focus after inspector dismissal, multiline input,
model selection, demo send/stop, terminal recovery, creation/switching of demo
chats with draft retention, and approval dismissal are
tested in the light profile. Dark, large text, and narrow profiles check
reachability and presentation. Standard profiles capture both orientations.

Windows can inspect GitHub Actions with `scripts/codexpad_ui/github_actions.py`.
It retrieves an existing Git credential only in memory and never prints it.
After push, the UI branch trigger starts the screenshot workflow. The existing
device build can be started separately on that branch:

```powershell
python scripts/codexpad_ui/github_actions.py dispatch --workflow arm64-ios-unsigned.yml --ref codex/ui-round1
python scripts/codexpad_ui/github_actions.py runs --branch codex/ui-round1
python scripts/codexpad_ui/github_actions.py artifacts --id RUN_ID
python scripts/codexpad_ui/github_actions.py download --id ARTIFACT_ID --output LOCAL_ZIP
```

For a targeted UI check, use GitHub Actions → **CodexPad native UI round 1** →
**Run workflow**, select `codex/ui-round1`, and choose the `profile` input.
`all` runs the four profiles; an individual profile runs only that test.

Live read-only verification on 2026-10-07 confirmed run `35712515741` succeeded
for baseline commit `a11f8db8b862af400d6c11876a9fe8fc4d849b58` (ARM64 iOS unsigned).
This is the previous baseline build, not a new round-1 build. Existing Git
Credential Manager authentication successfully returned workflows and runs.

## Recorded round-1 results

UI source: `9e50bb61ec922b76f5c6e5d28e2ecd97e2113812`.
The subsequent test/workflow commit
`4e9358733031b1a5acd9f6dee69a4ae080ba65b4` changes only the UI test and
profile selector. Its application SwiftUI sources are identical to this UI
source, so the existing device package and earlier passing screenshots still
represent the same application.
Native UI run: [37615582283](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37615582283).
The corresponding ARM64 unsigned device build passed in run
[37615636404](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37615636404).

- 11-inch simulated 600-point content container: XCTest passed in attempt 1;
  closed conversation, open workbench and thread-browser original PNGs saved.
- 11-inch dark accessibility XXL: XCTest passed in attempt 1; closed
  conversation, open workbench and pending-approval original PNGs saved.
- 11-inch dark standard: initial launch failed with `app state=1`
  (`NotRunning`); the single retry at identical source passed. Original
  portrait/landscape, workbench and approval PNGs saved from attempt 2.
- 11-inch light standard: initial launch failed before UI interaction. The
  single retry passed the earlier controls but failed while locating a
  hittable seeded thread row (`UITests.m:123`). Native evidence showed that
  the soft keyboard reduced the List viewport; the test incorrectly hid
  the visible sidebar when its target row was offscreen. A test-only fix
  scrolls the actual native List and opens the sidebar only when necessary.
  The targeted light run
  [37621843912](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37621843912)
  at test/workflow commit `4e9358733031b1a5acd9f6dee69a4ae080ba65b4` passed
  the complete XCTest suite: both orientations, workbench open/close,
  completed-tool expansion/collapse, model selection, multiline input,
  demo send/stop, desktop focus, terminal return, real new/switch conversation
  header predicates with retained draft, and approval dismissal. Its
  original native PNGs are saved with the other passing profiles.

All four profiles now have passing native XCTest evidence across these two
runs. The earlier matrix run retains its overall failure from the previous
light test result; the targeted successful run does not rewrite that history.

Original pixels and SHA-256 hashes are indexed at
`outputs/CodexPad-UI-Round1/screenshots/index.json` in the task workspace.
There are 21 original native PNGs, including 10 from the successful light run.
Entries identify source, run attempt, artifact, test and selected simulator.
The light entries record their test/workflow source `4e93587` and the
identical application source `9e50bb6`; other profiles were tested at
`9e50bb6`. The unsigned package uses that same application source.
The `state: Shutdown` field in `validation-context.json` is the simulator
selection snapshot taken **before boot**, not its state when screenshots
were captured. Native XCTest screenshots provide execution evidence.

Failed-launch screenshots and text diagnostics are preserved separately in
`work/ui-validation-evidence/run37615582283/`. They show SpringBoard and
`NotRunning`, without a surviving application tree. The available artifact
has no named crash report and no identified exit/assertion cause. The exit
cause remains undetermined; the successful dark retry does not establish
that startup or the real ARM64 runtime is stable.

## Limits

No Xcode or simulator is installed on this Windows host. Native build, test,
and screenshot verification runs on the macOS GitHub Actions runner; the
recorded results above identify the actual passing and failing checks.
This workflow does not use the connected iPad. Real-device keyboard behavior,
external hardware keyboard input, dynamic Stage Manager resizing, ARM64
runtime stability and authenticated server operations require separate
verification. Demo test passes must not be presented as evidence for them.
