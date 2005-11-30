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
	NSMutableArray *logArray;
	NSMutableDictionary *tmpDict;
	NSMutableDictionary *tmpDict2;
	NSMutableString *tmpString;
	NSMutableArray *pathsArray;
}

@end
