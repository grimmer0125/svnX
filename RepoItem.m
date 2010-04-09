//----------------------------------------------------------------------------------------
//  RepoItem.m - A file or folder in a Subversion repository.
//
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "NSString+MyAdditions.h"
#import "RepoItem.h"
#import "MyRepository.h"
#import "CommonUtils.h"
#import "IconUtils.h"


//----------------------------------------------------------------------------------------

@interface NSThread (OSX_10_4)

	+ (void) sleepForTimeInterval: (NSTimeInterval) ti;

@end	// NSThread (OSX_10_4)


//----------------------------------------------------------------------------------------

static inline NSString* NewString_	(NSData* data)
{ return [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease]; }


//----------------------------------------------------------------------------------------

enum { kSvnRevNumBufSize = 32 };

static const char*
SvnRevNumString (SvnRevNum rev, char buf[kSvnRevNumBufSize])
{
	if (rev == INT_MAX)
		return "HEAD";
	if (!SVN_IS_VALID_REVNUM(rev))
		return "";
	snprintf(buf, kSvnRevNumBufSize, "%lu", rev);
	return buf;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation RepoItem

ConstString kTypeRepoItem = @"svnX_REPO_ITEM";


//----------------------------------------------------------------------------------------

+ (id) repoItem: (NSDictionary*) dict
	   revision: (SvnRevNum)     revision
{
	RepoItem* obj = [self alloc];
	if (obj)
	{
		obj->fIsRoot   = FALSE;
		obj->fIsDir    = [[dict objectForKey: @"isDir"] boolValue];
		obj->fName     = [[dict objectForKey: @"name"] retain];
		obj->fAuthor   = [[dict objectForKey: @"author"] retain];
		obj->fRevision = revision;
		obj->fModRev   = [[dict objectForKey: @"mod_rev"] intValue];
		obj->fTime     = [[dict objectForKey: @"time"] doubleValue];
		if (!obj->fIsDir)
			obj->fSize = [[dict objectForKey: @"size"] longLongValue];
	}

	return obj;
}


//----------------------------------------------------------------------------------------

+ (id) repoItem: (BOOL) isDir
{
	RepoItem* obj = [self alloc];
	if (obj)
	{
		obj->fIsRoot = FALSE;
		obj->fIsDir  = isDir;
	}

	return obj;
}


//----------------------------------------------------------------------------------------

+ (id) repoItem: (BOOL)      isDir
	   name:     (NSString*) name
	   author:   (NSString*) author
	   revision: (SvnRevNum) revision
	   modRev:   (SvnRevNum) modRev
	   time:     (UTCTime)   time
	   size:     (SInt64)    size
{
	RepoItem* obj = [self alloc];
	if (obj)
	{
		obj->fIsRoot   = FALSE;
		obj->fIsDir    = isDir;
		obj->fName     = [name retain];
		obj->fAuthor   = [author retain];
		obj->fRevision = revision;
		obj->fModRev   = modRev;
		obj->fTime     = time;
		obj->fSize     = size;
	}

	return obj;
}


//----------------------------------------------------------------------------------------

+ (id) repoRoot: (BOOL)      isDir
	   name:     (NSString*) name
	   revision: (SvnRevNum) revision
	   url:      (NSURL*)    url
{
	RepoItem* obj = [self alloc];
	if (obj)
	{
		obj->fIsRoot   = TRUE;
		obj->fIsDir    = isDir;
		obj->fName     = [name retain];
		obj->fRevision =
		obj->fModRev   = revision;
		obj->fURL      = [url retain];
		if (!isDir)
			obj->fFileType = [[name pathExtension] retain];
	}

	return obj;
}


//----------------------------------------------------------------------------------------
// Create a pseudo-RepoItem for a log item or a log item's path.

+ (id) repoPath: (NSString*) path
	   revision: (SvnRevNum) revision
	   url:      (NSURL*)    url
{
	const BOOL isRoot = (path == nil);
	RepoItem* obj = [self repoRoot: isRoot name: nil revision: revision url: url];
	obj->fIsRoot = isRoot;
	obj->fIsLog  = TRUE;
	if (!isRoot)
	{
		obj->fName = [[path lastPathComponent] retain];
		obj->fPath = [[path stringByDeletingLastPathComponent] retain];
	}

	return [obj autorelease];
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[fName     release];
	[fAuthor   release];
	[fPath     release];
	[fFileType release];
	[fURL      release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------
// 'svn info' callback

static SvnError
svnInfoReceiver (void*     baton,
				 ConstCStr path,
				 SvnInfo   info,
				 SvnPool   pool)
{
	#pragma unused(path, pool)
	*(SvnNodeKind*) baton = info->kind;

	return SVN_NO_ERROR;
}


//----------------------------------------------------------------------------------------

- (void) doSvnInfo: (MyRepository*) document
{
	NSAutoreleasePool* autoPool = [NSAutoreleasePool new];
	SvnEnv* svnEnv = NULL;
	@try
	{
		NSURL* const url = [self url];
		if (SvnWantAndHave())
		{
			SvnClient ctx = SvnSetupClient(&svnEnv, document);

			char path[PATH_MAX * 2];
			NSIndex len = CFURLGetBytes((CFURLRef) url, (BytePtr) path, sizeof(path));
			if (len > 0)
			{
				if (path[len - 1] == '/')
					--len;
				path[len] = 0;
				SvnNodeKind kind = svn_node_unknown;
				const SvnOptRevision rev_opt = { svn_opt_revision_number, fRevision };
				SvnThrowIf(svn_client_info(path, &rev_opt, &rev_opt,
										   svnInfoReceiver, &kind, !kSvnRecurse,
										   ctx, SvnGetPool(svnEnv)));
				if (kind == svn_node_file)
					fIsDir = false;
				else if (kind == svn_node_dir)
					fIsDir = true;
				else
					dprintf("kind=%d", kind);
			}
		}
		else
		{
			id objs[12]; int count = 0;
			objs[count++] = @"info";
			count += [document svnStdOptions: objs + count];
			objs[count++] = PathPegRevNum(url, fRevision);
			Assert(count <= 12);
			NSData* outData = nil, *errData = nil;
			int status = SvnRun([NSArray arrayWithObjects: objs count: count],
								&outData, &errData, 0);

			if (status == 0 && [errData length] == 0)
			{
				for (ConstBytePtr p = [outData bytes],
								end = p + [outData length] - 12; p != end; ++p)
				{
					if (p[0] == '\n' && p[1] == 'N' &&
						memcmp(p + 2, "ode Kind: ", 10) == 0)
					{
						if (memcmp(p + 12, "file", 4) == 0)
							fIsDir = false;
						else if (memcmp(p + 12, "directory", 9) == 0)
							fIsDir = true;
						else
							dprintf("UNEXPECTED: \"%.*s\"\nstdout=\"%@\"",
									21, p, NewString_(outData));
						break;
					}
					if (p == end - 1)
						dprintf("WARNING: MISSING Node Kind\nstdout=\"%@\"",
								NewString_(outData));
				}
			}
			else
				dprintf("status=%d stderr=\"%@\"", status, NewString_(errData));
		}
	}
	@catch (...)
	{
	}
	@finally
	{
		fGettingInfo = false;
		SvnEndClient(svnEnv);
		[autoPool release];
	}
}


//----------------------------------------------------------------------------------------

- (void) svnInfo: (MyRepository*) document
{
	fGettingInfo = true;
//	dprintf("path='%@/%@' fRevision=%d fURL=<%@>", fPath, fName, fRevision, [fURL absoluteString]);
	[NSThread detachNewThreadSelector: @selector(doSvnInfo:)
							 toTarget: self
						   withObject: document];
}


//----------------------------------------------------------------------------------------

- (BOOL) isRoot
{
	return fIsRoot;
}


//----------------------------------------------------------------------------------------

- (BOOL) isDir
{
	if (fGettingInfo)
	{
		for (int i = 16 * 20; i > 0; --i)
		{
			[NSThread sleepForTimeInterval: 1.0 / 16];
			if (!*(volatile BOOL*) &fGettingInfo)
				break;
			if (i == 1)
				dprintf("TIME-OUT: svn info '%@@%d'", [[self url] absoluteString], fRevision);
		}
	}
	return fIsDir;
}


//----------------------------------------------------------------------------------------

- (BOOL) isLog
{
	return fIsLog;
}


//----------------------------------------------------------------------------------------

- (void) setName: (NSString*) name
{
	Assert(fName == nil);
	fName = [name retain];
}


//----------------------------------------------------------------------------------------

- (NSString*) name
{
	return fName ? fName : @"";
}


//----------------------------------------------------------------------------------------

- (void) setAuthor: (NSString*) author
{
	Assert(fAuthor == nil);
	fAuthor = [author retain];
}


//----------------------------------------------------------------------------------------

- (NSString*) author
{
	return fAuthor ? fAuthor : @"";
}


//----------------------------------------------------------------------------------------

- (NSString*) path
{
	return fPath ? [[fPath stringByAppendingPathComponent: fName] trimSlashes] : @"";
}


//----------------------------------------------------------------------------------------

- (NSString*) fileType
{
	return fFileType ? fFileType : NSFileTypeDirectory;
}


//----------------------------------------------------------------------------------------

- (void) setRevision: (SvnRevNum) revision
{
	fRevision = revision;
}


//----------------------------------------------------------------------------------------

- (SvnRevNum) revisionNum
{
	return fRevision;
}


//----------------------------------------------------------------------------------------

- (NSString*) revision
{
	return SvnRevNumToString(fRevision);
}


//----------------------------------------------------------------------------------------

- (void) setModRev: (SvnRevNum) modRev
{
	fModRev = modRev;
}


//----------------------------------------------------------------------------------------

- (SvnRevNum) modRevNum
{
	return fModRev;
}


//----------------------------------------------------------------------------------------

- (NSString*) modRev
{
	return SvnRevNumToString(fModRev);
}


//----------------------------------------------------------------------------------------

- (void) setSize: (SInt64) size
{
	fSize = size;
}


//----------------------------------------------------------------------------------------

- (SInt64) size
{
	return fSize;
}


//----------------------------------------------------------------------------------------

- (void) setTime: (UTCTime) time
{
	fTime = time;
}


//----------------------------------------------------------------------------------------

- (UTCTime) time
{
	return fTime;
}


//----------------------------------------------------------------------------------------

- (NSURL*) url
{
	return fIsRoot ? fURL
				   : [(id) CFURLCreateCopyAppendingPathComponent(NULL, (CFURLRef) fURL,
																 (CFStringRef) [self path], fIsDir)
						autorelease];
}


//----------------------------------------------------------------------------------------

- (BOOL) setUp: (NSString*) pathToColumn
		 url:   (NSURL*)    url
{
	Assert(fFileType == nil && fPath == nil && fURL == nil);
	if (!fIsDir)
		fFileType = [[fName pathExtension] retain];
	fPath = [pathToColumn retain];
	fURL  = [url retain];
	return fIsDir;
}


//----------------------------------------------------------------------------------------

- (IconRef) icon
{
	if (fIsDir)
		return fIsRoot ? RepositoryIcon() : GenericFolderIcon();

	return GetFileTypeIcon(fFileType);
}


//----------------------------------------------------------------------------------------

- (NSString*) toolTip
{
	char buf[kSvnRevNumBufSize];
	const char* mod_rev = SvnRevNumString(fModRev, buf);

	CFGregorianDate dt = CFAbsoluteTimeGetGregorianDate(fTime, NULL);
	#define	kFormat	@"Revision: %s\nAuthor: %@\nDate: %04u-%02u-%02u\nTime: %02u:%02u:%02u"
	return [NSString stringWithFormat: fIsDir ? kFormat : kFormat "\nSize: %qu bytes",
				mod_rev, fAuthor, dt.year, dt.month, dt.day,
				dt.hour, dt.minute, (int) dt.second, fSize];
	#undef	kFormat
}


//----------------------------------------------------------------------------------------

- (NSString*) pathWithRevision
{
	return PathWithRevision([self url], [self revision]);
}


//----------------------------------------------------------------------------------------

- (NSString*) pathPegRevision
{
	return PathPegRevision([self url], [self revision]);
}


//----------------------------------------------------------------------------------------

- (NSDictionary*) dictionary
{
	id size = fIsDir ? nil : [NSNumber numberWithLongLong: fSize];
	return [NSDictionary dictionaryWithObjectsAndKeys:
				NSBool(fIsDir),						@"isDir",
				fName ? fName : @"",				@"name",
				fAuthor ? fAuthor : @"",			@"author",
				[NSNumber numberWithLong: fModRev],	@"mod_rev",
				[NSNumber numberWithDouble: fTime],	@"time",
				size,								@"size",
				nil];
}


@end	// RepoItem


//----------------------------------------------------------------------------------------
// End of RepoItem.m
