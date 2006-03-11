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

@end
