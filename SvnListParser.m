//
//  SvnListParser.m
//  svnX
//
//  Created by Dominique PERETTI on 05/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "SvnListParser.h"


@implementation SvnListParser

- (void)dealloc
{
    [self setListArray: nil];
    [self setTmpDict: nil];
    [self setTmpDict2: nil];
    [self setTmpString: nil];

    [super dealloc];
}


-(NSArray *)parseXmlString:(NSString *)string
{
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES]];
	[parser setDelegate:self];

	[self setListArray:[NSMutableArray array]];
	[parser parse];
	if ( [parser parserError] != nil )
	{
		NSLog(@"Error while parsing list xml : %@", [[parser parserError] localizedDescription]);
	}

	[parser release];
	return [self listArray];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if ( [elementName isEqualToString:@"entry"] )
	{
		[self setTmpDict:attributeDict];
		[[self tmpDict] setObject:[NSNumber numberWithBool:([[attributeDict objectForKey:@"kind"] isEqual:@"dir"])] forKey:@"isDir"];
		[[self listArray] addObject:[self tmpDict]];		
	}
	else
	if ( [elementName isEqualToString:@"date"] )
	{  
		[self setTmpString:[NSMutableString string]];
		[[self tmpDict] setObject:[self tmpString] forKey:@"date"];
	}
	else
	if ( [elementName isEqualToString:@"size"] )
	{  
		[self setTmpString:[NSMutableString string]];
		[[self tmpDict] setObject:[self tmpString] forKey:@"size"];
	}
	else
	if ( [elementName isEqualToString:@"name"] )
	{  
		[self setTmpString:[NSMutableString string]];
		[[self tmpDict] setObject:[self tmpString] forKey:@"name"];
		[[self tmpDict] setObject:[self tmpString] forKey:@"displayName"];
	}
	else
	if ( [elementName isEqualToString:@"author"] )
	{  
		[self setTmpString:[NSMutableString string]];
		[[self tmpDict] setObject:[self tmpString] forKey:@"author"];
	}
	else
	if ( [elementName isEqualToString:@"commit"] )
	{  
		[[self tmpDict] setObject:[attributeDict objectForKey:@"revision"] forKey:@"revision"];
	}
	else
	{
		[self setTmpString:nil];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;
{
	if ( [elementName isEqualToString:@"paths"] )
	{  
		[[self tmpDict] setObject:[self pathsArray] forKey:@"paths"];
	}
	else
	if ( [elementName isEqualToString:@"date"] )
	{  
		[[self tmpDict] setObject:[[[self tmpDict] objectForKey:@"date"] substringWithRange:NSMakeRange(11, 8)] forKey:@"time"];
		[[self tmpDict] setObject:[[[self tmpDict] objectForKey:@"date"] substringWithRange:NSMakeRange(0, 10)] forKey:@"date"];
	}

}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [[self tmpString] appendString:[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}


// - listArray:
- (NSMutableArray *)listArray {
    return listArray; 
}

// - setListArray:
- (void)setListArray:(NSMutableArray *)aListArray {
    id old = [self listArray];
    listArray = [aListArray retain];
    [old release];
}

// - tmpDict:
- (NSMutableDictionary *)tmpDict {
    return tmpDict; 
}

// - setTmpDict:
- (void)setTmpDict:(NSMutableDictionary *)atmpDict {
    id old = [self tmpDict];
    tmpDict = [atmpDict retain];
    [old release];
}

// - tmpDict2:
- (NSMutableDictionary *)tmpDict2 { return tmpDict2; }

	// - setTmpDict2:
- (void)setTmpDict2:(NSMutableDictionary *)aTmpDict2 {
    id old = [self tmpDict2];
    tmpDict2 = [aTmpDict2 retain];
    [old release];
}

// - tmpString:
- (NSMutableString *)tmpString {
    return tmpString; 
}

// - setTmpString:
- (void)setTmpString:(NSMutableString *)aTmpString {
    id old = [self tmpString];
    tmpString = [aTmpString retain];
    [old release];
}


@end
