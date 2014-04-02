// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALUploadHistoryItem.h"
#import "ALAppDelegate.h"
#import "ALUploadManager.h"

@implementation ALUploadHistoryItem

@synthesize URL, filePath, originalURL;

- (void)deleteUpload {
	[ALUploadManager deleteUploadAtURL:URL];
	[[ALAppDelegate sharedAppDelegate] removeUploadFromHistory:self];
}

- (NSString*)constructLinkableURL {
	NSString* url = URL;

	if ([[NSUserDefaults standardUserDefaults] boolForKey:ALShouldAppendExtensionKey]) {
		NSString* ext = [[filePath path] pathExtension];
		url = [url stringByAppendingPathExtension:ext];
	}

	NSString* scheme = [originalURL scheme];
	int port = [[originalURL port] intValue];

	NSString* linkableURL = [NSString stringWithFormat:@"%@://%@", scheme, url];
	BOOL shouldInsertPort =
	    [[NSUserDefaults standardUserDefaults] boolForKey:ALShouldInsertPortKey];

	if (shouldInsertPort
	    && !(([scheme isEqualToString:@"http"] && port == 80)
	         || ([scheme isEqualToString:@"https"] && port == 443))) {
		NSLog(@"got a nonstandard port %d, gonna try to wedge it into the link",
		      port);
		NSURL* parsedURL = [NSURL URLWithString:linkableURL];
		linkableURL =
		    [NSString stringWithFormat:@"%@://%@:%d%@", scheme,
		                               [parsedURL host], port, [parsedURL path]];
	}

	return linkableURL;
}

- (void)copyLink {
	NSString* linkableURL = [self constructLinkableURL];

	NSString* errMsg = [self copyString:linkableURL];
	if (errMsg != nil) {
		NSString* subtitle =
		    [NSString stringWithFormat:@"The upload worked, but couldn't copy "
		                               @"the URL to clipboard: %@",
		                               errMsg];
		[[ALAppDelegate sharedAppDelegate]
		    showNotificationOfType:ALNotificationUploadAborted
		                     title:[NSString
		                               stringWithFormat:@"Error copying %@", linkableURL]
		                  subtitle:subtitle
		            additionalInfo:nil];
	} else {
		NSDictionary* info =
		    [NSDictionary dictionaryWithObject:linkableURL forKey:@"url"];
		[[ALAppDelegate sharedAppDelegate]
		    showNotificationOfType:ALNotificationURLCopied
		                     title:linkableURL
		                  subtitle:@"URL copied to clipboard"
		            additionalInfo:info];
	}
}

- (NSString*)copyString:(NSString*)str {
	NSPasteboard* pboard = [NSPasteboard generalPasteboard];

	if (pboard == nil) {
		return @"Failed to get handle on pasteboard";
	}

	[pboard declareTypes:@[NSPasteboardTypeString] owner:nil];
	[pboard clearContents];

	NSString* msg;

	@try {
		if (![pboard writeObjects:[NSArray arrayWithObject:str]]) {
			msg = @"Pasteboard ownership changed";
		}
	}
	@catch (NSException* e) {
		msg = [NSString stringWithFormat:@"%@: %@", e.name, e.reason];
	}
	return msg;
}

- (void)visitLink {
	NSString* linkableURL = [self constructLinkableURL];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:linkableURL]];
}

- (NSMenuItem*)menuItem {
	if (menuItem != nil) {
		return menuItem;
	}

	menuItem = [NSMenuItem new];
	NSString* title = [filePath lastPathComponent];
	[menuItem setTitle:title];

	NSMenuItem* visitLinkItem =
	    [[NSMenuItem alloc] initWithTitle:@"Open in Browser"
	                               action:@selector(visitLink)
	                        keyEquivalent:@""];
	[visitLinkItem setTarget:self];

	NSMenuItem* copyItem = [[NSMenuItem alloc] initWithTitle:@"Copy Link"
	                                                  action:@selector(copyLink)
	                                           keyEquivalent:@""];
	[copyItem setTarget:self];

	NSMenuItem* deleteItem =
	    [[NSMenuItem alloc] initWithTitle:@"Delete Upload"
	                               action:@selector(deleteUpload)
	                        keyEquivalent:@""];
	[deleteItem setTarget:self];

	NSMenu* submenu = [NSMenu new];
	[submenu addItem:copyItem];
	[submenu addItem:visitLinkItem];
	[submenu addItem:deleteItem];
	[menuItem setSubmenu:submenu];

	return menuItem;
}

@end
