//----------------------------------------------------------------------------------------
//	CommonUtils.h - Common Cocoa utilities & definitions
//
//	Copyright © Chris, 2003 - 2009.  All rights reserved.
//----------------------------------------------------------------------------------------

#pragma once

#import <Foundation/Foundation.h>


#define	for_each1(en, it)			for (id it; (it = [en nextObject]) != nil; )
#define	for_each_(en, it, coll)		en = [(coll) objectEnumerator]; for_each1(en, it)
#define	for_each(en, it, coll)		NSEnumerator* for_each_(en, it, coll)

static inline UInt64 microseconds()
	{ UnsignedWide t; Microseconds(&t); return *(UInt64*) &t; }


//----------------------------------------------------------------------------------------

typedef CFAbsoluteTime		UTCTime;
#ifndef qConstCStr
	typedef const char*		ConstCStr;
	#define	qConstCStr
#endif
#if __LP64__
	typedef double			GCoord;
#elif 1
	typedef float			GCoord;
#endif

#define	kNSTrue		((id) kCFBooleanTrue)
#define	kNSFalse	((id) kCFBooleanFalse)
#define	NSBool(f)	((f) ? kNSTrue : kNSFalse)


NSUserDefaults*	Preferences				(void);
BOOL			SyncPreference			(void);
id				GetPreference			(NSString* prefKey);
BOOL			GetPreferenceBool		(NSString* prefKey);
int				GetPreferenceInt		(NSString* prefKey);
void			SetPreference			(NSString* prefKey, id prefValue);
void			SetPreferenceBool		(NSString* prefKey, BOOL prefValue);
void			SetPreferenceInt		(NSString* prefKey, int prefValue);

NSInvocation*	MakeCallbackInvocation	(id target, SEL selector);
bool			AltOrShiftPressed		(void);
UTCTime			ParseDateTime			(NSString* date, NSString* time);

void			OpenFiles				(id fileOrFiles);
FSRef*			Folder_Find				(OSType folderType, FSRef* fsRef);
FSRef*			Folder_TemporaryItems	(FSRef* fsRef);
FSRef*			Folder_ChewableItems	(FSRef* fsRef);
BOOL			Folder_IsEqual			(OSType folderType, NSURL* url);
BOOL			Folder_IsTemporaryItems	(NSURL* url);
BOOL			Folder_IsChewableItems	(NSURL* url);


//----------------------------------------------------------------------------------------
// Wrap a selector in an object for sending later.

@interface Message : NSObject
{
	SEL		fMessage;
}

- (id) initWithMessage: (SEL) message;
//- (SEL) message;
- (void) sendTo:     (id) target;
- (void) sendTo:     (id) target
		 withObject: (id) object;
- (void) sendToOnMainThread: (id)   target;
- (void) sendToOnMainThread: (id)   target
		 withObject:         (id)   object
		 waitUntilDone:      (BOOL) wait;

@end


//----------------------------------------------------------------------------------------

@interface NSSavePanel (MakeAvailable)
	- (void) setIncludeNewFolderButton: (BOOL) flag;
@end


//----------------------------------------------------------------------------------------
// End of CommonUtils.h
