//
// MyDragSupportMatrix.m - Repository NSMatrix subclass
//

#import "MyDragSupportMatrix.h"
#import "MyDragSupportWindow.h"
#import "MyRepository.h"
#import "MySvnRepositoryBrowserView.h"
#import "RepoItem.h"
#import "IconUtils.h"
#import "ViewUtils.h"


//----------------------------------------------------------------------------------------

@implementation MyDragSupportMatrix

//----------------------------------------------------------------------------------------
// Special init would be done here:

- (id) initWithFrame:   (NSRect)  frameRect
	   mode:            (int)     aMode
	   prototype:       (NSCell*) aCell
	   numberOfRows:    (int)     numRows
	   numberOfColumns: (int)     numColumns
{
	#pragma unused(aMode)
	if (self = [super initWithFrame: frameRect
							   mode: NSListModeMatrix
						  prototype: aCell
					   numberOfRows: numRows
					numberOfColumns: numColumns])
	{
		// register for files dragged to the repository (-> svn import)
		[self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (id) initWithCoder: (NSCoder*) decoder
{
	if (self = [super initWithCoder: decoder])
	{
		[self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
	}
	return self;
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[self setDestinationCell: nil];

	[super dealloc];
}


//----------------------------------------------------------------------------------------
// Called if this is not the main repository browser.  Disables drag & drop and double-clicks.

- (void) setupForSubBrowser
{
	isSubBrowser = TRUE;
	[self unregisterDraggedTypes];
}


//----------------------------------------------------------------------------------------
// need to override this because NSMatrix eats drag events

- (void) mouseDown: (NSEvent*) event
{
	int row, col;

	if ([event clickCount] == 2)
	{
		if ([self getRow: &row column: &col forPoint: locationInView(event, self)])
		{
			// call MySvnRepositoryBrowserView's onDoubleClick:
			[[[self target] delegate] onDoubleClick: [self cellAtRow: row column: col]];
		}
	}
	else if ([self getRow: &row column: &col forPoint: locationInView(event, self)])
	{
		const int nCols = [self numberOfColumns];
		BOOL sendAction = YES;
		if ([event modifierFlags] & NSCommandKeyMask)		// Toggle
		{
			int i2 = row * nCols + col;
			NSBrowserCell* cell = [self cellAtRow: row column: col];
			if ([cell isEnabled])
				[self setSelectionFrom: i2 to: i2 anchor: i2 highlight: ![self isCellSelected: cell]];
			else
				sendAction = NO;
		}
		else if ([event modifierFlags] & NSShiftKeyMask)	// Continuous selection
		{
			int r = [self selectedRow];
			int c = [self selectedColumn];
			int i = r * nCols + c;
			int i2 = row * nCols + col;
			[self setSelectionFrom: i to: i2 anchor: i highlight: YES];
		}
		else
		{
			NSBrowserCell* cell = [self cellAtRow: row column: col];
			if ([cell isEnabled] && ![self isCellSelected: cell])
				[self selectCellAtRow: row column: col];
		}

		if (sendAction)
			[self sendAction];

		[[self window] makeFirstResponder: self];	// this is used to deal with NSBrowser issues
	}
	else
		[super mouseDown: event];
}


//----------------------------------------------------------------------------------------

- (BOOL) isCellSelected: (NSCell*) cell
{
	return [[self selectedCells] indexOfObjectIdenticalTo: cell] != NSNotFound;
}


//----------------------------------------------------------------------------------------

- (id) document
{
//	dprintf("document=%@", [[self window] classDescription]);
	return [(id) [self window] document];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Drag Out (export/checkout)
//----------------------------------------------------------------------------------------

enum { kDragImageSize = 32, kDragImageOffset = kDragImageSize / 2 };
static const NSSize gDragImageSize = { kDragImageSize, kDragImageSize };


- (void) mouseDragged: (NSEvent*) event
{
	if (isSubBrowser)
		return;

	NSRect srcRect = { locationInView(event, self), gDragImageSize };
	srcRect.origin.x -= kDragImageOffset;
	srcRect.origin.y -= kDragImageOffset;

	// dragPromisedFilesOfTypes is meant for Finder. This will in turn call dragImage:at:offset...
	// that we will override below to implement dragging to working copy (svn merge & switch).
	// See http://developer.apple.com/qa/qa2001/qa1300.html

	NSMutableArray* types = [NSMutableArray array];
	for_each_obj(en, it, [self selectedCells])
	{
		[types addObject: [(RepoItem*) [it representedObject] fileType]];
	}

	[self dragPromisedFilesOfTypes: types
						  fromRect: srcRect
							source: self
						 slideBack: YES
							 event: event];
}


//----------------------------------------------------------------------------------------

- (void) dragImage:  (NSImage*)      anImage
		 at:         (NSPoint)       imageLoc
		 offset:     (NSSize)        mouseOffset
		 event:      (NSEvent*)      theEvent
		 pasteboard: (NSPasteboard*) pboard
		 source:     (id)            sourceObject
		 slideBack:  (BOOL)          slideBack
{
	// if we're dragging exactly one cell then implement drag to working copy (svn merge or switch)
	const id cells = [self selectedCells];
	if ([cells count] == 1)
	{
		RepoItem* repoItem = [[cells lastObject] representedObject];
		[pboard addTypes: [NSArray arrayWithObjects: kTypeRepoItem, NSURLPboardType, nil]
				owner:    self];
		[pboard setData: [NSData dataWithBytes: &repoItem length: sizeof(repoItem)]
				forType: kTypeRepoItem];
		[[repoItem url] writeToPasteboard: pboard];

		if ([repoItem isDir])
			anImage = ImageFromIcon([repoItem icon], kDragImageSize);

		sourceObject = self;
	}

	NSImage* image = [[NSImage alloc] initWithSize: gDragImageSize];
	[image lockFocus];
	[anImage dissolveToPoint: NSMakePoint(0, 0) fraction: 0.667];
	[image unlockFocus];

	[super dragImage: image
				  at: imageLoc
			  offset: mouseOffset
			   event: theEvent
		  pasteboard: pboard
			  source: sourceObject
		   slideBack: slideBack];
}


//----------------------------------------------------------------------------------------

- (unsigned int) draggingSourceOperationMaskForLocal: (BOOL) isLocal
{
	#pragma unused(isLocal)
	return isSubBrowser ? NSDragOperationNone : NSDragOperationCopy | NSDragOperationPrivate;
}


#if 0
//----------------------------------------------------------------------------------------
// This does not work even though the following doc claims it should!
// <http://developer.apple.com/documentation/Cocoa/Conceptual/DragandDrop/Tasks/DraggingFiles.html>

- (void) deliverPromise: (NSDictionary*) args
{
	[[self document] deliverFiles: [args objectForKey: @"files"]
					 toFolder:     [args objectForKey: @"url"]
					 isTemporary:  NO];
}
#endif


//----------------------------------------------------------------------------------------

- (NSArray*) namesOfPromisedFilesDroppedAtDestination: (NSURL*) dropDestination
{
	NSArray* const files = [[self selectedCells] valueForKey: @"representedObject"];
#if 1
	// TemporaryItems => drop on docked app, ChewableItems => drop into document window
	const BOOL isTemp = (Folder_IsTemporaryItems(dropDestination) || Folder_IsChewableItems(dropDestination));
	return [[self document] deliverFiles: files toFolder: dropDestination isTemporary: isTemp];
#elif 0
	// This does not work (see deliverPromise: above).
	[self performSelector: @selector(deliverPromise:)
			   withObject: [NSDictionary dictionaryWithObjectsAndKeys: files,           @"files",
																	   dropDestination, @"url", nil]
			   afterDelay: 0.5];
	return [files valueForKey: @"name"];
#endif
}


//----------------------------------------------------------------------------------------

- (void) draggedImage: (NSImage*)        anImage
		 endedAt:      (NSPoint)         aPoint
		 operation:    (NSDragOperation) operation
{
	#pragma unused(anImage, aPoint, operation)
	// Panther bug workaround (http://www.cocoabuilder.com/archive/message/cocoa/2005/1/31/127154
	// and http://www.cocoabuilder.com/archive/message/2004/10/5/118857)
	[[NSPasteboard pasteboardWithName: NSDragPboard] declareTypes: nil owner: nil];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Drag In (import)
//----------------------------------------------------------------------------------------

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>) sender
{
	return (isSubBrowser || [sender draggingSource] == self) ? NSDragOperationNone : NSDragOperationAll;
}


//----------------------------------------------------------------------------------------

- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>) sender
{
	if (isSubBrowser || [sender draggingSource] == self)
		return NSDragOperationNone;

	NSArray* files = [[sender draggingPasteboard] propertyListForType: NSFilenamesPboardType];

	if ([files count] != 1) return NSDragOperationNone;

	int row, column;
	if ([self getRow: &row column: &column forPoint: [self convertPoint: [sender draggingLocation] fromView: nil]])
	{
		NSCell* cell = [self cellAtRow: row column: column];
		RepoItem* obj = [cell representedObject];

		if (![obj isDir])
		{
			shouldDraw = NO;
			newDrawRect = NSZeroRect;
			oldDrawRect = NSZeroRect;
			[self setNeedsDisplay: TRUE];
			return NSDragOperationNone;
		}

		[self setDestinationCell: cell];
		NSRect drawRect = [self cellFrameAtRow: row column: column];

		shouldDraw = TRUE;

		// Don't ask the view to draw it self unless necessary
		if (!NSEqualRects(drawRect, oldDrawRect))
		{
			newDrawRect = drawRect;
			[self setNeedsDisplay: TRUE];
		}

		return NSDragOperationAll;
	}
	else
	{
		shouldDraw = NO;
		[self setNeedsDisplay: TRUE];
		return NSDragOperationNone;
	}
}


//----------------------------------------------------------------------------------------

- (void) draggingExited: (id<NSDraggingInfo>) sender
{
	#pragma unused(sender)
	shouldDraw = NO;
	newDrawRect = NSZeroRect;
	oldDrawRect = NSZeroRect;
	[self setNeedsDisplay: TRUE];
}


//----------------------------------------------------------------------------------------

- (BOOL) performDragOperation: (id<NSDraggingInfo>) sender
{
	if (isSubBrowser)
		return NO;

	shouldDraw = NO;
	newDrawRect = NSZeroRect;
	oldDrawRect = NSZeroRect;
	[self setNeedsDisplay: TRUE];

	[[self document] receiveFiles:   [[sender draggingPasteboard] propertyListForType: NSFilenamesPboardType]
					 toRepositoryAt: [[self destinationCell] representedObject]];

	return YES;
}


//----------------------------------------------------------------------------------------

- (void) drawRect: (NSRect) rect
{
	[super drawRect: rect];

	if (shouldDraw)		// Draw drag tracking feedback
	{
		shouldDraw = TRUE;
		[[NSColor blackColor] setStroke];
	//	[[NSColor selectedControlColor] setStroke];
		[NSBezierPath strokeRect: newDrawRect];

		oldDrawRect = newDrawRect;
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Accessors
//----------------------------------------------------------------------------------------

- (NSCell*) destinationCell { return destinationCell; }


//----------------------------------------------------------------------------------------

- (void) setDestinationCell: (NSCell*) aDestinationCell
{
	id old = destinationCell;
	destinationCell = [aDestinationCell retain];
	[old release];
}


@end	// MyDragSupportMatrix

//----------------------------------------------------------------------------------------
// End of MyDragSupportMatrix.m
