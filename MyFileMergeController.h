/* MyFileMergeController */

#import <Cocoa/Cocoa.h>

@class MySvnLogView, MySvnLogView2;

@interface MyFileMergeController : NSObject
{
    IBOutlet NSWindow *svnSheet;

    IBOutlet MySvnLogView *svnLogView;
    IBOutlet MySvnLogView *svnLogView1; 
    IBOutlet MySvnLogView2 *svnLogView2;

    IBOutlet NSObjectController *objectController;

	NSInvocation *svnOptionsInvocation;
}

- (IBAction)compare:(id)sender;
- (IBAction)compareUrl:(id)sender;
- (IBAction)validate:(id)sender;

@end
