//----------------------------------------------------------------------------------------
//	SvnLogReport.m - Generate & display in HTML a Subversion log report
//
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "CommonUtils.h"
#import "SvnLogReport.h"
#import "MyRepository.h"
#import "MySvn.h"
#import "NSString+MyAdditions.h"
#import "Tasks.h"
#import <WebKit/WebKit.h>
#import <unistd.h>


//----------------------------------------------------------------------------------------

static NSMutableData*
Append (NSMutableData* data, NSString* src)
{
	[data appendData: [src dataUsingEncoding: NSUTF8StringEncoding]];
	return data;
}


//----------------------------------------------------------------------------------------

static NSXMLNode*
AddAttribute (NSXMLElement* node, NSString* name, NSString* value)
{
	NSXMLNode* attr = [NSXMLNode attributeWithName: name stringValue: value];
	[node addAttribute: attr];
	return attr;
}


//----------------------------------------------------------------------------------------

static NSXMLNode*
CopyAttribute (NSXMLElement* node, NSDictionary* dict, NSString* name)
{
	return AddAttribute(node, name, [dict objectForKey: name]);
}


//----------------------------------------------------------------------------------------

static NSXMLElement*
AddChild (NSXMLElement* node, NSString* name, NSString* value)
{
	NSXMLElement* child = [NSXMLNode elementWithName: name stringValue: value];
	[node addChild: child];
	return child;
}


//----------------------------------------------------------------------------------------

static NSXMLElement*
CopyChild (NSXMLElement* node, NSDictionary* dict, NSString* name)
{
	return AddChild(node, name, [dict objectForKey: name]);
}


//----------------------------------------------------------------------------------------

static NSXMLDocument*
LogToXML (NSArray* logItems, bool includePaths, int limit, bool reverseOrder)
{
	NSXMLElement* const root = [NSXMLNode elementWithName: @"log"];
	NSXMLDocument* const doc = [NSXMLNode documentWithRootElement: root];
	[doc setVersion: @"1.0"];
	NSEnumerator* en = reverseOrder ? [logItems reverseObjectEnumerator]
									: [logItems objectEnumerator];
	for_each1(en, it)
	{
		NSXMLElement* const entry = [NSXMLNode elementWithName: @"logentry"];
		[root addChild: entry];
		CopyAttribute(entry, it, @"revision");
		CopyChild(entry, it, @"author");
		CopyChild(entry, it, @"date");
		CopyChild(entry, it, @"msg");
		if (includePaths)
		{
			NSArray* const pathObjs = [it objectForKey: @"paths"];
			if (pathObjs != nil)
			{
				NSXMLElement* const paths = [NSXMLNode elementWithName: @"paths"];
				[entry addChild: paths];
				for_each_obj(en2, obj, pathObjs)
				{
					NSXMLElement* const path = CopyChild(paths, obj, @"path");
					CopyAttribute(path, obj, @"action");
					NSString* value;
					if ((value = [obj objectForKey: @"copyfrompath"]) != nil)
					{
						AddAttribute(path, @"copyfrom-rev", [obj objectForKey: @"copyfromrev"]);
						AddAttribute(path, @"copyfrom-path", value);
					}
				}
			}
		}

		if (--limit == 0)
			break;
	}

	return doc;
}


//----------------------------------------------------------------------------------------

#define	qUseNSOutputStream	0

#if qUseNSOutputStream

#define	write(os, data, length)		write_os(os, data, length)
typedef NSOutputStream* OS;


static void
write (OS os, const void* data, int length)
{
	[os write: (const uint8_t*) data maxLength: length];
}

#else
typedef int OS;
#endif


//----------------------------------------------------------------------------------------

