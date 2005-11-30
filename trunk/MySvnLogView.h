/* MySvnLogView */

#import <Cocoa/Cocoa.h>
#import "MySvnView.h"

#import "MySvnLogParser.h"

@interface MySvnLogView : MySvnView
{
    IBOutlet id svnLog;
	IBOutlet NSArrayController *logsAC;
	IBOutlet NSArrayController *logsACSelection;

	NSString *currentRevision;

	NSString *path;
	NSMutableArray *logArray;
	int mostRecentRevision; // remembers most recent revision to avoid fetching from scratch
	BOOL isVerbose; // passes -v to svn log to retrieve the changed paths of each revision
}


- (NSString *)currentRevision;
- (void)setCurrentRevision:(NSString *)aCurrentRevision;

- (NSString *)path; // Sets the path to get the log from. If set, url and revision won't be used.
- (void)setPath:(NSString *)aPath;

- (BOOL)isVerbose;
- (void)setIsVerbose:(BOOL)flag;


@end
