/* Manages the repository inspector interface */

#import <Cocoa/Cocoa.h>

@class MySvnLogView, MySvnRepositoryBrowserView, DrawerLogView, RepoItem;

/* Manages the repository inspector. */
@interface MyRepository : NSDocument
{
@protected
	IBOutlet MySvnLogView*					svnLogView;
	IBOutlet MySvnRepositoryBrowserView*	svnBrowserView;

	IBOutlet NSDrawer*						sidebar;
	IBOutlet DrawerLogView*					drawerLogView;

	IBOutlet NSTextView*					urlTextView;
	IBOutlet NSTextView*					commitTextView;
	IBOutlet NSTextField*					fileNameTextField;
	IBOutlet NSPanel*						importCommitPanel;
	IBOutlet NSWindow*						fLogReportSheet;

	BOOL									operationInProgress;

	BOOL									fIsFile;		// current URL is file
	NSURL*									fRootURL;		// repository URL
	NSURL*									fURL;			// current URL
	NSString*								fRevision;		// current revision
	NSString*								user;
	NSString*								pass;
	NSString*								windowTitle;

	unsigned int							fHeadRevision;	// repository head revision
	unsigned int							fLogRevision;
	NSMutableArray*							fLog;
	NSMutableDictionary*					displayedTaskObj;
	struct SvnEnv*							fSvnEnv;		// The svn client environment
}

+ (unsigned int) cleanUpLog: (NSMutableArray*) aLog;

- (IBAction) toggleSidebar:   (id) sender;
- (IBAction) svnCopy:         (id) sender;
- (IBAction) svnMove:         (id) sender;
- (IBAction) svnMkdir:        (id) sender;
- (IBAction) svnDelete:       (id) sender;
- (IBAction) svnFileMerge:    (id) sender;
- (IBAction) svnBlame:        (id) sender;
- (IBAction) svnReport:       (id) sender;
- (IBAction) svnOpen:         (id) sender;
- (IBAction) svnImport:       (id) sender;
- (IBAction) svnExport:       (id) sender;
- (IBAction) svnCheckout:     (id) sender;
- (IBAction) reportLimit:     (id) sender;
- (IBAction) reportOKed:      (id) sender;
- (IBAction) reportCancelled: (id) sender;

- (void) setupTitle: (NSString*) title
		 username:   (NSString*) username
		 password:   (NSString*) password
		 url:        (NSURL*)    repoURL;

- (void) openItem:    (RepoItem*)     fileObj
		 revision:    (NSString*)     pegRevision;
- (void) openLogPath: (NSDictionary*) pathInfo
		 revision:    (NSString*)     pegRevision;
- (void) openLogPath: (NSDictionary*) pathInfo
		 forLogEntry: (NSDictionary*) logEntry;
- (void) updateLog;

- (NSString*) revision;
- (NSString*) windowTitle;
- (BOOL)      rootIsFile;
- (NSURL*)    rootURL;
- (NSURL*)    url;
- (NSString*) browsePath;
- (struct svn_client_ctx_t*) svnClient;

- (NSArray*) deliverFiles:   (NSArray*)  repoItems
			 toFolder:       (NSURL*)    folderURL
			 isTemporary:    (BOOL)      isTemporary;
- (void)     receiveFiles:   (NSArray*)  files
			 toRepositoryAt: (RepoItem*) destRepoDir;

- (NSInvocation*) svnOptionsInvocation;

@end

