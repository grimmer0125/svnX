#import "MyWorkingCopyToolbar.h"
#import "NSString+MyAdditions.h"
#include "CommonUtils.h"


//----------------------------------------------------------------------------------------

@implementation MyWorkingCopyToolbar


//----------------------------------------------------------------------------------------

- (NSToolbarItem*) createItem: (NSString*) itsID
				   view:       (NSView*)   itsView, GCoord minWidth, GCoord minHeight,
													GCoord maxWidth, GCoord maxHeight
{
	NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier: itsID];
	[item setPaletteLabel: itsID];
	[item setLabel: itsID];

	[item setView: itsView];
	[item setMinSize: NSMakeSize(minWidth, minHeight)];
	[item setMaxSize: NSMakeSize(maxWidth, maxHeight)];

	[items setObject: item forKey: itsID];
	[item release];
	return item;
}


//----------------------------------------------------------------------------------------

- (NSToolbarItem*) createItem: (NSString*) itsID
				   label:      (NSString*) itsLabel
				   image:      (NSString*) imageName
				   help:       (NSString*) itsHelp
{
	NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier: itsID];
	[item setPaletteLabel: itsLabel];
	[item setLabel: itsLabel];
	[item setToolTip: itsHelp ? itsHelp : itsLabel];
	[item setTarget: controller];
	[item setAction: NSSelectorFromString([itsID stringByAppendingString: @":"])];
	[item setImage: [NSImage imageNamed: imageName]];

	[items setObject: item forKey: itsID];
	[item release];
	return item;
}


//----------------------------------------------------------------------------------------

- (void)awakeFromNib
{
    items = [[NSMutableDictionary alloc] init];

	[self createItem: @"Working Copy Path" view: workingCopyPathView, 150, 18, 340, 32];

	[self createItem: @"Filter" view: filterView, 74, 15, 74, 32];

	[self createItem: @"Search" view: searchView, 60, 19, 130, 32];

	[self createItem: @"View" view: modeView, 62, 20, 62, 20];

	[self createItem: @"refresh" label: @"Refresh" image: @"Refresh"
		  help:       @"Refresh the display.\n"
					   "Alt-click to also show repository updates."];

	[self createItem: @"svnFileMerge" label: @"Diff" image: @"FileMerge"
		  help:       @"Compare selected files with its base revision.\n"
					   "Alt-click to compare other revisions."];

	[self createItem: @"revealInFinder" label: @"Reveal" image: @"Finder"
		  help:       @"Show the selected file in the Finder."];

	[self createItem: @"svnUpdate" label: @"Update" image: @"checkout2"
		  help:       UTF8("Update this working copy to HEAD.\n"
						   "Alt-click to specify a different revision.")];

	[self createItem: @"openRepository" label: @"Repository" image: @"Repository"
		  help:       @"Open repository window for this current working."];

	[self createItem: @"toggleSidebar" label: @"Output" image: @"sidebar"
		  help:       @"Show/Hide output of updates and commits."];
	
    NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier: @"WorkingCopyToolBar2"];
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
	[toolbar setSizeMode: NSToolbarSizeModeDefault];
    [window setToolbar: toolbar];
    [toolbar release];
}

- (void)dealloc
{
    [items release];
    [super dealloc];
}


//----------------------------------------------------------------------------------------

- (NSToolbarItem*) toolbar:                   (NSToolbar*) toolbar
				   itemForItemIdentifier:     (NSString*)  itemIdentifier
				   willBeInsertedIntoToolbar: (BOOL)       flag
{
    return [items objectForKey: itemIdentifier];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:
				@"View",
				NSToolbarSeparatorItemIdentifier,
				@"revealInFinder",
				@"svnFileMerge",
				NSToolbarFlexibleSpaceItemIdentifier,
				@"Search",
				NSToolbarSeparatorItemIdentifier,
				@"svnUpdate",
				NSToolbarSeparatorItemIdentifier,
				@"openRepository",
				@"refresh",
				NSToolbarSeparatorItemIdentifier,
				@"toggleSidebar",
				nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:
				@"View",
				@"Filter",
				@"Working Copy Path",
				@"Search",
				@"revealInFinder",
				@"svnFileMerge",
				@"svnUpdate",
				@"openRepository",
				@"refresh",
				@"toggleSidebar",					
				NSToolbarSeparatorItemIdentifier,
				NSToolbarSpaceItemIdentifier,
				NSToolbarFlexibleSpaceItemIdentifier,
				nil];
}

@end

