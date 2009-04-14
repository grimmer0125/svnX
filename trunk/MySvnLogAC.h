/* MySvnLogAC */

#import <Cocoa/Cocoa.h>

@interface MySvnLogAC : NSArrayController
{
	NSString*	searchMessages;
	NSString*	searchPaths;
}


- (void) search:    (id) sender;
- (void) rearrange: (id) sender;
- (void) clearSearchPaths;

@end
