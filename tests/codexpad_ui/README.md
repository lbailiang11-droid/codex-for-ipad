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
stop. Existing approval labels and combined thread row labels locate real
controls; no test-only buttons are added.

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

Live read-only verification on 2026-10-07 confirmed run `35712515741` succeeded
for baseline commit `a11f8db8b862af400d6c11876a9fe8fc4d849b58` (ARM64 iOS unsigned).
This is the previous baseline build, not a new round-1 build. Existing Git
Credential Manager authentication successfully returned workflows and runs.

## Limits

No Xcode or simulator is installed on this Windows host. Native build, test,
and screenshot results remain unverified until the new workflow executes.
This workflow does not use the connected iPad. Real-device keyboard behavior,
external hardware keyboard input, dynamic Stage Manager resizing, ARM64
runtime stability and authenticated server operations require separate
verification. Demo test passes must not be presented as evidence for them.
