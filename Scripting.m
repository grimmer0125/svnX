//
//  Scripting.m
//  svnX
//
//  Created by Dominique Peretti on 11/12/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "Scripting.h"
#import "MyApp.h"


@implementation Scripting

- (id)performDefaultImplementation
{
	NSString *commandName = [[self commandDescription] commandName];
	
	if ( [commandName isEqualToString:@"fileHistoryOpenSheetForItem"] )
	{
		NSString *path = (NSString *)[self directParameter];

		[[NSApp delegate] fileHistoryOpenSheetForItem:path];
	}
	return nil;
}
@end
