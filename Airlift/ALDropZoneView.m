// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALDropZoneView.h"
#import "ALAppDelegate.h"

@interface ALDropZoneView () {
	NSStatusItem* statusItem;
	int status;
	CGFloat progress;
}

@end

@implementation ALDropZoneView

@synthesize currentUpload, menu;

static NSImage* StatusIcon;
static NSImage* StatusIconDrag;
static NSImage* StatusIconSelected;
static NSImage* StatusIconUploading;

static NSMenuItem* emptyUploadHistoryItem;

- (id)initWithFrame:(NSRect)frameRect {
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
		[self setHistoryItems:nil];

		statusItem = item;
		[statusItem setView:self];
		//[statusItem setMenu:menu];

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

	if (_status == ALDropZoneStatusUploading) {
		[[ALAppDelegate sharedAppDelegate] setIsBusyUploading:YES];
	}
}

- (void)removeStatus:(ALDropZoneStatus)_status {
	status &= ~_status;
	[self setNeedsDisplay:YES];

	if (_status == ALDropZoneStatusUploading) {
		[[ALAppDelegate sharedAppDelegate] setIsBusyUploading:NO];
		currentUpload = nil;
	}
}

- (void)mouseDown:(NSEvent*)theEvent {
	if ([self hasStatus:ALDropZoneStatusSelected]) {
		[self removeStatus:ALDropZoneStatusSelected];
	} else {
		[self addStatus:ALDropZoneStatusSelected];
		[statusItem popUpStatusItemMenu:menu];
	}
}

- (void)menuDidClose:(NSMenu*)menu {
	[self removeStatus:ALDropZoneStatusSelected];
}

- (void)setProgress:(CGFloat)_progress {
	progress = _progress;
	[self setNeedsDisplay:YES];
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

- (IBAction)cancelUpload:(id)sender {
	if (currentUpload == nil) {
		NSLog(@"Not cancelling upload because currentUpload is nil");
		return;
	}
	NSLog(@"Cancelling current upload");
	// when the upload object is cancelled, it will trigger its own request
	// completion delegate method, and that will remove the "uploading" status
	// over here, which will set the upload to nil. So we don't have to nil it
	// out here.
	[currentUpload cancel];
}

- (IBAction)oops:(id)sender {
	[ALUploadManager oops];
}

#pragma mark - Drag and drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	if (currentUpload != nil) {
		return NSDragOperationNone;
	}
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
	if (currentUpload != nil) {
		return NO;
	}
	NSPasteboard* pboard = [sender draggingPasteboard];

	if (![[pboard types] containsObject:NSFilenamesPboardType]) {
		return NO;
	}

	[self removeStatus:ALDropZoneStatusDrag];
	NSURL* filePath = [NSURL URLFromPasteboard:pboard];

	currentUpload = [[ALUploadManager alloc] initWithFileURL:filePath
	                                  deletingFileAfterwards:NO];
	[currentUpload doUpload];
	return YES;
}

@end
