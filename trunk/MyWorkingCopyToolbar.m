//
//	MyWorkingCopyToolbar.m
//

#import "MyWorkingCopyToolbar.h"
#import "NSString+MyAdditions.h"
#import "CommonUtils.h"


@implementation MyWorkingCopyToolbar


//----------------------------------------------------------------------------------------
// Private:

- (NSToolbarItem*) createItem: (NSString*) itsID
				   view:       (NSView*)   itsView,
							   GCoord minWidth, GCoord minHeight,
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
// Private:

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

- (void) awakeFromNib
{
	items = [[NSMutableDictionary alloc] init];

	[self createItem: @"Filter" view: filterView, 74, 15, 74, 32];

	[self createItem: @"Search" view: searchView, 60, 19, 130, 32];

	[self createItem: @"View" view: modeView, 62, 20, 62, 20];

	[self createItem: @"refresh" label: @"Refresh" image: @"Refresh"
		  help:       @"Refresh the display.\n"
					   "Alt-click to also show repository updates."];

	[self createItem: @"svnDiff" label: @"Diff" image: @"FileMerge"
		  help:       @"Compare each selected file with its BASE revision.\n"
					   "Shift-click to compare with PREV revision.\n"
					   "Alt-click to compare other revisions."];

	[self createItem: @"revealInFinder" label: @"Reveal" image: @"Finder"
		  help:       @"Show the selected file in the Finder."];

	[self createItem: @"svnUpdate" label: @"Update" image: @"checkout2"
		  help:       @"Update this working copy to HEAD.\n"
					   "Alt-click to specify a different revision."];

	[self createItem: @"openRepository" label: @"Repository" image: @"Repository"
		  help:       @"Open repository window for this working copy."];

	[self createItem: @"togglePropsView" label: @"Properties" image: @"Properties"
		  help:       @"Show/Hide Subversion properties editor."];

	[self createItem: @"toggleSidebar" label: @"Output" image: @"sidebar"
		  help:       @"Show/Hide output of updates, commits, merges, etc."];

	NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier: @"WorkingCopyToolBar2"];
	[toolbar setDelegate: self];
	[toolbar setAllowsUserCustomization: YES];
	[toolbar setAutosavesConfiguration: YES];
	[toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
	[toolbar setSizeMode: NSToolbarSizeModeDefault];
	[window setToolbar: toolbar];
	[toolbar release];
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[items release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (NSToolbarItem*) toolbar:                   (NSToolbar*) toolbar
				   itemForItemIdentifier:     (NSString*)  itemIdentifier
				   willBeInsertedIntoToolbar: (BOOL)       flag
{
	#pragma unused(toolbar, flag)
	return [items objectForKey: itemIdentifier];
}


//----------------------------------------------------------------------------------------

- (NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar*) toolbar
{
	#pragma unused(toolbar)
	return [NSArray arrayWithObjects:
				@"View",
				@"Filter",
				@"Search",
				@"revealInFinder",
				@"svnDiff",
				NSToolbarSeparatorItemIdentifier,
				@"svnUpdate",
				@"openRepository",
				@"refresh",
				NSToolbarFlexibleSpaceItemIdentifier,
				@"togglePropsView",
				@"toggleSidebar",
				nil];
}


//----------------------------------------------------------------------------------------

- (NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar*) toolbar
{
	#pragma unused(toolbar)
	return [NSArray arrayWithObjects:
				@"View",
				@"Filter",
				@"Search",
				@"revealInFinder",
				@"svnDiff",
				@"svnUpdate",
				@"openRepository",
				@"refresh",
				@"togglePropsView",
				@"toggleSidebar",
				NSToolbarSeparatorItemIdentifier,
				NSToolbarSpaceItemIdentifier,
				NSToolbarFlexibleSpaceItemIdentifier,
				nil];
}


//----------------------------------------------------------------------------------------

@end	// MyWorkingCopyToolbar

