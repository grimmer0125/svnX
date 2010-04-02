#import "FilePathCleanUpTransformer.h"
#import "CommonUtils.h"


@implementation FilePathCleanUpTransformer


+ (Class) transformedValueClass
{
	return [NSString class];
}

+ (BOOL) allowsReverseTransformation
{
	return YES;
}

- (id) transformedValue: (id) aString
{
	return [aString stringByStandardizingPath];
}

- (id) reverseTransformedValue: (id) aString
{
	return [aString stringByStandardizingPath];
}


@end	// FilePathCleanUpTransformer


//----------------------------------------------------------------------------------------
#pragma mark	-
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


@end	// FilePathAbbreviatedTransformer


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation FilePathWorkingCopy


- (id) init
{
	if (self = [super init])
	{
		[[NSUserDefaultsController sharedUserDefaultsController]
								addObserver: self
								forKeyPath:  @"values.abbrevWCFilePaths"
								options:     0
								context:     NULL];

		fTransform = GetPreferenceBool(@"abbrevWCFilePaths");
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
	fTransform = GetPreferenceBool(@"abbrevWCFilePaths");
}


//----------------------------------------------------------------------------------------

- (id) transformedValue: (id) aString
{
	return fTransform ? [aString stringByAbbreviatingWithTildeInPath] : aString;
}


@end	// FilePathWorkingCopy


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------
// Replaces control characters including NLs with spaces

@implementation OneLineTransformer


+ (Class) transformedValueClass
{
	return [NSString class];
}


+ (BOOL) allowsReverseTransformation
{
	return YES;
}


- (id) transformedValue: (id) aString
{
	const unsigned int kMaxLen = 1024;
	unsigned int length = [aString length];
	if (length > kMaxLen)
		length = kMaxLen;

	unichar buf[kMaxLen];
	[aString getCharacters: buf range: NSMakeRange(0, length)];

	BOOL changed = NO;
	for (int i = 0; i < length; ++i)
	{
		if (buf[i] < 32)
		{
			buf[i] = ' ';
			changed = YES;
		}
	}

	return changed ? [NSString stringWithCharacters: buf length: length] : aString;
}


- (id) reverseTransformedValue: (id) aString
{
	return [self transformedValue: aString];
}


@end	// OneLineTransformer

