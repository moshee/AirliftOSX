// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#import "ALDropZoneView.h"
#import "ALUploadManager.h"
#import "ALPreferenceViewController.h"

@interface ALAppDelegate
    : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate> {
@private
	IBOutlet ALPreferenceViewController* prefs;
}

@property (assign) IBOutlet NSWindow* window;
@property (readonly) ALDropZoneView* dropZone;

+ (void)uploadScreenshot:(NSArray*)additionalArgs;
+ (ALAppDelegate*)sharedAppDelegate;

- (void)didClickPreferences:(id)sender;
- (void)showNotificationOfType:(ALNotificationType)notificationType
                         title:(NSString*)title
                      subtitle:(NSString*)subtitle
                additionalInfo:(NSDictionary*)info;

enum HotkeyAction { HotkeyTakeScreenshot = 0, HotkeyTakeFullScreenshot };

@end
