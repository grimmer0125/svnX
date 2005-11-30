#import <Cocoa/Cocoa.h>
#import "MySVN.h"

/* Manages the result sheet of svn checkout/export (from repository inspector) and svn update (from wc inspector).*/
@interface MySvnResultController : NSObject
{
	NSWindow *sheet;
	NSTextView *resultTextView;
	NSObjectController *objectController;
	
	NSFileHandle *handle;
	NSFileHandle *errorHandle;
	NSTask *task;
	
	NSLock *processLock;

	int taskPid;
	
	BOOL shouldTerminate;
}

- (IBAction) validate:(id)sender;


@end
