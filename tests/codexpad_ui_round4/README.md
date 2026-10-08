# Native window acceptance after the three UI rounds

Branch: `codex/ui-round4`; baseline: `c600b2d`.

The supplied design brief defines three implementation stages, all retained.
This stage closes an evidence gap: previous 11-inch runs did not reach the
1280pt threshold for the native workbench inspector. It is not an additional
feature redesign or a speculative runtime repair.

One large iPad simulator runs `testRoundFourWindowTransitions`. Actual workspace
frames must establish landscape at least 1280pt and portrait below 1280pt.
The App uses its normal window constraints, with no Demo width override.
The test exercises real workbench controls and orientation changes, measures
inspector/sheet frames, checks tab and composer-draft retention, closes the
panel and types through restored focus. It also checks that reading earlier
messages across rotation retains the Latest affordance and that Latest works.

Screens and frame records are actual XCTest attachments. Demo data remains
explicitly isolated with `--codexpad-demo --codexpad-desktop-mode
--codexpad-demo-reading`; there are no real model turns or server requests.

The workflow selects an available 13-inch or 12.9-inch iPad on macOS 26,
records its name/runtime and source commit, and saves the xcresult, screenshots
and failure diagnostics. Only this new flow is selected. Previous Settings,
parser, Diff and accessibility suites are not repeated.

The initial plan required an actual failing interaction or demonstrated
defect before changing production sources. The first three runs retained
App/project sources identical to `4f47705` and reused its package. Subsequent
real Latest and input-clipping findings justified narrow production fixes
and new packages. Native test and package source identities are recorded
separately; no prior failed run is relabeled successful.

