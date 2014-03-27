// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALDropZoneView.h"

@interface ALDropZoneView () {
	NSStatusItem*    statusItem;
	NSPopover*       popover;
	int              state;
	id               popoverTransiencyMonitor;
}

@end

@implementation ALDropZoneView

/*
- (id) initWithViewController:(NSViewController *)controller {
	statusItem         = [[NSStatusBar systemStatusBar] statusItemWithLength:24.0];
	CGFloat itemWidth  = [statusItem length];
    CGFloat itemHeight = [[NSStatusBar systemStatusBar] thickness];
    NSRect  itemRect   = NSMakeRect(0.0, 0.0, itemWidth, itemHeight);
	self               = [super initWithFrame:itemRect];

	
	if (self) {
		popover                       = [NSPopover new];
		popover.contentViewController = controller;
		popover.behavior              = NSPopoverBehaviorTransient;
		statusItem.view               = self;
	}
	
	return self;
}
 */

- (id) initWithMenu:(NSMenu*)menu {
	NSStatusItem* item       = [[NSStatusBar systemStatusBar] statusItemWithLength:24.0];
	CGFloat       itemWidth  = [item length];
    CGFloat       itemHeight = [[NSStatusBar systemStatusBar] thickness];
    NSRect        itemRect   = NSMakeRect(0.0, 0.0, itemWidth, itemHeight);
	self                     = [super initWithFrame:itemRect];
	
	if (self) {
		statusItem = item;
		[statusItem setView:self];
		[menu setDelegate:self];
		[self setMenu:menu];
		state = StatusNormal;
		[self registerForDraggedTypes:@[NSFilenamesPboardType]];
	}
	
	return self;
}

#pragma mark - UI

- (void)drawRect:(NSRect)dirtyRect {
	[statusItem drawStatusBarBackgroundInRect:dirtyRect
								withHighlight:(state == StatusSelected)];
	
	NSImage* statusIcon;
	switch (state) {
	case StatusNormal:
		statusIcon = [NSImage imageNamed:@"StatusIcon"];
		break;
	case StatusDrag:
		statusIcon = [NSImage imageNamed:@"StatusIconDrag"];
		break;
	case StatusSelected:
		statusIcon = [NSImage imageNamed:@"StatusIconSelected"];
		break;
			//	case StatusUploading:
			//statusIcon = [NSImage imageNamed:@"StatusIconUploading"];
			//break;
	}
	
	NSSize  iconSize  = statusIcon.size;
    NSRect  bounds    = self.bounds;
    CGFloat iconX     = roundf((NSWidth(bounds) - iconSize.width) / 2);
    CGFloat iconY     = roundf((NSHeight(bounds) - iconSize.height) / 2);
    NSPoint iconPoint = NSMakePoint(iconX, iconY);
	
	[statusIcon drawAtPoint:iconPoint
				   fromRect:NSZeroRect
				  operation:NSCompositeSourceOver
				   fraction:1.0];
}

- (void) setState:(int)_state {
	state = _state;
	self.needsDisplay = YES;
}

- (void) mouseDown:(NSEvent *)theEvent {
	/*
	if ([popover isShown]) {
		[self hidePopover];
	} else {
		[self showPopover];
	}
	 */
	if (state == StatusNormal) {
		[self setState:StatusSelected];
	} else {
		[self setState:StatusNormal];
	}
	
	if (state == StatusSelected) {
		[statusItem popUpStatusItemMenu:[self menu]];
	}
}

- (void) menuDidClose:(NSMenu *)menu {
	[self setState:StatusNormal];
}

/*

- (void) hidePopover {
	[popover close];
	if (popoverTransiencyMonitor) {
		[NSEvent removeMonitor:popoverTransiencyMonitor];
		popoverTransiencyMonitor = nil;
	}
}

- (void) showPopover {
	[self setState:StatusSelected];
	
	if (![popover isShown]) {
		[popover showRelativeToRect:[self bounds]
							 ofView:self
					  preferredEdge:NSMinYEdge];

		popoverTransiencyMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSLeftMouseDownMask|NSRightMouseDownMask handler:^(NSEvent* event) {
            [self hidePopover];
        }];
		
		
	}
}

- (void) popoverWillClose:(NSNotification *)notification {
	[self setState:StatusNormal];
}

*/

#pragma mark - Uploading

- (void) setProgress:(float)progress {
	
}

#pragma mark - Drag and drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	[self setState:StatusDrag];
	return NSDragOperationCopy;
}

- (void) draggingExited:(id<NSDraggingInfo>)sender {
	[self setState:StatusNormal];
}

- (BOOL) prepareForDragOperation:(id<NSDraggingInfo>)sender {
	return YES;
}

- (BOOL) performDragOperation:(id<NSDraggingInfo>)sender {
	[self setState:StatusNormal];
	NSURL* filePath = [NSURL URLFromPasteboard:[sender draggingPasteboard]];
	
	if (filePath == nil) {
		return NO;
	}
	
	[[ALUploadManager new] uploadFileAtPath:filePath];
	
	return YES;
}

@end
