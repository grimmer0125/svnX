//
// MyRepositoryToolbar.m
//

#import "MyRepositoryToolbar.h"
#import "NSString+MyAdditions.h"


@implementation MyRepositoryToolbar

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
	if (itsHelp)
		[item setToolTip: itsHelp];
	[item setTarget: document];
	[item setAction: NSSelectorFromString([itsID stringByAppendingString: @":"])];
	[item setImage: [NSImage imageNamed: imageName]];
	[items setObject: item forKey: itsID];
	[item release];
	return item;
}


//----------------------------------------------------------------------------------------
// Private:

- (NSToolbarItem*) createItem: (NSString*) itsID
				   label:      (NSString*) itsLabel
				   help:       (NSString*) itsHelp
{
	return [self createItem: itsID label: itsLabel image: itsID help: itsHelp];
}


//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
	items = [[NSMutableDictionary alloc] init];

	[self createItem: @"svnCopy"       label: @"Copy"
				help: @"Copy selected item within the repository."];
	[self createItem: @"svnMove"       label: @"Move"
				help: @"Move selected item within the repository."];
	[self createItem: @"svnMkdir"      label: @"Make Dir" image: @"mkdir"
				help: @"Create directories in the repository."];
	[self createItem: @"svnDelete"     label: @"Delete"   image: @"delete"
				help: @"Delete items in the repository."];
	[self createItem: @"svnCheckout"   label: @"Checkout" image: @"checkout2"
				help: @"Checkout items from the repository."];
	[self createItem: @"svnImport"     label: @"Import"   image: @"import"
				help: @"Import a file or folder into the repository."];
	[self createItem: @"svnExport"     label: @"Export"   image: @"export"
				help: @"Export items from the repository."];
	[self createItem: @"svnFileMerge"  label: @"Diff"     image: @"FileMerge"
				help: @"Compare revisions of an item in the repository."];
	[self createItem: @"svnOpen"       label: @"Open"     image: @"open"
				help: @"Open the selected repository items."];
	[self createItem: @"svnBlame"      label: @"Blame"
				help: @"Show the content of files with revision and author information in-line."];
	[self createItem: @"svnReport"     label: @"Report"
				help: UTF8("Generate a printable report of the selected item\xE2\x80\x99s log.")];
	[self createItem: @"toggleSidebar" label: @"Output"   image: @"sidebar"
				help: @"Show/Hide output of main operations."];

	NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier: @"RepositoryToolBar2"];
	[toolbar setDelegate: self];
	[toolbar setAllowsUserCustomization: YES];
	[toolbar setAutosavesConfiguration: YES];
	[toolbar setDisplayMode: NSToolbarDisplayModeDefault];
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
					@"svnCopy",
					@"svnMove",
					@"svnMkdir",
					@"svnDelete",
					NSToolbarSeparatorItemIdentifier,
					@"svnOpen",
					@"svnFileMerge",
					@"svnBlame",
					@"svnReport",
					NSToolbarFlexibleSpaceItemIdentifier,
					@"svnCheckout",
					@"svnExport",
					@"svnImport",
					NSToolbarSeparatorItemIdentifier,
					@"toggleSidebar",
					nil];
}


//----------------------------------------------------------------------------------------

- (NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar*) toolbar
{
	#pragma unused(toolbar)
	return [NSArray arrayWithObjects:
					NSToolbarSeparatorItemIdentifier,
					NSToolbarSpaceItemIdentifier,
					NSToolbarFlexibleSpaceItemIdentifier,
					@"svnCopy",
					@"svnMove",
					@"svnMkdir",
					@"svnDelete",
					@"svnOpen",
					@"svnFileMerge",
					@"svnBlame",
					@"svnReport",
					@"svnCheckout",
					@"svnExport",
					@"svnImport",
					@"toggleSidebar",
					nil];
}


//----------------------------------------------------------------------------------------

@end

