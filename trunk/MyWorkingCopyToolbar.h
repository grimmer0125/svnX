
@class MyWorkingCopyController;

@interface MyWorkingCopyToolbar : NSObject
{
	IBOutlet MyWorkingCopyController* controller;
	IBOutlet id window;
	IBOutlet id workingCopyPathView;
	IBOutlet id refreshView;
	IBOutlet id filterView;
	IBOutlet id searchView;
	IBOutlet id modeView;

	NSMutableDictionary *items; // all items that are allowed to be in the toolbar
}


- (void)awakeFromNib;

- (void)dealloc;

// toolbar datasource

- (NSToolbarItem*) toolbar:                   (NSToolbar*) toolbar
				   itemForItemIdentifier:     (NSString*)  itemIdentifier
				   willBeInsertedIntoToolbar: (BOOL)       flag;

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;

@end

