#import "MyDragSupportWindow.h"
#import "MyWorkingCopy.h"
#import "MyWorkingCopyController.h"

NSString* const kTypeRepositoryPathAndRevision = @"REPOSITORY_PATH_AND_REVISION_TYPE";

@implementation MyDragSupportWindow

-(void)awakeFromNib
{
     [self registerForDraggedTypes:[NSArray arrayWithObjects: kTypeRepositoryPathAndRevision, nil]];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	return NSDragOperationLink;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];

	NSDictionary *fileObj = [NSUnarchiver unarchiveObjectWithData:[pboard dataForType: kTypeRepositoryPathAndRevision]];

	[[[(id) self document] controller] requestSwitchToRepositoryPath:fileObj];
	
	return YES;
}


@end
