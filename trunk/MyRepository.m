//
// MyRepository.m - Manages the repository inspector interface
//

#import "MyRepository.h"
#import "MySvn.h"
#import "Tasks.h"
#import "DrawerLogView.h"
#import "MyFileMergeController.h"
#import "MySvnOperationController.h"
#import "MySvnRepositoryBrowserView.h"
#import "MySvnLogView.h"
#import "NSString+MyAdditions.h"
#import "RepoItem.h"
#import "SvnLogReport.h"
#import "CommonUtils.h"
#import "MySvnLogParser.h"
#import "SvnInterface.h"
#import "ViewUtils.h"


static ConstString keyWidowFrame  = @"winFrame",
				   keyViewMode    = @"viewMode",
				   keyShowToolbar = @"showToolbar",
				   keyShowSidebar = @"showSidebar",
				   keySplitViews  = @"splitViews";


//----------------------------------------------------------------------------------------

static NSString*
TrimSlashes (RepoItem* obj)
{
	return [[[obj url] absoluteString] trimSlashes];
}


//----------------------------------------------------------------------------------------

static inline NSString*
PrefKey (NSString* nameKey)
{
	return [@"Repo:" stringByAppendingString: nameKey];
}


//----------------------------------------------------------------------------------------
// Return true if the command sent from sender wants its option enabled.

static bool
wantsOption (id sender)
{
	enum { kAltOrShift = 0, kOptionOff = 1, kOptionOn = 2 };
	const int tag = [sender tag];
	Assert(tag >= kAltOrShift && tag <= kOptionOn);
	return (tag == kAltOrShift && AltOrShiftPressed()) || tag == kOptionOn;
}


//----------------------------------------------------------------------------------------
// Path items in log items

static NSString*
getPath (NSDictionary* obj)
{
	return [obj objectForKey: @"path"];
}


//----------------------------------------------------------------------------------------

static int
getAction (NSDictionary* obj)
{
	ConstString action = [obj objectForKey: @"action"];
	if (action && [action length])
		return [action characterAtIndex: 0];
	return 0;
}


//----------------------------------------------------------------------------------------

static NSString*
getRevision (NSDictionary* obj)
{
	return [obj objectForKey: @"revision"];
}


//----------------------------------------------------------------------------------------

static int
compareRevisions (id obj1, id obj2, void* context)
{
	#pragma unused(context)
	return [(NSNumber*) [obj2 objectForKey: @"revision_n"] compare: [obj1 objectForKey: @"revision_n"]];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@interface MyRepository (Private)

	- (void) savePrefs;

	- (void) changeRepositoryUrl: (NSURL*) anUrl;
	- (BOOL) svnErrorIf: (id) taskObj;

	- (void) svnInfoCompletedCallback: (id) taskObj;
	- (void) fetchSvnInfo: (SEL) selector;
	- (void) fetchSvnInfo;
	- (void) fetchSvnInfoReceiveDataFinished: (NSString*) result;

	- (NSArray*) userValidatedFiles: (NSArray*) files
				 forDestination:     (NSURL*)   destinationURL;

	- (NSArray*) exportFiles: (NSArray*) fileObjs
				 toFolder:    (NSURL*)   folderURL
				 includeRev:  (BOOL)     includeRev
				 openAfter:   (BOOL)     openAfter;

	- (void) importFiles: (NSArray*)  files
			 intoFolder:  (RepoItem*) destRepoDir;

	- (void) requestReport;

	- (void) setRevision:         (NSString*) aRevision;
	- (void) setUrl:              (NSURL*)    anUrl;
	- (void) checkRepositoryURL;
	- (void) setDisplayedTaskObj: (NSMutableDictionary*) aDisplayedTaskObj;

	- (NSInvocation*) makeSvnOptionInvocation;
	- (NSInvocation*) makeCommandCallback;
	- (NSInvocation*) makeExtractedCallback;

@end


//----------------------------------------------------------------------------------------

@implementation MyRepository

#if 0
- init
{
	if (self = [super init])
	{
		[self setRevision: nil];

	//	logViewKind = GetPreferenceBool(@"defaultLogViewKindIsAdvanced") ? kAdvanced : kSimple;
	//	useAdvancedLogView = GetPreferenceBool(@"defaultLogViewKindIsAdvanced");
	}

	return self;
}
#endif


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[svnLogView unload];
	[svnBrowserView unload];

	[fRootURL release];
	[fURL release];
	[fRevision release];
	[windowTitle release];
	[user release];
	[pass release];

	[fLog release];
	[displayedTaskObj release];

//	NSLog(@"Repository dealloc'ed");
	SvnEndClient(fSvnEnv);

	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (NSWindow*) window
{
	return [svnLogView window];
}


//----------------------------------------------------------------------------------------

- (void) showWindows
{
	[super showWindows];
	const BOOL showURL = GetPreferenceBool(@"repURLInWindowTitle");
	[[self window] setTitle: [NSString stringWithFormat: (showURL ? @"Repository: %@ - %@"
																  : @"Repository: %@"),
														 windowTitle, fRootURL]];
}


//----------------------------------------------------------------------------------------

- (NSString*) windowNibName
{
	return @"MyRepository";
}


//----------------------------------------------------------------------------------------

- (void) windowControllerDidLoadNib: (NSWindowController*) aController
{
	[aController setShouldCascadeWindows: NO];
}


//----------------------------------------------------------------------------------------

- (void) windowWillClose: (NSNotification*) notification
{
	#pragma unused(notification)
	fPrefsChanged = TRUE;
	[self savePrefs];
	[svnLogView removeObserver: self forKeyPath: @"currentRevision"];
}


//----------------------------------------------------------------------------------------
// Mark prefs as changed but defer saving for 5 secs.

- (void) prefsChanged
{
	if (!fPrefsChanged)
	{
		fPrefsChanged = TRUE;
		[self performSelector: @selector(savePrefs) withObject: nil afterDelay: 5];
	}
}


//----------------------------------------------------------------------------------------

- (void) savePrefs
{
	NSWindow* const window = [self window];
	if (!fPrefsChanged || ![window isVisible])
		return;

	fPrefsChanged = FALSE;
	SetPreference(PrefKey(windowTitle),
				  [NSDictionary dictionaryWithObjectsAndKeys:
						[window stringWithSavedFrame],        keyWidowFrame,
						NSBool([svnLogView advanced]),        keyViewMode,
						NSBool([[window toolbar] isVisible]), keyShowToolbar,
						NSBool(IsOpen(sidebar)),              keyShowSidebar,
						getValuesForSplitViews(window),       keySplitViews,
						nil]);
}


//----------------------------------------------------------------------------------------

- (void) quitting: (NSNotification*) notification
{
	#pragma unused(notification)
	fPrefsChanged = TRUE;
	[self savePrefs];
}


//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
	[svnLogView addObserver: self forKeyPath: @"currentRevision" options: NSKeyValueChangeSetting context: nil];

	[svnBrowserView setSvnOptionsInvocation: [self makeSvnOptionInvocation]];
	[svnBrowserView setUrl: fURL];

	[svnLogView setIsFetching: TRUE];
	[svnLogView setSvnOptionsInvocation: [self makeSvnOptionInvocation]];
	[svnLogView setUrl: fURL];
//	[svnLogView setSvnOptions: [self makeSvnOptionInvocation] url: fURL currentRevision: [self revision]];
//	[svnLogView setupUrl: fURL options: [self makeSvnOptionInvocation] currentRevision: [self revision]];

	// display the known url as raw text while svn info is fetching data
	[urlTextView setBackgroundColor: [NSColor windowBackgroundColor]];
	[urlTextView setString: [fURL absoluteString]];

	NSWindow* const window = [self window];
	[window setDelegate: self];		// for windowWillClose messages
	[drawerLogView setup: self forWindow: window];

	Assert(windowTitle);
	ConstString prefKey = PrefKey(windowTitle);
	NSDictionary* const settings = GetPreference(prefKey);
	if (settings)
	{
		if (![[settings objectForKey: keyShowToolbar] boolValue])
			[[window toolbar] setVisible: NO];

		[window setFrameFromString: [settings objectForKey: keyWidowFrame]];

		if ([[settings objectForKey: keyShowSidebar] boolValue])
			[sidebar performSelector: @selector(open) withObject: nil afterDelay: 0.125];

		[svnLogView setAdvanced: [[settings objectForKey: keyViewMode] boolValue]];

		setupSplitViews(window, [settings objectForKey: keySplitViews], nil);
	}
	else
	{
		ConstString widowFrameKey = [@"repoWinFrame:" stringByAppendingString: windowTitle];
		[window setFrameUsingName: widowFrameKey];
	}

	[svnLogView setAutosaveName: prefKey];

	// fetch svn info in order to know the repository's root URL & HEAD revision
	[self performSelector: @selector(updateLog) withObject: nil afterDelay: 0];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(quitting:)
												 name: NSApplicationWillTerminateNotification object: nil];
}


