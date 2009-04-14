/* Manages the repository inspector interface */

#import <Cocoa/Cocoa.h>
#import "MySVN.h";

@class MySvnLogView, MySvnRepositoryBrowserView, DrawerLogView;

/* Manages the repository inspector. */
@interface MyRepository : NSDocument
{
	IBOutlet MySvnLogView*					svnLogView;
	IBOutlet MySvnRepositoryBrowserView*	svnBrowserView;

	IBOutlet NSDrawer*						sidebar;
	IBOutlet DrawerLogView*					drawerLogView;

	IBOutlet NSTextView*					urlTextView;
	IBOutlet NSTextView*					commitTextView;
	IBOutlet NSTextField*					fileNameTextField;
	IBOutlet NSPanel*						importCommitPanel;

	BOOL operationInProgress;

	NSURL *url;
	NSURL *rootUrl;
	NSString *revision;
	NSString *user;
	NSString *pass;
	NSString *windowTitle;
	
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

- (void) setDisplayedTaskObj: (NSMutableDictionary*) aDisplayedTaskObj;

- (void) openLogPath: (NSDictionary*) pathInfo
		 revision:    (NSString*)     pegRevision;
- (void) changeRepositoryUrl: (NSURL*) anUrl;

- (NSString*) revision;
- (void) setRevision: (NSString*) aRevision;

- (NSString*) windowTitle;
- (struct svn_client_ctx_t*) svnClient;

- (NSURL*) url;
- (void) setUrl: (NSURL*) anUrl;

- (void) fetchSvnInfo;
- (void) fetchSvnInfoReceiveDataFinished: (NSString*) result;

- (void) svnErrorIf: (id) taskObj;
- (void) svnError: (NSString*) errorString;
- (NSArray*) userValidatedFiles: (NSArray*) files forDestination: (NSURL*) destinationURL;
- (void) dragOutFilesFromRepository: (NSArray*) filesDicts toURL: (NSURL*) destinationURL;
- (void) dragExternalFiles: (NSArray*) files ToRepositoryAt: (NSDictionary*) representedObject;

- (NSInvocation*) makeSvnOptionInvocation;
- (NSInvocation*) makeCallbackInvocationOfKind: (int) callbackKind;
- (NSInvocation*) svnOptionsInvocation;

@end
