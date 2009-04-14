/* Tasks */

#import <Cocoa/Cocoa.h>

@interface Tasks : NSObject
{
    IBOutlet NSArrayController *tasksAC;

    IBOutlet NSPanel *activityWindow;
	IBOutlet NSDrawer *logDrawer;
	
	IBOutlet NSTextView *logTextView;
	
	id currentTaskObj;
}

+ (id) sharedInstance;

- (IBAction) stopTask:       (id) sender;
- (IBAction) clearCompleted: (id) sender;

- (void) newTaskWithDictionary: (NSMutableDictionary*) taskObj;
- (void) taskDataAvailable: (NSNotification*) aNotification isError: (BOOL) isError;
- (void) cancelCallbacksOnTarget: (id) target;

@end	// Tasks


//----------------------------------------------------------------------------------------

@protocol TaskDelegate;

@interface Task : NSObject
{
	NSTask*				fTask;
	id<TaskDelegate>	fDelegate;
	id					fObject;	// callback argument
}

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

