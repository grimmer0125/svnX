/* MySVN */

#import <Cocoa/Cocoa.h>

@interface MySvn : NSObject
{

}

+(NSMutableDictionary *)launchTask:(NSString *)taskLaunchPath arguments:(NSArray *)arguments callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo additionalTaskInfo:(id)additionalTaskInfo;

// CLASS VARIABLES ACCESSORS
+ (NSString *) svnPath;
+ (void) setSvnPath: (NSString *) aSvnPath;
+ (NSString *)bundleScriptPath:(NSString *)script;

@end
