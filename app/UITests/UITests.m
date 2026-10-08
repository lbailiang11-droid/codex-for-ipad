//
//  UITests.m
//  UITests
//
//  Created by Theodore Dubois on 11/13/20.
//

#import <XCTest/XCTest.h>

@interface UITests : XCTestCase
- (XCUIElement *)visibleButton:(NSString *)identifier inApp:(XCUIApplication *)app;
- (XCUIElement *)visibleThreadWithID:(NSString *)threadID inApp:(XCUIApplication *)app;
- (void)assertConversationTitle:(NSString *)title inApp:(XCUIApplication *)app;
- (void)attachScreen:(NSString *)name;
- (void)exercisePortraitAndLandscape:(XCUIApplication *)app;
- (void)exerciseWorkbench:(XCUIApplication *)app name:(NSString *)name;
- (void)scrollToButton:(XCUIElement *)button inApp:(XCUIApplication *)app;
- (XCUIElement *)roundTwoElement:(NSString *)identifier inApp:(XCUIApplication *)app;
- (void)tapRoundTwoButton:(NSString *)identifier inApp:(XCUIApplication *)app;
- (void)pasteRoundTwoCode:(NSString *)expected inApp:(XCUIApplication *)app;
- (void)exerciseRoundTwoReading:(XCUIApplication *)app name:(NSString *)name clipboard:(BOOL)clipboard;
- (void)openRoundTwoWorkbench:(XCUIApplication *)app;
- (void)openRoundTwoEntry:(NSString *)path inApp:(XCUIApplication *)app;
- (void)revealRoundTwoElement:(XCUIElement *)element scroller:(XCUIElement *)scroller forward:(BOOL)forward inApp:(XCUIApplication *)app;
- (XCUIElement *)roundTwoTextPreviewWithPrefix:(NSString *)prefix inApp:(XCUIApplication *)app;
- (void)exerciseRoundThreeAuxiliary:(XCUIApplication *)app name:(NSString *)name focus:(BOOL)focus;
- (void)exerciseRoundThreePendingRequests:(XCUIApplication *)app name:(NSString *)name;
- (void)openRoundThreeSettings:(XCUIApplication *)app;
- (void)assertRoundThreeSettingsTitle:(XCUIApplication *)app;
- (void)openRoundThreeFeaturesFromSettings:(XCUIApplication *)app;
- (void)exerciseRoundThreeVisualFix:(XCUIApplication *)app name:(NSString *)name;
- (void)tapRoundThreeDone:(XCUIApplication *)app;
- (void)revealRoundThreeElement:(XCUIElement *)element scroller:(XCUIElement *)scroller forward:(BOOL)forward inApp:(XCUIApplication *)app;
- (void)exerciseRoundThreeEmptyWorkbench:(XCUIApplication *)app name:(NSString *)name;
- (void)setRoundThreeSwitch:(XCUIElement *)control value:(NSString *)value inApp:(XCUIApplication *)app;
- (void)exerciseRoundThreeNoResults:(XCUIApplication *)app name:(NSString *)name;
- (void)exerciseRoundThreeFocus:(XCUIApplication *)app name:(NSString *)name;
- (void)exerciseRoundThreeStateVariants;
- (void)dismissRoundThreeKeyboard:(XCUIApplication *)app;
@end

@implementation UITests

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)setRoundThreeSwitch:(XCUIElement *)control value:(NSString *)value inApp:(XCUIApplication *)app {
    XCTAssertTrue(control.exists && control.isHittable);
    CGRect frame = control.frame;
    XCTAssertGreaterThan(frame.size.width, 0);
    // SwiftUI reports the labelled Toggle's complete row as the AX frame.
    // The native UISwitch is at its trailing edge; the row's centre is label
    // space, as the preserved first-run event and screenshot demonstrate.
    XCUICoordinate *edge = [control coordinateWithNormalizedOffset:CGVectorMake(1, 0.5)];
    [[edge coordinateWithOffset:CGVectorMake(-MIN(24, frame.size.width / 2), 0)] tap];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"value == %@", value];
    XCTNSPredicateExpectation *changed = [[XCTNSPredicateExpectation alloc] initWithPredicate:predicate object:control];
    BOOL matched = [XCTWaiter waitForExpectations:@[changed] timeout:5] == XCTWaiterResultCompleted;
    if (!matched) {
        [self attachScreen:@"round3-switch-value-did-not-change"];
        XCTAttachment *details = [XCTAttachment attachmentWithString:
            [NSString stringWithFormat:@"Switch frame=%@; expected=%@; actual=%@\n%@",
                NSStringFromCGRect(frame), value, control.value, app.debugDescription]];
        details.name = @"round3-switch-state-and-hierarchy";
        details.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:details];
    }
    XCTAssertTrue(matched, @"Native switch must reach the requested value through an actual tap");
}

