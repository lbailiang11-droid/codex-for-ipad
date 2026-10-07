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
    // Stay at the top; the fixture has thousands of lines below the honest
    // 200 KB cap notice, which should remain visible in this screenshot.
    [self attachScreen:[name stringByAppendingString:@"-file-truncated-preview"]];
    [self tapRoundTwoButton:@"codexpad.file-preview-back" inApp:app];

    [self openRoundTwoEntry:[root stringByAppendingString:@"/notes.txt"] inApp:app];
    NSPredicate *plainText = [NSPredicate predicateWithFormat:@"label CONTAINS %@", @"Text stays selectable."];
    XCTAssertTrue([[app.staticTexts matchingPredicate:plainText].firstMatch waitForExistenceWithTimeout:5]);
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
    [composer pressForDuration:1.2];
    XCUIElementQuery *pasteItems = [[app descendantsMatchingType:XCUIElementTypeAny]
        matchingPredicate:[NSPredicate predicateWithFormat:@"label == %@", @"Paste"]];
    XCTAssertTrue([pasteItems.firstMatch waitForExistenceWithTimeout:5], @"Native Paste menu did not appear");
    XCUIElement *paste = nil;
    for (NSUInteger index = 0; index < pasteItems.count; index++) {
        XCUIElement *candidate = [pasteItems elementBoundByIndex:index];
        if (candidate.isHittable) { paste = candidate; break; }
    }
    XCTAssertNotNil(paste);
    [paste tap];
    NSPredicate *rawCode = [NSPredicate predicateWithFormat:@"value == %@", expected];
    XCTNSPredicateExpectation *pasted = [[XCTNSPredicateExpectation alloc] initWithPredicate:rawCode object:composer];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[pasted] timeout:5], XCTWaiterResultCompleted,
        @"Copy/Paste must preserve raw code, including whitespace");

    // Remove only this known fixture paste, keeping the same App launch and
    // avoiding a second cold launch just to obtain an empty composer.
    NSMutableString *deleteKeys = [NSMutableString string];
    [expected enumerateSubstringsInRange:NSMakeRange(0, expected.length)
        options:NSStringEnumerationByComposedCharacterSequences
        usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            [deleteKeys appendString:XCUIKeyboardKeyDelete];
        }];
    [composer typeText:deleteKeys];
    XCTAssertTrue([(NSString *)composer.value length] == 0);
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
