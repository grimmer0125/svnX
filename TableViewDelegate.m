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

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation
{
	//[super tableView:aTableView toolTipForCell:aCell rect:rect tableColumn:aTableColumn row:row mouseLocation:mouseLocation];
	NSDictionary *rowDict = [[svnFilesAC arrangedObjects] objectAtIndex:row];
	NSDictionary *comments;
	
	switch ( [[aTableColumn identifier] intValue] )
	{
		case 1:
			
			comments = [NSDictionary dictionaryWithObjectsAndKeys:
			@"No modifications.", @" ", 
			@"Item is scheduled for Addition.", @"A", 
			@"Item is scheduled for Deletion.", @"D", 
			@"Item has been modified.", @"M", 
			@"Item has been replaced in your working copy. This means the file was scheduled for deletion, and then a new file with the same name was scheduled for addition in its place.", @"R", 
			@"The contents (as opposed to the properties) of the item conflict with updates received from the repository.", @"C", 
			@"Item is related to an externals definition.", @"X", 
			@"Item is being ignored (e.g. with the svn:ignore property).", @"I", 
			@"Item is not under version control.", @"?", 
			@"Item is missing (e.g. you moved or deleted it without using svn). This also indicates that a directory is incomplete (a checkout or update was interrupted).", @"!", 
			@"Item is versioned as one kind of object (file, directory, link), but has been replaced by different kind of object.", @"~", 
			nil];
			return [comments objectForKey:[rowDict objectForKey:@"col1"]];
			
		break;

		case 2:
			
			comments = [NSDictionary dictionaryWithObjectsAndKeys:
			@"No properties modifications.", @" ", 
			@"Properties for this item have been modified.", @"M",
			@"Properties for this item are in conflict with property updates received from the repository.", @"C",
			nil];
			return [comments objectForKey:[rowDict objectForKey:@"col2"]];
			
		break;

		case 3:
			
			comments = [NSDictionary dictionaryWithObjectsAndKeys:
			@"Item is not locked.", @" ", 
			@"Item is locked. (You may want to run svn clean up!)", @"L",
			nil];
			return [comments objectForKey:[rowDict objectForKey:@"col3"]];
			
		break;

		case 4:
			
			comments = [NSDictionary dictionaryWithObjectsAndKeys:
			@"No history scheduled with commit.", @" ", 
			@"History scheduled with commit.", @"+",
			nil];
			return [comments objectForKey:[rowDict objectForKey:@"col4"]];
			
		break;

		case 5:
			
			comments = [NSDictionary dictionaryWithObjectsAndKeys:
			@"Item is a child of its parent directory.", @" ", 
			@"Item is switched.", @"S",
			nil];
			return [comments objectForKey:[rowDict objectForKey:@"col5"]];
			
		break;

		case 6:
			
			comments = [NSDictionary dictionaryWithObjectsAndKeys:
			@"File is not locked in this working copy.", @" ", 
			@"File is locked in this working copy.", @"K",
			@"File is locked either by another user or in another working copy.", @"O",
			@"File was locked in this working copy, but the lock has been “stolen” and is invalid. The file is currently locked in the repository.", @"T",
			@"File was locked in this working copy, but the lock has been “broken” and is invalid. The file is no longer locked.", @"B",
			nil];
			return [comments objectForKey:[rowDict objectForKey:@"col6"]];
			
		break;

		case 7:
			
			comments = [NSDictionary dictionaryWithObjectsAndKeys:
			@"Item is up-to-date.", @"*",
			@"A newer revision of the item exists on the server.", @"*",
			nil];
			return [comments objectForKey:[rowDict objectForKey:@"col7"]];
			
		break;

		case 8:
			
			comments = [NSDictionary dictionaryWithObjectsAndKeys:
			@"File has properties", @"P",
			@"File doesn't have any property", @" ",
			nil];
			return [comments objectForKey:[rowDict objectForKey:@"col8"]];
			
		break;
	}
	return @"";
}

-(id)document
{
	return document;
}


@end
