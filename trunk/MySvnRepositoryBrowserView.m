//
// MySvnRepositoryBrowserView.m
//

#import "MySvnRepositoryBrowserView.h"
#import "MyDragSupportMatrix.h"
#import "MyApp.h"
#import "MySvn.h"
#import "MyRepository.h"
#import "SvnListParser.h"
#import "NSString+MyAdditions.h"
#import "Tasks.h"
#import "CommonUtils.h"


@class IconCache;

enum { kMiniIconSize = 13 };


static NSFont* gFont = nil;
static NSDictionary* gStyle = nil;
static IconCache* gIconCache = nil;


//----------------------------------------------------------------------------------------

static NSImage*
makeMiniIcon (NSImage* image)
{
	Assert(image != nil);

	static const NSRect dstRect = { 0, 0, kMiniIconSize, kMiniIconSize };
	NSRect srcRect;
	srcRect.origin.x =
	srcRect.origin.y = 0;
	srcRect.size = [image size];

	NSImage* icon = [[NSImage alloc] initWithSize: dstRect.size];
	[icon lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	[image drawInRect: dstRect fromRect: srcRect operation: NSCompositeCopy fraction: 1];
	[icon unlockFocus];

	return icon;
}


//----------------------------------------------------------------------------------------
#pragma mark	-

@interface IconCache : NSObject
{
	NSWorkspace*			fWorkspace;
	NSMutableDictionary*	fDict;
	NSImage*				fDirIcon;
	NSImage*				fRootIcon;
}

- (NSImage*) iconForFileType: (NSString*) fileType;
- (NSImage*) dirIcon;
- (NSImage*) rootIcon;

@end	// IconCache


//----------------------------------------------------------------------------------------
#pragma mark	-

@implementation IconCache

- (id) init
{
	extern NSImage* GenericFolderImage ();

	self = [super init];
	if (self != nil)
	{
		fWorkspace = [NSWorkspace sharedWorkspace];
		fDict      = [[NSMutableDictionary alloc] init];
		fDirIcon   = makeMiniIcon(GenericFolderImage());
		fRootIcon  = makeMiniIcon([NSImage imageNamed: @"Repository"]);
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	gIconCache = nil;
	[fDict release];
	[fDirIcon release];
	[fRootIcon release];

	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (NSImage*) iconForFileType: (NSString*) fileType
{
	NSImage* icon = [fDict objectForKey: fileType];
	if (icon == nil)
	{
		NSImage* const image = [fWorkspace iconForFileType: fileType];
		if (image != nil)
		{
			icon = makeMiniIcon(image);
			[fDict setObject: icon forKey: fileType];
			[icon release];
		}
	}

	return icon;
}


//----------------------------------------------------------------------------------------

- (NSImage*) dirIcon
{
	return fDirIcon;
}


//----------------------------------------------------------------------------------------

- (NSImage*) rootIcon
{
	return fRootIcon;
}

@end	// IconCache


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation MySvnRepositoryBrowserView

- (id) initWithFrame: (NSRect) frameRect
{
	if (gFont == nil)
		gFont = [[NSFont labelFontOfSize: [NSFont labelFontSize]] retain];
	if (gStyle == nil)
		gStyle = [[NSDictionary dictionaryWithObjectsAndKeys:
							gFont,                           NSFontAttributeName,
							[NSNumber numberWithFloat: 0.4], NSObliquenessAttributeName,
							nil] retain];

	if (gIconCache == nil)
		gIconCache = [[IconCache alloc] init];
	else
		[gIconCache retain];

	if (self = [super initWithFrame: frameRect])
	{
		showRoot = YES;
		if ([NSBundle loadNibNamed: @"MySvnRepositoryBrowserView" owner: self])
		{
			[fView setFrame: [self bounds]];
			[self addSubview: fView];
		}
	}

	return self;
}


- (void) dealloc
{
//	NSLog(@"dealloc repository browser view");
	[self setBrowserPath: nil];
	[gIconCache release];

	[super dealloc];
}


- (void) unload
{
	// the nib is responsible for releasing its top-level objects
//	[fView release];	// this is done by super

	// these objects are bound to the file owner and retain it
	// we need to unbind them 
	[revisionTextField unbind: @"value"];
	[super unload];
}


//----------------------------------------------------------------------------------------
// Note: <sender> is an NSCell in an NSMatrix in the NSBrowser <browser>

- (void) onDoubleClick: (id) sender
{
	AssertClass(sender, NSCell);
	if (!isSubBrowser)
		[[self repository] changeRepositoryUrl: [[sender representedObject] objectForKey: @"url"]];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	public methods
//----------------------------------------------------------------------------------------
// Returns an array of the selected represented objects

- (NSArray*) selectedItems
{
	return [[browser selectedCells] valueForKey: @"representedObject"];
}


//----------------------------------------------------------------------------------------

- (void) reset
{
	[self setBrowserPath: nil];
	[browser setPath: @"/"];
}


//----------------------------------------------------------------------------------------

- (void) setupForSubBrowser:      (BOOL) showRoot_
		 allowsLeaves:            (BOOL) allowsLeaves
		 allowsMultipleSelection: (BOOL) allowsMultiSel
{
	isSubBrowser = YES;
	showRoot = showRoot_;
	disallowLeaves = !allowsLeaves;
	[self setRevision: @"HEAD"];
	[browser setAllowsEmptySelection: NO];
	[browser setAllowsMultipleSelection: allowsMultiSel];

	[self fetchSvn];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Browser delegate methods

- (void) browser:             (NSBrowser*) sender
		 createRowsForColumn: (int)        column
		 inMatrix:            (NSMatrix*)  matrix
{
	const id revision = [self revision];
	if (revision == nil) return; 

	if (isSubBrowser)
		[(MyDragSupportMatrix*) matrix setupForSubBrowser];
	if ([matrix numberOfRows] != 0)
	{
	}
	else if (column == 0 && showRoot)
	{
		[self setIsFetching: NO];
		const id repository = [self repository];
		const BOOL isDir = ![repository rootIsFile];
		NSURL* const    url = [self url];
		NSString* const name = isDir ? @"root" : [UnEscapeURL(url) lastPathComponent];
		NSString* const fileType = isDir ? NSFileTypeDirectory : [name pathExtension];
		fNameLen = [name length] + 1;

		NSBrowserCell* const cell =
			[[NSBrowserCell alloc] initImageCell: isDir ? [gIconCache rootIcon]
														: [gIconCache iconForFileType: fileType]];
		[cell setAttributedStringValue: [[[NSAttributedString alloc]
												initWithString: name attributes: gStyle] autorelease]];
		[cell setLeaf: !isDir];
		[cell setLineBreakMode: NSLineBreakByTruncatingTail];
		[cell setRepresentedObject:
			[NSDictionary dictionaryWithObjectsAndKeys: kNSTrue,		@"isRoot",
														name,			@"name",
														@"",			@"path",
														url,			@"url",
														revision,		@"revision",
														fileType,		@"fileType",
														NSBool(isDir),	@"isDir",
														nil]];

		[matrix addRowWithCells: [NSArray arrayWithObject: cell]];
		[matrix putCell: cell atRow: 0 column: 0];
		[cell release];
		[matrix sizeToCells];
		[matrix display];
	}
	else
		[self fetchSvnListForUrl: [sender path] column: column matrix: matrix];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	svn related methods
//----------------------------------------------------------------------------------------
// Triggers the fetching

- (void) fetchSvn
{
	[self setBrowserPath: [browser path]];

	[super fetchSvn];

	[browser reloadColumn: 0];
	if (showRoot)
	{
		[browser selectRow: 0 inColumn: 0];
		[browser setWidth: fNameLen * 8 ofColumn: 0];
	}
}


//----------------------------------------------------------------------------------------

- (void) fetchSvnListForUrl: (NSString*) theURL
		 column:             (int)       column
		 matrix:             (NSMatrix*) matrix
{
	NSString* url2 = theURL;

	if (showRoot)
		url2 = [url2 substringFromIndex: fNameLen];		// get rid of "root" prefix

	NSURL* cleanUrl = [NSURL URLWithString: [[url2 trimSlashes] escapeURL] relativeToURL: [self url]];
	NSString* const revision = [self revision];
	NSData* cachedData;

	if (GetPreferenceBool(@"cacheSvnQueries") &&
		![revision isEqualToString: @"HEAD"] &&
		(cachedData = [NSData dataWithContentsOfFile: [self getCachePathForUrl: cleanUrl]]))
	{
		NSArray* resultArray = [SvnListParser parseData: cachedData];

		[self displayResultArray: resultArray column: column matrix: matrix];
	}
	else
	{
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
												[NSMutableArray array],           @"result",
												matrix,                           @"matrix",
												[NSNumber numberWithInt: column], @"column",
												cleanUrl,                         @"url",
												nil];
		[self setIsFetching: YES];

		{
			[self setPendingTask:
				[MySvn	list: PathPegRevision(cleanUrl, revision)
			  generalOptions: [self svnOptionsInvocation]
					 options: [NSArray arrayWithObjects: @"--xml", @"-r", revision, nil]
					callback: [self makeCallbackInvocationOfKind: 10]
				callbackInfo: info
					taskInfo: [self documentNameDict]]
			];
		}
	}
}


//----------------------------------------------------------------------------------------

- (NSString*) pathToColumn: (int) column
{
	NSString* result = [browser pathToColumn: column];
	if (showRoot)
	{
		result = [result substringFromIndex: fNameLen];		// don't keep the "root" prefix
	}

	return result;
}


//----------------------------------------------------------------------------------------

- (void) fetchSvnReceiveDataFinished: (id) taskObj
{
	[super fetchSvnReceiveDataFinished:taskObj];

	id info = [taskObj objectForKey:@"callbackInfo"];
	NSData* result = stdOutData(taskObj);

	NSURL *fetchedUrl = [info objectForKey:@"url"];
	NSMatrix *matrix = [info objectForKey:@"matrix"];
	int column = [[info objectForKey:@"column"] intValue];
	NSArray* resultArray = [SvnListParser parseData: result];
	[self displayResultArray:resultArray column:column matrix:matrix];

	if ( ![[self revision] isEqualToString:@"HEAD"] )
	{
		if ( ![result writeToFile: [self getCachePathForUrl: fetchedUrl] atomically: YES] )
		{
			NSLog(@"Could not cache: %@", fetchedUrl);
		}
	}
}


//----------------------------------------------------------------------------------------
/*
	Each cell has a representedObject type: RepoItem
		isRoot:		is root item (BOOL)
		name:		file name (NSString)
		path:		file path (NSString)
		url:		file URL  (NSURL)
		mod_rev:	last change revision number (NSString)
		revision:	revision number (NSString)
		fileType:	file ext or NSFileTypeDirectory (NSString)
		isDir:		item is a dir (BOOL)
		author:		revision author (NSString)
		date:		file modification date (UTCTime)
		size:		file size (SInt64)
*/

- (void) displayResultArray: (NSArray*)  resultArray
		 column:             (int)       column
		 matrix:             (NSMatrix*) matrix
{
	//NSLog(@"matrix %@ %@ %d %@", browser, matrix, column, [self pathToColumn: column]);
	NSImage* const dirIcon = [gIconCache dirIcon];
	NSString* const pathToColumn = [self pathToColumn: column];
	NSURL* const url = [self url];

	const int count = [resultArray count];
	for (int i = 0; i < count; ++i)
	{
		NSMutableDictionary* row  = [resultArray objectAtIndex: i];
		NSString* const name      = [row objectForKey: @"name"];
		const BOOL isDir          = [[row objectForKey: @"isDir"] boolValue];
		NSBrowserCell* const cell = [[NSBrowserCell alloc] initTextCell: name];

		NSString* path = [[pathToColumn stringByAppendingPathComponent: name] trimSlashes];
		NSString* urlPath = [path escapeURL];
		if (isDir)
			urlPath = [urlPath stringByAppendingString: @"/"];
		NSURL* theURL = [NSURL URLWithString: urlPath relativeToURL: url];

		NSString* fileType = isDir ? NSFileTypeDirectory : [name pathExtension];
		NSImage* icon = isDir ? dirIcon : [gIconCache iconForFileType: fileType];
		[row setObject: fileType forKey: @"fileType"];
		[row setObject: path     forKey: @"path"];
		[row setObject: theURL   forKey: @"url"];

		if (isDir)	// set the contextual menu on folders
		{
	#if 0 // contextual menu replaced with onDoubleClick
			NSMenu* m = [browserContextMenu copy];
			[[m itemAtIndex: 0] setRepresentedObject: row];
			[cell setMenu: m];
	#endif
		}
		else if (disallowLeaves)	// !isDir
		{
			[cell setEnabled: NO];
		}

		[cell setFont: gFont];
		[cell setImage: icon];
		[cell setLeaf: !isDir];
		[cell setRepresentedObject: row];
	//	NSLog(@"row=%@", row);

		[matrix addRowWithCells: [NSArray arrayWithObject: cell]];

		NSString* const revisionStr = [row objectForKey: @"revision"];
		NSString* const authorStr   = [row objectForKey: @"author"];
		NSString* const dateStr     = [row objectForKey: @"date"];
		NSString* const timeStr     = [row objectForKey: @"time"];
		NSString* const helpStr     = isDir
			? [NSString stringWithFormat: @"Revision: %@\nAuthor: %@\nDate: %@\nTime: %@",
										  revisionStr, authorStr, dateStr, timeStr]
			: [NSString stringWithFormat: @"Revision: %@\nAuthor: %@\nSize: %@ bytes\nDate: %@\nTime: %@",
										  revisionStr, authorStr, [row objectForKey: @"size"],
										  dateStr, timeStr];
		[matrix setToolTip: helpStr forCell: cell];

		[matrix putCell: cell atRow: i column: 0];
		[cell release];
	}

	[matrix sizeToCells];
	[matrix display];

//	if ( [self browserPath] != nil ) 
//	{
//		[browser setPath: [self browserPath]]; // attempt to restore the previously displayed path
//		[self setBrowserPath: nil];
//	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Accessors
//----------------------------------------------------------------------------------------

- (NSString*) browserPath { return browserPath; }


//----------------------------------------------------------------------------------------

- (void) setBrowserPath: (NSString*) aBrowserPath
{
	id old = browserPath;
	browserPath = [aBrowserPath retain];
	[old release];
}


//----------------------------------------------------------------------------------------

- (NSString*) getCachePathForUrl: (NSURL*) theURL
{
	return [MySvn cachePathForKey: [NSString stringWithFormat: @"%@::%@ list",
															   [theURL absoluteString], [self revision]]];
}


@end

//----------------------------------------------------------------------------------------
// End of MySvnRepositoryBrowserView.m
