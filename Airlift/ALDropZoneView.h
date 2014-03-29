// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Cocoa/Cocoa.h>

@interface ALDropZoneView : NSView <NSMenuDelegate, NSDraggingDestination>

- (id)initWithMenu:(NSMenu*)menu;

- (void)addStatus:(ALDropZoneStatus)status;
- (BOOL)hasStatus:(ALDropZoneStatus)status;
- (void)removeStatus:(ALDropZoneStatus)status;

- (void)setProgress:(CGFloat)progress;

@end
