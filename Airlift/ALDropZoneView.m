// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALDropZoneView.h"
#import "ALAppDelegate.h"

@interface ALDropZoneView () {
	NSStatusItem* statusItem;
	int status;
	CGFloat progress;
	NSMenuItem* progressMenuItem;
	NSMenuItem* cancelUploadMenuItem;
	NSMenuItem* oopsMenuItem;
	NSMenu* uploadHistoryMenu;
}

@end

@implementation ALDropZoneView

@synthesize currentUpload = _currentUpload;

static NSImage* StatusIcon;
static NSImage* StatusIconDrag;
static NSImage* StatusIconSelected;
static NSImage* StatusIconUploading;

static NSMenuItem* emptyUploadHistoryItem;

- (id)initWithMenu:(NSMenu*)menu {
	NSStatusItem* item =
	    [[NSStatusBar systemStatusBar] statusItemWithLength:28.0];
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

	if (emptyUploadHistoryItem == nil) {
		emptyUploadHistoryItem = [NSMenuItem new];
		[emptyUploadHistoryItem setTitle:@"(No uploads)"];
		[emptyUploadHistoryItem setEnabled:NO];
	}

	if (self) {
		progressMenuItem = [NSMenuItem new];
		[progressMenuItem setTitle:@"Uploading..."];
		[progressMenuItem setEnabled:NO];
		[progressMenuItem setHidden:YES];
		[menu insertItem:progressMenuItem atIndex:0];

		cancelUploadMenuItem =
		    [[NSMenuItem alloc] initWithTitle:@"Cancel upload"
		                               action:@selector(cancelUpload:)
		                        keyEquivalent:@""];
		[cancelUploadMenuItem setTarget:self];
		[cancelUploadMenuItem setHidden:YES];
		[menu insertItem:cancelUploadMenuItem atIndex:1];

		oopsMenuItem = [[NSMenuItem alloc] initWithTitle:@"Delete last upload"
		                                          action:@selector(oops:)
		                                   keyEquivalent:@""];
		[oopsMenuItem setTarget:self];
		[oopsMenuItem setToolTip:@"In a crisis, you can click this to quickly "
		              @"delete the last file uploaded."];

		[menu insertItem:oopsMenuItem atIndex:2];

		NSMenuItem* uploadHistoryMenuItem = [NSMenuItem new];
		[uploadHistoryMenuItem setTitle:@"Past uploads"];

		uploadHistoryMenu = [NSMenu new];
		[self setHistoryItems:nil];
		[uploadHistoryMenuItem setSubmenu:uploadHistoryMenu];
		[menu insertItem:uploadHistoryMenuItem atIndex:3];

		[menu insertItem:[NSMenuItem separatorItem] atIndex:4];

		statusItem = item;
		[statusItem setView:self];
		[menu setDelegate:self];
		[statusItem setMenu:menu];

		status = ALDropZoneStatusNormal;
		progress = 0.0;

		[self registerForDraggedTypes:@[NSFilenamesPboardType]];
	}

	return self;
}

#pragma mark - UI

