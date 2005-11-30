/* MyDragSupportMatrix */

#import <Cocoa/Cocoa.h>

@interface MyDragSupportMatrix : NSMatrix
{
    NSRect oldDrawRect, newDrawRect;
    BOOL shouldDraw;

	NSCell *destinationCell;
}
@end
