//
//  DrawerLogView.h
//  svnX
//
//  Created by Dominique PERETTI on 06/05/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DrawerLogView : NSView
{
	IBOutlet id _view;
	IBOutlet NSTextView *logTextView;
	IBOutlet NSObjectController *documentProxy;

	id document;

	id currentTaskObj;
}

- (void) setUp;
- (void) unload;
- (void) setDocument: (id) aDocument;

@end

