/* SingleFileInspector */

#import <Cocoa/Cocoa.h>

@class MySvn;
@class MyFileMergeController;

@interface SingleFileInspector : NSDocument
{
	NSString *path;
	IBOutlet id fileMergeView;
	IBOutlet MyFileMergeController *fileMergeController;
}

- (NSString *) path;
- (void) setPath: (NSString *) aPath;

@end
