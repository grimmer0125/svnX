#import "MyOutlineView.h"
#import "IconTextCell.h"
#import "IconUtils.h"

@implementation MyOutlineView

- (BOOL) inLiveResize { return NO; }


//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
	IconTextCell* const cell = [MiniIconTextCell new];
	[cell setFont: [NSFont labelFontOfSize: 0]];
	[cell setWraps: NO];
	[cell setEditable: NO];
	[cell setIconRef: GenericFolderIcon()];
	[[self tableColumnWithIdentifier: @"folders"] setDataCell: cell];
	[cell release];

	[self setIndentationPerLevel: 10];
	[self setAutoresizesOutlineColumn: NO];
	[self setBackgroundColor: [[NSColor controlAlternatingRowBackgroundColors] lastObject]];

	// register outliner for dragging
	[self registerForDraggedTypes: [NSArray arrayWithObject: @"svnX"]];
}


//----------------------------------------------------------------------------------------

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>) sender
{
	NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask & NSDragOperationMove)
	{
		return NSDragOperationMove;
	}
	if (sourceDragMask & NSDragOperationCopy)
	{
		return NSDragOperationCopy;
	}
	// default
	return NSDragOperationNone;
}


@end	// MyOutlineView

