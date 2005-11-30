/* Manages the repository inspector interface */

#import <Cocoa/Cocoa.h>
#import "MySVN.h";

@class MySvnLogView, MySvnLogView2, MySvnRepositoryBrowserView, DrawerLogView;
@class MySvnOperationController, MySvnMkdirController, MySvnMoveController, MySvnCopyController, MySvnDeleteController, MyFileMergeController;

/* Manages the repository inspector. */
@interface MyRepository : NSDocument
{
	IBOutlet MySvnLogView *svnLogView1;
	IBOutlet MySvnLogView2 *svnLogView2;
	IBOutlet MySvnLogView *svnLogView;
	IBOutlet MySvnRepositoryBrowserView *svnBrowserView;

	IBOutlet MySvnOperationController *svnOperationController;
	IBOutlet MySvnMkdirController *svnMkdirController;
	IBOutlet MySvnMoveController *svnMoveController;
	IBOutlet MySvnCopyController *svnCopyController;
	IBOutlet MySvnDeleteController *svnDeleteController;
	IBOutlet MyFileMergeController *fileMergeController;
	
	IBOutlet NSDrawer *sidebar;
	IBOutlet DrawerLogView *drawerLogView;

    IBOutlet NSTextView *commitTextView;
    IBOutlet NSTextField *fileNameTextField;
    IBOutlet NSPanel *importCommitPanel;
	
	BOOL operationInProgress;
	
	NSURL *url;
	NSString *revision;
	NSString *user;
	NSString *pass;
	NSString *windowTitle;
	
	NSString *logViewKind;
	NSMutableDictionary *displayedTaskObj;
}

- (NSURL *)url;
- (void)setUrl:(NSURL *)anUrl;

- (NSString *)revision;
- (void)setRevision:(NSString *)aRevision;

- (NSString *)user;
- (void) setUser: (NSString *) aUser;

- (NSString *)pass;
- (void) setPass: (NSString *) aPass;


- (NSString *)windowTitle;
- (void) setWindowTitle: (NSString *) aWindowTitle;

- (NSURL *)url;
- (void)setUrl:(NSURL *)anUrl;

- (NSString *)logViewKind;
- (void)setLogViewKind:(NSString *)aLogViewKind;

@end
