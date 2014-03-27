// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#import "ALPreferenceViewController.h"
#import "ALDropZoneView.h"
#import "ALUploadManager.h"

@interface ALAppDelegate : NSObject <NSApplicationDelegate, NSPopoverDelegate> {
	@private
	IBOutlet ALPreferenceViewController* prefs;
}

@property (assign) IBOutlet NSWindow *window;

+ (void) uploadScreenshot:(NSArray*)additionalArgs;

- (void) didClickPreferences:(id)sender;

enum HotkeyAction {
	HotkeyTakeScreenshot = 0,
	HotkeyTakeFullScreenshot
};

@end
