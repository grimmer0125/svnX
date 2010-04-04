//----------------------------------------------------------
// ReviewCommit.h - Review and edit a commit
//
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "Tasks.h"

@class WebView, MyWorkingCopy;

@interface ReviewController : NSResponder<TaskDelegate>
{
	IBOutlet NSWindow*		fWindow;
	IBOutlet WebView*		fDiffView;
	IBOutlet NSTableView*	fFilesView;
	IBOutlet NSTextView*	fMessageView;	// Current message
	IBOutlet NSTableView*	fRecentView;	// Recent messages
	IBOutlet NSTableView*	fTemplatesView;	// Template messages

@private
	MyWorkingCopy*			fDocument;
	NSMutableArray*			fFiles;
	NSArrayController*		fFilesAC;
	NSArrayController*		fRecentAC;
	NSMutableArray*			fTemplates;
	NSArrayController*		fTemplatesAC;
	int						fCommitFileCount;
	int						fEditState;
	BOOL					fIsBusy;
	BOOL					fSuppressAutoRefresh;
	Task*					fFileDiffTask;
}

+ (void) openForDocument: (MyWorkingCopy*) document;

- (NSWindow*) window;
- (void)      buildFileList;
- (void)      buildRecentMessages: (id) taskObj;
- (void)      svnCommit_Completed: (id) taskObj;
- (BOOL)      isDocumentEdited;

- (IBAction) checkAllFiles:    (id) sender;
- (IBAction) checkNoFiles:     (id) sender;
- (IBAction) refreshFiles:     (id) sender;
- (IBAction) openSelectedFile: (id) sender;
- (IBAction) diffSelectedFile: (id) sender;
- (IBAction) commitFiles:      (id) sender;
- (IBAction) setDefaultTab:    (id) sender;
- (IBAction) setOption:        (id) sender;
- (IBAction) setContextLines:  (id) sender;

@end	// ReviewController

