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
	
//	[[self tableColumnWithIdentifier:@"6"] setResizable:NO];
//	[[self tableColumnWithIdentifier:@"path"] setMinWidth:(float)0];
	[[self tableColumnWithIdentifier:@"path"] setWidth:(float)10000];
}

- (void)onDoubleClick:(id)sender
{
	[[[[self delegate] document] controller] doubleClickInTableView:sender];

}

@end
