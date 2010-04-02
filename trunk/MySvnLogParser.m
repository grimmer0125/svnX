//
//  MySvnLogParser.m
//  svnX
//

#import "MySvnLogParser.h"


@implementation MySvnLogParser

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


+ (NSMutableArray*) parseData: (NSData*) data
{
#if 1
	// HACK to fix 'Error NSXMLParserErrorDomain 1' on encountering control characters
	int length;
	BytePtr p = (BytePtr) [data bytes];
	for (length = [data length]; length--; ++p)
	{
		UInt8 ch = *p;
		if (ch < 32 && ch != 9 && ch != 10 && ch != 13)
			*p = ' ';
	}
#endif
	MySvnLogParser* parser = [[self alloc] init];
	NSMutableArray* result = [parser parseXML: data];
	[parser release];

	return result;
}


+ (NSMutableArray*) parseString: (NSString*) string
{
	return [self parseData: [string dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion: YES]];
}


- (NSMutableArray*) parseXML: (NSData*) data
{
	entry.revision =
	entry.msg      =
	entry.date     =
	entry.author   = @"";
	entry.paths    = nil;
	entries = [NSMutableArray array];

	NSXMLParser* parser = [[NSXMLParser alloc] initWithData: data];
	[parser setDelegate: self];

	[parser parse];
	if ([parser parserError] != nil)
	{
		NSLog(@"Error while parsing log xml: %@", [[parser parserError] localizedDescription]);
	}
	[parser release];

	return entries;
}


- (NSMutableArray*) parseXMLString: (NSString*) string
{
	return [self parseXML: [string dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion: YES]];
}


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
		case 'l':
			if ([elementName isEqualToString: @"logentry"])
			{
				entry.revision = [attributeDict objectForKey: @"revision"];
			}
			break;

		case 'p':
			if ([elementName isEqualToString: @"path"])
			{
				action       = [attributeDict objectForKey: @"action"];
				copyfromPath = [attributeDict objectForKey: @"copyfrom-path"];
				copyfromRev  = copyfromPath ? [attributeDict objectForKey: @"copyfrom-rev"] : nil;
			}
			break;
	}
}


- (void) parser:        (NSXMLParser*) parser
		 didEndElement: (NSString*)    elementName
		 namespaceURI:  (NSString*)    namespaceURI
		 qualifiedName: (NSString*)    qualifiedName
{
	#pragma unused(parser, namespaceURI, qualifiedName)
	switch ([elementName characterAtIndex: 0])
	{
		case 'a':
			if ([elementName isEqualToString: @"author"])
			{
				entry.author = [NSString stringWithString: bufString];
			}
			break;

		case 'd':
			if ([elementName isEqualToString: @"date"])
			{
				entry.date = [NSString stringWithString: bufString];
			}
			break;

		case 'l':
			if ([elementName isEqualToString: @"logentry"])
			{
				id revision_n = [NSNumber numberWithInt: [entry.revision intValue]];
				[entries addObject: [NSDictionary dictionaryWithObjectsAndKeys:
											entry.revision, @"revision",
											revision_n,     @"revision_n",
											entry.msg,      @"msg",
											entry.date,     @"date",
											entry.author,   @"author",
											entry.paths,    @"paths",
											nil]];
				entry.revision =
				entry.msg      =
				entry.date     =
				entry.author   = @"";
				entry.paths    = nil;
			}
			break;

		case 'm':
			if ([elementName isEqualToString: @"msg"])
			{
				entry.msg = [NSString stringWithString: bufString];
			}
			break;

		case 'p':
			if ([elementName isEqualToString: @"path"])
			{
				if (entry.paths == nil)
					entry.paths = [NSMutableArray array];

				[entry.paths addObject: [NSDictionary dictionaryWithObjectsAndKeys:
											[NSString stringWithString: bufString],	@"path",
											action,									@"action",
											copyfromPath,							@"copyfrompath",
											copyfromRev,							@"copyfromrev",
											nil]];
			}
			break;
	}
}


- (void) parser:          (NSXMLParser*) parser
		 foundCharacters: (NSString*)    string
{
	#pragma unused(parser)
	[bufString appendString: string];
}


@end

