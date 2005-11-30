#import "MySvnRepositoryBrowserView.h"

@implementation MySvnRepositoryBrowserView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		if ([NSBundle loadNibNamed:@"MySvnRepositoryBrowserView" owner:self])
		{
		  [_view setFrame:[self bounds]];
		  [self addSubview:_view];
		}
	}
	return self;
}

- (void)dealloc
{
//	NSLog(@"dealloc repository browser view");
    [self setBrowserPath: nil];

    [super dealloc];
}

- (void)unload
{
	// the nib is responsible for releasing its top-level objects
//	[_view release];	// this is done by super

	// these objects are bound to the file owner and retain it
	// we need to unbind them 
	[revisionTextField unbind:@"value"];
	[super unload];
}

#pragma mark -
#pragma mark public methods

-(NSMutableArray *)selectedItems
/* Returns a array of the selected represented objects */
{
	NSEnumerator *en = [[browser selectedCells] objectEnumerator];
	NSCell *cell;
	NSMutableArray *arr = [NSMutableArray array];
	
	while ( cell = [en nextObject] )
	{
		[arr addObject:[cell representedObject]];
	}
	
	return arr;
}

- (void)setAllowsEmptySelection:(BOOL)flag
{
	[browser setAllowsEmptySelection:flag];
}

- (void)setAllowsMultipleSelection:(BOOL)flag
{
	[browser setAllowsMultipleSelection:flag];
}

- (void)reset
{
	[self setBrowserPath:nil];
	[browser setPath:@"/"];
}

#pragma mark -
#pragma mark Browser delegate methods

- (void)browser:(NSBrowser *)sender createRowsForColumn:(int)column inMatrix:(NSMatrix *)matrix
{
	if ( [self revision] == nil ) return; 

	if ( [matrix numberOfRows] != 0 )
	{
	} else
	if ( [self showRoot] )
	{
		if ( column == 0 )
		{
			NSBrowserCell *cell = [[NSBrowserCell alloc] initTextCell:@"root"];

			NSFont *txtFont = [NSFont fontWithName:@"Lucida Grande" size:10];
			NSDictionary *txtDict = [NSDictionary dictionaryWithObjectsAndKeys:txtFont, NSFontAttributeName, [NSNumber numberWithFloat:0.4], NSObliquenessAttributeName, nil];
			NSAttributedString *attrStr = [[[NSAttributedString alloc] initWithString:@"root" attributes:txtDict] autorelease];
			[cell setAttributedStringValue:attrStr];

			[self setIsFetching:NO];

			[cell setLeaf:NO];
			
			NSURL *url= [self url];

			[cell setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:
																[NSNumber numberWithBool:YES], @"isRoot",
																@"root", @"name",
																@"", @"path",
																url, @"url",
																[self revision], @"revision",
																NSFileTypeDirectory, @"fileType",
																[NSNumber numberWithBool:YES], @"isDir",
																nil]];
																
			[matrix addRowWithCells:[NSArray arrayWithObject:cell]];
			[matrix putCell:cell atRow:0 column:0];
			[cell setLoaded:NO]; // because we want browser:willDisplayCell... to be called
			[cell release];
			[matrix sizeToCells];
			[matrix display];
		} 
		else
			[self fetchSvnListForUrl:[sender path] column:column matrix:matrix];
	}
	else
		[self fetchSvnListForUrl:[sender path] column:column matrix:matrix];
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column
{
	// this delegate method gives us a chance to antialias the icon
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	NSImage *icon = [cell image];
	[icon setSize:NSMakeSize(13, 13)];
	[cell setImage:icon];

}


#pragma mark -
#pragma mark svn related methods


- (void)fetchSvn
/* Triggers the fetching */
{
	
	[self setBrowserPath:[browser path]];

	[super fetchSvn];
	
	if ( [self showRoot] )
	{
		[browser reloadColumn:0];
		[browser selectRow:0 inColumn:0];
		[browser setWidth:50 ofColumn:0];
		
	} else
	{
		[browser reloadColumn:0];
	}
}


