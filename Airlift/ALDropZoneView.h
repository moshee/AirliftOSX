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
- (void) setStatus:(ALDropZoneStatus)status;
- (void) setProgress:(CGFloat)progress;


@end
