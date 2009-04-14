#import <Foundation/Foundation.h>
#import "MySvn.h"

@class MyRepository;

@interface MySvnView : NSView
{
	IBOutlet id		_view;
	IBOutlet id		progress;
	IBOutlet id		refetch;

	NSInvocation*	svnOptionsInvocation;
	NSString*		pass;
	NSURL*			url;
	NSString*		revision;
	id				pendingTask;
	BOOL			isFetching;
}

- (IBAction)refetch:(id)sender;

- (void)unload;

- (void)fetchSvn;
- (void)svnCommandComplete:(id)taskObj;
- (void)svnError:(NSString*)errorString;
- (void)fetchSvnReceiveDataFinished:(id)taskObj;

- (NSInvocation *)makeCallbackInvocationOfKind:(int)callbackKind;
- (NSInvocation *) svnOptionsInvocation;
- (void) setSvnOptionsInvocation: (NSInvocation *) aSvnOptionsInvocation;

- (NSURL *)url;
- (void)setUrl:(NSURL *)anUrl;

- (NSString *)revision;
- (void)setRevision:(NSString *)aRevision;

- (BOOL)isFetching;
- (void)setIsFetching:(BOOL)flag;

- (id)pendingTask;
- (void)setPendingTask:(id)aPendingTask;

- (MyRepository*) repository;
- (NSDictionary*) documentNameDict;

@end