static void
EncodeXML (OS os, const char* str)
{
	uint8_t buf[4096], *dst = buf;
	int ch;
	while ((ch = *str++) != 0)
	{
		// By default we have to encode at least '<', '>', '&' and '"'.
		switch (ch)
		{
			case '<':
				*dst++ = '&';
				*dst++ = 'l';
				*dst++ = 't';
				*dst++ = ';';
				break;

			case '>':
				*dst++ = '&';
				*dst++ = 'g';
				*dst++ = 't';
				*dst++ = ';';
				break;

			case '&':
				*dst++ = '&';
				*dst++ = 'a';
				*dst++ = 'm';
				*dst++ = 'p';
				*dst++ = ';';
				break;

			case '"':
				*dst++ = '&';
				*dst++ = 'q';
				*dst++ = 'u';
				*dst++ = 'o';
				*dst++ = 't';
				*dst++ = ';';
				break;

			case '\r':
			/*	*dst++ = '&';
				*dst++ = '#';
				*dst++ = '1';
				*dst++ = '3';
				*dst++ = ';';
				break;*/
				ch = '\n';

			default:
				*dst++ = ch;
				break;
		}

		if (dst >= &buf[sizeof(buf) - 8])
		{
			write(os, buf, dst - buf);
			dst = buf;
		}
	}

	if (dst != buf)
	{
		write(os, buf, dst - buf);
	}
}


//----------------------------------------------------------------------------------------

static void
EscapeAttr (OS os, const char* str)
{
	EncodeXML(os, str);
}


//----------------------------------------------------------------------------------------

static void
EscapeText (OS os, const char* str)
{
	uint8_t buf[4096], *dst = buf;
	int ch;
	while ((ch = *str++) != 0)
	{
		// By default we have to encode at least '<', '>', '&' and '"'.
		switch (ch)
		{
			case '<':
				*dst++ = '&';
				*dst++ = 'l';
				*dst++ = 't';
				*dst++ = ';';
				break;

			case '&':
				*dst++ = '&';
				*dst++ = 'a';
				*dst++ = 'm';
				*dst++ = 'p';
				*dst++ = ';';
				break;

			case '\r':
				ch = '\n';

			default:
				*dst++ = ch;
				break;
		}

		if (dst >= &buf[sizeof(buf) - 8])
		{
			write(os, buf, dst - buf);
			dst = buf;
		}
	}

	if (dst != buf)
	{
		write(os, buf, dst - buf);
	}
}


//----------------------------------------------------------------------------------------

static void
Write (OS os, const char* str)
{
	write(os, str, strlen(str));
}


//----------------------------------------------------------------------------------------

static void
WriteString (OS os, NSString* str)
{
	Write(os, [str UTF8String]);
}


//----------------------------------------------------------------------------------------

static void
WriteAttr (OS os, NSString* text)
{
	char buf[2048];
	EscapeAttr(os, ToUTF8(text, buf, sizeof(buf)) ? buf : [text UTF8String]);
}


//----------------------------------------------------------------------------------------

static void
WriteText (OS os, NSString* text)
{
	char buf[2048];
	EscapeText(os, ToUTF8(text, buf, sizeof(buf)) ? buf : [text UTF8String]);
}


#if 0
//----------------------------------------------------------------------------------------

static void
WriteF (OS os, NSString* format, ...)
{
	va_list ap;
	va_start(ap, format);
	WriteString(os, [[[NSString alloc] autorelease] initWithFormat: format arguments: ap]);
	va_end(ap);
}


//----------------------------------------------------------------------------------------

static void
WriteElement (OS os, NSDictionary* dict, NSString* name)
{
	WriteF(os, @"<%@>", name);
	WriteText(os, [dict objectForKey: name]);
	WriteF(os, @"</%@>", name);
}
#endif


//----------------------------------------------------------------------------------------

static void
writef (OS os, const char* format, ...)
{
	char buf[2048];
	va_list ap;
	va_start(ap, format);
	int len = vsnprintf(buf, sizeof(buf), format, ap);
	write(os, buf, len);
	va_end(ap);
}


//----------------------------------------------------------------------------------------

#if 0
static void
writekey (OS os, NSDictionary* dict, NSString* name)
{
	char buf[64];
	if (ToUTF8(name, buf, sizeof(buf)))
	{
		writef(os, "<%s>", buf);
		WriteText(os, [dict objectForKey: name]);
		writef(os, "</%s>", buf);
	}
	else
		WriteElement(os, dict, name);
}
#endif


