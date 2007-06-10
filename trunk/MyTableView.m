#import "MyTableView.h"

@implementation MyTableView

// It's mandatory to subclass MyTableView to implement this method.

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return  NSDragOperationCopy | NSDragOperationMove ;
}

- (void)awakeFromNib
{
	[self setDoubleAction:@selector(onDoubleClick:)];	
}

- (void)onDoubleClick:(id)sender
{
	[[[[self delegate] document] controller] doubleClickInTableView:sender];

}

@end
