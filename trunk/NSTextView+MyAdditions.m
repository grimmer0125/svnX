#import <Cocoa/Cocoa.h>
#import "NSString+MyAdditions.h"


@implementation NSTextView (MyAdditions)

- (void) appendString: (NSString*) string
		 isErrorStyle: (BOOL)      isErrorStyle
{
	static NSDictionary* stdStyle = nil, *errStyle = nil;
	if (stdStyle == nil)
	{
		NSFont* txtFont = [NSFont fontWithName: @"Courier" size: 11];
		stdStyle = [NSDictionary dictionaryWithObjectsAndKeys:
							txtFont, NSFontAttributeName,
							[NSColor blackColor], NSForegroundColorAttributeName,
							nil];
		[stdStyle retain];
		errStyle = [NSDictionary dictionaryWithObjectsAndKeys:
							txtFont, NSFontAttributeName,
							[NSColor redColor], NSForegroundColorAttributeName,
							nil];
		[errStyle retain];
	}

	NSAttributedString* attrStr = [[NSAttributedString alloc]
			initWithString: string attributes: isErrorStyle ? errStyle : stdStyle];
	[[self textStorage] appendAttributedString: attrStr];
	[attrStr release];
}

@end

