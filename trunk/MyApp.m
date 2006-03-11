#import "MyApp.h"

@implementation MyApp

@class SvnFileStatusToColourTransformer, SvnDateTransformer, ArrayCountTransformer, SvnFilePathTransformer, FilePathCleanUpTransformer, TrimNewLinesTransformer, TaskStatusToColorTransformer;

+ (MyApp *)myApp
{
    static id controller = nil;
    
    if (!controller) {
        controller = [NSApp delegate];
    }

    return controller;
}
+ (void)initialize
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	NSData *svnFileStatusModifiedColor = [NSArchiver archivedDataWithRootObject:[NSColor blackColor]];
	NSData *svnFileStatusNewColor = [NSArchiver archivedDataWithRootObject:[NSColor blueColor]];
	NSData *svnFileStatusMissingColor = [NSArchiver archivedDataWithRootObject:[NSColor redColor]];

	[dictionary setObject:svnFileStatusModifiedColor forKey:@"svnFileStatusModifiedColor"];
	[dictionary setObject:svnFileStatusNewColor forKey:@"svnFileStatusNewColor"];
	[dictionary setObject:svnFileStatusMissingColor forKey:@"svnFileStatusMissingColor"];
	
	[dictionary setObject:@"/usr/local/bin" forKey:@"svnBinariesFolder"];
	[dictionary setObject:[NSNumber numberWithBool:YES] forKey:@"cacheSvnQueries"];
	[dictionary setObject:[NSNumber numberWithInt:0] forKey:@"defaultDiffApplication"];

	[dictionary setObject:[NSNumber numberWithBool:YES] forKey:@"addWorkingCopyOnCheckout"];
	
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:dictionary];

	// Transformers

	[NSValueTransformer setValueTransformer:[[[SvnFileStatusToColourTransformer alloc] init] autorelease] forName:@"SvnFileStatusToColourTransformer"]; // used by MyWorkingCopy
	[NSValueTransformer setValueTransformer:[[[SvnDateTransformer alloc] init] autorelease] forName:@"SvnDateTransformer"];		// used by MySvnLogView
	[NSValueTransformer setValueTransformer:[[[ArrayCountTransformer alloc] init] autorelease] forName:@"ArrayCountTransformer"]; // used by MySvnLogView
	[NSValueTransformer setValueTransformer:[[[FilePathCleanUpTransformer alloc] init] autorelease] forName:@"FilePathCleanUpTransformer"]; // used by FavoriteWorkingCopies
	[NSValueTransformer setValueTransformer:[[[SvnFilePathTransformer alloc] init] autorelease] forName:@"lastPathComponent"]; // used by SingleFileInspector
	[NSValueTransformer setValueTransformer:[[[TrimNewLinesTransformer alloc] init] autorelease] forName:@"TrimNewLines"]; // used by MySvnLogView and MySvnLogView2 (to filter author name)
	[NSValueTransformer setValueTransformer:[[[TaskStatusToColorTransformer alloc] init] autorelease] forName:@"TaskStatusToColor"]; // used by Activity Window in svnX.nib
}


- (void)awakeFromNib
{
	[favoriteWorkingCopiesWindow makeKeyAndOrderFront:self];

}

- (IBAction)openFavorite:(id)sender
{
	[favoriteWorkingCopiesWindow makeKeyAndOrderFront:self];
}

- (IBAction)test:(id)sender
{
//	[self openSingleFile:@"/Users/dom/Sites/alahup/flash/_classes/com/lachoseinteractive/SmartEdit/Inspector_text.as"];
	NSMutableDictionary *obj = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"tadaa", @"name", nil];

}

- (void)openSingleFile:(NSString *)path  // Compare a single file in a svnX window. Invoked from Applescript.
{
	SingleFileInspector *newDoc = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"singleFile" display:YES];	
//	SingleFileInspector *newDoc = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"singleFile"];

	[newDoc setPath:path];
//	[newDoc makeWindowControllers];
//	[[NSDocumentController sharedDocumentController ] addDocument:newDoc];
//	[newDoc showWindows];
}


- (IBAction)openPreferences:(id)sender
{
	[preferencesWindow makeKeyAndOrderFront:self];
}

- (IBAction)closePreferences:(id)sender
{
    [preferencesWindow close];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender 
{
	return NO;
}

- (void)openRepository:(NSURL *)url user:(NSString *)user pass:(NSString *)pass
{
	[repositoriesController openRepositoryBrowser:[url absoluteString] title:[url absoluteString] user:user pass:pass];
}


#pragma mark -
#pragma mark Tasks management

-(void)newTaskWithDictionary:(NSMutableDictionary *)taskObj
// called from MySvn class
{
	[tasksManager newTaskWithDictionary:taskObj];
}


@end
