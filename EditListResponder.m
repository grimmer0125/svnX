//
// EditListResponder.m
//

#import "EditListResponder.h"
#import "CommonUtils.h"
#import "ViewUtils.h"


static ConstString kCopyType = @"svnX_COPIED_ROWS",
				   kMoveType = @"svnX_MOVED_ROWS";


//----------------------------------------------------------------------------------------

static void
moveObjectsFromIndexes (NSArrayController* ac, NSIndexSet* indexSet, unsigned toIndex)
{
	unsigned off1 = 0, off2 = 0;

	for (unsigned currentIndex = [indexSet firstIndex]; currentIndex != NSNotFound;
		 currentIndex = [indexSet indexGreaterThanIndex: currentIndex])
	{
		unsigned i = currentIndex, i1 = i, i2 = toIndex;

		if (i < toIndex)
			i1 = i -= off1++;
		else
			i1 = i + 1, i2 += off2++;
		[ac insertObject: [[ac arrangedObjects] objectAtIndex: i] atArrangedObjectIndex: i2];
		[ac removeObjectAtArrangedObjectIndex: i1];
	}
}


//----------------------------------------------------------------------------------------

static NSIndexSet*
indexSetFromRows (NSArray* rows)
{
	NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
	for_each_obj(en, idx, rows)
	{
		[indexSet addIndex: [idx intValue]];
	}
	return indexSet;
}


//----------------------------------------------------------------------------------------