- (void)fetchSvnListForUrl:(NSString *)url column:(int)column matrix:(NSMatrix *)matrix
{
	NSString *url2;
	
	if ( [self showRoot] )
	{
		url2 = [url substringFromIndex:5]; // get rid of "root" prefix
	
	} else
	{
		url2 = url;
	}

	NSURL *cleanUrl = [NSURL URLWithString:[NSString stringByAddingPercentEscape:[url2 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]]] relativeToURL:[self url]];

	BOOL useCache = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"cacheSvnQueries"] boolValue];
	NSDictionary *cachedDict;
	
	if ( useCache && ![[self revision] isEqualToString:@"HEAD"] && (cachedDict = [NSDictionary dictionaryWithContentsOfFile:[self getCachePathForUrl:cleanUrl]]) )
	{
		NSMutableArray *resultArray = [self parseSvnListResult:[cachedDict objectForKey:@"resultString"]];

		[self displayResultArray:resultArray column:column matrix:matrix];
	}
	else
	{
		[self setIsFetching:YES];

		[self setPendingTask:
		
		[MySvn		list: [cleanUrl absoluteString]
		  generalOptions: [self svnOptionsInvocation]
				 options: [NSArray arrayWithObjects:@"-v", [NSString stringWithFormat:@"-r%@", [self revision]], nil]

                callback: [self makeCallbackInvocationOfKind:10]
			callbackInfo: [NSDictionary dictionaryWithObjectsAndKeys:matrix, @"matrix", [NSNumber numberWithInt:column], @"column", cleanUrl, @"url", nil]
			    taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[[[[self window] windowController] document] windowTitle], @"documentName", nil]]

		];
	}
}

-(NSString *) pathToColumn:(int)column
{
	if ( [self showRoot] )
	{
		return [[browser pathToColumn:column] substringFromIndex:5]; // don't keep the "root" prefix
	
	} else	return [browser pathToColumn:column];
}

- (void)fetchSvnReceiveDataFinished:(id)taskObj
{
	[super fetchSvnReceiveDataFinished:taskObj];

	id info = [taskObj objectForKey:@"callbackInfo"];
	NSString *result = [taskObj objectForKey:@"stdout"];

	NSURL *fetchedUrl = [info objectForKey:@"url"];
	NSMatrix *matrix = [info objectForKey:@"matrix"];
	int column = [[info objectForKey:@"column"] intValue];
	NSMutableArray *resultArray = [self parseSvnListResult:result];
	[self displayResultArray:resultArray column:column matrix:matrix];

	NSDictionary *cachedDict = [NSDictionary dictionaryWithObjectsAndKeys:result, @"resultString", nil];
	
	if ( ![[self revision] isEqualToString:@"HEAD"] )
	{
		if ( ![cachedDict writeToFile:[self getCachePathForUrl:fetchedUrl] atomically:YES] )
		{
			NSLog(@"Could not cache : %@", fetchedUrl);
		}
	}
	//NSLog(@"%d  %@", [cachedDict writeToFile:[self getCachePathForUrl:fetchedUrl] atomically:YES], cachedDict);
}

