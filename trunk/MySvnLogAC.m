#import "MySvnLogAC.h"

@implementation MySvnLogAC

- (void)search:(id)sender
{
    [self setSearchString:[sender stringValue]];
    [self rearrangeObjects];    
}

- (void)rearrange:(id)sender
{
    [self rearrangeObjects];    
}

- (NSArray *)arrangeObjects:(NSArray *)objects
{
    NSMutableArray *matchedObjects = [NSMutableArray arrayWithCapacity:[objects count]];
    NSString *lowerSearch = [searchString lowercaseString];
    BOOL shouldSearchPathsOrMessages = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"shouldSearchPathsOrMessages"] boolValue];

	NSEnumerator *oEnum = [objects objectEnumerator];
    id item;
	
	if ((searchString != nil) && (![searchString isEqualToString:@""]))
	{
		while (item = [oEnum nextObject])
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			NSString *lowerName = [[item valueForKeyPath:@"msg"] lowercaseString];
			BOOL test = TRUE;
			
			
			if ( shouldSearchPathsOrMessages && [item valueForKeyPath:@"paths"] != NULL )
			{
				BOOL testPath = FALSE;
				id pathDict;
				NSEnumerator *pEnum = [[item valueForKeyPath:@"paths"] objectEnumerator];
				
				while (pathDict = [pEnum nextObject])
				{
					NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];

					if ([[[pathDict valueForKeyPath:@"path"] lowercaseString] rangeOfString:lowerSearch].location != NSNotFound)
					{
						testPath = testPath || TRUE;
					}
					
					if ( [pathDict valueForKeyPath:@"copyfrompath"] != NULL )
					if ([[[pathDict valueForKeyPath:@"copyfrompath"] lowercaseString] rangeOfString:lowerSearch].location != NSNotFound)
					{
						testPath = testPath || TRUE;
					}

					[pool2 release];
				}
			
				test = testPath;
				
			} else
			{
					if ([lowerName rangeOfString:lowerSearch].location == NSNotFound)
					{
						test = FALSE;
					}

			}
					
			if ( test ) [matchedObjects addObject:item];
			
			[pool release];
		
		}

	    return [super arrangeObjects:matchedObjects];
		
	} else
	{
		return [super arrangeObjects:objects];
	}
}


//  - dealloc:
- (void)dealloc
{
    [self setSearchString: nil];    
    [super dealloc];
}


// - searchString:
- (NSString *)searchString
{
	return searchString;
}
// - setSearchString:
- (void)setSearchString:(NSString *)newSearchString
{
    if (searchString != newSearchString)
	{
        [searchString autorelease];
        searchString = [newSearchString copy];
    }
}


@end
