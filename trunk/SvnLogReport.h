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

+ (void) createForURL:  (NSString*) fileURL
		 logItems:      (NSArray*)  logItems
		 revision:      (NSString*) revision
		 limit:         (int)       limit
		 pageLength:    (int)       pageLength
		 verbose:       (BOOL)      verbose
		 stopOnCopy:    (BOOL)      stopOnCopy
		 relativeDates: (BOOL)      relativeDates
		 reverseOrder:  (BOOL)      reverseOrder;

- (void) textSmaller: (id) sender;
- (void) textBigger: (id) sender;
- (void) printDocument: (id) sender;
- (BOOL) validateToolbarItem: (NSToolbarItem*) toolbarItem;
- (NSWindow*) window;

@end

