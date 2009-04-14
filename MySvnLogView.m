#import "MySvnLogView.h"
#import "MySvnLogAC.h"
#import "MySvnLogParser.h"
#import "MyRepository.h"
#import "MyApp.h"
#include "NSString+MyAdditions.h"
#include "CommonUtils.h"
#include "DbgUtils.h"


//----------------------------------------------------------------------------------------

static NSString*
getRevisionAtIndex (NSArray* array, int index)
{
	return (index >= 0 && index < [array count]) ? [[array objectAtIndex: index] objectForKey: @"revision"] : nil;
}


//----------------------------------------------------------------------------------------

static NSString*
pathItemToString (NSDictionary* item)
{
	NSString* str = [NSString stringWithFormat: @"%@\t%@", [item objectForKey: @"action"],
														   [item objectForKey: @"path"]];
	NSString* fromPath = [item objectForKey: @"copyfrompath"];
	if (fromPath)
		str = [NSString stringWithFormat: @"%@\t%@\t%@", str,
										  [item objectForKey: @"copyfromrev"], fromPath];

	return str;
}


//----------------------------------------------------------------------------------------

static NSString*
logItemToString (NSDictionary* item, BOOL isAdvanced)
{
	NSMutableString* str = [NSMutableString string];
	[str appendString: [NSString stringWithFormat: @"%@\t%@\t%@\n", [item objectForKey: @"revision"],
												   [item objectForKey: @"author"], [item objectForKey: @"date"]]];
	if (isAdvanced)
	{
		NSArray* const paths = [item objectForKey: @"paths"];
		NSEnumerator* enumerator = [paths objectEnumerator];
		id pathItem;
		while (pathItem = [enumerator nextObject])
		{
			[str appendString: pathItemToString(pathItem)];
			[str appendString: @"\n"];
		}
	}
	[str appendString: [item objectForKey: @"msg"]];
	[str appendString: @"\n"];

	return str;
}


//----------------------------------------------------------------------------------------
#pragma mark -
//----------------------------------------------------------------------------------------

@implementation MySvnLogView

- (id) initWithFrame: (NSRect) frameRect
{
	self = [super initWithFrame: frameRect];
	if (self != nil)
	{
		isVerbose = YES;
		fIsAdvanced = YES;

		if ([NSBundle loadNibNamed: @"MySvnLogView2" owner: self])
		{
			[_view setFrame: [self bounds]];
			[self addSubview: _view];

		//  [self addObserver:self forKeyPath:@"currentRevision"
		//			options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld) context:nil];
		}

		[self setMostRecentRevision: 1];
	}

	return self;
}


- (void) dealloc
{
//	NSLog(@"dealloc logview");
	[self setPath: nil];

	[self setLogArray: nil];
	[self setCurrentRevision: nil];

	[super dealloc];
}


- (void) unload
{
	// the nib is responsible for releasing its top-level objects
//	[_view release];	// this is done by super
	[logsAC release];
	[logsACSelection release];

	// these objects are bound to the file owner and retain it
	// we need to unbind them 
	[logsAC unbind:@"contentArray"];	// -> self retainCount -1
	
	[super unload];
}


//----------------------------------------------------------------------------------------
// This gets called twice because of the loadNibNamed call above.
// The first time with [self window] == nil.

- (void) awakeFromNib
{
	NSWindow* const window = [self window];
	if (window)
	{
		// Can't use [self repository] here as [window windowController] == nil
		[self setAdvanced: [[window delegate] isKindOfClass: [MyRepository class]] &&
						   GetPreferenceBool(@"defaultLogViewKindIsAdvanced")];

		[splitView setDelegate: self];	// allow us to keep the paths pane hidden during window resize
		[pathsTable setTarget: self];
		[pathsTable setDoubleAction: @selector(doubleClickPath:)];
		[window makeFirstResponder: logTable];
	}
}


//----------------------------------------------------------------------------------------

- (void) resetUrl: (NSURL*) anUrl
{
	[self setUrl:anUrl];
	[self setMostRecentRevision:0];
	[self setLogArray:nil];
}


//----------------------------------------------------------------------------------------

