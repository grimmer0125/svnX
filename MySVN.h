/* MySVN */

#import <Cocoa/Cocoa.h>

@interface MySvn : NSObject
{

}

+ (NSMutableDictionary*) diffItems:      (NSArray*)      itemsPaths
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) runScript:      (NSString*)     scriptName
						 options:        (NSArray*)      options
						 args:           (NSArray*)      args
						 name:           (NSString*)     name
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
						 dataOnly:       (BOOL)          dataOnly;

+ (NSMutableDictionary*) genericCommand: (NSString*)     command
						 arguments:      (NSArray*)      args
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) moveMultiple:   (NSArray*)      files
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) copyMultiple:   (NSArray*)      files
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) log:            (NSString*)     path
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) list:           (NSString*)     path
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) checkout:       (NSString*)     file
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) extractItems:   (NSArray*)     items
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) import:         (NSString*)     file
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) copy:           (NSString*)     file
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) move:           (NSString*)     file
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) mkdir:          (NSArray*)      files
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) delete:         (NSArray*)      files
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) blame:          (NSArray*)      files
						 revision:       (NSString*)     revision
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo;

+ (NSMutableDictionary*) statusAtWorkingCopyPath: (NSString*)     path
						 generalOptions:          (NSInvocation*) generalOptions
						 options:                 (NSArray*)      options
						 callback:                (NSInvocation*) callback
						 callbackInfo:            (id)            callbackInfo
						 taskInfo:                (id)            taskInfo;

+ (NSMutableDictionary*) updateAtWorkingCopyPath: (NSString*)     path
						 generalOptions:          (NSInvocation*) generalOptions
						 options:                 (NSArray*)      options
						 callback:                (NSInvocation*) callback
						 callbackInfo:            (id)            callbackInfo
						 taskInfo:                (id)            taskInfo;

+ (NSArray*) optionsFromSvnOptionsInvocation: (NSInvocation*) invocation;

+ (NSMutableDictionary*) launchTask:         (NSString*)     taskLaunchPath
						 arguments:          (NSArray*)      arguments
						 callback:           (NSInvocation*) callback
						 callbackInfo:       (id)            callbackInfo
						 taskInfo:           (id)            taskInfo
						 additionalTaskInfo: (id)            additionalTaskInfo
						 outputToData:       (BOOL)          outputToData;

+ (void) killTask: (NSDictionary*) taskObj
			force: (BOOL)          force;

+ (NSString*) cachePathForKey: (NSString*) key;

@end	// MySvn

static const unsigned kSortOptions = NSCaseInsensitiveSearch | NSNumericSearch;

NSString* SvnPath			(void);
NSString* SvnCmdPath		(void);
NSString* ShellScriptPath	(NSString* script);
NSString* GetDiffAppName	(void);

