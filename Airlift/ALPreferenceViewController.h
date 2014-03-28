// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

@interface ALPreferenceViewController : NSViewController {
  IBOutlet NSTextField *hostField;
  IBOutlet NSTextField *portField;
  IBOutlet NSSecureTextField *passwordField;
}

- (IBAction)didEnterHostname:(id)sender;
- (IBAction)didEnterPassword:(id)sender;

+ (void)updatePassword:(NSString *)newPassword forHost:(NSString *)host;
+ (NSString *)retrievePasswordForHost:(NSString *)host;
+ (NSString *)messageForStatusCode:(OSStatus)status;

@end
