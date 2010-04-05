//----------------------------------------------------------------------------------------
//  DrawerLogView.h - svnX
//
//  Created by Dominique PERETTI on 06/05/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//	Copyright © Chris, 2007 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>


@interface DrawerLogView : NSView
{
	IBOutlet id _view;
	IBOutlet NSTextView *logTextView;
	IBOutlet NSObjectController *documentProxy;

	id fDocument;
	id currentTaskObj;
}

- (void) setup:     (NSDocument*) document
		 forWindow: (NSWindow*)   window;

@end

