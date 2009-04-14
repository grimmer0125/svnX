/* MyApp */

#import <Cocoa/Cocoa.h>

@class RepositoriesController, FavoriteWorkingCopies;

/* " Application's main controller." */
@interface MyApp : NSObject
{
    IBOutlet id preferencesWindow;
	IBOutlet id favoriteWorkingCopiesWindow;	// Unused
	IBOutlet id tasksManager;
	IBOutlet RepositoriesController *repositoriesController;
	IBOutlet FavoriteWorkingCopies *favoriteWorkingCopies;
}


+ (MyApp*) myApp;

- (void) fileHistoryOpenSheetForItem: (NSString*) path;
	// Compare a single file in a svnX window. Invoked from Applescript.

- (IBAction) openPreferences:  (id) sender;
- (IBAction) closePreferences: (id) sender;

- (void) openRepository: (NSURL*)    url
		 user:           (NSString*) user
		 pass:           (NSString*) pass;

- (bool) checkSVNExistence: (bool) warn;
- (void) newTaskWithDictionary: (NSMutableDictionary*) taskObj;
- (NSString*) getMACAddress;

@end

