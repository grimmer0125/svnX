//
//  NSString+MyAdditions.h
//  svnX
//
//  Created by Dominique PERETTI on Sun Jul 18 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* UTF8				(const char* aUTF8String);
BOOL      ToUTF8			(NSString* string, char* buf, unsigned int bufSize);
NSString* EscapeURL			(NSString* url);
NSString* UnEscapeURL		(id url);
NSString* PathWithRevision	(id path, id revision);
NSString* PathPegRevision	(id path, id revision);
NSString* PathPegRevNum		(id path, unsigned int revision);
NSString* MessageString		(NSString* str);


//----------------------------------------------------------------------------------------
// NSString Additions

@interface NSString (MyAdditions)

+ (NSString*) stringByAddingPercentEscape: (NSString*) url;

- (NSString*) stringByDeletingLastComponent;
- (NSString*) escapeURL;
- (NSString*) trimSlashes;
- (NSString*) normalizeEOLs;
- (NSString*) withRevision: (NSString*) revision;

@end


//----------------------------------------------------------------------------------------
// NSTextView Additions

@interface  NSTextView (MyAdditions)

- (void) appendString: (NSString*) string
		 isErrorStyle: (BOOL)      isErrorStyle;

@end

