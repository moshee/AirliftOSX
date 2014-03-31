// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALAppDelegate.h"
#import "Finder.h"

@interface ALAppDelegate () {
	NSMutableArray* uploadHistory;
}

@end

@implementation ALAppDelegate

@synthesize isBusyUploading, dropZone;

const NSUInteger MAX_UPLOAD_HISTORY = 10;

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification {
	[self setIsBusyUploading:NO];

	[_window setContentSize:[[prefs view] frame].size];
	[_window setContentView:[prefs view]];
	[_window setReleasedWhenClosed:NO];
	[_window center];
	[_window setTitle:@"Airlift settings"];
	[_window setLevel:NSFloatingWindowLevel];

	[self addHotkey:kVK_ANSI_4
	    withModifiers:optionKey + shiftKey
	        signature:'usht'
	        forAction:ALHotkeyTakeScreenshot];
	[self addHotkey:kVK_ANSI_3
	    withModifiers:optionKey + shiftKey
	        signature:'uSHT'
	        forAction:ALHotkeyTakeFullScreenshot];
	[self addHotkey:kVK_ANSI_D
	    withModifiers:optionKey
	        signature:'uFnd'
	        forAction:ALHotkeyUploadFromFinder];
	[self addHotkey:kVK_ANSI_V
	    withModifiers:optionKey + shiftKey
	        signature:'upst'
	        forAction:ALHotkeyUploadFromPasteboard];

	[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

	[[SUUpdater sharedUpdater] setDelegate:self];
}

- (void)addHotkey:(UInt32)key
    withModifiers:(UInt32)modifiers
        signature:(OSType)signature
        forAction:(ALHotkeyAction)action {

	static EventHotKeyRef hotKeyRef;
	static EventHotKeyID hotKeyID;
	static EventTypeSpec eventType;

	eventType.eventClass = kEventClassKeyboard;
	eventType.eventKind = kEventHotKeyPressed;
	InstallApplicationEventHandler(&handleHotkey, 1, &eventType, NULL, NULL);

	hotKeyID.signature = signature;
	hotKeyID.id = action;
	RegisterEventHotKey(key, modifiers, hotKeyID, GetApplicationEventTarget(),
	                    0, &hotKeyRef);
}

- (IBAction)didClickPreferences:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	[_window makeKeyAndOrderFront:nil];
}

#pragma mark - Shared actions

