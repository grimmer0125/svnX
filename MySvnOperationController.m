#import "MySvnOperationController.h"


@implementation MySvnOperationController

//  - dealloc:
//- (void) dealloc {
//NSLog(@"MySvnOperationController dealloc called");
//
//    [super dealloc];
//}

- (void)unload
{
	[targetBrowser unload]; // targetBrowser was loaded from a nib (see "unload" comments).
		
	// the owner has to release its top level nib objects 
	[svnSheet release];
	[objectController release];
}

- (void)deactivate
{
	[targetBrowser setRevision:nil];
	[targetBrowser reset];
}

-(void)setSourceItem:(NSDictionary *)item
{
	[objectController setValue:item forKeyPath:@"content.sourceItem"];
	[targetName setStringValue:[[item objectForKey:@"path"] lastPathComponent]];
}

- (NSString *)getTargetPath
{
	return [[[[targetBrowser selectedItems] objectAtIndex:0] objectForKey:@"path"] stringByAppendingPathComponent:[targetName stringValue]];
}

- (NSURL *)getTargetUrl
{
	NSURL *url = [[[targetBrowser selectedItems] objectAtIndex:0] objectForKey:@"url"];
	NSURL *url2  = [NSURL URLWithString:[NSString stringByAddingPercentEscape:[targetName stringValue]] relativeToURL:url];

	return url2;
}

- (NSString *)getCommitMessage
{
	return [commitMessage string];
}

- (NSArray *)getTargets
{
	return [arrayController arrangedObjects];
}

-(void)setUrl:(NSURL *)url
{
//	[svnLogView setUrl:url];
	[targetBrowser setUrl:url];
	[objectController setValue:url forKeyPath:@"content.itemUrl"];
}

-(void)setPath:(NSString *)path
{
//	[svnLogView setPath:path];
	[objectController setValue:path forKeyPath:@"content.itemPath"];
}


- (void)setup:(NSString *)operation
{	
	
	if ( [operation isEqualToString:@"svnDelete"] )
	{
		[targetBrowser setRevision:@"HEAD"];
		[targetBrowser setAllowsEmptySelection:NO];
		[targetBrowser setShowRoot:NO];
		[targetBrowser setDisallowLeaves:NO];
		[targetBrowser setAllowsMultipleSelection:YES];

		[targetBrowser fetchSvn];
		
	} else
	{
		[targetBrowser setRevision:@"HEAD"];
		[targetBrowser setAllowsEmptySelection:NO];
		[targetBrowser setShowRoot:YES];
		[targetBrowser setDisallowLeaves:YES];
		[targetBrowser setAllowsMultipleSelection:NO];

		if ( [operation isEqualToString:@"svnMove"] )
		{
			[objectController setValue:@"HEAD" forKeyPath:@"content.sourceItem.revision"];
		}
		
		[targetBrowser fetchSvn];
	}
	
}


- (IBAction)addDirectory:(id)sender
{
	if ( [[targetName stringValue] isEqualToString:@""] )
	{
		[svnSheet makeFirstResponder:targetName];
		NSBeep();
	}
	else
	[arrayController addObject:[NSDictionary dictionaryWithObjectsAndKeys:[self getTargetPath], @"path", [self getTargetUrl], @"url", nil]];
}

- (IBAction)addItems:(id)sender
{
	[arrayController addObjects:[targetBrowser selectedItems]];
}

- (IBAction)validate:(id)sender
{
	if ( [[commitMessage string] isEqualToString:@""] && [sender tag] != 0 )
	{
		[svnSheet makeFirstResponder:commitMessage];
		NSBeep();

	} else
	{		
		[NSApp endSheet:svnSheet returnCode:[sender tag]];
	}
}


#pragma mark -
#pragma mark Error sheet

- (void)svnError:(NSString*)errorString
{
	NSAlert *alert = [NSAlert alertWithMessageText:@"Error"
									 defaultButton:@"OK"
								   alternateButton:nil
									   otherButton:nil
						 informativeTextWithFormat:errorString];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
}




#pragma mark -
#pragma mark Accessors

- (NSWindow *)window
{
	return svnSheet;
}


- (NSInvocation *) svnOptionsInvocation { return svnOptionsInvocation; }
- (void) setSvnOptionsInvocation: (NSInvocation *) aSvnOptionsInvocation {
    id old = [self svnOptionsInvocation];
    svnOptionsInvocation = [aSvnOptionsInvocation retain];
    [old release];

	if ( [targetBrowser respondsToSelector:@selector(setSvnOptionsInvocation:)] ) // FileMerge
		[targetBrowser setSvnOptionsInvocation:aSvnOptionsInvocation];
	
}

@end
