//----------------------------------------------------------------------------------------
//	SvnLogReport.h - Generate & display in HTML a Subversion log report
//
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "Tasks.h"

@class MyRepository, WebView;

@interface SvnLogReport : NSResponder<TaskDelegate>
{
	IBOutlet NSWindow*	fWindow;
	IBOutlet WebView*	fLogView;
}

+ (void) createFor:     (MyRepository*) document
		 url:           (NSString*) fileURL
		 logItems:      (NSArray*)  logItems
		 revision:      (NSString*) revision
		 limit:         (int)       limit
		 pageLength:    (int)       pageLength
		 verbose:       (BOOL)      verbose
		 stopOnCopy:    (BOOL)      stopOnCopy
		 relativeDates: (BOOL)      relativeDates
		 reverseOrder:  (BOOL)      reverseOrder;

- (NSWindow*) window;

@end	// SvnLogReport