- (void)drawRect:(NSRect)dirtyRect {
	[statusItem
	    drawStatusBarBackgroundInRect:dirtyRect
	                    withHighlight:([self hasStatus:ALDropZoneStatusSelected])];

	NSImage* statusIcon;

	if (status == ALDropZoneStatusNormal) {
		statusIcon = StatusIcon;
	} else {
		if ([self hasStatus:ALDropZoneStatusUploading]) {
			statusIcon = StatusIconUploading;
		} else if ([self hasStatus:ALDropZoneStatusSelected]) {
			statusIcon = StatusIconSelected;
		} else if ([self hasStatus:ALDropZoneStatusDrag]) {
			statusIcon = StatusIconDrag;
		}
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

	if ([self hasStatus:ALDropZoneStatusUploading]) {
		NSImage* overlayIcon;

		// For some reason, NSCompositeDestinationAtop doesn't work when using
		// the selected icon state. Even though it's still transparent in all
		// the same places. Possibly because it's white? Racist.
		// Anyways, we have to invert the operation when drawing that.
		NSCompositingOperation op;

		if ([self hasStatus:ALDropZoneStatusSelected]) {
			overlayIcon = StatusIconSelected;
			op = NSCompositeHighlight;
		} else {
			overlayIcon = StatusIcon;
			op = NSCompositeDestinationAtop;
		}

		iconSize = [overlayIcon size];
		CGFloat p = progress * iconSize.height;
		NSRect mask = NSMakeRect(0, 0, iconSize.width, p);

		[overlayIcon drawAtPoint:iconPoint
		                fromRect:mask
		               operation:op
		                fraction:1.0];
	}
}

- (BOOL)hasStatus:(ALDropZoneStatus)_status {
	return (status & _status) != 0;
}

- (void)addStatus:(ALDropZoneStatus)_status {
	status |= _status;
	[self setNeedsDisplay:YES];
}

- (void)removeStatus:(ALDropZoneStatus)_status {
	status &= ~_status;
	[self setNeedsDisplay:YES];

	if (_status == ALDropZoneStatusUploading) {
		[progressMenuItem setHidden:YES];
		[cancelUploadMenuItem setHidden:YES];
		_currentUpload = nil;
	}
}

- (void)mouseDown:(NSEvent*)theEvent {
	if ([self hasStatus:ALDropZoneStatusSelected]) {
		[self removeStatus:ALDropZoneStatusSelected];
	} else {
		[self addStatus:ALDropZoneStatusSelected];
	}

	if ([self hasStatus:ALDropZoneStatusSelected]) {
		[statusItem popUpStatusItemMenu:[statusItem menu]];
	}
}

- (void)menuDidClose:(NSMenu*)menu {
	[self removeStatus:ALDropZoneStatusSelected];
}

- (void)setProgress:(CGFloat)_progress {
	progress = _progress;
	[self setNeedsDisplay:YES];

	if ([self hasStatus:ALDropZoneStatusUploading]
	        && [progressMenuItem isHidden]) {
		[progressMenuItem setHidden:NO];
		[cancelUploadMenuItem setHidden:NO];
	}
}

- (void)setHistoryItems:(NSArray*)historyItems {
	[uploadHistoryMenu removeAllItems];
	if (historyItems == nil || [historyItems count] == 0) {
		[uploadHistoryMenu addItem:emptyUploadHistoryItem];
		return;
	}

	for (ALUploadHistoryItem* historyItem in historyItems) {
		NSMenuItem* menuItem = [NSMenuItem new];
		NSString* title = [[historyItem filePath] lastPathComponent];
		[menuItem setTitle:title];

		NSMenuItem* copyItem =
		    [[NSMenuItem alloc] initWithTitle:@"Copy link"
		                               action:@selector(copyLink)
		                        keyEquivalent:@""];
		[copyItem setTarget:historyItem];

		NSMenuItem* deleteItem =
		    [[NSMenuItem alloc] initWithTitle:@"Delete upload"
		                               action:@selector(deleteUpload)
		                        keyEquivalent:@""];
		[deleteItem setTarget:historyItem];

		NSMenu* submenu = [NSMenu new];
		[submenu addItem:copyItem];
		[submenu addItem:deleteItem];
		[menuItem setSubmenu:submenu];

		[uploadHistoryMenu addItem:menuItem];
	}
}

#pragma mark - Menu actions

- (void)cancelUpload:(id)sender {
	if (_currentUpload == nil) {
		NSLog(@"Not cancelling upload because currentUpload is nil");
		return;
	}
	NSLog(@"Cancelling current upload");
	[_currentUpload cancel];
}

- (void)oops:(id)sender {
	[ALUploadManager oops];
}

#pragma mark - Drag and drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	[self addStatus:ALDropZoneStatusDrag];
	return NSDragOperationCopy;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
	[self removeStatus:ALDropZoneStatusDrag];
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
	return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	NSPasteboard* pboard = [sender draggingPasteboard];

	if (![[pboard types] containsObject:NSFilenamesPboardType]) {
		return NO;
	}

	[self removeStatus:ALDropZoneStatusDrag];
	NSURL* filePath = [NSURL URLFromPasteboard:pboard];

	_currentUpload = [[ALUploadManager alloc] initWithFileURL:filePath];
	[_currentUpload doUpload];
	return YES;
}

@end
