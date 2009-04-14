//----------------------------------------------------------------------------------------
//	ViewUtils.h - NSView & NSWindow utilities
//
//	Copyright © Chris, 2008.  All rights reserved.
//----------------------------------------------------------------------------------------

#pragma once

#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>
#include "CommonUtils.h"


//----------------------------------------------------------------------------------------
// Make clicking NSButtonCells in a table not change the selection

@interface CTableView : NSTableView
{
}

	- (void) mouseDown: (NSEvent*) theEvent;

@end	// CTableView


//----------------------------------------------------------------------------------------
// Draw styled text in a table cell

@interface CStyledTextCell : NSTextFieldCell
{
}

	+ (void) initialize;
	- (void) drawWithFrame: (NSRect) cellFrame inView: (NSView*) controlView;

@end	// CStyledTextCell


//----------------------------------------------------------------------------------------

@interface NSWindow (ViewUtils)

	// Split Views
	- (NSMutableArray*) splitViews;
	- (NSArray*)        splitViewsValues;
	- (void)            splitViewsSetup: (NSArray*) values delegate: (id) delegate;
	- (void)            splitViewsLoad: (NSString*) prefsKey delegate: (id) delegate;
	- (void)            splitViewsSave: (NSString*) prefsKey;

@end	// NSWindow


//----------------------------------------------------------------------------------------

NSPoint		locationInView			(NSEvent* event, NSView* destView);

void		initSplitView			(NSSplitView* splitView, GCoord value, id delegate);
void		initSplitViewWithPref	(NSSplitView* splitView, NSString* prefsKey, id delegate);
void		resizeSplitView			(NSSplitView* sender, NSSize oldSize,
									 GCoord minWidth, GCoord minHeight);
void		getSubviewSplitViews	(NSView* rootView, NSMutableArray* array);
NSMutableArray*
			getSplitViews			(NSWindow* window);
NSArray*	getValuesForSplitViews	(NSWindow* window);
void		setupSplitViews			(NSWindow* window, NSArray* values, id delegate);
void		loadSplitViews			(NSWindow* window, NSString* prefsKey, id delegate);
void		saveSplitViews			(NSWindow* window, NSString* prefsKey);


//----------------------------------------------------------------------------------------
// End of ViewUtils.h
