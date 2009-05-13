/* MyFileMergeController */

#import <Cocoa/Cocoa.h>
#import "MySvnOperationController.h"

@class MySvnLogView, MyWorkingCopy;

@interface MyFileMergeController : MySvnOperationController
{
	IBOutlet MySvnLogView*			svnLogView;
}

+ (void) runDiffSheet: (MyWorkingCopy*) workingCopy
		 path:         (NSString*)      path
		 sourceItem:   (NSDictionary*)  sourceItem;

- (IBAction) compare:    (id) sender;
- (IBAction) compareUrl: (id) sender;
- (IBAction) validate:   (id) sender;

- (void) setupUrl:   (NSURL*)        url
		 options:    (NSInvocation*) options
		 sourceItem: (RepoItem*)     sourceItem;

@end

