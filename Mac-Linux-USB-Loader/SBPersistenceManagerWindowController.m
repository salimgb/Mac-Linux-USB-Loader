//
//  SBPersistenceManagerWindowController.m
//  Mac Linux USB Loader
//
//  Created by SevenBits on 1/22/14.
//  Copyright (c) 2014 SevenBits. All rights reserved.
//

#import "SBPersistenceManagerWindowController.h"
#import "SBAppDelegate.h"
#import "SBUSBDevice.h"

@interface SBPersistenceManagerWindowController ()

@end

@implementation SBPersistenceManagerWindowController {
	NSMutableDictionary *dict;
	NSSavePanel *spanel;
}

- (id)initWithWindow:(NSWindow *)window {
	self = [super initWithWindow:window];
	if (self) {
		// Initialization code here.
	}
	return self;
}

- (void)windowDidLoad {
	[super windowDidLoad];

	// Hide the setup view until we need it.
	[self.persistenceOptionsSetupBox setHidden:YES];
	[self.operationProgressLabel setStringValue:@""];

	// Setup the USB selector.
	dict = [NSMutableDictionary dictionaryWithDictionary:[[NSApp delegate] usbDictionary]];
	NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[dict count]];

	for (NSString *usb in dict) {
		[array insertObject:[dict[usb] name] atIndex:0];
	}

	[self.popupValues addObjects:array];

	[self.usbSelectorPopup addItemWithObjectValue:@"---"];
	[self.usbSelectorPopup setStringValue:@"---"];
	[self.usbSelectorPopup addItemsWithObjectValues:array];
	[self.usbSelectorPopup setDelegate:self];

	// Set up the USB persistence file size selector.
	NSDictionary *bindingOptions = @{ NSContinuouslyUpdatesValueBindingOption : @YES,
		                              NSConditionallySetsEditableBindingOption : @YES };
	[self.persistenceVolumeSizeTextField setDelegate:self];
	[self.persistenceVolumeSizeSlider bind:@"value"
	                              toObject:self.persistenceVolumeSizeTextField
	                           withKeyPath:@"integerValue" options:bindingOptions];
}

- (void)controlTextDidChange:(NSNotification *)note {
	[self.persistenceVolumeSizeSlider setIntegerValue:[self.persistenceVolumeSizeTextField integerValue]];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
	if ([self.usbSelectorPopup indexOfSelectedItem] != 0) {
		[self.persistenceOptionsSetupBox setHidden:NO];
	}
	else {
		[self.persistenceOptionsSetupBox setHidden:YES];
	}
}

- (IBAction)createPersistenceButtonPressed:(id)sender {
	// Disable all buttons.
	[sender setEnabled:NO];
	[self.persistenceVolumeSizeSlider setEnabled:NO];
	[self.persistenceVolumeSizeTextField setEnabled:NO];
	[self.usbSelectorPopup setEnabled:NO];

	NSInteger persistenceSizeInBytes = [self.persistenceVolumeSizeSlider integerValue] / 1048576;

	NSString *selectedUSB = [self.usbSelectorPopup objectValueOfSelectedItem];
	spanel = [NSSavePanel savePanel];
	[spanel setMessage:NSLocalizedString(@"You must authorize file creation on this USB. Click Save below.", nil)];
	[spanel setDirectoryURL:[NSURL URLWithString:[dict[selectedUSB] path]]];
	[spanel setNameFieldStringValue:@"casper-rw"];
	[spanel setCanCreateDirectories:NO];
	[spanel setCanSelectHiddenExtension:NO];
	[spanel setTreatsFilePackagesAsDirectories:NO];
	[spanel beginSheetModalForWindow:self.window completionHandler: ^(NSInteger result) {
	    if (result == NSFileHandlingPanelOKButton) {
	        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	            [self.spinner startAnimation:nil];
	            [self.operationProgressLabel setStringValue:NSLocalizedString(@"Creating persistence file...", nil)];
	            [SBUSBDevice createPersistenceFileAtUSB:[[spanel URL] path] withSize:persistenceSizeInBytes withWindow:self.window];
	            [self.operationProgressLabel setStringValue:NSLocalizedString(@"Creating virtual loopback filesystem...", nil)];
	            [SBUSBDevice createLoopbackPersistence:[[spanel URL] path]];

	            // Enable everything that was disabled.
	            dispatch_async(dispatch_get_main_queue(), ^{
	                [sender setEnabled:YES];
	                [self.persistenceVolumeSizeSlider setEnabled:YES];
	                [self.persistenceVolumeSizeTextField setEnabled:YES];
	                [self.usbSelectorPopup setEnabled:YES];

	                NSAlert *alert = [[NSAlert alloc] init];
	                [alert addButtonWithTitle:NSLocalizedString(@"Okay", nil)];
	                [alert setMessageText:NSLocalizedString(@"Done creating persistence.", nil)];
	                [alert setInformativeText:NSLocalizedString(@"The persistence file has been created. You should be able to boot your selected Linux distribution with persistence on this USB drive now.", nil)];
	                [alert setAlertStyle:NSWarningAlertStyle];
	                [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(regularSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];

	                [self.spinner stopAnimation:nil];
	                [self.operationProgressLabel setStringValue:@""];
				});
			});
		}
	    else {
	        [sender setEnabled:YES];
	        [self.persistenceVolumeSizeSlider setEnabled:YES];
	        [self.persistenceVolumeSizeTextField setEnabled:YES];
	        [self.usbSelectorPopup setEnabled:YES];
		}
	}];
}

- (void)regularSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	// Empty
}

@end
