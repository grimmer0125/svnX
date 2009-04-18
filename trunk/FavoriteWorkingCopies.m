#import "FavoriteWorkingCopies.h"
#import "EditListResponder.h"
#import "MyDragSupportArrayController.h"
#import "MyRepository.h"
#import "MyWorkingCopy.h"
#include "CommonUtils.h"


static NSString* const kDocType = @"workingCopy";


//----------------------------------------------------------------------------------------

@implementation FavoriteWorkingCopies

- (id) init
{
	self = [super init: @"wc"];
	if (self)
	{
		favoriteWorkingCopies = [[NSMutableArray array] retain];
		NSData* dataPrefs = [[NSUserDefaults standardUserDefaults] dataForKey: @"favoriteWorkingCopies"];

		if (dataPrefs != nil)
		{
			NSArray* arrayPrefs = [NSUnarchiver unarchiveObjectWithData: dataPrefs];

			if (arrayPrefs != nil)
			{
				[favoriteWorkingCopies addObjectsFromArray: arrayPrefs];
			}
		}
	}

	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver: self];

	[favoriteWorkingCopies release];
	[super dealloc];
}


- (void) savePreferences
{
	[self saveFavoriteWorkingCopiesPrefs];
}


- (NSArray*) dataArray
{
	return favoriteWorkingCopies;
}


- (void) awakeFromNib
{
	tableView = workingCopiesTableView;

	// Took me some time to find this one !!!
	// There is no possibility to bind an ArrayController to an arbitrary object in Interface Builder... in Panther.
	
	[favoriteWorkingCopiesAC bind:@"contentArray" toObject:self  withKeyPath:@"favoriteWorkingCopies" options:nil];

	[tableView registerForDraggedTypes:
					[NSArray arrayWithObjects:@"COPIED_ROWS_TYPE", @"MOVED_ROWS_TYPE", NSFilenamesPboardType, nil]];

	// Notification for user creating a new working copy - now add item into favorites list.
	[[NSNotificationCenter defaultCenter] addObserver: self 
		selector: @selector(newWorkingCopyNotificationHandler:) name: @"newWorkingCopy" object: nil];

	[[NSUserDefaultsController sharedUserDefaultsController]
							addObserver: self
							forKeyPath:  @"values.abbrevWCFilePaths"
							options:     0
							context:     NULL];

	[super awakeFromNib];
}


- (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	#pragma unused(keyPath, object, change, context)
	[workingCopiesTableView setNeedsDisplay: TRUE];
}


- (void) newWorkingCopyNotificationHandler: (NSNotification*) notification
{
	[self newWorkingCopyItemWithPath: [notification object]];
	
	[window makeKeyAndOrderFront: nil];
}


- (IBAction) newWorkingCopyItem: (id) sender
{
	#pragma unused(sender)
	[self newWorkingCopyItemWithPath: NSHomeDirectory()];
}


// Adds a new working copy with the given path.
- (void) newWorkingCopyItemWithPath: (NSString*) workingCopyPath
{
	[favoriteWorkingCopiesAC addObject:
		[NSMutableDictionary dictionaryWithObjectsAndKeys: @"My Project", @"name",
														   workingCopyPath, @"fullPath",
														   @"", @"user",
														   @"", @"pass",
														   nil]];
	[favoriteWorkingCopiesAC setSelectionIndex:([[favoriteWorkingCopiesAC arrangedObjects] count]-1)];
	
	[window makeFirstResponder:nameTextField];	
}


- (BOOL) showExtantWindow: (NSString*) name
		 fullPath:         (NSString*) fullPath
{
	NSArray* docs = [[NSDocumentController sharedDocumentController] documents];
	for_each(enumerator, obj, docs)
	{
		if ([[obj fileType] isEqualToString: kDocType] &&
			[[obj windowTitle] isEqualToString: name] &&
			[[obj workingCopyPath] isEqualToString: fullPath])
		{
			[[[[obj windowControllers] objectAtIndex: 0] window] makeKeyAndOrderFront: self];
			return TRUE;
		}
	}

	return FALSE;
}