//----------------------------------------------------------------------------------------

static void
writeelement (OS os, const char* name, NSDictionary* dict, NSString* key)
{
#if 0
	writef(os, "<%s>", name);
	WriteText(os, [dict objectForKey: key]);
	writef(os, "</%s>", name);
#elif 1
	uint8_t buf[4096], *dst = buf;
	char txt[2048];
	int ch;

	// <name>
	*dst++ = '<';
	const char* src = name;
	while ((ch = *src++) != 0)
		*dst++ = ch;
	*dst++ = '>';
//	Assert(dst - buf < 30);

	// escaped(dict.key)
	NSString* text = [dict objectForKey: key];
	src = ToUTF8(text, txt, sizeof(txt)) ? txt : [text UTF8String];
	while ((ch = *src++) != 0)
	{
		switch (ch)		// Escape '<' and '&'.
		{
			case '<':
				*dst++ = '&';
				*dst++ = 'l';
				*dst++ = 't';
				*dst++ = ';';
				break;

			case '&':
				*dst++ = '&';
				*dst++ = 'a';
				*dst++ = 'm';
				*dst++ = 'p';
				*dst++ = ';';
				break;

			case '\r':
				ch = '\n';

			default:
				*dst++ = ch;
				break;
		}

		if (dst >= &buf[sizeof(buf) - 8])
		{
			write(os, buf, dst - buf);
			dst = buf;
		}
	}

	// </name>
	*dst++ = '<';
	*dst++ = '/';
	src = name;
	while ((ch = *src++) != 0)
		*dst++ = ch;
	*dst++ = '>';

	write(os, buf, dst - buf);
#endif
}


//----------------------------------------------------------------------------------------

static void
WriteXMLLog (NSArray* logItems, bool includePaths, int limit, bool reverseOrder, NSString* xmlPath)
{
//	const UInt64 t0 = microseconds();
#if 0
	NSXMLDocument* doc = LogToXML(logItems, includePaths, limit, reverseOrder);
	[[doc XMLData/*WithOptions: NSXMLNodePrettyPrint*/] writeToFile: xmlPath atomically: false];
#elif 1
	#define	WRITE(cstr)		write(os, cstr, sizeof(cstr) - 1)
	const id autoPool = [[NSAutoreleasePool alloc] init];
  #if qUseNSOutputStream
	const OS os = [NSOutputStream outputStreamToFileAtPath: xmlPath append: NO];
	[os open];
  #else
	[[NSFileManager defaultManager] createFileAtPath: xmlPath contents: [NSData data] attributes: nil];
	const NSFileHandle* file = [NSFileHandle fileHandleForWritingAtPath: xmlPath];
	const OS os = [file fileDescriptor];
  #endif

	const id sortDescriptors = includePaths ? [NSArray arrayWithObject:
						[[[AlphaNumSortDesc alloc] initWithKey: @"path" ascending: YES] autorelease]]
											: nil;
	WRITE("<?xml version=\"1.0\"?><log>");
	NSEnumerator* en = reverseOrder ? [logItems reverseObjectEnumerator]
									: [logItems objectEnumerator];
	char act[8], rev[16];
	for_each1(en, it)
	{
		ToUTF8([it objectForKey: @"revision"], rev, sizeof(rev));
		writef(os, "<logentry revision=\"%s\">", rev);
		writeelement(os, "author", it, @"author");
		writeelement(os, "date",   it, @"date");
		writeelement(os, "msg",    it, @"msg");

		if (includePaths)
		{
			NSArray* const pathObjs = [it objectForKey: @"paths"];
			if (pathObjs != nil)
			{
				const id autoPool = [[NSAutoreleasePool alloc] init];
				WRITE("<paths>\n");
				for_each_obj(en2, obj, [pathObjs sortedArrayUsingDescriptors: sortDescriptors])
				{
					ToUTF8([obj objectForKey: @"action"], act, sizeof(act));
					NSString* value;
					if ((value = [obj objectForKey: @"copyfrompath"]) != nil)
					{
						ToUTF8([obj objectForKey: @"copyfromrev"], rev, sizeof(rev));
						writef(os, "<path action=\"%s\" copyfrom-rev=\"%s\" copyfrom-path=\"", act, rev);
						WriteAttr(os, value);
						WRITE("\">");
					}
					else
					{
						writef(os, "<path action=\"%s\">", act);
					}
					WriteText(os, [obj objectForKey: @"path"]);
					WRITE("</path>\n");
				}
				WRITE("</paths>");
				[autoPool release];
			}
		}
		WRITE("</logentry>\n");

		if (--limit == 0)
			break;
	}
	WRITE("</log>");
  #if qUseNSOutputStream
	[os close];
  #else
	[file closeFile];
  #endif
	[autoPool release];
	#undef	WRITE
#endif
//	dprintf("%g ms", (microseconds() - t0) * 1e-3);
}


