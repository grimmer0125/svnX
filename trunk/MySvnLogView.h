/* MySvnLogView */

#import <Cocoa/Cocoa.h>
#import "MySvnView.h"

@class MySvnLogAC;

@interface MySvnLogView : MySvnView
{
	IBOutlet NSTableView*		logTable;
	IBOutlet NSTableView*		pathsTable;
	IBOutlet NSSearchField*		searchPaths;
	IBOutlet id					splitView;
	IBOutlet MySvnLogAC*		logsAC;
	IBOutlet NSArrayController*	logsACSelection;

	NSString*					currentRevision;
	NSString*					path;
	NSMutableArray*				logArray;
	int		mostRecentRevision;	// remembers most recent revision to avoid fetching from scratch
	BOOL	isVerbose;			// passes -v to svn log to retrieve the changed paths of each revision
	BOOL	fIsAdvanced;
}

- (void) unload;

- (void) setAutosaveName: (NSString*) name;
- (void) resetUrl: (NSURL*) anUrl;
- (void) fetchSvn: (NSInvocation*) callback;
- (void) fetchSvn;

- (NSString*) selectedRevision;
- (NSString*) currentRevision;
- (void) setCurrentRevision: (NSString*) aCurrentRevision;

// Sets the path to get the log from. If set, url and revision won't be used.
- (void) setPath: (NSString*) aPath;

- (NSMutableArray*) logArray;
- (void) setLogArray: (NSMutableArray*) aLogArray;

- (BOOL) advanced;
- (void) setAdvanced: (BOOL) isAdvanced;
- (NSArray*) arrangedObjects;
- (NSDictionary*) targetSvnItem;

@end

