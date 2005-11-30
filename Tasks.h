/* Tasks */

#import <Cocoa/Cocoa.h>

@class MySvn;

@interface Tasks : NSObject
{
    IBOutlet NSArrayController *tasksAC;

    IBOutlet NSPanel *activityWindow;
	IBOutlet NSDrawer *logDrawer;
	
	IBOutlet NSTextView *logTextView;
	
	id currentTaskObj;
}

- (IBAction)stopTask:(id)sender;
- (IBAction)clearCompleted:(id)sender;

@end
