#import <Foundation/Foundation.h>
#import "MySvn.h"

@class MyRepository;

@interface MySvnView : NSView
{
@protected
	IBOutlet NSView*		fView;
	IBOutlet id				progress;
	IBOutlet id				refetch;
	IBOutlet MyRepository*	fRepository;	// Only valid in repository window

	NSInvocation*	fOptionsInvocation;
	NSURL*			fURL;
	NSString*		fRevision;
	id				pendingTask;
	BOOL			isFetching;
}

- (IBAction) refetch: (id) sender;

- (void) unload;

- (void) fetchSvn;
- (void) svnCommandComplete: (id) taskObj;
- (void) svnError: (NSString*) errorString;
- (void) fetchSvnReceiveDataFinished: (id) taskObj;

- (NSInvocation*) makeCallbackInvocationOfKind: (int) callbackKind;
- (NSInvocation*) svnOptionsInvocation;
- (void) setSvnOptionsInvocation: (NSInvocation*) aSvnOptionsInvocation;

- (NSURL*) url;
- (void) setUrl: (NSURL*) anUrl;

- (NSString*) revision;
- (void) setRevision: (NSString*) aRevision;

- (BOOL) isFetching;
- (void) setIsFetching: (BOOL) flag;

- (id) pendingTask;
- (void) setPendingTask: (id) aPendingTask;

- (MyRepository*) repository;
- (void) setRepository: (MyRepository*) repository;

- (NSDictionary*) documentNameDict;

@end

