#import "MyDragSupportMatrix.h"

@implementation MyDragSupportMatrix

// Special init would be done here :
- (id)initWithFrame:(NSRect)frameRect mode:(int)aMode prototype:(NSCell *)aCell numberOfRows:(int)numRows numberOfColumns:(int)numColumns
{
	if ( self = [super initWithFrame:frameRect mode:aMode prototype:aCell numberOfRows:numRows numberOfColumns:numColumns] )
	{	
		// register for files dragged to the repository (-> svn import)
		[self registerForDraggedTypes:	[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    }
    return self;
}

//  - dealloc:
- (void)dealloc {
    [self setDestinationCell: nil];

    [super dealloc];
}

#pragma mark -
#pragma mark Drag Out (export/checkout)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender { 

    if ([sender draggingSource] == self) {

        return NSDragOperationNone;
    } else {
        return NSDragOperationAll;
    }
}

- (void)mouseDown:(NSEvent *)event
{
  // need to override this because NSMatrix eats drag events
  int row, col;

  if ([self getRow: &row column: &col forPoint:[self convertPoint:[event locationInWindow] fromView: nil]])
  {

    if ([event modifierFlags] & NSCommandKeyMask) {
        int r, c, s, i, i2;
        r = [self selectedRow];
        c = [self selectedColumn];
        s = [self numberOfColumns];
        i = r*s + c;
        i2 = row*s + col;
        [self setSelectionFrom:i2 to:i2 anchor:i2 highlight:YES];     
    } else if ([event modifierFlags] & NSShiftKeyMask) {
        int r, c, s, i, i2;
        r = [self selectedRow];
        c = [self selectedColumn];
        s = [self numberOfColumns];
        i = r*s + c;
        i2 = row*s + col;
        [self setSelectionFrom:i to:i2 anchor:i highlight:YES];
    } else {
		
		if ( ! [self isCellSelected:[self cellAtRow:row column:col]] ) [self selectCellAtRow:row column:col];
    }


    [self sendAction];
    // this is used to deal with NSBrowser issues
    [[self window] makeFirstResponder:self];

  } else {
    [super mouseDown: event];
  }

}

- (BOOL)isCellSelected:(NSCell *)cell
{
	NSArray *selectedCells = [self selectedCells];
	NSEnumerator *e = [selectedCells objectEnumerator];
	id c;
	BOOL cellIsSelected = FALSE;
	
	while ( c = [e nextObject] )
	{
		if ( c == cell )
		{
			cellIsSelected = TRUE;
			break;
		}
	}
	
	return cellIsSelected;
}

- (void)mouseDragged:(NSEvent *)event
{
	NSPoint dragPoint;
	int row, col;

	NSCell *cell;
    NSPoint dragPosition;
    NSRect imageLocation;

    dragPosition = [self convertPoint:[event locationInWindow] fromView:nil];
    imageLocation.origin = dragPosition;
    imageLocation.size = NSMakeSize(32,32);
	
	// dragPromisedFilesOfTypes is meant for Finder. This will in turn call dragImage:at:offset... that we will override below to implement draggin to working copy (svn switch)
	// see http://developer.apple.com/qa/qa2001/qa1300.html
	
    [self dragPromisedFilesOfTypes:[[self selectedCells] valueForKeyPath:@"representedObject.fileType"] // key/value coding magic !
            fromRect:imageLocation
            source:self
            slideBack:YES
            event:event]; 
	return;
}

- (void)dragImage:(NSImage *)anImage at:(NSPoint)imageLoc offset:(NSSize)mouseOffset event:(NSEvent *)theEvent pasteboard:(NSPasteboard *)pboard source:(id)sourceObject slideBack:(BOOL)slideBack
{
	// if we're dragging exactly one cell
	if ( [[self selectedCells] count] == 1 ) 
	{
		NSCell *selectedCell = [[self selectedCells] objectAtIndex:0];
		
		// ... and the cell is a directory... then implement drag to working copy (svn switch)
		if ( [[selectedCell valueForKeyPath:@"representedObject.isDir"] boolValue] )
		{
			NSSize dragOffset = NSMakeSize(0.0, 0.0);
			[pboard addTypes:[NSArray arrayWithObject:@"REPOSITORY_PATH_AND_REVISION_TYPE"] owner:self];
			[pboard setData:[NSArchiver archivedDataWithRootObject:[selectedCell valueForKey:@"representedObject"]] forType:@"REPOSITORY_PATH_AND_REVISION_TYPE"];
			NSImage *img = [NSImage imageNamed:@"repository"];
			[img  setSize:NSMakeSize(32, 32)];
			
			[super dragImage:img at:imageLoc offset:dragOffset event:theEvent pasteboard:pboard source:self slideBack:NO];
		}
		else [super dragImage:anImage at:imageLoc offset:mouseOffset event:theEvent pasteboard:pboard source:sourceObject slideBack:slideBack];
		
	} else
	
	[super dragImage:anImage at:imageLoc offset:mouseOffset event:theEvent pasteboard:pboard source:sourceObject slideBack:slideBack];
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return NSDragOperationCopy | NSDragOperationPrivate;
}



- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
{
	[[[self window] document] dragOutFilesFromRepository:[[self selectedCells] valueForKey:@"representedObject"] toURL:dropDestination];
	
	return NULL; // we're just interested in the dropDestination.
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	// Panther bug workaround (http://www.cocoabuilder.com/archive/message/cocoa/2005/1/31/127154 and http://www.cocoabuilder.com/archive/message/2004/10/5/118857)
	[[NSPasteboard pasteboardWithName:NSDragPboard] declareTypes:nil owner:nil];

}

#pragma mark -
#pragma mark Drag In (import)

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSPoint point;
    NSRect drawRect, cellRect;
    int row, column;

    if ([sender draggingSource] == self) return NSDragOperationNone;

	NSArray *files = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];

	if ( [files count] != 1 ) return NSDragOperationNone;
	
	if ( [self getRow: &row column: &column forPoint:[self convertPoint:[sender draggingLocation] fromView: nil]] )
	{
		NSCell *cell = [self cellAtRow:row column:column];
		NSDictionary *obj = [cell representedObject];
		
		if ( ![[obj objectForKey:@"isDir"] boolValue] )
		{
			shouldDraw = NO;
			newDrawRect = NSZeroRect;
			oldDrawRect = NSZeroRect;
			[self setNeedsDisplay:TRUE];
			return NSDragOperationNone;
		}
		
		[self setDestinationCell: cell];
		drawRect = [self cellFrameAtRow:row column:column];

		shouldDraw = TRUE;

		// Don't ask the view to draw it self unless necessary
		if (NSEqualRects(drawRect, oldDrawRect) == FALSE) {
			newDrawRect = drawRect;
			[self setNeedsDisplay:TRUE];
		}

		return NSDragOperationAll;
		
	} else
	{
		shouldDraw = NO;
		[self setNeedsDisplay:TRUE];
		return NSDragOperationNone;
	}
	
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
	shouldDraw = NO;
	newDrawRect = NSZeroRect;
	oldDrawRect = NSZeroRect;
    [self setNeedsDisplay:TRUE];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSArray *types;

	shouldDraw = NO;
	newDrawRect = NSZeroRect;
	oldDrawRect = NSZeroRect;
    [self setNeedsDisplay:TRUE];

    pboard = [sender draggingPasteboard];
	NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

	[[[self window] document] dragExternalFiles:files ToRepositoryAt:[[self destinationCell] representedObject]];
	
    return YES;
}

- (void) drawRect:(NSRect)rect {
    [super drawRect:rect];
	
    if (shouldDraw)
	{
        NSRect rect;

        shouldDraw = TRUE;
        [[NSColor blackColor] set];
        [NSBezierPath strokeRect:newDrawRect];

        oldDrawRect = newDrawRect;
    }
}

#pragma mark -
#pragma mark Accessors

- (NSCell *)destinationCell { return destinationCell; }
- (void)setDestinationCell:(NSCell *)aDestinationCell {
    id old = [self destinationCell];
    destinationCell = [aDestinationCell retain];
    [old release];
}


@end
