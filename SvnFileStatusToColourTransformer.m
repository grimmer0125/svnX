
#import "SvnFileStatusToColourTransformer.h"
#include "CommonUtils.h"


@implementation SvnFileStatusToColourTransformer


+ (Class) transformedValueClass
{
	return [NSColor class];
}


+ (BOOL) allowsReverseTransformation
{
	return NO;
}


- (id) transformedValue: (id) aString
{
	//int priority = [aNumber intValue];

	if ([aString length] == 1)
	{
		NSString* prefKey = nil;
		switch ([aString characterAtIndex: 0])
		{
			case 'M':	prefKey = @"svnFileStatusModifiedColor";	break;
			case '?':	prefKey = @"svnFileStatusNewColor";			break;
			case '!':	prefKey = @"svnFileStatusMissingColor";		break;
		}
		if (prefKey != nil)
			return [NSUnarchiver unarchiveObjectWithData: GetPreference(prefKey)];
	}

	return [NSColor blackColor];
}


@end

