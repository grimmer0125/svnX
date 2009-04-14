/* MySvnRepositoryBrowserView */

#import <Cocoa/Cocoa.h>
#import "MySvnView.h"

@interface MySvnRepositoryBrowserView : MySvnView
{
	IBOutlet NSBrowser*		browser;
	IBOutlet NSTextField*	revisionTextField;
	IBOutlet NSMenu*		browserContextMenu;

	BOOL					showRoot;
	BOOL					disallowLeaves;
	BOOL					isSubBrowser;
	NSString*				browserPath;
}

- (void) unload;

- (void) onDoubleClick: (id) sender;
- (void) fetchSvn;
- (void) fetchSvnListForUrl: (NSString*) theURL
		 column:             (int)       column
		 matrix:             (NSMatrix*) matrix;

- (void) displayResultArray: (NSArray*)  resultArray
		 column:             (int)       column
		 matrix:             (NSMatrix*) matrix;

- (void) setupForSubBrowser:      (BOOL) showRoot_
		 allowsLeaves:            (BOOL) allowsLeaves
		 allowsMultipleSelection: (BOOL) allowsMultiSel;

- (NSMutableArray*) selectedItems;
- (void) reset;

- (NSString*) browserPath;
- (void) setBrowserPath: (NSString*) aBrowserPath;
- (NSString*) getCachePathForUrl: (NSURL*) theURL;

@end
