//
// RepositoriesController.m - Manage Repositories list window
//

#import "RepositoriesController.h"
#import "MyRepository.h"
#import "NSString+MyAdditions.h"
#import "CommonUtils.h"


static NSString* const kDocType = @"repository";
static /*const*/ EditListPrefKeys kPrefKeys =
	{ @"repositories", @"repEditShown", @"repPanelFrame"/*, NSURLPboardType*/ };


//----------------------------------------------------------------------------------------

@implementation RepositoriesController

- (id) init
{
	kPrefKeys.dragType = NSURLPboardType;
	if (self = [super init: &kPrefKeys])
	{
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (id) newObject: (NSPasteboard*) pboard
{
	id obj = nil;
	NSURL* url = nil;
	NSString* str = [pboard stringForType: @"public.url"];	// <= *.webloc file
	if (str != nil && (url = [NSURL URLWithString: str]) != nil)
	{
		// Name of file without extension
		str = [[[[NSURL URLFromPasteboard: pboard] path]
					lastPathComponent] stringByDeletingPathExtension];
	}
	if (url == nil)
		url = [NSURL URLFromPasteboard: pboard];
	if (url)
	{
		if (str == nil)
			str = [[url path] lastPathComponent];
		obj = [fAC newObject];
		[obj setValue: [url absoluteString] forKey: @"url"];
		[obj setValue: str forKey: @"name"];
	}
	return obj;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

- (IBAction) newItem: (id) sender
{
	#pragma unused(sender)
	[fAC addObject:
		[NSMutableDictionary dictionaryWithObjectsAndKeys: @"My Repository",	@"name",
														   @"svn://",			@"url",
														   @"",					@"user",
														   @"",					@"pass",
														   nil]];
	[super newItem: self];
}


//----------------------------------------------------------------------------------------

- (BOOL) showExtantWindow: (NSString*) name
		 url:              (NSString*) urlString
{
	NSURL* const url = StringToURL(urlString, YES);

	for_each_obj(en, doc, [[NSDocumentController sharedDocumentController] documents])
	{
		if ([[doc fileType] isEqualToString: kDocType] &&
			[[doc windowTitle] isEqualToString: name] &&
			[[doc url] isEqual: url])
		{
			[doc showWindows];
			return TRUE;
		}
	}

	return FALSE;
}


//----------------------------------------------------------------------------------------

- (void) showRepositoryBrowser: (NSDictionary*) repo
		 alwaysOpenNew:         (BOOL)          alwaysOpenNew
{
	Assert(repo != nil);
	NSString* const name = [repo objectForKey: @"name"];
	NSString* const url  = [repo objectForKey: @"url"];

	if (alwaysOpenNew || ![self showExtantWindow: name url: url])
	{
		[self openRepositoryBrowser: url title: name
							   user: [repo objectForKey: @"user"]
							   pass: [repo objectForKey: @"pass"]];
	}
}


//----------------------------------------------------------------------------------------

- (void) onDoubleClick: (id) sender
{
	#pragma unused(sender)
	NSArray* selectedObjects = [fAC selectedObjects];
	NSDictionary* selection;
	if ([selectedObjects count] != 0 && (selection = [selectedObjects objectAtIndex: 0]) != nil)
	{
		// If no option-key then look for & try to activate extant Repository window.
		[self showRepositoryBrowser: selection alwaysOpenNew: AltOrShiftPressed()];
	}
}


//----------------------------------------------------------------------------------------

- (void) openRepositoryBrowser: (NSString*) url
		 title:                 (NSString*) title
		 user:                  (NSString*) user
		 pass:                  (NSString*) pass
{
	const id docController = [NSDocumentController sharedDocumentController];

	MyRepository* newDoc = [docController makeUntitledDocumentOfType: kDocType];
	[newDoc setupTitle: title username: user password: pass url: StringToURL(url, YES)];

	[docController addDocument: newDoc];

	[newDoc makeWindowControllers];
	[newDoc showWindows];
}


//----------------------------------------------------------------------------------------
// Invoked from AppleScript.

- (void) openRepository: (NSString*) url
{
	// Find among the open repositories one that has a matching url
	for_each_obj(en1, it, [[NSDocumentController sharedDocumentController] documents])
	{
		if ([[it fileType] isEqualToString: kDocType] &&
			[url rangeOfString: [[it rootURL] absoluteString]
					   options: NSLiteralSearch | NSAnchoredSearch].location == 0)
		{
			[it showWindows];
			return;
		}
	}

	// Find among the known repositories one that has a matching url
	for_each_obj(en2, it, [fAC arrangedObjects])
	{
		if ([url rangeOfString: [it objectForKey: @"url"]
					   options: NSLiteralSearch | NSAnchoredSearch].location == 0)
		{
			[self showRepositoryBrowser: it alwaysOpenNew: NO];
			return;
		}
	}

	[self openRepositoryBrowser: url title: [UnEscapeURL(url) lastPathComponent] user: @"" pass: @""];
}


//----------------------------------------------------------------------------------------

- (IBAction) openPath: (id) sender
{
	#pragma unused(sender)
	NSString* selectionPath = NSHomeDirectory();
	NSOpenPanel* const oPanel = [NSOpenPanel openPanel];
	[oPanel setAllowsMultipleSelection: NO];
	[oPanel setCanChooseDirectories:    YES];
	[oPanel setCanChooseFiles:          NO];

	[oPanel beginSheetForDirectory: selectionPath file: nil types: nil modalForWindow: fWindow
					 modalDelegate: self
					didEndSelector: @selector(openPathDidEnd:returnCode:contextInfo:)
					   contextInfo: nil];
}


//----------------------------------------------------------------------------------------

- (void) openPathDidEnd: (NSOpenPanel*) sheet
		 returnCode:     (int)          returnCode
		 contextInfo:    (void*)        contextInfo
{
	#pragma unused(contextInfo)
	if (returnCode == NSOKButton)
	{
		NSString* pathToFile = [[sheet filenames] objectAtIndex: 0];
		[fAC setValue:   [NSString stringWithFormat: @"file://%@", pathToFile]
			 forKeyPath: @"selection.url"];
		[self savePreferences];
	}
}


@end

//----------------------------------------------------------------------------------------
// End of RepositoriesController.m
