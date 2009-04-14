//
//  SvnListParser.m
//  svnX
//
//  Created by Dominique PERETTI on 05/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "SvnListParser.h"
#include "CommonUtils.h"


@implementation SvnListParser

- (id) init
{
	self = [super init];
	if (self)
	{
		bufString = [[NSMutableString string] retain];
	}

	return self;
}


- (void) dealloc
{
	[bufString release];

	[super dealloc];
}


+ (NSArray*) parseData: (NSData*) data
{
	SvnListParser* parser = [[self alloc] init];
	NSArray* result = [parser parseXML: data];
	[parser release];

	return result;
}


+ (NSArray*) parseString: (NSString*) string
{
	return [self parseData: [string dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion: YES]];
}


- (NSArray*) parseXML: (NSData*) data
{
	curEntry = nil;
	entries = [NSMutableArray array];

	NSXMLParser* parser = [[NSXMLParser alloc] initWithData: data];
	[parser setDelegate: self];

	[parser parse];
	if ([parser parserError] != nil)
	{
		NSLog(@"Error while parsing list xml: %@", [[parser parserError] localizedDescription]);
	}
	[parser release];

	return entries;
}


- (NSArray*) parseXMLString: (NSString*) string
{
	return [self parseXML: [string dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion: YES]];
}


- (void) parser:          (NSXMLParser*)  parser
		 didStartElement: (NSString*)     elementName
		 namespaceURI:    (NSString*)     namespaceURI
		 qualifiedName:   (NSString*)     qualifiedName
		 attributes:      (NSDictionary*) attributeDict
{
	[bufString setString: @""];

	switch ([elementName characterAtIndex: 0])
	{
		case 'e':
			if ([elementName isEqualToString: @"entry"])
			{
				NSMutableDictionary* dict = [NSMutableDictionary dictionary];
				curEntry = dict;
				[entries addObject: dict];
				BOOL isDir = [[attributeDict objectForKey: @"kind"] isEqual: @"dir"];
				[dict setObject: NSBool(isDir) forKey: @"isDir"];
				[dict setObject: @"" forKey: @"author"];	// Somtimes it's missing from the XML
			}
			break;

		case 'c':
			if ([elementName isEqualToString: @"commit"])
			{
				[curEntry setObject: [attributeDict objectForKey: @"revision"] forKey: @"revision"];
			}
			break;
	}
}


- (void) parser:        (NSXMLParser*) parser
		 didEndElement: (NSString*)    elementName
		 namespaceURI:  (NSString*)    namespaceURI
		 qualifiedName: (NSString*)    qName
{
	NSMutableDictionary* dict = curEntry;

	switch ([elementName characterAtIndex: 0])
	{
		case 'a':
			if ([elementName isEqualToString: @"author"])
			{
				[dict setObject: [NSString stringWithString: bufString] forKey: @"author"];
			}
			break;

		case 'd':
			if ([elementName isEqualToString: @"date"])
			{
				NSString* date = bufString;		// YYYY-MM-DDTHH:MM:SS.sss
				[dict setObject: [date substringWithRange: NSMakeRange(11, 8)] forKey: @"time"];
				[dict setObject: [date substringWithRange: NSMakeRange(0, 10)] forKey: @"date"];
			}
			break;

		case 'n':
			if ([elementName isEqualToString: @"name"])
			{
				NSString* name = [NSString stringWithString: bufString];
				[dict setObject: name forKey: @"name"];
			}
			break;

		case 's':
			if ([elementName isEqualToString: @"size"])
			{
				[dict setObject: [NSString stringWithString: bufString] forKey: @"size"];
			}
			break;
	}
}


- (void) parser:          (NSXMLParser*) parser
		 foundCharacters: (NSString*)    string
{
	[bufString appendString: string];
}


@end

