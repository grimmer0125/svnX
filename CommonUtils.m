//----------------------------------------------------------------------------------------
//	CommonUtils.m - Common Cocoa utilities
//
//	Copyright © Chris, 2003 - 2009.  All rights reserved.
//----------------------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "CommonUtils.h"
#import "MySVN.h"
#import "Tasks.h"


//----------------------------------------------------------------------------------------

NSUserDefaults*
Preferences ()
{
	static id prefs = nil;
	if (prefs == nil)
		prefs = [NSUserDefaults standardUserDefaults];
	return prefs;
}


//----------------------------------------------------------------------------------------

BOOL
SyncPreference ()
{
	return [Preferences() synchronize];
}


//----------------------------------------------------------------------------------------

id
GetPreference (NSString* prefKey)
{
	return [Preferences() objectForKey: prefKey];
}


//----------------------------------------------------------------------------------------

BOOL
GetPreferenceBool (NSString* prefKey)
{
	return [Preferences() boolForKey: prefKey];
}


//----------------------------------------------------------------------------------------

int
GetPreferenceInt (NSString* prefKey)
{
	return [Preferences() integerForKey: prefKey];
}


//----------------------------------------------------------------------------------------

void
SetPreference (NSString* prefKey, id prefValue)
{
	[Preferences() setObject: prefValue forKey: prefKey];
}


//----------------------------------------------------------------------------------------

void
SetPreferenceBool (NSString* prefKey, BOOL prefValue)
{
	[Preferences() setBool: prefValue forKey: prefKey];
}


//----------------------------------------------------------------------------------------

