/* WorkingCopies */

#import <Cocoa/Cocoa.h>
#import "EditListResponder.h"

@class MyDragSupportArrayController;

/* "Implements BOTH the model and the controller of the favorite working copies panel. "*/
@interface FavoriteWorkingCopies : EditListResponder
{
	NSMutableArray *favoriteWorkingCopies;
	IBOutlet MyDragSupportArrayController *favoriteWorkingCopiesAC;

	IBOutlet id nameTextField;
	IBOutlet id pathTextField;
	IBOutlet id workingCopiesTableView;

	IBOutlet id application;
}

- (IBAction)newWorkingCopyItem:(id)sender;

- (IBAction)openPath:(id)sender;
- (IBAction)onValidate:(id)sender;

- (NSArray*) dataArray;
- (void)saveFavoriteWorkingCopiesPrefs;

- (void)onDoubleClick:(id)sender;

// Adds a new working copy with the given path.
- (void)newWorkingCopyItemWithPath:(NSString *)workingCopyPath;

@end

