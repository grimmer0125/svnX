//
// ReviewCommit.h
//

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

- (IBAction) checkAllFiles:    (id) sender;
- (IBAction) checkNoFiles:     (id) sender;
- (IBAction) refreshFiles:     (id) sender;
- (IBAction) openSelectedFile: (id) sender;
- (IBAction) diffSelectedFile: (id) sender;
- (IBAction) commitFiles:      (id) sender;

@end	// ReviewController

