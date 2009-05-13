//
// MyDragSupportWindow.m - Working Copy NSWindow subclass
//

#import "MyDragSupportWindow.h"
#import "MyWorkingCopy.h"
#import "MyWorkingCopyController.h"
#import "NSString+MyAdditions.h"
#import "RepoItem.h"


NSString* const kTypeRepositoryPathAndRevision = @"REPOSITORY_PATH_AND_REVISION_TYPE";
static bool gIsFile;


//----------------------------------------------------------------------------------------
// Retrieve RepoItem pointer from pasteboard.

static RepoItem*
repoItemFromPasteboard (NSPasteboard* pboard)
{
	Assert([[pboard dataForType: kTypeRepositoryPathAndRevision] length] == sizeof(RepoItem*));
	return *(RepoItem* const*) [[pboard dataForType: kTypeRepositoryPathAndRevision] bytes];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation MyDragSupportWindow

//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
	[self registerForDraggedTypes: [NSArray arrayWithObject: kTypeRepositoryPathAndRevision]];
}


//----------------------------------------------------------------------------------------

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>) sender
{
	gIsFile = ![repoItemFromPasteboard([sender draggingPasteboard]) isDir];
	return NSDragOperationCopy;
}


//----------------------------------------------------------------------------------------

- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>) sender
{
	if ([self attachedSheet])
		return NSDragOperationNone;
	NSDragOperation op = [sender draggingSourceOperationMask];
	return (gIsFile || op != NSDragOperationNone) ? NSDragOperationCopy : NSDragOperationLink;
}


//----------------------------------------------------------------------------------------

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>) sender
{
	#pragma unused(sender)
	return ([self attachedSheet] == nil);
}


//----------------------------------------------------------------------------------------

- (BOOL) performDragOperation: (id<NSDraggingInfo>) sender
{
	NSPasteboard* pboard = [sender draggingPasteboard];
	RepoItem* repoItem = repoItemFromPasteboard(pboard);
	NSDragOperation op = [sender draggingSourceOperationMask];

	// op: No keys => NSDragOperationPrivate | NSDragOperationCopy => Merge
	//	   Command or Control keys => NSDragOperationNone => Switch
	MyWorkingCopyController* controller = [[[self windowController] document] controller];
	if (gIsFile || op != NSDragOperationNone)
		[controller requestMergeFrom: repoItem];
	else
		[controller requestSwitchToRepositoryPath: repoItem];

	return YES;
}

@end	// MyDragSupportWindow


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation RepoItemView

//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[fRepoItem release];
	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (void) awakeFromNib
{
//	fRepoItem = nil;
	[self sendActionOn: 0];
	if ([NSTextField instancesRespondToSelector: @selector(awakeFromNib)])
		[super awakeFromNib];
	[self registerForDraggedTypes: [NSArray arrayWithObject: kTypeRepositoryPathAndRevision]];
}


//----------------------------------------------------------------------------------------

- (RepoItem*) repoItem
{
	return fRepoItem;
}


//----------------------------------------------------------------------------------------

- (void) setRepoItem: (RepoItem*) repoItem
{
	[repoItem retain];
	[fRepoItem release];
	fRepoItem = repoItem;
	[self setStringValue: repoItem ? [repoItem pathWithRevision] : @""];
	if (repoItem)
		[self sendAction: [self action] to: [self target]];
}


//----------------------------------------------------------------------------------------

- (void) setRepoItem: (RepoItem*) repoItem target: (id) target
{
	[self setTarget: target];
	[self setRepoItem: repoItem];
}


//----------------------------------------------------------------------------------------

- (void) drawRect: (NSRect) aRect
{
	[super drawRect: aRect];
	if ([self focusRingType] == NSFocusRingTypeExterior)
	{
		NSSetFocusRingStyle(NSFocusRingOnly);
		NSRectFill(aRect);
	}
}


//----------------------------------------------------------------------------------------

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>) sender
{
	#pragma unused(sender)
	if (![self isEnabled])
		return NSDragOperationNone;
	[self setFocusRingType: NSFocusRingTypeExterior];
	[self setKeyboardFocusRingNeedsDisplayInRect: [self bounds]];
	return NSDragOperationCopy;
}


//----------------------------------------------------------------------------------------

- (void) draggingExited: (id<NSDraggingInfo>) sender
{
	#pragma unused(sender)
	[self setKeyboardFocusRingNeedsDisplayInRect: [self bounds]];
	[self setFocusRingType: NSFocusRingTypeNone];
}


//----------------------------------------------------------------------------------------

- (BOOL) performDragOperation: (id<NSDraggingInfo>) sender
{
	if (![self isEnabled])
		return NO;
	[self draggingExited: sender];
	NSPasteboard* pboard = [sender draggingPasteboard];
	RepoItem* repoItem = repoItemFromPasteboard(pboard);

	[self setRepoItem: repoItem];

	return YES;
}

@end	// RepoItemView


//----------------------------------------------------------------------------------------
// End of MyDragSupportWindow.m
