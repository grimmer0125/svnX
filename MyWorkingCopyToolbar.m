#import "MyWorkingCopyToolbar.h"

@implementation MyWorkingCopyToolbar

- (void)awakeFromNib {
    int i;

    NSToolbarItem *workingCopyPathItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"Working Copy Path"];
    NSToolbarItem *filterItem =[[NSToolbarItem alloc] initWithItemIdentifier:@"Filter"];
    NSToolbarItem *searchItem =[[NSToolbarItem alloc] initWithItemIdentifier:@"Search"];
    NSToolbarItem *flatModeItem =[[NSToolbarItem alloc] initWithItemIdentifier:@"Flat Mode"];
    NSToolbarItem *smartModeItem =[[NSToolbarItem alloc] initWithItemIdentifier:@"Smart Mode"];
    NSToolbarItem *refreshItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"Refresh"];
    NSToolbarItem *fileMergeItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"svnFileMerge"];
    NSToolbarItem *revealInFinderItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"revealInFinder"];
    NSToolbarItem *svnUpdateItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"svnUpdate"];
    NSToolbarItem *openRepositoryItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"openRepository"];
    NSToolbarItem *toggleSidebarItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"toggleSidebar"];
	
    items=[[NSMutableDictionary alloc] init];

		
	[workingCopyPathItem setPaletteLabel:@"Working Copy Path"];
	[workingCopyPathItem setLabel:@"Working Copy Path"];
	[workingCopyPathItem setToolTip:@"Working Copy Path"];
	[workingCopyPathItem setTarget:self];
	[workingCopyPathItem setAction:@selector(toolbaritemclicked:)];
	[workingCopyPathItem setView:workingCopyPathView];
	[workingCopyPathItem setMaxSize:NSMakeSize(340, 32)];
	[workingCopyPathItem setMinSize:NSMakeSize(150, 18)];
	[items setObject:workingCopyPathItem forKey:@"Working Copy Path"];
	[workingCopyPathItem release];

	[filterItem setPaletteLabel:@"Filter"];
	[filterItem setLabel:@"Filter"];
	[filterItem setToolTip:@"Filter"];
	[filterItem setTarget:self];
	[filterItem setAction:@selector(toolbaritemclicked:)];
	[filterItem setView:filterView];
	[filterItem setMaxSize:NSMakeSize(76, 32)];
	[filterItem setMinSize:NSMakeSize(76, 15)];
	[items setObject:filterItem forKey:@"Filter"];
	[filterItem release];

	[searchItem setPaletteLabel:@"Search"];
	[searchItem setLabel:@"Search"];
	[searchItem setToolTip:@"Filters the result according to the search string."];
	[searchItem setView:searchView];
	[searchItem setMaxSize:NSMakeSize(130, 32)];
	[searchItem setMinSize:NSMakeSize(60, 19)];
	[items setObject:searchItem forKey:@"Search"];
	[searchItem release];

	[flatModeItem setPaletteLabel:@"Flat Mode"];
	[flatModeItem setLabel:@""];
	[flatModeItem setToolTip:@"Flat mode displays the items with their entire path relative to the working copy root. You cannot move, copy or rename files in flat mode."];
	[flatModeItem setView:flatModeView];
	[flatModeItem setMaxSize:NSMakeSize(70, 19)];
	[flatModeItem setMinSize:NSMakeSize(70, 19)];	
	[items setObject:flatModeItem forKey:@"Flat Mode"];
	[flatModeItem release];

	[smartModeItem setPaletteLabel:@"Smart Mode"];
	[smartModeItem setLabel:@""];
	[smartModeItem setToolTip:@"Smart Mode only displays files that have changed ('svn status').\n Very fast (no network query), but less information is retrieved."];
	[smartModeItem setView:smartModeView];
	[smartModeItem setMaxSize:NSMakeSize(80, 19)];
	[smartModeItem setMinSize:NSMakeSize(80, 19)];	
	[items setObject:smartModeItem forKey:@"Smart Mode"];
	[smartModeItem release];
	
	[refreshItem setPaletteLabel:@"Refresh"];
	[refreshItem setLabel:@"Refresh"];
	[refreshItem setToolTip:@"Refresh"];
	[refreshItem setTarget:controller];
	[refreshItem setAction:@selector(refresh:)];
	[refreshItem setImage:[NSImage imageNamed:@"Reload"]];
	[items setObject:refreshItem forKey:@"Refresh"];
	[refreshItem release];
	
	[fileMergeItem setPaletteLabel:@"FileMerge"];
	[fileMergeItem setLabel:@"FileMerge"];
	[fileMergeItem setToolTip:@"Compares selected file with its pristine copy.\nPress Alt while clicking to compare to other revisions."];
	[fileMergeItem setTarget:controller];
	[fileMergeItem setAction:@selector(svnFileMerge:)];
	[fileMergeItem setImage:[NSImage imageNamed:@"FileMerge"]];
	[items setObject:fileMergeItem forKey:@"svnFileMerge"];
	[fileMergeItem release];

	[revealInFinderItem setPaletteLabel:@"Reveal In Finder"];
	[revealInFinderItem setLabel:@"Reveal In Finder"];
	[revealInFinderItem setToolTip:@"Display the selected file in the Finder"];
	[revealInFinderItem setTarget:controller];
	[revealInFinderItem setAction:@selector(revealInFinder:)];
	[revealInFinderItem setImage:[NSImage imageNamed:@"Finder"]];
	[items setObject:revealInFinderItem forKey:@"revealInFinder"];
	[revealInFinderItem release];

	[svnUpdateItem setPaletteLabel:@"Update"];
	[svnUpdateItem setLabel:@"Update"];
	[svnUpdateItem setToolTip:@"Performs an 'svn update' on current working copy."];
	[svnUpdateItem setTarget:controller];
	[svnUpdateItem setAction:@selector(svnUpdate:)];
	[svnUpdateItem setImage:[NSImage imageNamed:@"checkout2"]];
	[items setObject:svnUpdateItem forKey:@"svnUpdate"];
	[svnUpdateItem release];

	[openRepositoryItem setPaletteLabel:@"Go to repository"];
	[openRepositoryItem setLabel:@"Go to repository"];
	[openRepositoryItem setToolTip:@"Opens a repository window with current working copy's repository."];
	[openRepositoryItem setTarget:controller];
	[openRepositoryItem setAction:@selector(openRepository:)];
	[openRepositoryItem setImage:[NSImage imageNamed:@"repository"]];
	[items setObject:openRepositoryItem forKey:@"openRepository"];
	[openRepositoryItem release];

	[toggleSidebarItem setPaletteLabel:@"Show output"];
	[toggleSidebarItem setLabel:@"Show output"];
	[toggleSidebarItem setToolTip:@"Shows output of updates and commits."];
	[toggleSidebarItem setTarget:controller];
	[toggleSidebarItem setAction:@selector(toggleSidebar:)];
	[toggleSidebarItem setImage:[NSImage imageNamed:@"sidebar"]];
	[items setObject:toggleSidebarItem forKey:@"toggleSidebar"];
	[toggleSidebarItem release];
	
    toolbar=[[NSToolbar alloc] initWithIdentifier:@"WorkingCopyToolBar2"];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[toolbar setSizeMode:NSToolbarSizeModeDefault];
    [window setToolbar:toolbar];
    [toolbar release];

}

