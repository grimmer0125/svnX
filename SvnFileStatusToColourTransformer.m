

#import "SvnFileStatusToColourTransformer.h"


@implementation SvnFileStatusToColourTransformer


+ (Class)transformedValueClass
{
    return [NSColor class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)aString
{	
    //int priority = [aNumber intValue];
    
	if ( [aString isEqualToString:@"M"] )
	return [NSUnarchiver unarchiveObjectWithData:[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"svnFileStatusModifiedColor"]];

	if ( [aString isEqualToString:@"?"] )
	return [NSUnarchiver unarchiveObjectWithData:[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"svnFileStatusNewColor"]];

	if ( [aString isEqualToString:@"!"] )
	return [NSUnarchiver unarchiveObjectWithData:[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"svnFileStatusMissingColor"]];

    return [NSColor blackColor];
}


@end

