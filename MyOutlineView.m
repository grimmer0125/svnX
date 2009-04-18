#import "MyOutlineView.h"
#import "ImageAndTextCell.h"

@implementation MyOutlineView

- (void) awakeFromNib
{
	ImageAndTextCell* cell = [[ImageAndTextCell alloc] init];
	[cell setFont: [NSFont labelFontOfSize: 0]];
	[cell setWraps: NO];
	[cell setEditable: NO];
	[[self tableColumnWithIdentifier: @"folders"] setDataCell: cell];
	[cell release];

	[self setIndentationPerLevel: 10];
	// register outliner for dragging
	[self registerForDraggedTypes: [NSArray arrayWithObject: @"svnX"]];
}


//----------------------------------------------------------------------------------------

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>) sender
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


@end
