// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALUploadManager.h"
#import "ALAppDelegate.h"

@interface ALUploadManager () {
	NSMutableData* receivedData;
	int responseCode;
	ALAppDelegate* appDelegate;
}

@end

@implementation ALUploadManager

- (id)init {
	self = [super init];
	if (self != nil) {
		appDelegate = [ALAppDelegate sharedAppDelegate];
	}
	return self;
}

+ (NSMutableURLRequest*)constructRequestToPath:(NSString*)path {
	ALAppDelegate* appDelegate = [ALAppDelegate sharedAppDelegate];
	NSString* host =
	    [[NSUserDefaults standardUserDefaults] stringForKey:@"host"];

	if ([host length] == 0) {
		[appDelegate showNotificationOfType:ALNotificationParameterError
		                              title:@"Error"
		                           subtitle:@"A host has not been configured"
		                     additionalInfo:nil];
		return nil;
	}

	NSString* port =
	    [[NSUserDefaults standardUserDefaults] stringForKey:@"port"];
	NSString* hostPort = [NSString stringWithFormat:@"%@:%@", host, port];
	NSString* password =
	    [ALPreferenceViewController retrievePasswordForHost:host];

	if ([password length] == 0) {
		[appDelegate showNotificationOfType:ALNotificationParameterError
		                              title:@"Error"
		                           subtitle:@"A password has not been set for "
		                                    @"the configured host"
		                     additionalInfo:nil];
		return nil;
	}

	NSURL* requestURL =
	    [[NSURL URLWithString:hostPort] URLByAppendingPathComponent:path];
	NSMutableURLRequest* request =
	    [NSMutableURLRequest requestWithURL:requestURL];

	[request setHTTPMethod:@"POST"];
	[request setValue:password forHTTPHeaderField:@"X-Airlift-Password"];

	return request;
}

+ (void)deleteUploadAtURL:(NSString*)urlToDelete {
	NSString* hash = [urlToDelete lastPathComponent];
	NSMutableURLRequest* request =
	    [ALUploadManager constructRequestToPath:[@"/" stringByAppendingString:hash]];
	if (request == nil) {
		return;
	}
	[request setHTTPMethod:@"DELETE"];

	void (^completionHandler)(NSData*, NSURLResponse*, NSError*);

	completionHandler = ^(NSData* data, NSURLResponse* response, NSError* error) {
		NSString* title;
		NSString* subtitle;
		ALNotificationType notificationType = ALNotificationUploadError;

		if (error != nil) {
			title =
			    [NSString stringWithFormat:@"Failed to delete %@", urlToDelete];
			subtitle =
			    [NSString stringWithFormat:@"Error performing request: %@", error];
		} else {
			NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;

			if ([httpResponse statusCode] == 204) {
				title = [NSString stringWithFormat:@"Deleted %@", urlToDelete];
				notificationType = ALNotificationOK;
			} else {
				title =
				    [NSString stringWithFormat:@"Failed to delete %@", urlToDelete];

				error = nil;
				NSDictionary* jsonResponse =
				    [NSJSONSerialization JSONObjectWithData:data
				                                    options:0
				                                      error:&error];
				if (error != nil) {
					subtitle = [NSString
					    stringWithFormat:@"Failed to parse server response "
					                     @"(server returned status: %ld)",
					                     [httpResponse statusCode]];
				} else {
					subtitle = [NSString
					    stringWithFormat:@"Server returned error: %@",
					                     [jsonResponse objectForKey:@"Err"]];
				}
			}
		}

		[[ALAppDelegate sharedAppDelegate] showNotificationOfType:notificationType
		                                                    title:title
		                                                 subtitle:subtitle
		                                           additionalInfo:nil];
	};

	NSURLSessionDataTask* task =
	    [[NSURLSession sharedSession] dataTaskWithRequest:request
	                                    completionHandler:completionHandler];
	[task resume];
}

