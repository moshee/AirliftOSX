// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALUploadManager.h"
#import "ALAppDelegate.h"

@interface ALUploadManager () {
	NSURLSession* session;
	NSMutableData* receivedData;
	int responseCode;
	ALAppDelegate* appDelegate;

	NSURL* targetFilePath;
	BOOL shouldDeleteFile;

	NSMutableURLRequest* request;
	NSURLSessionUploadTask* upload;
}

@end

@implementation ALUploadManager

- (id)initWithFileURL:(NSURL*)fileURL
    deletingFileAfterwards:(BOOL)shouldDelete {

	self = [super init];
	if (self == nil)
		return self;

	appDelegate = [ALAppDelegate sharedAppDelegate];
	request = [ALUploadManager constructRequestToPath:ALEndpointUploadFile];
	session = [NSURLSession sessionWithConfiguration:nil
	                                        delegate:self
	                                   delegateQueue:nil];

	shouldDeleteFile = shouldDelete;
	targetFilePath = fileURL;

	NSString* fileName = [[targetFilePath lastPathComponent]
	    stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	[request setValue:fileName forHTTPHeaderField:ALRequestHeaderFilename];

	upload = [session uploadTaskWithRequest:request fromFile:targetFilePath];

	return self;
}

+ (NSMutableURLRequest*)constructRequestToPath:(NSString*)path {
	ALAppDelegate* appDelegate = [ALAppDelegate sharedAppDelegate];
	NSString* host = [[appDelegate prefs] configuredHost];

	if ([host length] == 0) {
		[appDelegate showNotificationOfType:ALNotificationParameterError
		                              title:@"Error"
		                           subtitle:@"A host has not been configured"
		                     additionalInfo:nil];
		return nil;
	}

	NSString* password = [[appDelegate prefs] configuredPassword];

	if ([password length] == 0) {
		NSString* subtitle =
		    @"A password has not been set for the configured host";
		[appDelegate showNotificationOfType:ALNotificationParameterError
		                              title:@"Error"
		                           subtitle:subtitle
		                     additionalInfo:nil];
		return nil;
	}

	NSURL* parsedHost = [NSURL URLWithString:host];
	NSString* port =
	    [[NSUserDefaults standardUserDefaults] stringForKey:ALPortKey];

	NSString* hostPort =
	    [NSString stringWithFormat:@"%@://%@:%@%@", [parsedHost scheme],
	                               [parsedHost host], port, [parsedHost path]];

	NSURL* requestURL =
	    [[NSURL URLWithString:hostPort] URLByAppendingPathComponent:path];

	NSLog(@"Trying to send request to %@", requestURL);

	NSMutableURLRequest* request =
	    [NSMutableURLRequest requestWithURL:requestURL];

	[request setHTTPMethod:@"POST"];
	[request setValue:password forHTTPHeaderField:ALRequestHeaderPassword];

	return request;
}

+ (void)deleteUploadAtURL:(NSString*)urlToDelete {
	NSLog(@"Going to delete %@", urlToDelete);

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
		ALNotificationType notificationType = ALNotificationUploadAborted;

		if (error != nil) {
			title =
			    [NSString stringWithFormat:@"Failed to delete %@", urlToDelete];
			subtitle =
			    [NSString stringWithFormat:@"Error performing request: %@", error];
		} else {
			NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
			NSInteger status = [httpResponse statusCode];

			if (status == 204 || status == 200) {
				NSLog(@"Successfully deleted %@", urlToDelete);
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
					NSLog(@"Failed to parse JSON: %@", error);
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

+ (void)oops {
	NSLog(@"Going to delete last file uploaded");

	NSMutableURLRequest* request =
	    [ALUploadManager constructRequestToPath:ALEndpointOops];

	void (^completionHandler)(NSData*, NSURLResponse*, NSError*);

	completionHandler = ^(NSData* data, NSURLResponse* response, NSError* error) {
		NSString* title;
		NSString* subtitle;
		ALNotificationType notificationType = ALNotificationUploadAborted;

		if (error != nil) {
			title = [NSString stringWithFormat:@"Failed to perform oops"];
			subtitle =
			    [NSString stringWithFormat:@"Error performing request: %@", error];
		} else {
			NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
			NSInteger status = [httpResponse statusCode];

			// TODO: simplify logic once server API is more finalized
			// currently, both 204 (no content) and 200 (ok) have to be handled
			// because I just changed the 204 to 200 and return the URL of the
			// deleted file because that's good
			if (status == 204) {
				title = [NSString stringWithFormat:@"Crisis averted"];
				notificationType = ALNotificationOK;
			} else {
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
					if (status == 200) {
						title = [NSString stringWithFormat:@"Crisis averted"];
						subtitle =
						    [NSString
						        stringWithFormat:@"Deleted file at %@",
						                         [jsonResponse objectForKey:@"URL"]];
						notificationType = ALNotificationOK;
					} else {
						title = [NSString
						    stringWithFormat:@"Failed to perform oops"];
						subtitle =
						    [NSString
						        stringWithFormat:@"Server returned error: %@",
						                         [jsonResponse objectForKey:@"Err"]];
					}
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

- (void)doUpload {
	NSLog(@"Going to upload %@", targetFilePath);

	[[appDelegate dropZone] addStatus:ALDropZoneStatusUploading];
	[upload resume];
}

- (void)cancel {
	if (session == nil) {
		return;
	}
	[session invalidateAndCancel];
	[[appDelegate dropZone] removeStatus:ALDropZoneStatusUploading];
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

	[[appDelegate dropZone] removeStatus:ALDropZoneStatusUploading];

	if (error != nil) {
		NSLog(@"Request completed with error: %@", error);
		NSString* title = nil;
		NSString* subtitle = nil;
		if ([error code] == NSURLErrorCancelled) {
			title = @"Upload cancelled";
		} else {
			title = @"Error uploading";
			subtitle = [error description];
		}
		[appDelegate showNotificationOfType:ALNotificationUploadAborted
		                              title:title
		                           subtitle:subtitle
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
		[appDelegate showNotificationOfType:ALNotificationUploadAborted
		                              title:@"Error uploading"
		                           subtitle:subtitle
		                     additionalInfo:nil];
		NSLog(@"Failed to decode server response: %@", error);
		return;
	}

	if (responseCode != 201) {
		NSString* errString = [jsonResponse valueForKey:@"Err"];
		NSString* subtitle =
		    [NSString stringWithFormat:@"server returned error: %@ (status %d)",
		                               errString, responseCode];
		NSLog(@"Server error: %@ (status %d)", errString, responseCode);
		[appDelegate showNotificationOfType:ALNotificationUploadAborted
		                              title:@"Error uploading"
		                           subtitle:subtitle
		                     additionalInfo:nil];
		return;
	}

	NSString* gotURL = [jsonResponse objectForKey:@"URL"];
	NSLog(@"Request successful - got URL: %@", gotURL);

	ALUploadHistoryItem* historyItem = [ALUploadHistoryItem new];
	[historyItem setURL:gotURL];
	[historyItem setOriginalURL:[[upload originalRequest] URL]];
	[historyItem setFilePath:targetFilePath];

	[appDelegate addUploadToHistory:historyItem];
	if (shouldDeleteFile) {
		NSString* filePath = [targetFilePath path];
		[[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
	}
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
