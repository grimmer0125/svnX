//--------------------------------------------------------------------
//	IconTextCell.h - An NSTextFieldCell with both an icon & text.
//
//	Copyright © Chris, 2007 - 2010.  All rights reserved.
//--------------------------------------------------------------------

#import <Cocoa/Cocoa.h>


@interface IconTextCell : NSTextFieldCell
{
@protected
	IconRef		fIconRef;
}

- (void) setIconRef: (IconRef) iconRef;

@end	// IconTextCell

@interface MiniIconTextCell : IconTextCell @end

