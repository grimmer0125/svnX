//
//  SvnDateTransformer.m
//  svnX
//
//  Created by Dominique PERETTI on Mon Jul 12 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "SvnDateTransformer.h"


@implementation SvnDateTransformer

+ (Class)transformedValueClass
{
    return [NSDate class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)aString
{
	NSString *dateString = [NSString stringWithFormat:@"%@ %@ +0000", [aString substringToIndex:10], [aString substringWithRange:NSMakeRange(11, 8)]];
	NSDate *date = [NSDate dateWithString:dateString];
	
	return date;
}


@end
