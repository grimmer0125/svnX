#import "MySvnLogView.h"

@implementation MySvnLogView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{
		NSString *nibName;
		
			
		if ( [self isVerbose] )
		{
			nibName = @"MySvnLogView2";
			
		} else
		{
			nibName = @"MySvnLogView";
		}
		
		if ([NSBundle loadNibNamed:nibName owner:self])
		{
		  [_view setFrame:[self bounds]];
		  [self addSubview:_view];
		  
		//  [self addObserver:self forKeyPath:@"currentRevision" options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld) context:nil];

		}

	  [self setMostRecentRevision:1];

	}
	return self;
}

- (void)dealloc
{
//	NSLog(@"dealloc logview");
    [self setPath: nil];

    [self setLogArray: nil];
    [self setCurrentRevision: nil];

    [super dealloc];
}

- (void)unload
{
	// the nib is responsible for releasing its top-level objects
//	[_view release];	// this is done by super
	[logsAC release];
	
	
	if ( logsACSelection != nil ) [logsACSelection release];
	// these objects are bound to the file owner and retain it
	// we need to unbind them 
	[logsAC unbind:@"contentArray"];	// -> self retainCount -1
	
	[super unload];
}

- (void)resetUrl:(NSURL *)anUrl
{
	[self setUrl:anUrl];
	[self setMostRecentRevision:0];
	[self setLogArray:nil];
}

#pragma mark -
#pragma mark svn related methods


- (void)fetchSvnLog
{
	[self fetchSvn];
	
}

- (void)fetchSvn
/* Triggers the fetching */
{
	[super fetchSvn];

	if ( [self path] != nil )
	{
		[self fetchSvnLogForPath];  // when called from the working copy window, the fileMerge operation (svn diff)
									// takes a filesystem path, not an url+revision
	} else
		[self fetchSvnLogForUrl];
}

- (void)fetchSvnLogForUrl
{
	NSDictionary *cacheDict;
	BOOL useCache = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"cacheSvnQueries"] boolValue];
	
	if ( useCache && (cacheDict = [NSDictionary dictionaryWithContentsOfFile:[self getCachePath]]) )
	{
		[self setMostRecentRevision:[[cacheDict objectForKey:@"revision"] intValue]];
		[self setLogArray:[cacheDict objectForKey:@"logArray"]];
	}
	
	[self setPendingTask:
	
	[MySvn		log: [[self url] absoluteString]
	 generalOptions: [self svnOptionsInvocation]
			options: [NSArray arrayWithObjects:@"--xml", 
					 [NSString stringWithFormat:@"-r%@:%d", @"HEAD", [self mostRecentRevision]], (([self isVerbose])?(@"-v"):(nil)),  nil]

		   callback: [self makeCallbackInvocationOfKind:10]
	   callbackInfo: nil
		   taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[[[[self window] windowController] document] windowTitle], @"documentName", nil]]

	];
}
- (void)fetchSvnLogForPath
{
	[self setPendingTask:
	
	[MySvn		log: [self path]
	 generalOptions: [self svnOptionsInvocation]
			options: [NSArray arrayWithObjects:@"--xml", 
					 [NSString stringWithFormat:@"-r%@:%d", @"HEAD", [self mostRecentRevision]], (([self isVerbose])?(@"-v"):(nil)),  nil]

		   callback: [self makeCallbackInvocationOfKind:nil]
	   callbackInfo: nil
		   taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[[[[self window] windowController] document] windowTitle], @"documentName", nil]]

	];
}


- (void)fetchSvnReceiveDataFinished:(id)taskObj
{
	[super fetchSvnReceiveDataFinished:taskObj];

	NSString *result = [taskObj valueForKey:@"stdout"];
	
	MySvnLogParser *parser = [[MySvnLogParser alloc] init];
	
	NSMutableArray *parsedArray = [parser parseXmlString:result];

	if ( [parsedArray count] > 0 )
	{
		[self setMostRecentRevision:[[[parsedArray objectAtIndex:0] objectForKey:@"revision"] intValue]];
	
	} else
	{
		[self setMostRecentRevision:0];	
	}
	
	
	
	if ( [[self logArray] count] > 0 ) 	[[self logArray] removeObjectAtIndex:0];
	
	if ( logArray != nil )
	[parsedArray addObjectsFromArray:[self logArray]];
	
	[self setLogArray:parsedArray];
	
	NSDictionary *cachedDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:[self mostRecentRevision]], @"revision", [self logArray], @"logArray", nil];
	[cachedDict writeToFile:[self getCachePath] atomically:YES];
	
	if ( [self currentRevision] == nil && [[self logArray] count] > 0 )
	{
		[self setCurrentRevision:[[[self logArray] objectAtIndex:0] objectForKey:@"revision"]];

	} else
	if ( [self currentRevision] == nil && [[self logArray] count] == 0 )
	{
		[self setCurrentRevision:@"0"];
	}

	[parser release];
}

#pragma mark -
#pragma mark Table View datasource

/*" The tableview is driven by the bindings, except for the radio button column. "*/
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ( [[ aTableColumn identifier] isEqualToString:@"currentRevision"] ) // should be always the case
	{  
		if ( [[[[logsAC arrangedObjects] objectAtIndex:rowIndex] objectForKey:@"revision"] isEqualToString:[self currentRevision]] )
		return @"1";
	}
	
	return nil;
}
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	// The tableview is driven by the bindings, except for the first column !
	if ( [[ aTableColumn identifier] isEqualToString:@"currentRevision"] ) // should be always the case
	{   
		NSString *newRevision =  [[[logsAC arrangedObjects] objectAtIndex:rowIndex] objectForKey:@"revision"];

		if ( [self currentRevision] != newRevision )
		{
			[self setCurrentRevision:newRevision];
			[aTableView setNeedsDisplay:YES];
		}
	}
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
/*" Sometimes required by the compiler, sometimes not.  "*/
{
	return [[logsAC arrangedObjects] count];
}


#pragma mark -
#pragma mark Accessors


- (NSString *)selectedRevision // This is different from the checked one
{
    return [[[logsAC selectedObjects] objectAtIndex:0] objectForKey:@"revision"];
}

// - currentRevision:
- (NSString *)currentRevision {
    return currentRevision; 
}

// - setCurrentRevision:
- (void)setCurrentRevision:(NSString *)aCurrentRevision {
    id old = [self currentRevision];
    currentRevision = [aCurrentRevision retain];
    [old release];
}

// - path:
- (NSString *)path { return path; }

	// - setPath:
- (void)setPath:(NSString *)aPath {
    id old = [self path];
    path = [aPath retain];
    [old release];
}

// - isVerbose:
- (BOOL)isVerbose { return isVerbose; }
	// - setIsVerbose:
- (void)setIsVerbose:(BOOL)flag {
    isVerbose = flag;
}

// - logArray:
- (NSMutableArray *)logArray {
    return logArray; 
}

// - setLogArray:
- (void)setLogArray:(NSMutableArray *)aLogArray {
    id old = [self logArray];
    logArray = [aLogArray retain];
    [old release];
}

// - mostRecentRevision:
- (int)mostRecentRevision { return mostRecentRevision; }
// - setMostRecentRevision:
- (void)setMostRecentRevision:(int)aMostRecentRevision {
    mostRecentRevision = aMostRecentRevision;
}

- (NSString *)getCachePath
{
	NSString *logId = [NSString stringWithFormat:@"%@", (([self isVerbose])?(@"log_verbose.xml"):(@"log.xml"))];
	NSString *cachePath = [[MySvn cachePathForUrl:[self url]] stringByAppendingPathComponent:logId];

	return cachePath;
}

@end
