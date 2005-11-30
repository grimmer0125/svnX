#import "FilePathCleanUpTransformer.h"


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

