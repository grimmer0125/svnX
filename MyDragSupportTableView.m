#import "MyDragSupportTableView.h"

@implementation MyDragSupportTableView

- (unsigned int) draggingSourceOperationMaskForLocal: (BOOL) isLocal
{
	#pragma unused(isLocal)
	return  NSDragOperationCopy | NSDragOperationMove;
}

@end

