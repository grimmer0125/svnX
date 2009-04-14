/* TableViewDelegate */

#import <Cocoa/Cocoa.h>

NSString* helpTagForWCFile (NSDictionary* wcFileInfo);

@interface TableViewDelegate : NSObject
{
    IBOutlet id document;
	IBOutlet id svnFilesAC;
}

@end