SwiftUI inspector presentation is context-dependent according to
[Apple's inspector documentation](https://developer.apple.com/documentation/swiftui/view/inspector(ispresented:content:)).
Orientation is exercised using the native
[XCUIDevice API](https://developer.apple.com/documentation/xcuiautomation/xcuidevice).
Neither API use nor a passing interaction replaces inspection of original pixels.

Physical 11-inch iPad, hardware keyboard, real Stage Manager/Split View resizing,
live login/provider/file/approval operations and long connection stability are
separate from this simulator acceptance.

## First execution and targeted continuation

The first run [37763110536](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37763110536)
at `de6616d` remains failed: 1 test, 1 failure in 154.304 seconds. Actual
1376pt landscape / 1032pt portrait and Files inspector-to-sheet-to-inspector
assertions passed. Four prefix screenshots and one failure screenshot are
preserved with their original frames and source identity.

The immediate post-Done AX value assertion read `after Do`. The later failure
attachment already records the complete actual `after Done` in the same
composer, without another input operation. This establishes an early read;
it does not identify which UIKit/binding/AX update layer was delayed.
The driver now waits for the real complete value after input, without
retyping, replacing the binding or editing production code.

Manual `remaining` selects `testRoundFourRemaining`: re-establish the wide
Files inspector and verify Done input, then execute the shared reading and
toolbar-Hide checks. It does not repeat the passed workbench rotations.
The full flow remains available as `wide-light`; it is not relabeled passed.
Continuation [37765707117](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37765707117)
at `1646619` passed the real post-Done complete-value check; its screenshot
shows the full three-line draft. The complete job remains failed: 200.367
seconds, 1 failure before the reading/Hide checks completed.

The driver incorrectly expected the expanded output to expose Latest or the
final paragraph without scrolling. The real AX tree puts the final paragraph
at y=1278 below the timeline ending at y=839.5; its label also starts with a
newline, so the old BEGINSWITH matcher cannot select it. The driver now matches
the unique actual text with CONTAINS, scrolls the real timeline to establish
the bottom, then performs the unchanged upward/rotation/Latest checks.

Manual `reading-only` runs `testRoundFourReadingRemaining` and does not repeat
the passed workbench transition or Done checks. All failed conclusions remain
recorded.

Reading-only [37768052457](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37768052457)
at `4a3e44c` established the real bottom and then actually scrolled to the
first user paragraph. It failed in 86.204 seconds because Latest did not
exist. The screenshot shows the complete earlier paragraph; its frame is
y=233, the final paragraph is at y=1468 below the viewport ending at 839.5,
and the main vertical scroll bar is at 0%. This is a production follow-state
defect, rather than a failed gesture or missing Lazy row.

`CodexConversationView.swift` now uses the public iOS 18+ scroll-geometry
and scroll-phase callbacks for the real outer ScrollView. Only real user
scrolling away from the 80pt end threshold pauses following; content growth,
resize and programmatic scrolling do not do so alone. Returning to the end
resumes following. Both callback orders are handled. The iOS 17 deployment
target and original preference fallback remain unchanged; that fallback has
not been validated here. The precise old preference-callback failure was
not instrumented and is not claimed established.

The same reading-only interaction passed in
[37770366433](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37770366433)
at `b84a29f`: 1 test, 0 failures, 188.974 seconds, job `113288199825`,
artifact `11547497593`. Actual earlier-content scrolling exposes reachable
Latest; portrait/landscape rotation retains reading above the final paragraph;
tapping Latest returns the full final paragraph. Actual Files selection and
toolbar Hide preserve the draft and permit App-level input without retapping
the composer. Five original PNGs and five frame/AX records are preserved.

Pixel review of those originals found a separate input-layout issue: the
Hide screenshot shows the complete second line and third-line suffix, but
the first line's top is clipped. The complete AX value does not prove that
all three lines are simultaneously visible. The TextField's 61pt height is
consistent with default body metrics, while `.lineSpacing(4)` requires more
vertical space; the precise native intrinsic/content-height cause was not
instrumented.

`01b3002` removes only the composer's extra line spacing. It retains the body
font, vertical input, `lineLimit(1...7)`, text binding, focus and all actions.
Manual `toolbar-hide-only` selects `testRoundFourToolbarHideRemaining`, using
the same shared actual Hide/input sequence and recording before/after PNGs
only after the complete real value is present. This narrow check does not
repeat the just-passed reading or workbench rotations. The final App source
has its own successful ARM64 Release package from
[37772887105](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37772887105),
job `113296537498`, artifact `11548528820`, at `01b3002`. Existing RPC
regressions passed. The unsigned build 805 IPA has SHA-256
`7ae728b685434bee93e122b8b6657925e7b74cbcd45a0a7f7c900143880442ff`
and 5,888,242 bytes. It is not signed or installed. The b84a29f intermediate
package remains historical. No model/RPC/runtime/permission changes are included.

The first input-only run
[37772879090](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37772879090)
at `01b3002` remains failed: 1 test, 1 failure in 86.282 seconds, artifact
`11549945909`. Its 10-second actual-value wait expired before the workbench
opened. The later original UTF-8 value is exactly the expected 40-character
draft, and the original failure PNG shows all three lines intact, including
the first. This proves the displayed pre-Hide layout, not the unexecuted
Hide interaction. The missing intermediate AX-value sequence is not inferred.

`1cc46ad` changes only two input-value waits to 30 seconds; other waits remain
10 seconds. Exact value equality, real input and the no-composer-retap Hide
condition remain unchanged. There is no forced delay, repeated input or
binding replacement. App/project sources still match the `01b3002` package;
another ARM64 build is unnecessary. Only the same input-only flow is retried.

Retry [37775371303](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37775371303)
at `1cc46ad` also remains failed: 1 test, 1 failure in 103.079 seconds,
artifact `11550181522`. The 10-second landscape readiness wait expired
before typing began. Later original workspace/window frames are both
1376x1032 with orientation3, and the original PNG shows landscape. This
does not establish the earlier AX callback sequence or a production layout
defect. `762fbeb` gives all Round4 readiness predicates a bounded 30-second
wait and logs actual measured frames. Size thresholds and exact input
conditions stay unchanged; other rounds' helpers are not changed. App and
project sources still match the final `01b3002` package.

## Final targeted input acceptance

[37777595828](https://github.com/lbailiang11-droid/codex-for-ipad/actions/runs/37777595828)
at test source `762fbeb` passed: 1 test, 0 failures, 110.388 seconds,
job `113312265597`, artifact `11551007137`. App/project trees exactly match
the final package source `01b3002`; only the test driver changed.

Both original PNGs show all three lines fully visible simultaneously.
The post-Hide image also shows the complete `after toolbar Hide` suffix;
the model, reasoning, More and send controls remain visible and do not
overlap the input or keyboard. Actual complete-value assertions and frame
records confirm original-draft retention and continued App-level typing
without a composer retap after real Files selection and toolbar Hide.

Seventeen original PNGs and seventeen frame/AX records are preserved in
the task's separate `outputs/CodexPad-UI-Round4` directory, each copy
byte/SHA-256 matched: ten from the five failed runs, five from successful
reading, two from successful input. Failed runs remain failed. The full
xcresult/video artifacts are retained by GitHub; local evidence downloads
only the original PNG/text attachments, context and logs.

Reading evidence is from `b84a29f`; window/Done evidence is from the earlier
`4f47705` App source; input/package evidence is from `01b3002` App source.
No single full Round4 flow on the final source was executed or claimed.
Physical 11-inch iPad, iOS17 fallback, hardware keyboard, real window
resizing, streaming updates and live connections remain unverified.
