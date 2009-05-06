
#import <Foundation/Foundation.h>

@interface FilePathCleanUpTransformer : NSValueTransformer
{
}
@end


@interface FilePathAbbreviatedTransformer : NSValueTransformer
{
}
@end


@interface FilePathWorkingCopy : FilePathAbbreviatedTransformer
{
	BOOL	fTransform;
}
@end


@interface OneLineTransformer : NSValueTransformer
{
}
@end