- (void)uploadFileAtPath:(NSURL*)path {
	NSMutableURLRequest* request =
	    [ALUploadManager constructRequestToPath:@"/upload/file"];

	if (request == nil) {
		return;
	}

	NSString* fileName = [[path path] lastPathComponent];
	[request setValue:fileName forHTTPHeaderField:@"X-Airlift-Filename"];

	NSURLSession* session = [NSURLSession sessionWithConfiguration:nil
	                                                      delegate:self
	                                                 delegateQueue:nil];
	NSURLSessionUploadTask* upload =
	    [session uploadTaskWithRequest:request fromFile:path];

	[upload resume];
}

- (void)presentURL:(NSDictionary*)jsonResponse
    withOriginalURL:(NSURL*)originalURL {
	NSString* linkableURL =
	    [NSString stringWithFormat:@"%@://%@", [originalURL scheme],
	                               [jsonResponse valueForKey:@"URL"]];

	NSString* errMsg = copyString(linkableURL);
	if (errMsg != nil) {
		NSString* subtitle =
		    [NSString stringWithFormat:@"The upload worked, but couldn't copy "
		                               @"the URL to clipboard: %@",
		                               errMsg];
		[appDelegate
		    showNotificationOfType:ALNotificationUploadError
		                     title:[NSString
		                               stringWithFormat:@"Error copying %@", linkableURL]
		                  subtitle:subtitle
		            additionalInfo:nil];
	} else {
		NSDictionary* info =
		    [NSDictionary dictionaryWithObject:linkableURL forKey:@"url"];
		[appDelegate
		    showNotificationOfType:ALNotificationURLCopied
		                     title:[linkableURL
		                               stringByAppendingString:@" copied"]
		                  subtitle:@"Click this notification to delete it"
		            additionalInfo:info];
	}
}

NSString* copyString(NSString* str) {
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

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession*)session
                        task:(NSURLSessionTask*)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {

	CGFloat progress = (CGFloat)totalBytesSent
	                   / (CGFloat)totalBytesExpectedToSend;
	[[appDelegate dropZone] setProgress:progress];
}

- (void)URLSession:(NSURLSession*)session
                    task:(NSURLSessionTask*)task
    didCompleteWithError:(NSError*)error {

	[[appDelegate dropZone] setStatus:ALDropZoneStatusNormal];

	if (error != nil) {
		[appDelegate showNotificationOfType:ALNotificationUploadError
		                              title:@"Error uploading"
		                           subtitle:[error description]
		                     additionalInfo:nil];
		return;
	}

	NSDictionary* jsonResponse =
	    [NSJSONSerialization JSONObjectWithData:receivedData
	                                    options:0
	                                      error:&error];
	if (error != nil) {
		NSString* subtitle = [NSString
		    stringWithFormat:@"Failed to decode server response (status %d)",
		                     responseCode];
		[appDelegate showNotificationOfType:ALNotificationUploadError
		                              title:@"Error uploading"
		                           subtitle:subtitle
		                     additionalInfo:nil];
		NSLog(@"Failed to decode server response: %@", error);
		return;
	}

	if (responseCode != 201) {
		NSString* subtitle = [NSString
		    stringWithFormat:@"server returned error: %@ (status %d)",
		                     [jsonResponse valueForKey:@"Err"], responseCode];
		[appDelegate showNotificationOfType:ALNotificationUploadError
		                              title:@"Error uploading"
		                           subtitle:subtitle
		                     additionalInfo:nil];
		return;
	}

	[self presentURL:jsonResponse withOriginalURL:[[task originalRequest] URL]];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession*)session
              dataTask:(NSURLSessionDataTask*)dataTask
    didReceiveResponse:(NSURLResponse*)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {

	NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
	responseCode = (int)[httpResponse statusCode];
	completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession*)session
          dataTask:(NSURLSessionDataTask*)dataTask
    didReceiveData:(NSData*)data {

	if (receivedData == nil) {
		receivedData = [[NSMutableData alloc] init];
	}
	[receivedData appendData:data];
}

@end
