//
//  NSString+MyAdditions.m
//  svnX
//
//  Created by Dominique PERETTI on Sun Jul 18 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

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

+ (NSString *)stringByAddingPercentEscape:(NSString *)url
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


@end

