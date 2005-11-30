//
//  Scripting.m
//  svnX
//
//  Created by Dominique Peretti on 11/12/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "Scripting.h"


@implementation Scripting

- (id)performDefaultImplementation
{
	NSString *commandName = [[self commandDescription] commandName];
	
	if ( [commandName isEqualToString:@"openSingleFile"] )
	{
		NSString *path = (NSString *)[self directParameter];

		[[NSApp delegate] openSingleFile:path];
	}
	return nil;
}
@end
