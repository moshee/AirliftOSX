// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALDropZoneView.h"

@interface ALDropZoneView () {
	NSStatusItem* statusItem;
	NSPopover* popover;
	int status;
	id popoverTransiencyMonitor;
	CGFloat progress;
}

@end

@implementation ALDropZoneView

static NSImage* StatusIcon;
static NSImage* StatusIconDrag;
static NSImage* StatusIconSelected;
static NSImage* StatusIconUploading;

- (id)initWithMenu:(NSMenu*)menu {
	NSStatusItem* item =
	    [[NSStatusBar systemStatusBar] statusItemWithLength:24.0];
	CGFloat itemWidth = [item length];
	CGFloat itemHeight = [[NSStatusBar systemStatusBar] thickness];
	NSRect itemRect = NSMakeRect(0.0, 0.0, itemWidth, itemHeight);
	self = [super initWithFrame:itemRect];

	if (StatusIcon == nil) {
		StatusIcon = [NSImage imageNamed:@"StatusIcon"];
		StatusIconDrag = [NSImage imageNamed:@"StatusIconDrag"];
		StatusIconSelected = [NSImage imageNamed:@"StatusIconSelected"];
		StatusIconUploading = [NSImage imageNamed:@"StatusIconUploading"];
	}

	if (self) {
		statusItem = item;
		[statusItem setView:self];
		[menu setDelegate:self];
		[self setMenu:menu];
		status = ALDropZoneStatusNormal;
		progress = 0.0;
		[self registerForDraggedTypes:@[NSFilenamesPboardType]];
	}

	return self;
}

#pragma mark - UI

- (void)drawRect:(NSRect)dirtyRect {
	[statusItem drawStatusBarBackgroundInRect:dirtyRect
	                            withHighlight:(status == ALDropZoneStatusSelected)];

	NSImage* statusIcon;
	switch (status) {
	case ALDropZoneStatusNormal:
		statusIcon = StatusIcon;
		break;
	case ALDropZoneStatusDrag:
		statusIcon = StatusIconDrag;
		break;
	case ALDropZoneStatusSelected:
		statusIcon = StatusIconSelected;
		break;
	case ALDropZoneStatusUploading:
		statusIcon = StatusIconUploading;
		break;
	}

	NSSize iconSize = statusIcon.size;
	NSRect bounds = self.bounds;
	CGFloat iconX = roundf((NSWidth(bounds) - iconSize.width) / 2);
	CGFloat iconY = roundf((NSHeight(bounds) - iconSize.height) / 2);
	NSPoint iconPoint = NSMakePoint(iconX, iconY);

	[statusIcon drawAtPoint:iconPoint
	               fromRect:NSZeroRect
	              operation:NSCompositeSourceOver
	               fraction:1.0];

	if (status == ALDropZoneStatusUploading) {
		iconSize = [StatusIcon size];
		CGFloat p = progress * iconSize.height;
		NSRect mask = NSMakeRect(0, 0, iconSize.width, p);

		[StatusIcon drawAtPoint:iconPoint
		               fromRect:mask
		              operation:NSCompositeDestinationAtop
		               fraction:1.0];
	}
}

- (void)setStatus:(ALDropZoneStatus)_status {
	status = _status;
	[self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent*)theEvent {
	if (status == ALDropZoneStatusNormal) {
		[self setStatus:ALDropZoneStatusSelected];
	} else {
		[self setStatus:ALDropZoneStatusNormal];
	}

	if (status == ALDropZoneStatusSelected) {
		[statusItem popUpStatusItemMenu:[self menu]];
	}
}

- (void)menuDidClose:(NSMenu*)menu {
	[self setStatus:ALDropZoneStatusNormal];
}

#pragma mark - Uploading

- (void)setProgress:(CGFloat)_progress {
	progress = _progress;
	[self setNeedsDisplay:YES];
}

#pragma mark - Drag and drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	[self setStatus:ALDropZoneStatusDrag];
	return NSDragOperationCopy;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
	[self setStatus:ALDropZoneStatusNormal];
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
	return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	[self setStatus:ALDropZoneStatusNormal];
	NSURL* filePath = [NSURL URLFromPasteboard:[sender draggingPasteboard]];

	if (filePath == nil) {
		return NO;
	}

	[self setStatus:ALDropZoneStatusUploading];
	[[ALUploadManager new] uploadFileAtPath:filePath];

	return YES;
}

@end