+ (ALAppDelegate*)sharedAppDelegate {
	return (ALAppDelegate*)[[NSApplication sharedApplication] delegate];
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

- (ALPreferenceViewController*)prefs {
	return prefs;
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

OSStatus
handleHotkey(EventHandlerCallRef nextHandler, EventRef anEvent, void* userData) {
	EventHotKeyID hotKeyID;
	GetEventParameter(anEvent, kEventParamDirectObject, typeEventHotKeyID, NULL,
	                  sizeof(hotKeyID), NULL, &hotKeyID);

	switch (hotKeyID.id) {
	case ALHotkeyTakeScreenshot:
		[ALAppDelegate uploadScreenshot:@[@"-i"]];
		break;
	case ALHotkeyTakeFullScreenshot:
		[ALAppDelegate uploadScreenshot:nil];
		break;
	case ALHotkeyUploadFromFinder:
		[ALAppDelegate uploadFileFromFinder];
		break;
	case ALHotkeyUploadFromPasteboard:
		[ALAppDelegate uploadFromPasteboard];
		break;
	}

	return noErr;
}

+ (void)uploadScreenshot:(NSArray*)additionalArgs {
	NSString* fileName =
	    [ALAppDelegate createTimestampPrefixedWith:@"Screenshot"
	                                      endingIn:@".png"];

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
	ALUploadManager* upload = [[ALUploadManager alloc] initWithFileURL:fileURL
	                                            deletingFileAfterwards:YES];
	[[[ALAppDelegate sharedAppDelegate] dropZone] setCurrentUpload:upload];
	[upload doUpload];
}

+ (void)uploadFileFromFinder {
	FinderApplication* finder =
	    [SBApplication applicationWithBundleIdentifier:@"com.apple.Finder"];
	if (![finder isRunning]) {
		NSLog(@"Finder is not running");
		return;
	}

	SBElementArray* selection = [[finder selection] get];
	if ([selection count] == 0) {
		NSLog(@"Finder selection is empty");
		return;
	}

	NSArray* URLs = [selection arrayByApplyingSelector:@selector(URL)];
	NSString* first = [URLs firstObject];
	NSURL* fileURL = [NSURL URLWithString:first];
	if (fileURL == nil) {
		NSLog(@"couldn't convert FinderItem URL '%@' to NSURL", first);
		return;
	}

	ALUploadManager* upload = [[ALUploadManager alloc] initWithFileURL:fileURL
	                                            deletingFileAfterwards:NO];
	[[[ALAppDelegate sharedAppDelegate] dropZone] setCurrentUpload:upload];
	[upload doUpload];
}

+ (void)uploadFromPasteboard {
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];
	NSArray* types = [pboard types];

	NSURL* fileURL;
	BOOL shouldDelete;

	NSLog(@"%@", types);

	if ([types containsObject:NSURLPboardType]) {
		fileURL = [NSURL URLFromPasteboard:pboard];
		shouldDelete = NO;
	} else {
		NSString* tempPath;
		NSError* error;

		if ([types containsObject:NSPasteboardTypeHTML]) {
			NSString* text = [pboard stringForType:NSPasteboardTypeHTML];
			tempPath = [NSTemporaryDirectory()
			    stringByAppendingPathComponent:@"index.html"];

			[text writeToFile:tempPath
			       atomically:NO
			         encoding:NSUTF8StringEncoding
			            error:&error];
		} else if ([types containsObject:NSPasteboardTypePNG]) {
			NSData* data = [pboard dataForType:NSPasteboardTypePNG];
			NSString* fileName =
			    [ALAppDelegate createTimestampPrefixedWith:@"Image"
			                                      endingIn:@".png"];
			tempPath =
			    [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

			[data writeToFile:tempPath options:0 error:&error];
		} else if ([types containsObject:NSPasteboardTypeString]) {
			NSString* text = [pboard stringForType:NSPasteboardTypeString];
			NSString* fileName =
			    [ALAppDelegate createTimestampPrefixedWith:@"Paste"
			                                      endingIn:@".txt"];
			tempPath =
			    [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

			[text writeToFile:tempPath
			       atomically:NO
			         encoding:NSUTF8StringEncoding
			            error:&error];
		} else if ([types containsObject:NSPasteboardTypeTIFF]) {
			NSLog(@"yeah");
			NSData* data = [pboard dataForType:NSPasteboardTypeTIFF];
			CGImageRef image = [[NSBitmapImageRep imageRepWithData:data] CGImage];
			NSString* fileName =
			    [ALAppDelegate createTimestampPrefixedWith:@"Image"
			                                      endingIn:@".png"];
			tempPath =
			    [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

			fileURL = [NSURL fileURLWithPath:tempPath];

			CGImageDestinationRef dst = CGImageDestinationCreateWithURL(
			    (__bridge CFURLRef)fileURL, (CFStringRef) @"public.png", 0, NULL);
			CGImageDestinationAddImage(dst, image, NULL);
			CGImageDestinationFinalize(dst);
		} else {
			return;
		}

		if (error != nil) {
			NSString* subtitle =
			    [NSString stringWithFormat:@"Couldn't buffer paste: %@", error];
			[[ALAppDelegate sharedAppDelegate]
			    showNotificationOfType:ALNotificationUploadAborted
			                     title:@"Error uploading paste"
			                  subtitle:subtitle
			            additionalInfo:nil];
			return;
		}

		shouldDelete = YES;
		if (fileURL == nil) {
			fileURL = [NSURL fileURLWithPath:tempPath];
		}
	}

	ALUploadManager* upload =
	    [[ALUploadManager alloc] initWithFileURL:fileURL
	                      deletingFileAfterwards:shouldDelete];
	[[[ALAppDelegate sharedAppDelegate] dropZone] setCurrentUpload:upload];
	[upload doUpload];
}

+ (NSString*)createTimestampPrefixedWith:(NSString*)prefix
                                endingIn:(NSString*)extension {
	NSString* format = @"%Y-%m-%d at %H.%M.%S";
	NSDictionary* locale =
	    [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
	NSString* stamp = [[NSDate date] descriptionWithCalendarFormat:format
	                                                      timeZone:nil
	                                                        locale:locale];

	return [NSString stringWithFormat:@"%@ %@%@", prefix, stamp, extension];
}

@end
