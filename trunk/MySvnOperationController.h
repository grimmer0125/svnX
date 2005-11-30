/* MySvnOperationController */

#import <Cocoa/Cocoa.h>

@class MySvnRepositoryBrowserView;

/* Manages the sheets of svn operations. Meant to be the owner of svnCopy.nib, svnMkdir.nib, svnDelete.nib
(repository operations) or svnFileMerge.nib (working copy operations). */
@interface MySvnOperationController : NSObject
{
    IBOutlet NSObjectController *objectController;
    IBOutlet NSArrayController *arrayController; // to manage list of items (svn mkdir) 
    IBOutlet NSWindow *svnSheet;
    IBOutlet MySvnRepositoryBrowserView *targetBrowser;
	IBOutlet NSTextField *targetName;
	IBOutlet NSTextView *commitMessage;

	NSInvocation *svnOptionsInvocation;
}

- (IBAction)validate:(id)sender;
- (IBAction)addDirectory:(id)sender;
- (IBAction)addItems:(id)sender;

@end