//----------------------------------------------------------------------------------------

- (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	#pragma unused(object, context)
	if ([keyPath isEqualToString: @"currentRevision"])	// A new current revision was selected in the svnLogView
	{
		const id value = [change objectForKey: NSKeyValueChangeNewKey];
		[self setRevision: value];
		[svnBrowserView setRevision: value];
		[svnBrowserView fetchSvn];
	}
}


//----------------------------------------------------------------------------------------

- (void) setupTitle: (NSString*) title
		 username:   (NSString*) username
		 password:   (NSString*) password
		 url:        (NSURL*)    repoURL
{
	windowTitle = [title retain];
 	user = [username retain];
	pass = [password retain];
	Assert(fRootURL == nil);
	fRootURL = [repoURL retain];
	[self setUrl: repoURL];
}


//----------------------------------------------------------------------------------------
// Private:

- (NSString*) pathToURL: (NSString*) path
{
	Assert(path);
	return [[fRootURL absoluteString] stringByAppendingString: [path escapeURL]];
}


//----------------------------------------------------------------------------------------

- (IBAction) toggleSidebar: (id) sender
{
	[sidebar toggle: sender];
}


- (IBAction) pickedAFolderInBrowserView: (NSMenuItem*) sender
{
	// "Browse as sub-repository" context menu item. (see "browserContextMenu" Menu in IB)
	// representedObject of the sender menu item is the same as the row's in the browser.
	// Was set in MySvnRepositoryBrowserView.
	[self changeRepositoryUrl: [[sender representedObject] url]];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	clickable url
//----------------------------------------------------------------------------------------

- (void) displayUrlTextView
{
	[self checkRepositoryURL];
	NSString* tmpString = UnEscapeURL(fURL);
	int rootLength = [UnEscapeURL(fRootURL) length];
	if (rootLength == 0)
		rootLength = [tmpString length];
	const id layout = [urlTextView layoutManager];

	[urlTextView setString: @""];	// workaround to clean-up the style for sure
	[urlTextView setString: tmpString];
	[urlTextView setFont: [NSFont systemFontOfSize: 11]];
	[urlTextView setFont: [NSFont boldSystemFontOfSize: 11] range: NSMakeRange(0, rootLength)];
	[layout addTemporaryAttributes:
						[NSDictionary dictionaryWithObject: [NSNumber numberWithInt: NSUnderlineStyleNone]
													forKey: NSUnderlineStyleAttributeName]
			forCharacterRange: NSMakeRange(0, [tmpString length])];

	NSMutableDictionary* linkAttributes =
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithFloat: -0.5],					NSKernAttributeName,
			[NSColor blackColor],								NSForegroundColorAttributeName,
			[NSNumber numberWithInt: NSUnderlineStyleThick],	NSUnderlineStyleAttributeName,
			[NSCursor pointingHandCursor],						NSCursorAttributeName,
			[NSColor blueColor],								NSUnderlineColorAttributeName,
			nil];

	// Make a link on each part of the url. Stop at the root of the repository.
	while (TRUE)
	{
		NSString* tmp = [[tmpString stringByDeletingLastComponent] stringByAppendingString: @"/"];
		const int tmpLength = [tmp length];
		int oldLength = [tmpString length] - 1;
		if ([tmpString characterAtIndex: oldLength] != '/')
			++oldLength;
		NSRange range = { tmpLength, oldLength - tmpLength };

		if (tmpLength < rootLength)
		{
			int l = range.location;
			range.location = 0;
			range.length += l;
		}

		NSString* urlString = EscapeURL(tmpString);
		[linkAttributes setObject: urlString forKey: NSToolTipAttributeName];
		[linkAttributes setObject: urlString forKey: NSLinkAttributeName];
		[[urlTextView textStorage] addAttributes: linkAttributes range: range];   // required to set the link
		[layout addTemporaryAttributes: linkAttributes forCharacterRange: range]; // required to turn it to black

		if (tmpLength < rootLength) break;

		tmpString = tmp;
	}
}


//----------------------------------------------------------------------------------------
//	Handle a click on the repository url (MyRepository is urlTextView's delegate).

- (BOOL) textView:      (NSTextView*) textView
		 clickedOnLink: (id)          link
		 atIndex:       (unsigned)    charIndex
{
	#pragma unused(textView, charIndex)
	if ([link isKindOfClass: [NSString class]])
	{
	//	[svnLogView setRevision: fRevision];		// FIX_ME: call latestRevision:pegRev:
		[self changeRepositoryUrl: [NSURL URLWithString: link]];
		return YES;
	}

	return NO;
}


//----------------------------------------------------------------------------------------

- (NSDictionary*) documentNameDict
{
	return [NSDictionary dictionaryWithObject: windowTitle forKey: @"documentName"];
}


//----------------------------------------------------------------------------------------

