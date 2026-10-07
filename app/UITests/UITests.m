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
@end

@implementation UITests

- (void)setUp {
    self.continueAfterFailure = NO;
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
    XCUIElement *otherThread = [self visibleThreadWithID:@"demo-2" inApp:app];
    if (otherThread == nil) {
        [[self visibleButton:@"codexpad.threads" inApp:app] tap];
        otherThread = [self visibleThreadWithID:@"demo-2" inApp:app];
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

@end
