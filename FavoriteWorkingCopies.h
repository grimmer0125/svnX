/* WorkingCopies */

#import <Cocoa/Cocoa.h>
#import "EditListResponder.h"

/* "Implements BOTH the model and the controller of the favorite working copies panel. "*/
@interface FavoriteWorkingCopies : EditListResponder
{
}

// Adds a new working copy with the given path.
- (void) newWorkingCopyItemWithPath: (NSString*) workingCopyPath;

// Open a working copy window. Invoked from Applescript.
- (void) openWorkingCopy: (NSString*) aPath;

// Open a compare revisions sheet for <aPath> on an appropriate Working Copy window.
- (void) fileHistoryOpenSheetForItem: (NSString*) aPath;

@end

