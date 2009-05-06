//
// MySvnFilesArrayController.m
//

#import "MySvnFilesArrayController.h"
#import "MyWorkingCopy.h"


//----------------------------------------------------------------------------------------

@implementation MySvnFilesArrayController

- (void) search: (id) sender
{
	[self setSearchString:[sender stringValue]];
	[self rearrangeObjects];    
}


- (NSArray*) arrangeObjects: (NSArray*) objects
{
    NSMutableArray* matchedObjects = [NSMutableArray arrayWithCapacity: [objects count]];

	const int filter = [document filterMode];
	const BOOL treeMode = ![document flatMode];
	NSString* const	selectedPath = [document outlineSelectedPath];
    NSString* const lowerSearch = (searchString != nil && [searchString length] > 0) ? [searchString lowercaseString] : nil;
	BOOL isCommittable = NO;

	NSEnumerator* oEnum;
	id item;
	for (oEnum = [objects objectEnumerator]; item = [oEnum nextObject]; )
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		BOOL test = TRUE;

		if (filter != kFilterAll)
		{
			const unichar c1 = [[item objectForKey: @"col1"] characterAtIndex: 0],
						  c2 = [[item objectForKey: @"col2"] characterAtIndex: 0];

			switch (filter)
			{
				case kFilterModified:
					test = (c1 == 'M' || c2 == 'M');
					break;

				case kFilterNew:
					test = (c1 == '?');
					break;

				case kFilterMissing:
					test = (c1 == '!');
					break;

				case kFilterConflict:
					test = (c1 == 'C' || c2 == 'C');
					break;

				case kFilterChanged:	// Modified, added, deleted, replaced, conflict, missing, wrong kind
					test = (c1 == 'M' || c1 == 'A' || c1 == 'D' || c1 == 'R' || c1 == 'C' || c1 == '!' || c1 == '~');
					if (!test)
						test = (c2 == 'M' || c2 == 'C');		// Modified or conflict property
					break;
			}
		}

		NSString* path = nil;
		if (test && treeMode)
		{
			test = [[item objectForKey: @"dirPath"] isEqualToString: selectedPath] &&
					![(path = [item objectForKey: @"path"]) isEqualToString: selectedPath];
		}

		if (test && lowerSearch)
		{
			if (path == nil)
				path = [item objectForKey: @"path"];
			test = ([[path lowercaseString] rangeOfString: lowerSearch].location != NSNotFound);
		}

		if (test)
			[matchedObjects addObject: item];
		if (!isCommittable)
			isCommittable = [[item objectForKey: @"committable"] boolValue];

		[pool release];
	}

	[self setCommittable: isCommittable];

	return [super arrangeObjects: matchedObjects];
}


//  - dealloc:
- (void) dealloc
{
	[self setSearchString: nil];    
	[super dealloc];
}


// - searchString:
- (NSString*) searchString
{
	return searchString;
}

// - setSearchString:
- (void) setSearchString: (NSString*) newSearchString
{
	if (searchString != newSearchString)
	{
		[searchString autorelease];
		searchString = [newSearchString copy];
	}
}


//----------------------------------------------------------------------------------------

- (BOOL) committable
{
	return committable;
}


//----------------------------------------------------------------------------------------

- (void) setCommittable: (BOOL) isCommittable
{
	committable = isCommittable;
}

@end

