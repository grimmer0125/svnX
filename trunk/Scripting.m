//----------------------------------------------------------------------------------------
//  Scripting.m - Open Scripting Architecture support
//
//  Created by Dominique Peretti on 11/12/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "Scripting.h"
#import "MyApp.h"


@implementation Scripting

- (id) performDefaultImplementation
{
	NSString* const commandName = [[self commandDescription] commandName];
	const id directParam = [self directParameter];
	const id directParam0 = [directParam isKindOfClass: [NSArray class]]
									? [directParam lastObject] : directParam;
	NSString* const string0 = [directParam0 isKindOfClass: [NSString class]]
							? directParam0
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

	return nil;
}

@end

