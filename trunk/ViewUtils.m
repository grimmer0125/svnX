//----------------------------------------------------------------------------------------
//	ViewUtils.m - NSView & NSWindow utilities
//
//	Copyright © Chris, 2008 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "ViewUtils.h"
#import "CommonUtils.h"


//----------------------------------------------------------------------------------------
#pragma mark	View Based
//----------------------------------------------------------------------------------------

id
GetView (NSView* rootView, int tag)
{
	id view = [rootView viewWithTag: tag];
	if (view == nil)
		dprintf("WARNING: Couldn't find view for tag=%d view=%@", tag, rootView);
	return view;
}


//----------------------------------------------------------------------------------------

int
GetViewInt (NSView* rootView, int tag)
{
	return [GetView(rootView, tag) intValue];
}


//----------------------------------------------------------------------------------------

void
SetViewInt (NSView* rootView, int tag, int value)
{
	[GetView(rootView, tag) setIntValue: value];
}


//----------------------------------------------------------------------------------------

NSString*
GetViewString (NSView* rootView, int tag)
{
	return [GetView(rootView, tag) stringValue];
}


//----------------------------------------------------------------------------------------

void
SetViewString (NSView* rootView, int tag, NSString* value)
{
	[GetView(rootView, tag) setStringValue: value];
}


//----------------------------------------------------------------------------------------

void
ViewEnable (NSView* rootView, int tag, bool isEnabled)
{
	[GetView(rootView, tag) setEnabled: isEnabled];
}


//----------------------------------------------------------------------------------------

