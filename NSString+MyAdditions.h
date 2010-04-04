//----------------------------------------------------------------------------------------
//	NSString+MyAdditions.h - Additional NSString methods & utilities.
//
//	Created by Dominique PERETTI on Sun Jul 18 2004.
//	Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//	Copyright © Chris, 2007 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

NSString* UTF8				(const char* aUTF8String);
BOOL      ToUTF8			(NSString* string, char* buf, unsigned int bufSize);
NSString* EscapeURL			(NSString* url);
NSString* UnEscapeURL		(id url);
NSURL*    StringToURL		(NSString* urlString, BOOL isDirectory);
NSString* DeleteLastComponent(NSString* path);
NSString* AppendPathComponent(NSString* path, NSString* name);
NSString* PathWithRevision	(id path, id revision);
NSString* PathPegRevision	(id path, id revision);
NSString* PathPegRevNum		(id path, unsigned int revision);
NSString* MessageString		(NSString* str);

static inline NSString*
UTF8_ (const void* bytes, CFIndex numBytes)
{
	return (NSString*) CFStringCreateWithBytes(NULL, bytes, numBytes, kCFStringEncodingUTF8, FALSE);
}


//----------------------------------------------------------------------------------------
// NSString Additions

@interface NSString (MyAdditions)

+ (NSString*) stringByAddingPercentEscape: (NSString*) url;

- (NSString*) stringByDeletingLastComponent;
- (NSString*) escapeURL;
- (NSString*) trimSlashes;
- (NSString*) normalizeEOLs;
- (NSString*) withRevision: (NSString*) revision;
- (BOOL) beginsWith: (NSString*) str;
- (BOOL) endsWith: (NSString*) str;
- (BOOL) contains: (NSString*) str;

@end


//----------------------------------------------------------------------------------------
// NSTextView Additions

@interface  NSTextView (MyAdditions)

- (void) appendString: (NSString*) string
		 isErrorStyle: (BOOL)      isErrorStyle;

@end

