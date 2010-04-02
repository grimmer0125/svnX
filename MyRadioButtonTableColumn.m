#import "MyRadioButtonTableColumn.h"

@implementation MyRadioButtonTableColumn

- (void) awakeFromNib
{
	NSButtonCell* checkBox = [NSButtonCell new];
	[checkBox setButtonType: NSRadioButton];
	[checkBox setTitle: @""];
	[checkBox setRefusesFirstResponder: YES];
	[checkBox setControlSize: NSMiniControlSize];
	[checkBox setState: NSOnState];
//	[checkBox setFrameSize: NSMakeSize(8, 8)];

	[self setDataCell: checkBox];
	[checkBox release];
}

@end

