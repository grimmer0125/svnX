	#import "MySvnLogParser.h"


@implementation MySvnLogParser

- (void)dealloc
{
    [self setLogArray: nil];
    [self setTmpDict: nil];
    [self setTmpDict2: nil];
    [self setTmpString: nil];
    [self setPathsArray: nil];

    [super dealloc];
}


-(NSArray *)parseXmlString:(NSString *)string
{
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES]];
	[parser setDelegate:self];

	[self setLogArray:[NSMutableArray array]];
	[parser parse];
	if ( [parser parserError] != nil )
	{
		NSLog(@"Error while parsing log xml : %@", [[parser parserError] localizedDescription]);
	}

	[parser release];
	return [self logArray];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if ( [elementName isEqualToString:@"logentry"] )
	{
		[self setTmpDict:attributeDict];
		[attributeDict setObject:[NSNumber numberWithInt:[[attributeDict objectForKey:@"revision"] intValue]] forKey:@"revision_n"];
		[[self logArray] addObject:[self tmpDict]];
	}
	else
	if ( [elementName isEqualToString:@"date"] )
	{  
		[self setTmpString:[NSMutableString string]];
		[[self tmpDict] setObject:[self tmpString] forKey:@"date"];
	}
	else
	if ( [elementName isEqualToString:@"msg"] )
	{  
		[self setTmpString:[NSMutableString string]];
		[[self tmpDict] setObject:[self tmpString] forKey:@"msg"];
	}
	else
	if ( [elementName isEqualToString:@"author"] )
	{  
		[self setTmpString:[NSMutableString string]];
		[[self tmpDict] setObject:[self tmpString] forKey:@"author"];
	}
	else
	if ( [elementName isEqualToString:@"path"] )
	{  
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:attributeDict];

		if ( [attributeDict objectForKey:@"copyfrom-path"] != nil )
		{
			[attributes setValue:[attributeDict objectForKey:@"copyfrom-path"] forKey:@"copyfrompath"];
			[attributes setValue:[attributeDict objectForKey:@"copyfrom-rev"] forKey:@"copyfromrev"];
		}
		[self setTmpDict2:attributes];
		[self setTmpString:[NSMutableString string]];

		[[self pathsArray] addObject:tmpDict2];
		[[self tmpDict2] setObject:[self tmpString] forKey:@"path"];
	}
	else
		if ( [elementName isEqualToString:@"paths"] )
		{  
			[self setPathsArray:[NSMutableArray array]];
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
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [[self tmpString] appendString:string];
}


// - logArray:
- (NSMutableArray *)logArray {
    return logArray; 
}

// - setLogArray:
- (void)setLogArray:(NSMutableArray *)aLogArray {
    id old = [self logArray];
    logArray = [aLogArray retain];
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


// - pathsArray:
- (NSMutableArray *)pathsArray { return pathsArray; }

	// - setPathsArray:
- (void)setPathsArray:(NSMutableArray *)aPathsArray {
    id old = [self pathsArray];
    pathsArray = [aPathsArray retain];
    [old release];
}

@end