- (void) displayResultArray:(NSMutableArray *)resultArray column:(int)column matrix:(NSMatrix *)matrix
{
	//NSLog(@"matrix %@ %@ %d %@", browser, matrix, column, [self pathToColumn:column]);
	int i;
	for (i=0; i<[resultArray count]; i++ )
	{
		NSMutableDictionary *row = [resultArray objectAtIndex:i];
		NSBrowserCell *cell = [[NSBrowserCell alloc] initTextCell:[row objectForKey:@"displayName"]];
		NSString *fileType = [[row objectForKey:@"displayName"] pathExtension];
		NSImage *icon;
		NSString *name = [row objectForKey:@"name"];
		BOOL isDir = [[row objectForKey:@"isDir"] boolValue];
		
		NSString *path = [[[self pathToColumn:column] stringByAppendingPathComponent:name] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
		NSURL *url= [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [NSString stringByAddingPercentEscape:path], ((isDir)?(@"/"):(@""))] relativeToURL:[self url]];
		
		[row setObject:path forKey:@"path"];
		[row setObject:url forKey:@"url"];

		if ( [fileType isEqualToString:@""] && [[row objectForKey:@"isDir"] boolValue] )
		{
			icon = [NSImage imageNamed:@"FolderRef"];
			[row setObject:NSFileTypeDirectory forKey:@"fileType"];
			
		} else
		{
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:fileType];
			[row setObject:fileType forKey:@"fileType"];
		}

		//NSLog(@"%@", row);
		[cell setFont:[NSFont fontWithName:@"Lucida Grande" size:10]];
		[cell setImage:icon];
		[cell setLeaf:![[row objectForKey:@"isDir"] boolValue]];
		[cell setRepresentedObject:row];
		
		if ( [self disallowLeaves] && [cell isLeaf] )
		{
			[cell setEnabled:NO];
		}
		
		[matrix addRowWithCells:[NSArray arrayWithObject:cell]];
		[matrix setToolTip:[NSString stringWithFormat:@"Revision : %@\nAuthor : %@\nSize : %@ bytes\nTime : %@",  [row objectForKey:@"revision"],
																											[row objectForKey:@"author"],
																											[row objectForKey:@"size"],
																											[row objectForKey:@"time"]] forCell:cell];
		[matrix putCell:cell atRow:i column:0];
		[cell setLoaded:NO]; // because we want browser:willDisplayCell... to be called
		[cell release];
	}

	[matrix sizeToCells];
	[matrix display];
	
//	if ( [self browserPath] != nil ) 
//	{
//		[browser setPath:[self browserPath]]; // attempt to restore the previously displayed path
//		[self setBrowserPath:nil];
//	}
}


-(NSMutableArray *)parseSvnListResult:(NSString *)resultString
{
	NSArray *arr = [resultString componentsSeparatedByString:@"\n"]; 
	NSMutableArray *resultArr = [NSMutableArray array];
	int i;
	
	for ( i=0 ; i<[arr count]-1 ; i++ ) // last line is a blank line !
	{
		NSString *row =		[arr objectAtIndex:i];
		NSString *rev =		[[row substringWithRange:NSMakeRange(0, 7)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSString *author =  [[row substringWithRange:NSMakeRange(8, 8)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSString *size =	[[row substringWithRange:NSMakeRange(17, 10)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSString *time =	[row substringWithRange:NSMakeRange(28, 12)];
		NSString *name =	[[row substringFromIndex:41] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		BOOL isDir = [[name substringFromIndex:[name length]-1] isEqualToString:@"/"];
		
		[resultArr addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
											rev, @"revision", 
											author, @"author",
											size, @"size",
											time, @"time",
											name, @"name",
											(isDir)?([name substringWithRange:NSMakeRange(0, [name length]-1)]):(name), @"displayName",
											[NSNumber numberWithBool:isDir], @"isDir",
											
															nil]];
	}
	
	return resultArr;
}

#pragma mark -
#pragma mark Accessors

// - showRoot:
- (BOOL)showRoot { return showRoot; }
// - setShowRoot:
- (void)setShowRoot:(BOOL)flag {
    showRoot = flag;
}

// - disallowLeaves:
- (BOOL)disallowLeaves { return disallowLeaves; }
// - setDisallowLeaves:
- (void)setDisallowLeaves:(BOOL)flag {
    disallowLeaves = flag;
}

// - browserPath:
- (NSString *)browserPath { return browserPath; }

// - setBrowserPath:
- (void)setBrowserPath:(NSString *)aBrowserPath { 
    id old = [self browserPath];
    browserPath = [aBrowserPath retain];
	[old release];
	
}

- (NSString *)getCachePathForUrl:(NSURL *)url
{
	NSString *logId = @"list.xml";
	NSString *cachePath = [[MySvn cachePathForUrl:url revision:[self revision]] stringByAppendingPathComponent:logId];

	return cachePath;
}

@end