- (void)dealloc {
    [items release];
    [super dealloc];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    return [items objectForKey:itemIdentifier];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    return [NSArray arrayWithObjects:
				@"Flat Mode",
				@"Smart Mode",
				NSToolbarSeparatorItemIdentifier,
				@"svnFileMerge",
				@"revealInFinder",
				NSToolbarFlexibleSpaceItemIdentifier,
				@"Search",
				NSToolbarSeparatorItemIdentifier,
				@"svnUpdate",
				NSToolbarSeparatorItemIdentifier,
				@"openRepository",
				@"Refresh",
				NSToolbarSeparatorItemIdentifier,
				@"toggleSidebar",
				nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return [NSArray arrayWithObjects:
				@"Flat Mode",
				@"Smart Mode",
				@"Working Copy Path",
				@"Filter",
				@"Search",
				@"svnFileMerge",
				@"revealInFinder",
				@"svnUpdate",
				@"openRepository",
				@"Refresh",
				@"toggleSidebar",					
				NSToolbarSeparatorItemIdentifier,
				NSToolbarSpaceItemIdentifier,
				NSToolbarFlexibleSpaceItemIdentifier,
				nil];
}

- (int)count {
    return [items count];
}

- (IBAction)customize:(id)sender {
    [toolbar runCustomizationPalette:sender];
}

- (IBAction)showhide:(id)sender {
    [toolbar setVisible:![toolbar isVisible]];
}

- (void)toolbaritemclicked:(NSToolbarItem*)item {
    // log to console that the item was clicked
    //NSLog(@"Click %@!",[item label]);
}
- (NSToolbar *) toolbar { return toolbar; }

@end
