/* MySVN */

#import <Cocoa/Cocoa.h>

@interface MySvn : NSObject
{

}

+(void)svnCommand:(NSString *)command items:(NSArray *)itemsPaths options:(NSArray *)options threadSelector:(SEL)selector target:(id)target info:(id)info;

// CLASS VARIABLES ACCESSORS
+ (NSString *) svnPath;
+ (void) setSvnPath: (NSString *) aSvnPath;

@end
