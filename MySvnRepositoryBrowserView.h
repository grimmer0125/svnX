/* MySvnRepositoryBrowserView */

#import <Cocoa/Cocoa.h>
#import "MySvnView.h"

@interface MySvnRepositoryBrowserView : MySvnView
{
	IBOutlet NSBrowser *browser;
	IBOutlet NSTextField *revisionTextField;
		
	BOOL showRoot;
	BOOL disallowLeaves;
	NSString *browserPath;
}

- (void)fetchSvn;

- (NSString *)browserPath;
- (void)setBrowserPath:(NSString *)aBrowserPath;

@end
