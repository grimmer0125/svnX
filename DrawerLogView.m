//----------------------------------------------------------------------------------------
//	DrawerLogView.m - 
//
//	Copyright © Chris, 2007 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "DrawerLogView.h"
#import "MySvn.h"
#import "NSString+MyAdditions.h"
#import "CommonUtils.h"


@implementation DrawerLogView


- (id) initWithFrame: (NSRect) frame
{
	if (self = [super initWithFrame: frame])
	{
		if ([NSBundle loadNibNamed: @"DrawerLogView" owner: self])
		{
			[_view setFrame: [self bounds]];
			[self addSubview: _view];
		}
	}
	return self;
}


//----------------------------------------------------------------------------------------
// - document : A MyRepository or a MyWorkingCopy instance

- (id) document { return fDocument; }


- (void) setDocument: (id) aDocument
{
	Assert(fDocument == nil);
	fDocument = [aDocument retain];
}


//----------------------------------------------------------------------------------------

- (void) setup:     (NSDocument*) document
		 forWindow: (NSWindow*)   window
{
	[self setDocument: document];
	[fDocument addObserver: self forKeyPath: @"displayedTaskObj.newStdout"
			  options: NSKeyValueObservingOptionNew context: NULL];
	[fDocument addObserver: self forKeyPath: @"displayedTaskObj.newStderr"
			  options: NSKeyValueObservingOptionNew context: NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver: self selector: @selector(unload)
			   name: NSWindowWillCloseNotification object: window];
}


//----------------------------------------------------------------------------------------

- (void) unload
{
	[fDocument removeObserver: self forKeyPath: @"displayedTaskObj.newStdout"];
	[fDocument removeObserver: self forKeyPath: @"displayedTaskObj.newStderr"];
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	const id docProxy = documentProxy;
	documentProxy = nil;
	const id view = _view;
	_view = nil;

	// objects that are bound to the file owner retain it
	// we need to unbind them
	[docProxy unbind: @"contentObject"];

	// the owner has to release its top level nib objects
	[docProxy release];
	[view release];

	[fDocument release];
	fDocument = nil;
}


//----------------------------------------------------------------------------------------

- (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	#pragma unused(object, change, context)
	NSDictionary *taskObj = [fDocument valueForKey: @"displayedTaskObj"];

	if ( taskObj != nil )
	{
		if ( taskObj != currentTaskObj )
		{
			[[logTextView textStorage] setAttributedString: [taskObj objectForKey: @"combinedLog"]];
			currentTaskObj = taskObj;
		}

		if ( [keyPath isEqualToString: @"displayedTaskObj.newStdout"] )
		{
			[logTextView appendString: [taskObj objectForKey: @"newStdout"] isErrorStyle: NO];
		}
		else
		{
			[logTextView appendString: [taskObj objectForKey: @"newStderr"] isErrorStyle: YES];
		}
	}
	else
		[logTextView setString: @""];
}


//----------------------------------------------------------------------------------------

- (IBAction) stopDisplayedTask: (id) sender
{
	#pragma unused(sender)
	id taskObj = [fDocument valueForKey: @"displayedTaskObj"];

	if (taskObj)
		[MySvn killTask: taskObj force: AltOrShiftPressed()];
}


//----------------------------------------------------------------------------------------

@end	// DrawerLogView

