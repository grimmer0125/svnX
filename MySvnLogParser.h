//
//  MySvnLogParser.h
//  svnX
//
//  Created by Dominique PERETTI on Mon Jul 12 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MySvnLogParser : NSObject
{
	struct {
		NSString*			revision;
		NSString*			msg;
		NSString*			date;
		NSString*			author;
		NSMutableArray*		paths;
	} entry;
	NSMutableArray*			entries;
	id						action,			// path attributes
							copyfromPath,
							copyfromRev;
	NSMutableString*		bufString;
}

+ (NSMutableArray*) parseData:   (NSData*)   data;
+ (NSMutableArray*) parseString: (NSString*) string;

- (NSMutableArray*) parseXML:       (NSData*)   data;
- (NSMutableArray*) parseXMLString: (NSString*) string;

@end

