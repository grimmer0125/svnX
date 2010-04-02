//
// MySvnRepositoryBrowserView.m
//

#import "MySvnRepositoryBrowserView.h"
#import "MyDragSupportMatrix.h"
#import "MyApp.h"
#import "MySvn.h"
#import "MyRepository.h"
#import "RepoItem.h"
#import "SvnListParser.h"
#import "NSString+MyAdditions.h"
#import "Tasks.h"
#import "CommonUtils.h"
#import "SvnInterface.h"


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
// Compare names alphabetically & case insensitively.

static int
compareNames (id obj1, id obj2, void* context)
{
	#pragma unused(context)
	return [[obj1 name] compare: [obj2 name] options: kSortOptions];
}


//----------------------------------------------------------------------------------------
// Returns an array of RepoItems

static NSArray*
ToRepoItems (NSArray* dicts, NSString* revision)
{
	NSMutableArray* result = [NSMutableArray array];
	const SvnRevNum revNum = SvnRevNumFromString(revision);

	for_each_obj(en, it, dicts)
	{
		id obj = [RepoItem repoItem: it revision: revNum];
		[result addObject: obj];
		[obj release];
	}

	[result sortUsingFunction: compareNames context: NULL];

	return result;
}


//----------------------------------------------------------------------------------------
// Returns an array of dicts

static NSArray*
FromRepoItems (NSArray* repoItems)
{
	NSMutableArray* result = [NSMutableArray array];

	for_each_obj(en, it, repoItems)
	{
		[result addObject: [it dictionary]];
	}

	return result;
}


//----------------------------------------------------------------------------------------

