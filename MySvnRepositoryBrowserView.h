/* MySvnRepositoryBrowserView */

#import <Cocoa/Cocoa.h>
#import "MySvnView.h"
#import "SvnListParser.h"

@interface MySvnRepositoryBrowserView : MySvnView
{
	IBOutlet NSBrowser *browser;
	IBOutlet NSTextField *revisionTextField;
	IBOutlet NSMenu *browserContextMenu;
		
	BOOL showRoot;
	BOOL disallowLeaves;
	NSString *browserPath;
}

- (void)fetchSvn;

- (NSString *)browserPath;
- (void)setBrowserPath:(NSString *)aBrowserPath;

@end