void
ViewShow (NSView* rootView, int tag, bool isVisible)
{
	[GetView(rootView, tag) setHidden: !isVisible];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Window Based
//----------------------------------------------------------------------------------------

id
WGetView (NSWindow* window, int tag)
{
	id view = [[window contentView] viewWithTag: tag];
//	id view = [window->_contentView viewWithTag: tag];
	if (view == nil)
		dprintf("WARNING: Couldn't find view for tag=%d window=%@", tag, window);
	return view;
}


//----------------------------------------------------------------------------------------

int
WGetViewInt (NSWindow* window, int tag)
{
	return [WGetView(window, tag) intValue];
}


//----------------------------------------------------------------------------------------

void
WSetViewInt (NSWindow* window, int tag, int value)
{
	[WGetView(window, tag) setIntValue: value];
}


//----------------------------------------------------------------------------------------

NSString*
WGetViewString (NSWindow* window, int tag)
{
	return [WGetView(window, tag) stringValue];
}


//----------------------------------------------------------------------------------------

void
WSetViewString (NSWindow* window, int tag, NSString* value)
{
	[WGetView(window, tag) setStringValue: value];
}


//----------------------------------------------------------------------------------------

void
WViewEnable (NSWindow* window, int tag, bool isEnabled)
{
	[WGetView(window, tag) setEnabled: isEnabled];
}


//----------------------------------------------------------------------------------------

void
WViewShow (NSWindow* window, int tag, bool isVisible)
{
	[WGetView(window, tag) setHidden: !isVisible];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

void
ViewSetX (NSView* view, GCoord x)
{
	NSPoint pt = [view frame].origin;
	pt.x = x;
	[view setFrameOrigin: pt];
}


//----------------------------------------------------------------------------------------

void
ViewSetY (NSView* view, GCoord y)
{
	NSPoint pt = [view frame].origin;
	pt.y = y;
	[view setFrameOrigin: pt];
}


//----------------------------------------------------------------------------------------

void
ViewAdjustOrigin (NSView* view, GCoord deltaX, GCoord deltaY)
{
	NSPoint pt = [view frame].origin;
	pt.x += deltaX;
	pt.y += deltaY;
	[view setFrameOrigin: pt];
}


//----------------------------------------------------------------------------------------

void
ViewAdjustX (NSView* view, GCoord delta)
{
	NSPoint pt = [view frame].origin;
	pt.x += delta;
	[view setFrameOrigin: pt];
}


//----------------------------------------------------------------------------------------

void
ViewAdjustY (NSView* view, GCoord delta)
{
	NSPoint pt = [view frame].origin;
	pt.y += delta;
	[view setFrameOrigin: pt];
}


//----------------------------------------------------------------------------------------

void
ViewSetWidth (NSView* view, GCoord width)
{
	NSSize size = [view frame].size;
	size.width = width;
	[view setFrameSize: size];
}


//----------------------------------------------------------------------------------------

void
ViewSetHeight (NSView* view, GCoord height)
{
	NSSize size = [view frame].size;
	size.height = height;
	[view setFrameSize: size];
}


//----------------------------------------------------------------------------------------

void
ViewAdjustSize (NSView* view, GCoord deltaX, GCoord deltaY)
{
	NSSize size = [view frame].size;
	size.width  += deltaX;
	size.height += deltaY;
	[view setFrameSize: size];
}


//----------------------------------------------------------------------------------------

void
ViewAdjustWidth (NSView* view, GCoord delta)
{
	NSSize size = [view frame].size;
	size.width += delta;
	[view setFrameSize: size];
}


//----------------------------------------------------------------------------------------

void
ViewAdjustHeight (NSView* view, GCoord delta)
{
	NSSize size = [view frame].size;
	size.height += delta;
	[view setFrameSize: size];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

int
TagOfSelectedItem (NSPopUpButton* view)
{
	return [[view itemAtIndex: [view indexOfSelectedItem]] tag];
}


//----------------------------------------------------------------------------------------

bool
IsInResponderChain (NSWindow* window, NSResponder* obj)
{
	for (NSResponder* responder = [window firstResponder];
		 responder != nil; responder = [responder nextResponder])
	{
		if (responder == obj)
			return true;
	}

	return false;
}

//----------------------------------------------------------------------------------------

bool
IsViewInResponderChain (NSView* obj)
{
	return IsInResponderChain([obj window], obj);
}


//----------------------------------------------------------------------------------------

void
ChangeMenuCheck (NSMenu* menu, int checkTag, int uncheckTag)
{
	Assert(menu != NULL);
	if (uncheckTag)
		[[menu itemWithTag: uncheckTag] setState: NSOffState];
	if (checkTag)
		[[menu itemWithTag: checkTag] setState: NSOnState];
}


//----------------------------------------------------------------------------------------

NSPoint
locationInView (NSEvent* event, NSView* destView)
{
	return [destView convertPoint: [event locationInWindow] fromView: nil];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	CPopUpButton
//----------------------------------------------------------------------------------------
// An NSButton that displays its pop-up menu when clicked.

@interface CPopUpButton : NSButton @end


//----------------------------------------------------------------------------------------

@implementation CPopUpButton

- (void) mouseDown: (NSEvent*) theEvent
{
	NSWindow* const window = [self window];
	NSMenu* const menu = [self menu];
	const NSSize size = [self frame].size;
	NSPoint pt = [self convertPoint: NSMakePoint(0, size.height + 2) toView: nil];
	const GCoord y = [window frame].origin.y + pt.y - [[window screen] visibleFrame].origin.y;
	if (y < 17 * [menu numberOfItems] + 24)
	{
		pt.x += size.width;
		pt.y += size.height;
	}

	[self highlight: YES];
	theEvent = [NSEvent mouseEventWithType: NSLeftMouseDown
								  location: pt
							 modifierFlags: 0
								 timestamp: [theEvent timestamp]
							  windowNumber: [theEvent windowNumber]
								   context: [theEvent context]
							   eventNumber: [theEvent eventNumber]
								clickCount: 1
								  pressure: [theEvent pressure]];
	[NSMenu popUpContextMenu: menu withEvent: theEvent forView: self withFont: [self font]];
	[self highlight: NO];
}


//----------------------------------------------------------------------------------------

- (BOOL) performKeyEquivalent: (NSEvent*) theEvent
{
	return [[self menu] performKeyEquivalent: theEvent];
}

@end	// CPopUpButton


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	NSTableView Utils
//----------------------------------------------------------------------------------------

@implementation CTableView

//----------------------------------------------------------------------------------------

static void
display (NSCell* self, BOOL isHighlighted, NSRect rect, NSView* view)
{
	if (isHighlighted)
		[self setHighlighted: YES];
	[view displayRect: rect];
	if (isHighlighted)
		[self setHighlighted: NO];
}


//----------------------------------------------------------------------------------------

static BOOL
trackMouse (NSCell* self, NSRect cellFrame, NSView* controlView)
{
	[[controlView window] displayIfNeeded];
//	[self startTrackingAt: locationInView(theEvent, controlView) inView: controlView];
	display(self, YES, cellFrame, controlView);

	BOOL wasInside = YES;
	while (TRUE)	// keep control until mouse up
	{
		const unsigned int kMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask;
		NSEvent* const event = [[controlView window] nextEventMatchingMask: kMask];
		const NSEventType type = [event type];

		if (type == NSLeftMouseDragged)
		{
			BOOL inside = NSPointInRect(locationInView(event, controlView), cellFrame);

			if (inside != wasInside)
			{
				display(self, inside, cellFrame, controlView);
				wasInside = inside;
			}
		}
		else if (type == NSLeftMouseUp)
			break;
	/*	if (![self continueTracking: locationInView(theEvent, controlView)
				   at: locationInView(event, controlView) inView: controlView])
			break;*/
	}

/*	[self stopTracking: locationInView(theEvent, controlView)
		  at: locationInView(event, controlView) inView: controlView
		  mouseIsUp: ([event modifierFlags] & NSLeftMouseDown) == 0];*/
	[controlView setNeedsDisplayInRect: cellFrame];

	return wasInside;
}


//----------------------------------------------------------------------------------------

- (void) mouseDown: (NSEvent*) theEvent
{
	NSPoint localPoint = locationInView(theEvent, self);
	int colIndex, rowIndex;
	if ((colIndex = [self columnAtPoint: localPoint]) >= 0 &&
		(rowIndex = [self rowAtPoint: localPoint]) >= 0)
	{
		NSTableColumn* column = [[self tableColumns] objectAtIndex: colIndex];
		NSCell* cell = [column dataCellForRow: rowIndex];
		if (ISA(cell, NSButtonCell))
		{
			id delegate = [self delegate];
			BOOL value = [[delegate tableView: self objectValueForTableColumn: column
									row: rowIndex] boolValue];
			if (trackMouse(cell, [self frameOfCellAtColumn: colIndex row: rowIndex], self))
				[delegate tableView: self setObjectValue: NSBool(!value)
						  forTableColumn: column row: rowIndex];
			return;
		}
	}

	[super mouseDown: theEvent];
}

@end	// CTableView


//----------------------------------------------------------------------------------------

void
SetColumnSort (NSTableView* tableView, NSString* colId, NSString* key)
{
	NSTableColumn* col = [tableView tableColumnWithIdentifier: colId];
	Assert(col != nil);
	id desc = [[AlphaNumSortDesc alloc] initWithKey: key ascending: YES];
	[col setSortDescriptorPrototype: desc];
	[desc release];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation CStyledTextCell

static GCoord					gSTCellWidth = -999;
static NSMutableParagraphStyle*	gSTCellPS    = nil;
static NSFont*					gSTCellFont  = nil;


//----------------------------------------------------------------------------------------

+ (void) initialize
{
	Assert(gSTCellFont == nil);
	gSTCellPS   = [[[NSMutableParagraphStyle alloc] init] retain];
	gSTCellFont = [[NSFont labelFontOfSize: [NSFont labelFontSize]] retain];
}


//----------------------------------------------------------------------------------------

- (NSParagraphStyle*) paragraphStyle: (GCoord) width
{
	NSMutableParagraphStyle* ps = gSTCellPS;
	if (gSTCellWidth != width)
	{
		gSTCellWidth = width;
		[ps setTabStops: [NSArray arrayWithObjects:
				[[NSTextTab alloc] initWithType: NSCenterTabStopType location: width * 0.3],
				[[NSTextTab alloc] initWithType: NSRightTabStopType location: width],
				nil]];
	}

	return ps;
}


//----------------------------------------------------------------------------------------

- (void) drawWithFrame: (NSRect)  cellFrame
		 inView:        (NSView*) controlView
{
	const GCoord width = cellFrame.size.width - 4;
	cellFrame.origin.x += 2;
	cellFrame.size.width = width;

	NSParagraphStyle* ps = [self paragraphStyle: width];
	NSColor* color = nil;		// black text
	if ([self isHighlighted])	// white text?
	{
		color = [self highlightColorWithFrame: cellFrame inView: controlView];
		color = [color colorUsingColorSpaceName: NSDeviceWhiteColorSpace];
		color = ([color whiteComponent] < 0.67) ? [NSColor alternateSelectedControlTextColor] : nil;
	}
	NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:
												ps, NSParagraphStyleAttributeName,
												gSTCellFont, NSFontAttributeName,
												color, NSForegroundColorAttributeName,
												nil];
	NSAttributedString* str = [[NSAttributedString alloc] initWithString: [self objectValue]
														  attributes: attrs];
	[str drawInRect: cellFrame];
	[str release];
}

@end	// CStyledTextCell


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

static inline GCoord
get_wh (NSSize size, BOOL isHeight)
{
	return isHeight ? size.height : size.width;
}

static inline GCoord*
size_wh (NSSize* size, BOOL isHeight)
{
	return isHeight ? &size->height : &size->width;
}


static inline GCoord*
point_xy (NSPoint* point, BOOL isY)
{
	return isY ? &point->y : &point->x;
}


#define	WH(size, isHeight)				(*size_wh(&(size), (isHeight)))
#define	XY(point, isY)					(*point_xy(&(point), (isY)))
#define	SetWorH(size, isHeight, value)	(WH(size, isHeight) = (value))
#define	SetXorY(point, isY, value)		(XY(point, isY) = (value))


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	NSSplitView
//----------------------------------------------------------------------------------------
// Initialize subview 0 of <splitView> to have a width/height of <value> & set its delegate.

void
initSplitView (NSSplitView* splitView, GCoord value, id delegate)
{
/*	if (splitView == nil || value <= 0)
		dprintf("(splitView=%@, value=%g, delegate=%@)",
				splitView, value, delegate);*/
	if (splitView)
	{
		if (value > 0)
		{
			const BOOL isHorizontal = ![splitView isVertical];
			const GCoord splitSize = get_wh([splitView frame].size, isHorizontal),
						 dividerThickness = [splitView dividerThickness];
			NSView* const view0 = [[splitView subviews] objectAtIndex: 0];
			NSView* const view1 = [[splitView subviews] objectAtIndex: 1];

			NSRect frame = [view0 frame];
		/*	dprintf("(%@, %g, %@): splitSize=%g frame.%s=%g",
					splitView, value, delegate, splitSize,
					isHorizontal ? "height" : "width", WH(frame.size, isHorizontal));*/
			if (value <= splitSize - dividerThickness)
			{
				WH(frame.size, isHorizontal) = value;
				[view0 setFrame: frame];

				value += dividerThickness;
				XY(frame.origin, isHorizontal) = value;
				WH(frame.size, isHorizontal) = splitSize - value;
				[view1 setFrame: frame];
				[splitView adjustSubviews];
			}
		}

		if (delegate)
			[splitView setDelegate: delegate];
	}
}


//----------------------------------------------------------------------------------------

void
initSplitViewWithPref (NSSplitView* splitView, NSString* prefsKey, id delegate)
{
	initSplitView(splitView, GetPreferenceFloat(prefsKey), delegate);
}


//----------------------------------------------------------------------------------------
/*
	A | B
	-----
	  C
	The sender can be A & B's parent or AB & C's parent.
	Grows B & C, shrinks A to min of (minWidth, minHeight) before shrinking B or C.
*/

void
resizeSplitView (NSSplitView* sender, NSSize oldSize,
				 GCoord minWidth, GCoord minHeight)
{
	const NSSize newSize = [sender bounds].size;
	const GCoord dividerThickness = [sender dividerThickness],
				 newWidth         = newSize.width,
				 newHeight        = newSize.height;
	NSArray* subviews = [sender subviews];
	NSView* const view0 = [subviews objectAtIndex: 0];
	NSView* const view1 = [subviews objectAtIndex: 1];
	NSRect frame = [view0 frame];

	if ([sender isVertical])
	{
		// Try not to grow the left pane or shrink right pane
		const GCoord delta = newWidth - oldSize.width;
		if (delta < 0)
		{
			const GCoord width = MAX(frame.size.width + delta, minWidth);
			frame.size.width  = width;
			frame.size.height = newHeight;
			[view0 setFrame: frame];

			const GCoord x = width + dividerThickness;
			frame.origin.x   = x;
			frame.size.width = newWidth - x;
			[view1 setFrame: frame];
			return;
		}
		else if (delta > 0)
		{
			frame.size.height = newHeight;
			[view0 setFrame: frame];

			GCoord x = frame.size.width + dividerThickness;
			frame.origin.x   = x;
			frame.size.width = newWidth - x;
			[view1 setFrame: frame];
			return;
		}
	}
	else	// horizontal divider
	{
		// Try not to grow the top pane or shrink bottom pane
		const GCoord delta = newHeight - oldSize.height;
		if (delta < 0)
		{
			const GCoord height = MAX(frame.size.height + delta, minHeight);
			frame.size.height = height;
			frame.size.width  = newWidth;
			[view0 setFrame: frame];

			const GCoord y = height + dividerThickness;
			frame.origin.y    = y;
			frame.size.height = newHeight - y;
			[view1 setFrame: frame];
			return;
		}
		else if (delta > 0)
		{
			frame.size.width = newWidth;
			[view0 setFrame: frame];

			const GCoord y = frame.size.height + dividerThickness;
			frame.origin.y    = y;
			frame.size.height = newHeight - y;
			[view1 setFrame: frame];
			return;
		}
	}

	[sender adjustSubviews];
}


//----------------------------------------------------------------------------------------

void
getSubviewSplitViews (NSView* rootView, NSMutableArray* array)
{
	NSArray* subviews = [rootView subviews];
	if ([subviews count])
	{
		const Class splitViewClass = [NSSplitView class];
		for_each_obj(oEnum, view, subviews)
		{
			if ([view isKindOfClass: splitViewClass])
				[array addObject: view];
			getSubviewSplitViews(view, array);
		}
	}
}


//----------------------------------------------------------------------------------------

NSMutableArray*
getSplitViews (NSWindow* window)
{
	NSMutableArray* array = [NSMutableArray array];
	getSubviewSplitViews([window contentView], array);

	return array;
}


//----------------------------------------------------------------------------------------

NSArray*
getValuesForSplitViews (NSWindow* window)
{
	NSMutableArray* splitViews = getSplitViews(window);

	const int count = [splitViews count];
	int i;
	for (i = 0; i < count; ++i)
	{
		NSSplitView* view = [splitViews objectAtIndex: i];
		const NSSize size = [[[view subviews] objectAtIndex: 0] frame].size;
		id obj = [NSNumber numberWithFloat: get_wh(size, ![view isVertical])];
		[splitViews replaceObjectAtIndex: i withObject: obj];
	}

	return splitViews;
}


//----------------------------------------------------------------------------------------

void
setupSplitViews (NSWindow* window, NSArray* values, id delegate)
{
	NSArray* splitViews = getSplitViews(window);
//	dprintf("(%@): splitViews=%@", values, splitViews);
	int i, count = [splitViews count], valueCount = [values count];
	for (i = 0; i < count; ++i)
	{
		GCoord value = (i < valueCount) ? [[values objectAtIndex: i] floatValue] : 0;
//		dprintf_("    %d splitView=%@ value=%g", i, [splitViews objectAtIndex: i], value);
		initSplitView([splitViews objectAtIndex: i], value, delegate);
	}
//	dprintf_("setupSplitViews: done");
}


//----------------------------------------------------------------------------------------

void
loadSplitViews (NSWindow* window, NSString* prefsKey, id delegate)
{
	id values = GetPreference(prefsKey);
	setupSplitViews(window, ISA(values, NSArray) ? values : nil, delegate);
}


//----------------------------------------------------------------------------------------

void
saveSplitViews (NSWindow* window, NSString* prefsKey)
{
	NSArray* values = getValuesForSplitViews(window);

//	NSLog(@"saveSplitViews: %@", values);
	SetPreference(prefsKey, values);
//	NSLog(@"saveSplitViews: done");
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation NSWindow (ViewUtils)


- (NSMutableArray*) splitViews
{
	return getSplitViews(self);
}


//----------------------------------------------------------------------------------------

- (NSArray*) splitViewsValues
{
	return getValuesForSplitViews(self);
}


//----------------------------------------------------------------------------------------

- (void) splitViewsSetup: (NSArray*) values delegate: (id) delegate
{
	setupSplitViews(self, values, delegate);
}


//----------------------------------------------------------------------------------------

- (void) splitViewsLoad: (NSString*) prefsKey delegate: (id) delegate
{
	loadSplitViews(self, prefsKey, delegate);
}


//----------------------------------------------------------------------------------------

- (void) splitViewsSave: (NSString*) prefsKey
{
	saveSplitViews(self, prefsKey);
}


//----------------------------------------------------------------------------------------


@end	// NSWindow (ViewUtils)


//----------------------------------------------------------------------------------------

void
InitViewUtils ()
{
	static BOOL inited = NO;
	if (inited)
		return;
	inited = YES;
}


//----------------------------------------------------------------------------------------
// End of ViewUtils.m
