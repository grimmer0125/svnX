//----------------------------------------------------------------------------------------
//	MyWorkingCopyController.m - Controller of the working copy browser
//
//	Copyright © Chris, 2007 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "MyWorkingCopyController.h"
#import "MyWorkingCopy.h"
#import "MyApp.h"
#import "MyDragSupportWindow.h"
#import "MyFileMergeController.h"
#import "DrawerLogView.h"
#import "NSString+MyAdditions.h"
#import "ReviewCommit.h"
#import "RepoItem.h"
#import "SvnInterface.h"
#import "CommonUtils.h"
#import "ViewUtils.h"


//----------------------------------------------------------------------------------------

enum {
	vFlatTable	=	2000,
	vTreeTable	=	2002,
	vCmdButtons	=	3000
};

enum {
	kModeTree	=	0,
	kModeFlat	=	1,
	kModeSmart	=	2
};

static ConstString keyWCWidows    = @"wcWindows",		// Deprecated
				   keyWidowFrame  = @"winFrame",
				   keyViewMode    = @"viewMode",
				   keyFilterMode  = @"filterMode",
				   keyShowToolbar = @"showToolbar",
				   keyShowSidebar = @"showSidebar",
				   keySortDescs   = @"sortDescs",
				   keyTreeWidth   = @"treeWidth",
				   keyTreeSelPath = @"treeSelPath",
				   keyTreeExpanded = @"treeExpanded";

static const GCoord kMinFilesHeight    = 96,
					kMinTreeWidth      = 140,
					kMaxTreeWidthFract = 0.5,
					kDefaultTreeWidth  = 200;

static NSString* gInitName = nil;

extern BOOL Props_Toggle(void);
extern void Props_Reset(void);
extern void Props_Changed(id wc);


//----------------------------------------------------------------------------------------
// Subversion 1.4.6 commands that support recursive flags
//			Add, Remove, Update, Revert, Resolved, Lock, Unlock, Copy, Move, Rename, Info
// Default:  Y     -        Y      N         N      -      -      -      -      -      N
// Allow -R: N     -        N      Y         Y      -      -      -      -      -      Y
// Allow -N: Y     -        Y      N         N      -      -      -      -      -      N


//----------------------------------------------------------------------------------------
// Add, Delete, Update, Revert, Resolved, Lock, Unlock, Commit, Review

static ConstString gCommands[] = {
	@"add", @"remove", @"update", @"revert", @"resolved", @"lock", @"unlock",
	@"commit", @"review", @"resolve", @"cleanup", @"rename", @"copy", @"move", @"info"
};

static ConstString gVerbs[] = {
	@"add", @"remove", @"update", @"revert", @"resolve", @"lock", @"unlock",
	@"commit", @"review", @"resolve", @"cleanup", @"rename", @"copy", @"move", @"info"
};

// 0.add  1.remove  2.update  102.update-alt  3.revert  4.resolved  5.lock  6.unlock
// 7.commit  8.review  9.resolve  10.cleanup  11.rename  12.copy  13.move  14.info
enum SvnCommand {
	cmdAdd = 0, cmdRemove, cmdUpdate, cmdRevert, cmdResolved, cmdLock, cmdUnlock,
	cmdCommit, cmdReview, cmdResolve, cmdCleanup, cmdRename, cmdCopy, cmdMove, cmdInfo,
	cmdUpdateAlt = 100 + cmdUpdate,
	cmdReviewAlt = 100 + cmdReview,
	cmdInfoRecursive = 100 + cmdInfo
};
typedef enum SvnCommand SvnCommand;


//----------------------------------------------------------------------------------------

static NSMutableDictionary*
makeCommand (NSString* command, NSString* verb, NSString* destination)
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys: command,     @"command",
															  verb,        @"verb",
															  destination, @"destination",
															  nil];
}


//----------------------------------------------------------------------------------------

static NSMutableDictionary*
makeCommandDict (NSString* command, NSString* destination)
{
	return makeCommand(command, command, destination);
}


//----------------------------------------------------------------------------------------

static bool
supportsRecursiveFlag (NSString* cmd)
{
	return ([cmd isEqualToString: @"revert"] || [cmd isEqualToString: @"resolved"]);
}


//----------------------------------------------------------------------------------------

static bool
supportsNonRecursiveFlag (NSString* cmd)
{
	return ([cmd isEqualToString: @"add"] || [cmd isEqualToString: @"update"]);
}


//----------------------------------------------------------------------------------------

static id
getRecursiveOption (NSString* cmd, bool isRecursive)
{
	if (isRecursive)
		return supportsRecursiveFlag(cmd) ? @"--recursive" : nil;
	return supportsNonRecursiveFlag(cmd) ? @"--non-recursive" : nil;
}


//----------------------------------------------------------------------------------------

static NSString*
getPathPegRevision (RepoItem* repoItem)
{
	return repoItem ? PathPegRevision([repoItem url], [repoItem revision]) : @"";
}


//----------------------------------------------------------------------------------------

static BOOL
containsLocalizedString (NSString* container, NSString* str)
{
	return ([container rangeOfString: NSLocalizedString(str, nil)].location != NSNotFound);
}


//----------------------------------------------------------------------------------------

static NSString*
WCItemDesc (NSDictionary* item, BOOL isDir)
{
	NSString* name;
	if (item == nil || [(name = [item objectForKey: @"path"]) isEqualToString: @"."])
		return isDir ? @"This working copy" : nil;
	return [NSString stringWithFormat: @"%@ %C%@%C",
			(isDir ? @"Directory" : @"File"), 0x201C, name, 0x201D];
}


//----------------------------------------------------------------------------------------
// Also returns the displayPath of the first match in firstName.

static NSArray*
getDirFullPaths (NSArray* wcItems, NSString** firstName)
{
	NSString* displayPath = nil;
	NSMutableArray* const paths = [NSMutableArray array];
	for_each_obj(en, it, wcItems)
	{
		if ([[it objectForKey: @"isDir"] boolValue])
		{
			[paths addObject: [it objectForKey: @"fullPath"]];
			if (displayPath == nil)
				displayPath = [it objectForKey: @"displayPath"];
		}
	}
	*firstName = displayPath;
	return paths;
}


//----------------------------------------------------------------------------------------

static NSTableColumn*
setColumnSort (NSTableView* tableView, NSString* colId, Class sort)
{
	NSTableColumn* col = [tableView tableColumnWithIdentifier: colId];
	Assert(col != nil);
	id desc = [[sort alloc] initWithKey: colId ascending: YES];
	[col setSortDescriptorPrototype: desc];
	[desc release];
	return col;
}


//----------------------------------------------------------------------------------------

static inline NSString*
PrefKey (NSString* nameKey)
{
	return [@"WC:" stringByAppendingString: nameKey];
}


//----------------------------------------------------------------------------------------

