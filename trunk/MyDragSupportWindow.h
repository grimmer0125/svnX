/* MyDragSupportWindow */

#import <Cocoa/Cocoa.h>

@class RepoItem;

@interface MyDragSupportWindow : NSWindow @end


//----------------------------------------------------------------------------------------
// Class RepoItemView: Displays repos item URLs, provides drag feedback of repo items,
// accepts drops, notifies target of drop or change.

@interface RepoItemView : NSTextField
{
@private
	RepoItem*	fRepoItem;
}

- (RepoItem*) repoItem;
- (void)      setRepoItem: (RepoItem*) repoItem;
- (void)      setRepoItem: (RepoItem*) repoItem target: (id) target;

@end

