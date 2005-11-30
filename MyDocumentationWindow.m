#import "MyDocumentationWindow.h"

@implementation MyDocumentationWindow

-(void)awakeFromNib
{
	[[[[[[[[self contentView] subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0] readRTFDFromFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Resources/Documentation.rtf" ]];
}

@end