//========================================================================================
#pragma mark	-
//========================================================================================

@interface SvnLogToolbar : NSObject
{
	IBOutlet SvnLogReport*	fReport;

@private
	NSMutableDictionary*	fItems;
}
@end	// SvnLogToolbar


//----------------------------------------------------------------------------------------

@implementation SvnLogToolbar


- (void) dealloc
{
	[fItems release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (NSToolbarItem*) createItem: (NSString*) itsID
				   label:      (NSString*) itsLabel
				   help:       (NSString*) itsHelp
{
	NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier: itsID];
	[item setPaletteLabel: itsLabel];
	[item setLabel: itsLabel];
	if (itsHelp)
		[item setToolTip: itsHelp];
	[item setTarget: fReport];
	[item setAction: NSSelectorFromString([itsID stringByAppendingString: @":"])];
	[item setImage: [NSImage imageNamed: itsID]];
	[fItems setObject: item forKey: itsID];
	[item release];
	return item;
}


//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
	fItems = [NSMutableDictionary new];

	[self createItem: @"textSmaller" label: @"Smaller" help: @"Decrease font size."];
	[self createItem: @"textBigger"  label: @"Bigger"  help: @"Increase font size."];

	NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier: @"SvnLogToolbar"];
	[toolbar setDelegate: self];
	[toolbar setAllowsUserCustomization: YES];
	[toolbar setAutosavesConfiguration: YES];
	[toolbar setDisplayMode: NSToolbarDisplayModeDefault];
	[toolbar setSizeMode: NSToolbarSizeModeDefault];
	[[fReport window] setToolbar: toolbar];
	[toolbar release];
}


//----------------------------------------------------------------------------------------

- (NSToolbarItem*) toolbar:                   (NSToolbar*) toolbar
				   itemForItemIdentifier:     (NSString*)  itemIdentifier
				   willBeInsertedIntoToolbar: (BOOL)       flag
{
	#pragma unused(toolbar, flag)
	return [fItems objectForKey: itemIdentifier];
}


//----------------------------------------------------------------------------------------

- (NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar*) toolbar
{
	#pragma unused(toolbar)
	return [NSArray arrayWithObjects:
					NSToolbarSeparatorItemIdentifier,
					NSToolbarSpaceItemIdentifier,
					NSToolbarFlexibleSpaceItemIdentifier,
					NSToolbarPrintItemIdentifier,
					@"textSmaller",
					@"textBigger",
					nil];
}


//----------------------------------------------------------------------------------------

- (NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar*) toolbar
{
	#pragma unused(toolbar)
	return [NSArray arrayWithObjects:
					@"textSmaller",
					@"textBigger",
					NSToolbarFlexibleSpaceItemIdentifier,
					NSToolbarPrintItemIdentifier,
					nil];
}


//----------------------------------------------------------------------------------------

- (void) toolbarWillAddItem: (NSNotification*) notification
{
	NSToolbarItem* item = [[notification userInfo] objectForKey: @"item"];
	if ([[item itemIdentifier] isEqual: NSToolbarPrintItemIdentifier])
		[item setTarget: fReport];
}


