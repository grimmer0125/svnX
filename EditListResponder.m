//
// EditListResponder.m
//

#import "EditListResponder.h"
#include "CommonUtils.h"


@implementation EditListResponder

//----------------------------------------------------------------------------------------

- (id) init: (NSString*) prefsPrefix
{
	self = [super init];
	if (self)
	{
		tableView = nil;
		keyPrefix = prefsPrefix;
	}

	return self;
}

//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
	if (tableView)
	{
		[self setNextResponder: [tableView nextResponder]];
		[tableView setNextResponder: self];

		[tableView setDoubleAction: @selector(onDoubleClick:)];
		[tableView setTarget: self];
	}

	// Hide the Edit views if the prefs dictate & then set the window frame
	NSString* keyEditShown = [keyPrefix stringByAppendingString: @"EditShown"];
	if ([[NSUserDefaults standardUserDefaults] objectForKey: keyEditShown] == kNSFalse)
	{
		[[self disclosureView] setState: 0];
		[self toggleEdit: nil];		// hide it
	}
	NSString* keyFrame = [keyPrefix stringByAppendingString: @"PanelFrame"];
	[window setFrameAutosaveName: keyFrame];
	if (![window setFrameUsingName: keyFrame])
		/*[window setFrameTopLeftPoint: NSMakePoint(200, 44)]*/;
}


//----------------------------------------------------------------------------------------

- (NSButton*) disclosureView
{
	return [[window contentView] viewWithTag: 1001];
}


//----------------------------------------------------------------------------------------
// Hide/Show the Edit views

- (void) toggleEdit: (id) sender
{
	const bool isVisible = (sender != nil);
	NSView* contentView = [window contentView];
	NSView* scrollView = [[contentView subviews] objectAtIndex: 0];
//	NSView* scrollView = [[[contentView viewWithTag: 1000] superview] superview];

	const bool doShow = [editBox isHidden];
	if (doShow)
		[editBox setHidden: false];
	NSRect rect = [editBox frame];
	const GCoord dy = doShow ? rect.size.height : -rect.size.height;

	const UInt32 sizeScroll = [scrollView autoresizingMask],
				 sizeEdit   = [editBox autoresizingMask];

	[scrollView setAutoresizingMask: NSViewMinYMargin];
	[editBox    setAutoresizingMask: NSViewMinYMargin];

	rect = [window frame];
	rect.size.height += dy;
	rect.origin.y    -= dy;
	[window setFrame: rect display: isVisible animate: isVisible];

	[scrollView setAutoresizingMask: sizeScroll];
	[editBox    setAutoresizingMask: sizeEdit];

	if (!doShow)
		[editBox setHidden: true];

	[window makeFirstResponder: doShow ? [editBox nextValidKeyView] : scrollView];
	NSSize size = [window minSize];
	size.height += dy;
	[window setMinSize: size];
	if (isVisible)
		[self savePreferences];
//	[[tableView cornerView] setNeedsDisplay: true];
}


//----------------------------------------------------------------------------------------

- (void) keyDown: (NSEvent*) theEvent
{
	const unichar ch = [[theEvent characters] characterAtIndex: 0];
	if (ch == '\r' || ch == 3)
		[self onDoubleClick: nil];
	else if (ch >= ' ')
	{
		const int rows = [tableView numberOfRows];
		int i, selRow = [tableView selectedRow];
		if (selRow < 0)
			selRow = rows - 1;
		unichar ch0 = (ch >= 'a' && ch <= 'z') ? (ch - 32) : ch;
	//	NSString* prefix = [NSString stringWithCharacters: &ch0 length: 1];
		NSArray* const dataArray = [self dataArray];
		for (i = 1; i <= rows; ++i)
		{
			int index = (selRow + i) % rows;
			id wc = [dataArray objectAtIndex: index];
			NSString* name = [wc objectForKey: @"name"];
			if ([name length] && ([name characterAtIndex: 0] & ~0x20) == ch0)
	//		if ([[wc objectForKey: @"name"] hasPrefix: prefix])
			{
				[tableView selectRow: index byExtendingSelection: false];
				[tableView scrollRowToVisible: index];
				break;
			}
		}
	}
	else
		[super keyDown: theEvent];
}


//----------------------------------------------------------------------------------------

- (void) showWindow
{
	[window makeKeyAndOrderFront: nil];
}


//----------------------------------------------------------------------------------------
// subclass to implement

- (NSArray*) dataArray
{
	return nil;
}


//----------------------------------------------------------------------------------------
// subclass to implement

- (void) savePreferences
{
}


//----------------------------------------------------------------------------------------
// subclass to implement

- (void) onDoubleClick: (id) sender
{
}


//----------------------------------------------------------------------------------------

@end


//----------------------------------------------------------------------------------------
// End of EditListResponder.m
