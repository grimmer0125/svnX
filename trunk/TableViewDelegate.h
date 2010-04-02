/* TableViewDelegate */

#import <Cocoa/Cocoa.h>

NSString* HelpTagForWCItem (NSDictionary* wcFileInfo);

@interface TableViewDelegate : NSObject
{
	IBOutlet id document;
	IBOutlet id svnFilesAC;
}

@end

