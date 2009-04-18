/* Manages the repository inspector interface */

#import <Cocoa/Cocoa.h>

@class MySvnLogView, MySvnRepositoryBrowserView, DrawerLogView;

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

	BOOL									operationInProgress;

	NSURL*									fRootURL;		// repository URL
	NSURL*									fURL;			// current URL
	NSString*								fRevision;		// current revision
	NSString*								user;
	NSString*								pass;
	NSString*								windowTitle;

	unsigned int							fHeadRevision;	// repository head revision
	NSMutableDictionary*					displayedTaskObj;
	struct SvnEnv*							fSvnEnv;		// The svn client environment
}

- (IBAction) toggleSidebar: (id) sender;
- (IBAction) svnCopy:       (id) sender;
- (IBAction) svnMove:       (id) sender;
- (IBAction) svnMkdir:      (id) sender;
- (IBAction) svnDelete:     (id) sender;
- (IBAction) svnFileMerge:  (id) sender;
- (IBAction) svnBlame:      (id) sender;
- (IBAction) svnReport:     (id) sender;
- (IBAction) svnExport:     (id) sender;
- (IBAction) svnCheckout:   (id) sender;
- (IBAction) pickedAFolderInBrowserView: (NSMenuItem*) sender;

- (void) setupTitle: (NSString*) title
		 username:   (NSString*) username
		 password:   (NSString*) password
		 url:        (NSURL*)    repoURL;

- (void) browsePath: (NSString*) relativePath
		 revision:   (NSString*) pegRevision;
- (void) openLogPath: (NSDictionary*) pathInfo
		 revision:    (NSString*)     pegRevision;
- (void) changeRepositoryUrl: (NSURL*) anUrl;

- (NSString*) revision;
- (NSString*) windowTitle;
- (NSURL*)    url;
- (NSString*) browsePath;
- (struct svn_client_ctx_t*) svnClient;

- (void) dragOutFilesFromRepository: (NSArray*) filesDicts toURL: (NSURL*) destinationURL;
- (void) dragExternalFiles: (NSArray*) files ToRepositoryAt: (NSDictionary*) representedObject;

- (NSInvocation*) makeSvnOptionInvocation;
- (NSInvocation*) makeCallbackInvocationOfKind: (int) callbackKind;
- (NSInvocation*) svnOptionsInvocation;

@end
