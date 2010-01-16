//
//  NSWorkspace-Extensions.m
//  IconSetComposer
//
//  Created by Hori,Masaki on 06/01/25.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSWorkspace-Extensions.h"

#import "NSAppleEventDescriptor-Extensions.h"

@implementation NSWorkspace(HMCocoaExtention)
-(BOOL)quitApplication:(NSString *)appName
{
    NSAppleEventDescriptor *targetDesc;
    NSAppleEventDescriptor *appleEvent;
	AppleEvent reply;
	NSAppleEventDescriptor *replyDesc;
	NSAppleEventDescriptor *anser;
    OSStatus err;
	
    targetDesc = [NSAppleEventDescriptor targetDescriptorWithAppName:appName];
    if(!targetDesc) return NO;
	
    appleEvent = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass
                                                          eventID:kAEQuitApplication
                                                 targetDescriptor:targetDesc
                                                         returnID:kAutoGenerateReturnID
                                                    transactionID:kAnyTransactionID];
    if(!appleEvent) return NO;
	
    err = AESendMessage( [appleEvent aeDesc], &reply, kAECanInteract + kAEWaitReply , kAEDefaultTimeout );
	if( err == procNotFound) {
		AEDisposeDesc(&reply);
		return YES;
	}
	if(err != noErr) return err;
	
	replyDesc = [[[NSAppleEventDescriptor allocWithZone:[self zone]] initWithAEDescNoCopy:&reply] autorelease];
	anser = [replyDesc paramDescriptorForKeyword:keyErrorNumber];
	err = (OSStatus)[[anser stringValue] floatValue];
	if(err != noErr) {
		anser = [replyDesc paramDescriptorForKeyword:keyErrorString];
		if(anser) NSLog(@"Target returned error. (%@)",[anser stringValue]);
	}
    return err == noErr;
}

- (BOOL)openAlias:(NSData *)aliasData
{
	return [self openAlias:aliasData withApplication:nil andDeactivate:YES];
}
- (BOOL)openAlias:(NSData *)aliasData withApplication:(NSString *)appName
{
	return [self openAlias:aliasData withApplication:appName andDeactivate:YES];
}
- (BOOL)openAlias:(NSData *)aliasData withApplication:(NSString *)appName andDeactivate:(BOOL)flag
{
	if(!appName || [appName length] == 0) {
		appName = @"Finder";
	}
	
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass
																			 eventID:kAEOpenDocuments
																	   targetAppName:appName];
	
	NSAppleEventDescriptor *alias = [NSAppleEventDescriptor descriptorWithDescriptorType:typeAlias
																				   bytes:[aliasData bytes]
																				  length:[aliasData length]];
	[event setParamDescriptor:alias forKeyword:keyDirectObject];
	
	OSStatus error = [event sendAppleEventWithMode:kAECanInteract
									timeOutInTicks:kAEDefaultTimeout
											replay:NULL];
	
	if(flag && error == noErr) {
		[self launchApplication:appName];
	}
	return error == noErr;
}


inline static NSAppleEventDescriptor *fileDescriptor(NSString *filePath)
{
	NSAppleEventDescriptor *fileDesc;
	NSAppleEventDescriptor *fileNameDesc;
	NSURL *fileURL = [NSURL fileURLWithPath:filePath];
	const char *fileURLCharP;
	
	fileURLCharP = [[fileURL absoluteString] fileSystemRepresentation];
	fileNameDesc = [NSAppleEventDescriptor descriptorWithDescriptorType:typeFileURL
																  bytes:fileURLCharP
																 length:strlen(fileURLCharP)];
	
	fileDesc = [NSAppleEventDescriptor objectSpecifierWithDesiredClass:cFile
															 container:nil
															   keyForm:formName
															   keyData:fileNameDesc];
	return fileDesc;
}
- (BOOL)showInformationInFinder:(NSString *)filePath
{
	NSAppleEventDescriptor *ae;
	OSStatus err = noErr;
	
	ae = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass
												  eventID:kAEOpenDocuments
											targetAppName:@"Finder"];
	if(!ae) {
		NSLog(@"Can NOT create AppleEvent.");
		return NO;
	}
	
	NSAppleEventDescriptor *fileInfoDesc = [NSAppleEventDescriptor
											objectSpecifierWithDesiredClass:cProperty
											container:fileDescriptor(filePath)
											keyForm:cProperty
											keyData:[NSAppleEventDescriptor descriptorWithTypeCode:cInfoWindow]];
	
	[ae setParamDescriptor:fileInfoDesc
				forKeyword:keyDirectObject];
	
	// activate Finder
	[self launchApplication:@"Finder"];
	@try {
		err = [ae sendAppleEventWithMode:kAENoReply | kAENeverInteract
						  timeOutInTicks:kAEDefaultTimeout
								  replay:NULL];
	}
	@catch (NSException *ex) {
		if(![[ex name] isEqualTo:HMAEDescriptorSendingNotAppleEventException]) {
			@throw;
		}
	}
	@finally {
		if( err != noErr ) {
			NSLog(@"AESendMessage Error. Error NO is %d.", err );
		}
	}
		
	return err == noErr;
}

@end
