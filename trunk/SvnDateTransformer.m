//
//  SvnDateTransformer.m
//  svnX
//
//  Created by Dominique PERETTI on Mon Jul 12 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "SvnDateTransformer.h"
#import "CommonUtils.h"


static NSDateFormatter* gDateFormatter = nil;


@implementation SvnDateTransformer

+ (Class)transformedValueClass
{
	return [NSString class];
}


+ (BOOL)allowsReverseTransformation
{
	return NO;
}


//----------------------------------------------------------------------------------------

+ (NSDateFormatter*) formatter
{
	return gDateFormatter;
}


//----------------------------------------------------------------------------------------

- (id) init
{
	self = [super init];
	if (gDateFormatter == nil)
	{
		[[NSUserDefaultsController sharedUserDefaultsController]
								addObserver: self
								forKeyPath:  @"values.dateformat"
								options:     NSKeyValueObservingOptionNew
								context:     NULL];

		gDateFormatter = [[NSDateFormatter alloc]
								initWithDateFormat:   GetPreference(@"dateformat")
								allowNaturalLanguage: NO];
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	#pragma unused(keyPath, object, change, context)
	[gDateFormatter release];
	gDateFormatter = [[NSDateFormatter alloc]
							initWithDateFormat: GetPreference(@"dateformat")
							allowNaturalLanguage: NO];
}


//----------------------------------------------------------------------------------------

- (id) transformedValue: (id) aString
{
	NSString* dateString = [NSString stringWithFormat: @"%@ %@ +0000",
										[aString substringToIndex: 10],
										[aString substringWithRange: NSMakeRange(11, 8)]];

	return [gDateFormatter stringFromDate: [NSDate dateWithString: dateString]];
}


@end

