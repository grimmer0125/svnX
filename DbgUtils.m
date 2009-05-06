//----------------------------------------------------------------------------------------
//	DbgUtils.m - Cocoa debugging and error handling
//
//	Copyright © Chris, 2003 - 2008.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "NSString+MyAdditions.h"
#import "SvnInterface.h"


#if qDebug
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
	exit(1);
}


//----------------------------------------------------------------------------------------
// return "[<file>:<line>] <func>: "

static ConstCStr
DbgFLF (ConstCStr file, int line, ConstCStr func)
{
	static char buf[250];
	snprintf(buf, sizeof(buf), "%s: [%s:%d] %s: ",
			 kAppName, LeafName(file), line, Demangle(func));
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
	fprintf(stderr, "%s: [%s:%d] %s: %s\n", kAppName, LeafName(file), line, Demangle(func), buf);
}


//----------------------------------------------------------------------------------------
// Log "[<file>:<line>] <func>: <msg>"

void
DbgLog (ConstCStr file, int line, ConstCStr func, ConstCStr msg)
{
//	fprintf(stderr, "%s: [%s:%d] %s: %s\n", kAppName, LeafName(file), line, Demangle(func), msg);
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
	fprintf(stderr, "%s\n", buf);
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
		fprintf(stderr, "%s\n", SvnErrorToString(err, buf, sizeof(buf), "      SvnError="));
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

#endif	// qDebug


//----------------------------------------------------------------------------------------
// End of DbgUtils.m
