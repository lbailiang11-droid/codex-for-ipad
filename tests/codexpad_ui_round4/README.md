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

Production App/project changes are not planned without an actual failing
interaction or a demonstrated code defect. If App sources remain identical
to `4f47705`, the previous unsigned build 805 IPA is retained without a
duplicate ARM64 build. Native UI test source can differ from package source;
these identities must be recorded separately.

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

The same reading-only interaction will validate this production fix. A new
ARM64 package is now required; the previous build cannot contain the fix.
Results remain pending execution. No model/RPC/runtime/permission changes
are included.
