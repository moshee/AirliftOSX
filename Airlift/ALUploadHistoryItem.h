// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Foundation/Foundation.h>

@interface ALUploadHistoryItem : NSObject

// The originally returned URL, with no scheme or trailing extension.
@property (retain) NSString* URL;
// The local path of the file that was uploaded.
@property (retain) NSURL* filePath;
// The URL that the upload request was originally sent to.
@property (retain) NSURL* originalURL;

- (void)deleteUpload;
- (void)copyLink;

@end