static int
rowsAboveRow (NSIndexSet* indexSet, int row)
{
	unsigned currentIndex = [indexSet firstIndex];
	int i = 0;
	while (currentIndex != NSNotFound)
	{
		if (currentIndex < row) ++i;
		currentIndex = [indexSet indexGreaterThanIndex: currentIndex];
	}
	return i;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation EditListResponder

//----------------------------------------------------------------------------------------

- (id) init: (const EditListPrefKeys*) prefsKeys
{
	Assert(prefsKeys != NULL);
	if (self = [super init])
	{
		fPrefKeys  = prefsKeys;
		fDataArray = [[NSMutableArray array] retain];
		NSData* data = GetPreference(fPrefKeys->data);
		NSArray* array;

		if (data != nil && (array = [NSUnarchiver unarchiveObjectWithData: data]) != nil)
		{
			[fDataArray setArray: array];
		}
	}

	return self;
}

//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[fDataArray release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------
// subclass to implement

- (id) newObject: (NSPasteboard*) pboard
{
	#pragma unused(pboard)
	return nil;
}


//----------------------------------------------------------------------------------------

- (void) savePreferences
{
	SetPreference(fPrefKeys->data, [NSArchiver archivedDataWithRootObject: fDataArray]);
	SetPreferenceBool(fPrefKeys->editShown, [[self disclosureView] state] == NSOnState);
	SyncPreference();
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	User Interface
//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
	Assert(fTableView != nil);
	if (fTableView)
	{
		[fTableView setDraggingSourceOperationMask: NSDragOperationCopy | NSDragOperationMove
										  forLocal: YES];
		[fTableView registerForDraggedTypes:
				[NSArray arrayWithObjects: kCopyType, kMoveType, fPrefKeys->dragType, nil]];

		[self setNextResponder: [fTableView nextResponder]];
		[fTableView setNextResponder: self];

		[fTableView setDoubleAction: @selector(onDoubleClick:)];
		[fTableView setTarget: self];
	}

	// It is not possible to bind an ArrayController to an arbitrary object in Interface Builder...
	[fAC bind: @"contentArray" toObject: self withKeyPath: @"fDataArray" options: nil];

	// Hide the Edit views if the prefs dictate & then set the window frame
	if (!GetPreferenceBool(fPrefKeys->editShown))
	{
		[[self disclosureView] setState: 0];
		[self toggleEdit: nil];		// hide it
	}
	[fWindow setFrameAutosaveName: fPrefKeys->panelFrame];
	if (![fWindow setFrameUsingName: fPrefKeys->panelFrame])
		/*[fWindow setFrameTopLeftPoint: NSMakePoint(200, 44)]*/;
}


//----------------------------------------------------------------------------------------

- (void) showWindow
{
	[fWindow makeKeyAndOrderFront: nil];
}


//----------------------------------------------------------------------------------------

- (NSButton*) disclosureView
{
	return WGetView(fWindow, 1001);
}


//----------------------------------------------------------------------------------------

- (NSTextField*) nameTextField
{
	return WGetView(fWindow, 1002);
}


//----------------------------------------------------------------------------------------
// Hide/Show the Edit views

- (void) toggleEdit: (id) sender
{
	const bool isVisible = (sender != nil);
	NSView* contentView = [fWindow contentView];
	NSView* scrollView = [[contentView subviews] objectAtIndex: 0];
//	NSView* scrollView = [[[contentView viewWithTag: 1000] superview] superview];

	const bool doShow = [fEditBox isHidden];
	if (doShow)
		[fEditBox setHidden: false];
	NSRect rect = [fEditBox frame];
	const GCoord dy = doShow ? rect.size.height : -rect.size.height;

	const UInt32 sizeScroll = [scrollView autoresizingMask],
				 sizeEdit   = [fEditBox autoresizingMask];

	[scrollView setAutoresizingMask: NSViewMinYMargin];
	[fEditBox   setAutoresizingMask: NSViewMinYMargin];

	rect = [fWindow frame];
	rect.size.height += dy;
	rect.origin.y    -= dy;
	[fWindow setFrame: rect display: isVisible animate: isVisible];

	[scrollView setAutoresizingMask: sizeScroll];
	[fEditBox   setAutoresizingMask: sizeEdit];

	if (!doShow)
		[fEditBox setHidden: true];

	[fWindow makeFirstResponder: doShow ? [fEditBox nextValidKeyView] : scrollView];
	NSSize size = [fWindow minSize];
	size.height += dy;
	[fWindow setMinSize: size];
	if (isVisible)
		[self savePreferences];
//	[[fTableView cornerView] setNeedsDisplay: TRUE];
}


//----------------------------------------------------------------------------------------
// subclass to override

- (IBAction) newItem: (id) sender
{
	#pragma unused(sender)
	[fAC setSelectionIndex: [[fAC arrangedObjects] count] - 1];
	[fWindow makeFirstResponder: [self nameTextField]];
}


//----------------------------------------------------------------------------------------

- (IBAction) removeItem: (id) sender
{
	[fAC remove: sender];
	[self savePreferences];
}


//----------------------------------------------------------------------------------------
// subclass to implement

- (IBAction) openPath: (id) sender
{
	#pragma unused(sender)
}


//----------------------------------------------------------------------------------------

- (IBAction) onValidate: (id) sender
{
	#pragma unused(sender)
	[self savePreferences];
}


//----------------------------------------------------------------------------------------

- (void) keyDown: (NSEvent*) theEvent
{
	const unichar ch = [[theEvent characters] characterAtIndex: 0];
	if (ch == '\r' || ch == 3)
		[self onDoubleClick: nil];
	else if (ch >= ' ')
	{
		const int rows = [fTableView numberOfRows];
		int i, selRow = [fTableView selectedRow];
		if (selRow < 0)
			selRow = rows - 1;
		unichar ch0 = (ch >= 'a' && ch <= 'z') ? (ch - 32) : ch;
	//	NSString* prefix = [NSString stringWithCharacters: &ch0 length: 1];
		NSArray* const dataArray = fDataArray;
		for (i = 1; i <= rows; ++i)
		{
			int index = (selRow + i) % rows;
			id wc = [dataArray objectAtIndex: index];
			NSString* name = [wc objectForKey: @"name"];
			if ([name length] && ([name characterAtIndex: 0] & ~0x20) == ch0)
	//		if ([[wc objectForKey: @"name"] hasPrefix: prefix])
			{
				[fTableView selectRow: index byExtendingSelection: false];
				[fTableView scrollRowToVisible: index];
				break;
			}
		}
	}
	else
		[super keyDown: theEvent];
}


//----------------------------------------------------------------------------------------
// subclass to implement

- (void) onDoubleClick: (id) sender
{
	#pragma unused(sender)
#if 0
	NSArray* selectedObjects = [fAC selectedObjects];
	NSDictionary* selection;
	if ([selectedObjects count] != 0 && (selection = [selectedObjects objectAtIndex: 0]) != nil)
	{
		[self openItem: selection withOptionKey: AltOrShiftPressed()];
	}
#endif
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	TableView Delegate/Drag & Drop
//----------------------------------------------------------------------------------------

- (int) numberOfRowsInTableView: (NSTableView*) tableView
{
	#pragma unused(tableView)
	return [[fAC arrangedObjects] count];
}


//----------------------------------------------------------------------------------------
// If the number of rows is not 1, then we only support our own types.  If there is just one
// row, then try to create an NSURL from the url value in that row.  If that's possible,
// add NSURLPboardType to the list of supported types, and add the NSURL to the pasteboard.

- (BOOL) tableView:    (NSTableView*)  tableView
		 writeRows:    (NSArray*)      rows
		 toPasteboard: (NSPasteboard*) pboard
{
	#pragma unused(tableView)

	const id arrangedObjects = [fAC arrangedObjects];
	NSURL* url = nil;
	if ([rows count] == 1)
	{
		// Try to create an URL
		// If we can, add NSURLPboardType to the declared types and write
		// the URL to the pasteboard; otherwise declare existing types
		int row = [[rows lastObject] intValue];
		NSString* urlString = [[arrangedObjects objectAtIndex: row] valueForKey: @"url"];
		if (urlString)
			url = [NSURL URLWithString: urlString];
	}

	// declare our own pasteboard types
	NSArray* typesArray = [NSArray arrayWithObjects: kCopyType, kMoveType,
													 url ? NSURLPboardType : nil, nil];
	[pboard declareTypes: typesArray owner: self];
	if (url)
		[url writeToPasteboard: pboard];

	// add rows array for local move
	[pboard setPropertyList: rows forType: kMoveType];

	// create new array of selected rows for remote drop
	// could do deferred provision, but keep it direct for clarity
	NSMutableArray* rowCopies = [NSMutableArray arrayWithCapacity: [rows count]];
	for_each_obj(enumerator, idx, rows)
	{
		[rowCopies addObject: [arrangedObjects objectAtIndex: [idx intValue]]];
	}
	// setPropertyList works here because we're using dictionaries, strings,
	// and dates; otherwise, archive collection to NSData...
	[pboard setPropertyList: rowCopies forType: kCopyType];

	return YES;
}


//----------------------------------------------------------------------------------------

- (NSDragOperation) tableView:             (NSTableView*)             tableView
					validateDrop:          (id<NSDraggingInfo>)       info
					proposedRow:           (int)                      row
					proposedDropOperation: (NSTableViewDropOperation) op
{
	#pragma unused(op)
	NSDragOperation sourceMask = [info draggingSourceOperationMask];

	// we want to put the object at, not over,
	// the current row (contrast NSTableViewDropOn)
	[tableView setDropRow: row dropOperation: NSTableViewDropAbove];

	if (sourceMask & NSDragOperationMove) return NSDragOperationMove;
	if (sourceMask & NSDragOperationCopy) return NSDragOperationCopy;

	// default
	return NSDragOperationNone;
}


//----------------------------------------------------------------------------------------

- (BOOL) tableView:     (NSTableView*)             tableView
		 acceptDrop:    (id<NSDraggingInfo>)       info
		 row:           (int)                      row
		 dropOperation: (NSTableViewDropOperation) op
{
	#pragma unused(tableView, op)
	NSPasteboard* pboard = [info draggingPasteboard];
	NSDragOperation sourceMask = [info draggingSourceOperationMask];
	BOOL accept = NO;

	if (row < 0)
		row = 0;

	// if drag source is self, it's a move
	if ((sourceMask & NSDragOperationMove) && [info draggingSource] == fTableView)
	{
		NSIndexSet* indexSet = indexSetFromRows([pboard propertyListForType: kMoveType]);

		moveObjectsFromIndexes(fAC, indexSet, row);

		// set selected rows to those that were just moved
		// Need to work out what moved where to determine proper selection...
		int rowsAbove = rowsAboveRow(indexSet, row);

		NSRange range = NSMakeRange(row - rowsAbove, [indexSet count]);
		indexSet = [NSIndexSet indexSetWithIndexesInRange: range];
		[fAC setSelectionIndexes: indexSet];

		accept = YES;
	}
	else if (sourceMask & NSDragOperationCopy)
	{
		// Can we get rows from another document?  If so, add them, then return.
		NSArray* newRows = [pboard propertyListForType: kCopyType];
		if (newRows)
		{
			NSRange range = NSMakeRange(row, [newRows count]);
			NSIndexSet* indexSet = [NSIndexSet indexSetWithIndexesInRange: range];

			[fAC insertObjects: newRows atArrangedObjectIndexes: indexSet];
			// set selected rows to those that were just copied
			[fAC setSelectionIndexes: indexSet];

			accept = YES;
		}
	}

	if (!accept)
	{
		const id obj = [self newObject: pboard];
		if (obj)
		{
			[fAC insertObject: obj atArrangedObjectIndex: row];
			[fAC setSelectionIndex: row];	// set selected rows to that of the new object
			[obj release];

			accept = YES;
		}
	}

	if (accept)
		[self savePreferences];
	return accept;
}


@end

//----------------------------------------------------------------------------------------
// End of EditListResponder.m
