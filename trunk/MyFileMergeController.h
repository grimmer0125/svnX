/* MyFileMergeController */

#import <Cocoa/Cocoa.h>
#import "MySvnOperationController.h"

@class MySvnLogView, MyWorkingCopy, MyRepository;

@interface MyFileMergeController : MySvnOperationController
{
	IBOutlet MySvnLogView*			svnLogView;
}

+ (void) runSheet:   (MyRepository*)  repository
		 url:        (NSURL*)         url
		 revision:   (NSString*)      revision;

+ (void) runSheet:   (MyWorkingCopy*) workingCopy
		 path:       (NSString*)      path
		 sourceItem: (NSDictionary*)  sourceItem;

- (IBAction) compare:    (id) sender;
- (IBAction) compareUrl: (id) sender;
- (IBAction) validate:   (id) sender;

- (void) setupUrl: (NSURL*)        url
		 options:  (NSInvocation*) options
		 revision: (NSString*)     revision;

@end

