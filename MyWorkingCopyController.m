//
// MyWorkingCopyController.m - Controller of the working copy browser
//
#import "MyWorkingCopyController.h"
#import "MyWorkingCopy.h"
#import "MyApp.h"
#import "MyFileMergeController.h"
#import "DrawerLogView.h"
#import "NSString+MyAdditions.h"
#import "ReviewCommit.h"
#import "SvnInterface.h"
#import "CommonUtils.h"
#import "ViewUtils.h"


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

typedef NSString* const ConstString;
static ConstString keyWCWidows    = @"wcWindows",
				   keyWidowFrame  = @"winFrame",
				   keyViewMode    = @"viewMode",
				   keyFilterMode  = @"filterMode",
				   keyShowToolbar = @"showToolbar";
static NSString* gInitName = nil;


//----------------------------------------------------------------------------------------
// Subversion 1.4.6 commands that support recursive flags
//			Add, Remove, Update, Revert, Resolved, Lock, Unlock, Copy, Move, Rename
// Default:  Y     -        Y      N         N      -      -      -      -      -
// Allow -R: N     -        N      Y         Y      -      -      -      -      -
// Allow -N: Y     -        Y      N         N      -      -      -      -      -


//----------------------------------------------------------------------------------------
// Add, Delete, Update, Revert, Resolved, Lock, Unlock, Commit, Review

static NSString* const gCommands[] = {
	@"add", @"remove", @"update", @"revert", @"resolved", @"lock", @"unlock", @"commit", @"review"
};

static NSString* const gVerbs[] = {
	@"add", @"remove", @"update", @"revert", @"resolve", @"lock", @"unlock", @"commit", @"review"
};

enum SvnCommand {
	cAdd = 0, cRemove, cUpdate, cRevert, cResolved	//, cLock, cUnlock, cCopy, cMove, cRename
};


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
#pragma mark	-
//----------------------------------------------------------------------------------------

@interface MyWorkingCopyController (Private)

	- (IBAction) commitPanelValidate: (id) sender;
	- (IBAction) commitPanelCancel:   (id) sender;
	- (IBAction) renamePanelValidate: (id) sender;
	- (IBAction) switchPanelValidate: (id) sender;

	- (void) resetStatusMessage;
	- (void) runAlertBeforePerformingAction: (NSDictionary*) command;
	- (void) startCommitMessage: (NSString*) selectedOrAll;
	- (void) renamePanelForCopy: (BOOL)      isCopy
			 destination:        (NSString*) destination;

	- (void) requestSvnUpdate:   (BOOL)      forSelection;
	- (void) updateSheetSetKind: (id)        updateKindView;
	- (void) updateSheetDidEnd:  (NSWindow*) sheet
			 returnCode:         (int)       returnCode
			 contextInfo:        (void*)     contextInfo;

	- (NSArray*) selectedFilePaths;

