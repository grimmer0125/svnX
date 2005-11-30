#import <Cocoa/Cocoa.h>

@class MyWorkingCopyController;
@class MySvnFilesArrayController;

@class Tasks;

/*" Model of the working copy browser "*/
@interface MyWorkingCopy : NSDocument
{
	NSString *user;
	NSString *pass;

	NSString *workingCopyPath;
	NSString *revision;
	NSURL	 *repositoryUrl;

	NSString *windowTitle;

	NSString *outlineSelectedPath; // the currently selected path in the left outline view
	
	NSString *resultString;

	IBOutlet MyWorkingCopyController *controller;
	IBOutlet MySvnFilesArrayController *svnFilesAC;	
	
    NSMutableArray *svnFiles;
	NSMutableDictionary *svnDirectories;
	
	
	BOOL flatMode, smartMode;
	BOOL showUpdates; // svn status -u
	NSString *statusInfo;
	
	NSMutableDictionary *displayedTaskObj;
}

int filterMode;


//- (void)fetchSvnStatus;
//- (void)fetchSvnStatusReceiveData:(NSArray*)shellOutput;
//- (void)fetchSvnStatusReceiveDataFinished: (NSString *)result;

- (void)svnCommand:(NSString *)command options:(NSDictionary *)options;


- (void)computesResultArray;

- (int) filterMode;
- (void) setFilterMode: (int) aFilterMode;

- (void)setResultString: (NSString *)str;
- (NSString *)resultString;

- (void)setWorkingCopyPath: (NSString *)str;
- (NSString *)workingCopyPath;


- (NSString *) user;
- (void) setUser: (NSString *) aUser;
- (NSString *) pass;
- (void) setPass: (NSString *) aPass;

- (NSArray *)svnFiles;
- (void)setSvnFiles:(NSMutableArray *)aSvnFiles;

- (NSMutableDictionary *) svnDirectories;
- (void) setSvnDirectories: (NSMutableDictionary *) aSvnDirectories;

- (NSString *) windowTitle;
- (void) setWindowTitle: (NSString *) aWindowTitle;

- (BOOL) flatMode;
- (void) setFlatMode: (BOOL) flag;
- (BOOL) smartMode;
- (void) setSmartMode: (BOOL) flag;
- (BOOL)showUpdates;
- (void)setShowUpdates:(BOOL)flag;

- (NSString *) outlineSelectedPath;
- (void) setOutlineSelectedPath: (NSString *) anOutlineSelectedPath;

- (NSString *)statusInfo;
- (void)setStatusInfo:(NSString *)aStatusInfo;


@end
