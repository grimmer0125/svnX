//----------------------------------------------------------------------------------------
//	MyApp.m - NSApplication's delegate
//
//  Copyright Dominique Peretti, 2004 - 2008.
//	Copyright © Chris, 2008 - 2009.  All rights reserved.
//----------------------------------------------------------------------------------------

#import <CoreServices/CoreServices.h>
#import "MyApp.h"
#import "MySVN.h"
#import "GetEthernetAddrSample.h"
#import "FavoriteWorkingCopies.h"
#import "RepositoriesController.h"
#import "SvnFileStatusToColourTransformer.h"
#import "SvnDateTransformer.h"
#import "ArrayCountTransformer.h"
#import "SvnFilePathTransformer.h"
#import "FilePathCleanUpTransformer.h"
#import "TrimNewLinesTransformer.h"
#import "Tasks.h"
#import "CommonUtils.h"
#import "SvnInterface.h"


// TO_DO: Add file "TaskStatusToColorTransformer.h"
@interface TaskStatusToColorTransformer : NSObject
{
}
@end

@interface ActionToColor : NSValueTransformer
{
}
@end


//----------------------------------------------------------------------------------------

static void
addTransform (Class itsClass, NSString* itsName)
{
	[NSValueTransformer setValueTransformer: [[itsClass alloc] init] forName: itsName];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation MyApp

#define	kUseOldParsingMethod	@"useOldParsingMethod"

//----------------------------------------------------------------------------------------

+ (MyApp*) myApp
{
	static id controller = nil;

	if (!controller)
	{
		controller = [NSApp delegate];
	}

	return controller;
}


//----------------------------------------------------------------------------------------

+ (void) initialize
{
	NSMutableDictionary* const dictionary = [NSMutableDictionary dictionary];
	[SvnFileStatusToColourTransformer initialize: dictionary];

	SInt32 response;
	if (Gestalt(gestaltSystemVersion, &response) != noErr)
		response = 0;
	[dictionary setObject: (response >= 0x1050) ? @"/usr/bin" : @"/usr/local/bin"
													  forKey: @"svnBinariesFolder"];
	[dictionary setObject: kNSTrue                    forKey: @"cacheSvnQueries"];
	[dictionary setObject: [NSNumber numberWithInt:0] forKey: @"defaultDiffApplication"];
	[dictionary setObject: @"%y-%d-%m %H:%M:%S"       forKey: @"dateformat"];
	[dictionary setObject: kNSFalse                   forKey: @"includeRevisionInName"];
	[dictionary setObject: kNSTrue                    forKey: @"installSvnxTool"];

	// Working Copy
	[dictionary setObject: kNSTrue  forKey: @"addWorkingCopyOnCheckout"];
	[dictionary setObject: kNSFalse forKey: kUseOldParsingMethod];
	[dictionary setObject: kNSTrue  forKey: @"abbrevWCFilePaths"];
	[dictionary setObject: kNSTrue  forKey: @"expandWCTree"];
	[dictionary setObject: kNSFalse forKey: @"autoRefreshWC"];
	[dictionary setObject: kNSFalse forKey: @"compactWCColumns"];

	// Review & Commit
	[dictionary setObject: [NSArray arrayWithContentsOfFile:
										[[NSBundle mainBundle] pathForResource: @"Templates" ofType: @"plist"]]
				forKey:    @"msgTemplates"];
	[dictionary setObject: @"5"    forKey: @"diffContextLines"];
	[dictionary setObject: kNSTrue forKey: @"diffShowFunction"];
	[dictionary setObject: kNSTrue forKey: @"diffShowCharacters"];

	[dictionary setObject: [NSNumber numberWithInt: 99] forKey: @"loggingLevel"];

	[Preferences() registerDefaults: dictionary];
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues: dictionary];

	// Transformers																		// Used by:
	addTransform([SvnFileStatusToColourTransformer class], @"FileStatusToColor");		// MyWorkingCopy
	addTransform([SvnDateTransformer               class], @"SvnDateTransformer");		// MySvnLogView
	addTransform([ArrayCountTransformer            class], @"ArrayCountTransformer");	// MySvnLogView
	addTransform([FilePathCleanUpTransformer       class], @"FilePathCleanUp");			// FavoriteWorkingCopies (path field)
	addTransform([FilePathWorkingCopy              class], @"FilePathWorkingCopy");		// FavoriteWorkingCopies
	addTransform([SvnFilePathTransformer           class], @"lastPathComponent");		// SingleFileInspector
	addTransform([TrimNewLinesTransformer          class], @"TrimNewLines");			// MySvnLogView (author column)
	addTransform([TaskStatusToColorTransformer     class], @"TaskStatusToColor");		// Activity Window in svnX.nib
	addTransform([ActionToColor                    class], @"ActionToColor");			// MySvnLogView
	addTransform([OneLineTransformer               class], @"ForceOneLine");			// preferencesWindow
}


