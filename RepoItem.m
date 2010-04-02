//----------------------------------------------------------------------------------------
//  RepoItem.m - A file or folder in a Subversion repository.
//
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "NSString+MyAdditions.h"
#import "RepoItem.h"
#import "CommonUtils.h"


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
	}

	return obj;
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

- (BOOL) isRoot
{
	return fIsRoot;
}


//----------------------------------------------------------------------------------------

- (BOOL) isDir
{
	return fIsDir;
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
	return fPath ? fPath : @"";
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
	return fURL;
}


//----------------------------------------------------------------------------------------

- (BOOL) setUp: (NSString*) pathToColumn
		 url:   (NSURL*)    url
{
	NSString* path = [[pathToColumn stringByAppendingPathComponent: fName] trimSlashes];
	NSString* urlPath = [path escapeURL];
	if (fIsDir)
		urlPath = [urlPath stringByAppendingString: @"/"];
	NSURL* theURL = [NSURL URLWithString: urlPath relativeToURL: url];

	Assert(fFileType == nil && fPath == nil && fURL == nil);
	if (!fIsDir)
		fFileType = [[fName pathExtension] retain];
	fPath = [path   retain];
	fURL  = [theURL retain];
	return fIsDir;
}


//----------------------------------------------------------------------------------------

- (NSImage*) icon: (id) iconCache
{
	return [iconCache iconForFileType: fFileType];
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
	return self ? PathWithRevision(fURL, [self revision])
				: @"";
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
