/* MyDragSupportMatrix */

#import <Cocoa/Cocoa.h>

@interface MyDragSupportMatrix : NSMatrix
{
    NSRect	oldDrawRect, newDrawRect;
    BOOL	shouldDraw;
	BOOL	isSubBrowser;

	NSCell*	destinationCell;
}

- (void) setupForSubBrowser;

- (BOOL) isCellSelected: (NSCell*) cell;
- (NSCell*) destinationCell;
- (void) setDestinationCell: (NSCell*) aDestinationCell;

@end
