#import "MyOutlineView.h"
#import "ImageAndTextCell.h"

@implementation MyOutlineView

- (void)awakeFromNib
{
    NSTableColumn *tableColumn = nil;
    ImageAndTextCell *imageAndTextCell = nil;

    tableColumn = [self tableColumnWithIdentifier:@"folders"];
    imageAndTextCell = [[ImageAndTextCell alloc] init];
    [imageAndTextCell setEditable: NO];
    [tableColumn setDataCell:imageAndTextCell];
	[imageAndTextCell release];
	// register outliner for dragging
	[self registerForDraggedTypes:[NSArray arrayWithObjects:@"svnX", nil]];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
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
}


@end