//----------------------------------------------------------------------------------------

- (BOOL) checkSVNExistence: (BOOL) warn
{
	NSFileManager* fm = [NSFileManager defaultManager];
	BOOL isDir = NO,
		 exists = [fm fileExistsAtPath: SvnPath() isDirectory: &isDir] && isDir &&
				  [fm isExecutableFileAtPath: SvnCmdPath()];

//	dprintf("cmdPath='%@', exists=%d isDir=%d", SvnCmdPath(), exists, isDir);
	NSData* version = nil;
	if (exists)
	{
		Task* task = [Task task];
		NSPipe* pipe = [NSPipe pipe];
		[task setStandardOutput: pipe];
		[task launch: SvnCmdPath() arguments: [NSArray arrayWithObjects: @"--version", @"-q", nil]];
		version = [[pipe fileHandleForReading] readDataToEndOfFile];
	//	dprintf("version=[%@], pipe=%@", version, pipe);
	}
	[self setSvnVersion: version];

	if (!exists && warn)
	{
		NSBeep();
		id text = isDir ? @"Make sure the svn binary is present in the folder:\n%C%@%C.\n\n"
						   "Is a Subversion client installed?"
						   "  If so, make sure the path is correctly set in the preferences."
						: @"The 'Path to svn binaries folder' preference is\n%C%@%C.\n\n"
						   "This folder was not found.";
		NSAlert* alert = [NSAlert alertWithMessageText: @"Error: Unable to locate svn binary."
										 defaultButton: @"Open Preferences"
									   alternateButton: @"Quit"
										   otherButton: nil
							 informativeTextWithFormat: text, 0x201C, SvnPath(), 0x201D];

		[alert setAlertStyle: NSCriticalAlertStyle];
		if ([alert runModal] == NSOKButton)
			[self performSelector: @selector(openPreferences:) withObject: nil afterDelay: 0];
		else
			[NSApp terminate: nil];
	}
	return exists;
}


//----------------------------------------------------------------------------------------

- (BOOL) checkSVNExistence
{
	return [self checkSVNExistence: TRUE];
}


//----------------------------------------------------------------------------------------

- (void) applicationWillFinishLaunching: (NSNotification*) note
{
	#pragma unused(note)
	if (GetPreferenceBool(@"installSvnxTool"))
	{
		NSString* target = [NSHomeDirectory() stringByAppendingPathComponent: @"bin/svnx"];
		if (![[NSFileManager defaultManager] fileExistsAtPath: target])
		{
			[[NSFileManager defaultManager]
				createSymbolicLinkAtPath: target
							 pathContent: [[NSBundle mainBundle] pathForResource: @"svnx" ofType: nil]];
		}
	}

	[self checkSVNExistence: TRUE];
	[repositoriesController showWindow];
	[favoriteWorkingCopies showWindow];
}


//----------------------------------------------------------------------------------------

#if qDebug
- (IBAction) test: (id) sender
{
	#pragma unused(sender)
	dprintf("sender=%@", sender);
}
#endif


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	AppleScript Support
//----------------------------------------------------------------------------------------
// Compare a single file in a svnX window. Invoked from Applescript.

