/* MySvnOperationController */

#import <Cocoa/Cocoa.h>

@class MyRepository, MySvnRepositoryBrowserView, RepoItem;

typedef enum SvnOperation { kSvnCopy = 0, kSvnMove, kSvnDelete, kSvnMkdir, kSvnDiff } SvnOperation;

// Manages the sheets of svn operations. Meant to be the owner of svnCopy.nib, svnMkdir.nib,
// svnDelete.nib (repository operations) or svnFileMerge.nib (working copy operations).
@interface MySvnOperationController : NSObject
{
	IBOutlet NSObjectController*			objectController;
	IBOutlet NSArrayController*				arrayController;	// to manage list of items (svn mkdir) 
	IBOutlet NSWindow*						svnSheet;
	IBOutlet MySvnRepositoryBrowserView*	targetBrowser;
	IBOutlet NSTextField*					targetName;
	IBOutlet NSTextView*					commitMessage;

	NSInvocation*							svnOptionsInvocation;
	SvnOperation							svnOperation;
}

- (IBAction) validate:     (id) sender;
- (IBAction) addDirectory: (id) sender;
- (IBAction) addItems:     (id) sender;

+ (void) runSheet:   (SvnOperation)  operation
		 repository: (MyRepository*) repository
		 url:        (NSURL*)        url
		 sourceItem: (RepoItem*)     sourceItem;

- (NSString*) getTargetPath;
- (NSURL*)    getTargetUrl;
- (NSString*) getCommitMessage;
- (NSArray*)  getTargets;

- (void) finished;
- (SvnOperation) operation;

@end
