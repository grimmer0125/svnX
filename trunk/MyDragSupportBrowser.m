#import "MyDragSupportBrowser.h"
#import "MyDragSupportMatrix.h"

@implementation MyDragSupportBrowser


- (id) initWithCoder: (NSCoder*) decoder
{
	if (self = [super initWithCoder: decoder])
	{
		[self setMatrixClass: [MyDragSupportMatrix class]];
	}
	return self;
}


//----------------------------------------------------------------------------------------
// Called by MyDragSupportMatrix

- (void) onDoubleClick: (id) sender
{
//	NSLog(@"onDoubleClick: delegate=%@", [self delegate]);
	[[self delegate] onDoubleClick: sender];
}


@end

