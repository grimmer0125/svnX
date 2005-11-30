#import <Cocoa/Cocoa.h>


@interface  NSTextView (MyAdditions)


@end


@implementation NSTextView (MyAdditions)

-  appendString:(NSString *)string isErrorStyle:(BOOL)isErrorStyle
{
	NSFont *txtFont = [NSFont fontWithName:@"Courier" size:11];
	NSDictionary *txtDict;
	
	if ( isErrorStyle )
	{
		txtDict = [NSDictionary dictionaryWithObjectsAndKeys:txtFont, NSFontAttributeName, [NSColor redColor], NSForegroundColorAttributeName, nil];
	
	} else
	{
		txtDict = [NSDictionary dictionaryWithObjectsAndKeys:txtFont, NSFontAttributeName, [NSColor blackColor], NSForegroundColorAttributeName, nil];
	}
	
	NSAttributedString *attrStr = [[[NSAttributedString alloc] initWithString:string attributes:txtDict] autorelease];

	NSRange theEnd = NSMakeRange([[self textStorage] length], 0);

	[[self textStorage] replaceCharactersInRange:theEnd withAttributedString:attrStr];

	theEnd.location += [string length];
//	[self scrollRangeToVisible:theEnd];
}

@end
