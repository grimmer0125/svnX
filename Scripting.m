//----------------------------------------------------------------------------------------
//  Scripting.m - Open Scripting Architecture support
//
//  Created by Dominique Peretti on 11/12/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "Scripting.h"
#import "MyApp.h"
#import "CommonUtils.h"


@implementation Scripting

- (id) performDefaultImplementation
{
	ConstString commandName = [[self commandDescription] commandName];
	const id directParam = [self directParameter],
			 directParam0 = ISA(directParam, NSArray)
									? [directParam lastObject] : directParam;
	ConstString string0 = ISA(directParam0, NSString) ? directParam0
													  : nil;
	MyApp* const target = [NSApp delegate];
//	dprintf("%@", self);

//	switch ([[self commandDescription] appleEventClassCode])
//	switch ([[self commandDescription] appleEventCode])
	if ([commandName isEqualToString: @"displayHistory"] ||
		[commandName isEqualToString: @"fileHistoryOpenSheetForItem"])
	{
		if (string0)
			[target displayHistory: string0];
	}
	else if ([commandName isEqualToString: @"openWorkingCopy"])
	{
		if (string0)
			[target openWorkingCopy: string0];
	}
	else if ([commandName isEqualToString: @"openRepository"])
	{
		if (string0)
			[target openRepository: string0];
	}
	else if ([commandName isEqualToString: @"openFiles"])
	{
		if (string0)
			[target openFiles: directParam];
	}
	else if ([commandName isEqualToString: @"diffFiles"])
	{
		if (string0)
			[target diffFiles: directParam];
	}
	else if ([commandName isEqualToString: @"resolveFiles"])
	{
		if (string0)
			[target resolveFiles: directParam];
	}

	return nil;
}

@end	// Scripting

