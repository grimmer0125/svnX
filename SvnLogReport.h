//
// SvnLogReport.h
//

#import <Cocoa/Cocoa.h>
#import "Tasks.h"

@class WebView;

@interface SvnLogReport : NSResponder<TaskDelegate>
{
	IBOutlet NSWindow*	fWindow;
	IBOutlet WebView*	fLogView;
}

+ (void) svnLogReport: (NSString*) fileURL
		 revision:     (NSString*) revision
		 verbose:      (BOOL)      verbose;

- (void) textSmaller: (id) sender;
- (void) textBigger: (id) sender;
- (void) printDocument: (id) sender;
- (BOOL) validateToolbarItem: (NSToolbarItem*) toolbarItem;
- (NSWindow*) window;

@end

