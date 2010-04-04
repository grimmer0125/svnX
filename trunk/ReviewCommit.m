//----------------------------------------------------------------------------------------
//	ReviewCommit.m - Review and edit a commit
//
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <WebKit/WebKit.h>
#import "ReviewCommit.h"
#import "MySvnLogParser.h"
#import "MyWorkingCopy.h"
#import "MyWorkingCopyController.h"
#import "MySvn.h"
#import "SvnDateTransformer.h"
#import "TableViewDelegate.h"
#import "Tasks.h"
#import "IconTextCell.h"
#import "CommonUtils.h"
#import "IconUtils.h"
#import "ViewUtils.h"
#import "NSString+MyAdditions.h"


//----------------------------------------------------------------------------------------

@interface ReviewFile : NSObject
{
	NSDictionary*	fItem;
	IconRef			fIcon;
	BOOL			fCommit;
}

- (id) init: (NSDictionary*) item commit: (BOOL) commit;
- (NSDictionary*) item;
- (BOOL) commit;
- (void) setCommit: (BOOL) commit;
- (NSString*) name;
- (NSString*) fullPath;

@end	// ReviewFile


//----------------------------------------------------------------------------------------

@interface ReviewController (Private)

- (id) initWithDocument: (MyWorkingCopy*) document;
- (void) buildFileList: (BOOL) commitDefault;
- (void) taskCompleted: (Task*) task arg: (id) tmpHtmlPath;
- (void) displaySelectedFileDiff;
- (void) setIsBusy: (BOOL) isBusy;
- (BOOL) canCommit;
- (void) setCommitFileCount: (int) count;

@end	// ReviewController


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

static int
compareNames (id obj1, id obj2, void* context)
{
	#pragma unused(context)
	return [[obj1 name] compare: [obj2 name] options: kSortOptions];
}


//----------------------------------------------------------------------------------------