- (XCUIApplication *)launchDemo:(NSArray<NSString *> *)additionalArguments {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    app.launchArguments = [@[@"--codexpad-demo"] arrayByAddingObjectsFromArray:additionalArguments];
    [app launch];
    XCUIElement *workspace = [app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.workspace"];
    BOOL workspaceFound = [workspace waitForExistenceWithTimeout:20];
    if (!workspaceFound) {
        // Preserve the actual screen and hierarchy at the failure, before
        // XCTest terminates the app and the workflow captures SpringBoard.
        [self attachScreen:@"native-launch-workspace-missing"];
        XCUIElement *composer = [app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.composer"];
        NSString *details = [NSString stringWithFormat:@"app state=%lu; composer exists=%d\n%@",
            (unsigned long)app.state, composer.exists, app.debugDescription];
        XCTAttachment *tree = [XCTAttachment attachmentWithString:details];
        tree.name = @"native-launch-accessibility-tree";
        tree.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:tree];
    }
    XCTAssertTrue(workspaceFound, @"Native SwiftUI workspace did not appear");
    XCTAssertTrue([app.keyboards.firstMatch waitForNonExistenceWithTimeout:5]);
    return app;
}

- (void)testRoundOneLight {
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-long-model"]];
    [self exercisePortraitAndLandscape:app];
    XCUIElement *output = app.buttons[@"Show output"];
    for (NSUInteger attempt = 0; attempt < 8 && !output.isHittable; attempt++) {
        [app.scrollViews.firstMatch swipeDownWithVelocity:XCUIGestureVelocitySlow];
    }
    XCTAssertTrue(output.isHittable);
    NSPredicate *containsLastOutputLine = [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"[Demo output 24]"];
    XCUIElement *outputText = [app.staticTexts matchingPredicate:containsLastOutputLine].firstMatch;
    XCTAssertFalse(outputText.exists, @"Completed long output should start collapsed");
    [output tap];
    XCTAssertTrue([outputText waitForExistenceWithTimeout:5]);
    [self attachScreen:@"11-inch-light-completed-tool-output-expanded"];
    [output tap];
    XCTAssertTrue([outputText waitForNonExistenceWithTimeout:5]);
    [app terminate];

    // Only explicit demo mode answers these operations locally. Assertions
    // exercise the same visible SwiftUI controls, without paid model calls.
    app = [self launchDemo:@[@"--codexpad-desktop-mode"]];
    XCUIElement *composer = [app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.composer"];
    XCTAssertTrue(composer.isHittable);
    XCTAssertFalse(app.buttons[@"codexpad.send"].isEnabled);
    [composer tap];
    [composer typeText:@"Multiline input\n第二行验证"];
    XCTAssertTrue(app.buttons[@"codexpad.send"].isEnabled);
    [self attachScreen:@"11-inch-light-multiline-keyboard"];

    XCUIElement *model = [self visibleButton:@"codexpad.model-picker" inApp:app];
    XCTAssertNotNil(model);
    [model tap];
    XCUIElement *alternateModel = app.buttons[@"GPT-5.2-Codex"];
    XCTAssertTrue([alternateModel waitForExistenceWithTimeout:5]);
    [alternateModel tap];
    XCTAssertTrue([app.buttons[@"codexpad.model-picker"].label containsString:@"GPT-5.2-Codex"]);
    [self exerciseWorkbench:app name:@"11-inch-light-focused"];
    [app typeText:@" after workbench"];
    XCTAssertEqualObjects(composer.value, @"Multiline input\n第二行验证 after workbench");

    [[self visibleButton:@"codexpad.send" inApp:app] tap];
    XCUIElement *stop = app.buttons[@"codexpad.stop"];
    XCTAssertTrue([stop waitForExistenceWithTimeout:5]);
    XCTAssertTrue(stop.isHittable);
    XCTAssertFalse(app.buttons[@"codexpad.send"].exists);
    [app typeText:@"After send"];
    XCTAssertEqualObjects(composer.value, @"After send");
    [stop tap];
    XCTAssertTrue([app.buttons[@"codexpad.send"] waitForExistenceWithTimeout:5]);
    [app typeText:@" after stop"];
    XCTAssertEqualObjects(composer.value, @"After send after stop");

    [[self visibleButton:@"codexpad.terminal" inApp:app] tap];
    XCUIElement *returnButton = app.buttons[@"codexpad.return-to-workspace"];
    XCTAssertTrue([returnButton waitForExistenceWithTimeout:5]);
    [returnButton tap];
    XCTAssertTrue([composer waitForExistenceWithTimeout:5]);
    [app typeText:@" after terminal"];
    XCTAssertEqualObjects(composer.value, @"After send after stop after terminal");
    [self attachScreen:@"11-inch-light-desktop-focus-retained"];

    XCUIElement *create = [self visibleButton:@"codexpad.new-thread" inApp:app];
    XCTAssertNotNil(create);
    [create tap];
    [self assertConversationTitle:@"New demo chat" inApp:app];
    [app typeText:@" after new chat"];
    XCTAssertEqualObjects(composer.value, @"After send after stop after terminal after new chat");
    // Selecting a seeded thread must update the conversation, preserve the
    // existing composer draft, and return desktop input to that composer.
    // The soft keyboard reduces the sidebar List's height. A newly prepended
    // chat can put this real row outside its materialized viewport. Scroll
    // the native List rather than treating an offscreen row as a hidden sidebar.
    XCUIElement *threadList = app.collectionViews.firstMatch;
    if (!threadList.isHittable) {
        [[self visibleButton:@"codexpad.threads" inApp:app] tap];
        threadList = app.collectionViews.firstMatch;
    }
    XCTAssertTrue(threadList.isHittable);
    XCUIElement *otherThread = [self visibleThreadWithID:@"demo-2" inApp:app];
    for (NSUInteger attempt = 0; attempt < 8 && otherThread == nil; attempt++) {
        [threadList swipeUpWithVelocity:XCUIGestureVelocitySlow];
        otherThread = [self visibleThreadWithID:@"demo-2" inApp:app];
    }
    if (otherThread == nil) {
        [self attachScreen:@"11-inch-light-thread-switch-row-missing"];
        XCTAttachment *tree = [XCTAttachment attachmentWithString:app.debugDescription];
        tree.name = @"native-thread-switch-accessibility-tree";
        tree.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:tree];
    }
    XCTAssertNotNil(otherThread);
    [otherThread tap];
    [self assertConversationTitle:@"Audit iPad accessibility" inApp:app];
    [app typeText:@" after switching"];
    XCTAssertEqualObjects(composer.value, @"After send after stop after terminal after new chat after switching");
    XCTAssertFalse(app.buttons[@"codexpad.stop"].exists);
    [self attachScreen:@"11-inch-light-new-and-switched-chat"];
    [app terminate];

    app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-approval"]];
    XCUIElement *allow = app.buttons[@"Allow once"];
    [self scrollToButton:allow inApp:app];
    XCTAssertTrue(allow.isHittable);
    XCTAssertTrue(app.buttons[@"Allow for thread"].exists);
    XCTAssertTrue(app.buttons[@"Don’t allow"].exists);
    [self attachScreen:@"11-inch-light-pending-approval"];
    [allow tap];
    XCTAssertTrue([allow waitForNonExistenceWithTimeout:5]);
    XCTAssertFalse(app.staticTexts[@"Could not answer Codex"].exists);
}

- (void)testRoundOneDark {
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-long-model"]];
    [self exercisePortraitAndLandscape:app];
    [app terminate];
    app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-approval"]];
    XCUIElement *decline = app.buttons[@"Don’t allow"];
    [self scrollToButton:decline inApp:app];
    XCTAssertTrue(decline.isHittable);
    [self attachScreen:@"11-inch-dark-pending-approval"];
    [decline tap];
    XCTAssertTrue([decline waitForNonExistenceWithTimeout:5]);
}

- (void)testRoundOneNarrowContainer {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-width=600", @"--codexpad-demo-long-model"]];
    XCUIElement *workspace = [app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.workspace"];
    XCTAssertEqualWithAccuracy(workspace.frame.size.width, 600, 5, @"This must be a real measured 600-point hosting container");
    XCUIElement *threads = app.buttons[@"codexpad.threads"];
    XCTAssertTrue(threads.isHittable);
    XCTAssertTrue([app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.composer"].isHittable);
    [self attachScreen:@"11-inch-simulated-600pt-content-container-closed"];
    [self exerciseWorkbench:app name:@"11-inch-simulated-600pt-content-container"];
    [threads tap];
    XCUIElement *search = [app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.thread-search"];
    XCTAssertTrue([search waitForExistenceWithTimeout:5]);
    [self attachScreen:@"11-inch-simulated-600pt-content-container-thread-browser"];
}

- (void)testRoundOneAccessibility {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-long-model"]];
    XCTAssertTrue(app.buttons[@"codexpad.threads"].isHittable);
    XCTAssertTrue([app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.composer"].isHittable);
    XCTAssertTrue(app.buttons[@"codexpad.model-picker"].isHittable);
    [self attachScreen:@"11-inch-dark-accessibility-XXL-portrait-closed"];
    [self exerciseWorkbench:app name:@"11-inch-dark-accessibility-XXL-portrait"];
    [app terminate];
    app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-approval"]];
    XCUIElement *allow = app.buttons[@"Allow once"];
    [self scrollToButton:allow inApp:app];
    XCTAssertTrue(allow.isHittable);
    [self attachScreen:@"11-inch-dark-accessibility-XXL-pending-approval"];
    [allow tap];
    XCTAssertTrue([allow waitForNonExistenceWithTimeout:5]);
}

- (void)testRoundThreeLight {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-auxiliary"]];
    [self exerciseRoundThreeAuxiliary:app name:@"round3-11-inch-light" focus:YES];
    [self exerciseRoundThreePendingRequests:app name:@"round3-11-inch-light"];
    [self exerciseRoundThreeEmptyWorkbench:app name:@"round3-11-inch-light"];
    [app terminate];
    [self exerciseRoundThreeStateVariants];
}

- (void)testRoundThreeLightRemaining {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-auxiliary", @"--codexpad-show-all-features"]];
    XCUIElement *banner = [self roundTwoElement:@"codexpad.error-banner" inApp:app];
    XCTAssertTrue([banner waitForExistenceWithTimeout:5]);
    [self tapRoundTwoButton:@"codexpad.error-dismiss" inApp:app];
    XCTAssertTrue([banner waitForNonExistenceWithTimeout:5]);
    [self tapRoundTwoButton:@"codexpad.features" inApp:app];
    XCUIElement *center = [self roundTwoElement:@"codexpad.feature-center" inApp:app];
    XCTAssertTrue([center waitForExistenceWithTimeout:5]);
    [self exerciseRoundThreeNoResults:app name:@"round3-11-inch-light-remaining"];
    [self tapRoundThreeDone:app];
    XCTAssertTrue([center waitForNonExistenceWithTimeout:5]);
    [self exerciseRoundThreeFocus:app name:@"round3-11-inch-light-remaining"];
    [self exerciseRoundThreePendingRequests:app name:@"round3-11-inch-light-remaining"];
    [self exerciseRoundThreeEmptyWorkbench:app name:@"round3-11-inch-light-remaining"];
    [app terminate];
    [self exerciseRoundThreeStateVariants];
}

- (void)testRoundThreeLightRequestsRemaining {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-auxiliary"]];
    [self tapRoundTwoButton:@"codexpad.error-dismiss" inApp:app];
    XCTAssertTrue([[self roundTwoElement:@"codexpad.error-banner" inApp:app] waitForNonExistenceWithTimeout:5]);
    [self exerciseRoundThreePendingRequests:app name:@"round3-11-inch-light-requests"];
    [self exerciseRoundThreeEmptyWorkbench:app name:@"round3-11-inch-light-requests"];
    [app terminate];
    [self exerciseRoundThreeStateVariants];
}

- (void)exerciseRoundThreeStateVariants {

    // State fixtures only select real EnginePhase/empty-session values. The
    // retry/auth buttons are deliberately not invoked: they remain live RPCs.
    NSDictionary<NSString *, NSString *> *states = @{
        @"starting": @"codexpad.engine-starting",
        @"connecting": @"codexpad.engine-connecting",
        @"offline": @"codexpad.engine-offline",
        @"welcome": @"codexpad.welcome"
    };
    for (NSString *state in @[@"starting", @"connecting", @"offline", @"welcome"]) {
        XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-auxiliary",
            [@"--codexpad-demo-state-" stringByAppendingString:state]]];
        XCTAssertTrue([[self roundTwoElement:states[state] inApp:app] waitForExistenceWithTimeout:5]);
        XCTAssertFalse([self roundTwoElement:@"codexpad.composer" inApp:app].exists);
        if ([state isEqualToString:@"offline"]) {
            XCTAssertTrue(app.buttons[@"codexpad.engine-retry"].isEnabled);
        }
        [self attachScreen:[@"round3-11-inch-light-state-" stringByAppendingString:state]];
        if ([state isEqualToString:@"welcome"]) {
            // This existing createThread path is explicitly guarded in Demo.
            [self tapRoundTwoButton:@"codexpad.welcome-new-thread" inApp:app];
            XCTAssertTrue([[self roundTwoElement:@"codexpad.empty-conversation" inApp:app] waitForExistenceWithTimeout:5]);
            XCTAssertTrue([self roundTwoElement:@"codexpad.composer" inApp:app].isHittable);
            XCTAssertFalse(app.buttons[@"codexpad.send"].isEnabled);
            [self attachScreen:@"round3-11-inch-light-state-empty-conversation"];
        }
        [app terminate];
    }
}

- (void)testRoundThreeDark {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-auxiliary"]];
    [self exerciseRoundThreeAuxiliary:app name:@"round3-11-inch-dark" focus:YES];
    [self exerciseRoundThreePendingRequests:app name:@"round3-11-inch-dark"];
    [self exerciseRoundThreeEmptyWorkbench:app name:@"round3-11-inch-dark"];
}

- (void)testRoundThreeNarrowAccessibility {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-auxiliary", @"--codexpad-demo-width=600"]];
    XCTAssertEqualWithAccuracy([self roundTwoElement:@"codexpad.workspace" inApp:app].frame.size.width, 600, 5,
        @"Use the actual measured hosting container, not a screenshot crop");
    [self exerciseRoundThreeAuxiliary:app name:@"round3-simulated-600pt-XXL" focus:NO];
    [self exerciseRoundThreePendingRequests:app name:@"round3-simulated-600pt-XXL"];
    [self exerciseRoundThreeEmptyWorkbench:app name:@"round3-simulated-600pt-XXL"];
}

- (void)testRoundThreeVisualFixDark {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-auxiliary", @"--codexpad-show-all-features"]];
    [self exerciseRoundThreeVisualFix:app name:@"round3-visual-fix-11-inch-dark"];
}

- (void)testRoundThreeVisualFixNarrow {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-auxiliary", @"--codexpad-show-all-features", @"--codexpad-demo-width=600"]];
    XCTAssertEqualWithAccuracy([self roundTwoElement:@"codexpad.workspace" inApp:app].frame.size.width, 600, 5,
        @"Use the actual measured hosting container, not a screenshot crop");
    [self exerciseRoundThreeVisualFix:app name:@"round3-visual-fix-simulated-600pt-XXL"];
}

- (void)exerciseRoundThreeVisualFix:(XCUIApplication *)app name:(NSString *)name {
    // Only real Settings navigation and catalog selection are exercised here.
    // Composer, authentication, retries and server requests remain untouched.
    [self openRoundThreeSettings:app];
    XCTAssertEqualObjects(app.switches[@"codexpad.desktop-mode"].value, @"0");
    XCTAssertEqualObjects(app.switches[@"codexpad.touch-show-all"].value, @"1");
    [self attachScreen:[name stringByAppendingString:@"-settings-initial"]];

    XCUIElement *settings = [self roundTwoElement:@"codexpad.settings-screen" inApp:app];
    XCUIElement *scroller = settings.scrollViews.firstMatch;
    if (!scroller.exists) scroller = settings.collectionViews.firstMatch;
    if (!scroller.exists) scroller = settings.tables.firstMatch;
    XCTAssertTrue(scroller.exists, @"Scroll the presented Settings form");
    [scroller swipeUpWithVelocity:XCUIGestureVelocitySlow];
    [self assertRoundThreeSettingsTitle:app];
    [self attachScreen:[name stringByAppendingString:@"-settings-scrolled"]];
    [self tapRoundThreeDone:app];
    XCTAssertTrue([settings waitForNonExistenceWithTimeout:5]);
    [self openRoundThreeSettings:app];
    [self attachScreen:[name stringByAppendingString:@"-settings-reopened"]];

    [self openRoundThreeFeaturesFromSettings:app];
    XCUIElement *search = app.textFields[@"codexpad.feature-search"];
    XCTAssertTrue([search waitForExistenceWithTimeout:5]);
    XCTAssertTrue(search.isHittable);
    [search tap];
    [search typeText:@"thread/list"];
    XCTAssertTrue([app.keyboards.firstMatch waitForExistenceWithTimeout:5]);
    XCUIElement *feature = [self roundTwoElement:@"codexpad.feature.thread/list" inApp:app];
    XCTAssertTrue([feature waitForExistenceWithTimeout:5]);
    XCUIElement *catalog = [self roundTwoElement:@"codexpad.feature-catalog" inApp:app];
    XCUIElement *catalogScroller = catalog.collectionViews.firstMatch;
    if (!catalogScroller.exists) catalogScroller = catalog.scrollViews.firstMatch;
    if (!catalogScroller.exists) catalogScroller = catalog.tables.firstMatch;
    XCTAssertTrue(catalogScroller.exists);
    [self revealRoundThreeElement:feature scroller:catalogScroller forward:YES inApp:app];
    XCTAssertFalse([self roundTwoElement:@"codexpad.feature.fs/readFile" inApp:app].exists,
        @"The real search must filter a nonmatching operation");
    XCTAssertTrue(app.keyboards.firstMatch.exists, @"Keep the actual keyboard visible for the filtered-row screenshot");
    // This original screenshot is also reviewed for icon clipping/overlap.
    // Accessibility frames do not establish pixel-level visual correctness.
    [self attachScreen:[name stringByAppendingString:@"-feature-search"]];
    [feature tap];
    XCTAssertTrue([app.textViews[@"JSON parameters for thread/list"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue(app.staticTexts[@"thread/list"].exists);
    [self attachScreen:[name stringByAppendingString:@"-feature-detail"]];
}

- (void)exerciseRoundThreeAuxiliary:(XCUIApplication *)app name:(NSString *)name focus:(BOOL)focus {
    XCUIElement *banner = [self roundTwoElement:@"codexpad.error-banner" inApp:app];
    XCTAssertTrue([banner waitForExistenceWithTimeout:5]);
    [self attachScreen:[name stringByAppendingString:@"-error-and-waiting"]];
    XCUIElement *dismissError = [self visibleButton:@"codexpad.error-dismiss" inApp:app];
    XCTAssertNotNil(dismissError);
    XCTAssertGreaterThanOrEqual(dismissError.frame.size.width, 43.5);
    XCTAssertGreaterThanOrEqual(dismissError.frame.size.height, 43.5);
    [self tapRoundTwoButton:@"codexpad.error-dismiss" inApp:app];
    XCTAssertTrue([banner waitForNonExistenceWithTimeout:5]);

    XCTAssertFalse(app.buttons[@"codexpad.features"].exists, @"Touch mode starts with the complete feature entry hidden");
    [self openRoundThreeSettings:app];
    XCUIElement *desktop = app.switches[@"codexpad.desktop-mode"];
    XCUIElement *showAll = app.switches[@"codexpad.touch-show-all"];
    XCTAssertEqualObjects(desktop.value, @"0");
    XCTAssertEqualObjects(showAll.value, @"0");
    XCTAssertTrue(desktop.isHittable);
    XCTAssertTrue(showAll.isHittable);
    [self attachScreen:[name stringByAppendingString:@"-settings-touch"]];
    [self setRoundThreeSwitch:showAll value:@"1" inApp:app];
    XCTAssertEqualObjects(showAll.value, @"1");
    [self openRoundThreeFeaturesFromSettings:app];
    XCUIElement *center = [self roundTwoElement:@"codexpad.feature-center" inApp:app];
    XCTAssertTrue([center waitForExistenceWithTimeout:5]);
    XCUIElement *search = app.textFields[@"codexpad.feature-search"];
    XCTAssertTrue([search waitForExistenceWithTimeout:5]);
    XCTAssertTrue(search.isHittable);
    [search tap];
    [search typeText:@"thread/list"];
    XCUIElement *feature = [self roundTwoElement:@"codexpad.feature.thread/list" inApp:app];
    XCTAssertTrue([feature waitForExistenceWithTimeout:5]);
    // The larger system font can put a matching row below the visible List.
    // Scroll the real catalog before requiring the actual button to be hit.
    XCUIElement *catalog = [self roundTwoElement:@"codexpad.feature-catalog" inApp:app];
    XCUIElement *catalogScroller = catalog.collectionViews.firstMatch;
    if (!catalogScroller.exists) catalogScroller = catalog.scrollViews.firstMatch;
    if (!catalogScroller.exists) catalogScroller = catalog.tables.firstMatch;
    XCTAssertTrue(catalogScroller.exists);
    [self revealRoundThreeElement:feature scroller:catalogScroller forward:YES inApp:app];
    XCTAssertFalse([self roundTwoElement:@"codexpad.feature.fs/readFile" inApp:app].exists,
        @"The real search must filter a nonmatching operation");
    [self attachScreen:[name stringByAppendingString:@"-feature-search"]];
    [feature tap];
    XCUIElement *parameters = app.textViews[@"JSON parameters for thread/list"];
    XCTAssertTrue([parameters waitForExistenceWithTimeout:5]);
    XCUIElement *detail = nil;
    // The production detail ScrollView does not require a new test-only ID.
    // Locate the real ancestor of this existing, precisely labelled editor.
    for (NSUInteger index = 0; index < app.scrollViews.count; index++) {
        XCUIElement *candidate = [app.scrollViews elementBoundByIndex:index];
        if (candidate.textViews[@"JSON parameters for thread/list"].exists) {
            detail = candidate;
            break;
        }
    }
    XCTAssertNotNil(detail);
    XCTAssertTrue(app.staticTexts[@"thread/list"].exists);
    XCTAssertTrue(app.buttons[@"codexpad.feature-run"].isEnabled);
    [self attachScreen:[name stringByAppendingString:@"-feature-detail"]];
    NSString *initialParameters = parameters.value;
    if (focus) {
        [self revealRoundThreeElement:parameters scroller:detail forward:YES inApp:app];
        [parameters tap];
        [parameters typeText:@" "];
        XCTAssertNotEqualObjects(parameters.value, initialParameters);
    }
    NSString *actualDraft = parameters.value;
    XCUIElement *back = [self visibleButton:@"codexpad.feature-back" inApp:app];
    BOOL opensCompactCatalog = back != nil;
    if (opensCompactCatalog) {
        [back tap];
        XCTAssertTrue([app.buttons[@"codexpad.feature-browser-back"] waitForExistenceWithTimeout:5]);
    }
    [self exerciseRoundThreeNoResults:app name:name];
    if (opensCompactCatalog) {
        [self tapRoundTwoButton:@"codexpad.feature-browser-back" inApp:app];
        XCTAssertTrue([app.buttons[@"codexpad.feature-browser-back"] waitForNonExistenceWithTimeout:5]);
    }
    XCTAssertEqualObjects(parameters.value, actualDraft, @"Returning from catalog must preserve the actual JSON editor draft");
    [self tapRoundThreeDone:app];
    XCTAssertTrue([center waitForNonExistenceWithTimeout:5]);
    XCTAssertTrue([app.buttons[@"codexpad.features"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue([app.buttons[@"codexpad.input-mode"].label containsString:@"Touch mode"],
        @"Showing the complete catalog must not enable Desktop input behavior");

    if (focus) [self exerciseRoundThreeFocus:app name:name];
}

- (void)exerciseRoundThreeFocus:(XCUIApplication *)app name:(NSString *)name {
    XCUIElement *desktop = app.switches[@"codexpad.desktop-mode"];
    XCUIElement *showAll = app.switches[@"codexpad.touch-show-all"];
    XCUIElement *center = [self roundTwoElement:@"codexpad.feature-center" inApp:app];
    [self openRoundThreeSettings:app];
    [self setRoundThreeSwitch:desktop value:@"1" inApp:app];
    XCTAssertEqualObjects(desktop.value, @"1");
    XCTAssertFalse(showAll.exists);
    [self tapRoundThreeDone:app];
    XCTAssertTrue([app.buttons[@"codexpad.input-mode"].label containsString:@"Desktop mode"]);
    XCUIElement *composer = [self roundTwoElement:@"codexpad.composer" inApp:app];
    [composer tap];
    [composer typeText:@"Settings focus"];
    [self openRoundThreeSettings:app];
    XCTAssertEqualObjects(desktop.value, @"1");
    [self tapRoundThreeDone:app];
    // No composer tap here: this is the existing restoration contract.
    [app typeText:@" retained"];
    XCTAssertEqualObjects(composer.value, @"Settings focus retained");

    [self tapRoundTwoButton:@"codexpad.features" inApp:app];
    XCTAssertTrue([center waitForExistenceWithTimeout:5]);
    [self tapRoundThreeDone:app];
    [app typeText:@" after features"];
    XCTAssertEqualObjects(composer.value, @"Settings focus retained after features");

    // The Settings-to-Feature Center transition must wait for dismissal and
    // return focus after the final panel closes, with this real draft intact.
    [self openRoundThreeSettings:app];
    [self openRoundThreeFeaturesFromSettings:app];
    XCTAssertTrue([center waitForExistenceWithTimeout:5]);
    [self tapRoundThreeDone:app];
    [app typeText:@" after settings features"];
    XCTAssertEqualObjects(composer.value, @"Settings focus retained after features after settings features");
    [self attachScreen:[name stringByAppendingString:@"-desktop-focus-retained"]];

    [self openRoundThreeSettings:app];
    [self setRoundThreeSwitch:desktop value:@"0" inApp:app];
    XCTAssertEqualObjects(desktop.value, @"0");
    XCTAssertEqualObjects(showAll.value, @"1", @"The saved touch catalog choice survives Desktop mode");
    [self setRoundThreeSwitch:showAll value:@"0" inApp:app];
    XCTAssertEqualObjects(showAll.value, @"0");
    [self tapRoundThreeDone:app];
    XCTAssertFalse(app.buttons[@"codexpad.features"].exists);
    XCTAssertTrue([app.buttons[@"codexpad.input-mode"].label containsString:@"Touch mode"]);
    XCTAssertEqualObjects(composer.value, @"Settings focus retained after features after settings features");
}

- (void)exerciseRoundThreeNoResults:(XCUIApplication *)app name:(NSString *)name {
    XCUIElement *search = app.textFields[@"codexpad.feature-search"];
    XCTAssertTrue([search waitForExistenceWithTimeout:5]);
    XCTAssertTrue(search.isHittable);
    if (app.buttons[@"codexpad.feature-search-clear"].exists) {
        [self tapRoundTwoButton:@"codexpad.feature-search-clear" inApp:app];
    }
    NSPredicate *emptySearch = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        if (!search.exists) return NO;
        id value = search.value;
        return value == nil || ([value isKindOfClass:NSString.class] &&
            ([(NSString *)value length] == 0 || [value isEqual:search.placeholderValue]));
    }];
    XCTNSPredicateExpectation *initiallyEmpty = [[XCTNSPredicateExpectation alloc] initWithPredicate:emptySearch object:search];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[initiallyEmpty] timeout:5], XCTWaiterResultCompleted);
    [search tap];
    [search typeText:@"__codexpad_no_match__"];

    // ContentUnavailableView gives its ID to Image, text and Button children.
    // Require the observed state text and real action, not a decorative image.
    NSPredicate *titleMatch = [NSPredicate predicateWithFormat:@"identifier == %@ AND label == %@",
        @"codexpad.feature-no-results", @"No matching features"];
    XCUIElement *title = [app.staticTexts matchingPredicate:titleMatch].firstMatch;
    XCTAssertTrue([title waitForExistenceWithTimeout:5]);
    NSPredicate *clearMatch = [NSPredicate predicateWithFormat:@"identifier == %@ AND label == %@",
        @"codexpad.feature-no-results", @"Clear search"];
    XCUIElement *clear = [app.buttons matchingPredicate:clearMatch].firstMatch;
    XCUIElement *catalog = [self roundTwoElement:@"codexpad.feature-catalog" inApp:app];
    XCUIElement *scroller = catalog.collectionViews.firstMatch;
    if (!scroller.exists) scroller = catalog.scrollViews.firstMatch;
    if (!scroller.exists) scroller = catalog.tables.firstMatch;
    XCTAssertTrue(scroller.exists);
    [self revealRoundThreeElement:clear scroller:scroller forward:YES inApp:app];
    XCTAssertTrue(clear.isEnabled);
    XCTAssertTrue(CGRectIntersectsRect(title.frame, catalog.frame), @"The actual state title must be in the visible catalog");
    XCTAssertFalse([self roundTwoElement:@"codexpad.feature.thread/list" inApp:app].exists);
    [self attachScreen:[name stringByAppendingString:@"-feature-no-results"]];
    [clear tap];
    XCTNSPredicateExpectation *cleared = [[XCTNSPredicateExpectation alloc] initWithPredicate:emptySearch object:search];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[cleared] timeout:5], XCTWaiterResultCompleted,
        @"The real empty-state action must clear the bound search field");
    XCTAssertTrue([title waitForNonExistenceWithTimeout:5]);
}

- (void)exerciseRoundThreePendingRequests:(XCUIApplication *)app name:(NSString *)name {
    // Focus assertions have completed. Dismiss the real keyboard before
    // scrolling requests; its prediction row is also an AX ScrollView.
    [self dismissRoundThreeKeyboard:app];
    XCUIElement *picker = app.buttons[@"codexpad.question.options.reading-mode"];
    XCUIElement *timeline = nil;
    for (NSUInteger index = 0; index < app.scrollViews.count; index++) {
        XCUIElement *candidate = [app.scrollViews elementBoundByIndex:index];
        if (candidate.buttons[@"codexpad.question.options.reading-mode"].exists ||
            candidate.buttons[@"codexpad.approval.decline.approval-aux"].exists) {
            timeline = candidate;
            break;
        }
    }
    XCTAssertNotNil(timeline, @"Scroll the real ancestor of the pending request, not a keyboard or model-control scroll view");
    [self revealRoundThreeElement:picker scroller:timeline forward:NO inApp:app];
    XCUIElement *submit = app.buttons[@"codexpad.question.submit.question-aux"];
    XCTAssertFalse(submit.isEnabled, @"An unanswered required question cannot be submitted");
    [self attachScreen:[name stringByAppendingString:@"-pending-question"]];
    [picker tap];
    XCUIElement *option = app.buttons[@"Detailed notes"];
    XCTAssertTrue([option waitForExistenceWithTimeout:5]);
    XCTAssertTrue(option.isHittable);
    [option tap];
    XCTAssertTrue(submit.isEnabled);
    XCTAssertEqualObjects([self roundTwoElement:@"codexpad.question.field.reading-mode" inApp:app].value, @"Detailed notes",
        @"Structured choice and freeform input must still share the same answer binding");
    [self revealRoundThreeElement:submit scroller:timeline forward:YES inApp:app];
    [submit tap];
    XCTAssertTrue([[self roundTwoElement:@"codexpad.question.question-aux" inApp:app] waitForNonExistenceWithTimeout:5]);
    NSPredicate *actualPayload = [NSPredicate predicateWithFormat:
        @"label CONTAINS %@ AND label CONTAINS %@ AND label CONTAINS %@", @"reading-mode", @"Detailed notes", @"answers"];
    XCUIElement *notice = [app.staticTexts matchingPredicate:actualPayload].firstMatch;
    [self revealRoundThreeElement:notice scroller:timeline forward:NO inApp:app];
    XCTAssertTrue(notice.exists, @"The Demo receipt must expose the actual answer payload constructed by the same production path");
    XCTAssertFalse(app.staticTexts[@"Could not send your answer"].exists);

    XCUIElement *decline = app.buttons[@"codexpad.approval.decline.approval-aux"];
    [self revealRoundThreeElement:decline scroller:timeline forward:YES inApp:app];
    XCTAssertTrue(app.buttons[@"codexpad.approval.once.approval-aux"].exists);
    XCTAssertTrue(app.buttons[@"codexpad.approval.session.approval-aux"].exists);
    [self attachScreen:[name stringByAppendingString:@"-pending-approval"]];
    [decline tap];
    XCTAssertTrue([[self roundTwoElement:@"codexpad.approval.approval-aux" inApp:app] waitForNonExistenceWithTimeout:5]);
    XCTAssertFalse([self roundTwoElement:@"codexpad.error-banner" inApp:app].exists);
}

- (void)dismissRoundThreeKeyboard:(XCUIApplication *)app {
    XCUIElement *keyboard = app.keyboards.firstMatch;
    if (!keyboard.exists) return;
    XCUIElement *composer = [self roundTwoElement:@"codexpad.composer" inApp:app];
    id draft = composer.value;
    NSPredicate *dismissLabel = [NSPredicate predicateWithFormat:
        @"label MATCHES[c] %@ OR identifier MATCHES[c] %@", @"(Hide|Dismiss) keyboard", @"(Hide|Dismiss) keyboard"];
    XCUIElementQuery *buttons = [app.buttons matchingPredicate:dismissLabel];
    BOOL tapped = NO;
    for (NSUInteger index = 0; index < buttons.count; index++) {
        XCUIElement *button = [buttons elementBoundByIndex:index];
        if (button.isHittable) { [button tap]; tapped = YES; break; }
    }
    XCTAssertTrue(tapped, @"The native iPad keyboard must expose a reachable dismissal action");
    XCTAssertTrue([keyboard waitForNonExistenceWithTimeout:5]);
    XCTAssertEqualObjects(composer.value, draft, @"Dismissing the keyboard must preserve the actual composer draft");
}

- (void)exerciseRoundThreeEmptyWorkbench:(XCUIApplication *)app name:(NSString *)name {
    [self tapRoundTwoButton:@"codexpad.toggle-workbench" inApp:app];
    XCUIElement *workbench = [self roundTwoElement:@"codexpad.workbench" inApp:app];
    XCTAssertTrue([workbench waitForExistenceWithTimeout:5]);
    NSArray<NSString *> *tabs = [name containsString:@"light"] ? @[@"Plan", @"Changes", @"Files"] : @[@"Changes"];
    for (NSString *tab in tabs) {
        XCTAssertTrue(app.buttons[tab].isHittable);
        [app.buttons[tab] tap];
        NSString *identifier = [NSString stringWithFormat:@"codexpad.%@-empty", tab.lowercaseString];
        XCTAssertTrue([[self roundTwoElement:identifier inApp:app] waitForExistenceWithTimeout:5]);
        [self attachScreen:[NSString stringWithFormat:@"%@-empty-%@", name, tab.lowercaseString]];
    }
    [self tapRoundTwoButton:@"codexpad.close-workbench" inApp:app];
    XCTAssertTrue([workbench waitForNonExistenceWithTimeout:5]);
}

- (void)openRoundThreeSettings:(XCUIApplication *)app {
    XCUIElement *settings = [self visibleButton:@"codexpad.settings" inApp:app];
    if (settings == nil) {
        [self tapRoundTwoButton:@"codexpad.threads" inApp:app];
        XCTAssertTrue([app.buttons[@"codexpad.settings"] waitForExistenceWithTimeout:5]);
        settings = [self visibleButton:@"codexpad.settings" inApp:app];
    }
    XCTAssertNotNil(settings);
    [settings tap];
    XCTAssertTrue([app.switches[@"codexpad.desktop-mode"] waitForExistenceWithTimeout:5]);
    [self assertRoundThreeSettingsTitle:app];
}

- (void)assertRoundThreeSettingsTitle:(XCUIApplication *)app {
    XCUIElement *bar = app.navigationBars[@"Settings"];
    BOOL foundBar = [bar waitForExistenceWithTimeout:5];
    XCUIElement *title = [bar.staticTexts matchingPredicate:[NSPredicate predicateWithFormat:@"label == %@", @"Settings"]].firstMatch;
    BOOL foundTitle = foundBar && [title waitForExistenceWithTimeout:5];
    XCUIElement *done = bar.buttons[@"codexpad.settings-done"];
    BOOL foundDone = foundBar && [done waitForExistenceWithTimeout:5];
    if (!foundBar || !foundTitle || !foundDone) {
        [self attachScreen:@"round3-visual-fix-settings-title-missing"];
        XCTAttachment *tree = [XCTAttachment attachmentWithString:app.debugDescription];
        tree.name = @"round3-visual-fix-settings-title-accessibility-tree";
        tree.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:tree];
    }
    XCTAssertTrue(foundBar, @"Require the presented native Settings navigation bar");
    XCTAssertTrue(foundTitle, @"The real native Settings title must be exposed");
    XCTAssertTrue(foundDone);
    CGRect titleFrame = title.frame;
    XCTAssertGreaterThan(titleFrame.size.width, 0);
    XCTAssertGreaterThan(titleFrame.size.height, 0);
    XCTAssertTrue(CGRectContainsRect(bar.frame, titleFrame), @"Native title frame %@ must be inside navigation bar %@",
        NSStringFromCGRect(titleFrame), NSStringFromCGRect(bar.frame));
    XCTAssertFalse(CGRectIntersectsRect(titleFrame, done.frame), @"Settings title must not overlap the real Done action");
    // Screenshots still require visual review: AX geometry is not pixel proof.
}

- (void)tapRoundThreeDone:(XCUIApplication *)app {
    XCUIElementQuery *doneButtons = [app.buttons matchingPredicate:[NSPredicate predicateWithFormat:@"label == %@", @"Done"]];
    XCUIElement *done = nil;
    for (NSUInteger index = 0; index < doneButtons.count; index++) {
        XCUIElement *candidate = [doneButtons elementBoundByIndex:index];
        if (candidate.isHittable) { done = candidate; break; }
    }
    XCTAssertNotNil(done, @"The currently presented native auxiliary page must have a reachable Done action");
    [done tap];
}

- (void)openRoundThreeFeaturesFromSettings:(XCUIApplication *)app {
    XCUIElement *settings = [self roundTwoElement:@"codexpad.settings-screen" inApp:app];
    XCTAssertTrue(settings.exists);
    XCUIElement *scroller = settings.scrollViews.firstMatch;
    if (!scroller.exists) scroller = settings.collectionViews.firstMatch;
    if (!scroller.exists) scroller = settings.tables.firstMatch;
    XCTAssertTrue(scroller.exists, @"Use the presented native Settings form, not a list behind the sheet");
    XCUIElement *open = app.buttons[@"codexpad.open-feature-center"];
    [self revealRoundThreeElement:open scroller:scroller forward:YES inApp:app];
    [self assertRoundThreeSettingsTitle:app];
    [open tap];
    XCTAssertTrue([[self roundTwoElement:@"codexpad.feature-center" inApp:app] waitForExistenceWithTimeout:5]);
    XCTAssertTrue([settings waitForNonExistenceWithTimeout:5], @"Complete Settings dismissal before the next sheet");
}

- (void)revealRoundThreeElement:(XCUIElement *)element scroller:(XCUIElement *)scroller forward:(BOOL)forward inApp:(XCUIApplication *)app {
    for (NSUInteger attempt = 0; attempt < 10 && !element.isHittable; attempt++) {
        if (forward) [scroller swipeUpWithVelocity:XCUIGestureVelocitySlow];
        else [scroller swipeDownWithVelocity:XCUIGestureVelocitySlow];
    }
    if (!element.isHittable) {
        [self attachScreen:@"native-round3-control-unreachable"];
        XCTAttachment *tree = [XCTAttachment attachmentWithString:app.debugDescription];
        tree.name = @"native-round3-control-accessibility-tree";
        tree.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:tree];
    }
    XCTAssertTrue(element.exists);
    XCTAssertTrue(element.isHittable);
}

- (void)testRoundTwoLight {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-reading"]];
    [self exerciseRoundTwoReading:app name:@"round2-11-inch-light" clipboard:YES];
}

- (void)testRoundTwoDark {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-reading"]];
    [self exerciseRoundTwoReading:app name:@"round2-11-inch-dark" clipboard:YES];
}

- (void)testRoundTwoNarrowAccessibility {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-reading", @"--codexpad-demo-width=600"]];
    XCUIElement *workspace = [self roundTwoElement:@"codexpad.workspace" inApp:app];
    XCTAssertEqualWithAccuracy(workspace.frame.size.width, 600, 5);
    [self exerciseRoundTwoReading:app name:@"round2-simulated-600pt-content-XXL" clipboard:NO];
}

- (void)testRoundTwoNarrowPreview {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationLandscapeLeft;
    XCUIApplication *app = [self launchDemo:@[@"--codexpad-touch-mode", @"--codexpad-demo-reading", @"--codexpad-demo-width=600"]];
    XCUIElement *workspace = [self roundTwoElement:@"codexpad.workspace" inApp:app];
    XCTAssertEqualWithAccuracy(workspace.frame.size.width, 600, 5);
    [self openRoundTwoWorkbench:app];
    XCTAssertTrue(app.buttons[@"Files"].isHittable);
    [app.buttons[@"Files"] tap];

    NSString *root = @"/root/workspace/reading-demo";
    [self openRoundTwoEntry:[root stringByAppendingString:@"/large.txt"] inApp:app];
    XCTAssertTrue([[self roundTwoElement:@"codexpad.file-preview-truncated" inApp:app] waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(app.buttons[@"codexpad.file-preview-copy"].label, @"Copy preview");
    [self roundTwoTextPreviewWithPrefix:@"Readable preview line.\n" inApp:app];
    [self attachScreen:@"round2-simulated-600pt-content-XXL-native-text-truncated-preview"];
    [self tapRoundTwoButton:@"codexpad.file-preview-back" inApp:app];

    [self openRoundTwoEntry:[root stringByAppendingString:@"/notes.txt"] inApp:app];
    XCUIElement *notes = [self roundTwoTextPreviewWithPrefix:@"CodexPad reading workspace.\n" inApp:app];
    XCTAssertEqualObjects(notes.value, @"CodexPad reading workspace.\nText stays selectable.\n");
    [self attachScreen:@"round2-simulated-600pt-content-XXL-native-text-plain-preview"];
    [self tapRoundTwoButton:@"codexpad.file-preview-back" inApp:app];
    [self tapRoundTwoButton:@"codexpad.close-workbench" inApp:app];
    XCTAssertTrue([[self roundTwoElement:@"codexpad.workbench" inApp:app] waitForNonExistenceWithTimeout:5]);
    XCTAssertTrue([self roundTwoElement:@"codexpad.composer" inApp:app].isHittable);
}

- (void)exerciseRoundTwoReading:(XCUIApplication *)app name:(NSString *)name clipboard:(BOOL)clipboard {
    NSString *code = @"// 你好 👋\nlet greeting = \"Hello, iPad\"\nprint(greeting)\n";
    NSString *root = @"/root/workspace/reading-demo";
    NSString *conversationCopyID = @"codexpad.timeline.reading-code.code.1";
    XCUIElement *conversationCopy = app.buttons[conversationCopyID];
    [self revealRoundTwoElement:conversationCopy scroller:app.scrollViews.firstMatch forward:NO inApp:app];
    [self attachScreen:[name stringByAppendingString:@"-conversation-code"]];
    if (clipboard) {
        [conversationCopy tap];
        [self pasteRoundTwoCode:code inApp:app];
    }

    [self openRoundTwoWorkbench:app];
    XCTAssertTrue(app.buttons[@"Changes"].isHittable);
    [app.buttons[@"Changes"] tap];
    XCUIElement *summary = [self roundTwoElement:@"codexpad.diff-summary" inApp:app];
    XCTAssertTrue([summary waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(summary.label, @"4 added lines, 2 removed lines in validated text hunks");
    NSPredicate *partial = [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"validated text hunks only"];
    XCTAssertTrue([app.staticTexts matchingPredicate:partial].firstMatch.exists);
    XCUIElement *diff = [self roundTwoElement:@"codexpad.diff-content" inApp:app];
    NSPredicate *addedLinePredicate = [NSPredicate predicateWithFormat:
        @"identifier BEGINSWITH %@ AND label CONTAINS %@", @"codexpad.diff-line.Sources/Welcome.swift#0.", @"你好, iPad"];
    XCUIElement *addedLine = [[app descendantsMatchingType:XCUIElementTypeAny] matchingPredicate:addedLinePredicate].firstMatch;
    [self revealRoundTwoElement:addedLine scroller:diff forward:YES inApp:app];
    [self attachScreen:[name stringByAppendingString:@"-changes-per-file"]];
    XCUIElement *fold = app.buttons[@"codexpad.diff-file-toggle.Sources/Welcome.swift#0"];
    [self revealRoundTwoElement:fold scroller:diff forward:NO inApp:app];
    [fold tap];
    XCTAssertEqualObjects(fold.value, @"Collapsed");
    XCTAssertTrue([addedLine waitForNonExistenceWithTimeout:5]);
    [fold tap];
    XCTAssertEqualObjects(fold.value, @"Expanded");
    XCTAssertTrue([addedLine waitForExistenceWithTimeout:5]);

    XCUIElement *rawHeader = app.buttons[@"codexpad.diff-file-toggle.broken.txt#0"];
    [self revealRoundTwoElement:rawHeader scroller:diff forward:YES inApp:app];
    XCUIElement *raw = [self roundTwoElement:@"codexpad.diff-raw.broken.txt#0" inApp:app];
    XCTAssertTrue(raw.exists, @"Malformed hunk must preserve its raw patch");
    NSPredicate *rawText = [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"Incomplete after"];
    XCTAssertTrue([app.staticTexts matchingPredicate:rawText].firstMatch.exists);
    [self attachScreen:[name stringByAppendingString:@"-changes-raw-fallback"]];

    XCTAssertTrue(app.buttons[@"Files"].isHittable);
    [app.buttons[@"Files"] tap];
    [self openRoundTwoEntry:[root stringByAppendingString:@"/Sources"] inApp:app];
    [self openRoundTwoEntry:[root stringByAppendingString:@"/Sources/Welcome.swift"] inApp:app];
    XCUIElement *previewName = [self roundTwoElement:@"codexpad.file-preview-name" inApp:app];
    XCTAssertTrue([previewName waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(previewName.label, @"Welcome.swift");
    XCUIElement *fileCopy = app.buttons[@"codexpad.file-preview-code-copy"];
    XCTAssertTrue(fileCopy.isHittable);
    NSPredicate *fileSource = [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"print(greeting)"];
    XCTAssertTrue([app.staticTexts matchingPredicate:fileSource].firstMatch.exists);
    // The line-number gutter is intentionally hidden from VoiceOver. Its
    // presence/alignment is reviewed in this original native screenshot.
    [self attachScreen:[name stringByAppendingString:@"-file-code-line-numbers"]];
    if (clipboard) {
        [fileCopy tap];
        [self tapRoundTwoButton:@"codexpad.close-workbench" inApp:app];
        XCTAssertTrue([[self roundTwoElement:@"codexpad.workbench" inApp:app] waitForNonExistenceWithTimeout:5]);
        [self pasteRoundTwoCode:code inApp:app];
        [self openRoundTwoWorkbench:app];
    }
    [self tapRoundTwoButton:@"codexpad.file-preview-back" inApp:app];
    [self tapRoundTwoButton:@"codexpad.files-parent" inApp:app];
    [self tapRoundTwoButton:@"codexpad.files-refresh" inApp:app];

    [self openRoundTwoEntry:[root stringByAppendingString:@"/binary.bin"] inApp:app];
    XCTAssertTrue([[self roundTwoElement:@"codexpad.file-preview-binary" inApp:app] waitForExistenceWithTimeout:5]);
    XCTAssertFalse(app.buttons[@"codexpad.file-preview-copy"].isEnabled);
    if (clipboard) [self attachScreen:[name stringByAppendingString:@"-file-binary"]];
    [self tapRoundTwoButton:@"codexpad.file-preview-back" inApp:app];

    [self openRoundTwoEntry:[root stringByAppendingString:@"/empty.txt"] inApp:app];
    XCTAssertTrue([app.staticTexts[@"Empty file"] waitForExistenceWithTimeout:5]);
    if (clipboard) [self attachScreen:[name stringByAppendingString:@"-file-empty"]];
    [self tapRoundTwoButton:@"codexpad.file-preview-back" inApp:app];

    [self openRoundTwoEntry:[root stringByAppendingString:@"/large.txt"] inApp:app];
    XCTAssertTrue([[self roundTwoElement:@"codexpad.file-preview-truncated" inApp:app] waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(app.buttons[@"codexpad.file-preview-copy"].label, @"Copy preview");
    XCTAssertTrue(app.buttons[@"codexpad.file-preview-copy"].isEnabled);
    [self roundTwoTextPreviewWithPrefix:@"Readable preview line.\n" inApp:app];
    // Stay at the top; the fixture has thousands of lines below the honest
    // 200 KB cap notice, which should remain visible in this screenshot.
    [self attachScreen:[name stringByAppendingString:@"-file-truncated-preview"]];
    [self tapRoundTwoButton:@"codexpad.file-preview-back" inApp:app];

    [self openRoundTwoEntry:[root stringByAppendingString:@"/notes.txt"] inApp:app];
    XCUIElement *plainText = [self roundTwoTextPreviewWithPrefix:@"CodexPad reading workspace.\n" inApp:app];
    XCTAssertEqualObjects(plainText.value, @"CodexPad reading workspace.\nText stays selectable.\n");
    XCTAssertFalse(app.buttons[@"codexpad.file-preview-code-copy"].exists);
    if (clipboard) [self attachScreen:[name stringByAppendingString:@"-file-plain-text"]];
    [self tapRoundTwoButton:@"codexpad.close-workbench" inApp:app];
    XCTAssertTrue([[self roundTwoElement:@"codexpad.workbench" inApp:app] waitForNonExistenceWithTimeout:5]);
    XCTAssertTrue([self roundTwoElement:@"codexpad.composer" inApp:app].isHittable);
}

- (void)openRoundTwoWorkbench:(XCUIApplication *)app {
    XCUIElement *workbench = [self roundTwoElement:@"codexpad.workbench" inApp:app];
    if (!workbench.exists) [self tapRoundTwoButton:@"codexpad.toggle-workbench" inApp:app];
    XCTAssertTrue([workbench waitForExistenceWithTimeout:5]);
}

- (XCUIElement *)roundTwoTextPreviewWithPrefix:(NSString *)prefix inApp:(XCUIApplication *)app {
    XCUIElement *text = app.textViews[@"codexpad.file-preview-text"];
    XCTAssertTrue([text waitForExistenceWithTimeout:5]);
    NSPredicate *content = [NSPredicate predicateWithFormat:@"value BEGINSWITH %@", prefix];
    XCTNSPredicateExpectation *loaded = [[XCTNSPredicateExpectation alloc] initWithPredicate:content object:text];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[loaded] timeout:5], XCTWaiterResultCompleted,
        @"The actual native text view must expose the preview's source text");
    CGRect frame = text.frame;
    CGRect visible = CGRectIntersection(frame, [self roundTwoElement:@"codexpad.workbench" inApp:app].frame);
    XCTAssertGreaterThan(CGRectGetWidth(visible), 100);
    XCTAssertGreaterThan(CGRectGetHeight(visible), 40);
    XCTAssertTrue(text.isHittable, @"Preview body must occupy a visible, reachable viewport");
    return text;
}

- (void)openRoundTwoEntry:(NSString *)path inApp:(XCUIApplication *)app {
    XCUIElement *workbench = [self roundTwoElement:@"codexpad.workbench" inApp:app];
    XCUIElement *list = [workbench descendantsMatchingType:XCUIElementTypeCollectionView].firstMatch;
    XCTAssertTrue([list waitForExistenceWithTimeout:5]);
    XCUIElement *entry = app.buttons[[@"codexpad.file-entry." stringByAppendingString:path]];
    [self revealRoundTwoElement:entry scroller:list forward:YES inApp:app];
    [entry tap];
}

- (void)revealRoundTwoElement:(XCUIElement *)element scroller:(XCUIElement *)scroller forward:(BOOL)forward inApp:(XCUIApplication *)app {
    for (NSUInteger attempt = 0; attempt < 8 && !element.isHittable; attempt++) {
        XCTAssertTrue(scroller.exists, @"Expected the actual native content scroller");
        if (forward) [scroller swipeUpWithVelocity:XCUIGestureVelocitySlow];
        else [scroller swipeDownWithVelocity:XCUIGestureVelocitySlow];
    }
    if (!element.isHittable) {
        [self attachScreen:@"native-round2-control-unreachable"];
        XCTAttachment *tree = [XCTAttachment attachmentWithString:app.debugDescription];
        tree.name = @"native-round2-control-accessibility-tree";
        tree.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:tree];
    }
    XCTAssertTrue(element.isHittable);
}

- (void)exercisePortraitAndLandscape:(XCUIApplication *)app {
    for (NSNumber *orientation in @[@(UIDeviceOrientationPortrait), @(UIDeviceOrientationLandscapeLeft)]) {
        XCUIDevice.sharedDevice.orientation = orientation.integerValue;
        XCUIElement *workbench = [app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.workbench"];
        XCTAssertTrue([workbench waitForNonExistenceWithTimeout:5], @"Optional workbench must start closed");
        XCTAssertTrue([app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.composer"].isHittable);
        XCTAssertTrue(app.buttons[@"codexpad.model-picker"].exists);
        XCTAssertTrue(app.buttons[@"codexpad.reasoning-picker"].exists);
        XCTAssertTrue(app.buttons[@"codexpad.new-thread"].exists);
        NSString *name = orientation.integerValue == UIDeviceOrientationPortrait ? @"11-inch-portrait" : @"11-inch-landscape";
        [self attachScreen:[name stringByAppendingString:@"-closed"]];
        [self exerciseWorkbench:app name:name];
    }
}

- (void)exerciseWorkbench:(XCUIApplication *)app name:(NSString *)name {
    XCUIElement *toggle = [self visibleButton:@"codexpad.toggle-workbench" inApp:app];
    XCTAssertNotNil(toggle);
    [toggle tap];
    XCUIElement *workbench = [app descendantsMatchingType:XCUIElementTypeAny][@"codexpad.workbench"];
    XCTAssertTrue([workbench waitForExistenceWithTimeout:5]);
    [self attachScreen:[name stringByAppendingString:@"-workbench-open"]];
    XCUIElement *close = [self visibleButton:@"codexpad.close-workbench" inApp:app];
    XCTAssertNotNil(close);
    [close tap];
    XCTAssertTrue([workbench waitForNonExistenceWithTimeout:5]);
}

- (void)scrollToButton:(XCUIElement *)button inApp:(XCUIApplication *)app {
    XCUIElement *scroller = app.scrollViews.firstMatch;
    XCTAssertTrue(scroller.exists);
    // LazyVStack does not create a far-offscreen approval at accessibility
    // sizes. Scroll first, then require the actual button to exist and be
    // hittable; waiting for an unmaterialized row cannot reveal it.
    for (NSUInteger attempt = 0; attempt < 10 && !button.isHittable; attempt++) {
        [scroller swipeUpWithVelocity:XCUIGestureVelocitySlow];
    }
    XCTAssertTrue(button.exists);
}

- (XCUIElement *)visibleButton:(NSString *)identifier inApp:(XCUIApplication *)app {
    XCUIElementQuery *matches = [app.buttons matchingIdentifier:identifier];
    for (NSUInteger index = 0; index < matches.count; index++) {
        XCUIElement *candidate = [matches elementBoundByIndex:index];
        if (candidate.isHittable) return candidate;
    }
    return nil;
}

- (XCUIElement *)visibleThreadWithID:(NSString *)threadID inApp:(XCUIApplication *)app {
    // Use the real session ID so the query survives combined accessibility
    // labels and native List selection wrappers. Inspect the live hierarchy
    // after opening the sidebar instead of caching a previously hidden row.
    NSString *identifier = [@"codexpad.thread." stringByAppendingString:threadID];
    XCUIElementQuery *matches = [[app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:identifier];
    for (NSUInteger index = 0; index < matches.count; index++) {
        XCUIElement *candidate = [matches elementBoundByIndex:index];
        if (candidate.isHittable) return candidate;
    }
    return nil;
}

- (void)assertConversationTitle:(NSString *)title inApp:(XCUIApplication *)app {
    // A matching sidebar title exists before selection. Require the actual
    // conversation header to change, rather than accepting that duplicate.
    XCUIElement *header = app.staticTexts[@"codexpad.conversation-title"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"exists == YES AND label == %@", title];
    XCTNSPredicateExpectation *changed = [[XCTNSPredicateExpectation alloc] initWithPredicate:predicate object:header];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[changed] timeout:5], XCTWaiterResultCompleted);
}

- (void)attachScreen:(NSString *)name {
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

// Round 2 reading helpers. Copy is exercised through the App's real button;
// Paste uses the native edit menu in the existing composer, rather than
// reading UIPasteboard from the separate XCTest runner process.
- (XCUIElement *)roundTwoElement:(NSString *)identifier inApp:(XCUIApplication *)app {
    return [[app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:identifier].firstMatch;
}

- (void)tapRoundTwoButton:(NSString *)identifier inApp:(XCUIApplication *)app {
    XCUIElement *button = [self visibleButton:identifier inApp:app];
    XCTAssertNotNil(button, @"Expected a reachable native button: %@", identifier);
    [button tap];
}

- (void)pasteRoundTwoCode:(NSString *)expected inApp:(XCUIApplication *)app {
    XCUIElement *composer = [self roundTwoElement:@"codexpad.composer" inApp:app];
    XCTAssertTrue(composer.isHittable);
    [composer tap];
    XCTAssertTrue([app.keyboards.firstMatch waitForExistenceWithTimeout:10]);
    // The first attempt's native snapshot exposed this keyboard assistant
    // button. Use its real paste action instead of an unreliable remote menu
    // hit; no clipboard read or expected text is injected by the test runner.
    XCUIElement *paste = app.buttons[@"assistantPaste:forEvent:"];
    if (![paste waitForExistenceWithTimeout:5] || !paste.isHittable) {
        [composer pressForDuration:1.2];
        XCUIElementQuery *pasteItems = [[app descendantsMatchingType:XCUIElementTypeAny]
            matchingPredicate:[NSPredicate predicateWithFormat:@"label == %@", @"Paste"]];
        XCTAssertTrue([pasteItems.firstMatch waitForExistenceWithTimeout:5], @"Native Paste menu did not appear");
        paste = nil;
        for (NSUInteger index = 0; index < pasteItems.count; index++) {
            XCUIElement *candidate = [pasteItems elementBoundByIndex:index];
            if (candidate.isHittable) { paste = candidate; break; }
        }
    }
    XCTAssertNotNil(paste);
    XCTAssertTrue(paste.isEnabled, @"Native Paste must be enabled after Copy");
    [paste tap];
    NSPredicate *rawCode = [NSPredicate predicateWithFormat:@"value == %@", expected];
    XCTNSPredicateExpectation *pasted = [[XCTNSPredicateExpectation alloc] initWithPredicate:rawCode object:composer];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[pasted] timeout:5];
    if (result != XCTWaiterResultCompleted) {
        [self attachScreen:@"native-round2-copy-paste-mismatch"];
        id value = composer.value;
        NSString *actual = [value isKindOfClass:NSString.class] ? value : [value description];
        NSString *details = [NSString stringWithFormat:@"Actual composer value: %@\nActual UTF-8 bytes: %lu\nExpected UTF-8 bytes: %lu\n%@",
            actual, (unsigned long)[actual lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
            (unsigned long)[expected lengthOfBytesUsingEncoding:NSUTF8StringEncoding], app.debugDescription];
        XCTAttachment *evidence = [XCTAttachment attachmentWithString:details];
        evidence.name = @"native-round2-copy-paste-actual-value";
        evidence.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:evidence];
    }
    XCTAssertEqual(result, XCTWaiterResultCompleted,
        @"Copy/Paste must preserve raw code, including whitespace");

    // Remove only this known fixture paste, keeping the same App launch and
    // avoiding a second cold launch just to obtain an empty composer.
    NSMutableString *deleteKeys = [NSMutableString string];
    for (NSUInteger index = 0; index < expected.length; index++) {
        [deleteKeys appendString:XCUIKeyboardKeyDelete];
    }
    NSPredicate *emptyDraft = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        id value = composer.value;
        NSString *current = [value isKindOfClass:NSString.class] ? value : nil;
        BOOL emptyValue = value == nil || (current != nil &&
            (current.length == 0 || [current isEqualToString:composer.placeholderValue]));
        XCUIElement *send = app.buttons[@"codexpad.send"];
        return emptyValue && send.exists && !send.isEnabled;
    }];
    BOOL cleared = NO;
    // The failed light recording showed a remaining prefix after bulk deletion.
    // Keep deletion bounded to this already-verified fixture and require
    // the real empty input + disabled Send state before proceeding.
    for (NSUInteger attempt = 0; attempt < 3 && !cleared; attempt++) {
        [composer typeText:deleteKeys];
        XCTNSPredicateExpectation *empty = [[XCTNSPredicateExpectation alloc] initWithPredicate:emptyDraft object:composer];
        cleared = [XCTWaiter waitForExpectations:@[empty] timeout:2] == XCTWaiterResultCompleted;
    }
    if (!cleared) {
        [self attachScreen:@"native-round2-fixture-cleanup-incomplete"];
        XCTAttachment *evidence = [XCTAttachment attachmentWithString:app.debugDescription];
        evidence.name = @"native-round2-fixture-cleanup-actual-state";
        evidence.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:evidence];
    }
    XCTAssertTrue(cleared, @"The copied fixture must be fully removed; residual text cannot be treated as empty");
    XCUIElement *keyboard = app.keyboards.firstMatch;
    if (keyboard.exists) {
        // The current App has no codexpad.dismiss-keyboard control. Use the
        // iPad keyboard's real dismissal button before presenting the panel.
        NSPredicate *dismissLabel = [NSPredicate predicateWithFormat:
            @"label MATCHES[c] %@ OR identifier MATCHES[c] %@", @"(Hide|Dismiss) keyboard", @"(Hide|Dismiss) keyboard"];
        XCUIElementQuery *buttons = [app.buttons matchingPredicate:dismissLabel];
        BOOL tappedDismiss = NO;
        for (NSUInteger index = 0; index < buttons.count; index++) {
            XCUIElement *button = [buttons elementBoundByIndex:index];
            if (button.isHittable) { [button tap]; tappedDismiss = YES; break; }
        }
        if (tappedDismiss) XCTAssertTrue([keyboard waitForNonExistenceWithTimeout:5]);
    }
}

@end