- (MyWorkingCopy*) openNewDocument: (id) workingCopy
{
	NSString* const name = [workingCopy valueForKey: @"name"];
	// The controller needs the name in awakeFromNib, but the document doesn't know it until later.
	[MyWorkingCopy presetDocumentName: name];
	MyWorkingCopy* const newDoc = [[NSDocumentController sharedDocumentController]
										openUntitledDocumentOfType: kDocType display: YES];

	[newDoc setup: name
			user:  [workingCopy valueForKey: @"user"]
			pass:  [workingCopy valueForKey: @"pass"]
			path:  [workingCopy valueForKey: @"fullPath"]];

	return newDoc;
}


- (void) onDoubleClick: (id) sender
{
	#pragma unused(sender)
	if ( [[favoriteWorkingCopiesAC selectedObjects] count] != 0 )
	{
		const id selection = [favoriteWorkingCopiesAC valueForKey: @"selection"];

		// If no option-key then look for & try to activate extant Working Copy window.
		if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) ||
			![self showExtantWindow: [selection valueForKey: @"name"]
				   fullPath:         [selection valueForKey: @"fullPath"]])
		{
			[self openNewDocument: selection];
		}
	}
}


- (IBAction) openPath: (id) sender
{
	#pragma unused(sender)
	NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	NSString *selectionPath = [favoriteWorkingCopiesAC valueForKeyPath:@"selection.fullPath"];
	
	if (selectionPath == nil )
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


- (IBAction) onValidate: (id) sender
{
	#pragma unused(sender)
	[self saveFavoriteWorkingCopiesPrefs];
}


- (void) saveFavoriteWorkingCopiesPrefs
{
	NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
	[prefs setObject: [NSArchiver archivedDataWithRootObject: favoriteWorkingCopies] forKey: @"favoriteWorkingCopies"];
	[prefs setObject: NSBool([[self disclosureView] state]) forKey: @"wcEditShown"];
	[prefs synchronize];
}


- (void) openPathDidEnd: (NSOpenPanel*) sheet
		 returnCode:     (int)          returnCode
		 contextInfo:    (void*)        contextInfo
{
	#pragma unused(contextInfo)
	NSString *pathToFile = nil;

	if (returnCode == NSOKButton)
	{
		pathToFile = [[[sheet filenames] objectAtIndex:0] copy];
		[favoriteWorkingCopiesAC setValue:pathToFile forKeyPath:@"selection.fullPath"];
		[self saveFavoriteWorkingCopiesPrefs];
	}
}


- (void) fileHistoryOpenSheetForItem: (NSString*) aPath
{
	id bestMatchWc = nil;
	int bestMatchScore = 0;
	MyWorkingCopy* wcDocument = nil;
	NSArray* const documents = [[NSDocumentController sharedDocumentController] documents];

	// Find among the known working copies one that has a matching path
	NSEnumerator *e = [[favoriteWorkingCopiesAC arrangedObjects] objectEnumerator];
	for (id wc; (wcDocument == nil) && (wc = [e nextObject]) != nil; )
	{
		NSString* const fullPath = [wc valueForKey: @"fullPath"];
		NSRange r = [aPath rangeOfString: fullPath options: NSLiteralSearch | NSAnchoredSearch];

		if (r.location == 0 && r.length > bestMatchScore)
		{
			bestMatchWc = wc;
			bestMatchScore = r.length;

			// if the working copy is currently open in svnx we stop there and use it
			for_each(enumerator, anOpenDocument, documents)
			{
				if ([[anOpenDocument fileType] isEqualToString: kDocType] &&
					[[anOpenDocument workingCopyPath] isEqualToString: fullPath])
				{
					// we found a matching working copy that is currently open in svnX
					wcDocument = anOpenDocument;
					break;
				}
			}
		}
	}

	// if we found a matching working copy that is not currently open, then let's open it
	if (wcDocument == nil && bestMatchWc != nil)
		wcDocument = [self openNewDocument: bestMatchWc];

	if (wcDocument != nil)
	{
		[[wcDocument controller]
			fileHistoryOpenSheetForItem: [NSDictionary dictionaryWithObject: aPath forKey: @"fullPath"]];
	}
	else
	{
		NSRunAlertPanel(@"No working copy found.",
						[NSString stringWithFormat:
								@"svnX cannot find a working copy for the file %C%@%C.\n\n"
								 "Please make sure that the working copy that owns the file"
								 " is defined in svnX's Working Copies window.",
								 0x201C, aPath, 0x201D],
						@"Cancel", nil, nil);
	}
}


//----------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Drag & drop
//----------------------------------------------------------------------------------------

- (BOOL) tableView:    (NSTableView*)  tv
		 writeRows:    (NSArray*)      rows
		 toPasteboard: (NSPasteboard*) pboard
{
	#pragma unused(tv)
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
		// the URL to the pasteboard; otherwise declare existing types
		int row = [[rows objectAtIndex:0] intValue];
		NSString *urlString = [[[favoriteWorkingCopiesAC arrangedObjects] objectAtIndex:row] valueForKey:@"url"];
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
	for_each(enumerator, idx, rows)
	{
		[rowCopies addObject:[[favoriteWorkingCopiesAC arrangedObjects] objectAtIndex:[idx intValue]]];
	}
	// setPropertyList works here because we're using dictionaries, strings,
	// and dates; otherwise, archive collection to NSData...
	[pboard setPropertyList:rowCopies forType:@"COPIED_ROWS_TYPE"];
	
    return YES;
}


- (NSDragOperation)tableView:(NSTableView*)tv
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(int)row
	   proposedDropOperation:(NSTableViewDropOperation)op
{
	#pragma unused(op)
    NSDragOperation dragOp = NSDragOperationCopy;
    
    // if drag source is self, it's a move
    if ([info draggingSource] == workingCopiesTableView)
	{
		dragOp =  NSDragOperationMove;
    }
    // we want to put the object at, not over,
    // the current row (contrast NSTableViewDropOn) 
    [tv setDropRow:row dropOperation:NSTableViewDropAbove];
	
    return dragOp;
}


- (BOOL) tableView:     (NSTableView*)             tv
		 acceptDrop:    (id<NSDraggingInfo>)       info
		 row:           (int)                      row
		 dropOperation: (NSTableViewDropOperation) op
{
	#pragma unused(tv, op)
	if (row < 0)
	{
		row = 0;
	}

    // if drag source is self, it's a move
    if ([info draggingSource] == workingCopiesTableView)
    {
		NSArray *rows = [[info draggingPasteboard] propertyListForType:@"MOVED_ROWS_TYPE"];
		NSIndexSet  *indexSet = [favoriteWorkingCopiesAC indexSetFromRows:rows];
		
		[favoriteWorkingCopiesAC moveObjectsInArrangedObjectsFromIndexes:indexSet toIndex:row];
		
		// set selected rows to those that were just moved
		// Need to work out what moved where to determine proper selection...
		int rowsAbove = [favoriteWorkingCopiesAC rowsAboveRow:row inIndexSet:indexSet];
		
		NSRange range = NSMakeRange(row - rowsAbove, [indexSet count]);
		indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
		[favoriteWorkingCopiesAC setSelectionIndexes:indexSet];
		
		[self saveFavoriteWorkingCopiesPrefs];
		
		return YES;
    }
	
	// Can we get rows from another document?  If so, add them, then return.
	NSArray *newRows = [[info draggingPasteboard] propertyListForType:@"COPIED_ROWS_TYPE"];
	if (newRows)
	{
		NSRange range = NSMakeRange(row, [newRows count]);
		NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
		
		[favoriteWorkingCopiesAC insertObjects:newRows atArrangedObjectIndexes:indexSet];
		// set selected rows to those that were just copied
		[favoriteWorkingCopiesAC setSelectionIndexes:indexSet];
		
		[self saveFavoriteWorkingCopiesPrefs];
		
		return YES;
    }

	NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	if (files)
	{
		id newObject = [favoriteWorkingCopiesAC newObject];	
		[favoriteWorkingCopiesAC insertObject:newObject atArrangedObjectIndex:row];
		// "new" -- returned with retain count of 1
		[newObject release];
		[newObject takeValue:[files objectAtIndex:0] forKey:@"fullPath"];
		[newObject takeValue:[[files objectAtIndex:0] lastPathComponent] forKey:@"name"];

		// set selected rows to those that were just copied
		[favoriteWorkingCopiesAC setSelectionIndex:row];
		
		[self saveFavoriteWorkingCopiesPrefs];
		
		return YES;		
	}
    return NO;
}


@end

