//----------------------------------------------------------------------------------------
//	CommonUtils.h - Common Cocoa utilities & definitions
//
//	Copyright © Chris, 2003 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

//----------------------------------------------------------------------------------------

#define	for_each0(en, it, col, msg)	en = [(col) msg]; for_each1(en, it)
#define	for_each1(en, it)			for (id it; (it = [en nextObject]) != nil; )
#define	for_each_(en, it, col, msg)	NSEnumerator* for_each0(en, it, col, msg)
#define	for_each_obj(en, it, col)	for_each_(en, it, col, objectEnumerator)
#define	for_each_key(en, ke, dict)	for_each_(en, ke, dict, keyEnumerator)


//----------------------------------------------------------------------------------------
// Macros

#if __LP64__
	typedef double				GCoord;
#elif 1
	typedef float				GCoord;
#endif

#if (__APPLE_CC__ > 5400)
	#define	XC3(A, B)			A		// Xcode >= 3
#else
	#define	XC3(A, B)			B		// Xcode < 3
#endif

#define	UTF_8_16(u8,u16)		XC3(@u16, UTF8(u8))
#define	ISA(OBJ, CLASS)			([(OBJ) isKindOfClass: [CLASS class]])

#define	SetVar(var, ref)		do { id old = (var); (var) = [(ref) retain]; \
									 [old release]; } while (0)
#define ResetVar(var)			do { [(var) release]; (var) = nil; } while (0)


//----------------------------------------------------------------------------------------
// Basic Types

typedef const UInt8*			ConstBytePtr;
typedef NSString* const			ConstString;
typedef unsigned int			NSIndex;
typedef CFAbsoluteTime			UTCTime;
#ifndef qConstCStr
	typedef const char*			ConstCStr;
	#define	qConstCStr
#endif

#define	kNSTrue					((id) kCFBooleanTrue)
#define	kNSFalse				((id) kCFBooleanFalse)
#define	NSBool(f)				((f) ? kNSTrue : kNSFalse)
static const NSIndex kIndex0 = 0;

//----------------------------------------------------------------------------------------

NSUserDefaults*	Preferences				(void);
BOOL			SyncPreference			(void);
id				GetPreference			(NSString* prefKey);
BOOL			GetPreferenceBool		(NSString* prefKey);
int				GetPreferenceInt		(NSString* prefKey);
float			GetPreferenceFloat		(NSString* prefKey);
double			GetPreferenceDouble		(NSString* prefKey);
void			SetPreference			(NSString* prefKey, id prefValue);
void			SetPreferenceBool		(NSString* prefKey, BOOL prefValue);
void			SetPreferenceInt		(NSString* prefKey, int prefValue);
void			SetPreferenceFloat		(NSString* prefKey, float prefValue);
void			SetPreferenceDouble		(NSString* prefKey, double prefValue);
void			DeletePreference		(NSString* prefKey);

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

static inline UInt64	microseconds	()
		{ UnsignedWide t; Microseconds(&t); return *(UInt64*) &t; }


//----------------------------------------------------------------------------------------
// Wrap a selector in an object for sending later.

@interface Message : NSObject
{
	SEL		fMessage;
}

+ (id)   message:            (SEL)   message;
- (id)   initWithMessage:    (SEL)   message;
- (SEL)  message;
- (void) sendTo:             (id)   target;
- (void) sendTo:             (id)   target
		 withObject:         (id)   object;
- (void) sendToOnMainThread: (id)   target;
- (void) sendToOnMainThread: (id)   target
		 withObject:         (id)   object
		 waitUntilDone:      (BOOL) wait;

@end	// Message


//----------------------------------------------------------------------------------------

@interface NSSavePanel (MakeAvailable)
	- (void) setIncludeNewFolderButton: (BOOL) flag;
@end


//----------------------------------------------------------------------------------------

@interface AlphaNumSortDesc : NSSortDescriptor
{
@protected
	NSString*	fKey;
	BOOL		fAscending;
}

- (id) initWithKey: (NSString*) key ascending: (BOOL) ascending;

@end	// AlphaNumSortDesc


//----------------------------------------------------------------------------------------
// End of CommonUtils.h
