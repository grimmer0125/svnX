//
//  SvnListParser.h
//  svnX
//
//  Created by Dominique PERETTI on 05/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SvnListParser : NSObject {
	NSMutableArray *listArray;
	NSMutableDictionary *tmpDict;
	NSMutableDictionary *tmpDict2;
	NSMutableString *tmpString;
}

@end
