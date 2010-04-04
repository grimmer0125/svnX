//----------------------------------------------------------------------------------------
//	IconTextCell.m - An NSTextFieldCell which displays both an icon & text.
//
//	Copyright © Chris, 2007 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "IconTextCell.h"
#import "CommonUtils.h"


enum {
	kIconSize		=	16,
	kIconLeft		=	0,
	kIconRight		=	4,
	kIconWidth		=	kIconLeft + kIconSize + kIconRight,

	kMiniIconSize	=	12,
	kMiniIconLeft	=	3,
	kMiniIconRight	=	0,
	kMiniIconWidth	=	kMiniIconLeft + kMiniIconSize + kMiniIconRight
};

#define	fMini		_tfFlags.mini


//----------------------------------------------------------------------------------------

@implementation IconTextCell

//----------------------------------------------------------------------------------------
// Set the IconRef for a standard size icon text cell.

- (void) setIconRef: (IconRef) iconRef
{
	fMini    = 0;
	fIconRef = iconRef;
}


//----------------------------------------------------------------------------------------

- (void) editWithFrame: (NSRect)   aRect
		 inView:        (NSView*)  controlView
		 editor:        (NSText*)  textObj
		 delegate:      (id)       anObject
		 event:         (NSEvent*) theEvent
{
	const GCoord width = fMini ? kMiniIconWidth : kIconWidth;
	aRect.origin.x    += width;
	aRect.origin.y    += 1;
	aRect.size.width  -= width;
	aRect.size.height -= 2;
	[super editWithFrame: aRect inView: controlView editor: textObj delegate: anObject event: theEvent];
}


//----------------------------------------------------------------------------------------

- (void) selectWithFrame: (NSRect)  aRect
		 inView:          (NSView*) controlView
		 editor:          (NSText*) textObj
		 delegate:        (id)      anObject
		 start:           (int)     selStart
		 length:          (int)     selLength
{
	const GCoord width = fMini ? kMiniIconWidth : kIconWidth;
	aRect.origin.x   += width;
	aRect.size.width -= width;
	[super selectWithFrame: aRect
					inView: controlView
					editor: textObj
				  delegate: anObject
					 start: selStart
					length: selLength];
}


//----------------------------------------------------------------------------------------

- (void) drawWithFrame: (NSRect)  cellFrame
		 inView:        (NSView*) controlView
{
	if (fIconRef != NULL)
	{
		CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];

		const BOOL mini = fMini;
		const GCoord size  = mini ? kMiniIconSize : kIconSize,
					 width = mini ? kMiniIconWidth : kIconWidth;
		const CGRect rect = {{ mini ? kMiniIconLeft : kIconLeft, -size }, { size, size }};
		CGAffineTransform mat = { 1, 0, 0, -1, cellFrame.origin.x,
								  cellFrame.origin.y + floor((cellFrame.size.height - size) * 0.5) };
		CGContextSaveGState(ctx);
		CGContextConcatCTM(ctx, mat);
		WarnIf(PlotIconRefInContext(ctx, &rect, kAlignNone, kTransformNone,
									NULL, kPlotIconRefNormalFlags, fIconRef));
		CGContextRestoreGState(ctx);
		cellFrame.origin.x    += width;
		cellFrame.origin.y    += 1;
		cellFrame.size.width  -= width;
		cellFrame.size.height -= 2;
	}
	[super drawWithFrame: cellFrame inView: controlView];	// Draws the text
}


//----------------------------------------------------------------------------------------

- (NSSize) cellSize
{
	NSSize cellSize = [super cellSize];
	const BOOL mini = fMini;
	cellSize.width += fIconRef ? (mini ? kMiniIconWidth : kIconWidth)
							   : (mini ? kMiniIconLeft + kMiniIconRight : kIconLeft + kIconRight);
	return cellSize;
}


//----------------------------------------------------------------------------------------

@end	// IconTextCell


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation MiniIconTextCell


//----------------------------------------------------------------------------------------
// Set the IconRef for a mini size icon text cell.

- (void) setIconRef: (IconRef) iconRef
{
	fMini    = 1;
	fIconRef = iconRef;
}


//----------------------------------------------------------------------------------------

@end	// MiniIconTextCell


//----------------------------------------------------------------------------------------
// End of IconTextCell.m
