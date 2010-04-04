#import "OutlinerDataSource.h"
#import "MyWorkingCopy.h"
#import "MyWorkingCopyController.h"


@implementation OutlinerDataSource

//----------------------------------------------------------------------------------------
// Data Source methods

- (int) outlineView:            (NSOutlineView*) outlineView
		numberOfChildrenOfItem: (id)             item
{
	#pragma unused(outlineView)
	return (item == nil) ? 1 : [item childCount];
}


- (BOOL) outlineView:      (NSOutlineView*) outlineView
		 isItemExpandable: (id)             item
{
	#pragma unused(outlineView)
	return (item == nil) || [item childCount] > 0;
}


- (id) outlineView: (NSOutlineView*) outlineView
	   child:       (int)            index
	   ofItem:      (WCTreeEntry*)   item
{
	#pragma unused(outlineView)
	return (item == nil) ? [document svnDirectories] : [item childAtIndex: index];
}


- (id) outlineView:               (NSOutlineView*) outlineView
	   objectValueForTableColumn: (NSTableColumn*) tableColumn
	   byItem:                    (id)             item
{
	#pragma unused(outlineView, tableColumn)
	return (item == nil) ? @"/" : [item name];
}


//----------------------------------------------------------------------------------------
// Delegate methods

- (BOOL) outlineView:           (NSOutlineView*) outlineView
		 shouldEditTableColumn: (NSTableColumn*) tableColumn
		 item:                  (id)             item
{
	#pragma unused(outlineView, tableColumn, item)
	return NO;
}


//----------------------------------------------------------------------------------------

- (void) outlineViewSelectionDidChange: (NSNotification*) notification
{
	NSOutlineView* const ov = [notification object];

//	NSLog(@"Outliner click : %@", [[ov itemAtRow: [ov selectedRow]] path]);
	[document setOutlineSelectedPath: [[ov itemAtRow: [ov selectedRow]] path]];
}


//----------------------------------------------------------------------------------------

- (void) outlineView:     (NSOutlineView*) outlineView
		 willDisplayCell: (id)             cell
		 forTableColumn:  (NSTableColumn*) tableColumn
		 item:            (id)             item
{
	#pragma unused(outlineView, tableColumn)

	[cell setImage: [item icon: document]];
}


//----------------------------------------------------------------------------------------
// Dragging

- (NSDragOperation) outlineView:        (NSOutlineView*)     outlineView
					validateDrop:       (id<NSDraggingInfo>) sender
					proposedItem:       (id)                 item
					proposedChildIndex: (int)                childIndex
{
	#pragma unused(outlineView, item)
	if (childIndex != -1 || [sender draggingSource] != [controller valueForKey: @"tableResult"])
		return NSDragOperationNone;		// childIndex = -1 : inside the folder

	// we want to return the correct mask in order to let the system show the appropriate "drag icon"
	NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask & NSDragOperationMove)
		return NSDragOperationMove;

	if (sourceDragMask & NSDragOperationCopy)
		return NSDragOperationCopy;

	// default
	return NSDragOperationNone;
}


//----------------------------------------------------------------------------------------

- (BOOL) outlineView: (NSOutlineView*)     outlineView
		 acceptDrop:  (id<NSDraggingInfo>) sender
		 item:        (id)                 targetItem
		 childIndex:  (int)                childIndex
{
	#pragma unused(outlineView, childIndex)
//	NSPasteboard* pboard = [sender draggingPasteboard];
	NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	NSString* fullPath = [[document workingCopyPath] stringByAppendingPathComponent: [targetItem path]];

	if (sourceDragMask & NSDragOperationMove)
	{
		//NSLog(@"move to : %@", fullPath);
		[controller requestSvnMoveSelectedItemsToDestination: fullPath];
	}
	else if (sourceDragMask & NSDragOperationCopy)
	{
		//NSLog(@"copy to : %@", fullPath);
		[controller requestSvnCopySelectedItemsToDestination: fullPath];
	}

	return YES;
}

@end

