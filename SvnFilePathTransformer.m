#import "SvnFilePathTransformer.h"


@implementation SvnFilePathTransformer


+ (Class)transformedValueClass
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)aString
{	
	return [aString lastPathComponent];
}

@end

