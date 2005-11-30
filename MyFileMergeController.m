#import "MyFileMergeController.h"
#include "MySvn.h";

#define SVNXCallbackFileMerge 4

@implementation MyFileMergeController

//- (void)dealloc {
//	NSLog(@"FileMergeController dealloc'ed");
//    [super dealloc];
//}

-(void)awakeFromNib
{
	svnLogView = svnLogView1;
}

- (void)setup
{	
	[svnLogView fetchSvnLog];
}

- (void)unload
{
	[svnLogView1 unload];
	[svnLogView2 unload];
	
	// the owner has to release its top level nib objects 
	[svnSheet release];
	[objectController release];
}

- (IBAction)validate:(id)sender
{
	if ( [objectController valueForKeyPath:@"content.sourceItem.callback"] ) // see singleFileInspector
	{
		id callback = [objectController valueForKeyPath:@"content.sourceItem.callback"];
		[callback closeCallback];
	}
	
	[NSApp endSheet:svnSheet returnCode:[sender tag]];
}

-(void)setUrl:(NSURL *)url
{
	[svnLogView setUrl:url];
//	[targetBrowser setUrl:url];
	[objectController setValue:url forKeyPath:@"content.itemUrl"];
}

-(void)setPath:(NSString *)path
{
	[svnLogView setPath:path];
	[objectController setValue:path forKeyPath:@"content.itemPath"];
}

-(void)setSourceItem:(NSDictionary *)item
{
	[objectController setValue:item forKeyPath:@"content.sourceItem"];
//	[targetName setStringValue:[[item objectForKey:@"path"] lastPathComponent]];
}

# pragma mark FileMerge

- (IBAction)compare:(id)sender
{
	if ( [sender tag ] == 0 ) // Compare working copy to selected 
	{
		[MySvn	   fileMergeItems: [NSArray arrayWithObject:[objectController valueForKeyPath:@"content.sourceItem.fullPath"]]
				   generalOptions: [self svnOptionsInvocation]
						  options: [NSArray arrayWithObject:[NSString stringWithFormat:@"-r%@", [svnLogView selectedRevision]]]
						 callback: [self makeCallbackInvocationOfKind:SVNXCallbackFileMerge]
					 callbackInfo: nil
						 taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self documentName], @"documentName", nil]];

	} else // tag == 1    Compare marked to selected
	{   
		[MySvn	   fileMergeItems: [NSArray arrayWithObject:[objectController valueForKeyPath:@"content.sourceItem.fullPath"]]
				   generalOptions: [self svnOptionsInvocation]
						  options: [NSArray arrayWithObject:[NSString stringWithFormat:@"-r%@:%@", [svnLogView selectedRevision], [svnLogView currentRevision]]]
						 callback: [self makeCallbackInvocationOfKind:SVNXCallbackFileMerge]
					 callbackInfo: nil
						 taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self documentName], @"documentName", nil]];
	}
}

- (IBAction)compareUrl:(id)sender
/* used by svnFileMergeFromRepository */
{
		[MySvn	   fileMergeItems: [NSArray arrayWithObject:[[objectController valueForKeyPath:@"content.sourceItem.url"] absoluteString]]
				   generalOptions: [self svnOptionsInvocation]
						  options: [NSArray arrayWithObject:[NSString stringWithFormat:@"-r%@:%@", [svnLogView selectedRevision], [svnLogView currentRevision]]]
						 callback: [self makeCallbackInvocationOfKind:SVNXCallbackFileMerge]
					 callbackInfo: nil
						 taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self documentName], @"documentName", nil]];
}

-(void)fileMergeCallback:(id)taskObj
{
	if ( [[taskObj valueForKey:@"status"] isEqualToString:@"completed"] )
	{
		
	} else
	if ( [[taskObj valueForKey:@"stderr"] length] > 0 ) [self svnError:[taskObj valueForKey:@"stderr"]];

}

#pragma mark -
#pragma mark Tab View delegate

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	BOOL isFileMergeFromRepository = ( [svnLogView url] != nil );

	svnLogView = [[[tabViewItem view] subviews] objectAtIndex:0];

	[svnLogView setSvnOptionsInvocation:[self svnOptionsInvocation]];

	if ( isFileMergeFromRepository )
	{
		[svnLogView setUrl:[objectController valueForKeyPath:@"content.itemUrl"]];
		
	} else // This was invoked from a working copy window
	{
		[svnLogView setPath:[objectController valueForKeyPath:@"content.itemPath"]]; // with FileMerge operation, logView doesn't need and URL and a revision... just a path	
	}
	
	[svnLogView fetchSvnLog];
	
}

#pragma mark -
#pragma mark Helpers

- (NSInvocation *)makeCallbackInvocationOfKind:(int)callbackKind;
{
	
	SEL callbackSelector;
	NSInvocation *callback;

	switch ( callbackKind )
	{		
		case SVNXCallbackFileMerge:
			
			callbackSelector = @selector(fileMergeCallback:);
		
		break;
	}
	
	callback = [NSInvocation invocationWithMethodSignature:[MyFileMergeController instanceMethodSignatureForSelector:callbackSelector]];
	[callback setSelector:callbackSelector];
	[callback setTarget:self];	

	return callback;
}

#pragma mark -
#pragma mark Accessors

- (NSWindow *)window
{
	return svnSheet;
}

- (NSString *)documentName
{
	return @"fileMerge";
}


- (NSInvocation *) svnOptionsInvocation { return svnOptionsInvocation; }
- (void) setSvnOptionsInvocation: (NSInvocation *) aSvnOptionsInvocation {
    id old = [self svnOptionsInvocation];
    svnOptionsInvocation = [aSvnOptionsInvocation retain];
    [old release];

	[svnLogView setSvnOptionsInvocation:aSvnOptionsInvocation];	
}


@end