- (void) displayHistory: (NSString*) path
{
	[[NSApplication sharedApplication] activateIgnoringOtherApps: YES];
	[favoriteWorkingCopies fileHistoryOpenSheetForItem: path];
}


//----------------------------------------------------------------------------------------
// Open a working copy window.

- (void) openWorkingCopy: (NSString*) path
{
	[favoriteWorkingCopies openWorkingCopy: path];
}


//----------------------------------------------------------------------------------------
// Open a repository window.

- (void) openRepository: (NSString*) url
{
	[repositoriesController openRepository: url];
}


//----------------------------------------------------------------------------------------
// Open one or more files in appropriate applications.

- (void) openFiles: (id) fileOrFiles
{
	OpenFiles(fileOrFiles);
}


//----------------------------------------------------------------------------------------
// Compare one or more files with their base revisions.

- (void) diffFiles: (id) fileOrFiles
{
	[favoriteWorkingCopies diffFiles: fileOrFiles];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

- (IBAction) openPreferences: (id) sender
{
	#pragma unused(sender)
	[preferencesWindow setDelegate: self];
	[preferencesWindow makeKeyAndOrderFront: self];
}


//----------------------------------------------------------------------------------------

- (IBAction) closePreferences: (id) sender
{
	#pragma unused(sender)
	[preferencesWindow close];
	[self checkSVNExistence: TRUE];
}


//----------------------------------------------------------------------------------------

- (BOOL) windowShouldClose: (id) sender
{
	if (sender == preferencesWindow)
	{
		[sender makeFirstResponder: sender];
		[self performSelector: @selector(checkSVNExistence) withObject: nil afterDelay: 0];
	}
	return YES;
}


//----------------------------------------------------------------------------------------

- (BOOL) useOldParsingMethod
{
	return GetPreferenceBool(kUseOldParsingMethod) || ![self svnHasLibs];
}


//----------------------------------------------------------------------------------------

- (void) setUseOldParsingMethod: (BOOL) on
{
	SetPreferenceBool(kUseOldParsingMethod, on);
}


//----------------------------------------------------------------------------------------

- (BOOL) svnHasLibs
{
	return (fSvnVersion != 0) && SvnInitialize();
}


//----------------------------------------------------------------------------------------

- (void) setSvnHasLibs: (id) ignore
{
	#pragma unused(ignore)
	[self setUseOldParsingMethod: GetPreferenceBool(kUseOldParsingMethod)];
}


//----------------------------------------------------------------------------------------

- (UInt32) svnVersionNum
{
	return fSvnVersion;
}


//----------------------------------------------------------------------------------------

- (NSString*) svnVersion
{
	return fSvnVersion ? [NSString stringWithFormat: @"%u.%u.%u",
								fSvnVersion / 1000000, (fSvnVersion / 1000) % 1000, fSvnVersion % 1000]
					   : nil;
}


//----------------------------------------------------------------------------------------

- (void) setSvnVersion: (NSData*) data
{
	char buf[64];
	[data getBytes: buf length: sizeof(buf) - 1];
	buf[([data length] < sizeof(buf)) ? [data length] : sizeof(buf) - 1] = 0;

	// Parse \w[0-9]+.[0-9]+.[0-9]+
	UInt32 version = 0;
	int i = 0, n, digit;
	while (buf[i] && buf[i] <= ' ')
		++i;
	for (n = 0; (digit = buf[i] - '0') >= 0 && digit <= 9; ++i)
		n = n * 10 + digit;
	version = n * 1000000;
	if (buf[i++] == '.')
	{
		for (n = 0; (digit = buf[i] - '0') >= 0 && digit <= 9; ++i)
			n = n * 10 + digit;
		version += n * 1000;
		if (buf[i++] == '.')
		{
			for (n = 0; (digit = buf[i] - '0') >= 0 && digit <= 9; ++i)
				n = n * 10 + digit;
			version += n;
		}
	}

	fSvnVersion = version;
//	dprintf("version=%u => '%@' %@", version, [self svnVersion], data);
	[self setSvnHasLibs: nil];		// Force bindings to update
}


//----------------------------------------------------------------------------------------

static BOOL gCanFocus = YES;

- (void) svnCmdPathFocus: (id) sender
{
	[[sender window] makeFirstResponder: sender];
	gCanFocus = YES;
	NSBeep();
}


//----------------------------------------------------------------------------------------

- (IBAction) svnCmdPathChanged: (id) sender
{
	if (![self checkSVNExistence: FALSE] && gCanFocus)
	{
		gCanFocus = NO;
		[self performSelector: @selector(svnCmdPathFocus:) withObject: sender afterDelay: 0.125];
	}
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

- (BOOL) applicationShouldHandleReopen: (NSApplication*) theApplication
		 hasVisibleWindows:             (BOOL)           visibleWindows
{
	#pragma unused(theApplication)
	if (!visibleWindows)
	{
		[favoriteWorkingCopies showWindow];
	}

	return YES;
}


//----------------------------------------------------------------------------------------

- (BOOL) applicationShouldOpenUntitledFile: (NSApplication*) sender 
{
	#pragma unused(sender)
	return NO;
}


//----------------------------------------------------------------------------------------

- (BOOL) application: (NSApplication*) theApplication
		 openFile:    (NSString*)      filename
{
	#pragma unused(theApplication)
	[self displayHistory: filename];

	return YES;
}


//----------------------------------------------------------------------------------------

- (void) openRepository: (NSURL*) url user: (NSString*) user pass: (NSString*) pass
{
	[repositoriesController openRepositoryBrowser: [url absoluteString] title: [url absoluteString] user: user pass: pass];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Tasks management
//----------------------------------------------------------------------------------------
// called from MySvn class

- (void) newTaskWithDictionary: (NSMutableDictionary*) taskObj
{
	[tasksManager newTaskWithDictionary: taskObj];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Sparkle Plus delegate methods
//----------------------------------------------------------------------------------------

- (NSMutableArray*) updaterCustomizeProfileInfo: (NSMutableArray*) profileInfo
{
	NSString *MACAddress = [self getMACAddress];
	NSArray *profileDictObjs = [NSArray arrayWithObjects:@"MACAddr",@"MAC Address", MACAddress, MACAddress, nil];
	NSArray *profileDictKeys = [NSArray arrayWithObjects:@"key", @"visibleKey", @"value", @"visibleValue", nil];

	[profileInfo addObject: [NSDictionary dictionaryWithObjects: profileDictObjs forKeys: profileDictKeys]];

	//NSLog(@"%@", profileInfo);
	
	return profileInfo;
}


//----------------------------------------------------------------------------------------

- (NSString*) getMACAddress
{
	EnetData data[10];
	UInt32 entryCount = 10;
	MACAddress mac;

	int err = GetEthernetAddressInfo((EnetData*)&data, &entryCount);

	if ( err == noErr )
	{
		NSValue *value = [NSValue valueWithBytes:&data[0].macAddress objCType:@encode(MACAddress)];
		[value getValue:&mac];
		NSMutableString *s = [NSMutableString string];
		int i;
		
		for ( i=0; i<kIOEthernetAddressSize; i++ )
		{
			[s appendFormat:@"%02X", mac[i]];
		
			if(i < kIOEthernetAddressSize-1) [s appendString:@":"];
		}
		
		return s;
	}
	
	return @"";
}

@end	// MyApp


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------
// The text view of the help documentation window

@interface HelpDocView : NSTextView
{
}
@end


@implementation HelpDocView

- (void) awakeFromNib
{
	[self readRTFDFromFile: [[NSBundle mainBundle] pathForResource: @"Documentation" ofType: @"rtf"]];
}

@end	// HelpDocView


//----------------------------------------------------------------------------------------
// End of MyApp.m
