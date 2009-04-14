//
// EditListResponder.h
//

#import <Cocoa/Cocoa.h>

// Superclass for FavoriteWorkingCopies & RepositoriesController

@interface EditListResponder : NSResponder
{
    IBOutlet NSWindow*		window;
    IBOutlet NSTableView*	tableView;
	IBOutlet NSBox*			editBox;
	NSString*				keyPrefix;	// prefs prefix
}

- (id)        init:          (NSString*) prefsPrefix;
- (void)      awakeFromNib;
- (NSButton*) disclosureView;
- (void)      toggleEdit:    (id) sender;
- (void)      keyDown:       (NSEvent*) theEvent;
- (void)      showWindow;
- (NSArray*)  dataArray;					// subclass to implement
- (void)      savePreferences;				// subclass to implement
- (void)      onDoubleClick: (id) sender;	// subclass to implement

@end

