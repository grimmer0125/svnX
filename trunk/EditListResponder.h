//
// EditListResponder.h
//

#import <Cocoa/Cocoa.h>

typedef struct EditListPrefKeys
	{ NSString* data, *editShown, *panelFrame, *dragType; } EditListPrefKeys;

// Superclass for FavoriteWorkingCopies & RepositoriesController

@interface EditListResponder : NSResponder
{
	IBOutlet NSWindow*			fWindow;
	IBOutlet NSTableView*		fTableView;
	IBOutlet NSBox*				fEditBox;
	IBOutlet NSArrayController*	fAC;
	NSMutableArray*				fDataArray;
	const EditListPrefKeys*		fPrefKeys;
}

- (id)        init:          (const EditListPrefKeys*) prefsKeys;
- (id)        newObject:     (NSPasteboard*) pboard;
- (void)      savePreferences;
- (void)      awakeFromNib;
- (void)      showWindow;
- (NSButton*) disclosureView;
- (NSTextField*) nameTextField;
- (void)      keyDown:       (NSEvent*) theEvent;
- (void)      onDoubleClick: (id) sender;	// subclass to implement
- (IBAction)  toggleEdit:    (id) sender;
- (IBAction)  newItem:       (id) sender;	// subclass to implement
- (IBAction)  removeItem:    (id) sender;	// subclass to implement
- (IBAction)  openPath:      (id) sender;	// subclass to implement
- (IBAction)  onValidate:    (id) sender;

@end

