//----------------------------------------------------------------------------------------
//	DbgUtils.m - Cocoa debugging and error handling
//
//	Copyright © Chris, 2003 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "NSString+MyAdditions.h"
#import "SvnInterface.h"


#if qDebug
//----------------------------------------------------------------------------------------

static UInt32
OSX ()
{
	static SInt32 response;
	if (response == 0 && Gestalt(gestaltSystemVersion, &response) != noErr)
		response = 1;
//	fprintf(stderr, "response=0x%lX\n", response);
	return response;
}


//----------------------------------------------------------------------------------------

static const char*
Prefix ()
{
	static const char* prefix = NULL;
	if (prefix == NULL)
		prefix = (OSX() >= 0x1050) ? "" : kAppName ": ";
	return prefix;
}


//----------------------------------------------------------------------------------------

static FILE*
OS ()
{
	static FILE* file = NULL;
	if (file == NULL)
	{
		if (OSX() >= 0x1050)
		{
		//	file = fopen("/tmp/" kAppName "-dbg.log", "a");
			if (file != NULL)
				fprintf(file, "\n------------------------------------------------------------\n");
		}
		if (file == NULL)
			file = stderr;
		setlinebuf(file);
	}
	return file;
}


//----------------------------------------------------------------------------------------

ConstCStr
LeafName (ConstCStr file)
{
	if (file != NULL)
	{
		ConstCStr s;
		char ch;
		for (s = file; (ch = *s++) != 0; )
			if (ch == '/')
				file = s;
	}

	return file;
}


//----------------------------------------------------------------------------------------

ConstCStr
Demangle (ConstCStr func)
{
	if (func != NULL)
	{
		static char buf[256];
		ConstCStr s;
		char ch;
		for (s = func; (ch = *s++) != 0; )
			if (ch == ' ')
			{
				int i = 0;
				while (i < sizeof(buf) - 1)
				{
					ch = *s++;
					if (ch == ']' || ch == 0)
						break;
					buf[i++] = ch;
				}
				buf[i] = 0;
				func = buf;
				break;
			}
	}

	return func;
}


//----------------------------------------------------------------------------------------

OSStatus
DbgWarnIf (ConstCStr file, int line, ConstCStr func, OSStatus err)
{
	if (err != noErr)
	{
		DbgLogF(file, line, func, "WARNING err=%s=%d", GetMacOSStatusErrorString(err), err);
	}

	return err;
}


//----------------------------------------------------------------------------------------

OSStatus
DbgWarnIfNot (ConstCStr file, int line, ConstCStr func, OSStatus err, OSStatus exclude)
{
	if (err != noErr && err != exclude)
	{
		DbgLogF(file, line, func, "WARNING err=%s=%d", GetMacOSStatusErrorString(err), err);
	}

	return err;
}


//----------------------------------------------------------------------------------------

void
DbgAssert (ConstCStr file, int line, ConstCStr func, ConstCStr expr)
{
	DbgLogF(file, line, func, "ASSERT %s", expr);
	int n = *(int*) 0; (void) n;
	exit(1);
}


//----------------------------------------------------------------------------------------
// return "[<file>:<line>] <func>: "

static ConstCStr
DbgFLF (ConstCStr file, int line, ConstCStr func)
{
	static char buf[250];
	snprintf(buf, sizeof(buf), "%s[%s:%d] %s: ",
			 Prefix(), LeafName(file), line, Demangle(func));
	return buf;
}


//----------------------------------------------------------------------------------------
// Log "[<file>:<line>] <func>: <msg>..."

void
DbgLogF (ConstCStr file, int line, ConstCStr func, ConstCStr fmt, ...)
{
	va_list ap; va_start(ap, fmt);
	NSString* s = [[NSString alloc] initWithFormat: UTF8(fmt) arguments: ap];
	va_end(ap);
	char buf[2048];
	if (!ToUTF8(s, buf, sizeof(buf)))
		buf[0] = 0;
	[s release];
	fprintf(OS(), "%s[%s:%d] %s: %s\n", Prefix(), LeafName(file), line, Demangle(func), buf);
}


//----------------------------------------------------------------------------------------
// Log "[<file>:<line>] <func>: <msg>"

void
DbgLog (ConstCStr file, int line, ConstCStr func, ConstCStr msg)
{
//	fprintf(OS(), "%s[%s:%d] %s: %s\n", Prefix(), LeafName(file), line, Demangle(func), msg);
	DbgLogF(file, line, func, "%s", msg);
}


//----------------------------------------------------------------------------------------
// Log "<msg>..."

void
DbgLogF2 (ConstCStr fmt, ...)
{
	va_list ap; va_start(ap, fmt);
	NSString* s = [[NSString alloc] initWithFormat: UTF8(fmt) arguments: ap];
	va_end(ap);
	char buf[2048];
	if (!ToUTF8(s, buf, sizeof(buf)))
		buf[0] = 0;
	[s release];
	fprintf(OS(), "%s\n", buf);
}


//----------------------------------------------------------------------------------------

static char*
SvnErrorToString (SvnError err, char buf[], size_t bufSize, ConstCStr prefix)
{
	snprintf(buf, bufSize, "%s{[%s:%ld] err=%d %s}",
			 prefix, err->file, err->line, err->apr_err, err->message);
	return buf;
}


//----------------------------------------------------------------------------------------

void
DbgSvnPrint (SvnError err)
{
	if (err)
	{
		char buf[512];
		fprintf(OS(), "%s\n", SvnErrorToString(err, buf, sizeof(buf), "      SvnError="));
	}
}


//----------------------------------------------------------------------------------------

void
DbgSvnThrowIf (SvnError err, ConstCStr file, int line, ConstCStr func)
{
	if (err)
	{
		char buf[512];
		DbgLog(file, line, func, SvnErrorToString(err, buf, sizeof(buf), "THROW SvnError="));
		SvnDoThrow(err);
	}
}


//----------------------------------------------------------------------------------------

void
DbgSvnReportCatch (SvnException* ex, ConstCStr file, int line, ConstCStr func)
{
	char buf[512];
	DbgLog(file, line, func, SvnErrorToString([ex error], buf, sizeof(buf), "CAUGHT SvnError="));
}


//----------------------------------------------------------------------------------------

void
DbgReportCatch (ConstCStr file, int line, ConstCStr func, NSObject* err)
{
	char buf[2048];
	ConstCStr msg = "CAUGHT ???";
	if ([[NSString stringWithFormat: @"CAUGHT %@", err]
			getCString: buf maxLength: sizeof(buf) encoding: NSUTF8StringEncoding])
		msg = buf;
	DbgLog(file, line, func, msg);
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@interface NSObject (Debug)

	- (void) doesNotRecognizeSelector: (SEL) aSelector;

@end	// NSObject (Debug)


//----------------------------------------------------------------------------------------

@implementation NSObject (Debug)

- (void) doesNotRecognizeSelector: (SEL) aSelector
{
	dprintf_("UNREGOCNISED SELECTOR: [%@:0x%X %s]",
			 [self className], self, sel_getName(aSelector));
	int n = *(int*) 0; (void) n;
}

@end	// NSObject (Debug)


//----------------------------------------------------------------------------------------

#endif	// qDebug


//----------------------------------------------------------------------------------------
// End of DbgUtils.m
