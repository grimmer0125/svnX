//
// MySvnOperationController.m - Manages the repository copy, move, delete, mkdir & diff UIs
//

#import "MySvnOperationController.h"
#import "MySvnRepositoryBrowserView.h"
#import "NSString+MyAdditions.h"
#import "RepoItem.h"


@implementation MySvnOperationController

//----------------------------------------------------------------------------------------
// Private:

- (void) setupUrl:   (NSURL*)        url
		 options:    (NSInvocation*) options
		 sourceItem: (RepoItem*)     sourceItem
{
	if (svnOptionsInvocation != options)
	{
		[svnOptionsInvocation release];
		svnOptionsInvocation = [options retain];
	}

	if ([targetBrowser respondsToSelector: @selector(setSvnOptionsInvocation:)])
		[targetBrowser setSvnOptionsInvocation: options];

	[targetBrowser setUrl: url];
	[objectController setValue: url forKeyPath: @"content.itemUrl"];
	if (sourceItem != nil)
	{
		id revision = (svnOperation == kSvnMove) ? @"HEAD" : [sourceItem revision];
		id dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										[sourceItem name],		@"name",
										[sourceItem author],	@"author",
										[sourceItem path],		@"path",
										revision,				@"revision",
										nil];
		[objectController setValue: dict forKeyPath: @"content.sourceItem"];
		[targetName setStringValue: [sourceItem name]];
	}

	if (svnOperation == kSvnDelete)
	{
		[targetBrowser setupForSubBrowser: NO allowsLeaves: YES allowsMultipleSelection: YES];
	}
	else
	{
		Assert(svnOperation != kSvnDiff);

		[targetBrowser setupForSubBrowser: YES allowsLeaves: NO allowsMultipleSelection: NO];
	}
}


//----------------------------------------------------------------------------------------

- (void) setupUrl: (NSURL*)        url
		 options:  (NSInvocation*) options
		 revision: (NSString*)     revision
{
	#pragma unused(url, options, revision)
	dprintf("UNIMPLEMENTED: (url=<%@> revision=%@)", url, revision);
}


//----------------------------------------------------------------------------------------
// Private:

- (id) initSheet:  (SvnOperation)  operation
	   repository: (MyRepository*) repository
	   url:        (NSURL*)        url
	   sourceItem: (RepoItem*)     sourceItem
	   revision:   (NSString*)     revision
{
	Assert(operation >= kSvnCopy && operation <= kSvnDiff);

	if (self = [super init])
	{
	//	dprintf("0x%X operation=%d", self, operation);
		static NSString* const nibNames[] = {
			// kSvnCopy, kSvnMove, kSvnDelete, kSvnMkdir, kSvnDiff
			@"svnCopy", @"svnCopy", @"svnDelete", @"svnMkdir", @"svnFileMergeFromRepository"
		};
		NSString* nibName = nibNames[operation];

		svnOperation = operation;
		if ([NSBundle loadNibNamed: nibName owner: self])
		{
			// TO_DO: retain sourceItem for use by copy or move
			if (targetBrowser != nil)
				[targetBrowser setRepository: repository];
			if (revision)
				[self setupUrl: url options: [repository svnOptionsInvocation]
					  revision: revision];
			else
				[self setupUrl: url options: [repository svnOptionsInvocation]
					  sourceItem: sourceItem];

			[NSApp beginSheet:     svnSheet
				   modalForWindow: [repository windowForSheet]
				   modalDelegate:  repository
				   didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:)
				   contextInfo:    self];
		}
		else
			dprintf("loadNibNamed '%@' FAILED", nibName);
	}

	return self;
}


//----------------------------------------------------------------------------------------

+ (void) runSheet:   (SvnOperation)  operation
		 repository: (MyRepository*) repository
		 url:        (NSURL*)        url
		 sourceItem: (RepoItem*)     sourceItem
{
	[[self alloc] initSheet: operation repository: repository url: url
				   sourceItem: sourceItem revision: nil];
}


//----------------------------------------------------------------------------------------