- (IBAction) copy: (id) sender
{
	NSString* str = nil;
	id view = [[self window] firstResponder];
	if (view == logTable)
	{
		str = logItemToString([[logsAC selectedObjects] objectAtIndex: 0], fIsAdvanced);
	}
	else if (view == pathsTable)
	{
		str = pathItemToString([[logsACSelection selectedObjects] objectAtIndex: 0]);
	}
	else
		dprintf("firstResponder=%@", view);

	if (str)
	{
		NSPasteboard* clipboard = [NSPasteboard generalPasteboard];
		[clipboard declareTypes: [NSArray arrayWithObject: NSStringPboardType] owner: self];
		[clipboard setString: str forType: NSStringPboardType];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) keyDown: (NSEvent*) theEvent
{
	// Make space-bar in log table => acts as if the radio button in the selected row was clicked
	if ([[self window] firstResponder] == logTable &&
		[[theEvent characters] characterAtIndex: 0] == ' ')
	{
		NSString* rev = [self selectedRevision];
		if (rev)
		{
			[self setCurrentRevision: rev];
			[logTable setNeedsDisplay: YES];
		}
	}
	else
		[super keyDown: theEvent];
}


//----------------------------------------------------------------------------------------
// <sender> is splitView with paths in lower pane

- (void) splitView:                 (NSSplitView*) sender
		 resizeSubviewsWithOldSize: (NSSize)       oldSize
{
	if (!fIsAdvanced)
	{
		const NSSize newSize = [sender bounds].size;
		NSView* const view0 = [[sender subviews] objectAtIndex: 0];
		NSRect frame = [view0 frame];
		frame.size.width  = newSize.width;
		frame.size.height = newSize.height - [sender dividerThickness];
		[view0 setFrame: frame];
	}
	[sender adjustSubviews];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	svn related methods
//----------------------------------------------------------------------------------------

- (void) doSvnLog:    (NSString*) aPath
		 pegRevision: (NSString*) pegRev
{
	if (pegRev)
		aPath = PathPegRevision(aPath, pegRev);
	else
		pegRev = @"HEAD";
	id taskInfo = [MySvn	log: aPath
				 generalOptions: [self svnOptionsInvocation]
						options: [NSArray arrayWithObjects: @"--xml", 
										[NSString stringWithFormat: @"-r%@:%d", pegRev, [self mostRecentRevision]],
										isVerbose ? @"-v" : nil,
										nil]
					   callback: [self makeCallbackInvocationOfKind: 0]
				   callbackInfo: nil
					   taskInfo: [self documentNameDict]];
	[self setPendingTask: taskInfo];
}


- (void) fetchSvnLog
{
	[self fetchSvn];
}


// Triggers the fetching
- (void) fetchSvn
{
	[super fetchSvn];

	if ( [self path] != nil )
	{
		[self fetchSvnLogForPath];  // when called from the working copy window, the fileMerge operation (svn diff)
	}								// takes a filesystem path, not an url+revision
	else
		[self fetchSvnLogForUrl];
}


- (void) fetchSvnLogForUrl
{
	NSDictionary* cacheDict = nil;
	BOOL useCache = [GetPreference(@"cacheSvnQueries") boolValue];

	NSData* cacheData;
	if (useCache && (cacheData = [NSData dataWithContentsOfFile: [self getCachePath]]))
	{
		NSString* errorString = nil;
		cacheDict = [NSPropertyListSerialization propertyListFromData: cacheData
												 mutabilityOption:     kCFPropertyListMutableContainers
												 format:               NULL
												 errorDescription:     &errorString];
		if (errorString)
			NSLog(@"fetchSvnLogForUrl: ERROR: %@", errorString);
		[errorString release];
	}
	if (cacheDict)
	{
		[self setMostRecentRevision:[[cacheDict objectForKey:@"revision"] intValue]];
		[self setLogArray:[cacheDict objectForKey:@"logArray"]];
	}

	[self doSvnLog: [[self url] absoluteString] pegRevision: [self revision]];
}


- (void) fetchSvnLogForPath
{
	[self doSvnLog: [self path] pegRevision: nil];
}


- (void) fetchSvnReceiveDataFinished: (id) taskObj
{
	[super fetchSvnReceiveDataFinished:taskObj];

	NSData* data = [taskObj valueForKey: @"stdoutData"];
	if (data != nil && [data length] != 0)
	{
		NSMutableArray* parsedArray = [MySvnLogParser parseData: data];

		[self setMostRecentRevision: [parsedArray count] ? [getRevisionAtIndex(parsedArray, 0) intValue] : 0];

		NSMutableArray* array = [self logArray];
		const int count = [array count];
		if (count > 0)
		{
			[array removeObjectAtIndex: 0];

			if (count > 1)
				[parsedArray addObjectsFromArray: array];
		}

		[self setLogArray: parsedArray];
		array = parsedArray;

		if (currentRevision == nil)
		{
			[self setCurrentRevision: [array count] ? getRevisionAtIndex(array, 0) : @"0"];
		}

		if ([self url] != nil)	// Only cache logs for repository URLs not Working Copy paths
		{
			id dict = [NSDictionary dictionaryWithObjectsAndKeys:
							[NSNumber numberWithInt: [self mostRecentRevision]], @"revision",
							array, @"logArray",
							nil];
			NSString* errorString = nil;
			id data = [NSPropertyListSerialization dataFromPropertyList: dict
												   format:               NSPropertyListBinaryFormat_v1_0
												   errorDescription:     &errorString];
			if (data)
			{
				[data writeToFile: [self getCachePath] atomically: YES];
			}
			else
			{
				NSLog(@"fetchSvnReceiveDataFinished: ERROR: %@", errorString);
				[errorString release];
			}
		}
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Table View datasource
//----------------------------------------------------------------------------------------

// The tableview is driven by the bindings, except for the radio button column.

- (id) tableView:                 (NSTableView*)   aTableView
	   objectValueForTableColumn: (NSTableColumn*) aTableColumn
	   row:                       (int)            rowIndex
{
	if ([[aTableColumn identifier] isEqualToString: @"currentRevision"])	// should be always the case
	{
		return NSBool([getRevisionAtIndex([logsAC arrangedObjects], rowIndex) isEqualToString: currentRevision]);
	}

	return nil;
}


- (void) tableView:      (NSTableView*)   aTableView
		 setObjectValue: (id)             anObject
		 forTableColumn: (NSTableColumn*) aTableColumn
		 row:            (int)            rowIndex
{
	// The tableview is driven by the bindings, except for the first column !
	if ([[aTableColumn identifier] isEqualToString: @"currentRevision"])	// should be always the case
	{
		NSString* newRevision = getRevisionAtIndex([logsAC arrangedObjects], rowIndex);

		if (currentRevision == nil || ![currentRevision isEqualToString: newRevision])
		{
			[self setCurrentRevision:newRevision];
			[aTableView setNeedsDisplay: YES];
		}
	}
}


// Sometimes required by the compiler, sometimes not.

- (int) numberOfRowsInTableView: (NSTableView*) aTableView
{
	return [[logsAC arrangedObjects] count];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Accessors
//----------------------------------------------------------------------------------------

- (NSString*) selectedRevision	// This is different from the checked one
{
	return getRevisionAtIndex([logsAC selectedObjects], 0);
}


// - currentRevision:
- (NSString*) currentRevision { return currentRevision; }

// - setCurrentRevision:
- (void) setCurrentRevision: (NSString*) aCurrentRevision
{
	id old = currentRevision;
	currentRevision = [aCurrentRevision retain];
	[old release];
}


// - path:
- (NSString*) path { return path; }

// - setPath:
- (void) setPath: (NSString*) aPath
{
	id old = path;
	path = [aPath retain];
	[old release];
}


// - logArray:
- (NSMutableArray*) logArray { return logArray; }

// - setLogArray:
- (void) setLogArray: (NSMutableArray*) aLogArray
{
	id old = logArray;
	logArray = [aLogArray retain];
	[old release];
}


// - mostRecentRevision:
- (int) mostRecentRevision { return mostRecentRevision; }

// - setMostRecentRevision:
- (void) setMostRecentRevision: (int) aMostRecentRevision
{
	mostRecentRevision = aMostRecentRevision;
}


//----------------------------------------------------------------------------------------

- (BOOL) advanced
{
	return fIsAdvanced;
}


//----------------------------------------------------------------------------------------

- (void) setAdvanced: (BOOL) isAdvanced
{
	if (fIsAdvanced == isAdvanced)
		return;
	fIsAdvanced = isAdvanced;

	const id firstResponder = isAdvanced ? nil : [[self window] firstResponder];

	// Hide or show Paths search field
	[searchPaths setHidden: !isAdvanced];
	if (!isAdvanced && [[searchPaths stringValue] length])
	{
		[searchPaths setStringValue: @""];
		[logsAC clearSearchPaths];
	}

	// Hide or show pathsCount column
	NSTableColumn* col = [logTable tableColumnWithIdentifier: @"pathsCount"];
	Assert(col);
	const GCoord colWidth = isAdvanced ? 30 : -4;
	[col setMinWidth: colWidth];
	[col setWidth: colWidth];

	// Collapse or expand paths table
	const id subViews = [splitView subviews];
	NSView* pathsView = [subViews objectAtIndex: 1];
	Assert(pathsView);
	GCoord splitterSize = [splitView dividerThickness];
	if (isAdvanced)
		splitterSize = -splitterSize;
	NSRect frame = [splitView frame];
	frame.origin.y -= splitterSize;
	frame.size.height += splitterSize;
	[splitView setFrame: frame];

	frame = [pathsView frame];
	frame.size.height = isAdvanced ? 100 : 0;
	[pathsView setFrame: frame];
	[pathsView setHidden: !isAdvanced];

	[splitView adjustSubviews];
	[splitView setNeedsDisplay: YES];
	[[subViews objectAtIndex: 0] setNeedsDisplay: YES];

	// If we just hid the focused view then focus the log table.
	// This is required as hiding an NSSearchField doesn't update the focus.
	if (firstResponder && [firstResponder isKindOfClass: [NSView class]] &&
						  [firstResponder isHiddenOrHasHiddenAncestor])
		[[self window] makeFirstResponder: logTable];
}


//----------------------------------------------------------------------------------------

- (NSString*) getCachePath
{
	NSString* logName = isVerbose ? @" log_verbose" : @" log";
	return [MySvn cachePathForKey: [[[self url] absoluteString] stringByAppendingString: logName]];
}

@end

