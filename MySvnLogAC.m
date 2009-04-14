#import "MySvnLogAC.h"
#include "CommonUtils.h"


@implementation MySvnLogAC

- (void) search: (id) sender
{
	enum {
		vSearchMsgs		=	404,
		vSearchPaths	=	405
	};

	NSString** searchString = ([sender tag] == vSearchPaths) ? &searchPaths : &searchMessages;
	NSString* newSearchString = [sender stringValue];
//	if (!*searchString != newSearchString)
	if (![*searchString isEqualToString: newSearchString])
	{
		[*searchString autorelease];
		*searchString = [newSearchString length] ? [newSearchString copy] : nil;

		[self rearrangeObjects];
	}
}


- (void) rearrange: (id) sender
{
	[self rearrangeObjects];
}


- (void) clearSearchPaths
{
	[searchPaths autorelease];
	searchPaths = nil;
	[self rearrangeObjects];
}


- (NSArray*) arrangeObjects: (NSArray*) objects
{
	if (searchMessages || searchPaths)
	{
		NSString* const lowerSearchMsgs  = [searchMessages lowercaseString];
		NSString* const lowerSearchPaths = [searchPaths lowercaseString];
		NSMutableArray* const matchedObjects = [NSMutableArray arrayWithCapacity: [objects count]];

		NSEnumerator* oEnum = [objects objectEnumerator];
		id item;
		while (item = [oEnum nextObject])
		{
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			BOOL test = TRUE;

			if (lowerSearchMsgs)
			{
				NSString* text = [item objectForKey: @"msg"];
				test = ([[text lowercaseString] rangeOfString: lowerSearchMsgs].location != NSNotFound);
			}

			if (test && lowerSearchPaths)
			{
				test = FALSE;
				NSArray* paths = [item objectForKey: @"paths"];
				if (paths != nil)
				{
					id pathDict;
					NSEnumerator* pEnum = [paths objectEnumerator];

					while (pathDict = [pEnum nextObject])
					{
				//		NSAutoreleasePool* pool2 = [[NSAutoreleasePool alloc] init];

						NSString* text = [pathDict objectForKey: @"path"];
						if (text != nil && [[text lowercaseString]
													rangeOfString: lowerSearchPaths].location != NSNotFound)
						{
							test = TRUE;
							break;
						}

						text = [pathDict objectForKey: @"copyfrompath"];
						if (text != nil && [[text lowercaseString]
													rangeOfString: lowerSearchPaths].location != NSNotFound)
						{
							test = TRUE;
							break;
						}

				//		[pool2 release];
					}
				}
			}

			if (test)
				[matchedObjects addObject: item];

			[pool release];
		}

		objects = matchedObjects;
	}

	return [super arrangeObjects: objects];
}


// - dealloc:
- (void) dealloc
{
	[searchMessages autorelease];
	[searchPaths autorelease];

	[super dealloc];
}


@end

