#import "MySvnFilesArrayController.h"

@implementation MySvnFilesArrayController

- (void)search:(id)sender
{
    [self setSearchString:[sender stringValue]];
    [self rearrangeObjects];    
}


- (NSArray *)arrangeObjects:(NSArray *)objects
{
    NSMutableArray *matchedObjects = [NSMutableArray arrayWithCapacity:[objects count]];
    NSString *lowerSearch = [searchString lowercaseString];
    
	NSEnumerator *oEnum = [objects objectEnumerator];
    id item;
	
    while (item = [oEnum nextObject])
	{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			NSString *lowerName = [[item valueForKeyPath:@"path"] lowercaseString];
			BOOL test = FALSE;

			if ( [document filterMode] == 1 && ( ![[item valueForKeyPath:@"col1"] isEqualToString:@"M"] ) )
			{
				test = FALSE;
			
			} else
			
			if ( [document filterMode] == 2 && ( ![[item valueForKeyPath:@"col1"] isEqualToString:@"?"] ) )
			{
				test = FALSE;
			
			} else
			
			if ( [document filterMode] == 3 && ( ![[item valueForKeyPath:@"col1"] isEqualToString:@"!"] ) )
			{
				test = FALSE;
			
			} else
			if ( [document flatMode] == YES )
			{
				test = TRUE;
			
			} else
			{
				if ( [[item valueForKeyPath:@"dirPath"] isEqualToString:[document outlineSelectedPath]] && ![[item valueForKeyPath:@"path"] isEqualToString:[document outlineSelectedPath]] )
				{
					test = TRUE;
				}
			}
			
		    if ((searchString != nil) && (![searchString isEqualToString:@""]))
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