@end


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
	isDisplayingErrorSheet = NO;
	[self setStatusMessage: @""];

	[document   addObserver:self forKeyPath:@"flatMode"
				options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];

	[drawerLogView setDocument:document];
	[drawerLogView setUp];

	NSTableView* const tableView = tableResult;
	[[[tableView tableColumnWithIdentifier: @"path"] dataCell] setDrawsBackground: NO];

	[self setNextResponder: [tableView nextResponder]];
	[tableView setNextResponder: self];

	NSUserDefaults* const prefs = [NSUserDefaults standardUserDefaults];
	NSDictionary* wcWindows = [prefs dictionaryForKey: keyWCWidows];
	if (wcWindows != nil)
	{
		NSDictionary* settings = [wcWindows objectForKey: gInitName];
		if (settings != nil)
		{
			if (![[settings objectForKey: keyShowToolbar] boolValue])
				[[window toolbar] setVisible: NO];

			ConstString widowFrame = [settings objectForKey: keyWidowFrame];
			if (widowFrame != nil)
				[window setFrameFromString: widowFrame];
		}
	}

	[self adjustOutlineView];
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[savedSelection release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------
// Called after 'document' is setup

- (void) setup
{
	int viewMode   = kModeSmart;
	int filterMode = kFilterAll;

	NSUserDefaults* const prefs = [NSUserDefaults standardUserDefaults];
	NSDictionary* wcWindows = [prefs dictionaryForKey: keyWCWidows];
	if (wcWindows != nil)
	{
		ConstString nameKey = [document windowTitle];
		NSDictionary* settings = [wcWindows objectForKey: nameKey];
		if (settings != nil)
		{
			viewMode    = [[settings objectForKey: keyViewMode] intValue];
			filterMode  = [[settings objectForKey: keyFilterMode] intValue];
		//	searchStr   = [settings objectForKey: keySearchStr];
		}
	}

	[modeView setIntValue: viewMode];
	[self setCurrentMode: viewMode];
	if (viewMode == kModeSmart)		// Force refresh as mode is default & thus hasn't changed so won't auto-refresh
		[document svnRefresh];
	[filterView selectItemWithTag: filterMode];
	[document setFilterMode: filterMode];

	[window makeKeyAndOrderFront: self];
	[self savePrefs];

	[window setDelegate: self];		// for windowDidMove & windowDidResize messages
}


//----------------------------------------------------------------------------------------

- (void) windowDidBecomeKey: (NSNotification*) notification
{
	#pragma unused(notification)
	if (suppressAutoRefresh)
	{
		suppressAutoRefresh = false;
	}
	else if (!svnStatusPending && GetPreferenceBool(@"autoRefreshWC"))
	{
		[document svnRefresh];
	}
}


//----------------------------------------------------------------------------------------

- (void) windowDidMove: (NSNotification*) notification
{
	#pragma unused(notification)
	[self savePrefs];
}


//----------------------------------------------------------------------------------------

- (void) windowDidResize: (NSNotification*) notification
{
	#pragma unused(notification)
	[self savePrefs];
}


//----------------------------------------------------------------------------------------

- (BOOL) windowShouldClose: (id) sender
{
	const BOOL shouldClose = (*[document reviewCount] == 0);
	if (!shouldClose)
		NSBeep();
	return shouldClose;
}


//----------------------------------------------------------------------------------------

- (void) savePrefs
{
	NSUserDefaults* const prefs = [NSUserDefaults standardUserDefaults];

	BOOL showToolbar = [[window toolbar] isVisible];
	NSDictionary* settings = [NSDictionary dictionaryWithObjectsAndKeys:
								[window stringWithSavedFrame],                   keyWidowFrame,
								[NSNumber numberWithInt: [self currentMode]],    keyViewMode,
								[NSNumber numberWithInt: [document filterMode]], keyFilterMode,
								NSBool(showToolbar),                             keyShowToolbar,
								nil];

	ConstString nameKey = [document windowTitle];
	NSDictionary* wcWindows = [prefs dictionaryForKey: keyWCWidows];
	if (wcWindows == nil)
	{
		wcWindows = [NSDictionary dictionaryWithObject: settings forKey: nameKey];
	}
	else
	{
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary: wcWindows];
		[dict setObject: settings forKey: nameKey];
		wcWindows = dict;
	}

	[prefs setObject: wcWindows forKey: keyWCWidows];
//	[prefs synchronize];
}


//----------------------------------------------------------------------------------------

- (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	#pragma unused(object, change, context)
	if ( [keyPath isEqualToString:@"flatMode"] )
	{
		[self adjustOutlineView];
	}
}


//----------------------------------------------------------------------------------------

- (void) cleanup
{
	[document removeObserver: self forKeyPath: @"flatMode"];

	DrawerLogView* obj = drawerLogView;
	drawerLogView = nil;
	[obj unload];
}


//----------------------------------------------------------------------------------------

