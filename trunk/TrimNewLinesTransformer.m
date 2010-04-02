
#import "TrimNewLinesTransformer.h"


@implementation TrimNewLinesTransformer

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
	return [aString stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @"\n"]];
}


@end