static int
compareTemplateNames (id obj1, id obj2, void* context)
{
	#pragma unused(context)
	return [[obj1 objectForKey: @"name"] compare: [obj2 objectForKey: @"name"]
										 options: kSortOptions];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation ReviewFile


//----------------------------------------------------------------------------------------

- (id) init:   (NSDictionary*) item
	   commit: (BOOL) commit
{
	if (self = [super init])
	{
		fItem   = [item retain];
		fCommit = commit;
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[fItem release];
	if (fIcon)
		WarnIf(ReleaseIconRef(fIcon));
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (NSDictionary*) item
{
	return fItem;
}


//----------------------------------------------------------------------------------------

- (BOOL) commit
{
	return fCommit;
}


//----------------------------------------------------------------------------------------

- (void) setCommit: (BOOL) commit
{
	fCommit = commit;
}


//----------------------------------------------------------------------------------------

- (NSString*) name
{
	return [fItem objectForKey: @"path"];
}


//----------------------------------------------------------------------------------------

- (NSString*) fullPath
{
	return [fItem objectForKey: @"fullPath"];
}


//----------------------------------------------------------------------------------------

- (IconRef) icon
{
	if (fIcon == NULL)
	{
		Boolean isDir = false;
		ConstString fullPath = [self fullPath];
		fIcon = GetFileOrTypeIcon([fullPath fileSystemRepresentation], fullPath, &isDir);
	}
	return fIcon;
}


@end	// ReviewFile


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation ReviewController

static ConstString kPrefTemplates = @"msgTemplates",
				   kPrefKeySplits = @"reviewSplits";

static ConstString kPrefDefaultTab   = @"diffDefaultTab",
				   kPrefContextLines = @"diffContextLines",
				   kPrefShowFunction = @"diffShowFunction",
				   kPrefShowChars    = @"diffShowCharacters";

enum {
	kPaneMessage	=	0,
	kPaneRecent		=	1,
	kPaneTemplates	=	2,

	cmdDefaultTab		=	1000,
	cmdShowFunction		=	2000,
	cmdShowChars		=	2001,

	vDiffSettingsPopUp	=	510,	// NSPopUpButton

	kMaxTempHTMLFiles	=	8
};


//----------------------------------------------------------------------------------------

+ (void) openForDocument: (MyWorkingCopy*) document
{
	ReviewController* obj = [[ReviewController alloc] initWithDocument: document];
	[obj release];
}


//----------------------------------------------------------------------------------------

- (id) initWithDocument: (MyWorkingCopy*) document
{
	if (self = [super init])
	{
	//	[[[document windowControllers] objectAtIndex: 0] setShouldCloseDocument: NO];
	//	[[document controller] retain];
		[document registerSubController: self];
		fDocument = [document retain];
		fTemplates = [[NSMutableArray array] retain];
		if ([NSBundle loadNibNamed: @"ReviewCommit" owner: self])
		{
			[fWindow retain];
			[self buildFileList: YES];
		}
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
//	NSLog(@"dealloc ReviewController");
//	[[[fDocument windowControllers] objectAtIndex: 0] setShouldCloseDocument: YES];
//	[[fDocument controller] release];
	[fTemplates release];
	[fDocument release];
	[fFileDiffTask release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (NSView*) unbindSuperView: (NSView*) view
{
	while (view)	// Find first super-view that is an NSView
	{
		view = [view superview];
		if ([view isMemberOfClass: [NSView class]])
		{
			[view unbind: NSHiddenBinding];
			break;
		}
	}
	return view;
}


//----------------------------------------------------------------------------------------

- (void) unload
{
	enum {
		vPaneSelector	=	500,	// NSSegmentedControl
		vCommitButton	=	501,
		vCommitInfo		=	502,
		iBusyIndicator	=	0		// NSProgressIndicator
	};

	[Tasks cancelCallbacksOnTarget: self];
	NSWindow* const window = fWindow;
	fWindow = NULL;
	NSView* const root = [window contentView];
	[fFilesAC unbind: NSContentArrayBinding];
	[[root viewWithTag: vPaneSelector] unbind: NSSelectedIndexBinding];
	[self unbindSuperView: fRecentView];
	[self unbindSuperView: fTemplatesView];
	NSView* view = [root viewWithTag: vCommitButton];
	[view unbind: NSEnabledBinding];
	[view unbind: NSEnabledBinding];
	view = [root viewWithTag: vCommitInfo];
	[view unbind: NSDisplayPatternValueBinding];
	[view unbind: NSDisplayPatternValueBinding];
	view = [[[view superview] subviews] objectAtIndex: iBusyIndicator];
	[view unbind: NSAnimateBinding];

	[window release];
}


//----------------------------------------------------------------------------------------
// Private:

- (NSInvocation*) makeCallback: (SEL) selector
{
	return MakeCallbackInvocation([self retain], selector);
}


//----------------------------------------------------------------------------------------
// Private:

- (void) buildFileList: (BOOL) commitDefault
{
	NSArray* const svnFiles = [fDocument svnFiles];
	NSArray* const oldFiles = [fFilesAC content];
	NSMutableArray* const newFiles = [NSMutableArray array];

	int commitFileCount = 0;
	for_each_obj(oEnum, item, svnFiles)
	{
		if ([[item objectForKey: @"committable"] boolValue])
		{
			BOOL commit = commitDefault;
			NSString* const name = [item objectForKey: @"path"];
			for_each_obj(oEnum2, item2, oldFiles)
				if ([name isEqualToString: [item2 name]])
				{
					commit = [item2 commit];
					break;
				}
			[newFiles addObject: [[ReviewFile alloc] init: item commit: commit]];
			if (commit)
				++commitFileCount;
		}
	}

	fFiles = newFiles;
	[newFiles sortUsingFunction: compareNames context: NULL];
	[fFilesAC setContent: newFiles];
	[self setCommitFileCount: commitFileCount];
	if (!commitDefault)
		[self displaySelectedFileDiff];
}


//----------------------------------------------------------------------------------------

- (void) buildFileList
{
	[self buildFileList: NO];
}


//----------------------------------------------------------------------------------------
// If there is a selected item then return it else return nil.
// Private:

- (ReviewFile*) selectedItemOrNil
{
	int rowIndex = [fFilesView selectedRow];
	return (rowIndex >= 0) ? [fFiles objectAtIndex: rowIndex] : nil;
}


//----------------------------------------------------------------------------------------
// TO_DO: Move this into document & have it notify all review windows
// Build list of recent commit messages
// Private:

- (void) buildRecentList: (BOOL) full
{
	[MySvn		log: [[fDocument repositoryUrl] absoluteString]
	 generalOptions: [fDocument svnOptionsInvocation]
			options: [NSArray arrayWithObjects: @"--limit", (full ? @"50" : @"1"), @"--xml", nil]
		   callback: [self makeCallback: @selector(buildRecentMessages:)]
	   callbackInfo: nil
		   taskInfo: nil];
}


//----------------------------------------------------------------------------------------

- (void) buildRecentMessages: (id) taskObj
{
	if ([fWindow isVisible] && isCompleted(taskObj) && stdErr(taskObj) == nil)
	{
		NSData* data = stdOutData(taskObj);
		if (data != nil && [data length] != 0)
		{
			NSArray* const array = [MySvnLogParser parseData: data];
			const int count = [array count];
			NSDateFormatter* const formatter = [SvnDateTransformer formatter];
			NSDate* const date = [[NSDate alloc] init];
			for_each_obj(oEnum, item, array)
			{
				NSString* str = [item objectForKey: @"date"];
				str = [NSString stringWithFormat: @"%@ %@ +0000",
										[str substringToIndex: 10],
										[str substringWithRange: NSMakeRange(11, 8)]];
				str = [formatter stringFromDate: [date initWithString: str]];
				id obj = [NSDictionary dictionaryWithObject:
								[NSString stringWithFormat: @"r%@\t%@\t%@\n%@",
															[item objectForKey: @"revision"],
															[item objectForKey: @"author"],
															str,
															[item objectForKey: @"msg"]]
								forKey: @"log"];
				if (count == 1)
				{
					// If the last commit was to an svn:external then this log entry
					// may be a duplicate.  If it is then don't add it.
					NSArray* recentArray = [fRecentAC arrangedObjects];
					if ([recentArray count] == 0 || ![[recentArray objectAtIndex: 0] isEqual: obj])
						[fRecentAC insertObject: obj atArrangedObjectIndex: 0];
				}
				else
					[fRecentAC addObject: obj];
			}
			[date release];
		}
	}
	[self release];
}


//----------------------------------------------------------------------------------------
// Build list of template commit messages
// Private:

- (void) buildTemplatesList
{
	for_each_obj(en, it, GetPreference(kPrefTemplates))
		[fTemplates addObject: [[it mutableCopy] autorelease]];
	[fTemplates sortUsingFunction: compareTemplateNames context: NULL];
	[fTemplatesAC setContent: fTemplates];
}


//----------------------------------------------------------------------------------------

- (IBAction) addTemplate: (id) sender
{
	#pragma unused(sender)
	id obj = [NSMutableDictionary dictionaryWithObjectsAndKeys: @"untitled", @"name",
																@"template body", @"body", nil];
	[fTemplatesAC addObject: obj];
	[fTemplatesAC setSelectionIndex: [fTemplates count] - 1];
}


//----------------------------------------------------------------------------------------

- (void) saveTemplates
{
	SetPreference(kPrefTemplates, fTemplates);
}


//----------------------------------------------------------------------------------------

- (void) setAllFilesCommit: (BOOL) commit
{
	for_each_obj(oEnum, item, fFiles)
	{
		[item setCommit: commit];
	}
	[self setCommitFileCount: (commit ? [fFiles count] : 0)];
	[fFilesAC rearrangeObjects];
}


//----------------------------------------------------------------------------------------

- (IBAction) checkAllFiles: (id) sender
{
	#pragma unused(sender)
	[self setAllFilesCommit: YES];
}


//----------------------------------------------------------------------------------------

- (IBAction) checkNoFiles: (id) sender
{
	#pragma unused(sender)
	[self setAllFilesCommit: NO];
}


//----------------------------------------------------------------------------------------

- (IBAction) refreshFiles: (id) sender
{
	#pragma unused(sender)
	[fDocument svnRefresh];
}


//----------------------------------------------------------------------------------------

- (IBAction) openSelectedFile: (id) sender
{
	#pragma unused(sender)
	ReviewFile* item = [self selectedItemOrNil];
	if (item)
	{
		OpenFiles([item fullPath]);
	}
}


//----------------------------------------------------------------------------------------

- (void) svnErrorAlertDidEnd: (NSAlert*) alert
		 returnCode:          (int)      returnCode
		 contextInfo:         (void*)    contextInfo
{
	#pragma unused(alert, returnCode, contextInfo)
}


//----------------------------------------------------------------------------------------

- (BOOL) svnError: (id) taskObj
{
	NSString* errMsg = nil;
	const BOOL isErr = (!isCompleted(taskObj) && (errMsg = stdErr(taskObj)) != nil);
	if (isErr)
	{
		if ([fWindow attachedSheet])
			[NSApp endSheet: [fWindow attachedSheet]];

		[[fDocument controller] stopProgressIndicator];

		if ([fWindow isVisible])
		{
			NSAlert* alert = [NSAlert alertWithMessageText: @"Error"
											 defaultButton: @"OK"
										   alternateButton: nil
											   otherButton: nil
								 informativeTextWithFormat: @"%@", errMsg];

			[alert setAlertStyle: NSCriticalAlertStyle];

			[alert beginSheetModalForWindow: fWindow
							  modalDelegate: self
							 didEndSelector: @selector(svnErrorAlertDidEnd:returnCode:contextInfo:)
								contextInfo: NULL];
		}
	}

	return isErr;
}


//----------------------------------------------------------------------------------------

- (void) svnDiff_Completed: (id) taskObj
{
	if ([fWindow isVisible])
	{
		[self svnError: taskObj];
	}
	[self release];
}


//----------------------------------------------------------------------------------------

- (IBAction) diffSelectedFile: (id) sender
{
	#pragma unused(sender)
	ReviewFile* item = [self selectedItemOrNil];
	if (item)
		[fDocument diffItems: [NSArray arrayWithObject: [item fullPath]]
					callback: [self makeCallback: @selector(svnDiff_Completed:)]
				callbackInfo: nil];
}


//----------------------------------------------------------------------------------------

- (void) svnCommit_Completed: (id) taskObj
{
//	dprintf("0x%X taskObj=%@", self, taskObj);
	if ([fWindow isVisible])
	{
		[self setIsBusy: NO];
		if (![self svnError: taskObj])
		{
			[self refreshFiles: nil];
			[self buildRecentList: NO];
		}
	}
	[self release];
}


//----------------------------------------------------------------------------------------

- (void) doCommitFiles
{
	Assert([self canCommit]);
	NSMutableArray* commitFiles = [NSMutableArray array];
	for_each_obj(oEnum, item, fFiles)
	{
		if ([item commit])
			[commitFiles addObject: [item item]];
	}

	[self setIsBusy: YES];
	[fDocument svnCommit: commitFiles
				 message: [fMessageView string]
				callback: [self makeCallback: @selector(svnCommit_Completed:)]
			callbackInfo: nil];
}


//----------------------------------------------------------------------------------------

- (void) commitFiles: (NSAlert*) alert
		 returnCode:  (int)      returnCode
		 contextInfo: (void*)    context
{
	#pragma unused(alert, context)
	if (returnCode == NSOKButton)
	{
		fSuppressAutoRefresh = TRUE;
		[self doCommitFiles];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) commitFiles: (id) sender
{
	#pragma unused(sender)
	if (AltOrShiftPressed())
		[self doCommitFiles];
	else
	{
		NSAlert* alert =
			[NSAlert alertWithMessageText: [NSString stringWithFormat:
												@"Commit changes to the repository\nfor %u of %u items.",
												fCommitFileCount, [fFiles count]]
							defaultButton: nil
						  alternateButton: @"Cancel"
							  otherButton: nil
				informativeTextWithFormat: @""];

		[alert setAlertStyle: NSInformationalAlertStyle];
		[alert beginSheetModalForWindow: fWindow
						  modalDelegate: self
						 didEndSelector: @selector(commitFiles:returnCode:contextInfo:)
							contextInfo: nil];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) toggleSelectedFile: (id) sender
{
	#pragma unused(sender)
	ReviewFile* item = [self selectedItemOrNil];
	if (item)
	{
		const BOOL commit = ![item commit];
		[item setCommit: commit];
		NSRect r = [fFilesView rectOfRow: [fFilesView selectedRow]];
		[fFilesView setNeedsDisplayInRect: r];
		[self setCommitFileCount: fCommitFileCount + (commit ? 1 : -1)];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) revealSelectedFile: (id) sender
{
	#pragma unused(sender)
	ReviewFile* item = [self selectedItemOrNil];
	if (item)
	{
		[[NSWorkspace sharedWorkspace] selectFile: [item fullPath] inFileViewerRootedAtPath: nil];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) doubleClick: (id) sender
{
	[self openSelectedFile: sender];
}


//----------------------------------------------------------------------------------------
// The 'review.sh >> <tmpHtmlPath>' task has completed

- (void) taskCompleted: (Task*) task object: (id) tmpHtmlPath
{
	if (task != fFileDiffTask && fFileDiffTask != nil)
		return;
	if (task == fFileDiffTask)
	{
		fFileDiffTask = nil;
		[task release];
	}
	if ([fWindow isVisible])
		[[fDiffView mainFrame] loadRequest: [NSURLRequest requestWithURL:
												[NSURL fileURLWithPath: tmpHtmlPath]]];
}


//----------------------------------------------------------------------------------------
// Private:

- (NSString*) tmpHtmlPath
{
	static unsigned int fileIndex = 0;
	return [NSString stringWithFormat: @"/tmp/svnx-review-%X%c.html",
											self, 'z' - (++fileIndex % kMaxTempHTMLFiles)];
}


//----------------------------------------------------------------------------------------

- (void) displayFileDiff: (ReviewFile*) item
{
//	dprintf("item=%@ '%@'", item, [item name]);
	if (item)
	{
		Task* task = fFileDiffTask;
		if (task)	// Kill old task
		{
			fFileDiffTask = nil;
			[[task task] interrupt];
			[task release];
		}

	//	NSString* options = [NSString stringWithFormat: @"-r%@:1", fRevision];
		NSString* tmpHtmlPath = [self tmpHtmlPath];

		// review.sh <svn-tool> <options> <ctx-lines> <show-func> <show-chars> <dest-html> <paths...>
		NSArray* arguments = [NSArray arrayWithObjects:
			SvnCmdPath(),											// svn tool
			@"",													// options
			GetPreference(kPrefDefaultTab),							// default tab
			GetPreference(kPrefContextLines),						// context lines
			GetPreferenceBool(kPrefShowFunction) ? @"1" : @"",		// show function
			GetPreferenceBool(kPrefShowChars) ? @"1" : @"",			// show characters
			tmpHtmlPath,											// destination html file
			[item fullPath],										// path
			nil];

		task = [Task taskWithDelegate: self object: tmpHtmlPath];
		fFileDiffTask = [task retain];
		[task launch: ShellScriptPath(@"review") arguments: arguments];
	}
}


//----------------------------------------------------------------------------------------

- (void) displaySelectedFileDiff
{
	[self displayFileDiff: [self selectedItemOrNil]];
}


//----------------------------------------------------------------------------------------

- (void) alertUserShouldClose
{
	NSAlert* alert =
		[NSAlert alertWithMessageText: @"Close this window?"
						defaultButton: @"Close"
					  alternateButton: @"Cancel"
						  otherButton: nil
			informativeTextWithFormat: @"You have selected items &"
										" a message that has not been commited."];

	[alert setAlertStyle: NSWarningAlertStyle];
	[alert beginSheetModalForWindow: fWindow
					  modalDelegate: self
					 didEndSelector: @selector(shouldClose:returnCode:contextInfo:)
						contextInfo: nil];
	NSBeep();
}


//----------------------------------------------------------------------------------------

- (void) shouldClose: (NSAlert*) alert
		 returnCode:  (int)      returnCode
		 contextInfo: (void*)    context
{
	#pragma unused(alert, context)
	if (returnCode == NSOKButton)
	{
		fSuppressAutoRefresh = TRUE;
		[fWindow setDocumentEdited: FALSE];
		[fWindow performSelector: @selector(performClose:) withObject: self afterDelay: 0];
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

- (BOOL) isBusy
{
	return fIsBusy;
}


//----------------------------------------------------------------------------------------

- (void) setIsBusy: (BOOL) isBusy
{
	fIsBusy = isBusy;
}


//----------------------------------------------------------------------------------------

- (BOOL) canCommit
{
	return fCommitFileCount > 0 && [[fMessageView string] length] > 0;
}


//----------------------------------------------------------------------------------------
// Called by 'textDidChange' & 'setCommitFileCount'.
// Forces NIB to re-evaluate 'canCommit' and updates window 'dirty' flag.

- (void) setCanCommit: (id) ignored
{
	#pragma unused(ignored)
	[fWindow setDocumentEdited: [self canCommit]];
}


//----------------------------------------------------------------------------------------

- (int) commitFileCount
{
	return fCommitFileCount;
}


//----------------------------------------------------------------------------------------

- (void) setCommitFileCount: (int) count
{
	fCommitFileCount = count;
	[self setCanCommit: nil];
}


//----------------------------------------------------------------------------------------

- (IBAction) changeEditView: (id) sender
{
	#pragma unused(sender)
//	dprintf("%d", [sender selectedSegment]);
//	[self setEditPane: [sender selectedSegment]];
}


//----------------------------------------------------------------------------------------

- (BOOL) hideMessage	{ return fEditState != kPaneMessage; }

- (BOOL) hideRecent		{ return fEditState != kPaneRecent; }

- (BOOL) hideTemplates	{ return fEditState != kPaneTemplates; }


//----------------------------------------------------------------------------------------

- (void) setHideMessage:   (BOOL) state	{ _Pragma("unused(state)") }

- (void) setHideRecent:    (BOOL) state	{ _Pragma("unused(state)") }

- (void) setHideTemplates: (BOOL) state	{ _Pragma("unused(state)") }


//----------------------------------------------------------------------------------------

- (int) editPane
{
	return fEditState;
}


//----------------------------------------------------------------------------------------

- (void) setEditPane: (int) pane
{
	fEditState = pane;
	[self setHideMessage:   (pane != kPaneMessage)];
	[self setHideRecent:    (pane != kPaneRecent)];
	[self setHideTemplates: (pane != kPaneTemplates)];

	if (pane == kPaneMessage)
		[fWindow makeFirstResponder: fMessageView];
	else if (pane == kPaneRecent)
		[fWindow makeFirstResponder: fRecentView];
	else if (pane == kPaneTemplates)
		[fWindow makeFirstResponder: fTemplatesView];
}


//----------------------------------------------------------------------------------------

- (NSWindow*) window
{
	return fWindow;
}


//----------------------------------------------------------------------------------------

- (BOOL) isDocumentEdited
{
	return [fWindow isDocumentEdited];
}


//----------------------------------------------------------------------------------------

- (void) textDidChange: (NSNotification*) notification
{
	#pragma unused(notification)
	[self setCanCommit: nil];
}


//----------------------------------------------------------------------------------------

- (void) insertRecent: (id) sender
{
	#pragma unused(sender)
	int rowIndex = [fRecentView selectedRow];
	if (rowIndex >= 0)
	{
		NSString* str = [[[fRecentAC arrangedObjects] objectAtIndex: rowIndex] objectForKey: @"log"];
		NSRange range = [str rangeOfString: @"\n"];
		str = [str substringFromIndex: range.location + 1];

		[fMessageView insertText: str];
		[self setEditPane: kPaneMessage];
	}
	else
		NSBeep();
}


//----------------------------------------------------------------------------------------
// Calls a script with the args: svnBinDir, wcPath, 3, commit-file-names...

- (NSString*) insertTemplateScript: (NSString*) script
{
	const NSStringEncoding kEncoding = NSUTF8StringEncoding;
	NSMutableArray* args = [NSMutableArray arrayWithObjects:
								GetPreference(@"svnBinariesFolder"),
								[fDocument workingCopyPath],
								@"3",			// count of args before first file
								nil];

	for_each_obj(oEnum, it, fFiles)
	{
		if ([it commit])
			[args addObject: [it name]];
	}

//	dprintf("args=%@\nscript='%@'", args, script);

	NSString* result = @"[SCRIPT: Couldn't run]";
	static unsigned int uid = 0;
	NSString* const path = [NSString stringWithFormat: @"/tmp/svnx%u-script%u.sh", getpid(), ++uid];
	char cpath[64];
	if ([[script normalizeEOLs] writeToFile: path atomically: NO encoding: kEncoding error: nil] &&
		[path getCString: cpath maxLength: sizeof(cpath) encoding: kEncoding] &&
		chmod(cpath, S_IRWXU) == 0)
	{
		NSPipe* const pipe = [NSPipe pipe];
		Task* const task = [[Task task] retain];
		[task setStandardOutput: pipe];
		[task launch: path arguments: args];

		NSTask* const nsTask = [task task];
		NSFileHandle* const handle = [pipe fileHandleForReading];
		NSMutableData* const data = [NSMutableData dataWithLength: 0];
		const UTCTime endTime = CFAbsoluteTimeGetCurrent() + 30;		// Wait a max of 30 secs
		while ([nsTask isRunning] && CFAbsoluteTimeGetCurrent() < endTime)
		{
		//	[NSThread sleepForTimeInterval: 1.0 / 8];
			[data appendData: [handle availableData]];
		}

		if (![nsTask isRunning])
		{
			[data appendData: [handle readDataToEndOfFile]];
			result = [[NSString alloc] initWithData: data encoding: kEncoding];
		}
		else
		{
			[nsTask terminate];
			result = @"[SCRIPT: Timed-out]";
		}

		[task release];
		(void) unlink(cpath);
	}

	return result;
}


//----------------------------------------------------------------------------------------

- (void) insertTemplate: (id) sender
{
	#pragma unused(sender)
	int rowIndex = [fTemplatesView selectedRow];
	if (rowIndex >= 0)
	{
		NSRange range;
		NSMutableString* str = [[[fTemplates objectAtIndex: rowIndex]
													objectForKey: @"body"] mutableCopy];

		// <MACHINE>
		range = [str rangeOfString: @"<MACHINE>"];
		if (range.location != NSNotFound)
		{
			[str replaceCharactersInRange: range withString: (id) CSCopyMachineName()];
		}

		// <USER>
		range = [str rangeOfString: @"<USER>"];
		if (range.location != NSNotFound)
		{
			[str replaceCharactersInRange: range withString: (id) CSCopyUserName(TRUE)];
		}

		// <DATE>
		range = [str rangeOfString: @"<DATE>"];
		if (range.location != NSNotFound)
		{
			id tmpStr = [[SvnDateTransformer formatter] stringFromDate: [NSDate date]];
			[str replaceCharactersInRange: range withString: tmpStr];
		}

		// <FILES> or <FILES>...</FILES>
		range = [str rangeOfString: @"<FILES>"];
		if (range.location != NSNotFound)
		{
			id fileSep = @"\n";		// default separator
			NSRange range2 = [str rangeOfString: @"</FILES>"];
			if (range2.location != NSNotFound && range2.location > range.location)
			{
				unsigned int loc = range.location + range.length;
				fileSep = [str substringWithRange: NSMakeRange(loc, range2.location - loc)];
				range.length = range2.length + range2.location - range.location;
			}

			id tmpStr = [NSMutableString string];
			for_each_obj(oEnum, item, fFiles)
			{
				if ([item commit])
				{
					if ([tmpStr length] != 0)
						[tmpStr appendString: fileSep];
					[tmpStr appendString: [item name]];
				}
			}
			[str replaceCharactersInRange: range withString: tmpStr];
		}

		// <SCRIPT>...</SCRIPT>
		range = [str rangeOfString: @"<SCRIPT>"];
		if (range.location != NSNotFound)
		{
			NSRange range2 = [str rangeOfString: @"</SCRIPT>"];
			if (range2.location != NSNotFound && range2.location > range.location)
			{
				unsigned int loc = range.location + range.length;
				NSString* script = [str substringWithRange: NSMakeRange(loc, range2.location - loc)];
				range.length = range2.length + range2.location - range.location;
				[str replaceCharactersInRange: range withString: [self insertTemplateScript: script]];
			}
		}

		[fMessageView insertText: str];
		[str release];
		[self setEditPane: kPaneMessage];
	}
	else
		NSBeep();
}


//----------------------------------------------------------------------------------------

- (IBAction) setDefaultTab: (id) sender
{
	const int newValue = [sender tag],
			  oldValue = [GetPreference(kPrefDefaultTab) intValue] + cmdDefaultTab;
	if (newValue != oldValue)
	{
		SetPreference(kPrefDefaultTab,
					  (newValue == cmdDefaultTab) ? @"0"
												  : ((newValue == cmdDefaultTab + 1) ? @"1" : @"2"));
		[self displaySelectedFileDiff];
		ChangeMenuCheck([sender menu], newValue, oldValue);
	}
}


//----------------------------------------------------------------------------------------
// Show Function & Show Characters

- (IBAction) setOption: (id) sender
{
	ConstString prefId = ([sender tag] == cmdShowChars) ? kPrefShowChars : kPrefShowFunction;
	const BOOL value = !GetPreferenceBool(prefId);
	SetPreferenceBool(prefId, value);
	[self displaySelectedFileDiff];
	[sender setState: value];
}


//----------------------------------------------------------------------------------------

- (IBAction) setContextLines: (id) sender
{
	const int newValue = [sender tag],
			  oldValue = [GetPreference(kPrefContextLines) intValue];
	if (newValue != oldValue)
	{
		SetPreference(kPrefContextLines, [sender title]);
		[self displaySelectedFileDiff];
		ChangeMenuCheck([sender menu], newValue, oldValue);
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Window delegate
//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
	NSWindow* const window = fWindow;

	// Insert after window in responder chain
	[self setNextResponder: [window nextResponder]];
	[window setNextResponder: self];

	[fFilesView setDoubleAction: @selector(doubleClick:)];
	[fFilesView setTarget: self];
	[fFilesView setDraggingSourceOperationMask: NSDragOperationCopy forLocal: NO];

	[window setTitle: [NSString stringWithFormat: [window title], [fDocument windowTitle]]];

	[fMessageView setDelegate: self];

	loadSplitViews(window, kPrefKeySplits, self);

	[fRecentView setDoubleAction: @selector(insertRecent:)];
	[fRecentView setTarget: self];
	[self buildRecentList: YES];

	[fTemplatesView setDoubleAction: @selector(insertTemplate:)];
	[fTemplatesView setTarget: self];
	[self buildTemplatesList];

	[self setEditPane: kPaneMessage];
	[window makeKeyAndOrderFront: self];
	[window setDelegate: self];	// After makeKeyAndOrderFront to prevent [fDocument svnRefresh]

	// Init check marks of diff prefs pop-up menu
	NSMenu* const menu = [WGetView(window, vDiffSettingsPopUp) menu];
	ChangeMenuCheck(menu, cmdDefaultTab + [GetPreference(kPrefDefaultTab) intValue], 0);
	if (GetPreferenceBool(kPrefShowFunction))
		ChangeMenuCheck(menu, cmdShowFunction, 0);
	if (GetPreferenceBool(kPrefShowChars))
		ChangeMenuCheck(menu, cmdShowChars, 0);
	ChangeMenuCheck(menu, [GetPreference(kPrefContextLines) intValue], 0);
}


//----------------------------------------------------------------------------------------

- (void) windowDidBecomeKey: (NSNotification*) notification
{
	#pragma unused(notification)
//	dprintf("%@", self);
	if (fSuppressAutoRefresh)
	{
		fSuppressAutoRefresh = FALSE;
	}
	else if (GetPreferenceBool(@"autoRefreshWC"))
	{
		[self refreshFiles: nil];
	}
}


//----------------------------------------------------------------------------------------

- (void) windowDidResignKey: (NSNotification*) notification
{
	#pragma unused(notification)
//	dprintf("refs=%d", [self retainCount]);
	saveSplitViews(fWindow, kPrefKeySplits);
	[self saveTemplates];
}


//----------------------------------------------------------------------------------------

- (BOOL) windowShouldClose: (id) sender
{
	#pragma unused(sender)
	BOOL askUser = [self isDocumentEdited];
	if (askUser)
		[self performSelector: @selector(alertUserShouldClose) withObject: nil afterDelay: 0];
	return !askUser;
}


//----------------------------------------------------------------------------------------

- (void) windowWillClose: (NSNotification*) notification
{
	#pragma unused(notification)
	[fDocument unregisterSubController: self];

	saveSplitViews(fWindow, kPrefKeySplits);
	[self saveTemplates];
	[fWindow setDelegate: nil];		// prevents windowDidResignKey message
	[self unload];

	// Delete temp HTML files
	for (int i = 0; i < kMaxTempHTMLFiles; ++i)
	{
		ConstCStr cpath = [[self tmpHtmlPath] fileSystemRepresentation];
		if (cpath)
			(void) unlink(cpath);
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Split Views delegate
//----------------------------------------------------------------------------------------

enum {
	kMinLeftWidth		= 200,
	kMinRightWidth		= 260,
	kMinTopHeight		= 160,
	kMinBottomHeight	= 160
};


//----------------------------------------------------------------------------------------

- (GCoord) splitView:              (NSSplitView*) sender
		   constrainMinCoordinate: (GCoord)       proposedMin
		   ofSubviewAt:            (int)          offset
{
	#pragma unused(offset, proposedMin)
	return [sender isVertical] ? kMinLeftWidth		// left min
							   : kMinTopHeight;		// top min
}


//----------------------------------------------------------------------------------------

- (GCoord) splitView:              (NSSplitView*) sender
		   constrainMaxCoordinate: (GCoord)       proposedMax
		   ofSubviewAt:            (int)          offset
{
	#pragma unused(offset)
	return [sender isVertical] ? proposedMax - kMinRightWidth		// left max
							   : proposedMax - kMinBottomHeight;	// top max
}


//----------------------------------------------------------------------------------------

- (void) splitView:                 (NSSplitView*) sender
		 resizeSubviewsWithOldSize: (NSSize)       oldSize
{
	resizeSplitView(sender, oldSize, kMinLeftWidth, kMinTopHeight);
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Table View delegate
//----------------------------------------------------------------------------------------

- (void) tableViewSelectionDidChange: (NSNotification*) notification
{
	#pragma unused(notification)
	[self displaySelectedFileDiff];
}


//----------------------------------------------------------------------------------------

- (void) tableView:       (NSTableView*)   aTableView
		 willDisplayCell: (id)             aCell
		 forTableColumn:  (NSTableColumn*) aTableColumn
		 row:             (int)            rowIndex
{
	#pragma unused(aTableView)

	if ([[aTableColumn identifier] isEqualToString: @"file"])
	{
		ReviewFile* item = [fFiles objectAtIndex: rowIndex];
		[aCell setIconRef: [item icon]];
		[aCell setTitle: [[item item] objectForKey: @"path"]];
	}
}


//----------------------------------------------------------------------------------------

- (BOOL) tableView:            (NSTableView*)  aTableView
		 writeRowsWithIndexes: (NSIndexSet*)   rowIndexes
		 toPasteboard:         (NSPasteboard*) pboard
{
	#pragma unused(aTableView)
	ReviewFile* item = [fFiles objectAtIndex: [rowIndexes firstIndex]];
	NSArray* filePaths = [NSArray arrayWithObject: [item fullPath]];

	[pboard declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] owner: nil];
	[pboard setPropertyList: filePaths forType: NSFilenamesPboardType];

	return YES;
}


//----------------------------------------------------------------------------------------

- (NSString*) tableView:      (NSTableView*)   aTableView
			  toolTipForCell: (NSCell*)        aCell
			  rect:           (NSRectPointer)  rect
			  tableColumn:    (NSTableColumn*) aTableColumn
			  row:            (int)            rowIndex
			  mouseLocation:  (NSPoint)        mouseLocation
{
	#pragma unused(aTableView, aCell, rect, mouseLocation)
	ReviewFile* item = [fFiles objectAtIndex: rowIndex];
	NSString* colID = [aTableColumn identifier];

	if ([colID isEqualToString: @"commit"])
	{
		return [item commit] ? @"Commit changes to this item."
							 : UTF_8_16("Don\xE2\x80\x99t commit changes to this item.",
										"Don\u2019t commit changes to this item.");
	}
	else if ([colID isEqualToString: @"file"])
	{
		return HelpTagForWCItem([item item]);
	}

	return @"";
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Table View dataSource
//----------------------------------------------------------------------------------------
// The tableView is driven by the bindings, except for the checkbox column.

- (id) tableView:                 (NSTableView*)   aTableView
	   objectValueForTableColumn: (NSTableColumn*) aTableColumn
	   row:                       (int)            rowIndex
{
	#pragma unused(aTableView, aTableColumn)
//	dprintf("col=%@ row=%d", [aTableColumn identifier], rowIndex);

	if ([[aTableColumn identifier] isEqualToString: @"commit"])
	{
		return NSBool([[fFiles objectAtIndex: rowIndex] commit]);
	}
//	else
//		dprintf("col=%@ row=%d", [aTableColumn identifier], rowIndex);

	return nil;
}


//----------------------------------------------------------------------------------------

- (void) tableView:      (NSTableView*)   aTableView
		 setObjectValue: (id)             anObject
		 forTableColumn: (NSTableColumn*) aTableColumn
		 row:            (int)            rowIndex
{
	#pragma unused(aTableView, aTableColumn)
//	dprintf("%@ col=%@ row=%d", anObject, [aTableColumn identifier], rowIndex);

	if ([[aTableColumn identifier] isEqualToString: @"commit"])		// should be always the case
	{
		const BOOL commit = [anObject boolValue];
		ReviewFile* item = [fFiles objectAtIndex: rowIndex];
		[item setCommit: commit];
		[self setCommitFileCount: fCommitFileCount + (commit ? 1 : -1)];
	}
}


//----------------------------------------------------------------------------------------

- (int) numberOfRowsInTableView: (NSTableView*) aTableView
{
	#pragma unused(aTableView)
	return [fFiles count];
}


@end	// ReviewController

//----------------------------------------------------------------------------------------
// End of ReviewCommit.m