void
InitWCPreferences (void)
{
	// Split svnX 1.1 array of dicts into separate dict prefs
	NSDictionary* const wcWindows = GetPreference(keyWCWidows);
	if (wcWindows)
	{
		for_each_key(en, key, wcWindows)
		{
			ConstString prefKey = PrefKey(key);
			if (!GetPreference(prefKey))
				SetPreference(prefKey, [wcWindows objectForKey: key]);
		}
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@interface SortPath : AlphaNumSortDesc @end

@implementation SortPath

- (NSComparisonResult) compareObject: (id) obj1 toObject: (id) obj2
{
	NSComparisonResult result = [[obj1 objectForKey: @"path"]
									compare: [obj2 objectForKey: @"path"]
									options: NSCaseInsensitiveSearch | NSNumericSearch];
	return fAscending ? result : -result;
}

@end	// SortPath


//----------------------------------------------------------------------------------------

@interface SortRevision : AlphaNumSortDesc @end

@implementation SortRevision

- (NSComparisonResult) compareObject: (id) obj1 toObject: (id) obj2
{
	NSComparisonResult result = [[obj1 objectForKey: @"revisionCurrent"]
									compare: [obj2 objectForKey: @"revisionCurrent"]
									options: NSNumericSearch];
	return fAscending ? result : -result;
}

@end	// SortRevision


//----------------------------------------------------------------------------------------

@interface SortLast : AlphaNumSortDesc @end

@implementation SortLast

- (NSComparisonResult) compareObject: (id) obj1 toObject: (id) obj2
{
	NSComparisonResult result = [[obj1 objectForKey: @"revisionLastChanged"]
									compare: [obj2 objectForKey: @"revisionLastChanged"]
									options: NSNumericSearch];
	return fAscending ? result : -result;
}

@end	// SortLast


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@interface MyWorkingCopyController (Private)

	- (void) prefsChanged;
	- (void) savePrefs;

	- (IBAction) commitPanelValidate: (id) sender;
	- (IBAction) commitPanelCancel:   (id) sender;
	- (IBAction) renamePanelValidate: (id) sender;
	- (IBAction) switchPanelValidate: (id) sender;
	- (IBAction) mergeSheetDoClick:   (id) sender;

	- (void) runAlertBeforePerformingAction: (NSDictionary*) command;
	- (void) startCommitMessage: (NSString*) selectedOrAll;
	- (void) renamePanelForCopy: (BOOL)      isCopy
			 destination:        (NSString*) destination;
	- (void) requestNameSheet:   (SvnCommand) cmd;
	- (void) openSidebar;
	- (void) svnCleanup_Request;

	- (void) requestSvnUpdate:   (BOOL)      forSelection;
	- (void) updateSheetSetKind: (id)        updateKindView;
	- (void) updateSheetDidEnd:  (NSWindow*) sheet
			 returnCode:         (int)       returnCode
			 contextInfo:        (void*)     contextInfo;

	- (int)  mergeSheetSetKind: (id) mergeKindView;
	- (void) mergeSheetDidEnd:  (NSWindow*) sheet
			 returnCode:        (int)       returnCode
			 contextInfo:       (void*)     contextInfo;

	- (NSArray*) selectedFilePaths;

@end	// WorkingCopyCon (Private)


//----------------------------------------------------------------------------------------
#pragma mark -
//----------------------------------------------------------------------------------------

@implementation MyWorkingCopyController

//----------------------------------------------------------------------------------------

+ (void) presetDocumentName: name
{
	gInitName = name;
}


//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
	fTreeExpanded = [NSMutableArray new];
	isDisplayingErrorSheet = NO;
	suppressAutoRefresh = TRUE;
	Assert(document != nil);
	[window setDelegate: self];		// for windowDid*, windowShould* & windowWill* messages

	int viewMode   = kModeSmart,
		filterMode = kFilterAll;
	GCoord treeWidth = 0;
	id sortDescsPref = nil;
	ConstString prefKey = PrefKey(gInitName);
	NSDictionary* const settings = GetPreference(prefKey);
	if (settings != nil)
	{
		viewMode   = [[settings objectForKey: keyViewMode] intValue];
		filterMode = [[settings objectForKey: keyFilterMode] intValue];
	//	searchStr  = [settings objectForKey: keySearchStr];

		if (![[settings objectForKey: keyShowToolbar] boolValue])
			[[window toolbar] setVisible: NO];

		[window setFrameFromString: [settings objectForKey: keyWidowFrame]];

		if ([[settings objectForKey: keyShowSidebar] boolValue])
			[sidebar performSelector: @selector(open) withObject: nil afterDelay: 0.125];

		ConstString treeSelPath = [settings objectForKey: keyTreeSelPath];
		if (treeSelPath != nil)
			[document setOutlineSelectedPath: treeSelPath];

		id treeExpanded = [settings objectForKey: keyTreeExpanded];
		if (treeExpanded)
			[fTreeExpanded addObjectsFromArray: treeExpanded];
		else
			[fTreeExpanded addObject: @""];

		treeWidth = [[settings objectForKey: keyTreeWidth] floatValue];
		sortDescsPref = [settings objectForKey: keySortDescs];
	}

	[modeView setIntValue: viewMode];
	[self performSelector: @selector(initMode:) withObject: [NSNumber numberWithInt: viewMode] afterDelay: 0];
	[filterView selectItemWithTag: filterMode];
	[document setFilterMode: filterMode];

	[self setStatusMessage: @""];

	[document addObserver: self forKeyPath: @"flatMode"
				  options: (NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context: NULL];

	[drawerLogView setup: document forWindow: window];

	// This also loads the table view's sorting so do it first (so we can overwrite it)
	[tableResult setAutosaveName: prefKey];

	// Try to load the table view's sorting from our pref
	NSArray* sortDescs = nil;
	if (sortDescsPref && ISA(sortDescsPref, NSData))
	{
		sortDescs = [NSUnarchiver unarchiveObjectWithData: sortDescsPref];
		if (!ISA(sortDescs, NSArray))
			sortDescs = nil;
	}

	// Otherwise set the table view's default sorting to status type & path columns
	if (!sortDescs)
	{
		sortDescs = [NSArray arrayWithObjects:
						[[[NSSortDescriptor alloc] initWithKey: @"col1" ascending: NO]  autorelease], 
						[[[SortPath         alloc] initWithKey: @"path" ascending: YES] autorelease], nil];
	}
	[svnFilesAC setSortDescriptors: sortDescs];

	NSTableView* const tableView = tableResult;
	setColumnSort(tableView, @"path",   [SortPath     class]);
	setColumnSort(tableView, @"rev",    [SortRevision class]);
	setColumnSort(tableView, @"change", [SortLast     class]);

	if (GetPreferenceBool(@"compactWCColumns"))
	{
		NSFont* const font = [NSFont labelFontOfSize: 9];
		for (int i = 1; i <= 8; ++i)
		{
			const unichar ch = '0' + i;
			NSTableColumn* col = [tableView tableColumnWithIdentifier: [NSString stringWithCharacters: &ch length: 1]];
			if (!col) continue;
			NSCell* cell = [col dataCell];
			[cell setAlignment: NSLeftTextAlignment];
			[cell setFont: font];
			[col setMinWidth: 9];
			[col setWidth:    9];
			[col setMaxWidth: 9];
		}
	}

	[self setNextResponder: [tableView nextResponder]];
	[tableView setNextResponder: self];

	if (treeWidth <= 0)
		treeWidth = kDefaultTreeWidth;
	fTreeWidth = treeWidth;
	[self adjustOutlineView];
	fTreeWidth = treeWidth;		// adjustTreeView may have overwritten this if it called closeTreeView

	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(quitting:)
												 name: NSApplicationWillTerminateNotification object: nil];
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
//	dprintf("%@", self);
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[savedSelection release];
	[fTreeExpanded  release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (void) initMode: (NSNumber*) number
{
	const int viewMode = [number intValue];
	if (viewMode == [self currentMode])		// Force refresh if mode hasn't changed so won't auto-refresh
	{
		[document svnRefresh];
		[self prefsChanged];
	}
	else
		[self setCurrentMode: viewMode];
}


//----------------------------------------------------------------------------------------

- (void) windowDidBecomeMain: (NSNotification*) notification
{
	#pragma unused(notification)
	if (suppressAutoRefresh)
	{
		suppressAutoRefresh = FALSE;
	}
	else if (!svnStatusPending && GetPreferenceBool(@"autoRefreshWC"))
	{
		[document performSelector: @selector(svnRefresh) withObject: nil afterDelay: 0];
	}
	[self selectionChanged];
}


//----------------------------------------------------------------------------------------

- (void) windowDidResignMain: (NSNotification*) notification
{
	#pragma unused(notification)
	Props_Reset();
}


//----------------------------------------------------------------------------------------

- (BOOL) windowShouldClose: (id) sender
{
	#pragma unused(sender)
	// If there's a sub-controller then we can't close.
	const id subController = [document anySubController];
	if (subController)
	{
		// Focus the sub-controller's window
		[[subController window] performSelector: @selector(makeKeyAndOrderFront:)
									 withObject: nil afterDelay: 0];
		NSBeep();
		return FALSE;
	}

	return TRUE;
}


//----------------------------------------------------------------------------------------

- (void) windowWillClose: (NSNotification*) notification
{
	#pragma unused(notification)
	[document removeObserver: self forKeyPath: @"flatMode"];
	fPrefsChanged = TRUE;
	[self savePrefs];

	document = nil;
	drawerLogView = nil;
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
	if (!fPrefsChanged || document == nil || ![window isVisible])
		return;

	fPrefsChanged = FALSE;
	const GCoord treeWidth = [SubView(splitView, 0) frame].size.width;
	if (treeWidth > 0)
		fTreeWidth = treeWidth;
	const id sortDescs = [NSArchiver archivedDataWithRootObject: [svnFilesAC sortDescriptors]];
	SetPreference(PrefKey([document windowTitle]),
				  [NSDictionary dictionaryWithObjectsAndKeys:
								[window stringWithSavedFrame],                   keyWidowFrame,
								[NSNumber numberWithInt: [self currentMode]],    keyViewMode,
								[NSNumber numberWithInt: [document filterMode]], keyFilterMode,
								NSBool([[window toolbar] isVisible]),            keyShowToolbar,
								NSBool(IsOpen(sidebar)),                         keyShowSidebar,
								[NSNumber numberWithFloat: fTreeWidth],          keyTreeWidth,
								[document outlineSelectedPath],                  keyTreeSelPath,
								fTreeExpanded,                                   keyTreeExpanded,
								sortDescs,                                       keySortDescs,
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

- (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	#pragma unused(object, change, context)
	if ([keyPath isEqualToString: @"flatMode"])
	{
		[self adjustOutlineView];
	}
}


//----------------------------------------------------------------------------------------

- (void) keyDown: (NSEvent*) theEvent
{
	ConstString chars = [theEvent charactersIgnoringModifiers];
	const unichar ch = [chars characterAtIndex: 0];
	const UInt32 modifiers = [theEvent modifierFlags];

	if (ch == '\r' || ch == 3)
	{
		[self doubleClickInTableView: nil];
	}
	else if ((modifiers & (NSControlKeyMask | NSCommandKeyMask)) == NSControlKeyMask) // ctrl+<letter> => command button
	{
		for_each_obj(enumerator, cell, [WGetView(window, vCmdButtons) cells])
		{
			ConstString keys = [cell keyEquivalent];
			if (keys != nil && [keys length] == 1 && ch == ([keys characterAtIndex: 0] | 0x20))
			{
				[cell performClick: self];
				break;
			}
		}
	}
	else if (ch >= ' ' && ch < 0xF700 && (modifiers & NSCommandKeyMask) == 0)
	{
		NSTableView* const tableView = tableResult;
		NSArray* const dataArray = [svnFilesAC arrangedObjects];
		const int rows = [dataArray count];
		int selRow = [svnFilesAC selectionIndex];
		if (selRow == NSNotFound)
			selRow = rows - 1;
		const unichar ch0 = (ch >= 'a' && ch <= 'z') ? (ch - 32) : ch;
		for (int i = 1; i <= rows; ++i)
		{
			const int index = (selRow + i) % rows;
			NSString* name = [[dataArray objectAtIndex: index] objectForKey: @"displayPath"];
			if ([name length] && ([name characterAtIndex: 0] & ~0x20) == ch0)
			{
				[tableView selectRow: index byExtendingSelection: FALSE];
				[tableView scrollRowToVisible: index];
				break;
			}
		}
	}
	else
		[super keyDown: theEvent];
}


//----------------------------------------------------------------------------------------

- (void) saveSelection
{
	if ([[svnFilesAC arrangedObjects] count] > 0)
	{
		SetVar(savedSelection, [self selectedFilePaths]);
	}
//	dprintf("savedSelection=%@", savedSelection);
}


//----------------------------------------------------------------------------------------

- (void) restoreSelection
{
//	dprintf("savedSelection=%@ tree='%@'", savedSelection, [document outlineSelectedPath]);
	if (savedSelection != nil)
	{
		NSArray* const wcFiles = [svnFilesAC arrangedObjects];
		NSMutableIndexSet* sel = [NSMutableIndexSet indexSet];

		for_each_obj(en, fullPath, savedSelection)
		{
			int index = 0;
			for_each_obj(wcEn, wcIt, wcFiles)
			{
				if ([fullPath isEqualToString: [wcIt objectForKey: @"fullPath"]])
				{
					[sel addIndex: index];
					break;
				}
				++index;
			}
		}

		if ([sel count])
			[svnFilesAC setSelectionIndexes: sel];

		[savedSelection release];
		savedSelection = nil;
		[self selectionChanged];
	}
}


//----------------------------------------------------------------------------------------
// Return TRUE if there is no sheet blocking this window, otherwise beep & return FALSE.

- (BOOL) noSheet
{
	if ([window attachedSheet])
	{
		NSBeep();
		return FALSE;
	}
	return TRUE;
}


//----------------------------------------------------------------------------------------

- (void) selectionChanged
{
	if ([window isVisible])
	{
		Props_Changed(self);
	}
}


//----------------------------------------------------------------------------------------
#pragma mark -
#pragma mark IBActions
//----------------------------------------------------------------------------------------

- (IBAction) refresh: (id) sender
{
	#pragma unused(sender)
	if (!svnStatusPending && [self noSheet])
		[document svnRefresh];
}


- (IBAction) toggleView: (id) sender
{
	#pragma unused(sender)
	//[[self document] setFlatMode: !([[self document] flatMode])];

//	[self adjustOutlineView];
}


//----------------------------------------------------------------------------------------

- (IBAction) performAction: (id) sender
{
	const BOOL isButton = ISA(sender, NSMatrix);
	const SvnCommand action = isButton ? SelectedTag(sender) : [sender tag];

	if (action == cmdReview || action == cmdReviewAlt)
	{
		const id subController = [document anySubController];
		if (subController == nil || action == cmdReviewAlt || AltOrShiftPressed())
			[ReviewController performSelector: @selector(openForDocument:) withObject: document afterDelay: 0];
		else
			[[subController window] makeKeyAndOrderFront: self];
	}
	else if (action == cmdUpdateAlt || (isButton && action == cmdUpdate && AltOrShiftPressed()))
	{
		[self requestSvnUpdate: TRUE];
	}
	else if (action == cmdCommit)
	{
		[self startCommitMessage: @"selected"];
	}
	else if (action == cmdResolve)
	{
		[document svnResolve: [self selectedFilePaths]];
	}
	else if (action == cmdCleanup)
	{
		[self svnCleanup_Request];
	}
	else if (action == cmdRename || action == cmdCopy)
	{
		[self requestNameSheet: action];
	}
	else if (action == cmdInfo || action == cmdInfoRecursive)
	{
		id paths = [self selectedFilePaths];
		if ([paths count] == 0)		// Use selected tree folder or nil => WC
			paths = [document flatMode] ? nil : [document treeSelectedFullPath];
		[self openSidebar];
		[document svnInfo: paths options: (action == cmdInfoRecursive) ? @"--recursive" : nil];
	}
	else if (action < sizeof(gCommands) / sizeof(gCommands[0]))
	{
		[self performSelector: @selector(runAlertBeforePerformingAction:)
			  withObject: makeCommand(gCommands[action], gVerbs[action], nil)
			  afterDelay: 0];
	}
	else
		dprintf("(%@): ERROR: action=%d", sender, action);
}


//----------------------------------------------------------------------------------------
// If there is a single selected item then return it else return nil.
// Private:

- (NSDictionary*) selectedItemOrNil
{
	NSArray* const selectedObjects = [svnFilesAC selectedObjects];
	return ([selectedObjects count] == 1) ? [selectedObjects objectAtIndex: 0] : nil;
}


//----------------------------------------------------------------------------------------

- (void) doubleClickInTableView: (id) sender
{
	#pragma unused(sender)
	NSArray* const filePaths = [self selectedFilePaths];
	if ([filePaths count] != 0)
		OpenFiles(filePaths);
}


//----------------------------------------------------------------------------------------

- (void) adjustOutlineView
{
	[document setSvnFiles: nil];
	NSView* view;
	if ([document flatMode])
	{
		[self closeOutlineView];
		view = tableResult;
	}
	else
	{
		[self openOutlineView];
		view = outliner;
	}
	[window makeFirstResponder: view];
}


//----------------------------------------------------------------------------------------

- (void) openOutlineView
{
	NSRect frame = [splitView frame];
	GCoord width = [[splitView superview] frame].size.width;
	frame.origin.x = 0;
	frame.size.width = width;
	[splitView setFrame: frame];
	[SubView(splitView, 0) setHidden: NO];

	width = [self splitView: splitView constrainMaxCoordinate: width - [splitView dividerThickness] ofSubviewAt: 0];
	if (fTreeWidth > width)
		fTreeWidth = width;
	initSplitView(splitView, fTreeWidth, nil);
}


//----------------------------------------------------------------------------------------

- (void) closeOutlineView
{
	NSView* const leftView = SubView(splitView, 0);

	const GCoord kDivGap = [splitView dividerThickness];
	NSRect frame = [splitView frame];
	frame.origin.x = -kDivGap;
	frame.size.width = [[splitView superview] frame].size.width + kDivGap;
	[splitView setFrame: frame];

	frame = [leftView frame];
	if (frame.size.width > 0)
		fTreeWidth = frame.size.width;
	frame.size.width = 0;
	[leftView setFrame: frame];
	[leftView setHidden: YES];

	[splitView adjustSubviews];
}


//----------------------------------------------------------------------------------------

- (void) fetchSvnStatus
{
	[self startProgressIndicator];

	[document fetchSvnStatus: AltOrShiftPressed()];
}


//----------------------------------------------------------------------------------------

- (void) fetchSvnInfo
{
	[self startProgressIndicator];

	[document fetchSvnInfo];
}


//----------------------------------------------------------------------------------------

- (void) fetchSvnStatusVerboseReceiveDataFinished
{
	if (![window isVisible])
		return;
	[self stopProgressIndicator];

	NSOutlineView* const tree = outliner;
	if ([tree numberOfRows] != 0)
	{
		// Save the path of the selected tree item
		ConstString selPath = [document outlineSelectedPath];

		[tree reloadData];
		Assert([tree numberOfRows] > 0);

		// Restore the expanded tree items
		UInt32 xIndex = 0, xCount = [fTreeExpanded count];
		id xPath = nil, item;
		for (int index = 0; (item = [tree itemAtRow: index]) != nil; ++index)
		{
			NSString* path = [item path];
			if (xPath == nil && xIndex < xCount)
				xPath = [fTreeExpanded objectAtIndex: xIndex++];
			if (xPath != nil && [xPath isEqualToString: path])
			{
				[tree expandItem: item];
				xPath = nil;
			}
		}

		[self selectTreePath: selPath];
	}
	svnStatusPending = NO;
}


//----------------------------------------------------------------------------------------
// Filter mode

- (void) setFilterMode: (int) mode
{
	[document setFilterMode: mode];
	[svnFilesAC rearrangeObjects];
	[self prefsChanged];
}


//----------------------------------------------------------------------------------------
// The Filter toolbar pop-up menu has changed

- (IBAction) changeFilter: (id) sender
{
	if ([self noSheet])
		[self setFilterMode: [[sender selectedItem] tag]];
	else
		[sender selectItemWithTag: [document filterMode]];
}


//----------------------------------------------------------------------------------------

- (IBAction) openRepository: (id) sender
{
	#pragma unused(sender)
	if ([self noSheet])
	{
		[[NSApp delegate] openRepository: [document repositoryUrl] user: [document user] pass: [document pass]];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) toggleSidebar: (id) sender
{
	if ([self noSheet])
	{
		[sidebar toggle: sender];
		[self prefsChanged];
	}
}


//----------------------------------------------------------------------------------------

- (void) openSidebar
{
	if (!IsOpen(sidebar))
	{
		[sidebar open: nil];
		[self prefsChanged];
	}
}


//----------------------------------------------------------------------------------------
// View mode: Sent by command key menu

- (IBAction) changeMode: (id) sender
{
//	dprintf("%@ tag=%d", sender, [sender tag]);
	if ([self noSheet])
		[self setCurrentMode: [sender tag] % 10];	// kModeTree, kModeFlat or kModeSmart
}


//----------------------------------------------------------------------------------------
// View mode

- (int) currentMode
{
	return [document smartMode] ? kModeSmart : ([document flatMode] ? kModeFlat : kModeTree);
}


//----------------------------------------------------------------------------------------
// View mode

- (void) setCurrentMode: (int) mode
{
//	dprintf("%d", mode);
	if ([self currentMode] != mode)
	{
		[self saveSelection];
		switch (mode)
		{
			case kModeTree:
				if ([document flatMode])
					[document setFlatMode: FALSE];
				break;

			case kModeFlat:
				if ([document smartMode])
					[document setSmartMode: FALSE];
				else if (![document flatMode])
					[document setFlatMode: TRUE];
				break;

			case kModeSmart:
				if (![document smartMode])
					[document setSmartMode: TRUE];
				break;
		}
		[self prefsChanged];
	}
}


//----------------------------------------------------------------------------------------

- (void) resetStatusMessage
{
	if ([window isVisible])
	{
		id obj = [document repositoryUrl];
		if (obj == nil)
		{
			[self performSelector: @selector(resetStatusMessage) withObject: nil afterDelay: 0.1];	// try later
			return;
		}

		[statusView setStringValue: PathWithRevision(obj, [document revision])];
	}
	[window release];		// iff window is hidden or statusView was set
}


//----------------------------------------------------------------------------------------

- (void) setStatusMessage: (NSString*) message
{
	if (message)
		[statusView setStringValue: message];
	else
	{
		[window retain];
		[self resetStatusMessage];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) togglePropsView: (id) sender
{
	#pragma unused(sender)
	if (Props_Toggle())
		[self selectionChanged];
}


//----------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Split View delegate
//----------------------------------------------------------------------------------------

- (BOOL) splitView:          (NSSplitView*) sender
		 canCollapseSubview: (NSView*)      subview
{
	#pragma unused(sender, subview)
#if 0
	NSView* leftView = SubView(splitView, 0);

	if (subview == leftView)
	{
		return NO; // I would like to return YES here, but can't find a way to uncollapse a view programmatically.
				   // Collasping a view is obviously not setting its width to 0 ONLY.
				   // If I allow user collapsing here, I won't be able to expand the left view with the "toggle button"
				   // (it will remain closed, in spite of a size.width > 0);
	}
#endif

	return NO;
}


//----------------------------------------------------------------------------------------

- (GCoord) splitView:              (NSSplitView*) sender
		   constrainMaxCoordinate: (GCoord)       proposedMax
		   ofSubviewAt:            (int)          offset
{
	#pragma unused(sender, offset)
	return proposedMax * kMaxTreeWidthFract;	// max tree width = proposedMax * kMaxTreeWidthFract
}


//----------------------------------------------------------------------------------------

- (GCoord) splitView:              (NSSplitView*) sender
		   constrainMinCoordinate: (GCoord)       proposedMin
		   ofSubviewAt:            (int)          offset
{
	#pragma unused(sender, proposedMin, offset)
	return kMinTreeWidth;						// min tree width = kMinTreeWidth
}


//----------------------------------------------------------------------------------------

- (void) splitView:                 (NSSplitView*) sender
		 resizeSubviewsWithOldSize: (NSSize)       oldSize
{
	#pragma unused(oldSize)
	NSArray* subviews = [sender subviews];
	NSView* view0 = [subviews objectAtIndex: 0];
	NSView* view1 = [subviews objectAtIndex: 1];
	NSRect frame  = [sender frame],								// get the new frame of the whole splitView
		   frame0 = [view0 frame],								// current frame of the left/top subview
		   frame1 = [view1 frame];								// ...and the right/bottom
	const GCoord kDivGap = [sender dividerThickness],
				 kWidth  = frame.size.width,
				 kHeight = frame.size.height;

	{								// Adjust split view so that the left frame stays a constant size
		GCoord width0 = frame0.size.width;
		if (width0 > (kWidth - kDivGap) * kMaxTreeWidthFract)
			width0 = (kWidth - kDivGap) * kMaxTreeWidthFract;
		frame0.size.width  = width0;							// prevent files from shrinking too much
		frame0.size.height = kHeight;							// full height

		const GCoord x1 = width0 + kDivGap;
		frame1.origin.x    = x1;
		frame1.size.width  = kWidth - x1;						// the rest of the width
		frame1.size.height = kHeight;							// full height
	}

	[view0 setFrame: frame0];
	[view1 setFrame: frame1];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Svn Operation Requests
//----------------------------------------------------------------------------------------
#pragma mark	svn update

enum {
	vUpdateDesc		=	100,
	vNumberField	=	101,
	vNumberStepper	=	102,
	vDateField		=	103,
	vRecursive		=	104,
	vIgnoreExts		=	105,
	vUpdateKind		=	200,

	vRevHead		=	201,
	vRevBase		=	202,
	vRevCommitted	=	203,
	vRevPrev		=	204,
	vRevNumber		=	205,
	vRevDate		=	206
};


//----------------------------------------------------------------------------------------

- (void) requestSvnUpdate: (BOOL) forSelection
{
	NSView* const root = [updateSheet contentView];
	NSString* msg = @"Update entire working copy to:";
	if (forSelection)
	{
		NSArray* const selObjs = [svnFilesAC selectedObjects];
		const int count = [selObjs count];
		msg = (count == 1) ? [NSString stringWithFormat: @"Update item %C%@%C to:",
									0x201C, [[selObjs lastObject] objectForKey: @"displayPath"], 0x201D]
						   : [NSString stringWithFormat: @"Update %d items to:", count];
	}
	SetViewString(root, vUpdateDesc, msg);

	const SvnRevNum revNum = [[document revision] intValue];
	// TO_DO
//	[GetView(root, vNumberStepper) setMaxValue: <repo HEAD revNum>];
	if (!updateInited)
	{
		updateInited = TRUE;
		SetViewInt(root, vNumberField, revNum);
		SetViewInt(root, vNumberStepper, revNum);

		[GetView(root, vDateField) setDateValue: [NSDate date]];
		[self updateSheetSetKind: nil];
	}

	[NSApp beginSheet:     updateSheet
		   modalForWindow: [self window]
		   modalDelegate:  self
		   didEndSelector: @selector(updateSheetDidEnd:returnCode:contextInfo:)
		   contextInfo:    (void*) (intptr_t) forSelection];
}


//----------------------------------------------------------------------------------------

- (void) updateSheetSetKind: (id) updateKindView
{
	NSWindow* const aWindow = updateSheet;
	if (updateKindView == nil)
		updateKindView = WGetView(aWindow, vUpdateKind);
	const int kind = SelectedTag(updateKindView);

	WViewEnable(aWindow, vNumberField,   (kind == vRevNumber));
	WViewEnable(aWindow, vNumberStepper, (kind == vRevNumber));
	WViewEnable(aWindow, vDateField,     (kind == vRevDate));

	[aWindow makeFirstResponder: aWindow];
	[aWindow selectNextKeyView: self];
}


//----------------------------------------------------------------------------------------

- (IBAction) updateSheetDoClick: (id) sender
{
	const int tag = [sender tag];
	switch (tag)
	{
		case NSOKButton:
			if (SelectedTag(WGetView(updateSheet, vUpdateKind)) == vRevNumber &&
				![updateSheet makeFirstResponder: nil])
			{
				NSBeep();
				break;
			}
			suppressAutoRefresh = TRUE;
			// Fall through
		case NSCancelButton:
			[NSApp endSheet: updateSheet returnCode: tag];
			break;

		case vNumberField:
		case vNumberStepper:
			[WGetView(updateSheet, tag ^ vNumberField ^ vNumberStepper) takeIntValueFrom: sender];
			break;

		case vUpdateKind:
			[self updateSheetSetKind: sender];
			break;
	}
}


//----------------------------------------------------------------------------------------

- (void) updateSheetDidEnd: (NSWindow*) sheet
		 returnCode:        (int)       returnCode
		 contextInfo:       (void*)     contextInfo
{
	[sheet orderOut: self];
	if (returnCode != NSOKButton) return;

	NSView* const root = [sheet contentView];

	NSString* revision = nil;
	switch (SelectedTag(GetView(root, vUpdateKind)))
	{
		case vRevHead:
			revision = @"HEAD";
			break;

		case vRevBase:
			revision = @"BASE";
			break;

		case vRevCommitted:
			revision = @"COMMITTED";
			break;

		case vRevPrev:
			revision = @"PREV";
			break;

		case vRevNumber:
		{
			const SvnRevNum revNum = GetViewInt(root, vNumberField);
			Assert(revNum >= 1 && revNum <= 9999999);
			revision = SvnRevNumToString(revNum);
			break;
		}

		case vRevDate:
			revision = [NSString stringWithFormat: @"{%@}",
				[[[GetView(root, vDateField) dateValue] description] substringToIndex: 10]];
			break;

		default:
			dprintf("UNKNOWN cell.tag=%d", SelectedTag(GetView(root, vUpdateKind)));
			break;
	}

	if (revision != nil)
	{
		id arg1 = nil, arg2 = nil;
		if (!GetViewInt(root, vRecursive))
			arg1 = @"--non-recursive";
		if (GetViewInt(root, vIgnoreExts))
			*(arg1 ? &arg2 : &arg1) = @"--ignore-externals";

		[document performSelector: contextInfo ? @selector(svnUpdateSelectedItems:)	// current selection
											   : @selector(svnUpdate:)				// entire working copy
					   withObject: [NSArray arrayWithObjects: @"-r", revision, arg1, arg2, nil]
					   afterDelay: 0.1];
	}
}


//----------------------------------------------------------------------------------------

- (void) svnUpdate: (id) sender
{
	#pragma unused(sender)
	if (![self noSheet])
		;
	else if (AltOrShiftPressed())
	{
		[self requestSvnUpdate: FALSE];
	}
	else
	{
		[[NSAlert alertWithMessageText: @"Update this working copy to the latest revision?"
						 defaultButton: @"OK"
					   alternateButton: @"Cancel"
						   otherButton: nil
			 informativeTextWithFormat: @""]

			beginSheetModalForWindow: [self window]
					   modalDelegate: self
					  didEndSelector: @selector(updateWorkingCopyPanelDidEnd:returnCode:contextInfo:)
						 contextInfo: NULL];
	}
}


//----------------------------------------------------------------------------------------

- (void) updateWorkingCopyPanelDidEnd: (NSAlert*) alert
		 returnCode:                   (int)      returnCode
		 contextInfo:                  (void*)    contextInfo
{
	#pragma unused(alert, contextInfo)
	if (returnCode == NSOKButton)
	{
		suppressAutoRefresh = TRUE;
		[document performSelector: @selector(svnUpdate) withObject: nil afterDelay: 0.1];
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	svn diff
//----------------------------------------------------------------------------------------

- (void) fileHistoryOpenSheetForItem: (id) item
{
	if (item == nil)
		item = [document findRootItem];

	if (item == nil)
		return;
	// close the sheet if it is already open
	if ([window attachedSheet])
		[NSApp endSheet: [window attachedSheet]];

	[MyFileMergeController runSheet: document path: [item objectForKey: @"fullPath"] sourceItem: item];
}


//----------------------------------------------------------------------------------------
// Ask user to confirm diff of entire WC.

- (void) svnDiff_Request: (id) options
{
	NSAlert* alert =
		[NSAlert alertWithMessageText: options ? @"Diff this entire working copy with its PREV revision?"
											   : @"Diff this entire working copy with its BASE revision?"
						defaultButton: nil		// OK
					  alternateButton: @"Cancel"
						  otherButton: nil
			informativeTextWithFormat: @"Select one or more items first to show only their diffs."];
	[alert beginSheetModalForWindow: window
					  modalDelegate: self
					 didEndSelector: @selector(svnDiff_SheetEnded:returnCode:contextInfo:)
						contextInfo: [options retain]];
}


//----------------------------------------------------------------------------------------

- (void) svnDiff_SheetEnded: (NSAlert*) alert
		 returnCode:         (int)      returnCode
		 contextInfo:        (void*)    contextInfo
{
	#pragma unused(alert)

	if (returnCode == NSOKButton)
	{
		[document svnDiff: nil options: (id) contextInfo];	// Diff entire WC
	}
	[(id) contextInfo autorelease];
}


//----------------------------------------------------------------------------------------

- (void) svnDiffWithOption: (NSString*) option
{
	if ([self noSheet])
	{
		NSArray* paths = [self selectedFilePaths];
		if ([paths count] == 0)
			[self svnDiff_Request: option];
		else
			[document svnDiff: paths options: option];
	}
}


//----------------------------------------------------------------------------------------
// Diff each selected item with its BASE revision.  If no selection ask user.

- (IBAction) diffBase: (id) sender
{
	#pragma unused(sender)
	[self svnDiffWithOption: nil];
}


//----------------------------------------------------------------------------------------
// Diff each selected item with its PREV revision.  If no selection ask user.

- (IBAction) diffPrev: (id) sender
{
	#pragma unused(sender)
	[self svnDiffWithOption: @"-rPREV"];
}


//----------------------------------------------------------------------------------------
// Open diff/log sheet for first selected item or entire WC if no selection.

- (IBAction) diffSheet: (id) sender
{
	#pragma unused(sender)
	if ([self noSheet])
	{
		NSArray* const selection = [svnFilesAC selectedObjects];
		[self fileHistoryOpenSheetForItem: [selection count] ? [selection objectAtIndex: 0] : nil];
	}
}


//----------------------------------------------------------------------------------------
// Called by Diff toolbar item.
// diff with BASE:   click Diff        |  cmd-D        ->  diffBase:
// diff with PREV:   shift-click Diff  |  cmd-shift-D  ->  diffPrev: 
// open diff sheet:  alt-click Diff    |  cmd-L        ->  diffSheet:

- (void) svnDiff: (id) sender
{
	#pragma unused(sender)
	if ([self noSheet])
	{
		const UInt32 modifiers = [[NSApp currentEvent] modifierFlags];
		if ((modifiers & NSShiftKeyMask) != 0)				// shift-click
		{
			[self diffPrev: nil];
		}
		else if ((modifiers & NSAlternateKeyMask) != 0)		// alt-click
		{
			[self diffSheet: nil];
		}
		else												// click
		{
			[self diffBase: nil];
		}
	}
}


- (void) sheetDidEnd: (NSWindow*) sheet
		 returnCode:  (int)       returnCode
		 contextInfo: (void*)     contextInfo
{
	[sheet orderOut: nil];

	if ( returnCode == 1 )
	{
	}

	[(MyFileMergeController*) contextInfo finished];
}


//----------------------------------------------------------------------------------------
#pragma mark	svn rename
//----------------------------------------------------------------------------------------
// In-line edit of WC item name.

- (void) requestSvnRenameSelectedItemTo: (NSString*) destination
{
	[self runAlertBeforePerformingAction: makeCommandDict(@"rename", destination)];
}


//----------------------------------------------------------------------------------------
#pragma mark	svn move

- (void) requestSvnMoveSelectedItemsToDestination: (NSString*) destination
{
	[self renamePanelForCopy: false destination: destination];
}


//----------------------------------------------------------------------------------------
#pragma mark	svn copy

- (void) requestSvnCopySelectedItemsToDestination: (NSString*) destination
{
	[self renamePanelForCopy: true destination: destination];
}


//----------------------------------------------------------------------------------------
#pragma mark	svn copy & svn move common

- (void) renameSheet: (SvnCommand) cmd
		 filePaths:   (NSArray*)   filePaths
		 destination: (NSString*)  destination
{
	Assert(cmd == cmdRename || cmd == cmdCopy || cmd == cmdMove);
	NSMutableDictionary* action = makeCommandDict(gCommands[cmd], destination);
	if (filePaths == nil)
		filePaths = [self selectedFilePaths];
	[action setObject: filePaths forKey: @"itemPaths"];

	if ([filePaths count] == 1)
	{
		suppressAutoRefresh = TRUE;
		ConstString fullPath = [filePaths lastObject];
		NSString* title = (cmd == cmdCopy) ? @"Copy and Rename" : @"Move and Rename";
		// If dest dir == source dir then use the following titles instead
		if ([destination isEqualToString: [fullPath stringByDeletingLastPathComponent]])
			title = (cmd == cmdCopy) ? @"Copy" : @"Rename";
		[[[renamePanel contentView] viewWithTag: 100] setStringValue: title];
		[renamePanelTextField setStringValue: [fullPath lastPathComponent]];
		[renamePanelTextField selectText: self];
		[NSApp beginSheet:     renamePanel
			   modalForWindow: [self window]
			   modalDelegate:  self
			   didEndSelector: @selector(renamePanelDidEnd:returnCode:contextInfo:)
			   contextInfo:    [action retain]];
	}
	else
		[self runAlertBeforePerformingAction: action];
}


//----------------------------------------------------------------------------------------

- (void) renamePanelForCopy: (BOOL)      isCopy
		 destination:        (NSString*) destination
{
	[self renameSheet: isCopy ? cmdCopy : cmdMove filePaths: nil destination: destination];
}


//----------------------------------------------------------------------------------------

- (void) renamePanelDidEnd: (NSWindow*) sheet
		 returnCode:        (int)       returnCode
		 contextInfo:       (void*)     contextInfo
{
	[sheet orderOut: nil];
	NSMutableDictionary* action = contextInfo;

	[action setObject: [[(id) contextInfo objectForKey: @"destination"]
						stringByAppendingPathComponent: [renamePanelTextField stringValue]]
			forKey: @"destination"];

	if (returnCode == NSOKButton)
	{
		[self performSelector: @selector(svnCommand:) withObject: action afterDelay: 0];
	}
	else
		[action release];
}


- (IBAction) renamePanelValidate: (id) sender
{
	[NSApp endSheet: renamePanel returnCode: [sender tag]];
}


//----------------------------------------------------------------------------------------
// User requested to rename or copy the selected item.

- (void) requestNameSheet: (SvnCommand) cmd
{
	NSDictionary* const item = [self selectedItemOrNil];
	if (item)
	{
		ConstString fullPath = [item objectForKey: @"fullPath"];
		[self renameSheet: cmd
				filePaths: [NSArray arrayWithObject: fullPath]
			  destination: [fullPath stringByDeletingLastPathComponent]];
	}
	else
		[self svnError: @"Please select exactly one item."];
}


//----------------------------------------------------------------------------------------
#pragma mark	svn cleanup
//----------------------------------------------------------------------------------------
// Ask user to confirm cleanup of entire working copy, current folder or selected folders.

- (void) svnCleanup_Request
{
	NSString* firstName = nil;
	NSArray* paths = getDirFullPaths([svnFilesAC selectedObjects], &firstName);

	int count = [paths count];
	if (count == 0 && ![document flatMode])	// Selected tree folder
	{
		count = 1;
		firstName = [document outlineSelectedPath];
		[(NSMutableArray*) paths addObject: [document treeSelectedFullPath]];
	}

	NSString* msg;
	if (count == 0 || [paths containsObject: [document workingCopyPath]])
	{
		msg = @"Recursively clean up this entire working copy.";
		paths = nil;	// => [fDocument workingCopyPath]
	}
	else if (count == 1)
		msg = [NSString stringWithFormat: @"Recursively clean up folder \u201C%@\u201D.", firstName];
	else
		msg = [NSString stringWithFormat: @"Recursively clean up the %u selected folders.", count];

	NSAlert* alert = [NSAlert alertWithMessageText: msg
									 defaultButton: nil		// OK
								   alternateButton: @"Cancel"
									   otherButton: nil
						 informativeTextWithFormat: @""];
	[alert beginSheetModalForWindow: window
					  modalDelegate: self
					 didEndSelector: @selector(svnCleanup:returnCode:contextInfo:)
						contextInfo: [paths retain]];
}


//----------------------------------------------------------------------------------------

- (void) svnCleanup:  (NSAlert*) alert
		 returnCode:  (int)      returnCode
		 contextInfo: (void*)    contextInfo
{
	#pragma unused(alert)
	NSArray* const paths = [(NSArray*) contextInfo autorelease];

	if (returnCode == NSOKButton)
	{
		suppressAutoRefresh = TRUE;
		[[alert window] orderOut: nil];
		[document svnCleanup: paths];
	}
}


//----------------------------------------------------------------------------------------
// called from MyDragSupportWindow
#pragma mark	svn merge

enum {
	vMergeURL1			=	2,
	vMergeURL2			=	3,
	vMergeKind			=	4,
	vMergeReverse		=	5,
	vMergeRecursive		=	6,
	vMergeTarget		=	7,
	vMergeRevNum		=	11,
	vMergeRevStep		=	12,

	kMergeKind1Change	=	101,
	kMergeKindRevRange	=	102,
	kMergeKind2URLs		=	103
};

/*
	merge: Apply the differences between two sources to a working copy path.
	usage: 1. merge sourceURL1[@N] sourceURL2[@M] [WCPATH]
		   2. merge sourceWCPATH1@N sourceWCPATH2@M [WCPATH]
		   3. merge [-c M | -r N:M] SOURCE[@REV] [WCPATH]

	  1. In the first form, the source URLs are specified at revisions N and M.  These
		 are the two sources to be compared.  The revisions default to HEAD if omitted.

	  2. In the second form, the URLs corresponding to the source working copy paths
		 define the sources to be compared.  The revisions must be specified.

	  3. In the third form, SOURCE can be a URL, or working copy item in which case the
		 corresponding URL is used.  This URL in revision REV is compared as it existed
		 between revisions N and M.  If REV is not specified, HEAD is assumed.
		 The '-c M' option is equivalent to '-r N:M' where N = M-1.
		 Using '-c -M' does the reverse: '-r M:N' where N = M-1.

	  WCPATH is the working copy path that will receive the changes. If WCPATH is omitted,
	  a default value of '.' is assumed, unless the sources have identical basenames that
	  match a file within '.': in which case, the differences will be applied to that file.

	Valid options:
	  -r [--revision] arg      : ARG (some commands also take ARG1:ARG2 range)
	  -c [--change] arg        : the change made by revision ARG (like -r ARG-1:ARG)
								 If ARG is negative this is like -r ARG:ARG-1
	  -N [--non-recursive]     : operate on single directory only
	  -q [--quiet]             : print as little as possible
	  --force                  : force operation to run
	  --dry-run                : try operation but make no changes
	  --diff3-cmd arg          : use ARG as merge command
	  -x [--extensions] arg    : Default: '-u'.
	  --ignore-ancestry        : ignore ancestry when calculating merges
	  --username arg           : specify a username ARG
	  --password arg           : specify a password ARG
	  --no-auth-cache          : do not cache authentication tokens
	  --non-interactive        : do no interactive prompting
	  --config-dir arg         : read user configuration files from directory ARG
*/

//----------------------------------------------------------------------------------------
/*
	Options are:
		Reverse direction checkbox.
		Recursive checkbox.
		1. No additional options:
				merge --change <revision> <path>@<revision> <working-copy-target>
		2. Additional revision number:
				merge --revision <revision2>:<revision> <path>@<revision> <working-copy-target>
		2. Additional URL:
				merge <path2>@<revision2> <path1>@<revision1> <working-copy-target>
	Supports dragging of URLs into the merge sheet.
	Chooses the most appropriate merge target based on the URLs kind (file or dir),
	the selected items in the WC window, and the name of the URLs file.
*/

- (void) requestMergeFrom: (RepoItem*) repositoryPathObj
{
	NSString* const revision = [repositoryPathObj revision];

	[WGetView(mergeSheet, vMergeURL1) setRepoItem: repositoryPathObj];
	[WGetView(mergeSheet, vMergeURL2) setRepoItem: nil];
	[self mergeSheetSetKind: nil];
	WSetViewString(mergeSheet, vMergeRevNum, revision);
	WSetViewString(mergeSheet, vMergeRevStep, revision);

	// If we couldn't find a suitable target then alert the user & bail
	if ([WGetView(mergeSheet, vMergeURL1) repoItem] == nil)
	{
		NSAlert* alert =
			[NSAlert alertWithMessageText: @"Could not find a target for this item."
							defaultButton: @"OK"
						  alternateButton: nil
							  otherButton: nil
				informativeTextWithFormat: @"Select a suitable target to receive the changes then try again."];

		[alert setAlertStyle: NSWarningAlertStyle];
		[alert	beginSheetModalForWindow: window
						   modalDelegate: nil
						  didEndSelector: NULL
							 contextInfo: nil];
		return;
	}

	[NSApp beginSheet:     mergeSheet
		   modalForWindow: [self window]
		   modalDelegate:  self
		   didEndSelector: @selector(mergeSheetDidEnd:returnCode:contextInfo:)
		   contextInfo:    NULL];
}


//----------------------------------------------------------------------------------------

- (int) mergeSheetSetKind: (id) mergeKindView
{
	NSWindow* const aWindow = mergeSheet;
	if (mergeKindView == nil)
		mergeKindView = WGetView(aWindow, vMergeKind);
	const int kind = SelectedTag(mergeKindView);
	bool showRevRange = (kind == kMergeKindRevRange),
		 showURL2     = (kind == kMergeKind2URLs);

	WViewEnable(aWindow, vMergeRevNum,   showRevRange);
	WViewEnable(aWindow, vMergeRevStep,  showRevRange);
	WViewEnable(aWindow, vMergeURL2,     showURL2);

	[aWindow makeFirstResponder: aWindow];
	[aWindow selectNextKeyView: self];

	return kind;
}


//----------------------------------------------------------------------------------------

- (IBAction) mergeSheetDoClick: (id) sender
{
	const int tag = [sender tag];
	switch (tag)
	{
		case NSOKButton:
		{
			int kind = SelectedTag(WGetView(mergeSheet, vMergeKind));
			if ([WGetView(mergeSheet, vMergeURL1) repoItem] == nil ||
				(kind == kMergeKindRevRange && ![mergeSheet makeFirstResponder: nil]) ||
				(kind == kMergeKind2URLs && [WGetView(mergeSheet, vMergeURL2) repoItem] == nil))
			{
				NSBeep();
				break;
			}
		}
			// Fall through
		case NSCancelButton:
			[NSApp endSheet: mergeSheet returnCode: tag];
			break;

		case vMergeKind:
			[self mergeSheetSetKind: sender];
			break;

		case vMergeRevNum:
		case vMergeRevStep:
			[WGetView(mergeSheet, tag ^ vMergeRevNum ^ vMergeRevStep) takeIntValueFrom: sender];
			break;
	}
}


//----------------------------------------------------------------------------------------
// Find a suitable target for the merge.

- (NSDictionary*) mergeSheetTarget: (RepoItem*) repoItem srcIsDir: (BOOL) srcIsDir
{
	Assert(repoItem != nil);

	BOOL dstIsDir;
	NSFileManager* const fileManager = [NSFileManager defaultManager];

	// Look for a suitable match in the selection
	for_each_obj(en, it, [svnFilesAC selectedObjects])
	{
		if (![[it objectForKey: @"new"] boolValue] &&
			[fileManager fileExistsAtPath: [it objectForKey: @"fullPath"]
						 isDirectory: &dstIsDir] && srcIsDir == dstIsDir)
		{
			return it;
		}
	}

	// Look for a matching name in the WC arranged objects
	NSString* const srcName = [repoItem name];
	for_each_obj(en2, it, [svnFilesAC arrangedObjects])
	{
		if (![[it objectForKey: @"new"] boolValue] &&
			[srcName isEqualToString: [[it objectForKey: @"displayPath"] lastPathComponent]] &&
			[fileManager fileExistsAtPath: [it objectForKey: @"fullPath"]
						 isDirectory: &dstIsDir] && srcIsDir == dstIsDir)
		{
			return it;
		}
	}

	// Look for a matching name in the WC
	for_each_obj(en3, it, [svnFilesAC content])
	{
		if (![[it objectForKey: @"new"] boolValue] &&
			[srcName isEqualToString: [[it objectForKey: @"displayPath"] lastPathComponent]] &&
			[fileManager fileExistsAtPath: [it objectForKey: @"fullPath"]
						 isDirectory: &dstIsDir] && srcIsDir == dstIsDir)
		{
			return it;
		}
	}

	return nil;		// => Working copy root
}


//----------------------------------------------------------------------------------------
// The RepoItemViews send this message when changed.

- (IBAction) mergeSheetURLChanged: (id) sender
{
	const int tag = [sender tag];
	if (tag == vMergeURL1)
	{
		RepoItem* const repoItem = [sender repoItem];
		if (repoItem == nil)
			return;

		const BOOL isDir = [repoItem isDir];
		NSString* value = WCItemDesc([self mergeSheetTarget: repoItem srcIsDir: isDir], isDir);

		WSetViewString(mergeSheet, vMergeTarget, value ? value : @"");
		if (value == nil)	// Source file doesn't match any file in WC
		{
			[sender setRepoItem: nil];
			NSBeep();
		}
		WViewEnable(mergeSheet, vMergeRecursive, isDir);

		// Clear URL 2 if not same kind
		RepoItemView* repoItemView2 = WGetView(mergeSheet, vMergeURL2);
		RepoItem* repoItem2 = [repoItemView2 repoItem];
		if (repoItem2 != nil && isDir != [repoItem2 isDir])
			[repoItemView2 setRepoItem: nil];
	}
	else if (tag == vMergeURL2)
	{
		RepoItem* const repoItem1 = [WGetView(mergeSheet, vMergeURL1) repoItem],
				* const repoItem2 = [sender repoItem];
		if (repoItem2 == nil)
			return;
		if (repoItem1 == nil || [repoItem1 isDir] != [repoItem2 isDir])
		{
			[sender setRepoItem: nil];
			NSBeep();
		}
	}
}


//----------------------------------------------------------------------------------------

- (void) mergeSheetDidEnd: (NSWindow*) sheet
		 returnCode:       (int)       returnCode
		 contextInfo:      (void*)     contextInfo
{
	#pragma unused(contextInfo)
	if (returnCode == NSOKButton)
	{
		RepoItem* const repoItem1 = [WGetView(sheet, vMergeURL1) repoItem],
				* const repoItem2 = [WGetView(sheet, vMergeURL2) repoItem];
		Assert(repoItem1 != nil);
		NSString* const url1 = getPathPegRevision(repoItem1),
				* const rev1 = [repoItem1 revision];
		const int kind = SelectedTag(WGetView(sheet, vMergeKind));
		const bool reverse = (WGetViewInt(sheet, vMergeReverse) == NSOnState);

		const BOOL isDir = [repoItem1 isDir];
		NSDictionary* targetItem = [self mergeSheetTarget: repoItem1 srcIsDir: isDir];
		Assert(targetItem != nil || isDir);
		NSString* const targetPath = targetItem ? [targetItem objectForKey: @"fullPath"]
												: [document workingCopyPath];

	//	NSLog(@"\n    repoItem1=<%@>\n    repoItem2=<%@>", url1, getPathPegRevision(repoItem2));

		id objs[10];
		int count = 0;
		objs[count++] = @"--force";
		if (isDir && WGetViewInt(sheet, vMergeRecursive) == NSOffState)
			objs[count++] = @"--non-recursive";
	//	objs[count++] = @"--dry-run";
	//	objs[count++] = @"--ignore-ancestry";

		switch (kind)
		{
			case kMergeKind1Change:
				// svn merge --force -c [-]<rev1> <url1@rev1> <targetPath>
	//			NSLog(@"\n  svn merge -c %s%@ '%@' '%@'", (reverse ? "-" : ""), rev1, url1, targetPath);
				objs[count++] = @"-c";
				objs[count++] = reverse ? [NSString stringWithFormat: @"-%@", rev1] : rev1;
				objs[count++] = url1;
				objs[count++] = targetPath;
				break;

			case kMergeKindRevRange:
			{	// svn merge --force -r <rev1>:<rev2> <url1@rev1> <targetPath>
				const id rev2 = SvnRevNumToString(WGetViewInt(sheet, vMergeRevNum));
	//			NSLog(@"\n  svn merge -r %@:%@ '%@' '%@'", reverse ? rev1 : rev2,
	//													   reverse ? rev2 : rev1, url1, targetPath);
				objs[count++] = @"-r";
				objs[count++] = [NSString stringWithFormat: @"%@:%@", reverse ? rev1 : rev2,
																	  reverse ? rev2 : rev1];
				objs[count++] = url1;
				objs[count++] = targetPath;
				break;
			}

			case kMergeKind2URLs:
			{	// svn merge --force <url1@rev1> <url2@rev2> <targetPath>
				Assert(repoItem2 != nil);
				const id url2 = getPathPegRevision(repoItem2);
	//			NSLog(@"\n  svn merge '%@' '%@' '%@'", reverse ? url1 : url2, reverse ? url2 : url1, targetPath);
				objs[count++] = reverse ? url1 : url2;
				objs[count++] = reverse ? url2 : url1;
				objs[count++] = targetPath;
				break;
			}

			default:
				count = 0;
				break;
		}

		Assert(count < sizeof(objs) / sizeof(objs[0]));
		if (count > 0)
			[document performSelector: @selector(svnMerge:)
						   withObject: [NSArray arrayWithObjects: objs count: count]
						   afterDelay: 0.1];
	}

	[sheet orderOut: self];		// Here because it can change the selection
}


//----------------------------------------------------------------------------------------
// called from MyDragSupportWindow
#pragma mark	svn switch

- (void) requestSwitchToRepositoryPath: (RepoItem*) repositoryPathObj
{
//	NSLog(@"%@", repositoryPathObj);
	NSString* path = [[repositoryPathObj url] absoluteString];
	NSString* revision = [repositoryPathObj revision];

	NSMutableDictionary* action = makeCommandDict(@"switch", path);
	[action setObject: revision forKey: @"revision"];

	[switchPanelSourceTextField setStringValue: PathWithRevision([document repositoryUrl], [document revision])];
	[switchPanelDestinationTextField setStringValue: PathWithRevision(path, revision)];

	[NSApp beginSheet:     switchPanel
		   modalForWindow: [self window]
		   modalDelegate:  self
		   didEndSelector: @selector(switchPanelDidEnd:returnCode:contextInfo:)
		   contextInfo:    [action retain]];
}


//----------------------------------------------------------------------------------------

- (IBAction) switchPanelValidate: (id) sender
{
	[NSApp endSheet: switchPanel returnCode: [sender tag]];
}


//----------------------------------------------------------------------------------------

- (void) switchPanelDidEnd: (NSWindow*) sheet
		 returnCode:        (int)       returnCode
		 contextInfo:       (void*)     contextInfo
{
	[sheet orderOut: self];
	NSDictionary* action = contextInfo;

	if (returnCode == NSOKButton)
	{
		id objs[10];
		int count = 0;
		objs[count++] = @"-r";
		objs[count++] = [action objectForKey: @"revision"];
		if ([switchPanelRelocateButton intValue] == 1)	// --relocate
		{
			objs[count++] = @"--relocate";
			objs[count++] = [[document repositoryUrl] absoluteString];
		}
		objs[count++] = [action objectForKey: @"destination"];
		objs[count++] = [document workingCopyPath];
		[document performSelector: @selector(svnSwitch:)
					   withObject: [NSArray arrayWithObjects: objs count: count]
					   afterDelay: 0.1];
	}

	[action release];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Common Methods
//----------------------------------------------------------------------------------------

- (NSString*) messageTextForCommand: (NSDictionary*) command
{
	NSString* const verb = [command objectForKey: @"verb"];
	NSArray* const selection = [svnFilesAC selectedObjects];
	const int count = [selection count];

	if (count == 1)
		return [NSString stringWithFormat: @"Are you sure you want to %@ the item %C%@%C?",
							verb, 0x201C, [[selection lastObject] objectForKey: @"displayPath"], 0x201D];

	return [NSString stringWithFormat: @"Are you sure you want to %@ the %u selected items?", verb, count];
}


//----------------------------------------------------------------------------------------

- (NSString*) infoTextForCommand: (NSString*) cmd
{
	if ([cmd isEqualToString: @"remove"])
	{
		NSArray* const selection = [svnFilesAC selectedObjects];
		if ([[selection valueForKey: @"addable"    ] containsObject: kNSTrue] ||
			[[selection valueForKey: @"committable"] containsObject: kNSTrue])
		{
			return @"WARNING: Removing modified or unversioned files may result in loss of data.";
		}
	}

	return @"";
}


//----------------------------------------------------------------------------------------

- (void) runAlertBeforePerformingAction: (NSDictionary*) command
{
	ConstString cmd = [command objectForKey: @"command"];
	if ([cmd isEqualToString: @"commit"])
	{
		[self startCommitMessage: @"selected"];
	}
	else
	{
		NSAlert* alert = [NSAlert alertWithMessageText: [self messageTextForCommand: command]
										 defaultButton: @"OK"
									   alternateButton: @"Cancel"
										   otherButton: nil
							 informativeTextWithFormat: [self infoTextForCommand: cmd]];

		// Add recursive checkbox if supported by command:
		// TO_DO: (possibly) check for folder
		const BOOL isDefaultRecursive = supportsNonRecursiveFlag(cmd);
		if (isDefaultRecursive || supportsRecursiveFlag(cmd))
		{
			NSButton* recursive = [alert addButtonWithTitle: @"Recursive"];
			[recursive setButtonType: NSSwitchButton];
			[[recursive cell] setCellAttribute: NSCellLightsByContents to: 1];
			[recursive setState: (isDefaultRecursive ? NSOnState : NSOffState)];
			[recursive setAction: NULL];
		}

		[alert beginSheetModalForWindow: window
						  modalDelegate: self
						 didEndSelector: @selector(commandPanelDidEnd:returnCode:contextInfo:)
							contextInfo: [command retain]];
	}
}


//----------------------------------------------------------------------------------------

- (void) svnCommand: (id) action
{
	ConstString command = [action objectForKey: @"command"];
	NSArray* const itemPaths = [action objectForKey: @"itemPaths"];
	id recursive = [action objectForKey: @"recursive"];
	if (recursive != nil)
		recursive = getRecursiveOption(command, [recursive boolValue]);

	if ([command isEqualToString: @"rename"] ||
		[command isEqualToString: @"move"] ||
		[command isEqualToString: @"copy"])
	{
		Assert(recursive == nil);
		[document svnCommand: command options: [action objectForKey: @"options"] info: action itemPaths: itemPaths];
	}
	else if ([command isEqualToString: @"remove"])
	{
		Assert(recursive == nil);
		[document svnCommand: command options: [NSArray arrayWithObject: @"--force"] info: nil itemPaths: itemPaths];
	}
	else if ([command isEqualToString: @"commit"])
	{
		Assert(recursive == nil);
		[self startCommitMessage: @"selected"];
	}
	else // Add, Update, Revert, Resolved, Lock, Unlock
	{
		[document svnCommand: command options: (recursive ? [NSArray arrayWithObject: recursive] : nil)
					    info: nil itemPaths: itemPaths];
	}

	[action release];
}


//----------------------------------------------------------------------------------------

- (void) commandPanelDidEnd: (NSAlert*) alert
		 returnCode:         (int)      returnCode
		 contextInfo:        (void*)    contextInfo
{
	const id action = (id) contextInfo;

	if (returnCode == NSOKButton)
	{
		NSArray* buttons = [alert buttons];
		if ([buttons count] >= 3)	// Has Recursive checkbox
		{
			[action setObject: NSBool([[buttons objectAtIndex: 2] state] == NSOnState)
					   forKey: @"recursive"];
		}

		[self performSelector: @selector(svnCommand:) withObject: action afterDelay: 0.1];
	}
	else
	{
		[svnFilesAC discardEditing]; // cancel editing, useful to revert a row being renamed (see TableViewDelegate).
		[action release];
	}
}


//----------------------------------------------------------------------------------------
// Commit Sheet
//----------------------------------------------------------------------------------------

- (void) startCommitMessage: (NSString*) selectedOrAll
{
	[NSApp beginSheet:     commitPanel
		   modalForWindow: [self window]
		   modalDelegate:  self
		   didEndSelector: @selector(commitPanelDidEnd:returnCode:contextInfo:)
		   contextInfo:    [selectedOrAll retain]];
}


- (void) commitPanelDidEnd: (NSWindow*) sheet
		 returnCode:        (int)       returnCode
		 contextInfo:       (void*)     contextInfo
{
	if (returnCode == NSOKButton)
	{
		suppressAutoRefresh = TRUE;
		[document svnCommit: [commitPanelText string]];
	}

	[(id) contextInfo release];
	[sheet close];
}


- (IBAction) commitPanelValidate: (id) sender
{
	#pragma unused(sender)
	[NSApp endSheet: commitPanel returnCode: NSOKButton];
}


- (IBAction) commitPanelCancel: (id) sender
{
	#pragma unused(sender)
	[NSApp endSheet: commitPanel returnCode: NSCancelButton];
}


//----------------------------------------------------------------------------------------
// Error Sheet
//----------------------------------------------------------------------------------------

- (void) doSvnError: (NSString*) errorString
{
	Assert(errorString != nil);
	if (![window isVisible])
		return;

	svnStatusPending = NO;
	[self stopProgressIndicator];

	if (!isDisplayingErrorSheet)
	{
		static UTCTime prevTime = 0;
		NSWindow* const sheet = [window attachedSheet];
		// Allow user to prevent repeated alerts.
		BOOL canClose = !sheet &&
						((CFAbsoluteTimeGetCurrent() - prevTime) < 5.0 ||
						 containsLocalizedString(errorString, @" is not a working copy") ||
						 containsLocalizedString(errorString, @" client is too old"));
		isDisplayingErrorSheet = YES;

		NSBeep();
		NSAlert* alert = [NSAlert alertWithMessageText: @"Error"
										 defaultButton: @"OK"
									   alternateButton: canClose ? @"Close Working Copy" : nil
										   otherButton: nil
							 informativeTextWithFormat: @"%@", errorString];

		[alert setAlertStyle: NSCriticalAlertStyle];
		[alert	beginSheetModalForWindow: sheet ? sheet : window
						   modalDelegate: self
						  didEndSelector: @selector(svnErrorSheetEnded:returnCode:contextInfo:)
							 contextInfo: &prevTime];
	}
}


//----------------------------------------------------------------------------------------

- (void) svnError: (NSString*) errorString
{
	[self performSelector: @selector(doSvnError:) withObject: errorString afterDelay: 0.1];
}


//----------------------------------------------------------------------------------------

- (void) svnErrorSheetEnded: (NSAlert*) alert
		 returnCode:         (int)      returnCode
		 contextInfo:        (void*)    contextInfo
{
	#pragma unused(alert)
	isDisplayingErrorSheet = NO;
	*(UTCTime*) contextInfo = CFAbsoluteTimeGetCurrent();
	if (returnCode == NSAlertAlternateReturn)
	{
		suppressAutoRefresh = TRUE;
		[window performSelector: @selector(performClose:) withObject: self afterDelay: 0];
	}
}


//----------------------------------------------------------------------------------------

- (void) startProgressIndicator
{
	svnStatusPending = YES;
	[progressIndicator startAnimation: self];
}


- (void) stopProgressIndicator
{
	[progressIndicator stopAnimation: self];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Convenience Accessors
//----------------------------------------------------------------------------------------

- (MyWorkingCopy*) document
{
	return document;
}


- (NSWindow*) window
{
	return window;
}


- (NSArray*) selectedFiles
{
	return [svnFilesAC selectedObjects];
}


- (NSArray*) selectedFilePaths
{
	return [[svnFilesAC selectedObjects] valueForKey: @"fullPath"];
}


//----------------------------------------------------------------------------------------
// Set fTreeExpanded to the list of expanded tree paths.

- (void) calcTreeExpanded
{
	[fTreeExpanded removeAllObjects];
	NSOutlineView* const tree = outliner;
	const int rowCount = [tree numberOfRows];
	for (int index = 0; index < rowCount; ++index)
	{
		id item = [tree itemAtRow: index];
		if ([tree isItemExpanded: item])
		{
			[fTreeExpanded addObject: [item path]];
		}
	}
	[self prefsChanged];
}


//----------------------------------------------------------------------------------------
// Select <treePath> in fTreeView or its deepest ancestor if it doesn't exist.

- (void) selectTreePath: (NSString*) treePath
{
	int selectedRow = 0;
	NSOutlineView* const tree = outliner;
	const int rowCount = [tree numberOfRows];
	while (selectedRow == 0 && [treePath length] > 0)
	{
		for (int index = 0; index < rowCount; ++index)
		{
			ConstString path = [[tree itemAtRow: index] path];
			if ([treePath isEqualToString: path])
			{
				selectedRow = index;
				break;
			}
		}
		if (selectedRow == 0)
			treePath = [treePath stringByDeletingLastPathComponent];
	}
	[tree selectRowIndexes: [NSIndexSet indexSetWithIndex: selectedRow] byExtendingSelection: NO];
	[tree scrollRowToVisible: selectedRow];
}


//----------------------------------------------------------------------------------------
// Have the Finder show the parent folder for the selected files.
// if no row in the list is selected then open the root directory of the project

- (void) revealInFinder: (id) sender
{
	#pragma unused(sender)
	NSWorkspace* const ws = [NSWorkspace sharedWorkspace];
	NSArray* const selectedFiles = [self selectedFilePaths];

	if ([selectedFiles count] <= 0)
	{
		[ws selectFile: [document workingCopyPath] inFileViewerRootedAtPath: nil];
	}
	else
	{
		for_each_obj(enumerator, file, selectedFiles)
		{
			[ws selectFile: file inFileViewerRootedAtPath: nil];
		}
	}
}

@end	// MyWorkingCopyController


//----------------------------------------------------------------------------------------
// End of MyWorkingCopyController.m
