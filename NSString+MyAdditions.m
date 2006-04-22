//
//  NSString+MyAdditions.m
//  svnX
//
//  Created by Dominique PERETTI on Sun Jul 18 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "NSString+MyAdditions.h"


@implementation NSString (MyAdditions)

+ (NSString *)stringByAddingPercentEscape:(NSString *)url
{
	return [(id)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)url, NULL, NULL, kCFStringEncodingUTF8) autorelease];
}

// used in MyRepository.m as a workaround to a problem in standard [NSString stringByDeletingLastPathComponent] which turns "svn://blah" to "svn:/blah"
- (NSString *)stringByDeletingLastComponent
{
	
	NSRange r = [[self stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]] rangeOfString:@"/" options:NSBackwardsSearch];
	
	
	if ( r.length > 0 )
	{
		return [self substringToIndex:r.location];

	} else return self;
}

@end
