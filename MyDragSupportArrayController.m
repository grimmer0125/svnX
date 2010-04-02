#import "MyDragSupportArrayController.h"

@implementation MyDragSupportArrayController

-(void) moveObjectsInArrangedObjectsFromIndexes: (NSIndexSet*) indexSet
		toIndex:                                 (unsigned)    index
{
	unsigned off1 = 0, off2 = 0;
	unsigned currentIndex = [indexSet firstIndex];
	while (currentIndex != NSNotFound)
	{
		unsigned i = currentIndex;

		if (i < index)
		{
			i -= off1++;
			[self insertObject: [[self arrangedObjects] objectAtIndex: i] atArrangedObjectIndex: index];
			[self removeObjectAtArrangedObjectIndex: i];
		}
		else
		{
			[self insertObject: [[self arrangedObjects] objectAtIndex: i] atArrangedObjectIndex: index + off2++];
			[self removeObjectAtArrangedObjectIndex: i + 1];
		}
		currentIndex = [indexSet indexGreaterThanIndex: currentIndex];
	}
}


- (NSIndexSet*) indexSetFromRows: (NSArray*) rows
{
	NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
	NSEnumerator *rowEnumerator = [rows objectEnumerator];
	NSNumber *idx;
	while (idx = [rowEnumerator nextObject])
	{
		[indexSet addIndex: [idx intValue]];
	}
	return indexSet;
}


- (int) rowsAboveRow: (int)         row
		inIndexSet:   (NSIndexSet*) indexSet
{
	unsigned currentIndex = [indexSet firstIndex];
	int i = 0;
	while (currentIndex != NSNotFound)
	{
		if (currentIndex < row) { i++; }
		currentIndex = [indexSet indexGreaterThanIndex: currentIndex];
	}
	return i;
}


@end

