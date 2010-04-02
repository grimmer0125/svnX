/* MyDragSupportArrayController */

#import <Cocoa/Cocoa.h>

@interface MyDragSupportArrayController : NSArrayController
{
}

- (void) moveObjectsInArrangedObjectsFromIndexes: (NSIndexSet*) indexSet
		 toIndex:                                 (unsigned)    index;
- (NSIndexSet*) indexSetFromRows: (NSArray*)    rows;
- (int)         rowsAboveRow:     (int)         row
				inIndexSet:       (NSIndexSet*) indexSet;

@end

