// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Cocoa/Cocoa.h>
#import "ALUploadManager.h"
#import "ALUploadHistoryItem.h"

@interface ALDropZoneView : NSView <NSMenuDelegate, NSDraggingDestination>

@property (retain) ALUploadManager* currentUpload;

- (id)initWithMenu:(NSMenu*)menu;

- (void)addStatus:(ALDropZoneStatus)status;
- (BOOL)hasStatus:(ALDropZoneStatus)status;
- (void)removeStatus:(ALDropZoneStatus)status;
- (void)setHistoryItems:(NSArray*)historyItems;

- (void)setProgress:(CGFloat)progress;

@end
