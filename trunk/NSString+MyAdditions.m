//----------------------------------------------------------------------------------------
//	NSString+MyAdditions.m - Additional NSString methods & utilities.
//
//	Created by Dominique PERETTI on Sun Jul 18 2004.
//	Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//	Copyright © Chris, 2007 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "NSString+MyAdditions.h"


//----------------------------------------------------------------------------------------

NSString*
UTF8 (const char* aUTF8String)
{
	return aUTF8String ? [NSString stringWithUTF8String: aUTF8String] : @"";
}


//----------------------------------------------------------------------------------------

BOOL
ToUTF8 (NSString* string, char* buf, unsigned int bufSize)
{
	return string &&
		   [string getCString: buf maxLength: bufSize encoding: NSUTF8StringEncoding];
}


//----------------------------------------------------------------------------------------

NSString*
EscapeURL (NSString* url)
{
	return [url stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
}


//----------------------------------------------------------------------------------------

NSString*
UnEscapeURL (id url)
{
	if ([url isKindOfClass: [NSURL class]])
		url = [url absoluteString];
	return [url stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
}


//----------------------------------------------------------------------------------------

static inline BOOL
isURLChar (unichar ch)
{
	// Based on table in http://www.opensource.apple.com/darwinsource/10.5.6/CF-476.17/CFURL.c
	if (ch >= 33 && ch <= 126)
		if (ch != '"' && ch != '%' && ch != '<' && ch != '>' &&
						(ch < '[' || ch > '^') && ch != '`' && (ch < '{' || ch == '~'))
			return TRUE;
	return FALSE;
}


//----------------------------------------------------------------------------------------

static inline BOOL
isHexChar (unichar ch)
{
	return (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f');
}


//----------------------------------------------------------------------------------------
// Convert a string to a URL, escaping if necessary.

NSURL*
StringToURL (NSString* urlString, BOOL isDirectory)
{
	int length = [urlString length];
	if (isDirectory && [urlString characterAtIndex: length - 1] != '/')
		urlString = [urlString stringByAppendingString: @"/"];

	// Escape urlString iff it isn't already escaped
	for (int i = 0; i < length; ++i)
	{
		unichar ch = [urlString characterAtIndex: i];
		if (!isURLChar(ch) &&
			(ch != '%' || i >= length - 2 || !isHexChar([urlString characterAtIndex: i + 1]) ||
											 !isHexChar([urlString characterAtIndex: i + 2])))
		{
			urlString = [urlString stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
			break;
		}
	}

	return [NSURL URLWithString: urlString];
}


//----------------------------------------------------------------------------------------
// Returns "<path>" of "<path>/+<name>/*"

NSString*
DeleteLastComponent (NSString* path)
{
	Assert(path != nil);
	unsigned int length0 = [path length], length = length0;

	// Strip trailing '/'s
	while (length > 0 && [path characterAtIndex: length - 1] == '/')
		--length;

	// Strip trailing name
	while (length > 0 && [path characterAtIndex: length - 1] != '/')
		--length;

	// Strip final '/'
	if (length > 0)
		--length;

	if (length == 0 && length0 > 0 && [path characterAtIndex: 0] == '/')
		return @"/";

	return [path substringToIndex: length];
}


//----------------------------------------------------------------------------------------
// Returns "<path>/<name>"

NSString*
AppendPathComponent (NSString* path, NSString* name)
{
	Assert(path != nil);
	Assert(name != nil);
	unsigned int length = [path length];
	if (length == 0)
		return name;

	if ([path characterAtIndex: length - 1] != '/')
		return [path stringByAppendingFormat: @"/%@", name];

	return [path stringByAppendingString: name];
}


//----------------------------------------------------------------------------------------
// Returns "<path>  [Rev. <revision>]"

NSString*
PathWithRevision (id path, id revision)
{
	assert(path != nil);

	path = UnEscapeURL(path);
	if (revision == nil)
		return path;
//	if ([revision isKindOfClass: [NSNumber class]])
//		revision = [revision absoluteString];

	return [NSString stringWithFormat: @"%@  [Rev. %@]", path, revision];
}


//----------------------------------------------------------------------------------------
// Returns "<path>@<revision>"

NSString*
PathPegRevision (id path, id revision)
{
	assert(path != nil);

	if ([path isKindOfClass: [NSURL class]])
		path = [path absoluteString];
	const int lastIndex = [path length] - 1;
	if ([path characterAtIndex: lastIndex] == '/')
		path = [path substringToIndex: lastIndex];
	if (revision == nil)
		return path;

	return [NSString stringWithFormat: @"%@@%@", path, revision];
}


//----------------------------------------------------------------------------------------
// Returns "<path>@<revision>"

NSString*
PathPegRevNum (id path, unsigned int revision)
{
	assert(path != nil);

	if ([path isKindOfClass: [NSURL class]])
		path = [path absoluteString];

	return [NSString stringWithFormat: @"%@@%u", path, revision];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------
// An NSString that responds to [fileSystemRepresentation] by calling [UTF8String].

@interface MsgString : NSString
{
	NSString*	fString;
}
@end


//----------------------------------------------------------------------------------------

@implementation MsgString

- (id) initWithString: (NSString*) aString
{
	self = [super init];
	if (self != nil)
	{
		fString = [aString copy];
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[fString release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (unsigned int) length
{
	return [fString length];
}



//----------------------------------------------------------------------------------------

- (unichar) characterAtIndex: (unsigned) index
{
	return [fString characterAtIndex: index];
}


//----------------------------------------------------------------------------------------

- (void) getCharacters: (unichar*) buffer range: (NSRange) aRange
{
	return [fString getCharacters: buffer range: aRange];
}


//----------------------------------------------------------------------------------------

- (const char*) fileSystemRepresentation
{
	return [fString UTF8String];
}

@end


//----------------------------------------------------------------------------------------
// Return a normalized string that prevents [fileSystemRepresentation] from decomposing it.

NSString*
MessageString (NSString* str)
{
	assert(str != nil);

	return [MsgString stringWithString: [str normalizeEOLs]];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation NSString (MyAdditions)


//----------------------------------------------------------------------------------------

- (NSComparisonResult) compareAlphaNum: (NSString*) aString
{
	return [self compare: aString options: NSCaseInsensitiveSearch | NSNumericSearch];
}


//----------------------------------------------------------------------------------------

+ (NSString*) stringByAddingPercentEscape: (NSString*) url
{
	return [(id) CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef) url, NULL, NULL,
														 kCFStringEncodingUTF8) autorelease];
}


//----------------------------------------------------------------------------------------
// used in MyRepository.m as a workaround to a problem in standard
// [NSString stringByDeletingLastPathComponent] which turns "svn://blah" to "svn:/blah"

- (NSString*) stringByDeletingLastComponent
{
	NSRange r = [[self trimSlashes] rangeOfString: @"/" options: NSBackwardsSearch];

	if ( r.length > 0 )
		return [self substringToIndex: r.location];

	return self;
}


//----------------------------------------------------------------------------------------

- (NSString*) escapeURL
{
	return [(id) CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef) self, NULL, NULL,
														 kCFStringEncodingUTF8) autorelease];
}


//----------------------------------------------------------------------------------------

- (NSString*) trimSlashes
{
	static NSCharacterSet* chSet = nil;
	if (chSet == nil)
		[chSet = [NSCharacterSet characterSetWithCharactersInString: @"/"] retain];

	return [self stringByTrimmingCharactersInSet: chSet];
}


//----------------------------------------------------------------------------------------
// Normalize end-of-line characters.  Also remove any spurious control characters.

- (NSString*) normalizeEOLs
{
	NSMutableString* str = [NSMutableString string];
	[str setString: self];
	[str replaceOccurrencesOfString: @"\r\n" withString: @"\n"
		 options: NSLiteralSearch range: NSMakeRange(0, [str length])];
	[str replaceOccurrencesOfString: @"\r" withString: @"\n"
		 options: NSLiteralSearch range: NSMakeRange(0, [str length])];
	int i;
	for (i = 0; i < 32; ++i)
		if (i != 9 && i != 10 && i != 13)
		{
			unichar ch = i;
			NSString* chStr = [NSString stringWithCharacters: &ch length: sizeof(ch)];
			[str replaceOccurrencesOfString: chStr withString: @""
				 options: NSLiteralSearch range: NSMakeRange(0, [str length])];
		}

	return str;
}


//----------------------------------------------------------------------------------------
// Returns "<self>  [Rev. <revision>]"

- (NSString*) withRevision: (NSString*) revision
{
	if (revision == nil)
		return self;

	return [NSString stringWithFormat: @"%@  [Rev. %@]", self, revision];
}


//----------------------------------------------------------------------------------------
// Returns TRUE if self begins with <str>

- (BOOL) beginsWith: (NSString*) str
{
	Assert(str != nil);
	return [self rangeOfString: str options: NSLiteralSearch | NSAnchoredSearch].location == 0;
}


//----------------------------------------------------------------------------------------
// Returns TRUE if self ends with <str>

- (BOOL) endsWith: (NSString*) str
{
	Assert(str != nil);
	const unsigned flags = NSLiteralSearch | NSAnchoredSearch | NSBackwardsSearch;
	return [self rangeOfString: str options: flags].location != NSNotFound;
}


//----------------------------------------------------------------------------------------
// Returns TRUE if self contains <str>

- (BOOL) contains: (NSString*) str
{
	Assert(str != nil);
	return [self rangeOfString: str options: NSLiteralSearch].location != NSNotFound;
}


@end

//----------------------------------------------------------------------------------------
// End of NSString+MyAdditions.m
