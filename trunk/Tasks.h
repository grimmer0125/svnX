/* Tasks */

#import <Cocoa/Cocoa.h>

#define	TaskObj		NSMutableDictionary
BOOL		isCompleted	(TaskObj* taskObj);
NSString*	stdErr		(TaskObj* taskObj);
NSString*	stdOut		(TaskObj* taskObj);
NSData*		stdOutData	(TaskObj* taskObj);
id			callbackInfo(TaskObj* taskObj);


//----------------------------------------------------------------------------------------

@interface Tasks : NSObject
{
	IBOutlet NSArrayController*	tasksAC;
	IBOutlet NSPanel*			activityWindow;
	IBOutlet NSDrawer*			logDrawer;
	IBOutlet NSTextView*		logTextView;

	id currentTaskObj;
}

- (IBAction) stopTask:       (id) sender;
- (IBAction) clearCompleted: (id) sender;

- (void) taskDataAvailable: (NSNotification*) aNotification isError: (BOOL) isError;
+ (void) addTask: (TaskObj*) taskObj;
+ (void) cancelCallbacksOnTarget: (id) target;

@end	// Tasks


//----------------------------------------------------------------------------------------

@protocol TaskDelegate;

@interface Task : NSObject
{
	NSTask*				fTask;
	id<TaskDelegate>	fDelegate;
	id					fObject;	// callback argument
}

+ (NSMutableDictionary*) createEnvironment: (BOOL) isUnbuffered;
+ (id) task;
+ (id) taskWithDelegate: (id<TaskDelegate>) target object: (id) object;
- (id) initWithDelegate: (id<TaskDelegate>) target object: (id) object;
- (NSTask*) task;
- (void) launch:    (NSString*) path
		 arguments: (NSArray*)  arguments;
- (void) launch:    (NSString*) path
		 arguments: (NSArray*)  arguments
		 stdOutput: (NSString*) stdOutput;
- (void) setStandardOutput: (id) file;

@end	// Task

@protocol TaskDelegate<NSObject>
	- (void) taskCompleted: (Task*) task object: (id) object;
@end	// TaskDelegate

