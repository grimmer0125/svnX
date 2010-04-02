#import "ArrayCountTransformer.h"


// Transformer to workaround what I think is a limitation of Panther.
// One should be able to use path.@count in the keyPath field of interface builder,
// but this doesn't seem to work.

@implementation ArrayCountTransformer

+ (Class) transformedValueClass
{
	return [NSNumber class];
}

+ (BOOL) allowsReverseTransformation
{
	return NO;
}

- (id) transformedValue: (id) aArray
{
	return [NSNumber numberWithInt: [aArray count]];
}

@end

