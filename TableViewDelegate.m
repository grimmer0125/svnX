#import "TableViewDelegate.h"

@implementation TableViewDelegate

- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard 
{
	NSArray *selectedObjects = [svnFilesAC selectedObjects];
	NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[selectedObjects count]];
	NSEnumerator *en = [rows objectEnumerator];
	NSEnumerator *pathsEnumerator = [selectedObjects objectEnumerator];
	id object;

	while ( object = [pathsEnumerator nextObject] )
	{
		[filePaths addObject:[object objectForKey:@"fullPath"]];
	}
	
	// Dragging only works in non flatMode :
	
	if ([document flatMode] == true )
	{
		[pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
	
	} else
	{
		[pboard declareTypes:[NSArray arrayWithObjects:@"svnX", NSFilenamesPboardType, nil] owner:nil];

		// Let's prevent the user from dragging non selected items
		//
		while ( object = [en nextObject] )
		{
			if ( ![tableView isRowSelected:[object intValue]] ) return FALSE;
		}
	}

    [pboard setPropertyList:filePaths forType:NSFilenamesPboardType];
	
	return YES;

}
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	[[document controller] requestSvnRenameSelectedItemTo:[ [[document workingCopyPath] stringByAppendingPathComponent:[document outlineSelectedPath]]
								stringByAppendingPathComponent:[fieldEditor string]]];
	return FALSE;
}


-(id)document
{
	return document;
}


@end
