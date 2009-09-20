//
// MyFileMergeController.m - Controller for UI sheet for Subversion diff using selection(s) from log
//

#import "MyFileMergeController.h"
#import "MySvn.h"
#import "MySvnLogView.h"
#import "MyWorkingCopy.h"
#import "NSString+MyAdditions.h"
#import "RepoItem.h"
#import "Tasks.h"
#import "CommonUtils.h"


@implementation MyFileMergeController

//----------------------------------------------------------------------------------------
// Private:

- (void) setupWithOptions: (NSInvocation*) options
		 sourceItem:       (NSDictionary*) sourceItem
		 descPath:         (id)            descPath
		 descRev:          (NSString*)     descRev
{
    if (svnOptionsInvocation != options)
	{
		[svnOptionsInvocation release];
		svnOptionsInvocation = [options retain];
	}
	[objectController setValue: sourceItem forKeyPath: @"content.sourceItem"];
	[objectController setValue: PathWithRevision(descPath, descRev) forKeyPath: @"content.desc"];
	[svnLogView setRevision: descRev];
	[svnLogView setSvnOptionsInvocation: options];
	[svnLogView fetchSvn];
}


//----------------------------------------------------------------------------------------

- (void) setupUrl:   (NSURL*)        url
		 options:    (NSInvocation*) options
		 sourceItem: (RepoItem*)     sourceItem
{
//	dprintf("(url=<%@> sourceItem=%@) revision=%@ modRev=%@", url, sourceItem, [sourceItem revision], [sourceItem modRev]);
	[svnLogView setPath: [url absoluteString]];
	[objectController setValue: url forKeyPath: @"content.itemUrl"];
	[self setupWithOptions: options
		  sourceItem:       [NSDictionary dictionaryWithObject: url forKey: @"url"]		// content.sourceItem.url
		  descPath:         url
		  descRev:          [sourceItem revision]];
}


//----------------------------------------------------------------------------------------
// Private:

- (id) initDiffSheet: (MyWorkingCopy*) workingCopy
	   path:          (NSString*)      path
	   sourceItem:    (NSDictionary*)  sourceItem
{
	if (self = [super init])
	{
		svnOperation = kSvnDiff;	// kSvnWCDiff?
		if ([NSBundle loadNibNamed: @"svnFileMerge" owner: self])
		{
			[svnLogView setPath: path];
			[objectController setValue: path forKeyPath: @"content.itemPath"];
			[self setupWithOptions: [workingCopy svnOptionsInvocation] sourceItem: sourceItem
				  descPath: path descRev: [sourceItem objectForKey: @"revisionCurrent"]];

			[NSApp beginSheet:     svnSheet
				   modalForWindow: [workingCopy windowForSheet]
				   modalDelegate:  [workingCopy controller]
				   didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:)
				   contextInfo:    self];
		}	
		else
			dprintf("loadNibNamed FAILED");
	}

	return self;
}


//----------------------------------------------------------------------------------------

+ (void) runDiffSheet: (MyWorkingCopy*) workingCopy
		 path:         (NSString*)      path
		 sourceItem:   (NSDictionary*)  sourceItem
{
	[[self alloc] initDiffSheet: workingCopy path: path sourceItem: sourceItem];
}


//----------------------------------------------------------------------------------------

- (void) finished
{
	[svnLogView unload];
	
	// the owner has to release its top level nib objects 
	[svnSheet release];
	[objectController release];

	[self release];
}


//----------------------------------------------------------------------------------------

- (IBAction) validate: (id) sender
{
	id callback = [objectController valueForKeyPath: @"content.sourceItem.callback"];
	if (callback)	// see singleFileInspector
	{
	//	[callback closeCallback];
	}

	[NSApp endSheet: svnSheet returnCode: [sender tag]];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	FileMerge
//----------------------------------------------------------------------------------------
// Private:

- (void) comparePath:   (NSString*) path
		 toWorkingCopy: (BOOL)      toWorkingCopy
{
	// Block the button's action if the list is currently unpopulated.
	if ([svnLogView selectedRevision] == nil || [svnLogView currentRevision] == nil)
	{
		NSBeep();
		return;
	}
	id revOption = [NSString stringWithFormat:
						toWorkingCopy ? @"-r%@"			// Compare selected to working copy
									  : @"-r%@:%@",		// Compare selected to marked
						[svnLogView selectedRevision], [svnLogView currentRevision]];

	[MySvn      diffItems: [NSArray arrayWithObject: path]
		   generalOptions: svnOptionsInvocation
				  options: [NSArray arrayWithObject: revOption]
				 callback: MakeCallbackInvocation(self, @selector(fileMergeCallback:))
			 callbackInfo: nil
				 taskInfo: [NSDictionary dictionaryWithObject: @"svnDiff" forKey: @"documentName"]];
}


//----------------------------------------------------------------------------------------
// used by fileHistoryOpenSheetForItem from MyWorkingCopyController

- (IBAction) compare: (id) sender
{
	[self comparePath:   [objectController valueForKeyPath: @"content.sourceItem.fullPath"]
		  toWorkingCopy: ([sender tag] == 0)];
}


//----------------------------------------------------------------------------------------
// used by svnFileMerge from MyRepository

- (IBAction) compareUrl: (id) sender
{
	#pragma unused(sender)
	NSString* path = [[objectController valueForKeyPath: @"content.sourceItem.url"] absoluteString];
	[self comparePath: PathPegRevision(path, [svnLogView revision]) toWorkingCopy: NO];
}


//----------------------------------------------------------------------------------------

- (void) fileMergeCallback: (id) taskObj
{
	if (!isCompleted(taskObj))
	{
		NSString* errorString = stdErr(taskObj);
		if (errorString)
			[svnLogView svnError: taskObj];
	}
}


@end

