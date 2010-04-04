#import "MyTableView.h"
#import "MyWorkingCopy.h"
#import "MyWorkingCopyController.h"
#import "TableViewDelegate.h"
#import "IconTextCell.h"
#import "IconUtils.h"


@implementation MyTableView

// It's mandatory to subclass MyTableView to implement this method.

- (unsigned int) draggingSourceOperationMaskForLocal: (BOOL) isLocal
{
	#pragma unused(isLocal)
	return  NSDragOperationCopy | NSDragOperationMove;
}


- (void) awakeFromNib
{
#if 1
	NSTableColumn* const col = [self tableColumnWithIdentifier: @"path"];
	IconTextCell* const cell = [IconTextCell new];
	[cell setFont: [NSFont labelFontOfSize: 11]];
	[cell setIconRef: GenericFileIcon()];
	[col setDataCell: cell];
	[cell release];
	[self removeTableColumn: [self tableColumnWithIdentifier: @"icon"]];
	[col unbind: NSValueBinding];
#endif
	[self setDoubleAction: @selector(onDoubleClick:)];
}


- (void) onDoubleClick: (id) sender
{
	[[[[self delegate] document] controller] doubleClickInTableView: sender];
}


//----------------------------------------------------------------------------------------
// Subvert the 10.5 behaviour (which eats SOME of these events)

- (void) keyDown: (NSEvent*) theEvent
{
//	dprintf("keyCode=0x%X", [theEvent keyCode]);
	switch ([theEvent keyCode])
	{
		case 0x73:	// Home
			[self scrollRowToVisible: 0];
			break;
		case 0x77:	// End
			[self scrollRowToVisible: [self numberOfRows] - 1];
			break;
		case 0x74:	// Page Up
		case 0x79:	// Page Down
		case 0x7E:	// Up
		case 0x7D:	// Down
			[super keyDown: theEvent];
			break;

		default:
			[[self nextResponder] keyDown: theEvent];
			break;
	}
}

@end	// MyTableView

