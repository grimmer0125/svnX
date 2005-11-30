#import "SingleFileInspector.h"

// This class subclasses NSDocument. See Scripting.m. This is the document that is created when
// FileMerge via svnX is invoked from AppleScript.

@implementation SingleFileInspector

- init
{
    if (self = [super init])
	{
		[self addObserver:self forKeyPath:@"path" options:NSKeyValueChangeSetting context:nil];	
   }
	
    return self;
}

//  - dealloc:
- (void) dealloc {
    [self setPath: nil];

    [super dealloc];
}

- (NSString *)windowNibName
{
    return @"SingleFileInspector";
}


- (void)windowWillClose:(NSNotification *)notification
{
	[fileMergeController unload];
	[self removeObserver:self forKeyPath:@"path"];
}

- (void)awakeFromNib
{
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController
{
    [super windowControllerDidLoadNib:windowController];

	if ( [NSBundle loadNibNamed:@"svnFileMerge" owner:fileMergeController] )
	{
		[fileMergeView addSubview:[[fileMergeController window] contentView]];
		[[[fileMergeView subviews] objectAtIndex:0] setAutoresizingMask:[fileMergeView autoresizingMask]];
		[[[fileMergeView subviews] objectAtIndex:0] setFrameSize:[fileMergeView frame].size];
	}
	
	[[self windowForSheet] orderFrontRegardless];
	[[self windowForSheet] setLevel:NSFloatingWindowLevel];
//	[[self windowForSheet] setLevel:NSNormalWindowLevel];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ( [keyPath isEqualToString:@"path"] )
	{
		[self svnFileMerge:self];
	}
}

- (void)svnFileMerge:(id)sender
{
	id item = [NSDictionary dictionaryWithObjectsAndKeys:path, @"fullPath", self, @"callback", nil]; // callback will be called on close button pressed

	[fileMergeController setPath:[item objectForKey:@"fullPath"]];
	[fileMergeController setSourceItem:item];
	[fileMergeController setup]; 
}

- (void)closeCallback
{
	[[self windowForSheet] performClose:self];
}


#pragma mark -
#pragma mark Accessors


- (NSString *) windowTitle {
    return @"AppleScript"; 
}
// - path:
- (NSString *) path {
    return path; 
}

// - setPath:
- (void) setPath: (NSString *) aPath {
    id old = [self path];
    path = [aPath retain];
    [old release];
}

@end
