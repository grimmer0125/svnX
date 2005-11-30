#import "MyDragSupportTableView.h"

@implementation MyDragSupportTableView

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return  NSDragOperationCopy | NSDragOperationMove ;
}

@end