//----------------------------------------------------------------------------------------

@end	// SvnLogToolbar


//========================================================================================
#pragma mark	-
//========================================================================================

enum {
	kUnlimitedLogLimit	=	0,
	kDefaultLogLimit	=	kUnlimitedLogLimit,
	kDefaultPageLength	=	500
};

static ConstString kDialogId = @"BrowseLog";


@implementation SvnLogReport

//----------------------------------------------------------------------------------------

- (void) taskCompleted: (Task*) task
		 object:        (id)    object
{
	#pragma unused(task)
	if (![fWindow isVisible])
		return;

//	static UInt64 t0;
	if (object != nil)	// svn task
	{
//		t0 = microseconds();
		[[Task taskWithDelegate: self object: nil]
				launch:    @"/usr/bin/xsltproc"
				arguments: object];
	}
	else				// xsltproc task
	{
//		dprintf("%g ms", (microseconds() - t0) * 1e-3);
		[[fLogView mainFrame] reload];
	//	[fBusyIndicator stopAnimation: self];
	//	[fBusyIndicator setHidden: YES];
	}
}


//----------------------------------------------------------------------------------------

- (void) createReport:  (NSString*) fileURL
		 document:      (MyRepository*) fDocument
		 logItems:      (NSArray*)  logItems
		 revision:      (NSString*) revision
		 limit:         (int)       limit
		 pageLength:    (int)       pageLength
		 verbose:       (BOOL)      verbose
		 stopOnCopy:    (BOOL)      stopOnCopy
		 relativeDates: (BOOL)      relativeDates
		 reverseOrder:  (BOOL)      reverseOrder
{
	Assert(fWindow != nil);
	Assert(fLogView != nil);

	if (revision == nil)
		revision = @"HEAD";
	[fWindow setTitle: PathWithRevision(fileURL, revision)];
	[fWindow makeKeyAndOrderFront: nil];

//	[fBusyIndicator setHidden: NO];
//	[fBusyIndicator startAnimation: self];
//	NSLog(@"svn log --xml -v -r %@ '%@'", revision, fileURL);
	const pid_t pid = getpid();
	static unsigned int uid = 0;
	++uid;
	ConstString tmpXmlPath  = [NSString stringWithFormat: @"/tmp/svnx%u-log%u.xml", pid, uid],
				tmpHtmlBase = [NSString stringWithFormat: @"svnx%u-log%u-", pid, uid],
				tmpHtmlPath = [NSString stringWithFormat: @"/tmp/%@1.html", tmpHtmlBase],
				pageLen     = [NSString stringWithFormat: @"%u", pageLength];

	NSBundle* bundle = [NSBundle mainBundle];
	ConstString srcXslPath = [bundle pathForResource: @"svnlog" ofType: @"xsl"];
//	ConstString srcCssPath = [bundle pathForResource: @"svnlog" ofType: @"css"];

	NSArray* args2 = [NSArray arrayWithObjects: @"--stringparam", @"file", fileURL,
												@"--stringparam", @"revision", revision,
												@"--stringparam", @"base", [bundle resourcePath],
												@"--stringparam", @"F", tmpHtmlBase,
												@"--param", @"page-len", pageLen,
												@"--param", @"age", (relativeDates ? @"1" : @"0"),
												@"-o", @"/tmp/",
												srcXslPath, tmpXmlPath, nil];

	[@"Working..." writeToFile: tmpHtmlPath atomically: false];

	if (logItems != nil)
	{
		WriteXMLLog(logItems, verbose, limit, reverseOrder, tmpXmlPath);

		[self taskCompleted: nil object: args2];
	}
	else
	{
		id objs[20];
		int count = [fDocument svnStdOptions: objs];
		objs[count++] = @"log";
		objs[count++] = @"--xml";
		objs[count++] = [NSString stringWithFormat: (reverseOrder ? @"-r1:%@" : @"-r%@:1"), revision];
		objs[count++] = PathPegRevision(fileURL, revision);
		if (verbose)
			objs[count++] = @"-v";
		if (stopOnCopy)
			objs[count++] = @"--stop-on-copy";
		if (limit != kUnlimitedLogLimit)
		{
			objs[count++] = @"--limit";
			objs[count++] = [NSString stringWithFormat: @"%u", limit];
		}
		Assert(count < 18);
		NSArray* args = [NSArray arrayWithObjects: objs count: count];

		// TO_DO: store task & kill it if window closes before completion
		Task* task = [Task taskWithDelegate: self object: args2];
		[@"?" writeToFile: tmpXmlPath atomically: false];
		[task launch: SvnCmdPath() arguments: args stdOutput: tmpXmlPath];
	}

	[[fLogView mainFrame] loadRequest: [NSURLRequest requestWithURL:
											[NSURL fileURLWithPath: tmpHtmlPath]]];
	[[fLogView mainFrame] performSelector: @selector(reload) withObject: nil afterDelay: 2];
}


