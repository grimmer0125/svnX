
#import "MyRepositoryToolbar.h"


@implementation MyRepositoryToolbar

- (void)awakeFromNib {
    int i;
	
    NSToolbarItem *svnCopyItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"svnCopy"];
    NSToolbarItem *svnMoveItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"svnMove"];
    NSToolbarItem *svnMkdirItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"svnMkdir"];
    NSToolbarItem *svnDelete=[[NSToolbarItem alloc] initWithItemIdentifier:@"svnDelete"];
    NSToolbarItem *svnCheckout=[[NSToolbarItem alloc] initWithItemIdentifier:@"svnCheckout"];
    NSToolbarItem *svnExport=[[NSToolbarItem alloc] initWithItemIdentifier:@"svnExport"];
    NSToolbarItem *fileMergeItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"svnFileMerge"];
    NSToolbarItem *toggleSidebarItem=[[NSToolbarItem alloc] initWithItemIdentifier:@"toggleSidebar"];

    items=[[NSMutableDictionary alloc] init];

	[svnMoveItem setPaletteLabel:@"svnMove"];
	[svnMoveItem setLabel:@"svn move"];
	[svnMoveItem setToolTip:@"Select an item to move and click."];
	[svnMoveItem setTarget:document];
	[svnMoveItem setAction:@selector(svnMove:)];
	[svnMoveItem setImage:[NSImage imageNamed:@"svnMove"]];
	[items setObject:svnMoveItem forKey:@"svnMove"];
	[svnMoveItem release];

	[svnCopyItem setPaletteLabel:@"svnCopy"];
	[svnCopyItem setLabel:@"svn copy"];
	[svnCopyItem setToolTip:@"Select a folder for branching or tagging and click."];
	[svnCopyItem setTarget:document];
	[svnCopyItem setAction:@selector(svnCopy:)];
	[svnCopyItem setImage:[NSImage imageNamed:@"svnCopy"]];
	[items setObject:svnCopyItem forKey:@"svnCopy"];
	[svnCopyItem release];

	[svnMkdirItem setPaletteLabel:@"svn mkdir"];
	[svnMkdirItem setLabel:@"svn mkdir"];
	[svnMkdirItem setToolTip:@"Click to create one or more directories via immediate commit."];
	[svnMkdirItem setTarget:document];
	[svnMkdirItem setAction:@selector(svnMkdir:)];
	[svnMkdirItem setImage:[NSImage imageNamed:@"mkdir"]];
	[items setObject:svnMkdirItem forKey:@"svnMkdir"];
	[svnMkdirItem release];

	[svnDelete setPaletteLabel:@"svn delete"];
	[svnDelete setLabel:@"svn delete"];
	[svnDelete setToolTip:@"Click to select items to delete via immediate commit."];
	[svnDelete setTarget:document];
	[svnDelete setAction:@selector(svnDelete:)];
	[svnDelete setImage:[NSImage imageNamed:@"delete"]];
	[items setObject:svnDelete forKey:@"svnDelete"];
	[svnDelete release];
	
	[svnCheckout setPaletteLabel:@"svn checkout"];
	[svnCheckout setLabel:@"svn checkout"];
	[svnCheckout setToolTip:@"Select a revision and a path to checkout and click."];
	[svnCheckout setTarget:document];
	[svnCheckout setAction:@selector(svnCheckout:)];
	[svnCheckout setImage:[NSImage imageNamed:@"checkout2"]];
	[items setObject:svnCheckout forKey:@"svnCheckout"];
	[svnCheckout release];

	[svnExport setPaletteLabel:@"svn export"];
	[svnExport setLabel:@"svn export"];
	[svnExport setToolTip:@"Select a revision and a path to export and click."];
	[svnExport setTarget:document];
	[svnExport setAction:@selector(svnExport:)];
	[svnExport setImage:[NSImage imageNamed:@"export"]];
	[items setObject:svnExport forKey:@"svnExport"];
	[svnExport release];
	
	[fileMergeItem setPaletteLabel:@"FileMerge"];
	[fileMergeItem setLabel:@"FileMerge"];
	[fileMergeItem setToolTip:@"Compare revisions of a file in the repository."];
	[fileMergeItem setTarget:document];
	[fileMergeItem setAction:@selector(svnFileMerge:)];
	[fileMergeItem setImage:[NSImage imageNamed:@"FileMerge"]];
	[items setObject:fileMergeItem forKey:@"svnFileMerge"];
	[fileMergeItem release];

	[toggleSidebarItem setPaletteLabel:@"Show output"];
	[toggleSidebarItem setLabel:@"Show output"];
	[toggleSidebarItem setToolTip:@"Shows output of main operations."];
	[toggleSidebarItem setTarget:document];
	[toggleSidebarItem setAction:@selector(toggleSidebar:)];
	[toggleSidebarItem setImage:[NSImage imageNamed:@"sidebar"]];
	[items setObject:toggleSidebarItem forKey:@"toggleSidebar"];
	[toggleSidebarItem release];

    toolbar=[[NSToolbar alloc] initWithIdentifier:@"RepositoryToolBar2"];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeDefault];
	[toolbar setSizeMode:NSToolbarSizeModeDefault];
    [window setToolbar:toolbar];
    [toolbar release];
    
    [window makeKeyAndOrderFront:nil];
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
					@"svnCopy",
					@"svnMove",
					@"svnMkdir",
					@"svnDelete",
					@"svnFileMerge",
					NSToolbarFlexibleSpaceItemIdentifier,
					@"svnCheckout",
					@"svnExport",
					NSToolbarSeparatorItemIdentifier,
					@"toggleSidebar",
					nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return [NSArray arrayWithObjects:
					NSToolbarSeparatorItemIdentifier,
					NSToolbarSpaceItemIdentifier,
					NSToolbarFlexibleSpaceItemIdentifier,
					@"svnCopy",
					@"svnMove",
					@"svnMkdir",
					@"svnDelete",
					@"svnCheckout",
					@"svnExport",					
					@"svnFileMerge",
					@"toggleSidebar",
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
}
- (NSToolbar *) toolbar { return toolbar; }

@end
