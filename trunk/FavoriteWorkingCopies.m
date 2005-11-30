#import "FavoriteWorkingCopies.h"

#define preferences [NSUserDefaults standardUserDefaults]


@implementation FavoriteWorkingCopies

- (id)init
{
    self = [super init];
    if (self)
	{
		NSData *dataPrefs = [preferences objectForKey:@"favoriteWorkingCopies"];
				
		if ( dataPrefs != nil )
		{
			id favoriteWorkingCopiesPrefs = [NSUnarchiver unarchiveObjectWithData:dataPrefs];
			
			if ( favoriteWorkingCopiesPrefs != nil )
			{
				[self setFavoriteWorkingCopies:[NSMutableArray arrayWithArray:favoriteWorkingCopiesPrefs]];
			
			} else
			{
				[self setFavoriteWorkingCopies:[NSMutableArray array]];
			}
		
		} else
		{
			[self setFavoriteWorkingCopies:[NSMutableArray array]];
		}
    }
    return self;
}

- (void)dealloc {
    [self setFavoriteWorkingCopies:nil];
    [super dealloc];
}


- (void)awakeFromNib
{
	// Took me some time to found this one !!!
	// There is no possibility to bind an ArrayController to an arbitrary object in Interface Builder... in Panther.
	
    [favoriteWorkingCopiesAC bind:@"contentArray" toObject:self  withKeyPath:@"favoriteWorkingCopies" options:nil];

	[workingCopiesTableView setDoubleAction:@selector(onDoubleClick:)];

    [workingCopiesTableView registerForDraggedTypes:[NSArray arrayWithObjects:@"COPIED_ROWS_TYPE", @"MOVED_ROWS_TYPE", NSFilenamesPboardType, nil]];

	[workingCopiesTableView setTarget:self];
	
//	[self addObserver:self forKeyPath:@"favoriteWorkingCopies" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
}

//
//- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
//{
//
//	[self saveFavoriteWorkingCopiesPrefs];
//
//}

- (IBAction)newWorkingCopyItem:(id)sender
{
	[favoriteWorkingCopiesAC addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:@"My Project", @"name",
																									NSHomeDirectory(), @"fullPath",
																									@"", @"user",
																									@"", @"pass",
																									nil]];
	[favoriteWorkingCopiesAC setSelectionIndex:([[favoriteWorkingCopiesAC arrangedObjects] count]-1)];
	
	[window makeFirstResponder:nameTextField];	
}

- (void)onDoubleClick:(id)sender
{
	if ( [[favoriteWorkingCopiesAC selectedObjects] count] != 0 )
	{
		NSDocument * newDoc = [[NSDocumentController sharedDocumentController ] openUntitledDocumentOfType:@"workingCopy" display:YES ];	
		
		[newDoc setWindowTitle:[favoriteWorkingCopiesAC valueForKeyPath:@"selection.name"]];
		[newDoc setUser:[favoriteWorkingCopiesAC valueForKeyPath:@"selection.user"]];
		[newDoc setPass:[favoriteWorkingCopiesAC valueForKeyPath:@"selection.pass"]];
		[newDoc setWorkingCopyPath:[favoriteWorkingCopiesAC valueForKeyPath:@"selection.fullPath"]];
	}
}

- (IBAction)openPath:(id)sender
{
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

- (IBAction)onValidate:(id)sender
{
	[self saveFavoriteWorkingCopiesPrefs];
}
- (void)saveFavoriteWorkingCopiesPrefs
{
	[preferences setObject:[NSArchiver archivedDataWithRootObject:[self favoriteWorkingCopies]] forKey:@"favoriteWorkingCopies"];
	[preferences synchronize];
}


- (void)openPathDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
 {
    NSString *pathToFile = nil;

    if (returnCode == NSOKButton) {

        pathToFile = [[[sheet filenames] objectAtIndex:0] copy];
		[favoriteWorkingCopiesAC setValue:pathToFile forKeyPath:@"selection.fullPath"];
		[self saveFavoriteWorkingCopiesPrefs];

    }
}

#pragma mark -
#pragma mark Drag & drop


- (BOOL)tableView:(NSTableView *)tv
		writeRows:(NSArray*)rows
	 toPasteboard:(NSPasteboard*)pboard
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
	NSEnumerator *rowEnumerator = [rows objectEnumerator];
	NSNumber *idx;
	while (idx = [rowEnumerator nextObject])
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



- (BOOL)tableView:(NSTableView*)tv
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)op
{
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


#pragma mark -
#pragma mark Accessors

///////  favoriteWorkingCopies  ///////

- (unsigned int) countOfFavoriteWorkingCopies {
    return [favoriteWorkingCopies count];
}

- (id) objectInFavoriteWorkingCopiesAtIndex: (unsigned int)index {
    return [favoriteWorkingCopies objectAtIndex: index];
}

- (void) insertObject:(id)anObject inFavoriteWorkingCopiesAtIndex: (unsigned int)index {

    [favoriteWorkingCopies insertObject: anObject atIndex: index];
}

- (void) removeObjectFromFavoriteWorkingCopiesAtIndex: (unsigned int)index {
    [favoriteWorkingCopies removeObjectAtIndex: index];
}

- (void) replaceObjectInFavoriteWorkingCopiesAtIndex: (unsigned int)index withObject: (id)anObject {
    [favoriteWorkingCopies replaceObjectAtIndex: index withObject: anObject];
}

// - favoriteWorkingCopies:
- (NSArray *) favoriteWorkingCopies { return favoriteWorkingCopies; }

// - setFavoriteWorkingCopies:
- (void) setFavoriteWorkingCopies: (NSMutableArray *) aFavoriteWorkingCopies {
    id old = [self favoriteWorkingCopies];
    favoriteWorkingCopies = [aFavoriteWorkingCopies retain];
    [old release];
}




@end
