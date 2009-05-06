
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

- (void) dealloc
{
	[self setDocument: nil];
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (void) setUp
{
	[document addObserver: self forKeyPath: @"displayedTaskObj.newStdout"
			  options: (NSKeyValueObservingOptionNew) context: nil];
	[document addObserver: self forKeyPath: @"displayedTaskObj.newStderr"
			  options: (NSKeyValueObservingOptionNew) context: nil];
}


//----------------------------------------------------------------------------------------

- (void) unload
{
	[document removeObserver: self forKeyPath: @"displayedTaskObj.newStdout"];
	[document removeObserver: self forKeyPath: @"displayedTaskObj.newStderr"];

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
}


//----------------------------------------------------------------------------------------

- (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	#pragma unused(object, change, context)
	NSDictionary *taskObj = [document valueForKey: @"displayedTaskObj"];

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
	id taskObj = [document valueForKey: @"displayedTaskObj"];
	
	if ( taskObj == nil ) return;
	
	if (AltOrShiftPressed())
	{
		[MySvn killProcess: [[taskObj objectForKey: @"pid"] intValue]];
	}
	else
	{
		[[taskObj objectForKey: @"task"] terminate];
	}	
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Accessors
//----------------------------------------------------------------------------------------
// - document : A MyRepository or a MyWorkingCopy instance

- (id) document { return document; }


- (void) setDocument: (id) aDocument
{
	id old = document;
	document = [aDocument retain];
	[old release];
}


@end

