// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <Sparkle/SUUpdater.h>

#import "ALDropZoneView.h"
#import "ALUploadManager.h"
#import "ALPreferenceViewController.h"
#import "ALUploadHistoryItem.h"

@interface ALAppDelegate
    : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate> {
@private
	IBOutlet ALPreferenceViewController* prefs;
	IBOutlet SUUpdater* updater;
}

@property (assign) IBOutlet NSWindow* window;
@property (assign) IBOutlet ALDropZoneView* dropZone;
@property (assign) BOOL isBusyUploading;

+ (void)uploadScreenshot:(NSArray*)additionalArgs;
+ (ALAppDelegate*)sharedAppDelegate;

- (void)showNotificationOfType:(ALNotificationType)notificationType
                         title:(NSString*)title
                      subtitle:(NSString*)subtitle
                additionalInfo:(NSDictionary*)info;
- (void)addUploadToHistory:(ALUploadHistoryItem*)upload;
- (void)removeUploadFromHistory:(ALUploadHistoryItem*)upload;
- (ALPreferenceViewController*)prefs;

- (IBAction)didClickPreferences:(id)sender;

@end