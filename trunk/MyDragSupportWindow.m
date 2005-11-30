#import "MyDragSupportWindow.h"

@implementation MyDragSupportWindow

-(void)awakeFromNib
{
     [self registerForDraggedTypes:[NSArray arrayWithObjects:@"REPOSITORY_PATH_AND_REVISION_TYPE", nil]];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	return NSDragOperationLink;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];

	NSDictionary *fileObj = [NSUnarchiver unarchiveObjectWithData:[pboard dataForType:@"REPOSITORY_PATH_AND_REVISION_TYPE"]];

	[[[self document] controller] requestSwitchToRepositoryPath:fileObj];
	
	return YES;
}


@end
