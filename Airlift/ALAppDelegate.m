// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALAppDelegate.h"

@interface ALAppDelegate () {
	NSMenu* menu;
	NSMutableArray* uploadHistory;
}

@end

@implementation ALAppDelegate

const NSUInteger MAX_UPLOAD_HISTORY = 10;

@synthesize dropZone;

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification {
	menu = [[NSMenu alloc] init];
	[menu addItemWithTitle:@"Settings..."
	                action:@selector(didClickPreferences:)
	         keyEquivalent:@""];

	NSMenuItem* checkUpdatesMenuItem =
	    [[NSMenuItem alloc] initWithTitle:@"Check for updates..."
	                               action:@selector(checkForUpdates:)
	                        keyEquivalent:@""];
	[checkUpdatesMenuItem setTarget:updater];
	[menu addItem:checkUpdatesMenuItem];

	[menu addItem:[NSMenuItem separatorItem]];
	[menu addItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@""];

	dropZone = [[ALDropZoneView alloc] initWithMenu:menu];

	[_window setContentSize:[[prefs view] frame].size];
	[_window setContentView:[prefs view]];
	[_window setReleasedWhenClosed:NO];
	[_window center];
	[_window setTitle:@"Airlift settings"];
	[_window setLevel:NSFloatingWindowLevel];

	EventHotKeyRef hotKeyRef;
	EventHotKeyID hotKeyID;
	EventTypeSpec eventType;

	eventType.eventClass = kEventClassKeyboard;
	eventType.eventKind = kEventHotKeyPressed;
	InstallApplicationEventHandler(&handleHotkey, 1, &eventType, NULL, NULL);

	hotKeyID.signature = 'shot';
	hotKeyID.id = HotkeyTakeScreenshot;
	RegisterEventHotKey(kVK_ANSI_4, optionKey + shiftKey, hotKeyID,
	                    GetApplicationEventTarget(), 0, &hotKeyRef);

	hotKeyID.signature = 'SHOT';
	hotKeyID.id = HotkeyTakeFullScreenshot;
	RegisterEventHotKey(kVK_ANSI_3, optionKey + shiftKey, hotKeyID,
	                    GetApplicationEventTarget(), 0, &hotKeyRef);

	[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

	[[SUUpdater sharedUpdater] setDelegate:self];
}

+ (ALAppDelegate*)sharedAppDelegate {
	return (ALAppDelegate*)[[NSApplication sharedApplication] delegate];
}

- (void)didClickPreferences:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	[_window makeKeyAndOrderFront:nil];
}

- (void)quit:(id)sender {
	[NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

- (void)showNotificationOfType:(ALNotificationType)notificationType
                         title:(NSString*)title
                      subtitle:(NSString*)subtitle
                additionalInfo:(NSDictionary*)info {

	NSUserNotification* notification = [[NSUserNotification alloc] init];
	NSMutableDictionary* userInfo =
	    [NSMutableDictionary dictionaryWithDictionary:info];
	[userInfo setObject:[NSNumber numberWithInteger:notificationType]
	             forKey:@"type"];

	[notification setUserInfo:userInfo];
	[notification setTitle:title];
	[notification setSubtitle:subtitle];

	[[NSUserNotificationCenter defaultUserNotificationCenter]
	    deliverNotification:notification];
}

- (void)addUploadToHistory:(ALUploadHistoryItem*)historyItem {
	if (uploadHistory == nil) {
		uploadHistory = [NSMutableArray array];
	}
	if ([uploadHistory count] >= MAX_UPLOAD_HISTORY) {
		[uploadHistory removeLastObject];
	}

	[historyItem copyLink];
	[uploadHistory insertObject:historyItem atIndex:0];
	[dropZone setHistoryItems:uploadHistory];
}

- (void)removeUploadFromHistory:(ALUploadHistoryItem*)historyItem {
	[uploadHistory removeObject:historyItem];
	[dropZone setHistoryItems:uploadHistory];
}

- (NSArray*)uploadHistory {
	return (NSArray*)uploadHistory;
}

#pragma mark - NSUserNotificationCenterDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter*)center
       didActivateNotification:(NSUserNotification*)notification {

	ALNotificationType notificationType =
	    [[[notification userInfo] valueForKey:@"type"] intValue];

	switch (notificationType) {
	case ALNotificationURLCopied:
		[[NSWorkspace sharedWorkspace]
		    openURL:[NSURL URLWithString:[[notification userInfo] objectForKey:@"url"]]];
		break;
	case ALNotificationOK:
	case ALNotificationUploadAborted:
		break;
	case ALNotificationParameterError:
		[[ALAppDelegate sharedAppDelegate] didClickPreferences:self];
		break;
	}
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter*)center
     shouldPresentNotification:(NSUserNotification*)notification {
	return YES;
}

#pragma mark - Hotkey handling

+ (void)uploadScreenshot:(NSArray*)additionalArgs {
	NSString* format = @"Screenshot %Y-%m-%d at %H.%M.%S.png";
	NSDictionary* locale =
	    [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
	NSString* fileName = [[NSDate date] descriptionWithCalendarFormat:format
	                                                         timeZone:nil
	                                                           locale:locale];
	NSString* tempFilePath =
	    [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

	NSArray* screencaptureArgs;
	if (additionalArgs == nil) {
		screencaptureArgs = @[tempFilePath];
	} else {
		screencaptureArgs = [additionalArgs arrayByAddingObject:tempFilePath];
	}

	NSTask* screencaptureTask =
	    [NSTask launchedTaskWithLaunchPath:@"/usr/sbin/screencapture"
	                             arguments:screencaptureArgs];
	[screencaptureTask waitUntilExit];

	if (![[NSFileManager defaultManager] fileExistsAtPath:tempFilePath]) {
		return;
	}

	NSURL* fileURL = [NSURL fileURLWithPath:tempFilePath];
	ALUploadManager* upload = [[ALUploadManager alloc] initWithFileURL:fileURL];
	[[[ALAppDelegate sharedAppDelegate] dropZone] setCurrentUpload:upload];
	[upload doUpload];
}

OSStatus
handleHotkey(EventHandlerCallRef nextHandler, EventRef anEvent, void* userData) {
	EventHotKeyID hotKeyID;
	GetEventParameter(anEvent, kEventParamDirectObject, typeEventHotKeyID, NULL,
	                  sizeof(hotKeyID), NULL, &hotKeyID);

	switch (hotKeyID.id) {
	case HotkeyTakeScreenshot:
		[ALAppDelegate uploadScreenshot:@[@"-i"]];
		break;
	case HotkeyTakeFullScreenshot:
		[ALAppDelegate uploadScreenshot:nil];
		break;
	}

	return noErr;
}

/*

#pragma mark - SUUpdaterDelegate

- (void)updater:(SUUpdater*)updater
    didFinishLoadingAppcast:(SUAppcast*)appcast {
    for (SUAppcastItem* item in [appcast items]) {
        NSLog(@"%@", item);
        NSLog(@"%@", [item versionString]);
        NSLog(@"%@", [item DSASignature]);
        NSLog(@"%@", [item fileURL]);
    }
}

- (id<SUVersionComparison>)versionComparatorForUpdater:(SUUpdater*)updater {
    return self;
}

#pragma mark - SUVersionComparison

- (NSComparisonResult)compareVersion:(NSString*)versionA
                           toVersion:(NSString*)versionB {
    NSLog(@"comparing %@ to %@", versionA, versionB);
    return NSOrderedSame;
}
 */

@end
