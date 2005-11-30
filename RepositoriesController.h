/* RepositoriesController */

#import <Cocoa/Cocoa.h>

@class MyRepository;

@interface RepositoriesController : NSObject
{
	IBOutlet NSArrayController *repositoriesAC;
    IBOutlet id nameTextField;
    IBOutlet id window;
    IBOutlet NSTableView* tableView;

	NSMutableArray *repositories;
}

- (IBAction)onValidate:(id)sender;
- (IBAction)newRepositoryItem:(id)sender;

- (NSMutableArray *)repositories;
- (void)setRepositories:(NSMutableArray *)aRepositories;

@end
