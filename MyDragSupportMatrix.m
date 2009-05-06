//
// MyDragSupportMatrix.m - Repository NSMatrix subclass
//

#import "MyDragSupportMatrix.h"
#import "MyDragSupportWindow.h"
#import "MyRepository.h"
#import "MySvnRepositoryBrowserView.h"
#import "ViewUtils.h"


extern NSImage* GenericFolderImage32 (void);


//----------------------------------------------------------------------------------------

@implementation MyDragSupportMatrix

// Special init would be done here:

- (id) initWithFrame:   (NSRect)  frameRect
	   mode:            (int)     aMode
	   prototype:       (NSCell*) aCell
	   numberOfRows:    (int)     numRows
	   numberOfColumns: (int)     numColumns
{
	if (self = [super initWithFrame: frameRect
							   mode: aMode
						  prototype: aCell
					   numberOfRows: numRows
					numberOfColumns: numColumns])
	{
		// register for files dragged to the repository (-> svn import)
		[self registerForDraggedTypes: [NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	}
	
	return self;
}


- (id) initWithCoder: (NSCoder*) decoder
{
	if (self = [super initWithCoder:decoder])
	{
		[self registerForDraggedTypes: [NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	}
	return self;
}


//  - dealloc:
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
#pragma mark	-
#pragma mark	Drag Out (export/checkout)

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>) sender
{
	return (isSubBrowser || [sender draggingSource] == self) ? NSDragOperationNone : NSDragOperationAll;
}


- (void) mouseDown: (NSEvent*) event
{
	// need to override this because NSMatrix eats drag events
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


- (BOOL) isCellSelected: (NSCell*) cell
{
	return [[self selectedCells] indexOfObjectIdenticalTo: cell] != NSNotFound;
}


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

	// dragPromisedFilesOfTypes is meant for Finder. This will in turn call dragImage:at:offset... that we will override
	// below to implement dragging to working copy (svn switch). See http://developer.apple.com/qa/qa2001/qa1300.html

	NSArray* types = [[self selectedCells] valueForKeyPath: @"representedObject.fileType"];	// key/value coding magic!
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
		id fileObj = [[cells lastObject] representedObject];
		[pboard addTypes: [NSArray arrayWithObjects: kTypeRepositoryPathAndRevision, NSURLPboardType, nil]
				owner:    self];
		[pboard setData: [NSArchiver archivedDataWithRootObject: fileObj]
				forType: kTypeRepositoryPathAndRevision];
		[[fileObj objectForKey: @"url"] writeToPasteboard: pboard];

		if ([[fileObj objectForKey: @"isRoot"] boolValue])
			anImage = [NSImage imageNamed: @"Repository"];
		else if ([[fileObj objectForKey: @"isDir"] boolValue])
			anImage = GenericFolderImage32();

		sourceObject = self;
	}

	[anImage setSize: gDragImageSize];
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


//----------------------------------------------------------------------------------------

- (id) document
{
//	NSLog(@"MyDragSupportMatrix document=%@", [[self window] classDescription]);
	return [(id) [self window] document];
}


//----------------------------------------------------------------------------------------

- (NSArray*) namesOfPromisedFilesDroppedAtDestination: (NSURL*) dropDestination
{
	[[self document]
			dragOutFilesFromRepository: [[self selectedCells] valueForKey:@"representedObject"]
			toURL: dropDestination];
	
	return NULL; // we're just interested in the dropDestination.
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
		NSDictionary* obj = [cell representedObject];

		if (![[obj objectForKey: @"isDir"] boolValue])
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


- (void) draggingExited: (id<NSDraggingInfo>) sender
{
	#pragma unused(sender)
	shouldDraw = NO;
	newDrawRect = NSZeroRect;
	oldDrawRect = NSZeroRect;
	[self setNeedsDisplay: TRUE];
}


- (BOOL) performDragOperation: (id<NSDraggingInfo>) sender
{
	if (isSubBrowser)
		return NO;

	shouldDraw = NO;
	newDrawRect = NSZeroRect;
	oldDrawRect = NSZeroRect;
	[self setNeedsDisplay: TRUE];

	NSPasteboard* pboard = [sender draggingPasteboard];
	NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

	[[self document] dragExternalFiles:files ToRepositoryAt:[[self destinationCell] representedObject]];

	return YES;
}


- (void) drawRect: (NSRect) rect
{
	[super drawRect: rect];

	if (shouldDraw)
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

- (NSCell*) destinationCell { return destinationCell; }

- (void) setDestinationCell: (NSCell*) aDestinationCell
{
	id old = destinationCell;
	destinationCell = [aDestinationCell retain];
	[old release];
}


@end

