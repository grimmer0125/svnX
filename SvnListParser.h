//----------------------------------------------------------------------------------------
//  SvnListParser.h - Parse the XML output of `svn list`.
//
//  Created by Dominique PERETTI on 05/01/06.
//  Copyright 2006 Dominique PERETTI. All rights reserved.
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>


@class RepoItem;

@interface SvnListParser : NSObject
{
	NSMutableArray*			entries;
	RepoItem*				curEntry;
	NSMutableString*		bufString;
}

+ (NSArray*) parseData:   (NSData*)   data;
+ (NSArray*) parseString: (NSString*) string;

- (NSArray*) parseXML:       (NSData*)   data;
- (NSArray*) parseXMLString: (NSString*) string;

@end

