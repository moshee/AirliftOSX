// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// The UploadManager class handles all communication to the server.

#import <Foundation/Foundation.h>
#import "ALPreferenceViewController.h"
#import "ALUploadHistoryItem.h"

@interface ALUploadManager
    : NSObject <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

+ (void)deleteUploadAtURL:(NSString*)urlToDelete;
+ (void)oops;

- (id)initWithFileURL:(NSURL*)fileURL deletingFileAfterwards:(BOOL)shouldDelete;

- (void)doUpload;
- (void)cancel;

@end

static NSString* const ALEndpointUploadFile = @"/upload/file";
static NSString* const ALEndpointOops = @"/oops";

static NSString* const ALRequestHeaderFilename = @"X-Airlift-Filename";
static NSString* const ALRequestHeaderPassword = @"X-Airlift-Password";