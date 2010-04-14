//----------------------------------------------------------------------------------------
//	ViewUtils.h - NSView & NSWindow utilities
//
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#pragma once

#import <AppKit/NSView.h>
#import <AppKit/NSWindow.h>
#import "CommonUtils.h"


//----------------------------------------------------------------------------------------
// Make clicking NSButtonCells in a table not change the selection

@interface CTableView : NSTableView
{
}

	- (void) mouseDown: (NSEvent*) theEvent;

@end	// CTableView

void SetColumnSort (NSTableView* tableView, NSString* colId, NSString* key);


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

id			GetView					(NSView* rootView, int tag);
int			GetViewInt				(NSView* rootView, int tag);
void		SetViewInt				(NSView* rootView, int tag, int value);

NSString*	GetViewString			(NSView* rootView, int tag);
void		SetViewString			(NSView* rootView, int tag, NSString* value);
void		ViewShow				(NSView* rootView, int tag, bool isVisible);
void		ViewEnable				(NSView* rootView, int tag, bool isEnabled);
NSView*		SubView					(NSView* aView, int index);

id			WGetView				(NSWindow* window, int tag);
int			WGetViewInt				(NSWindow* window, int tag);
void		WSetViewInt				(NSWindow* window, int tag, int value);
static inline
bool		WViewIsOn				(NSWindow* window, int tag)
										{ return WGetViewInt(window, tag) == NSOnState; }
NSString*	WGetViewString			(NSWindow* window, int tag);
void		WSetViewString			(NSWindow* window, int tag, NSString* value);
void		WViewEnable				(NSWindow* window, int tag, bool isEnabled);
void		WViewShow				(NSWindow* window, int tag, bool isVisible);
static inline
void		WHideView				(NSWindow* window, int tag)
										{ WViewShow(window, tag, FALSE); }
static inline
void		WShowView				(NSWindow* window, int tag)
										{ WViewShow(window, tag, TRUE); }
int			TagOfSelectedItem		(NSPopUpButton* view);
static inline
int			CurrentTag				(NSPopUpButton* view)
										{ return TagOfSelectedItem(view); }
static inline
int			SelectedTag				(NSMatrix* view)
										{ return [[view selectedCell] tag]; }

void		ViewSetX				(NSView* view, GCoord x);
void		ViewSetY				(NSView* view, GCoord y);
void		ViewAdjustOrigin		(NSView* view, GCoord deltaX, GCoord deltaY);
void		ViewAdjustX				(NSView* view, GCoord delta);
void		ViewAdjustY				(NSView* view, GCoord delta);

void		ViewSetWidth			(NSView* view, GCoord width);
void		ViewSetHeight			(NSView* view, GCoord height);
void		ViewAdjustSize			(NSView* view, GCoord deltaX, GCoord deltaY);
void		ViewAdjustWidth			(NSView* view, GCoord delta);
void		ViewAdjustHeight		(NSView* view, GCoord delta);

bool		IsInResponderChain		(NSWindow* window, NSResponder* obj);
bool		IsViewInResponderChain	(NSView* obj);

void		ChangeMenuCheck			(NSMenu* menu, int checkTag, int uncheckTag);

bool		IsOpen					(NSDrawer* drawer);

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

void		InitViewUtils			(void);


//----------------------------------------------------------------------------------------
// End of ViewUtils.h