static NSArray*
RepoItemsSetRevision (NSArray* repoItems, id revision)
{
	const SvnRevNum revNum = SvnRevNumFromString(revision);
	for_each_obj(en, it, repoItems)
	{
		[(RepoItem*) it setRevision: revNum];
	}

	[(NSMutableArray*) repoItems sortUsingFunction: compareNames context: NULL];

	return repoItems;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

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

@interface MySvnRepositoryBrowserView (Private)

	- (void) displayDirCache: info;
	- (void) displayDirNoCache: info;
	- (void) displayDirList: (NSArray*)      dirList
			 info:           (NSDictionary*) info
			 shouldCache:    (BOOL)          shouldCache;

@end	// MySvnRepositoryBrowserView (Private)


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


//----------------------------------------------------------------------------------------

- (void) dealloc
{
//	dprintf("0x%X", self);
	[self setBrowserPath: nil];
	[gIconCache release];

	[super dealloc];
}


//----------------------------------------------------------------------------------------

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
	{
		[fRepository openItem: [sender representedObject] revision: [self revision]];
	}
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
// If there is a single selected item then return it else return nil.

- (RepoItem*) selectedItemOrNil
{
	NSArray* cells = [browser selectedCells];

	return (cells != nil && [cells count] == 1) ? [[cells lastObject] representedObject] : nil;
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
//----------------------------------------------------------------------------------------

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
		const BOOL isDir = ![fRepository rootIsFile];
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
		id repoItem = [RepoItem repoRoot: isDir name: name
								revision: SvnRevNumFromString(revision) url: url];
		[cell setRepresentedObject: repoItem];
		[repoItem release];

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
#pragma mark	-
#pragma mark	svn list
//----------------------------------------------------------------------------------------

typedef const svn_dirent_t*	SvnListEntry;
typedef const svn_lock_t*	SvnLock;

const UInt32 kListFlags = SVN_DIRENT_KIND | SVN_DIRENT_SIZE | SVN_DIRENT_CREATED_REV |
						  SVN_DIRENT_TIME | SVN_DIRENT_LAST_AUTHOR;

const NSPropertyListFormat kListCacheFormat = NSPropertyListBinaryFormat_v1_0;


//----------------------------------------------------------------------------------------

struct SvnListEnv
{
	SvnRevNum		fRevision;
	NSMutableArray*	fList;
//	UInt64			fT0;
	id				fSelf;
};

typedef struct SvnListEnv SvnListEnv;


//----------------------------------------------------------------------------------------
// Repo 'svn list' callback.  Appends to fList in (SvnListEnv*) baton.

static SvnError
svnListReceiver (void*        baton,
				 const char*  path,
				 SvnListEntry dirent,
				 SvnLock      lock,
				 const char*  abs_path,
				 SvnPool      pool)
{
	#pragma unused(lock, abs_path, pool)
	/*dprintf("rev=%d kind=%d time=%qi author=%s path=<%s>",
			dirent->created_rev, dirent->kind, dirent->time, dirent->last_author, path);*/
	SvnListEnv* const env = (SvnListEnv*) baton;
	if ([env->fSelf pendingTask] == nil)
		return svn_error_create(SVN_ERR_CANCELLED, NULL, NULL);
	if (*path != 0)
	{
		const char* str = strrchr(path, '/');
		if (str != NULL)
			path = str + 1;
		id obj = [RepoItem repoItem: (dirent->kind == svn_node_dir)
						   name:     UTF8(path)
						   author:   UTF8(dirent->last_author)
						   revision: env->fRevision
						   modRev:   dirent->created_rev
						   time:     dirent->time * 1e-6 - kCFAbsoluteTimeIntervalSince1970
						   size:     dirent->size];
		[env->fList addObject: obj];
		[obj release];
	#if 0
		if (env->fT0 && microseconds() - env->fT0 > 500 * 1000)
		{
			env->fT0 = 0;
			[env->fSelf setIsFetching: YES];
		}
	#endif
	}

	return SVN_NO_ERROR;
}


//----------------------------------------------------------------------------------------
// svn list of info.url via SvnInterface (called by separate thread)

- (void) svnDoList: (NSDictionary*) info
{
	Assert(fRepository);
//	NSLog(@"svn list - begin");
//	NSLog(@"svnDoList: rev=%@ url=<%@>", [self revision], [[info objectForKey: @"url"] absoluteString]);
	[self retain];
	NSAutoreleasePool* const autoPool = [[NSAutoreleasePool alloc] init];
	const SvnPool pool = SvnNewPool();	// Create top-level memory pool.
	@try
	{
		UInt64 t0 = microseconds();
		SvnClient ctx = [fRepository svnClient];

		char path[PATH_MAX * 2];
		if (ToUTF8([[info objectForKey: @"url"] absoluteString], path, sizeof(path)))
		{
			int len = strlen(path);
			if (len > 0 && path[len - 1] == '/')
				path[len - 1] = 0;
			NSString* const revision = [self revision];
			const BOOL isHead = [revision isEqualToString: @"HEAD"];
			svn_opt_revision_t rev_opt = { svn_opt_revision_head };
			if (!isHead)
			{
				rev_opt.kind         = svn_opt_revision_number;
				rev_opt.value.number = [revision intValue];
			}
			SvnListEnv env = { SvnRevNumFromString(revision), [info objectForKey: @"result"], /*t0,*/ self };

			// Retrive directory list from repository.
			SvnThrowIf(svn_client_list(path, &rev_opt, &rev_opt, !kSvnRecurse,
									   kListFlags, false,
									   svnListReceiver, &env,
									   ctx, pool));
			[env.fList sortUsingFunction: compareNames context: NULL];

			const double t = microseconds() - t0;
		/*	dprintf("results=%d column=%@ matrix=%@",
					[env.fList count], [info objectForKey: @"column"], [info objectForKey: @"matrix"]);
			dprintf("rev=%@ results=%d column=%@ '%s'",
					revision, [env.fList count], [info objectForKey: @"column"], strrchr(path, '/'));*/
		#if qTime
			dprintf("svn_client_list: time=%g ms", t * 1e-3);
		#endif

			[self performSelectorOnMainThread: (!isHead && t > 50e3 && GetPreferenceBool(@"cacheSvnQueries"))
													? @selector(displayDirCache:)
													: @selector(displayDirNoCache:)
				  withObject: info waitUntilDone: YES];
		}
	}
	@catch (SvnException* ex)
	{
		SvnReportCatch(ex);
		[self setIsFetching: NO];
		if ([ex error]->apr_err != SVN_ERR_CANCELLED)
			[self performSelectorOnMainThread: @selector(svnError:) withObject: [ex message] waitUntilDone: NO];
	}
	@finally
	{
		SvnDeletePool(pool);
		[autoPool release];
		[self setPendingTask: nil];
		[self release];
//		NSLog(@"svn list - end");
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
		NSString* errorString = nil;
		NSArray* resultArray = ToRepoItems(
			[NSPropertyListSerialization propertyListFromData: cachedData
										 mutabilityOption:     NSPropertyListMutableContainers
										 format:               NULL
										 errorDescription:     &errorString], revision);
		if (errorString != nil)
		{
			dprintf("WARNING: Could not parse plist cache: %@\n    data=%@ error=%@",
					cleanUrl, cachedData, errorString);
			[errorString release];
		}
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

		if (SvnWantAndHave())
		{
		//	dprintf("svnDoList url='%@'", cleanUrl);
			[self setPendingTask: info];	// Use any old dict
			[NSThread detachNewThreadSelector: @selector(svnDoList:)
					  toTarget:                self
					  withObject:              info];
		}
		else
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
	NSArray* const resultArray = [SvnListParser parseData: stdOutData(taskObj)];
	NSString* const revision = [self revision];
	[self displayDirList: RepoItemsSetRevision(resultArray, revision)
		  info:           [taskObj objectForKey: @"callbackInfo"]
		  shouldCache:    ![revision isEqualToString: @"HEAD"]];
}


//----------------------------------------------------------------------------------------

- (void) displayDirCache: info
{
	[self displayDirList: [info objectForKey: @"result"]
		  info:           info
		  shouldCache:    YES];
}


//----------------------------------------------------------------------------------------

- (void) displayDirNoCache: info
{
	[self displayDirList: [info objectForKey: @"result"]
		  info:           info
		  shouldCache:    NO];
}


//----------------------------------------------------------------------------------------

- (void) displayDirList: (NSArray*)      dirList
		 info:           (NSDictionary*) info
		 shouldCache:    (BOOL)          shouldCache
{
	[super fetchSvnReceiveDataFinished: nil];

	[self displayResultArray: dirList
		  column:             [[info objectForKey: @"column"] intValue]
		  matrix:             [info objectForKey: @"matrix"]];

	if (shouldCache)
	{
		NSString* errorString = nil;
		NSData* data = [NSPropertyListSerialization dataFromPropertyList: FromRepoItems(dirList)
													format:               kListCacheFormat
													errorDescription:     &errorString];

		NSURL* fetchedUrl = [info objectForKey: @"url"];
		if (data == nil || ![data writeToFile: [self getCachePathForUrl: fetchedUrl] atomically: YES])
		{
			dprintf("WARNING: Could not cache: %@\n    data=%@ error=%@", fetchedUrl, data, errorString);
		}
		[errorString release];
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
		RepoItem* const item = [resultArray objectAtIndex: i];
		const BOOL isDir = [item setUp: pathToColumn url: url];

		NSBrowserCell* const cell = [[NSBrowserCell alloc] initTextCell: [item name]];
		if (!isDir && disallowLeaves)
			[cell setEnabled: NO];
		[cell setFont: gFont];
		[cell setImage: isDir ? dirIcon : [item icon: gIconCache]];
		[cell setLeaf: !isDir];
		[cell setRepresentedObject: item];
	//	NSLog(@"item=%@", item);

		[matrix addRowWithCells: [NSArray arrayWithObject: cell]];
		[matrix setToolTip: [item toolTip] forCell: cell];

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
	return [MySvn cachePathForKey: [NSString stringWithFormat: @"%@::%@ list3",
															   [theURL absoluteString], [self revision]]];
}


@end

//----------------------------------------------------------------------------------------
// End of MySvnRepositoryBrowserView.m
