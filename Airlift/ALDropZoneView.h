// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Cocoa/Cocoa.h>
#import "ALUploadManager.h"

@interface ALDropZoneView : NSView <NSMenuDelegate, NSDraggingDestination>

//- (id) initWithViewController:(NSViewController*)controller;
- (id) initWithMenu:(NSMenu*)menu;

//- (void) showPopover;
//- (void) hidePopover;
- (void) setProgress:(float)progress;

enum IconStatus {
	StatusNormal = 0,
	StatusDrag,
	StatusSelected,
	StatusUploading
};

@end