void
SetPreferenceInt (NSString* prefKey, int prefValue)
{
	[Preferences() setInteger: prefValue forKey: prefKey];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

NSInvocation*
MakeCallbackInvocation (id target, SEL selector)
{
#if qDebug
	NSMethodSignature* methodSig = [[target class] instanceMethodSignatureForSelector: selector];
	if (methodSig == nil)
		dprintf("(%@ '@%s'): ERROR: no method found", target, sel_getName(selector));
	Assert(methodSig != nil);
	NSInvocation* callback = [NSInvocation invocationWithMethodSignature: methodSig];
#else
	NSInvocation* callback = [NSInvocation invocationWithMethodSignature:
									[[target class] instanceMethodSignatureForSelector: selector]];
#endif
	[callback setSelector: selector];
	[callback setTarget:   target];

	return callback;
}


//----------------------------------------------------------------------------------------

bool
AltOrShiftPressed ()
{
	return ([[NSApp currentEvent] modifierFlags] & (NSAlternateKeyMask | NSShiftKeyMask)) != 0;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------
// Parse date & time strings of the format: date="YYYY-MM-DD" & time="HH:MM:SS"

UTCTime
ParseDateTime (NSString* date, NSString* time)
{
	return [[NSDate dateWithString: [NSString stringWithFormat: @"%@ %@ +0000", date, time]]
				timeIntervalSinceReferenceDate];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------
// Open one or more files using open.sh given their full paths.

void
OpenFiles (id fileOrFiles)
{
	NSMutableArray* arguments = [NSMutableArray arrayWithObject: GetDiffAppName()];
	if ([fileOrFiles isKindOfClass: [NSArray class]])
		[arguments addObjectsFromArray: fileOrFiles];
	else
		[arguments addObject: fileOrFiles];

	[[Task task] launch: ShellScriptPath(@"open") arguments: arguments];
}


//----------------------------------------------------------------------------------------
// kOnAppropriateDisk, kTemporaryFolderType => /tmp
// kOnAppropriateDisk, kChewableItemsFolderType => /private/var/tmp/folders.#/Cleanup At Startup/
// kUserDomain, kChewableItemsFolderType => ~/Library/Caches/Cleanup At Startup/
// kUserDomain, kMagicTemporaryItemsFolderType => fnfErr
// kUserDomain, kTemporaryItemsInUserDomainFolderType => fnfErr
// kUserDomain, kTemporaryFolderType => ~/Library/Caches/TemporaryItems/
// kUserDomain, kUserSpecificTmpFolderType => ~/Library/Caches/

FSRef*
Folder_Find (OSType folderType, FSRef* fsRef)
{
	return (WarnIf(FSFindFolder(kUserDomain, folderType,
								kCreateFolder, fsRef)) == noErr) ? fsRef : NULL;
}


//----------------------------------------------------------------------------------------
// ~/Library/Caches/TemporaryItems/

FSRef*
Folder_TemporaryItems (FSRef* fsRef)
{
	return Folder_Find(kTemporaryFolderType, fsRef);
}


//----------------------------------------------------------------------------------------
// ~/Library/Caches/Cleanup At Startup/

FSRef*
Folder_ChewableItems (FSRef* fsRef)
{
	return Folder_Find(kChewableItemsFolderType, fsRef);
}


//----------------------------------------------------------------------------------------

BOOL
Folder_IsEqual (OSType folderType, NSURL* url)
{
	FSRef tempFolder;
	if (url && Folder_Find(folderType, &tempFolder))
	{
		FSRef fsRef;
		return CFURLGetFSRef((CFURLRef) url, &fsRef) &&
			   FSCompareFSRefs(&tempFolder, &fsRef) == noErr;
	}

	return FALSE;
}


//----------------------------------------------------------------------------------------

BOOL
Folder_IsTemporaryItems (NSURL* url)
{
	return Folder_IsEqual(kTemporaryFolderType, url);
}


//----------------------------------------------------------------------------------------

BOOL
Folder_IsChewableItems (NSURL* url)
{
	return Folder_IsEqual(kChewableItemsFolderType, url);
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation Message

- (id) initWithMessage: (SEL) message
{
	if (self = [super init])
	{
		fMessage = message;
	}
	return self;
}


//----------------------------------------------------------------------------------------

- (void) sendTo: (id) target
{
	if (fMessage)
		[target performSelector: fMessage withObject: nil];
}


//----------------------------------------------------------------------------------------

- (void) sendTo:     (id) target
		 withObject: (id) object
{
	if (fMessage)
		[target performSelector: fMessage withObject: object];
}


//----------------------------------------------------------------------------------------

- (void) sendToOnMainThread: (id) target
{
	if (fMessage)
		[target performSelectorOnMainThread: fMessage withObject: nil waitUntilDone: NO];
}


//----------------------------------------------------------------------------------------

- (void) sendToOnMainThread: (id)   target
		 withObject:         (id)   object
		 waitUntilDone:      (BOOL) wait
{
	if (fMessage)
		[target performSelectorOnMainThread: fMessage withObject: object waitUntilDone: wait];
}

@end	// Message


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@interface NSSavePanel (ShouldBeAvailableInOSX10_4)
	- (void) _setIncludeNewFolderButton: (BOOL) flag;
@end


//----------------------------------------------------------------------------------------

@implementation NSSavePanel (MakeAvailable)

- (void) setIncludeNewFolderButton: (BOOL) flag
{
	if ([self respondsToSelector: @selector(_setIncludeNewFolderButton:)])
		[self _setIncludeNewFolderButton: flag];
}


@end	// NSSavePanel


//----------------------------------------------------------------------------------------
#pragma mark -
//----------------------------------------------------------------------------------------

@implementation AlphaNumSortDesc

- (id) initWithKey: (NSString*) key ascending: (BOOL) ascending
{
	if (self = [super initWithKey: key ascending: ascending])
	{
		fKey       = [self key];
		fAscending = ascending;
	}
	return self;
}


//----------------------------------------------------------------------------------------

- (NSComparisonResult) compareObject: (id) obj1 toObject: (id) obj2
{
	NSComparisonResult result = [[obj1 objectForKey: fKey] compare: [obj2 objectForKey: fKey]
														   options: kSortOptions];
	return fAscending ? result : -result;
}


//----------------------------------------------------------------------------------------

- (id) reversedSortDescriptor
{
	return [[AlphaNumSortDesc alloc] initWithKey: fKey ascending: !fAscending];
}


@end	// AlphaNumSortDesc


//----------------------------------------------------------------------------------------
// End of CommonUtils.m
