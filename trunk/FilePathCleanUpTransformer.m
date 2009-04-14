#import "FilePathCleanUpTransformer.h"
#include "CommonUtils.h"


@implementation FilePathCleanUpTransformer


+ (Class)transformedValueClass
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)transformedValue:(id)aString
{
	return [aString stringByStandardizingPath];
}

- (id)reverseTransformedValue:(id)aString
{
	return [aString stringByStandardizingPath];
}


@end


//----------------------------------------------------------------------------------------

@implementation FilePathAbbreviatedTransformer


+ (Class) transformedValueClass
{
    return [NSString class];
}

+ (BOOL) allowsReverseTransformation
{
    return NO;
}

- (id) transformedValue: (id) aString
{
	return [aString stringByAbbreviatingWithTildeInPath];
}


@end


//----------------------------------------------------------------------------------------

@implementation FilePathWorkingCopy


- (id) init
{
	self = [super init];
	if (self)
	{
		[[NSUserDefaultsController sharedUserDefaultsController]
								addObserver: self
								forKeyPath:  @"values.abbrevWCFilePaths"
								options:     0
								context:     NULL];

		fTransform = [GetPreference(@"abbrevWCFilePaths") boolValue];
	}

    return self;
}


//----------------------------------------------------------------------------------------

- (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	fTransform = [GetPreference(@"abbrevWCFilePaths") boolValue];
}


//----------------------------------------------------------------------------------------

- (id) transformedValue: (id) aString
{
	return fTransform ? [aString stringByAbbreviatingWithTildeInPath] : aString;
}


@end