+ (void) runSheet:   (SvnOperation)  operation
		 repository: (MyRepository*) repository
		 url:        (NSURL*)        url
		 revision:   (NSString*)     revision
{
	[[self alloc] initSheet: operation repository: repository url: url
				 sourceItem: nil revision: revision];
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
//	dprintf("0x%X operation=%d", self, svnOperation);
	[svnOptionsInvocation release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (void) finished
{
	[targetBrowser setRevision: nil];
	[targetBrowser reset];
	[targetBrowser unload]; // targetBrowser was loaded from a nib (see "unload" comments).

	// the owner has to release its top level nib objects
	[svnSheet release];
	[objectController release];
	[arrayController  release];

	[self release];
}


//----------------------------------------------------------------------------------------

- (RepoItem*) selectedItem
{
	return [[targetBrowser selectedItems] objectAtIndex: 0];
}


//----------------------------------------------------------------------------------------
// Transform the text into something, vaguely, legal for a file name

- (NSString*) getTargetName
{
	NSMutableString* text = [NSMutableString stringWithString: [targetName stringValue]];
	[text replaceOccurrencesOfString: @"/" withString: @":"
		  options: NSLiteralSearch range: NSMakeRange(0, [text length])];

	NSRange range;
	int len = [text length];
	if (len >= 128)
	{
		range.location = 128;
		range.length   = len - 128;
		[text deleteCharactersInRange: range];
	}
	NSCharacterSet* chSet = [NSCharacterSet controlCharacterSet];
	while ((range = [text rangeOfCharacterFromSet: chSet]).location != NSNotFound)
		[text replaceCharactersInRange: range withString: @"-"];

	chSet = [NSCharacterSet characterSetWithCharactersInString: @"[];?"];	// reserved: ";?@&=+$,"
	while ((range = [text rangeOfCharacterFromSet: chSet]).location != NSNotFound)
		[text replaceCharactersInRange: range withString: @"-"];

	return text;
}


//----------------------------------------------------------------------------------------

- (NSString*) getTargetPath
{
	return [[[self selectedItem] path]
				stringByAppendingPathComponent: [self getTargetName]];
}


- (NSURL*) getTargetUrl
{
	return [NSURL URLWithString: EscapeURL([self getTargetName])
				  relativeToURL: [[self selectedItem] url]];
}


- (NSString*) getCommitMessage
{
	return MessageString([commitMessage string]);
}


- (NSArray*) getTargets
{
	return [arrayController arrangedObjects];
}


//----------------------------------------------------------------------------------------
// For svn mkdir

- (IBAction) addDirectory: (id) sender
{
	#pragma unused(sender)
	if ([[self getTargetName] length] == 0)
	{
		[svnSheet makeFirstResponder: targetName];
		NSBeep();
	}
	else
	{
		id dir = [NSDictionary dictionaryWithObjectsAndKeys: [self getTargetPath], @"path",
															 [self getTargetUrl],  @"url",
															 nil];
		if (![[arrayController arrangedObjects] containsObject: dir])
			[arrayController addObject: dir];
		else
			NSBeep();
	//	dprintf("dir=%@", dir);
	}
}


//----------------------------------------------------------------------------------------
// For svn delete

- (IBAction) addItems: (id) sender
{
	#pragma unused(sender)
	NSArray* const theItems = [arrayController arrangedObjects];
	NSMutableArray* selectedItems = [NSMutableArray array];

	for_each_obj(en, it, [targetBrowser selectedItems])
	{
		if (![theItems containsObject: it])
			[selectedItems addObject: it];
	}

	if ([selectedItems count])
		[arrayController addObjects: selectedItems];
	else
		NSBeep();
}


//----------------------------------------------------------------------------------------

- (IBAction) validate: (id) sender
{
	if ([sender tag] != 0 && [[commitMessage string] length] == 0)
	{
		[svnSheet makeFirstResponder: commitMessage];
		NSBeep();
	}
	else
	{
		[NSApp endSheet: svnSheet returnCode: [sender tag]];
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Error sheet

- (void) svnError: (NSString*) errorString
{
	NSAlert* alert = [NSAlert alertWithMessageText: @"Error"
									 defaultButton: @"OK"
								   alternateButton: nil
									   otherButton: nil
						 informativeTextWithFormat: @"%@", errorString];

	[alert setAlertStyle: NSCriticalAlertStyle];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Accessors

- (SvnOperation) operation
{
	return svnOperation;
}


@end

