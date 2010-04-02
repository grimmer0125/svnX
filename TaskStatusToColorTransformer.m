
@interface TaskStatusToColorTransformer : NSObject @end


@implementation TaskStatusToColorTransformer

+ (Class) transformedValueClass
{
	return [NSColor class];
}


+ (BOOL) allowsReverseTransformation
{
	return NO;
}


- (id) transformedValue: (NSString*) aString
{
	if ([aString isEqualToString: @"error"])
	{
		return [NSColor redColor];
	}
	return [NSColor blackColor];
}


@end

