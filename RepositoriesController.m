#import "RepositoriesController.h"
#import "MyDragSupportArrayController.h"
#import "MyRepository.h"
#import "NSString+MyAdditions.h"
#include "CommonUtils.h"


#define preferences [NSUserDefaults standardUserDefaults]


//----------------------------------------------------------------------------------------


static inline BOOL
IsURLChar (unichar ch)
{
	// Based on table in http://www.opensource.apple.com/darwinsource/10.5.6/CF-476.17/CFURL.c
	if (ch >= 33 && ch <= 126)
		if (ch != '"' && ch != '%' && ch != '<' && ch != '>' &&
						(ch < '[' || ch > '^') && ch != '`' && (ch < '{' || ch == '~'))
			return TRUE;
	return FALSE;
}


//----------------------------------------------------------------------------------------

static inline BOOL
IsHexChar (unichar ch)
{
	return (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f');
}


//----------------------------------------------------------------------------------------

static NSURL*
StringToURL (NSString* urlString)
{
	int length = [urlString length];
	if ([urlString characterAtIndex: length - 1] != '/')
		urlString = [urlString stringByAppendingString: @"/"];

	// Escape urlString iff it isn't already escaped
	for (int i = 0; i < length; ++i)
	{
		unichar ch = [urlString characterAtIndex: i];
		if (!IsURLChar(ch) &&
			(ch != '%' || i >= length - 2 || !IsHexChar([urlString characterAtIndex: i + 1]) ||
											 !IsHexChar([urlString characterAtIndex: i + 2])))
		{
			urlString = [urlString stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
			break;
		}
	}

	return [NSURL URLWithString: urlString];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation RepositoriesController

- (id) init
{
	self = [super init: @"rep"];
	if (self)
	{
		NSMutableArray* reposArray = [NSMutableArray array];

		NSData* dataPrefs = [preferences objectForKey: @"repositories"];
		if (dataPrefs != nil)
		{
			id repositoriesFromPrefs = [NSUnarchiver unarchiveObjectWithData: dataPrefs];

			if (repositoriesFromPrefs != nil)
			{
				[reposArray setArray: repositoriesFromPrefs];
			}
		}
		[self setRepositories: reposArray];
	}

	return self;
}


- (void) dealloc
{
//	[self removeObserver:self forKeyPath:@"repositories"];
	[self setRepositories: nil];

	[super dealloc];
}


- (void) savePreferences
{
	[self saveRepositoriesPrefs];
}


- (NSArray*) dataArray
{
	return repositories;
}


- (void) awakeFromNib
{
	[repositoriesAC bind:@"contentArray" toObject:self  withKeyPath:@"repositories" options:nil];

	[tableView registerForDraggedTypes:
				[NSArray arrayWithObjects:	@"COPIED_ROWS_TYPE", @"MOVED_ROWS_TYPE", NSURLPboardType, nil]];

	[super awakeFromNib];
}


- (IBAction) newRepositoryItem: (id) sender
{
	[repositoriesAC addObject:
		[NSMutableDictionary dictionaryWithObjectsAndKeys: @"My Repository", @"name",
														   @"svn://", @"url",
														   @"", @"user",
														   @"", @"pass",
														   nil]];
	[repositoriesAC setSelectionIndex:([[repositoriesAC arrangedObjects] count]-1)];
	
	[window makeFirstResponder:nameTextField];	
}


- (BOOL) showExtantWindow: (NSString*) name
		 url:              (NSString*) urlString
{
	NSURL* url = StringToURL(urlString);

	for_each(enumerator, obj, [[NSDocumentController sharedDocumentController] documents])
	{
		if ([[obj fileType] isEqualToString: @"repository"] &&
			[[obj windowTitle] isEqualToString: name] &&
			[[obj url] isEqual: url])
		{
			[[[[obj windowControllers] objectAtIndex: 0] window] makeKeyAndOrderFront: self];
			return TRUE;
		}
	}

	return FALSE;
}


- (void) onDoubleClick: (id) sender
{
	NSArray* selectedObjects = [repositoriesAC selectedObjects];
	NSDictionary* selection;
	if ([selectedObjects count] != 0 && (selection = [selectedObjects objectAtIndex: 0]) != nil)
	{
		NSString* const name = [selection objectForKey: @"name"];
		NSString* const url  = [selection objectForKey: @"url"];

		// If no option-key then look for & try to activate extant Repository window.
		if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) ||
			![self showExtantWindow: name url: url])
		{
			[self openRepositoryBrowser: url title: name
					user: [selection objectForKey: @"user"]
					pass: [selection objectForKey: @"pass"]];
		}
	}
}


- (void) openRepositoryBrowser: (NSString*) url
		 title:                 (NSString*) title
		 user:                  (NSString*) user
		 pass:                  (NSString*) pass
{
	const id docController = [NSDocumentController sharedDocumentController];

	MyRepository *newDoc = [docController makeUntitledDocumentOfType:@"repository"];	
	[newDoc setupTitle: title username: user password: pass url: StringToURL(url)];

	[docController addDocument: newDoc];

	[newDoc makeWindowControllers];
	[newDoc showWindows];
}


- (IBAction) openPath: (id) sender
{
	NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	NSString *selectionPath = nil;
	
	if (selectionPath == nil)
	{
		selectionPath = NSHomeDirectory();
	}
	
	[oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories:YES];
	[oPanel setCanChooseFiles:NO];
	
	[oPanel beginSheetForDirectory:selectionPath file:nil types:nil modalForWindow:window
				modalDelegate: self
				didEndSelector:@selector(openPathDidEnd:returnCode:contextInfo:)
				contextInfo:nil
		];
}


- (void) openPathDidEnd: (NSOpenPanel*) sheet
		 returnCode:     (int)          returnCode
		 contextInfo:    (void*)        contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString* pathToFile = [[sheet filenames] objectAtIndex: 0];
		[repositoriesAC setValue:   [NSString stringWithFormat: @"file://%@", pathToFile]
						forKeyPath: @"selection.url"];
		[self saveRepositoriesPrefs];
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Drag & drop

- (BOOL) tableView:    (NSTableView*)  tv
		 writeRows:    (NSArray*)      rows
		 toPasteboard: (NSPasteboard*) pboard
{
	// declare our own pasteboard types
	NSArray *typesArray = [NSArray arrayWithObjects:@"COPIED_ROWS_TYPE", @"MOVED_ROWS_TYPE", nil];

	/*
	 If the number of rows is not 1, then we only support our own types.
	 If there is just one row, then try to create an NSURL from the url
	 value in that row.  If that's possible, add NSURLPboardType to the
	 list of supported types, and add the NSURL to the pasteboard.
	 */
	if ([rows count] != 1)
	{
		[pboard declareTypes:typesArray owner:self];
	}
	else
	{
		// Try to create an URL
		// If we can, add NSURLPboardType to the declared types and write
		//the URL to the pasteboard; otherwise declare existing types
		int row = [[rows objectAtIndex:0] intValue];
		NSString *urlString = [[[repositoriesAC arrangedObjects] objectAtIndex:row] valueForKey:@"url"];
		NSURL *url;
		if (urlString && (url = [NSURL URLWithString:urlString]))
		{
			typesArray = [typesArray arrayByAddingObject:NSURLPboardType];	
			[pboard declareTypes:typesArray owner:self];
			[url writeToPasteboard:pboard];	
		}
		else
		{
			[pboard declareTypes:typesArray owner:self];
		}
	}
	
	// add rows array for local move
	[pboard setPropertyList:rows forType:@"MOVED_ROWS_TYPE"];
	
	// create new array of selected rows for remote drop
	// could do deferred provision, but keep it direct for clarity
	NSMutableArray *rowCopies = [NSMutableArray arrayWithCapacity:[rows count]];
	NSEnumerator *rowEnumerator = [rows objectEnumerator];
	NSNumber *idx;
	while (idx = [rowEnumerator nextObject])
	{
		[rowCopies addObject:[[repositoriesAC arrangedObjects] objectAtIndex:[idx intValue]]];
	}
	// setPropertyList works here because we're using dictionaries, strings,
	// and dates; otherwise, archive collection to NSData...
	[pboard setPropertyList:rowCopies forType:@"COPIED_ROWS_TYPE"];
	
	return YES;
}


- (NSDragOperation) tableView:             (NSTableView*)             tv
					validateDrop:          (id<NSDraggingInfo>)       info
					proposedRow:           (int)                      row
					proposedDropOperation: (NSTableViewDropOperation) op
{
//	NSDragOperation dragOp = NSDragOperationCopy;
	NSPasteboard *pboard = pboard;
	NSDragOperation sourceMask = [info draggingSourceOperationMask];

	// we want to put the object at, not over,
	// the current row (contrast NSTableViewDropOn) 
	[tv setDropRow:row dropOperation:NSTableViewDropAbove];

	if ( sourceMask & NSDragOperationMove ) return NSDragOperationMove;
	if ( sourceMask & NSDragOperationCopy ) return NSDragOperationCopy;

	// default
	return NSDragOperationNone;
}


- (BOOL) tableView:     (NSTableView*)             tv
		 acceptDrop:    (id<NSDraggingInfo>)       info
		 row:           (int)                      row
		 dropOperation: (NSTableViewDropOperation) op
{
	NSPasteboard *pboard = [info draggingPasteboard];
	NSDragOperation sourceMask = [info draggingSourceOperationMask];

	if (row < 0)
	{
		row = 0;
	}

	// if drag source is self, it's a move
	if ( sourceMask & NSDragOperationMove )
	{
//	if ([info draggingSource] == tableView)
//	{
		NSArray *rows = [pboard propertyListForType:@"MOVED_ROWS_TYPE"];
		NSIndexSet  *indexSet = [repositoriesAC indexSetFromRows:rows];
		
		[repositoriesAC moveObjectsInArrangedObjectsFromIndexes:indexSet toIndex:row];
		
		// set selected rows to those that were just moved
		// Need to work out what moved where to determine proper selection...
		int rowsAbove = [repositoriesAC rowsAboveRow:row inIndexSet:indexSet];
		
		NSRange range = NSMakeRange(row - rowsAbove, [indexSet count]);
		indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
		[repositoriesAC setSelectionIndexes:indexSet];

		[self saveRepositoriesPrefs];

		return YES;
	}
	else if ( sourceMask & NSDragOperationCopy )
	{
		// Can we get rows from another document?  If so, add them, then return.
		NSArray *newRows = [pboard propertyListForType:@"COPIED_ROWS_TYPE"];
		if (newRows)
		{
			NSRange range = NSMakeRange(row, [newRows count]);
			NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
			
			[repositoriesAC insertObjects:newRows atArrangedObjectIndexes:indexSet];
			// set selected rows to those that were just copied
			[repositoriesAC setSelectionIndexes:indexSet];

			[self saveRepositoriesPrefs];
			
			return YES;
		}
	} 

	// Can we get an URL?  If so, add a new row, configure it, then return.
	NSURL *url = [NSURL URLFromPasteboard:pboard];
	if (url)
	{
		id newObject = [repositoriesAC newObject];	
		[repositoriesAC insertObject:newObject atArrangedObjectIndex:row];
		// "new" -- returned with retain count of 1
		[newObject release];
		[newObject takeValue:[url absoluteString] forKey:@"url"];
		[newObject takeValue:[NSCalendarDate date] forKey:@"date"];
		// set selected rows to those that were just copied
		[repositoriesAC setSelectionIndex:row];

		[self saveRepositoriesPrefs];
		
		return YES;		
	}

	return NO;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Prefs Saving

// see Interface builder's text fields

- (IBAction) onValidate: (id) sender
{
	[self saveRepositoriesPrefs];
}


- (void) saveRepositoriesPrefs
{
	NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[self repositories]] forKey:@"repositories"];
	[prefs setObject: NSBool([[self disclosureView] state]) forKey: @"repEditShown"];
	[prefs synchronize];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Accessors

- (void) insertObject:          (id)           anObject
		 inRepositoriesAtIndex: (unsigned int) index
{
	[repositories insertObject: anObject atIndex: index];
	[self saveRepositoriesPrefs];
}


- (void) removeObjectFromRepositoriesAtIndex: (unsigned int) index
{
	[repositories removeObjectAtIndex: index];
	[self saveRepositoriesPrefs];
}


- (void) replaceObjectInRepositoriesAtIndex: (unsigned int) index
		 withObject:                         (id)           anObject
{
	[repositories replaceObjectAtIndex: index withObject: anObject];
	[self saveRepositoriesPrefs];	
}


// - repositories:
- (NSMutableArray*) repositories
{
	return repositories; 
}


// - setRepositories:
- (void) setRepositories: (NSMutableArray*) aRepositories
{
	id old = repositories;
	repositories = [aRepositories retain];
	[old release];
}


@end

