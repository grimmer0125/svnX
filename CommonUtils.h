//----------------------------------------------------------------------------------------
//	CommonUtils.h - Common Cocoa utilities & definitions
//
//	Copyright © Chris, 2003 - 2008.  All rights reserved.
//----------------------------------------------------------------------------------------

#pragma once

#include <Foundation/Foundation.h>


#define	for_each1(en, it)			for (id it; (it = [en nextObject]) != nil; )
#define	for_each_(en, it, coll)		en = [(coll) objectEnumerator]; for_each1(en, it)
#define	for_each(en, it, coll)		NSEnumerator* for_each_(en, it, coll)


//----------------------------------------------------------------------------------------


typedef const char*			ConstCStr;
#if __LP64__
	typedef double			GCoord;
#elif 1
	typedef float			GCoord;
#endif

#define	kNSTrue		((id) kCFBooleanTrue)
#define	kNSFalse	((id) kCFBooleanFalse)
#define	NSBool(f)	((f) ? kNSTrue : kNSFalse)


id				GetPreference			(NSString* prefKey);
BOOL			GetPreferenceBool		(NSString* prefKey);
int				GetPreferenceInt		(NSString* prefKey);
void			SetPreference			(NSString* prefKey, id prefValue);

NSInvocation*	MakeCallbackInvocation	(id target, SEL selector);

bool			AltOrShiftPressed		();


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
