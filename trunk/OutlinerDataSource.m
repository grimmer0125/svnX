#import "OutlinerDataSource.h"

@implementation OutlinerDataSource

// Data Source methods

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    return (item == nil) ? 1 : [[item objectForKey:@"children"] count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return ([self outlineView:outlineView numberOfChildrenOfItem:item] > 0 ) ? YES : NO;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item {
	if ( item == nil ) return [document svnDirectories];
	else
	{
		NSMutableArray *dirsArray = [item objectForKey:@"children"];

		[dirsArray sortUsingDescriptors:[NSArray arrayWithObject: [[[NSSortDescriptor alloc] 
                                                 initWithKey:@"name" ascending:YES] autorelease]]];

		return [dirsArray objectAtIndex:index];
	}
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    return (item == nil) ? @"/" : (id)[item objectForKey:@"name"];
}

// Delegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    return NO;
}
- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	NSOutlineView *ov = [notification object];
	
//	NSLog(@"Outliner click : %@", [[ov itemAtRow:[ov selectedRow]] objectForKey:@"path"]);
	[document setOutlineSelectedPath:[[ov itemAtRow:[ov selectedRow]] objectForKey:@"path"]];
}
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	[cell setImage:[item objectForKey:@"icon"]];
}


// Dragging

- (unsigned int)outlineView:(NSOutlineView*)olv validateDrop:(id <NSDraggingInfo>)sender proposedItem:(id)item proposedChildIndex:(int)childIndex
{
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	if ( childIndex != -1) return NO; // childIndex = -1 : inside the folder
	
	// we want to return the correct mask in order to let the system show the appropriate "drag icon"
	
	if (sourceDragMask & NSDragOperationMove)
	{
		return NSDragOperationMove;
    }
	if (sourceDragMask & NSDragOperationCopy)
	{
		return NSDragOperationCopy;
    }
}
- (BOOL)outlineView:(NSOutlineView*)olv acceptDrop:(id <NSDraggingInfo>)sender item:(id)targetItem childIndex:(int)childIndex
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask & NSDragOperationMove)
	{
		//NSLog(@"move to : %@", [[document workingCopyPath] stringByAppendingPathComponent:[targetItem objectForKey:@"dirPath"]]);
		[controller requestSvnMoveSelectedItemsToDestination:[[document workingCopyPath] stringByAppendingPathComponent:[targetItem objectForKey:@"path"]]];
    } else
	if (sourceDragMask & NSDragOperationCopy)
	{
		//NSLog(@"copy to : %@", [[document workingCopyPath] stringByAppendingPathComponent:[targetItem objectForKey:@"dirPath"]]);
		[controller requestSvnCopySelectedItemsToDestination:[[document workingCopyPath] stringByAppendingPathComponent:[targetItem objectForKey:@"path"]]];
    }
	
    return YES;
}
@end

