// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALUploadManager.h"

@interface ALUploadManager () {
	NSURL* uploadURL;
	NSString* password;
	NSMutableData* receivedData;
	int responseCode;
}

@end

@implementation ALUploadManager

- (id) init {
	self = [super init];
	if (self != nil) {
		NSString* host = [[NSUserDefaults standardUserDefaults] stringForKey:@"host"];
		uploadURL      = [[NSURL URLWithString:host] URLByAppendingPathComponent:@"/upload/file"];
		password       = [ALPreferenceViewController retrievePasswordForHost:host];
	}
	return self;
}

- (void) uploadFileAtPath:(NSURL*)path {
	if (uploadURL == nil) {
		NSLog(@"Empty host");
		return;
	}
	if (password == nil || [password length] == 0) {
		NSLog(@"Empty password");
		return;
	}
	
	NSString*            fileName  = [[path path] lastPathComponent];
	NSMutableURLRequest* request   = [NSMutableURLRequest requestWithURL:uploadURL];
	
	//	[request setHTTPBodyStream:fileStream];
	[request setHTTPMethod:@"POST"];
	[request setValue:password forHTTPHeaderField:@"X-Airlift-Password"];
	[request setValue:fileName forHTTPHeaderField:@"X-Airlift-Filename"];
		
	NSURLSession*           session = [NSURLSession sessionWithConfiguration:nil delegate:self delegateQueue:nil];
	NSURLSessionUploadTask* upload  = [session uploadTaskWithRequest:request fromFile:path];
	
	[upload resume];
}

- (void) presentURL:(NSDictionary*)jsonResponse {
	NSString* linkableURL = [NSString stringWithFormat:@"%@://%@", [uploadURL scheme], [jsonResponse valueForKey:@"URL"]];
	NSLog(@"got URL: %@", linkableURL);
	
	NSUserNotification* notification = [[NSUserNotification alloc] init];
	
	NSString* errMsg = copyString(linkableURL);
	if (errMsg != nil) {
		[notification setTitle:@"Error"];
		[notification setSubtitle:errMsg];
	} else {
		[notification setTitle:linkableURL];
		[notification setSubtitle:@"URL copied to clipboard"];
	}

	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

NSString* copyString(NSString* str) {
    NSPasteboard* pboard = [NSPasteboard generalPasteboard];
	
    if (pboard == nil) {
        return @"Failed to get handle on pasteboard";
    }
	
    [pboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
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

#pragma mark - NSURLSessionTaskDelegate

- (void) URLSession:(NSURLSession *)session
			   task:(NSURLSessionTask *)task
	didSendBodyData:(int64_t)bytesSent
	 totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
	
	NSLog(@"Progress: %d%%", (int)roundf(100 * ((float)totalBytesSent / (float)totalBytesExpectedToSend)));
}

- (void) URLSession:(NSURLSession *)session
			   task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
	if (error != nil) {
		NSLog(@"Finished with error: %@", error);
		return;
	}
	
	NSDictionary* jsonResponse = [NSJSONSerialization JSONObjectWithData:receivedData options:0 error:&error];
	if (error != nil) {
		NSLog(@"error parsing json: %@", error);
		return;
	}
	
	if (responseCode != 201) {
		NSLog(@"server returned error: %@ (status %d)", [jsonResponse valueForKey:@"Err"], responseCode);
		return;
	}
	
	[self presentURL:jsonResponse];
}

#pragma mark - NSURLSessionDataDelegate

- (void) URLSession:(NSURLSession *)session
		   dataTask:(NSURLSessionDataTask *)dataTask
 didReceiveResponse:(NSURLResponse *)response
  completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
	
	NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
	responseCode = (int)[httpResponse statusCode];
	NSLog(@"response: %d", responseCode);
	completionHandler(NSURLSessionResponseAllow);
}

- (void) URLSession:(NSURLSession *)session
		   dataTask:(NSURLSessionDataTask *)dataTask
	 didReceiveData:(NSData *)data {
	
	if (receivedData == nil) {
		receivedData = [[NSMutableData alloc] init];
	}
	[receivedData appendData:data];
}

@end
