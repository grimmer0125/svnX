//----------------------------------------------------------------------------------------
//  SvnListParser.m - Parse the XML output of `svn list`.
//
//  Created by Dominique PERETTI on 05/01/06.
//  Copyright 2006 Dominique PERETTI. All rights reserved.
//	Copyright © Chris, 2008 - 2009.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "CommonUtils.h"
#import "NSString+MyAdditions.h"
#import "RepoItem.h"
#import "SvnListParser.h"


@implementation SvnListParser

//----------------------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		bufString = [[NSMutableString string] retain];
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[bufString release];

	[super dealloc];
}


//----------------------------------------------------------------------------------------

+ (NSArray*) parseData: (NSData*) data
{
	SvnListParser* parser = [[self alloc] init];
	NSArray* result = [parser parseXML: data];
	[parser release];

	return result;
}


//----------------------------------------------------------------------------------------

+ (NSArray*) parseString: (NSString*) string
{
	return [self parseData: [string dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion: YES]];
}


//----------------------------------------------------------------------------------------

- (NSArray*) parseXML: (NSData*) data
{
	curEntry = nil;
	entries = [NSMutableArray array];

	NSXMLParser* parser = [[NSXMLParser alloc] initWithData: data];
	[parser setDelegate: self];

	[parser parse];
	if ([parser parserError] != nil)
	{
		dprintf("Error while parsing list xml: %@", [[parser parserError] localizedDescription]);
	}
	[parser release];

	return entries;
}


//----------------------------------------------------------------------------------------

- (NSArray*) parseXMLString: (NSString*) string
{
	return [self parseXML: [string dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion: YES]];
}


//----------------------------------------------------------------------------------------

- (void) parser:          (NSXMLParser*)  parser
		 didStartElement: (NSString*)     elementName
		 namespaceURI:    (NSString*)     namespaceURI
		 qualifiedName:   (NSString*)     qualifiedName
		 attributes:      (NSDictionary*) attributeDict
{
	#pragma unused(parser, namespaceURI, qualifiedName)
	[bufString setString: @""];

	switch ([elementName characterAtIndex: 0])
	{
		case 'e':
			if ([elementName isEqualToString: @"entry"])
			{
				curEntry = [RepoItem repoItem: [[attributeDict objectForKey: @"kind"] isEqual: @"dir"]];
				[entries addObject: curEntry];
				[curEntry release];		// Was retained by addObject:
			}
			break;

		case 'c':
			if ([elementName isEqualToString: @"commit"])
			{
				[curEntry setModRev: [[attributeDict objectForKey: @"revision"] intValue]];
			}
			break;
	}
}


//----------------------------------------------------------------------------------------

- (void) parser:        (NSXMLParser*) parser
		 didEndElement: (NSString*)    elementName
		 namespaceURI:  (NSString*)    namespaceURI
		 qualifiedName: (NSString*)    qualifiedName
{
	#pragma unused(parser, namespaceURI, qualifiedName)
	RepoItem* repoItem = curEntry;

	switch ([elementName characterAtIndex: 0])
	{
		case 'a':
			if ([elementName isEqualToString: @"author"])
			{
				[repoItem setAuthor: [NSString stringWithString: bufString]];
			}
			break;

		case 'd':
			if ([elementName isEqualToString: @"date"])
			{
				[repoItem setTime: ParseDateTime([bufString substringToIndex: 10],
												 [bufString substringWithRange: NSMakeRange(11, 8)])];
			}
			break;

		case 'n':
			if ([elementName isEqualToString: @"name"])
			{
				[repoItem setName: [NSString stringWithString: bufString]];
			}
			break;

		case 's':
			if ([elementName isEqualToString: @"size"])
			{
				[repoItem setSize: (SInt64) [bufString doubleValue]];
			}
			break;
	}
}


//----------------------------------------------------------------------------------------

- (void) parser:          (NSXMLParser*) parser
		 foundCharacters: (NSString*)    string
{
	#pragma unused(parser)
	[bufString appendString: string];
}


@end


//----------------------------------------------------------------------------------------
// End of SvnListParser.m
