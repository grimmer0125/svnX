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
#import "Tasks.h"
#import "SvnLogReport.h"
#import "CommonUtils.h"
#import "SvnInterface.h"

enum {
	SVNXCallbackExtractedToFileSystem,
	SVNXCallbackCopy,
	SVNXCallbackMove,
	SVNXCallbackMkdir,
	SVNXCallbackDelete,
	SVNXCallbackImport,
	SVNXCallbackSvnInfo,
	SVNXCallbackGetOptions
};


//----------------------------------------------------------------------------------------

static NSString*
TrimSlashes (id obj)
{
	return [[[obj valueForKey: @"url"] absoluteString] trimSlashes];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@interface MyRepository (Private)

	- (BOOL) svnErrorIf: (id) taskObj;
	- (void) svnError: (NSString*) errorString;

	- (void) displayUrlTextView;

	- (void) updateLog;
	- (void) fetchSvnInfo: (SEL) selector;
	- (void) fetchSvnInfo;
	- (void) fetchSvnInfoReceiveDataFinished: (NSString*) result;

	- (void) svnInfoCompletedCallback: (id) taskObj;
	- (NSArray*) userValidatedFiles: (NSArray*) files
				 forDestination:     (NSURL*)   destinationURL;

	- (void) setRevision:         (NSString*) aRevision;
	- (void) setUrl:              (NSURL*)    anUrl;
	- (void) checkRepositoryURL;
	- (void) setDisplayedTaskObj: (NSMutableDictionary*) aDisplayedTaskObj;
	- (NSInvocation*) makeSvnOptionInvocation;
	- (NSInvocation*) makeCallbackInvocationOfKind: (int) callbackKind;

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
	[svnLogView unload];
	[svnBrowserView unload];

	[self setUrl: nil];
 	[fRootURL release];
	[self setRevision: nil];
	[windowTitle release];
	[user release];
	[pass release];

	[self setDisplayedTaskObj: nil];

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

- (NSString*) preferenceName
{
	return [@"repoWinFrame:" stringByAppendingString: windowTitle];
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

- (void) close
{
	[[self window] saveFrameUsingName: [self preferenceName]];

	[svnLogView removeObserver: self forKeyPath: @"currentRevision"];

	[drawerLogView unload];
	
	[super close];	
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

	[drawerLogView setDocument: self];
	[drawerLogView setUp];

	NSWindow* window = [self window];
	NSString* widowFrameKey = [self preferenceName];
	[window setFrameUsingName: widowFrameKey];
	[window setFrameAutosaveName: widowFrameKey];

	// fetch svn info in order to know the repository's root URL & HEAD revision
	[self updateLog];
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

- (IBAction) toggleSidebar: (id) sender
{
	[sidebar toggle: sender];
}


- (IBAction) pickedAFolderInBrowserView: (NSMenuItem*) sender
{
	// "Browse as sub-repository" context menu item. (see "browserContextMenu" Menu in IB)
	// representedObject of the sender menu item is the same as the row's in the browser.
	// Was set in MySvnRepositoryBrowserView.
	[self changeRepositoryUrl: [[sender representedObject] objectForKey: @"url"]];
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

- (NSString*) pathAtCurrentRevision: (id) repoItem
{
	// <path>@<revision>
	return [NSString stringWithFormat: @"%@@%@", TrimSlashes(repoItem), fRevision];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Log Management
//----------------------------------------------------------------------------------------

- (void) fetchSvnLog
{
	[svnLogView fetchSvnLog];
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

- (void) browsePath: (NSString*) relativePath
		 revision:   (NSString*) pegRevision
{
	NSString* newURL = [[fRootURL absoluteString] stringByAppendingString: relativePath];
	[self changeRepositoryUrl: [NSURL URLWithString: newURL]];
	[self setRevision: pegRevision];
}


//----------------------------------------------------------------------------------------
// Set browse URL from a path in a log entry

- (void) openLogPath: (NSDictionary*) pathInfo
		 revision:    (NSString*)     pegRevision
{
	#pragma unused(pathInfo, pegRevision)
#if 0
	[self browsePath: [pathInfo objectForKey: @"path"] revision: pegRevision];
#endif
}


//----------------------------------------------------------------------------------------

- (void) changeRepositoryUrl: (NSURL*) anUrl
{
	[self setUrl: anUrl];
	[svnBrowserView setUrl: fURL];
	[svnLogView resetUrl: fURL];
	[self displayUrlTextView];
	[svnLogView fetchSvnLog];
	[svnBrowserView fetchSvn];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	svn info
//----------------------------------------------------------------------------------------

struct SvnInfoEnv
{
	SvnRevNum		fRevision;
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
	SvnInfoEnv* env = (SvnInfoEnv*) baton;
	env->fRevision = info->rev;
	strncpy(env->fURL, info->repos_root_URL, sizeof(env->fURL));
//	strncpy(env->fUUID, info->repos_UUID, sizeof(env->fUUID));

	return SVN_NO_ERROR;
}


//----------------------------------------------------------------------------------------
// svn info of <fRootURL> via SvnInterface (called by separate thread)

- (void) svnDoInfo: (Message*) completedMsg
{
	[self retain];
	NSAutoreleasePool* autoPool = [[NSAutoreleasePool alloc] init];
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
			env.fURL[0] = 0;

			// Retrive HEAD revision info from repository root.
			SvnThrowIf(svn_client_info(path, &peg_rev, &rev_opt,
									   svnInfoReceiver, &env, !kSvnRecurse,
									   ctx, pool));

			[fRootURL release];
			fRootURL = (NSURL*) CFURLCreateWithBytes(kCFAllocatorDefault,
													 (const UInt8*) env.fURL, strlen(env.fURL),
													 kCFStringEncodingUTF8, NULL);
			fHeadRevision = env.fRevision;
			[self checkRepositoryURL];
			[completedMsg sendToOnMainThread: self];
			[self performSelectorOnMainThread: @selector(displayUrlTextView) withObject: nil waitUntilDone: NO];
		}
	}
	@catch (SvnException* ex)
	{
		SvnReportCatch(ex);
		[self performSelectorOnMainThread: @selector(svnError:) withObject: [ex message] waitUntilDone: NO];
	}
	@finally
	{
		SvnDeletePool(pool);
		[autoPool release];
		[self release];
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
		for (int i = 0; i < count; ++i)
		{
			NSString* line = [lines objectAtIndex: i];

			if ([line length] > 16 &&
				[[line substringWithRange: NSMakeRange(0, 17)] isEqualToString: @"Repository Root: "])
			{
				[fRootURL release];
				fRootURL = [[NSURL URLWithString: [line substringFromIndex: 17]] retain];
				[self displayUrlTextView];
				break;
			}
		}
	}
}


//----------------------------------------------------------------------------------------
// If there is a single selected repository-browser item then return it else return nil.
// Private:

- (NSDictionary*) selectedItemOrNil
{
	NSArray* const selectedObjects = [svnBrowserView selectedItems];
	return ([selectedObjects count] == 1) ? [selectedObjects objectAtIndex: 0] : nil;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	svn operations

- (IBAction) svnCopy: (id) sender
{
	#pragma unused(sender)
	NSDictionary* selection = [self selectedItemOrNil];
	if (!selection)
	{
		[self svnError: @"Please select exactly one item to copy."];
	}
	else if ([[selection valueForKey: @"isRoot"] boolValue])
	{
		[self svnError: @"Can't copy root folder."];
	}
	else
	{
		[MySvnOperationController runSheet: kSvnCopy repository: self url: fURL sourceItem: selection];
	}
}


- (IBAction) svnMove: (id) sender
{
	#pragma unused(sender)
	NSDictionary* selection = [self selectedItemOrNil];
	if (!selection)
	{
		[self svnError: @"Please select exactly one item to move."];
	}
	else if ([[selection valueForKey: @"isRoot"] boolValue])
	{
		[self svnError: @"Can't move root folder."];
	}
	else
	{
		[MySvnOperationController runSheet: kSvnMove repository: self url: fURL sourceItem: selection];
	}
}


- (IBAction) svnMkdir: (id) sender
{
	#pragma unused(sender)
	[MySvnOperationController runSheet: kSvnMkdir repository: self url: fURL sourceItem: nil];
}


- (IBAction) svnDelete: (id) sender
{
	#pragma unused(sender)
	[MySvnOperationController runSheet: kSvnDelete repository: self url: fURL sourceItem: nil];
}


- (IBAction) svnFileMerge: (id) sender
{
	#pragma unused(sender)
	NSDictionary* selection = [self selectedItemOrNil];
	if (!selection)
	{
		[self svnError: @"Please select exactly one item."];
	}
	else
	{
		[MyFileMergeController runSheet: kSvnDiff repository: self
							   url: [selection valueForKey: @"url"] sourceItem: selection];
	}	
}


//----------------------------------------------------------------------------------------

- (IBAction) svnBlame: (id) sender
{
	#pragma unused(sender)
	NSArray* const selectedObjects = [svnBrowserView selectedItems];
//	NSLog(@"svnBlame: %@", selectedObjects);
	NSMutableArray* files = [NSMutableArray array];
	for_each(enumerator, item, selectedObjects)
	{
		if (![[item valueForKey: @"isDir"] boolValue])
			[files addObject: PathPegRevision([item valueForKey: @"url"], fRevision)];
	}

	if ([files count] == 0)
	{
		[self svnError: @"Please select one or more files."];
	}
	else
	{
		[MySvn blame:          files
			   revision:       fRevision
			   generalOptions: [self svnOptionsInvocation]
			   options:        [NSArray arrayWithObjects: AltOrShiftPressed() ? @"--verbose" : @"", nil]
			   callback:       MakeCallbackInvocation(self, @selector(svnErrorIf:))
			   callbackInfo:   nil
			   taskInfo:       [self documentNameDict]];
	}	
}


//----------------------------------------------------------------------------------------

- (IBAction) svnReport: (id) sender
{
	#pragma unused(sender)
	NSDictionary* selection = [self selectedItemOrNil];
	if (!selection)
	{
		[self svnError:@"Please select exactly one item."];
	}
	else
	{
		[SvnLogReport svnLogReport: [[selection valueForKey: @"url"] absoluteString]
					  revision:     [self revision]
					  verbose:      !AltOrShiftPressed()];
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Checkout, Export & Import
//----------------------------------------------------------------------------------------
// Private:

- (void) chooseFolder:   (NSString*) message
		 didEndSelector: (SEL)       didEndSelector
		 contextInfo:    (void*)     contextInfo
{
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];

	[oPanel setAllowsMultipleSelection: NO];
	[oPanel setCanChooseDirectories:    YES];
	[oPanel setCanChooseFiles:          NO];
	[oPanel setCanCreateDirectories:    YES];
	[oPanel setMessage: message];

	[oPanel beginSheetForDirectory: NSHomeDirectory() file: nil types: nil
					modalForWindow: [self windowForSheet]
					 modalDelegate: self
				    didEndSelector: didEndSelector
					   contextInfo: contextInfo];
}


//----------------------------------------------------------------------------------------

- (IBAction) svnExport: (id) sender
{
	#pragma unused(sender)
	NSArray* const selectedObjects = [svnBrowserView selectedItems];
	const int count = [selectedObjects count];
	NSString* message = (count == 1)
				? [NSString stringWithFormat: @"Export %C%@%C into folder:", 0x201C,
											  [[selectedObjects objectAtIndex: 0] valueForKey: @"name"], 0x201D]
				: [NSString stringWithFormat: @"Export %d items into folder:", count];

	[self chooseFolder: message
		didEndSelector: @selector(exportPanelDidEnd:returnCode:contextInfo:)
		   contextInfo: NULL];
}


//----------------------------------------------------------------------------------------

- (IBAction) svnCheckout: (id) sender
{
	#pragma unused(sender)
	NSDictionary* selection = [self selectedItemOrNil];
	if (!selection || ![[selection valueForKey: @"isDir"] boolValue])
	{
		[self svnError: @"Please select exactly one folder to checkout."];
	}
	else
	{
		NSString* message = [NSString stringWithFormat: @"Checkout %C%@%C into folder:",
														0x201C, [selection valueForKey: @"name"], 0x201D];
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
        NSString* destinationPath = [[sheet filenames] objectAtIndex:0];
		[self setDisplayedTaskObj:
			[MySvn    checkout: [self pathAtCurrentRevision: (id) contextInfo]
				   destination: destinationPath
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-r", fRevision, nil]
					  callback: [self makeCallbackInvocationOfKind:SVNXCallbackExtractedToFileSystem]
				  callbackInfo: destinationPath
					  taskInfo: [self documentNameDict]]];

		// TL : Creating new working copy for the checked out path.
		if (GetPreferenceBool(@"addWorkingCopyOnCheckout"))
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:@"newWorkingCopy" object:destinationPath];
		}
	}
}


//----------------------------------------------------------------------------------------
// Private:

- (void) exportFiles:   (NSArray*) validatedFiles
		 toDestination: (NSURL*)   destinationURL
{
	NSString* const destPath = [destinationURL path];

	NSMutableArray *shellScriptArguments = [NSMutableArray array];

	// We use a single shell script to do all because we want to
	// handle it as a single task (that will be easier to terminate)

	for_each(enumerator, item, validatedFiles)
	{
		NSString *destinationPath = [destPath stringByAppendingPathComponent:[item valueForKey:@"name"]];
		NSString *sourcePath = [self pathAtCurrentRevision: item];
		NSString* operation = [[item valueForKey: @"isDir"] boolValue]
									? @"e"		// folder => svn export (see svnextract.sh)
									: @"c";		// file   => svn cat

		[shellScriptArguments addObjectsFromArray:
				[NSArray arrayWithObjects: operation, sourcePath, destinationPath, nil]];
	}

	[self setDisplayedTaskObj:
		[MySvn	extractItems: shellScriptArguments
			  generalOptions: [self svnOptionsInvocation]
					 options: [NSArray arrayWithObjects: @"-r", fRevision, nil]
					callback: [self makeCallbackInvocationOfKind: SVNXCallbackExtractedToFileSystem]
				callbackInfo: destPath
					taskInfo: [self documentNameDict]]
	];
}


//----------------------------------------------------------------------------------------
// Private:

- (void) checkoutFiles: (NSArray*) validatedFiles
		 toDestination: (NSURL*)   destinationURL
{
	id item = [validatedFiles objectAtIndex:0]; // one checks out no more than one directory
	NSString *destinationPath = [[destinationURL path] stringByAppendingPathComponent:[item valueForKey:@"name"]];

	[self setDisplayedTaskObj:
		[MySvn    checkout: [self pathAtCurrentRevision: item]
			   destination: destinationPath
			generalOptions: [self svnOptionsInvocation]
				   options: [NSArray arrayWithObjects: @"-r", fRevision, nil]
				  callback: [self makeCallbackInvocationOfKind:SVNXCallbackExtractedToFileSystem]
			  callbackInfo: destinationPath
				  taskInfo: [self documentNameDict]]
	];

	// TL : Creating new working copy for the checked out path.
	if (GetPreferenceBool(@"addWorkingCopyOnCheckout"))
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"newWorkingCopy" object:destinationPath];
	}
}


//----------------------------------------------------------------------------------------

- (void) exportPanelDidEnd: (NSOpenPanel*) sheet
		 returnCode:        (int)          returnCode
		 contextInfo:       (void*)        contextInfo
{
	#pragma unused(contextInfo)

	if (returnCode == NSOKButton)
	{
		NSURL *destinationURL = [NSURL fileURLWithPath:[[sheet filenames] objectAtIndex:0]];
		NSArray *validatedFiles = [self userValidatedFiles: [svnBrowserView selectedItems]
										forDestination:     destinationURL];

		[self exportFiles: validatedFiles toDestination: destinationURL];
	}
}


//----------------------------------------------------------------------------------------

- (void) extractedItemsCallback: (NSDictionary*) taskObj
{
	NSString* extractDestinationPath = [taskObj valueForKey: @"callbackInfo"];

	// let the Finder know about the operation (required for Panther)
	[[NSWorkspace sharedWorkspace] noteFileSystemChanged: extractDestinationPath];

	[self svnErrorIf: taskObj];
}


//----------------------------------------------------------------------------------------

- (void) dragOutFilesFromRepository: (NSArray*) filesDicts
		 toURL:                      (NSURL*)   destinationURL
{
	NSArray* validatedFiles = [self userValidatedFiles: filesDicts forDestination: destinationURL];
	BOOL isCheckout = FALSE;	// -> export by default

	if ( [validatedFiles count] == 1 )
	{
		if ( [[[validatedFiles objectAtIndex:0] valueForKey:@"isDir"] boolValue] )
		{
			NSAlert *alert = [[NSAlert alloc] init];
			
			[alert addButtonWithTitle:@"Export"];
			[alert addButtonWithTitle:@"Checkout"];
			
			[alert setMessageText:@"Do you want to extract the folder versioned (checkout) or unversioned (export)?"];
//			[alert setInformativeText:@"Hum ?"];
			[alert setAlertStyle:NSWarningAlertStyle];

			int alertResult = [alert runModal];
			
			if ( alertResult == NSAlertFirstButtonReturn) // Unversioned -> export
			{
				isCheckout = FALSE;
			} 
			else if ( alertResult == NSAlertSecondButtonReturn) // Versioned -> checkout
			{
				isCheckout = TRUE;
			} 
			
			[alert release];
		}
	}

	if (isCheckout)		// => checkout
	{
		[self checkoutFiles: validatedFiles toDestination: destinationURL];
	}
	else				// => export
	{
		[self exportFiles: validatedFiles toDestination: destinationURL];
	}
}


//----------------------------------------------------------------------------------------

- (void) dragExternalFiles: (NSArray*)      files
		 ToRepositoryAt:    (NSDictionary*) representedObject
{
	NSString *filePath = [files objectAtIndex:0];

	[importCommitPanel setTitle:@"Import"];
	[fileNameTextField setStringValue:[filePath lastPathComponent]];

	[NSApp	beginSheet:importCommitPanel
			modalForWindow:[self windowForSheet] 
			modalDelegate:self 
			didEndSelector:@selector(importCommitPanelDidEnd:returnCode:contextInfo:) 
			contextInfo:[[NSDictionary dictionaryWithObjectsAndKeys:
										TrimSlashes(representedObject), @"destination",
										filePath, @"filePath", nil] retain] ];
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
		[self setDisplayedTaskObj:
			[MySvn		import: [dict objectForKey: @"filePath"]
				   destination: [NSString stringWithFormat: @"%@/%@",
									[dict objectForKey:@"destination"], [fileNameTextField stringValue]]
											// stringByAppendingPathComponent would eat svn:// into svn:/ !
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-m", MessageString([commitTextView string]), nil]
					  callback: [self makeCallbackInvocationOfKind: SVNXCallbackImport]
				  callbackInfo: nil
					  taskInfo: [self documentNameDict]]
			];
	}

	[dict release];
}


//----------------------------------------------------------------------------------------

- (IBAction) importCommitPanelValidate: (id) sender
{
	[NSApp endSheet:importCommitPanel returnCode:[sender tag]];
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
			sourceUrl = [[[self selectedItemOrNil] valueForKey: @"url"] absoluteString];
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
					  callback: [self makeCallbackInvocationOfKind: SVNXCallbackCopy]
				  callbackInfo: nil
					  taskInfo: [self documentNameDict]];
			break;

		case kSvnMove:
			[MySvn		  move: sourceUrl
				   destination: targetUrl
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-m", commitMessage, nil]
					  callback: [self makeCallbackInvocationOfKind: SVNXCallbackMove]
				  callbackInfo: nil
					  taskInfo: [self documentNameDict]];
			break;

		case kSvnMkdir:									// Some Key-Value coding magic !! (multiple directories)
			[MySvn		 mkdir: [[controller getTargets] mutableArrayValueForKeyPath: @"url.absoluteString"]
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-m", commitMessage, nil]
					  callback: [self makeCallbackInvocationOfKind: SVNXCallbackMkdir]
				  callbackInfo: nil
					  taskInfo: [self documentNameDict]];
			break;

		case kSvnDelete:								// Some Key-Value coding magic !! (multiple directories)
			[MySvn		delete: [[controller getTargets] mutableArrayValueForKeyPath: @"url.absoluteString"]
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects: @"-m", commitMessage, nil]
					  callback: [self makeCallbackInvocationOfKind: SVNXCallbackDelete]
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

- (void) svnCommandComplete: (id) taskObj
{
	if (isCompleted(taskObj))
	{
		[svnLogView fetchSvnLog];
	}

	[self svnErrorIf: taskObj];
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
	NSAlert* alert = [NSAlert alertWithMessageText: @"svn Error"
								     defaultButton: @"OK"
								   alternateButton: nil
									   otherButton: nil
						 informativeTextWithFormat: @"%@", errorString];

	[alert setAlertStyle: NSCriticalAlertStyle];

	if ([[self windowForSheet] attachedSheet] != nil)
		[NSApp endSheet: [[self windowForSheet] attachedSheet]];

	[alert beginSheetModalForWindow: [self windowForSheet]
					  modalDelegate: self
					 didEndSelector: nil
						contextInfo: nil];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Helpers

- (NSArray*) userValidatedFiles: (NSArray*) files
			 forDestination:     (NSURL*)   destinationURL
{
	NSMutableArray* validatedFiles = [NSMutableArray array];
	BOOL yesToAll = NO;

	for_each(enumerator, item, files)
	{
		if (yesToAll)
		{
			[validatedFiles addObject: item];

			continue;
		}

		NSString* const name = [item valueForKey: @"name"];
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


- (NSMutableDictionary*) getSvnOptions
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys: user, @"user", pass, @"pass", nil];
}


- (NSInvocation*) makeSvnOptionInvocation
{
	return MakeCallbackInvocation(self, @selector(getSvnOptions));
}


- (NSInvocation*) makeCallbackInvocationOfKind: (int) callbackKind
{
	SEL callbackSelector = nil;

	switch ( callbackKind )
	{
		case SVNXCallbackExtractedToFileSystem:
			callbackSelector = @selector(extractedItemsCallback:);
			break;

		case SVNXCallbackCopy:
		case SVNXCallbackMove:
		case SVNXCallbackMkdir:
		case SVNXCallbackDelete:
		case SVNXCallbackImport:
			callbackSelector = @selector(svnCommandComplete:);
			break;

		case SVNXCallbackSvnInfo:
			callbackSelector = @selector(svnInfoCompletedCallback:);
			break;

		case SVNXCallbackGetOptions:
			callbackSelector = @selector(getSvnOptions);
			break;
	}

	return MakeCallbackInvocation(self, callbackSelector);
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Document delegate

- (void) canCloseDocumentWithDelegate: (id)    delegate
		 shouldCloseSelector:          (SEL)   shouldCloseSelector
		 contextInfo:                  (void*) contextInfo
{
	// tell the task center to cancel pending callbacks to prevent crash
	[[Tasks sharedInstance] cancelCallbacksOnTarget: self];

	[super canCloseDocumentWithDelegate: delegate
		   shouldCloseSelector:          shouldCloseSelector
		   contextInfo:                  contextInfo];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Accessors

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

- (NSURL*) rootURL { return fRootURL; }


//----------------------------------------------------------------------------------------
// url

- (NSURL*) url { return fURL; }

- (void) setUrl: (NSURL*) anUrl
{
	id old = fURL;
	fURL = [anUrl retain];
	[old release];
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
	NSDictionary* selection = [self selectedItemOrNil];

	return [(selection ? [selection valueForKey: @"url"] : fURL) absoluteString];
}


//----------------------------------------------------------------------------------------

- (SvnClient) svnClient
{
	return SvnSetupClient(&fSvnEnv, self);
}


@end

//----------------------------------------------------------------------------------------
// End of MyRepository.m
