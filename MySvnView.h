#import <Foundation/Foundation.h>

#import "MySvn.h"

@interface MySvnView : NSView
{
    IBOutlet id _view;

    IBOutlet id progress;
    IBOutlet id refetch;

	NSInvocation *svnOptionsInvocation;
	NSString *pass;
	NSURL *url;
	NSString *revision;
	id pendingTask;
	BOOL isFetching;
}

- (IBAction)refetch:(id)sender;

- (NSInvocation *) svnOptionsInvocation;
- (void) setSvnOptionsInvocation: (NSInvocation *) aSvnOptionsInvocation;

- (NSURL *)url;
- (void)setUrl:(NSURL *)anUrl;

- (NSString *)revision;
- (void)setRevision:(NSString *)aRevision;

- (id)pendingTask;
- (void)setPendingTask:(id)aPendingTask;


@end