- (NSString*) pathAtCurrentRevision: (RepoItem*) repoItem
{
	// <path>@<revision>
	return [NSString stringWithFormat: @"%@@%@", TrimSlashes(repoItem), fRevision];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Log Management
//----------------------------------------------------------------------------------------
// Sort, remove duplicates & return newest revision.

+ (unsigned int) cleanUpLog: (NSMutableArray*) aLog
{
	unsigned int revision = 0,
				 count = [aLog count];
	if (count)
	{
		[aLog sortUsingFunction: compareRevisions context: NULL];
		--count;
		for (unsigned int i = 0; i < count; )		// remove duplicates
		{
			const id rev = getRevision([aLog objectAtIndex: i]);
			++i;
			if ([rev isEqualToString: getRevision([aLog objectAtIndex: i])])
			{
				[aLog removeObjectAtIndex: i];
				--i;
				--count;
			}
		}
		revision = [getRevision([aLog objectAtIndex: 0]) intValue];
	}
	return revision;
}


//----------------------------------------------------------------------------------------

- (void) setLog: (NSMutableArray*) newLog
{
	id oldLog = fLog;
	fLog = [newLog retain];
	[oldLog release];

	fLogRevision = [MyRepository cleanUpLog: newLog];
}


//----------------------------------------------------------------------------------------

- (NSString*) getCachePath
{
	Assert(fRootURL);
	return [MySvn cachePathForKey: [[fRootURL absoluteString] stringByAppendingString: @" repo_log"]];
}


//----------------------------------------------------------------------------------------
// Initiate fetching of repository log entries HEAD thru fLogRevision.

- (void) fetchSvnLog: (SEL) completedMsg
{
	[svnLogView fetchSvn: MakeCallbackInvocation(self, completedMsg)];
}


//----------------------------------------------------------------------------------------
// Initiate fetching of repository log entries HEAD thru fLogRevision.

- (void) fetchSvnLog
{
	[self fetchSvnLog: @selector(svnLogCompleted:)];
}


//----------------------------------------------------------------------------------------

- (void) svnLogCompleted: (id) taskObj
{
	[svnLogView fetchSvnReceiveDataFinished: taskObj];
	[self setLog: [svnLogView logArray]];
}


//----------------------------------------------------------------------------------------
// Initiate fetching of repository info then any new log entries.

- (void) updateLog
{
	[self fetchSvnInfo: @selector(updateLog_InfoCompleted:)];
}


//----------------------------------------------------------------------------------------

- (void) updateLog_InfoCompleted: (id) taskObj
{
	if (!SvnWantAndHave())
		[self svnInfoCompletedCallback: taskObj];
	[self fetchSvnLog];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Repository URL
//----------------------------------------------------------------------------------------

- (NSString*) latestRevision: (NSURL*)    aURL
			  pegRev:         (NSString*) pegRev
{
	#pragma unused(aURL)
	return pegRev;
}


//----------------------------------------------------------------------------------------
// Private:

- (void) browseURL: (NSURL*)    aURL
		 revision:  (NSString*) revision
{
//	dprintf("aURL=<%@> rev. %@=>%@", [aURL absoluteString], fRevision, revision);
	id oldRev = [fRevision retain];
	if (revision != oldRev)
		[svnLogView setRevision: revision];
	[self changeRepositoryUrl: aURL];
	if (revision != oldRev)
		[svnLogView setRevision: oldRev];
	//	[svnBrowserView setRevision: revision];
	[oldRev release];
}


//----------------------------------------------------------------------------------------
// Set browse URL from repository browser

- (void) openItem: (RepoItem*) repoItem
		 revision: (NSString*) pegRevision
{
	if ([repoItem isRoot])
		return;
	NSString* path = [repoItem path];
	if ([repoItem isDir])
		path = [path stringByAppendingString: @"/"];
	if (!pegRevision)
		pegRevision = [repoItem revision];
	//	pegRevision = [repoItem modRev];

//	dprintf("path='%@' revision=%@\n    fURL=<%@>", [path escapeURL], pegRevision, fURL);
	NSURL* aURL = [path isEqualToString: @"/"]
						? [NSURL URLWithString: [[fRootURL absoluteString] stringByAppendingString: @"/"]]
						: [NSURL URLWithString: [path escapeURL] relativeToURL: fURL];
	NSString* rev = [self latestRevision: aURL pegRev: pegRevision];
	[self browseURL: aURL revision: rev];
}


//----------------------------------------------------------------------------------------
// Set browse URL from a path in a log entry

- (void) openLogPath: (NSDictionary*) pathInfo
		 revision:    (NSString*)     pegRevision
{
	NSString* relativePath = getPath(pathInfo);
	NSURL* aURL = [NSURL URLWithString: [[fRootURL absoluteString]
											stringByAppendingString: [relativePath escapeURL]]];
//	dprintf("path='%@' revision=%@\n    aURL=<%@>", [relativePath escapeURL], pegRevision, aURL);
	NSString* rev = [self latestRevision: aURL pegRev: pegRevision];
	[self browseURL: aURL revision: rev];
}


//----------------------------------------------------------------------------------------

- (void) openLogPath: (NSDictionary*) pathInfo
		 forLogEntry: (NSDictionary*) logEntry
{
	[self openLogPath: pathInfo revision: getRevision(logEntry)];
}


//----------------------------------------------------------------------------------------

- (void) changeRepositoryUrl: (NSURL*) anUrl
{
	[self setUrl: anUrl];
	[svnBrowserView setUrl: fURL];
	[self displayUrlTextView];
	[svnLogView resetUrl: fURL];
	[self updateLog];
	[svnBrowserView fetchSvn];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	svn info
//----------------------------------------------------------------------------------------

struct SvnInfoEnv
{
	SvnRevNum		fRevision;
	SvnNodeKind		fKind;
	char			fURL[2048];
};

typedef struct SvnInfoEnv SvnInfoEnv;


//----------------------------------------------------------------------------------------
// Repo 'svn info' callback.  Sets <revision> and <url>.

static SvnError
svnInfoReceiver (void*       baton,
				 const char* path,
				 SvnInfo     info,
				 SvnPool     pool)
{
	#pragma unused(path, pool)
//	dprintf("revision=%d URL=<%s>", info->rev, info->repos_root_URL);
	SvnInfoEnv* env = (SvnInfoEnv*) baton;
	env->fRevision = info->rev;
	env->fKind     = info->kind;
	strncpy(env->fURL, info->repos_root_URL, sizeof(env->fURL));
//	strncpy(env->fUUID, info->repos_UUID, sizeof(env->fUUID));
//	svn_revnum_t last_changed_rev;
//	apr_time_t last_changed_date;
//	const char *last_changed_author;

	return SVN_NO_ERROR;
}


//----------------------------------------------------------------------------------------
// svn info of <fRootURL> via SvnInterface (called by separate thread)

- (void) svnDoInfo: (Message*) completedMsg
{
//	NSLog(@"svn info - begin");
	NSAutoreleasePool* autoPool = [NSAutoreleasePool new];
	SvnPool pool = SvnNewPool();	// Create top-level memory pool.
	@try
	{
		SvnClient ctx = SvnSetupClient(&fSvnEnv, self);

		char path[PATH_MAX * 2];
		if (ToUTF8([fRootURL absoluteString], path, sizeof(path)))
		{
			int len = strlen(path);
			if (len > 0 && path[len - 1] == '/')
				path[len - 1] = 0;
			const SvnOptRevision peg_rev = { svn_opt_revision_head, 0 },
								 rev_opt = { svn_opt_revision_unspecified, 0 };
			SvnInfoEnv env;
			env.fRevision = 0;
			env.fKind     = svn_node_unknown;
			env.fURL[0]   = 0;

		//	dprintf("svn_client_info URL=<%s>", path);
			// Retrive HEAD revision info from repository root.
			SvnThrowIf(svn_client_info(path, &peg_rev, &rev_opt,
									   svnInfoReceiver, &env, !kSvnRecurse,
									   ctx, pool));

		//	fIsFile = (env.fKind == svn_node_file);
			[fRootURL release];
			fRootURL = (NSURL*) CFURLCreateWithBytes(kCFAllocatorDefault,
													 (const UInt8*) env.fURL, strlen(env.fURL),
													 kCFStringEncodingUTF8, NULL);
			fHeadRevision = env.fRevision;
			[self checkRepositoryURL];
		/*	dprintf("'%s' => env.fRevision=%d  fLogRevision=%d fIsFile=%d",
					path, env.fRevision, fLogRevision, fIsFile);*/
			[completedMsg sendToOnMainThread: self];
			[self performSelectorOnMainThread: @selector(displayUrlTextView) withObject: nil waitUntilDone: NO];
		}
	}
	@catch (SvnException* ex)
	{
		SvnReportCatch(ex);
		if (fRevision == nil)	// First time?
		{
			if (fLog != nil)
				[self performSelectorOnMainThread: @selector(setRevision:)
									   withObject: getRevision([fLog objectAtIndex: 0]) waitUntilDone: NO];
			[completedMsg sendToOnMainThread: self];
			[self performSelectorOnMainThread: @selector(displayUrlTextView) withObject: nil waitUntilDone: NO];
		}
		[self performSelectorOnMainThread: @selector(svnError:) withObject: [ex message] waitUntilDone: NO];
	}
	@finally
	{
		SvnDeletePool(pool);
		[autoPool release];
		[completedMsg release];
//		NSLog(@"svn info - end");
	}
}


//----------------------------------------------------------------------------------------
// Get current repository info & send <completedMsg> to self on completion.

- (void) fetchSvnInfo: (SEL) completedMsg
{
	if (!SvnWantAndHave())
	{
		if (completedMsg == NULL)
			completedMsg = @selector(svnInfoCompletedCallback:);
		[MySvn    genericCommand: @"info"
					   arguments: [NSArray arrayWithObject: [fURL absoluteString]]
				  generalOptions: [self svnOptionsInvocation]
						 options: nil
						callback: MakeCallbackInvocation(self, completedMsg)
					callbackInfo: nil
						taskInfo: [self documentNameDict]];
	}
	else
	{
		id message = [[Message alloc] initWithMessage: completedMsg];
		[NSThread detachNewThreadSelector: @selector(svnDoInfo:) toTarget: self withObject: message];
	}
}


//----------------------------------------------------------------------------------------

- (void) fetchSvnInfo
{
	[self fetchSvnInfo: NULL];
}


//----------------------------------------------------------------------------------------

- (void) svnInfoCompletedCallback: (id) taskObj
{
	if (isCompleted(taskObj))
	{
		[self fetchSvnInfoReceiveDataFinished: stdOut(taskObj)];
	}

	[self svnErrorIf: taskObj];
}


//----------------------------------------------------------------------------------------

- (void) fetchSvnInfoReceiveDataFinished: (NSString*) result
{
	NSArray* lines = [result componentsSeparatedByString: @"\n"];
	const int count = [lines count];

	if (count < 5)
	{
		[self svnError: result];
	}
	else
	{
		BOOL isFile = NO;
		NSString* url = nil;
		for (int i = 0; i < count; ++i)
		{
			NSString* line = [lines objectAtIndex: i];
			const int len = [line length];

			if (len > 16 &&
				[[line substringWithRange: NSMakeRange(0, 17)] isEqualToString: @"Repository Root: "])
			{
				url = [line substringFromIndex: 17];
			}
			else if (len > 14 &&
					 [[line substringWithRange: NSMakeRange(0, 15)] isEqualToString: @"Node Kind: file"])
			{
				isFile = TRUE;
			}
			else if (len > 10 &&
					 [[line substringWithRange: NSMakeRange(0, 10)] isEqualToString: @"Revision: "])
			{
				fHeadRevision = [[line substringFromIndex: 10] intValue];
			}
		}
	//	dprintf("isFile=%d fHeadRevision=%d url=<%@>", isFile, fHeadRevision, url);
		if (url != nil)
		{
		//	fIsFile = isFile;
			[fRootURL release];
			fRootURL = [[NSURL URLWithString: url] retain];
			[self displayUrlTextView];
		}
	}
}


//----------------------------------------------------------------------------------------
// If there is a single selected repository-browser item then return it else return nil.
// Private:

- (RepoItem*) selectedItemOrNil
{
	return [svnBrowserView selectedItemOrNil];
}


//----------------------------------------------------------------------------------------
// Get the deepest selected directory from the repository-browser.
// Private:

- (RepoItem*) selectedDirectory
{
	RepoItem* dir = nil;
	NSArray* const selectedObjects = [svnBrowserView selectedItems];
	if ([selectedObjects count] > 0)
		dir = [selectedObjects objectAtIndex: 0];

	if (dir == nil || ![dir isDir])
	{
		NSBrowser* browser = [svnBrowserView valueForKey: @"browser"];
		int col = [browser selectedColumn] - 1;
		col = MAX(col, 0);
		int row = [browser selectedRowInColumn: col];
		row = MAX(row, 0);
		dir = [[[browser matrixInColumn: col] cellAtRow: row column: 0] representedObject];
	}

	return dir;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	svn operations

- (IBAction) svnCopy: (id) sender
{
	#pragma unused(sender)
	RepoItem* selection = [self selectedItemOrNil];
	if (!selection)
	{
		[self svnError: @"Please select exactly one item to copy."];
	}
	else if ([selection isRoot])
	{
		[self svnError: @"Can't copy root folder."];
	}
	else
	{
		[MySvnOperationController runSheet: kSvnCopy repository: self url: fURL sourceItem: selection];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) svnMove: (id) sender
{
	#pragma unused(sender)
	RepoItem* selection = [self selectedItemOrNil];
	if (!selection)
	{
		[self svnError: @"Please select exactly one item to move."];
	}
	else if ([selection isRoot])
	{
		[self svnError: @"Can't move root folder."];
	}
	else
	{
		[MySvnOperationController runSheet: kSvnMove repository: self url: fURL sourceItem: selection];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) svnMkdir: (id) sender
{
	#pragma unused(sender)
	[MySvnOperationController runSheet: kSvnMkdir repository: self url: fURL sourceItem: nil];
}


//----------------------------------------------------------------------------------------

- (IBAction) svnDelete: (id) sender
{
	#pragma unused(sender)
	[MySvnOperationController runSheet: kSvnDelete repository: self url: fURL sourceItem: nil];
}


//----------------------------------------------------------------------------------------

- (IBAction) svnFileMerge: (id) sender
{
	[self svnDiff: sender];
}


//----------------------------------------------------------------------------------------
// Return TRUE if there is no sheet blocking this window, otherwise beep & return FALSE.

- (BOOL) noSheet
{
	if ([[self window] attachedSheet])
	{
		NSBeep();
		return FALSE;
	}
	return TRUE;
}


//----------------------------------------------------------------------------------------

- (void) diff:    (id) fileURLs
		 options: (id) options
{
	if (!ISA(fileURLs, NSArray))
		fileURLs = [NSArray arrayWithObject: fileURLs];
	if (options && !ISA(options, NSArray))
		options = [NSArray arrayWithObject: options];
	[MySvn      diffItems: fileURLs
		   generalOptions: [self svnOptionsInvocation]
				  options: options
				 callback: MakeCallbackInvocation(self, @selector(svnErrorIf:))
			 callbackInfo: nil
				 taskInfo: [self documentNameDict]];
}


//----------------------------------------------------------------------------------------

- (void) diff:     (id)        fileURLs
		 revision: (NSString*) revision
{
	Assert(revision);
	[self diff: fileURLs options: [NSArray arrayWithObjects: @"-c", revision, nil]];
}


//----------------------------------------------------------------------------------------
// Diff PREV or sheet of the selected log-item, log-item path or repository-items.

- (IBAction) svnDiff: (id) sender
{
	if (![self noSheet])
		return;
	const bool useSheet = wantsOption(sender);
	NSDictionary* target = [svnLogView targetSvnItem];
	if (target)											// log-item or log-item path?
	{
		const id path     = getPath(target),
				 revision = [svnLogView selectedRevision],
				 url      = path ? [NSURL URLWithString: [self pathToURL: path]] : fURL;
		const int action  = getAction(target);
		if (url == nil || revision == nil || (useSheet && path == nil))
		{
			NSBeep();
		}
		else if (useSheet)								// diff sheet for highlighted changed-path
		{
			// Only display diff sheet if action is modify, replace or add with history
			if (action == 'M' || action == 'R' || (action == 'A' && [target objectForKey: @"copyfrompath"] != nil))
				[MyFileMergeController runSheet: self url: url revision: revision];
			else	// Added or deleted path...
				NSBeep();
		}
		else											// last change of highlighted changed-path
		{												// or highlighted change of repository-URL
			const id newURL = PathPegRevision(url, revision);
			NSString* str;
			if (path && (str = [target objectForKey: @"copyfrompath"]) != nil)
			{
				// svn diff <src-URL>@src-rev <new-URL>@sel-rev
				[self diff: [NSArray arrayWithObjects:
										PathPegRevision([self pathToURL: str],
														[target objectForKey: @"copyfromrev"]),
										newURL, nil]
						  options: nil];
			}
			else if (!path || action == 'M' || action == 'R')
			{
				[self diff: newURL revision: revision];
			}
			else	// Added or deleted path...
				NSBeep();
		}
	}
	else if ([svnBrowserView isFirstResponder])
	{
		NSArray* const repoItems = [svnBrowserView selectedItems];
		if (useSheet)									// diff sheet for repository-item
		{
			if ([repoItems count])
			{
				RepoItem* repoItem = [repoItems objectAtIndex: 0];
				[MyFileMergeController runSheet: self url: [repoItem url] revision: [repoItem revision]];
			}
			else
				NSBeep();
		}
		else											// last change of repository-items
		{
			for_each_obj(en, item, repoItems)
			{
				[self diff: [item pathPegRevision] revision: [item modRev]];
			}
		}
	}
	else
		NSBeep();
}


//----------------------------------------------------------------------------------------

- (IBAction) svnBlame: (id) sender
{
	if (![self noSheet])
		return;
	NSMutableArray* files = [NSMutableArray array];
	id revision = nil;
	NSDictionary* target = [svnLogView targetSvnItem];
	if (target)												// log-item or log-item path?
	{
		const id path = getPath(target);
		if (path)											// log-item path?
		if (getAction(target) != 'D')						// not delete?
		{
			revision = [svnLogView selectedRevision];
			[files addObject: PathPegRevision([self pathToURL: path], revision)];
			[files addObject: [path lastPathComponent]];
		}
	}
	else if ([svnBrowserView isFirstResponder])
	{
		for_each_obj(en, item, [svnBrowserView selectedItems])
		{
			if ([item isDir]) continue;
			[files addObject: [item pathPegRevision]];
			[files addObject: [item name]];
		}

		if ([files count] == 0)
		{
			[self svnError: @"Please select one or more repository files."];
			return;
		}
	}

	if ([files count] != 0)
	{
		[MySvn blame:          files		// URL@rev, file-name pairs
			   revision:       revision ? revision : [self revision]
			   generalOptions: [self svnOptionsInvocation]
			   options:        [NSArray arrayWithObjects: wantsOption(sender) ? @"--verbose" : @"", nil]
			   callback:       MakeCallbackInvocation(self, @selector(svnErrorIf:))
			   callbackInfo:   nil
			   taskInfo:       [self documentNameDict]];
	}
	else
		NSBeep();
}


//----------------------------------------------------------------------------------------
// Report sheet: Setup views & open sheet

- (IBAction) svnReport: (id) sender
{
	#pragma unused(sender)

	[self requestReport];
}


//----------------------------------------------------------------------------------------
// Export & open the selected files/folders

- (void) openFiles: (NSArray*) repoItems
{
	FSRef tempFolder;
	if (Folder_TemporaryItems(&tempFolder))
	{
		NSURL* folderURL = (NSURL*) CFURLCreateFromFSRef(NULL, &tempFolder);
		if (folderURL != nil)
		{
			[self exportFiles: repoItems
					 toFolder: [folderURL autorelease] includeRev: YES openAfter: YES];
		}
	}
}


//----------------------------------------------------------------------------------------
// Export & open the selected files/folders

- (IBAction) svnOpen: (id) sender
{
	#pragma unused(sender)
	if (![self noSheet])
		return;
	NSArray* files = nil;
	NSDictionary* target = [svnLogView targetSvnItem];
	if (target)												// log-item or log-item path?
	{
		const id path     = getPath(target),
				 revision = [svnLogView selectedRevision],
				 url      = path ? [self pathToURL: path] : nil;
		if (url != nil && revision != nil)					// log-item path?
		if (getAction(target) != 'D')						// not delete?
		{
			RepoItem* repoItem = [RepoItem repoPath: path
										   revision: SvnRevNumFromString(revision)
												url: fURL];
			[repoItem svnInfo: self];
			files = [NSArray arrayWithObject: repoItem];
		}
	}
	else if ([svnBrowserView isFirstResponder])
	{
		files = [svnBrowserView selectedItems];
	}

	if ([files count] != 0)
	{
		[self openFiles: files];
	}
	else
		NSBeep();
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Report Sheet
//----------------------------------------------------------------------------------------

enum {
	vReportKind				=	100,
	vReportPaths			=	101,
	vReportCrossCopies		=	102,
	vReportLimit			=	103,
	vReportLimitNum			=	104,
	vReportRelativeDates	=	105,
	vReportReverseOrder		=	106,
	kReportKindURL			=	0,
	kReportKindCurrentLog	=	1,
	kReportLimitDefault		=	1000,
	kReportLimitMin			=	1,
	kReportLimitMax			=	1000000
};


//----------------------------------------------------------------------------------------
// Report sheet: Setup views & open sheet

- (void) requestReport
{
	NSWindow* const sheet = fLogReportSheet;
	NSView* const views = [sheet contentView];

	NSMatrix* kinds = GetView(views, vReportKind);
	[[kinds cellWithTag: kReportKindURL] setTitle: UnEscapeURL([self browsePath])];
	[kinds selectCellWithTag: (IsViewInResponderChain(svnLogView) ? kReportKindCurrentLog : kReportKindURL)];

	NSControl* const limitView = GetView(views, vReportLimitNum);
	const int reportLimitNum = [limitView intValue];
	if (reportLimitNum < kReportLimitMin || reportLimitNum > kReportLimitMax)
		[limitView setIntValue: kReportLimitDefault];
	[limitView setEnabled: GetViewInt(views, vReportLimit)];

	[NSApp beginSheet:     sheet
		   modalForWindow: [self window]
		   modalDelegate:  self
		   didEndSelector: @selector(reportSheetDidEnd:returnCode:contextInfo:)
		   contextInfo:    (void*) NULL];
}


//----------------------------------------------------------------------------------------
// Report sheet: Read views & create report

- (void) reportFromSheet: (NSWindow*) sheet
{
	NSView* const views = [sheet contentView];
	const bool isCurrentLog = ([[GetView(views, vReportKind) selectedCell] tag] == kReportKindCurrentLog),
			   reportPaths  = GetViewInt(views, vReportPaths),
			   reportCopies = GetViewInt(views, vReportCrossCopies),
			   reportLimit  = GetViewInt(views, vReportLimit),
			   reportDates  = GetViewInt(views, vReportRelativeDates),
			   reverseOrder = GetViewInt(views, vReportReverseOrder);
	const int reportLimitNum = reportLimit ? GetViewInt(views, vReportLimitNum) : 0;

	[SvnLogReport createFor:     self
				  url:           (isCurrentLog ? [fURL absoluteString] : [self browsePath])
				  logItems:      (isCurrentLog ? [svnLogView arrangedObjects] : nil)
				  revision:      fRevision
				  limit:         reportLimitNum
				  pageLength:    0
				  verbose:       reportPaths
				  stopOnCopy:    !reportCopies
				  relativeDates: reportDates
				  reverseOrder:  reverseOrder];
}


//----------------------------------------------------------------------------------------
// Report sheet: Limit checkbox clicked

- (IBAction) reportLimit: (id) sender
{
	NSWindow* const window = [sender window];
	NSView* const views = [window contentView];

	NSControl* const limitView = GetView(views, vReportLimitNum);
	const bool enable = GetViewInt(views, vReportLimit);
	[limitView setEnabled: enable];
	if (enable)
		[window selectNextKeyView: self];
}


//----------------------------------------------------------------------------------------
// Report sheet: OK button clicked

- (IBAction) reportOKed: (id) sender
{
	NSWindow* const window = [sender window];
	NSControl* const limitView = GetView([window contentView], vReportLimitNum);
	[limitView validateEditing];
	const int reportLimitNum = [limitView intValue];
	if (![limitView isEnabled] ||
		(reportLimitNum >= kReportLimitMin && reportLimitNum <= kReportLimitMax))
	{
		[NSApp endSheet: window returnCode: NSOKButton];
	}
	else
	{
		[limitView setIntValue: kReportLimitDefault];
		[window selectNextKeyView: self];
		NSBeep();
	}
}


//----------------------------------------------------------------------------------------
// Report sheet: Cancel button clicked

- (IBAction) reportCancelled: (id) sender
{
	[NSApp endSheet: [sender window] returnCode: NSCancelButton];
}


//----------------------------------------------------------------------------------------
// Report sheet: dismissed

- (void) reportSheetDidEnd: (NSWindow*) sheet
		 returnCode:        (int)       returnCode
		 contextInfo:       (void*)     contextInfo
{
	#pragma unused(contextInfo)
	[sheet orderOut: self];
	if (returnCode == NSOKButton)
		[self reportFromSheet: sheet];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Checkout, Export
//----------------------------------------------------------------------------------------
// Private:

- (void) chooseAny:      (NSString*) message
		 allowFiles:     (BOOL)      allowFiles
		 didEndSelector: (SEL)       didEndSelector
		 contextInfo:    (void*)     contextInfo
{
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];

	[oPanel setAllowsMultipleSelection: NO];
	[oPanel setCanChooseDirectories:    YES];
	[oPanel setCanChooseFiles:          allowFiles];
	[oPanel setCanCreateDirectories:    !allowFiles];
	[oPanel setMessage: message];

	[oPanel beginSheetForDirectory: NSHomeDirectory() file: nil types: nil
					modalForWindow: [self windowForSheet]
					 modalDelegate: self
					didEndSelector: didEndSelector
					   contextInfo: contextInfo];
}


//----------------------------------------------------------------------------------------
// Private:

- (void) chooseFolder:   (NSString*) message
		 didEndSelector: (SEL)       didEndSelector
		 contextInfo:    (void*)     contextInfo
{
	[self chooseAny: message allowFiles: NO didEndSelector: didEndSelector contextInfo: contextInfo];
}


//----------------------------------------------------------------------------------------
// Private:

- (void) checkout: (RepoItem*) repoItem
		 toFolder: (NSString*) destinationPath
{
	[self setDisplayedTaskObj:
		[MySvn    checkout: [self pathAtCurrentRevision: repoItem]
			   destination: destinationPath
			generalOptions: [self svnOptionsInvocation]
				   options: [NSArray arrayWithObjects: @"-r", fRevision, nil]
				  callback: [self makeExtractedCallback]
			  callbackInfo: destinationPath
				  taskInfo: [self documentNameDict]]
	];

	// TL : Creating new working copy for the checked out path.
	if (GetPreferenceBool(@"addWorkingCopyOnCheckout"))
	{
		[[NSNotificationCenter defaultCenter] postNotificationName: @"newWorkingCopy" object: destinationPath];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) svnExport: (id) sender
{
	#pragma unused(sender)
	NSArray* const selectedObjects = [svnBrowserView selectedItems];
	const int count = [selectedObjects count];
	NSString* message = (count == 1)
				? [NSString stringWithFormat: @"Export %C%@%C into folder:", 0x201C,
											  [[selectedObjects lastObject] name], 0x201D]
				: [NSString stringWithFormat: @"Export %d items into folder:", count];

	[self chooseFolder: message
		didEndSelector: @selector(exportPanelDidEnd:returnCode:contextInfo:)
		   contextInfo: [selectedObjects retain]];
}


//----------------------------------------------------------------------------------------

- (IBAction) svnCheckout: (id) sender
{
	#pragma unused(sender)
	RepoItem* selection = [self selectedItemOrNil];
	if (!selection || ![selection isDir])
	{
		[self svnError: @"Please select exactly one folder to checkout."];
	}
	else
	{
		NSString* message = [NSString stringWithFormat: @"Checkout %C%@%C into folder:",
														0x201C, [selection name], 0x201D];
		[self chooseFolder: message
			didEndSelector: @selector(checkoutPanelDidEnd:returnCode:contextInfo:)
			   contextInfo: selection];
	}
}


//----------------------------------------------------------------------------------------

- (void) checkoutPanelDidEnd: (NSOpenPanel*) sheet
		 returnCode:          (int)          returnCode
		 contextInfo:         (void*)        contextInfo
{
	if (returnCode == NSOKButton)
	{
		[self checkout: (RepoItem*) contextInfo
			  toFolder: [[sheet filenames] objectAtIndex: 0]];
	}
}


//----------------------------------------------------------------------------------------
// Private:

- (NSArray*) exportFiles: (NSArray*) fileObjs
			 toFolder:    (NSURL*)   folderURL
			 includeRev:  (BOOL)     includeRev
			 openAfter:   (BOOL)     openAfter
{
	NSString* const destPath = [folderURL path];
	NSMutableArray* arguments = [NSMutableArray arrayWithObject: openAfter ? GetDiffAppName() : @""];
	NSMutableArray* fileNames = [NSMutableArray array];

	// We use a single shell script to do all because we want to
	// handle it as a single task (that will be easier to terminate)

	includeRev = includeRev && GetPreferenceBool(@"includeRevisionInName");
	for_each_obj(enumerator, item, fileObjs)
	{
		NSString* name = [item name];
		if (includeRev)									// 'name' => 'r# name'
			name = [NSString stringWithFormat: @"r%u %@", [item revisionNum], name];
		// operation, sourcePath, destinationPath
		[arguments addObject: [item isDir] ? @"e"		// folder => svn export (see svnextract.sh)
										   : @"c"];		// file   => svn cat
		[arguments addObject: [self pathAtCurrentRevision: item]];
		[arguments addObject: [destPath stringByAppendingPathComponent: name]];
		[fileNames addObject: name];
	}

	// We used to call `extractItems: arguments options: NewArray(@"-r", fRevision)`
	// But the Subversion docs are wrong (1.4.5-1.6.6) and -r REV is not required (or wanted).
	[self setDisplayedTaskObj:
		[MySvn	extractItems: arguments
			  generalOptions: [self svnOptionsInvocation]
					 options: [NSArray array]
					callback: [self makeExtractedCallback]
				callbackInfo: destPath
					taskInfo: [self documentNameDict]]
	];

	return fileNames;
}


//----------------------------------------------------------------------------------------
// Private:

- (NSArray*) exportFiles:   (NSArray*) fileObjs
			 toFolder:      (NSURL*)   folderURL
{
	return [self exportFiles: fileObjs toFolder: folderURL includeRev: NO openAfter: NO];
}


//----------------------------------------------------------------------------------------
// Private:

- (void) checkoutFiles: (NSArray*) repoItems
		 toFolder:      (NSURL*)   folderURL
{
	RepoItem* repoItem = [repoItems objectAtIndex: 0]; // one checks out no more than one directory

	[self checkout: repoItem
		  toFolder: [[folderURL path] stringByAppendingPathComponent: [repoItem name]]];
}


//----------------------------------------------------------------------------------------

- (void) exportPanelDidEnd: (NSOpenPanel*) sheet
		 returnCode:        (int)          returnCode
		 contextInfo:       (void*)        contextInfo
{
	NSArray* selectedObjects = contextInfo;

	if (returnCode == NSOKButton)
	{
		NSURL* folderURL = [NSURL fileURLWithPath: [[sheet filenames] objectAtIndex: 0]];
		[self exportFiles: [self userValidatedFiles: selectedObjects forDestination: folderURL]
			  toFolder:    folderURL];
	}

	[selectedObjects release];
}


//----------------------------------------------------------------------------------------

- (void) extract_Completed: (id) taskObj
{
	// let the Finder know about the operation (required for Panther)
	[[NSWorkspace sharedWorkspace] noteFileSystemChanged: callbackInfo(taskObj)];

	[self svnErrorIf: taskObj];
}


//----------------------------------------------------------------------------------------

- (void) dragOutFilesFromRepository: (NSArray*) filesDicts
		 toURL:                      (NSURL*)   destinationURL
{
	NSArray* validatedFiles = [self userValidatedFiles: filesDicts forDestination: destinationURL];
	BOOL isCheckout = FALSE;	// -> export by default

	if ([validatedFiles count] == 1 && [[validatedFiles lastObject] isDir])
	{
		NSAlert* alert =
			[NSAlert alertWithMessageText: @"Extract the folder versioned (checkout) or unversioned (export)?"
					 defaultButton:        @"Export"
					 alternateButton:      @"Cancel"
					 otherButton:          @"Checkout"
					 informativeTextWithFormat: @""];
		[alert setAlertStyle: NSWarningAlertStyle];

		switch ([alert runModal])
		{
			case NSAlertDefaultReturn:		// Unversioned -> export
				isCheckout = FALSE;
				break;

			case NSAlertOtherReturn:		// Versioned -> checkout
				isCheckout = TRUE;
				break;

			default:						// Cancel
				return;
		}
	}

	if (isCheckout)		// => checkout
	{
		[self checkoutFiles: validatedFiles toFolder: destinationURL];
	}
	else				// => export
	{
		[self exportFiles: validatedFiles toFolder: destinationURL];
	}
}


//----------------------------------------------------------------------------------------

- (NSArray*) deliverFiles: (NSArray*) fileObjs
			 toFolder:     (NSURL*)   folderURL
			 isTemporary:  (BOOL)     isTemporary
{
	NSArray* fileNames = nil;
	if (isTemporary)
	{
		fileNames = [self exportFiles: fileObjs toFolder: folderURL includeRev: YES openAfter: NO];
		// Try and wait for export to finish before returning so that dropping on an app icon
		// or in an app window will succeed.  If the files don't exist those drags will fail.
		if (displayedTaskObj)
		{
			NSTask* const task = [displayedTaskObj objectForKey: @"task"];
			// Wait up to 30 seconds but exit asap.
			for (int i = 0; [task isRunning] && i < 30 * 16; ++i)
				[NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0 / 16]];
		}
	}
	else
		[self dragOutFilesFromRepository: fileObjs toURL: folderURL];
	return fileNames;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Import
//----------------------------------------------------------------------------------------

enum {
	vImportSource	=	10,
	vImportDest,
	vImportName,
	vImportRecursive
};


//----------------------------------------------------------------------------------------

- (IBAction) svnImport: (id) sender
{
	#pragma unused(sender)
	RepoItem* destDir = [self selectedDirectory];
	Assert(destDir != nil);
	if (destDir != nil)
	{
		[self chooseAny:    [NSString stringWithFormat: @"Import into %C%@%C:", 0x201C,
														UnEscapeURL([destDir url]), 0x201D]
			allowFiles:     YES
			didEndSelector: @selector(importPanelDidEnd:returnCode:contextInfo:)
			contextInfo:    [destDir retain]];
	}
}


//----------------------------------------------------------------------------------------

- (void) importPanelDidEnd: (NSOpenPanel*) sheet
		 returnCode:        (int)          returnCode
		 contextInfo:       (void*)        contextInfo
{
	RepoItem* destDir = contextInfo;

	if (returnCode == NSOKButton)
	{
		[sheet orderOut: self];
		[self importFiles: [sheet filenames] intoFolder: destDir];
	}

	[destDir release];
}


//----------------------------------------------------------------------------------------

- (void) importFiles: (NSArray*)  files
		 intoFolder:  (RepoItem*) destRepoDir
{
	// Abort if any sheet already open
	if (![self noSheet])
		return;

	// Setup name, source & destination fields
	NSString* const filePath = [files objectAtIndex: 0];
	[fileNameTextField setStringValue: [filePath lastPathComponent]];
	WSetViewString(importCommitPanel, vImportSource, GetPreferenceBool(@"abbrevWCFilePaths")
											? [filePath stringByAbbreviatingWithTildeInPath] : filePath);
	WSetViewString(importCommitPanel, vImportDest, [[destRepoDir path] stringByAppendingString: @"/"]);

	// Recursive checkbox only shown for directories
	BOOL isDir = FALSE;
	NSButton* const recursive = WGetView(importCommitPanel, vImportRecursive);
	if (recursive)
	{
		[recursive setHidden: !([[NSFileManager defaultManager]
									fileExistsAtPath: filePath isDirectory: &isDir] && isDir)];
		if (isDir)
			[recursive setState: NSOnState];
	}

	[NSApp beginSheet:     importCommitPanel
		   modalForWindow: [self windowForSheet]
		   modalDelegate:  self
		   didEndSelector: @selector(importCommitPanelDidEnd:returnCode:contextInfo:)
		   contextInfo:    [[NSDictionary dictionaryWithObjectsAndKeys:
										TrimSlashes(destRepoDir), @"destination",
										filePath,                 @"filePath",
										NSBool(isDir),            @"isDir",
										nil] retain]
	];
}


//----------------------------------------------------------------------------------------

- (void) receiveFiles:   (NSArray*)  files
		 toRepositoryAt: (RepoItem*) destRepoDir
{
	[self importFiles: files intoFolder: destRepoDir];
}


//----------------------------------------------------------------------------------------

- (void) importCommitPanelDidEnd: (NSPanel*) sheet
		 returnCode:              (int)      returnCode
		 contextInfo:             (void*)    contextInfo
{
	[sheet orderOut: self];

	NSDictionary* dict = contextInfo;

	if (returnCode == NSOKButton)
	{
		id recursive = ([dict objectForKey: @"isDir"] == kNSTrue &&
						WGetViewInt(sheet, vImportRecursive) == NSOffState) ? @"-N" : nil;
		[self setDisplayedTaskObj:
			[MySvn		import: [dict objectForKey: @"filePath"]
				   destination: [NSString stringWithFormat: @"%@/%@",
									[dict objectForKey: @"destination"], [fileNameTextField stringValue]]
											// stringByAppendingPathComponent would eat svn:// into svn:/ !
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-m", MessageString([commitTextView string]),
														   recursive, nil]
					  callback: [self makeCommandCallback]
				  callbackInfo: nil
					  taskInfo: [self documentNameDict]]
			];
	}

	[dict release];
}


//----------------------------------------------------------------------------------------

- (IBAction) importCommitPanelValidate: (id) sender
{
	[NSApp endSheet: importCommitPanel returnCode: [sender tag]];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

- (void) sheetDidEnd: (NSWindow*) sheet
		 returnCode:  (int)       returnCode
		 contextInfo: (void*)     contextInfo
{
	[sheet orderOut: nil];

	MySvnOperationController* const controller = contextInfo;

	if (returnCode == NSOKButton)
	{
		const SvnOperation operation = [controller operation];
		NSString* sourceUrl = nil, *targetUrl = nil, *commitMessage = nil;

		if (operation == kSvnCopy || operation == kSvnMove)
		{
			sourceUrl = [[[self selectedItemOrNil] url] absoluteString];
			targetUrl = [[controller getTargetUrl] absoluteString];
		}
		if (operation != kSvnDiff)
			commitMessage = [controller getCommitMessage];

		switch (operation)
		{
		case kSvnCopy:
			[MySvn		  copy: sourceUrl
				   destination: targetUrl
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-r", fRevision, @"-m", commitMessage, nil]
					  callback: [self makeCommandCallback]
				  callbackInfo: nil
					  taskInfo: [self documentNameDict]];
			break;

		case kSvnMove:
			[MySvn		  move: sourceUrl
				   destination: targetUrl
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-m", commitMessage, nil]
					  callback: [self makeCommandCallback]
				  callbackInfo: nil
					  taskInfo: [self documentNameDict]];
			break;

		case kSvnMkdir:									// Some Key-Value coding magic !! (multiple directories)
			[MySvn		 mkdir: [[controller getTargets] mutableArrayValueForKeyPath: @"url.absoluteString"]
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-m", commitMessage, nil]
					  callback: [self makeCommandCallback]
				  callbackInfo: nil
					  taskInfo: [self documentNameDict]];
			break;

		case kSvnDelete:								// Some Key-Value coding magic !! (multiple directories)
			[MySvn		delete: [[controller getTargets] mutableArrayValueForKeyPath: @"url.absoluteString"]
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-m", commitMessage, nil]
					  callback: [self makeCommandCallback]
				  callbackInfo: nil
					  taskInfo: [self documentNameDict]];
			break;

	//	case kSvnDiff:
	//		break;
		}
	}

	[controller finished];
}


//----------------------------------------------------------------------------------------

- (void) svnCommand_Completed: (id) taskObj
{
	if (isCompleted(taskObj))
	{
		[self fetchSvnInfo: @selector(svnCommand_InfoCompleted:)];
	}

	[self svnErrorIf: taskObj];
}


//----------------------------------------------------------------------------------------

- (void) svnCommand_InfoCompleted: (id) taskObj
{
	if (!SvnWantAndHave() && isCompleted(taskObj))
	{
		[self fetchSvnInfoReceiveDataFinished: stdOut(taskObj)];
	}

	if (fHeadRevision > fLogRevision)
	{
		[self fetchSvnLog: @selector(svnCommand_LogCompleted:)];
	}
	else
	{
		[self updateLog_InfoCompleted: taskObj];
	}
}


//----------------------------------------------------------------------------------------
// Select HEAD item in log (after a copy, move, mkdir, delete or import)

- (void) svnCommand_LogCompleted: (id) taskObj
{
	[self svnLogCompleted: taskObj];

	if (isCompleted(taskObj) && [fLog count] > 0)
	{
		[self setRevision: getRevision([fLog objectAtIndex: 0])];
		[svnLogView setCurrentRevision: fRevision];
	}
}


//----------------------------------------------------------------------------------------

- (BOOL) svnErrorIf: (id) taskObj
{
	NSString* errText = stdErr(taskObj);
	if (errText)
	{
		[self svnError: errText];
		return TRUE;
	}

	return FALSE;
}


//----------------------------------------------------------------------------------------

- (void) svnError: (NSString*) errorString
{
	[self performSelector: @selector(doSvnError:) withObject: errorString afterDelay: 0.1];
}


//----------------------------------------------------------------------------------------

- (void) doSvnError: (NSString*) errorString
{
	const BOOL wasErrorShown = fIsErrorShown;
	fIsErrorShown = YES;
//	dprintf("wasErrorShown=%d \"%@\"", wasErrorShown, errorString);
	Assert(errorString);
	NSWindow* const window = [self window];
	if ([window isVisible])
	{
		[svnLogView     setIsFetching: NO];
		[svnBrowserView setIsFetching: NO];

		if (!wasErrorShown)
		{
			NSBeep();
			NSAlert* alert = [NSAlert alertWithMessageText: @"svn Error"
											 defaultButton: @"OK"
										   alternateButton: nil
											   otherButton: nil
								 informativeTextWithFormat: @"%@", errorString];

			NSWindow* const sheet = [window attachedSheet];
			[alert setAlertStyle: NSCriticalAlertStyle];
			[alert beginSheetModalForWindow: sheet ? sheet : window
							  modalDelegate: self
							 didEndSelector: @selector(svnError_SheetEnded:returnCode:contextInfo:)
								contextInfo: nil];
		}
	}
}


//----------------------------------------------------------------------------------------

- (void) svnError_SheetEnded: (NSAlert*) alert
		 returnCode:          (int)      returnCode
		 contextInfo:         (void*)    contextInfo
{
	#pragma unused(alert, returnCode, contextInfo)
	fIsErrorShown = NO;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Helpers

- (NSArray*) userValidatedFiles: (NSArray*) files
			 forDestination:     (NSURL*)   destinationURL
{
	NSMutableArray* validatedFiles = [NSMutableArray array];
	BOOL yesToAll = NO;

	for_each_obj(enumerator, item, files)
	{
		if (yesToAll)
		{
			[validatedFiles addObject: item];

			continue;
		}

		NSString* const name = [item name];
		if ([[NSFileManager defaultManager]
					fileExistsAtPath: [[destinationURL path] stringByAppendingPathComponent: name]])
		{
			NSAlert* alert = [[NSAlert alloc] init];
			int alertResult;

			[alert addButtonWithTitle: @"Yes"];
			[alert addButtonWithTitle: @"No"];

			if ([files count] > 1)
			{
				[alert addButtonWithTitle: @"Cancel All"];
				[alert addButtonWithTitle: @"Yes to All"];
			}

			[alert setMessageText: [NSString stringWithFormat: @"%C%@%C already exists at destination.",
															   0x201C, [name trimSlashes], 0x201D]];
			[alert setInformativeText: @"Do you want to replace it?"];
			[alert setAlertStyle: NSWarningAlertStyle];

			alertResult = [alert runModal];

			if (alertResult == NSAlertThirdButtonReturn)		// Cancel All
			{
				return [NSArray array];
			}
			else if (alertResult == NSAlertSecondButtonReturn)	// No
			{
				// don't add
			}
			else if (alertResult == NSAlertFirstButtonReturn)	// Yes
			{
				[validatedFiles addObject: item];
			}
			else
			{
				yesToAll = YES;
				[validatedFiles addObject: item];
			}

			[alert release];
		}
		else
		{
			[validatedFiles addObject: item];
		}
	}

	return validatedFiles;
}


//----------------------------------------------------------------------------------------

- (NSMutableDictionary*) getSvnOptions
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys: user, @"user", pass, @"pass", nil];
}


//----------------------------------------------------------------------------------------

- (NSInvocation*) makeSvnOptionInvocation
{
	return MakeCallbackInvocation(self, @selector(getSvnOptions));
}


//----------------------------------------------------------------------------------------

- (NSInvocation*) makeCommandCallback
{
	return MakeCallbackInvocation(self, @selector(svnCommand_Completed:));
}


//----------------------------------------------------------------------------------------

- (NSInvocation*) makeExtractedCallback
{
	return MakeCallbackInvocation(self, @selector(extract_Completed:));
}


//----------------------------------------------------------------------------------------

- (int) svnStdOptions: (id[]) objs
{
	int count = 0;
	if ([user length])
	{
		objs[count++] = @"--username";
		objs[count++] = user;

		if ([pass length])
		{
			objs[count++] = @"--password";
			objs[count++] = pass;
		}
	}

	objs[count++] = @"--non-interactive";
//	if (HasSvnV1_6() && GetPreferenceBool(@"trustServerCert"))
//		objs[count++] = @"--trust-server-cert";
	Assert(count <= 6);
	return count;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Document delegate
//----------------------------------------------------------------------------------------

- (void) canCloseDocumentWithDelegate: (id)    delegate
		 shouldCloseSelector:          (SEL)   shouldCloseSelector
		 contextInfo:                  (void*) contextInfo
{
	// tell the task center to cancel pending callbacks to prevent crash
	[Tasks cancelCallbacksOnTarget: self];

	[super canCloseDocumentWithDelegate: delegate
		   shouldCloseSelector:          shouldCloseSelector
		   contextInfo:                  contextInfo];
}


//----------------------------------------------------------------------------------------
// Disable Copy, Move, Mkdir & Delete toolbar items if root URL is a file

- (BOOL) validateToolbarItem: (NSToolbarItem*) theItem
{
	static NSSet* ids = nil;
	if (ids == nil)
		ids = [[NSSet setWithObjects: @"svnCopy", @"svnMove", @"svnMkdir", @"svnDelete", nil] retain];

	return !fIsFile || ![ids containsObject: [theItem itemIdentifier]];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Accessors
//----------------------------------------------------------------------------------------

- (NSString*) user	{ return user; }

- (NSString*) pass	{ return pass; }


//----------------------------------------------------------------------------------------

- (NSInvocation*) svnOptionsInvocation
{
	return [self makeSvnOptionInvocation];
}


//----------------------------------------------------------------------------------------
// displayedTaskObj

- (NSMutableDictionary*) displayedTaskObj { return displayedTaskObj; }

- (void) setDisplayedTaskObj: (NSMutableDictionary*) aDisplayedTaskObj
{
	id old = displayedTaskObj;
	displayedTaskObj = [aDisplayedTaskObj retain];
	[old release];
}


//----------------------------------------------------------------------------------------

- (BOOL) rootIsFile { return fIsFile; }


//----------------------------------------------------------------------------------------

- (NSURL*) rootURL { return fRootURL; }


//----------------------------------------------------------------------------------------
// url

- (NSURL*) url { return fURL; }

- (void) setUrl: (NSURL*) anUrl
{
	id old = fURL;
	fURL = [anUrl retain];
	[old release];
	NSString* const str = [anUrl relativeString];
	fIsFile = ([str characterAtIndex: [str length] - 1] != '/');
}


//----------------------------------------------------------------------------------------
// Private:
// Check & repair fURL if it doesn't start with fRootURL.

- (void) checkRepositoryURL
{
	Assert(fRootURL != nil);
	Assert(fURL != nil);
	NSString* const rootURL = [fRootURL absoluteString],
			* const url     = [fURL absoluteString];
	if ([rootURL length] > [url length] ||
		[url rangeOfString: rootURL options: NSLiteralSearch | NSAnchoredSearch].location != 0)
	{
		dprintf("\n    fRootURL=<%@>\n        fURL=<%@> *BAD*", UnEscapeURL(fRootURL), UnEscapeURL(fURL));
		[self setUrl: fRootURL];
	}
}


//----------------------------------------------------------------------------------------
// revision

- (NSString*) revision { return fRevision; }

- (void) setRevision: (NSString*) aRevision
{
	if (aRevision != fRevision)
	{
		id old = fRevision;
		fRevision = [aRevision retain];
		[old release];
	}
}


//----------------------------------------------------------------------------------------

- (NSString*) windowTitle { return windowTitle; }


//----------------------------------------------------------------------------------------
// operationInProgress

- (BOOL) operationInProgress { return operationInProgress; }

- (void) setOperationInProgress: (BOOL) aBool
{
	operationInProgress = aBool;
}


//----------------------------------------------------------------------------------------

- (NSString*) browsePath
{
	RepoItem* selection = [self selectedItemOrNil];

	return [(selection ? [selection url] : fURL) absoluteString];
}


//----------------------------------------------------------------------------------------

- (SvnClient) svnClient
{
	return SvnSetupClient(&fSvnEnv, self);
}


@end

//----------------------------------------------------------------------------------------
// End of MyRepository.m
