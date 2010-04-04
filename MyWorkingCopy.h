//----------------------------------------------------------------------------------------
//	MyWorkingCopy.h - Working Copy model
//
//	Copyright 2004 - 2007 Dominique Peretti.
//	Copyright © Chris, 2007 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "CommonUtils.h"

enum {
	kFilterAll		=	0,
	kFilterModified	=	1,
	kFilterNew		=	2,
	kFilterMissing	=	3,
	kFilterConflict	=	4,
	kFilterChanged	=	5
};

extern ConstString kUseOldParsingMethod;
void InitWCPreferences (void);

@class WCTreeEntry, MyWorkingCopyController, MySvnFilesArrayController;

/*" Model of the working copy browser "*/
@interface MyWorkingCopy : NSDocument
{
	NSString*		user;
	NSString*		pass;
	NSString*		workingCopyPath;
	NSString*		revision;
	NSURL*			repositoryUrl;

	NSString*		windowTitle;
	NSString*		outlineSelectedPath;	// the currently selected path in the left outline view

	IBOutlet MyWorkingCopyController*	controller;
	IBOutlet MySvnFilesArrayController*	svnFilesAC;

	NSArray*		svnFiles;
	WCTreeEntry*	svnDirectories;

	BOOL			flatMode, smartMode;
	BOOL			showUpdates;			// svn status -u
	int				filterMode;
	NSMutableSet*	subControllers;			// active ReviewContollers

	NSMutableDictionary*	displayedTaskObj;
	struct SvnEnv*			fSvnEnv;		// the svn client environment
	BOOL					fInfoPending, fStatusPending;
}


+ (void) presetDocumentName: name;
- (void) setup: (NSString*) title
		 user:  (NSString*) username
		 pass:  (NSString*) password
		 path:  (NSString*) fullPath;
- (void) svnRefresh;

- (void) fetchSvnInfo;
- (void) svnUpdateSelectedItems: (NSArray*) options;
- (void) svnUpdate: (NSArray*) options;
- (void) svnUpdate;
- (void) diffItems:    (NSArray*)      items
		 callback:     (NSInvocation*) callback
		 callbackInfo: (id)            callbackInfo;
- (void) diffItems: (NSArray*) items;
- (void) fetchSvnStatus: (BOOL) showUpdates;
- (void) fetchSvnInfoReceiveDataFinished: (NSString*) result;

- (void) svnInfo: (const struct svn_info_t*) info
		 forPath: (const char*)              path;

- (void) svnCommit:    (NSArray*)      items
		 message:      (NSString*)     message
		 callback:     (NSInvocation*) callback
		 callbackInfo: (id)            callbackInfo;

- (void) svnCommit: (NSString*) message;
- (void) svnMerge:  (NSArray*) options;
- (void) svnSwitch: (NSArray*) options;

- (void) svnCommand: (NSString*)     command
		 options:    (NSArray*)      options
		 info:       (NSDictionary*) info
		 itemPaths:  (NSArray*)      itemPaths;

- (NSInvocation*) svnOptionsInvocation;
- (WCTreeEntry*)  svnDirectories;

- (NSString*) workingCopyPath;
- (void)      setWorkingCopyPath: (NSString*) str;
- (NSString*) user;
- (void)      setUser:            (NSString*) aUser;
- (NSString*) pass;
- (void)      setPass:            (NSString*) aPass;
- (NSString*) revision;
- (void)      setRevision:        (NSString*) aRevision;
- (NSArray*)  svnFiles;
- (void)      setSvnFiles:        (NSArray*)  aSvnFiles;
- (NSString*) windowTitle;
- (void)      setWindowTitle:     (NSString*) aWindowTitle;

- (BOOL) flatMode;
- (void) setFlatMode: (BOOL) flag;
- (BOOL) smartMode;
- (void) setSmartMode: (BOOL) flag;
- (int)  filterMode;
- (void) setFilterMode: (int) aFilterMode;

- (void) registerSubController:   (id) aController;
- (void) unregisterSubController: (id) aController;
- (id)   anySubController;
- (int)  countUnsavedSubControllers;

- (id) controller;
- (NSURL*) repositoryUrl;
- (void) setRepositoryUrl: (NSURL*) aRepositoryUrl;

- (NSImage*)  iconForFile: (NSString*) relPath;
- (NSString*) treeSelectedFullPath;
- (NSString*) outlineSelectedPath;
- (void)      setOutlineSelectedPath: (NSString*) aPath;

@end	// MyWorkingCopy


//----------------------------------------------------------------------------------------

@interface WCTreeEntry : NSObject
{
	NSMutableArray*	children;
	NSString*		name;
	NSString*		path;
	NSImage*		icon;
	BOOL			sorted;
}

+ (id) create: (NSMutableArray*) itsChildren
	   name:   (NSString*)       itsName
	   path:   (NSString*)       itsPath
	   icon:   (NSImage*)        itsIcon;
- (void) dealloc;
- (int) childCount;
- (id) childAtIndex: (int) index;
- (NSMutableArray*) children;
- (NSString*) name;
- (NSString*) path;
- (NSImage*) icon: (MyWorkingCopy*) workingCopy;

@end	// WCTreeEntry

