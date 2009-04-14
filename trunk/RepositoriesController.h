/* RepositoriesController */

#import <Cocoa/Cocoa.h>
#import "EditListResponder.h"

@class MyRepository, MyDragSupportArrayController;

@interface RepositoriesController : EditListResponder
{
	IBOutlet MyDragSupportArrayController *repositoriesAC;
    IBOutlet id nameTextField;

	NSMutableArray *repositories;
}

- (IBAction)onValidate:(id)sender;
- (IBAction)newRepositoryItem:(id)sender;

- (NSMutableArray *)repositories;
- (void)setRepositories:(NSMutableArray *)aRepositories;
- (void)saveRepositoriesPrefs;
- (void)openRepositoryBrowser:(NSString *)url title:(NSString *)title
		user:(NSString *)user pass:(NSString *)pass;

@end