- (void) keyDown: (NSEvent*) theEvent
{
	NSString* const chars = [theEvent charactersIgnoringModifiers];
	const unichar ch = [chars characterAtIndex: 0];

	if (ch == '\r' || ch == 3)
		[self doubleClickInTableView: nil];
	else if (([theEvent modifierFlags] & NSControlKeyMask) != 0)	// ctrl+<letter> => command button
	{
		for_each(enumerator, cell, [[[window contentView] viewWithTag: vCmdButtons] cells])
		{
			NSString* const keys = [cell keyEquivalent];
			if (keys != nil && [keys length] == 1 && ch == ([keys characterAtIndex: 0] | 0x20))
			{
				[cell performClick: self];
				break;
			}
		}
	}
	else if (ch >= ' ')
	{
		NSTableView* const tableView = tableResult;
		NSArray* const dataArray = [svnFilesAC arrangedObjects];
		const int rows = [dataArray count];
		int i, selRow = [svnFilesAC selectionIndex];
		if (selRow == NSNotFound)
			selRow = rows - 1;
		const unichar ch0 = (ch >= 'a' && ch <= 'z') ? (ch - 32) : ch;
		for (i = 1; i <= rows; ++i)
		{
			int index = (selRow + i) % rows;
			id wc = [dataArray objectAtIndex: index];
			NSString* name = [wc objectForKey: @"displayPath"];
			if ([name length] && ([name characterAtIndex: 0] & ~0x20) == ch0)
			{
				[tableView selectRow: index byExtendingSelection: false];
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
		if (savedSelection != nil)
		{
			[savedSelection release];
			savedSelection = nil;
		}

		savedSelection = [[self selectedFilePaths] retain];
	}
//	NSLog(@"savedSelection=%@", savedSelection);
}


//----------------------------------------------------------------------------------------

- (void) restoreSelection
{
//	NSLog(@"restoreSelection=%@ tree='%@'", savedSelection, [document outlineSelectedPath]);
	if (savedSelection != nil)
	{
		NSArray* const wcFiles = [svnFilesAC arrangedObjects];
		NSMutableIndexSet* sel = [NSMutableIndexSet indexSet];

		NSEnumerator* it = [savedSelection objectEnumerator];
		NSString* fullPath;
		while (fullPath = [it nextObject])
		{
			NSEnumerator* wcIt = [wcFiles objectEnumerator];
			NSDictionary* dict;
			int index = 0;
			while (dict = [wcIt nextObject])
			{
				if ([fullPath isEqualToString: [dict objectForKey: @"fullPath"]])
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
	}
}


//----------------------------------------------------------------------------------------
#pragma mark -
#pragma mark IBActions
//----------------------------------------------------------------------------------------

- (IBAction) openAWorkingCopy: (id) sender
{
	#pragma unused(sender)
    NSOpenPanel* oPanel = [NSOpenPanel openPanel];

    [oPanel setAllowsMultipleSelection: NO];
    [oPanel setCanChooseDirectories: YES];
	[oPanel setCanChooseFiles: NO];

	[oPanel beginSheetForDirectory: NSHomeDirectory() file: nil types: nil
					modalForWindow: [self window]
					modalDelegate:  self
					didEndSelector: @selector(openPanelDidEnd:returnCode:contextInfo:)
					contextInfo:    NULL];
}


- (void) openPanelDidEnd: (NSOpenPanel*) sheet
		 returnCode:      (int)          returnCode
		 contextInfo:     (void*)        contextInfo
{
	#pragma unused(contextInfo)
	if (returnCode == NSOKButton)
	{
		NSString* pathToFile = [[[sheet filenames] objectAtIndex: 0] copy];

		[document setWorkingCopyPath: pathToFile];
		[document svnRefresh];
	}
}


- (IBAction) refresh: (id) sender
{
	#pragma unused(sender)
	if (!svnStatusPending)
		[document svnRefresh];
}


- (IBAction) toggleView: (id) sender
{
	#pragma unused(sender)
	//[[self document] setFlatMode:!([[self document] flatMode])];

//	[self adjustOutlineView];
}


//----------------------------------------------------------------------------------------

- (IBAction) performAction: (id) sender
{
	const unsigned int action = SelectedTag(sender);
	enum { kUpdate = 2, kReview = 8 };
	if (action == kReview)
	{
		[ReviewController performSelector: @selector(openForDocument:) withObject: document afterDelay: 0];
	}
	else if (action == kUpdate && AltOrShiftPressed())
	{
		[self requestSvnUpdate: TRUE];
	}
	else if (action < sizeof(gCommands) / sizeof(gCommands[0]))
	{
		[self performSelector: @selector(runAlertBeforePerformingAction:)
			  withObject: makeCommand(gCommands[action], gVerbs[action], nil)
			  afterDelay: 0];
	}
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
	NSArray* const selection = [svnFilesAC selectedObjects];
	if ([selection count] > 0)
	{
		OpenFiles([selection valueForKey: @"fullPath"]);
	}
}


- (void) adjustOutlineView
{
	[document setSvnFiles: nil];
	int tag;
	if ([document flatMode])
	{
		[self closeOutlineView];
		tag = vFlatTable;
	}
	else
	{
		[self openOutlineView];
		tag = vTreeTable;
	}
	[window makeFirstResponder: WGetView(window, tag)];
}


- (void) openOutlineView
{
	NSView* leftView = [[splitView subviews] objectAtIndex: 0];

	NSRect frame = [splitView frame];
	frame.origin.x = 0;
	frame.size.width = [[splitView superview] frame].size.width;
	[splitView setFrame: frame];

	frame = [leftView frame];
	frame.size.width = 200;
	[leftView setFrame: frame];
	[leftView setHidden: NO];

	[splitView adjustSubviews];
	[splitView setNeedsDisplay: YES];
}


- (void) closeOutlineView
{
	NSView* leftView = [[splitView subviews] objectAtIndex: 0];

	const GCoord kDivGap = [splitView dividerThickness];
	NSRect frame = [splitView frame];
	frame.origin.x = -kDivGap;
	frame.size.width = [[splitView superview] frame].size.width + kDivGap;
	[splitView setFrame: frame];

	frame = [leftView frame];
	frame.size.width = 0;
	[leftView setFrame: frame];
	[leftView setHidden: YES];

	[splitView adjustSubviews];
	[splitView setNeedsDisplay: YES];
}


- (void) fetchSvnStatus
{
	[self startProgressIndicator];

	[document fetchSvnStatus: AltOrShiftPressed()];
}


- (void) fetchSvnInfo
{
	[self startProgressIndicator];

	[document fetchSvnInfo];
}


//- (void) fetchSvnStatusReceiveDataFinished
//{
//	[self stopProgressIndicator];
//	[textResult setString:[[self document] resultString]];
//	
//	svnStatusPending = NO;
//}


//----------------------------------------------------------------------------------------

- (void) fetchSvnStatusVerboseReceiveDataFinished
{
	[self stopProgressIndicator];

//	NSOutlineView* const view = outliner;
	NSIndexSet* selectedRows = [outliner selectedRowIndexes];
	unsigned int index,
				 selectedRow = [selectedRows firstIndex],
				 rowCount    = [outliner numberOfRows];
	if (selectedRow == NSNotFound)
	{
		selectedRow = 0;
		selectedRows = [NSIndexSet indexSetWithIndex: 0];
	}

	// Save the paths of the selected item
	NSString* selPath = [[outliner itemAtRow: selectedRow] path];

	NSMutableArray* expanded = nil;
	if (outlineInited && selPath != nil)	// Save the paths of the expanded items
	{
		expanded = [NSMutableArray array];
		for (index = 0; index < rowCount; ++index)
		{
			id item = [outliner itemAtRow: index];
			if ([outliner isItemExpanded: item])
			{
				[expanded addObject: [item path]];
			}
		}
	}

	[outliner reloadData];

	if (!outlineInited)
	{
		if (![document flatMode])			// First time through - expand top level
		{									// If preference is set then expand children too
			outlineInited = YES;
			[outliner expandItem: [outliner itemAtRow: 0] expandChildren: GetPreferenceBool(@"expandWCTree")];
		}
	}
	else if (selPath != nil)				// Restore the expanded items
	{
		unsigned int xIndex = 0, xCount = [expanded count];
		id xPath = nil, item;
		for (index = 0; (item = [outliner itemAtRow: index]) != nil; ++index)
		{
			NSString* path = [item path];
			if (xPath == nil && xIndex < xCount)
				xPath = [expanded objectAtIndex: xIndex++];
			if (xPath != nil && [xPath isEqualToString: path])
			{
				[outliner expandItem: item];
				xPath = nil;
			}
											// Restore the selected item
			if (selPath != nil && [selPath isEqualToString: path])
			{
				selectedRows = [NSIndexSet indexSetWithIndex: index];
				selPath = nil;
			}
		}
	}

	[outliner selectRowIndexes: selectedRows byExtendingSelection: NO];
	if ([selectedRows count])
		[outliner scrollRowToVisible: [selectedRows firstIndex]];

	svnStatusPending = NO;
}


//----------------------------------------------------------------------------------------
// Filter mode

- (void) setFilterMode: (int) mode
{
	[document setFilterMode: mode];
	[self savePrefs];
}


- (IBAction)changeFilter:(id)sender
{
	int tag = [[sender selectedItem] tag];																		

	[self setFilterMode: tag];
}


//----------------------------------------------------------------------------------------

- (IBAction) openRepository: (id) sender
{
	#pragma unused(sender)
	[[NSApp delegate] openRepository: [document repositoryUrl] user: [document user] pass: [document pass]];
}


- (IBAction) toggleSidebar: (id) sender
{
	#pragma unused(sender)
	[sidebar toggle:sender];
}


//----------------------------------------------------------------------------------------
// View mode

- (IBAction) changeMode: (id) sender
{
//	NSLog(@"changeMode: %@ tag=%d", sender, [sender tag]);
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
//	NSLog(@"setCurrentMode: %d", mode);
	if ([self currentMode] != mode)
	{
		[self saveSelection];
		switch (mode)
		{
			case kModeTree:
				if ([document flatMode])
					[document setFlatMode: false];
				break;

			case kModeFlat:
				if ([document smartMode])
					[document setSmartMode: false];
				else if (![document flatMode])
					[document setFlatMode: true];
				break;

			case kModeSmart:
				if (![document smartMode])
					[document setSmartMode: true];
				break;
		}
		[self savePrefs];
	}
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
#pragma mark -
#pragma mark Split View delegate
//----------------------------------------------------------------------------------------

static const GCoord kMinFilesHeight    = 96,
					kMinTreeWidth      = 140,
					kMaxTreeWidthFract = 0.5;


//----------------------------------------------------------------------------------------

- (BOOL) splitView:          (NSSplitView*) sender
		 canCollapseSubview: (NSView*)      subview
{
	#pragma unused(sender)

#if 0
	NSView* leftView = [[splitView subviews] objectAtIndex: 0];

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
	#pragma unused(sender)

	return proposedMax * kMaxTreeWidthFract;	// max tree width = proposedMax * kMaxTreeWidthFract
}


//----------------------------------------------------------------------------------------

- (GCoord) splitView:              (NSSplitView*) sender
		   constrainMinCoordinate: (GCoord)       proposedMin
		   ofSubviewAt:            (int)          offset
{
	#pragma unused(sender)

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
	NSString* msg;
	if (forSelection)
	{
		NSArray* const selObjs = [svnFilesAC selectedObjects];
		const int count = [selObjs count];
		msg = (count == 1) ? [NSString stringWithFormat: @"Update item %C%@%C to:",
									0x201C, [[selObjs objectAtIndex: 0] objectForKey: @"displayPath"], 0x201D]
						   : [NSString stringWithFormat: @"Update %d items to:", count];
	}
	else
		msg = @"Update entire working copy to:";
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
	if (AltOrShiftPressed())
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


- (void) updateWorkingCopyPanelDidEnd: (NSAlert*) alert
		 returnCode:                   (int)      returnCode
		 contextInfo:                  (void*)    contextInfo
{
	#pragma unused(alert, contextInfo)
	if ( returnCode == 0 ) return;

	[document performSelector: @selector(svnUpdate) withObject: nil afterDelay: 0.1];
}


//----------------------------------------------------------------------------------------
#pragma mark	svn diff

- (void) fileHistoryOpenSheetForItem: (id) item
{
	// close the sheet if it is already open
	if ([window attachedSheet])
		[NSApp endSheet: [window attachedSheet]];

	[MyFileMergeController runDiffSheet: document path: [item objectForKey: @"fullPath"]
						   sourceItem: item];
}


- (void) svnDiff: (id) sender
{
	#pragma unused(sender)
	if (AltOrShiftPressed())
	{
		NSDictionary* selection;
		if (selection = [self selectedItemOrNil])
		{
			[self fileHistoryOpenSheetForItem: selection];
		}
		else
		{
			[self svnError: @"Please select exactly one item."];
		}
	}
	else
	{
		[document diffItems: [self selectedFilePaths]];
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

- (void) renamePanelForCopy: (BOOL)      isCopy
		 destination:        (NSString*) destination
{
	NSMutableDictionary* action = makeCommandDict(isCopy ? @"copy" : @"move", destination);
	[action setObject: [self selectedFilePaths] forKey: @"itemPaths"];

	NSDictionary* selection;
	if (selection = [self selectedItemOrNil])
	{
		suppressAutoRefresh = true;		// Otherwise selection gets reset before it's used
		[[[renamePanel contentView] viewWithTag: 100]
				setStringValue: isCopy ? @"Copy and Rename" : @"Move and Rename"];
		[renamePanelTextField setStringValue: [[selection valueForKey: @"path"] lastPathComponent]];
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
		[self runAlertBeforePerformingAction: action];
	}

	[action release];
}


- (IBAction) renamePanelValidate: (id) sender
{
	[NSApp endSheet: renamePanel returnCode: [sender tag]];
}


//----------------------------------------------------------------------------------------
// called from MyDragSupportWindow
#pragma mark	svn switch

- (void) requestSwitchToRepositoryPath: (NSDictionary*) repositoryPathObj
{
//	NSLog(@"%@", repositoryPathObj);
	NSString* path = [repositoryPathObj valueForKeyPath: @"url.absoluteString"];
	NSString* revision = [repositoryPathObj valueForKey: @"revision"];

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
	NSMutableDictionary* action = contextInfo;

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

- (void) runAlertBeforePerformingAction: (NSDictionary*) command
{
	NSString* cmd = [command objectForKey: @"command"];
	if ([cmd isEqualToString: @"commit"])
	{
		[self startCommitMessage: @"selected"];
	}
	else
	{
		NSString* message = [NSString stringWithFormat: @"Are you sure you want to %@ the selected items?",
														[command objectForKey: @"verb"]];
		NSAlert* alert = [NSAlert alertWithMessageText: message
										 defaultButton: @"OK"
									   alternateButton: @"Cancel"
										   otherButton: nil
							 informativeTextWithFormat: @""];

		// Add recursive checkbox if supported by command:
		// TO_DO: (possibly) check for folder
		bool isDefaultRecursive = supportsNonRecursiveFlag(cmd);
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
	NSString* const command = [action objectForKey: @"command"];
	NSArray* itemPaths = [action objectForKey: @"itemPaths"];
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
	id action = contextInfo;

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
#if 1
		[document svnCommit: [commitPanelText string]];
#else
		[document performSelector: @selector(svnCommit:)
				  withObject:      [commitPanelText string]
				  afterDelay:      0.1];
#endif
	}
	[(id) contextInfo release];	
	[sheet close];
}


//----------------------------------------------------------------------------------------
// Error Sheet

- (void) doSvnError: (NSString*) errorString
{
	// close any existing sheet that is not an svnError sheet (workaround a "double sheet" effect
	// that can occur because svn info and svn status are launched simultaneously)
	if ( !isDisplayingErrorSheet && [window attachedSheet] != nil )
		[NSApp endSheet: [window attachedSheet]];

 	[self stopProgressIndicator];
	
	if (!isDisplayingErrorSheet)
	{
		isDisplayingErrorSheet = YES;

		NSAlert* alert = [NSAlert alertWithMessageText: @"Error"
										 defaultButton: @"OK"
									   alternateButton: nil
										   otherButton: nil
							 informativeTextWithFormat: @"%@", errorString];

		[alert setAlertStyle: NSCriticalAlertStyle];

		[alert	beginSheetModalForWindow: window
						   modalDelegate: self
						  didEndSelector: @selector(svnErrorSheetEnded:returnCode:contextInfo:)
						     contextInfo: nil];
	}
}


- (void) svnError: (NSString*) errorString
{
	[self performSelector: @selector(doSvnError:) withObject: errorString afterDelay: 0.1];
}


- (void) svnErrorSheetEnded: (NSAlert*) alert
		 returnCode:         (int)      returnCode
		 contextInfo:        (void*)    contextInfo
{
	#pragma unused(alert, returnCode, contextInfo)
	isDisplayingErrorSheet = NO;
}


//----------------------------------------------------------------------------------------

- (IBAction) commitPanelValidate: (id) sender
{
	#pragma unused(sender)
	[NSApp endSheet:commitPanel returnCode:1];
}


- (IBAction) commitPanelCancel: (id) sender
{
	#pragma unused(sender)
	[NSApp endSheet:commitPanel returnCode:0];
}


- (void) startProgressIndicator
{
	svnStatusPending = YES;
	[progressIndicator startAnimation:self];
}


- (void) stopProgressIndicator
{
	[progressIndicator stopAnimation:self];
}


#if 0
- (NSDictionary*) performActionMenusDict
{
	if ( performActionMenusDict == nil )
	{
		performActionMenusDict = [[NSDictionary dictionaryWithContentsOfFile:
						[[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Resources/"]
								stringByAppendingPathComponent:@"performMenus.plist"]] retain];
	}

	return performActionMenusDict;
}
#endif


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


- (NSArray*) selectedFilePaths
{
	return [[svnFilesAC selectedObjects] valueForKey: @"fullPath"];
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
		for_each(enumerator, file, selectedFiles) 
		{
			[ws selectFile: file inFileViewerRootedAtPath: nil];
		}
	}
}

@end

