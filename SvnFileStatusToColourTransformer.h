
#import <Foundation/Foundation.h>

@interface SvnFileStatusToColourTransformer : NSValueTransformer
{
}

+ (void) initialize: (NSMutableDictionary*) prefs;
+ (void) update;

@end

