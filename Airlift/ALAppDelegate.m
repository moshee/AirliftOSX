// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALAppDelegate.h"

@interface ALAppDelegate () {
  NSMenu *menu;
}

@end

@implementation ALAppDelegate

@synthesize dropZone = _dropZone;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  prefs = [[ALPreferenceViewController alloc]
      initWithNibName:@"ALPreferenceViewController"
               bundle:nil];
  // dropZone = [[ALDropZoneView alloc] initWithViewController:prefs];

  menu = [[NSMenu alloc] init];
  [menu addItemWithTitle:@"Preferences..."
                  action:@selector(didClickPreferences:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@""];

  _dropZone = [[ALDropZoneView alloc] initWithMenu:menu];

  [_window setContentSize:[[prefs view] frame].size];
  [_window setContentView:[prefs view]];
  [_window setReleasedWhenClosed:NO];
  [_window center];
  [_window setTitle:@"Connection details"];
  [_window setLevel:NSFloatingWindowLevel];

  EventHotKeyRef hotKeyRef;
  EventHotKeyID hotKeyID;
  EventTypeSpec eventType;

  eventType.eventClass = kEventClassKeyboard;
  eventType.eventKind = kEventHotKeyPressed;
  InstallApplicationEventHandler(&handleHotkey, 1, &eventType, NULL, NULL);

  hotKeyID.signature = 'shot';
  hotKeyID.id = HotkeyTakeScreenshot;
  RegisterEventHotKey(kVK_ANSI_4, optionKey + shiftKey, hotKeyID,
                      GetApplicationEventTarget(), 0, &hotKeyRef);

  hotKeyID.signature = 'SHOT';
  hotKeyID.id = HotkeyTakeFullScreenshot;
  RegisterEventHotKey(kVK_ANSI_3, optionKey + shiftKey, hotKeyID,
                      GetApplicationEventTarget(), 0, &hotKeyRef);

  [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
}

+ (ALAppDelegate *)sharedAppDelegate {
  return (ALAppDelegate *)[[NSApplication sharedApplication] delegate];
}

- (void)didClickPreferences:(id)sender {
  [NSApp activateIgnoringOtherApps:YES];
  [_window makeKeyAndOrderFront:nil];
}

- (void)quit:(id)sender {
  [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

- (void)showNotificationOfType:(ALNotificationType)notificationType
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                additionalInfo:(NSDictionary *)info {

  NSUserNotification *notification = [[NSUserNotification alloc] init];
  NSMutableDictionary *userInfo =
      [NSMutableDictionary dictionaryWithDictionary:info];
  [userInfo setObject:[NSNumber numberWithInteger:notificationType]
               forKey:@"type"];

  [notification setUserInfo:userInfo];
  [notification setTitle:title];
  [notification setSubtitle:subtitle];

  [[NSUserNotificationCenter defaultUserNotificationCenter]
      deliverNotification:notification];
}

#pragma mark - NSUserNotificationCenterDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter *)center
       didActivateNotification:(NSUserNotification *)notification {

  ALNotificationType notificationType =
      [[[notification userInfo] valueForKey:@"type"] intValue];

  switch (notificationType) {
  case ALNotificationURLCopied:
    [ALUploadManager
        deleteUploadAtURL:[[notification userInfo] objectForKey:@"url"]];
    break;
  case ALNotificationOK:
  case ALNotificationUploadError:
    break;
  case ALNotificationParameterError:
    [[ALAppDelegate sharedAppDelegate] didClickPreferences:self];
    break;
  }
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification {
  return YES;
}

#pragma mark - Hotkey handling

+ (void)uploadScreenshot:(NSArray *)additionalArgs {
  NSString *fileName = [[NSDate date]
      descriptionWithCalendarFormat:@"Screenshot %Y-%m-%d at %H.%M.%S.png"
                           timeZone:nil
                             locale:
                                 [[NSUserDefaults
                                         standardUserDefaults] dictionaryRepresentation]];
  NSString *tempFilePath =
      [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

  NSArray *screencaptureArgs;
  if (additionalArgs == nil) {
    screencaptureArgs = @[ tempFilePath ];
  } else {
    screencaptureArgs = [additionalArgs arrayByAddingObject:tempFilePath];
  }

  NSTask *screencaptureTask =
      [NSTask launchedTaskWithLaunchPath:@"/usr/sbin/screencapture"
                               arguments:screencaptureArgs];
  [screencaptureTask waitUntilExit];

  if (![[NSFileManager defaultManager] fileExistsAtPath:tempFilePath]) {
    return;
  }

  [[ALUploadManager new] uploadFileAtPath:[NSURL fileURLWithPath:tempFilePath]];
}

OSStatus handleHotkey(EventHandlerCallRef nextHandler, EventRef anEvent,
                      void *userData) {
  EventHotKeyID hotKeyID;
  GetEventParameter(anEvent, kEventParamDirectObject, typeEventHotKeyID, NULL,
                    sizeof(hotKeyID), NULL, &hotKeyID);

  switch (hotKeyID.id) {
  case HotkeyTakeScreenshot:
    [ALAppDelegate uploadScreenshot:@[ @"-i" ]];
    break;
  case HotkeyTakeFullScreenshot:
    [ALAppDelegate uploadScreenshot:nil];
    break;
  }

  return noErr;
}

@end