//----------------------------------------------------------------------------------------

- (void) textSmaller: (id) sender
{
	if ([fLogView canMakeTextSmaller])
		[fLogView makeTextSmaller: sender];
}


//----------------------------------------------------------------------------------------

- (void) textBigger: (id) sender
{
	if ([fLogView canMakeTextLarger])
		[fLogView makeTextLarger: sender];
}


//----------------------------------------------------------------------------------------

- (void) doPrintDocument
{
	NSView* view = [[[fLogView mainFrame] frameView] documentView];
	NSPrintOperation* printOperation = [NSPrintOperation printOperationWithView: view];
	[printOperation runOperationModalForWindow: fWindow delegate: nil
					didRunSelector: NULL contextInfo: NULL];
}


//----------------------------------------------------------------------------------------

- (void) printDocument: (id) sender
{
	#pragma unused(sender)
	[self performSelector: @selector(doPrintDocument) withObject: nil afterDelay: 0];
}


//----------------------------------------------------------------------------------------
// Optional method:  This message is sent to us since we are the target of some toolbar item actions
// (for example:  of the save items action)

ConstString SaveDocToolbarItemIdentifier   = @"svnX.save",
			SearchDocToolbarItemIdentifier = @"svnX.search";

- (BOOL) validateToolbarItem: (NSToolbarItem*) toolbarItem
{
	bool enable = !false;
	ConstString itemID = [toolbarItem itemIdentifier];
	if ([itemID isEqual: SaveDocToolbarItemIdentifier])
		enable = true;	//[self isDocumentEdited];
	else if ([itemID isEqual: NSToolbarPrintItemIdentifier])
		enable = true;
	else if ([itemID isEqual: SearchDocToolbarItemIdentifier])
		enable = true;	//[[[documentTextView textStorage] string] length] > 0;

	return enable;
}


//----------------------------------------------------------------------------------------

- (NSWindow*) window
{
	return fWindow;
}


//----------------------------------------------------------------------------------------

+ (void) createFor:     (MyRepository*) document
		 url:           (NSString*) fileURL
		 logItems:      (NSArray*)  logItems
		 revision:      (NSString*) revision
		 limit:         (int)       limit
		 pageLength:    (int)       pageLength
		 verbose:       (BOOL)      verbose
		 stopOnCopy:    (BOOL)      stopOnCopy
		 relativeDates: (BOOL)      relativeDates
		 reverseOrder:  (BOOL)      reverseOrder
{
	if (pageLength <= 0)
		pageLength = kDefaultPageLength;
	SvnLogReport* obj = [self new];
	if ([NSBundle loadNibNamed: kDialogId owner: obj])
	{
		[obj createReport: fileURL
				 document: document
				 logItems: logItems
				 revision: revision
					limit: limit
			   pageLength: pageLength
				  verbose: verbose
			   stopOnCopy: stopOnCopy
			relativeDates: relativeDates
			 reverseOrder: reverseOrder];
	}
	else
		[obj release];
}


//----------------------------------------------------------------------------------------

@end	// SvnLogReport


//----------------------------------------------------------------------------------------
// End of SvnLogReport.m
