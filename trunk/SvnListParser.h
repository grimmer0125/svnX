//
//  SvnListParser.h
//  svnX
//
//  Created by Dominique PERETTI on 05/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SvnListParser : NSObject
{
	NSMutableArray*			entries;
	NSMutableDictionary*	curEntry;
	NSMutableString*		bufString;
}

+ (NSArray*) parseData:   (NSData*)   data;
+ (NSArray*) parseString: (NSString*) string;

- (NSArray*) parseXML:       (NSData*)   data;
- (NSArray*) parseXMLString: (NSString*) string;

@end

