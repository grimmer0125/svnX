#import "MyRepository.h"
#include "MySvn.h";
#include "Tasks.h";

#define SVNXCallbackExtractedToFileSystem 1
#define SVNXCallbackCopy 2
#define SVNXCallbackMove 3
#define SVNXCallbackMkdir 4
#define SVNXCallbackDelete 5
#define SVNXCallbackImport 6

@implementation MyRepository

- init
{
    if (self = [super init])
	{
		[self setRevision:nil];
		
		if ( [[[NSUserDefaults standardUserDefaults] valueForKey:@"defaultLogViewKindIsAdvanced"] boolValue] )
		{
			[self setLogViewKind:@"advanced"];
		} else
		{
			[self setLogViewKind:@"simple"];		
		}
   }
	
    return self;
}


- (void)dealloc
{
	[svnLogView1 unload];
	[svnLogView2 unload];
	[svnBrowserView unload];
	

    [self setUrl: nil];
    [self setUser: nil];
    [self setPass: nil];
    [self setRevision: nil];
    [self setWindowTitle: nil];

    [self setLogViewKind: nil];
    [self setDisplayedTaskObj: nil];

//	NSLog(@"Repository dealloc'ed");
//	
    [super dealloc];
}

- (void)close
{
	[svnLogView1 removeObserver:self forKeyPath:@"currentRevision"];
	[svnLogView2 removeObserver:self forKeyPath:@"currentRevision"];
	
	[drawerLogView unload];
	
	[super close];	
}

- (NSString *)windowNibName
{
    return @"MyRepository";
}

- (void)awakeFromNib
{
	[svnLogView1 addObserver:self forKeyPath:@"currentRevision" options:NSKeyValueChangeSetting context:nil];
	[svnLogView2 addObserver:self forKeyPath:@"currentRevision" options:NSKeyValueChangeSetting context:nil];

	[svnBrowserView setSvnOptionsInvocation:[self makeSvnOptionInvocation]];
	[svnBrowserView setUrl:[self url]];
	[svnBrowserView setShowRoot:YES];

	
	// if log view is in simple mode, we need to force fetchSvnLog,
	// if log view is in advanced mode (see -init), we don't want to do that because bindings will trigger the selection
	// of the "advanced" tab, and the delegate method of the tab view will be called, thus calling fetchSvnLog (see -tabView:willSelectTabViewItem:) 
	if ( [[self logViewKind] isEqualToString:@"simple"] )
	{
		svnLogView = svnLogView1;

		[svnLogView setSvnOptionsInvocation:[self makeSvnOptionInvocation]];
		[svnLogView setUrl:[self url]];
		[svnLogView fetchSvnLog];
	}
	
	[drawerLogView setDocument:self];
	[drawerLogView setUp];
	
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ( [keyPath isEqualToString:@"currentRevision"] )		// A new current revision was selected in the svnLogView
	{		
		//NSLog(@"%@", [change objectForKey:NSKeyValueChangeNewKey]);
		[self setRevision:[change objectForKey:NSKeyValueChangeNewKey]];
		[svnBrowserView setRevision:[change objectForKey:NSKeyValueChangeNewKey]];
		[svnBrowserView fetchSvn];
	}
}

- (IBAction)toggleSidebar:(id)sender
{
	[sidebar toggle:sender];
}

#pragma mark -
#pragma mark svn operations

- (IBAction) svnCopy:(id)sender
{
	if ( [[svnBrowserView selectedItems] count ] != 1 )
	{
		[self svnError:@"Please select exactly one item to copy."];

	} else if ( [[[[svnBrowserView selectedItems] objectAtIndex:0] valueForKey:@"isRoot"] boolValue] == YES )
	{
		[self svnError:@"Can't copy root folder."];
	}
	else
	{
		if ( [NSBundle loadNibNamed:@"svnCopy" owner:svnCopyController] )
		{		
			[svnCopyController setSourceItem:[[svnBrowserView selectedItems] objectAtIndex:0]];
			[svnCopyController setSvnOptionsInvocation:[self svnOptionsInvocation]];
			[svnCopyController setUrl:[self url]];
			[svnCopyController setup:@"svnCopy"];

			[NSApp beginSheet:[svnCopyController window]
				modalForWindow:[self windowForSheet]
				modalDelegate:self
				didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
				contextInfo:@"svnCopy"];
		}
	}
}

- (IBAction) svnMove:(id)sender
{
	if ( [[svnBrowserView selectedItems] count ] != 1 )
	{
		[self svnError:@"Please select exactly one item to move."];

	} else if ( [[[[svnBrowserView selectedItems] objectAtIndex:0] valueForKey:@"isRoot"] boolValue] == YES )
	{
		[self svnError:@"Can't copy root folder."];
	}
	else
	{
		if ( [NSBundle loadNibNamed:@"svnCopy" owner:svnMoveController] )
		{
			[svnMoveController setSourceItem:[[svnBrowserView selectedItems] objectAtIndex:0]];
			[svnMoveController setSvnOptionsInvocation:[self svnOptionsInvocation]];
			[svnMoveController setUrl:[self url]];
			[svnMoveController setup:@"svnMove"];

			[NSApp beginSheet:[svnMoveController window]
				modalForWindow:[self windowForSheet]
				modalDelegate:self
				didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
				contextInfo:@"svnMove"];

		}
	}
}

- (IBAction) svnMkdir:(id)sender
{
	if ( [NSBundle loadNibNamed:@"svnMkdir" owner:svnMkdirController] )
	{
		[svnMkdirController setSvnOptionsInvocation:[self svnOptionsInvocation]];
		[svnMkdirController setUrl:[self url]];
		[svnMkdirController setup:@"svnMkdir"];
		
		[NSApp beginSheet:[svnMkdirController window]
			modalForWindow:[self windowForSheet]
			modalDelegate:self
			didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			contextInfo:@"svnMkdir"];
	}
}

- (IBAction) svnDelete:(id)sender
{
	if ( [NSBundle loadNibNamed:@"svnDelete" owner:svnDeleteController] )
	{
		[svnDeleteController setSvnOptionsInvocation:[self svnOptionsInvocation]];
		[svnDeleteController setUrl:[self url]];
		[svnDeleteController setup:@"svnDelete"]; 

		[NSApp beginSheet:[svnDeleteController window]
			modalForWindow:[self windowForSheet]
			modalDelegate:self
			didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			contextInfo:@"svnDelete"];
	}
}


- (void)svnFileMerge:(id)sender
{
	if ( [[svnBrowserView selectedItems] count ] != 1 )
	{
		[self svnError:@"Please select exactly one item."];
		return;	
	} 

	id item = [[svnBrowserView selectedItems] objectAtIndex:0];

	if ( [NSBundle loadNibNamed:@"svnFileMergeFromRepository" owner:fileMergeController] )
	{
		[fileMergeController setSvnOptionsInvocation:[self svnOptionsInvocation]];
		[fileMergeController setUrl:[item objectForKey:@"url"]]; 
		[fileMergeController setSourceItem:item];
		[fileMergeController setup]; 

		[NSApp beginSheet:[fileMergeController window]
			modalForWindow:[self windowForSheet]
			modalDelegate:self
			didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
			contextInfo:@"svnFileMerge"];
	}	

}

- (IBAction)svnExport:(id)sender
{
	NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	NSString *selectionPath = NSHomeDirectory();
	
	[oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories:YES];
	[oPanel setCanChooseFiles:NO];
	[oPanel _setIncludeNewFolderButton:YES];
	
	[oPanel beginSheetForDirectory:selectionPath file:nil types:nil modalForWindow:[self windowForSheet]
							  modalDelegate: self
							 didEndSelector:@selector(exportPanelDidEnd:returnCode:contextInfo:)
								contextInfo:nil
		];
}

- (IBAction) svnCheckout:(id)sender
{
	if ( [[svnBrowserView selectedItems] count ] != 1 || [[[[svnBrowserView selectedItems] objectAtIndex:0] valueForKey:@"isDir"] boolValue] == FALSE )
	{
		[self svnError:@"Please select exactly one folder to checkout."];
	}
	else
	{
		NSOpenPanel *oPanel = [NSOpenPanel openPanel];
		NSString *selectionPath = NSHomeDirectory();
		
		[oPanel setAllowsMultipleSelection:NO];
		[oPanel setCanChooseDirectories:YES];
		[oPanel setCanChooseFiles:NO];
		[oPanel setCanCreateDirectories:YES];
		
		[oPanel beginSheetForDirectory:selectionPath file:nil types:nil modalForWindow:[self windowForSheet]
								  modalDelegate: self
								 didEndSelector:@selector(checkoutPanelDidEnd:returnCode:contextInfo:)
									contextInfo:nil
			];
	}
}

- (void)checkoutPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSString *destinationPath = nil;
	
    if (returnCode == NSOKButton)
	{
        destinationPath = [[sheet filenames] objectAtIndex:0];

		[self setDisplayedTaskObj:
				[MySvn        checkout: [[[[[svnBrowserView selectedItems] objectAtIndex:0] objectForKey:@"url"] absoluteString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]]
				   destination: destinationPath
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects:[NSString stringWithFormat:@"-r%@", [self revision]],  nil]
					  callback: [self makeCallbackInvocationOfKind:SVNXCallbackExtractedToFileSystem]
				  callbackInfo: destinationPath
					  taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self windowTitle], @"documentName", nil]]];
    }
}

- (void)exportPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if ( returnCode == NSOKButton )
	{
		NSURL *destinationURL = [NSURL fileURLWithPath:[[sheet filenames] objectAtIndex:0]];
		NSArray *validatedFiles = [self userValidatedFiles:[svnBrowserView selectedItems] forDestination:destinationURL];

		[self exportFiles:[NSDictionary dictionaryWithObjectsAndKeys:validatedFiles, @"validatedFiles", 
									destinationURL, @"destinationURL", nil]];
	}
}

-(void)exportFiles:(NSDictionary *)args
{
	NSURL *destinationURL = [args objectForKey:@"destinationURL"];
	NSArray *validatedFiles = [args objectForKey:@"validatedFiles"];

	
	NSEnumerator *e = [validatedFiles objectEnumerator];
	NSDictionary *item;
	
	NSMutableArray *shellScriptArguments = [NSMutableArray array];
	
	// folders -> svn export
	// files -> svn cat
	// we want to let a single shell script do that because we want to handle it has a single task (that will be namely easier to terminate)
	//
	
	while ( item = [e nextObject] )
	{
		NSString *destinationPath = [[destinationURL path] stringByAppendingPathComponent:[item valueForKey:@"name"]];
		NSString *sourcePath = [[[item valueForKey:@"url"] absoluteString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
		
		if ( [[item valueForKey:@"isDir"] boolValue] )
		{														   
			[shellScriptArguments addObjectsFromArray:[NSArray arrayWithObjects: 
															@"e", // == export (see svnextract.sh)
															sourcePath,
															destinationPath, nil]];
		} else
		{
			[shellScriptArguments addObjectsFromArray:[NSArray arrayWithObjects: 
															@"c", // == cat (see svnextract.sh)
															sourcePath, 
															destinationPath, nil]];
	
		}

	}

	[self setDisplayedTaskObj:
	[MySvn		extractItems: shellScriptArguments
			  generalOptions: [self svnOptionsInvocation]
					 options: [NSArray arrayWithObjects:[NSString stringWithFormat:@"-r%@", [self revision]],  nil]
					callback: [self makeCallbackInvocationOfKind:SVNXCallbackExtractedToFileSystem]
				callbackInfo: [destinationURL path]
					taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self windowTitle], @"documentName", nil]
			    ]];
}

-(void)extractedItemsCallback:(NSDictionary *)taskObj
{
	NSString *extractDestinationPath = [taskObj valueForKey:@"callbackInfo"];
	
	// let the Finder know about the operation (required for Panther)
	[[NSWorkspace sharedWorkspace] noteFileSystemChanged:extractDestinationPath];
	
	if ( [[taskObj valueForKey:@"stderr"] length] > 0 ) [self svnError:[taskObj valueForKey:@"stderr"]];
}

-(void)dragOutFilesFromRepository:(NSArray *)filesDicts toURL:(NSURL *)destinationURL
{
	NSArray *validatedFiles = [self userValidatedFiles:filesDicts
									forDestination:destinationURL];
	BOOL checkoutOrExport = FALSE; // -> export by default
							
	if ( [validatedFiles count] == 1 )
	{
		if ( [[[validatedFiles objectAtIndex:0] valueForKey:@"isDir"] boolValue] )
		{
			NSAlert *alert = [[NSAlert alloc] init];
			int alertResult;
			
			[alert addButtonWithTitle:@"Export"];
			[alert addButtonWithTitle:@"Checkout"];
			
			[alert setMessageText:@"Do you want to extract the folder versioned (checkout) or unversioned (export) ?"];
//			[alert setInformativeText:@"Hum ?"];
			[alert setAlertStyle:NSWarningAlertStyle];


			alertResult = [alert runModal];
			
			if ( alertResult == NSAlertFirstButtonReturn) // Unversioned -> export
			{
				checkoutOrExport = FALSE;
			} 
			else
			if ( alertResult == NSAlertSecondButtonReturn) // Versioned -> checkout
			{
				checkoutOrExport = TRUE;
			} 
			
			[alert release];
		
		}

	}
	
	[self extractFiles:validatedFiles toDestinationURL:destinationURL checkout:checkoutOrExport];

}

-(void)dragExternalFiles:(NSArray *)files ToRepositoryAt:(NSDictionary *)representedObject
{	
	NSString *filePath = [files objectAtIndex:0];

	[importCommitPanel setTitle:@"Import"];
	[fileNameTextField setStringValue:[filePath lastPathComponent]];

	[NSApp	beginSheet:importCommitPanel
			modalForWindow:[self windowForSheet] 
			modalDelegate:self 
			didEndSelector:@selector(importCommitPanelDidEnd:returnCode:contextInfo:) 
			contextInfo:[[NSDictionary dictionaryWithObjectsAndKeys:
										[[[representedObject valueForKey:@"url"] absoluteString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]], @"destination",
										filePath, @"filePath", nil] retain] ];


}

- (void)importCommitPanelDidEnd:(NSPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:nil];
	
	NSDictionary *dict = contextInfo;
	
	if ( returnCode == 1 )
	{
		[self setDisplayedTaskObj:
			[MySvn		import: [dict objectForKey:@"filePath"]
				   destination: [NSString stringWithFormat:@"%@/%@", [dict objectForKey:@"destination"], [fileNameTextField stringValue]] // stringByAppendingPathComponent would eat svn:// into svn:/ !
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObject:[NSString stringWithFormat:@"-m%@", [commitTextView string]]]
					  callback: [self makeCallbackInvocationOfKind:SVNXCallbackImport]
				  callbackInfo: nil
					  taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self windowTitle], @"documentName", nil]]
			];


	}
	
	[contextInfo release];																					
}

- (IBAction)importCommitPanelValidate:(id)sender;
{
	[NSApp endSheet:importCommitPanel returnCode:[sender tag]];
}




-(void)extractFiles:(NSArray *)validatedFiles toDestinationURL:(NSURL *)destinationURL checkout:(BOOL)checkoutOrExport
{
	if ( checkoutOrExport == TRUE ) // => checkout
	{				
		id item = [validatedFiles objectAtIndex:0]; // one checks out no more than one directory
		NSString *destinationPath = [[destinationURL path] stringByAppendingPathComponent:[item valueForKey:@"name"]];
		
		[self setDisplayedTaskObj:
		[MySvn		  checkout: [[[item valueForKey:@"url"] absoluteString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]]
				   destination: destinationPath
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects:[NSString stringWithFormat:@"-r%@", [self revision]],  nil]
					  callback: [self makeCallbackInvocationOfKind:SVNXCallbackExtractedToFileSystem]
				  callbackInfo: destinationPath
					  taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self windowTitle], @"documentName", nil]
					  				  ]];

	
	} else // => export
	{
		[self exportFiles:[NSDictionary dictionaryWithObjectsAndKeys:validatedFiles, @"validatedFiles", 
									destinationURL, @"destinationURL", nil]];
	}
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	[sheet orderOut:nil];

	if ( returnCode == 1 )
	{
		if ( [contextInfo isEqualToString:@"svnCopy"] )
		{
			NSString *sourceUrl = [[[[svnBrowserView selectedItems] objectAtIndex:0] objectForKey:@"url"] absoluteString];
			NSString *targetUrl = [[svnCopyController getTargetUrl] absoluteString];

			[MySvn		  copy: sourceUrl
				   destination: targetUrl
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects:	[NSString stringWithFormat:@"-r%@", [self revision]],
															[NSString stringWithFormat:@"-m%@", [svnCopyController getCommitMessage]],
												nil]
					  callback: [self makeCallbackInvocationOfKind:SVNXCallbackCopy]
				  callbackInfo: nil
					  taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self windowTitle], @"documentName", nil]];

			[svnCopyController deactivate];
			[svnCopyController unload];
									  
		}
		else
		if ( [contextInfo isEqualToString:@"svnMove"] )
		{
			NSString *sourceUrl = [[[[svnBrowserView selectedItems] objectAtIndex:0] objectForKey:@"url"] absoluteString];
			NSString *targetUrl = [[svnMoveController getTargetUrl] absoluteString];

			[MySvn		  move: sourceUrl
				   destination: targetUrl
				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObject:[NSString stringWithFormat:@"-m%@", [svnMoveController getCommitMessage]]]
												
					  callback: [self makeCallbackInvocationOfKind:SVNXCallbackMove]
				  callbackInfo: nil
					  taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self windowTitle], @"documentName", nil]];

			[svnMoveController deactivate];
			[svnMoveController unload];
		}
		else
		if ( [contextInfo isEqualToString:@"svnMkdir"] )
		{
			[MySvn		 mkdir: [[svnMkdirController getTargets] mutableArrayValueForKeyPath:@"url.absoluteString"]  // Some Key-Value coding magic !! (multiple directories)

				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects:[NSString stringWithFormat:@"-m%@", [svnMkdirController getCommitMessage]],
																		nil]
					  callback: [self makeCallbackInvocationOfKind:SVNXCallbackMkdir]
				  callbackInfo: nil
					  taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self windowTitle], @"documentName", nil]];

			[svnMkdirController deactivate];
			[svnMkdirController unload];
								
		}
		else
		if ( [contextInfo isEqualToString:@"svnDelete"] )
		{
			[MySvn		delete: [[svnDeleteController getTargets] mutableArrayValueForKeyPath:@"url.absoluteString"]  // Some Key-Value coding magic !! (multiple directories)

				generalOptions: [self svnOptionsInvocation]
					   options: [NSArray arrayWithObjects:[NSString stringWithFormat:@"-m%@", [svnDeleteController getCommitMessage]],
																		nil]
					  callback: [self makeCallbackInvocationOfKind:SVNXCallbackDelete]
				  callbackInfo: nil
					  taskInfo: [NSDictionary dictionaryWithObjectsAndKeys:[self windowTitle], @"documentName", nil]];

			[svnDeleteController deactivate];
			[svnDeleteController unload];
		}
	}
	
//	[contextInfo release];
}


- (void)svnCommandComplete:(id)taskObj
{
	if ( [[taskObj valueForKey:@"status"] isEqualToString:@"completed"] )
	{
		[svnLogView fetchSvnLog];
	} 
	
	if ( [[taskObj valueForKey:@"stderr"] length] > 0 ) [self svnError:[taskObj valueForKey:@"stderr"]];
}

- (void)svnError:(NSString*)errorString
{
	NSAlert *alert = [NSAlert alertWithMessageText:@"svn Error"
			defaultButton:@"OK"
			alternateButton:nil
			otherButton:nil
			informativeTextWithFormat:errorString];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
		
	if ( [[self windowForSheet] attachedSheet] != nil ) [NSApp endSheet:[[self windowForSheet] attachedSheet]];

	[alert
			beginSheetModalForWindow:[self windowForSheet]
						modalDelegate:self
						didEndSelector:nil
						contextInfo:nil];
}


#pragma mark -
#pragma mark Helpers


- (NSArray *)userValidatedFiles:(NSArray *)files forDestination:(NSURL *)destinationURL
{
	NSEnumerator *en = [files objectEnumerator];
	id item;
	NSMutableArray *validatedFiles = [NSMutableArray array];

	BOOL yesToAll = NO;

	while ( item = [en nextObject] )
	{
		if ( yesToAll )
		{
			[validatedFiles addObject:item];
			
			continue;
		}
		
		if ( [[NSFileManager defaultManager] fileExistsAtPath:[[destinationURL path] stringByAppendingPathComponent:[item valueForKey:@"name"]]] )
		{
			NSAlert *alert = [[NSAlert alloc] init];
			int alertResult;
			
			[alert addButtonWithTitle:@"Yes"];
			[alert addButtonWithTitle:@"No"];
			
			if ( [files count] > 1 )
			{
				[alert addButtonWithTitle:@"Cancel all"];
				[alert addButtonWithTitle:@"Yes to all"];
			}
			
			[alert setMessageText:[NSString stringWithFormat:@"\"%@\" already exists at destination", [[item valueForKey:@"name"] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]]]];
			[alert setInformativeText:@"Do you want to replace it ?"];
			[alert setAlertStyle:NSWarningAlertStyle];

			alertResult = [alert runModal];
			
			if ( alertResult == NSAlertThirdButtonReturn ) // Cancel All
			{
				return [NSArray array];
			}
			else
			if ( alertResult == NSAlertSecondButtonReturn) // No
			{
				// don't add
			} 
			else
			if ( alertResult == NSAlertFirstButtonReturn) // Yes
			{
				[validatedFiles addObject:item];
			} 
			else
			{
				yesToAll = YES;
				[validatedFiles addObject:item];
			}


			[alert release];
		
		} else
		{
			[validatedFiles addObject:item];
		}
		
	}

	return validatedFiles;
}

- (NSMutableDictionary *)getSvnOptions
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:[self user], @"user", [self pass], @"pass", nil ];
}

- (NSInvocation *) makeSvnOptionInvocation
{
	SEL getSvnOptions = @selector(getSvnOptions);
	
	NSInvocation *svnOptionsInvocation = [NSInvocation invocationWithMethodSignature:[MyRepository instanceMethodSignatureForSelector:getSvnOptions]];
	[svnOptionsInvocation setSelector:getSvnOptions];
	[svnOptionsInvocation setTarget:self];
	
	return svnOptionsInvocation;
}

- (NSInvocation *) makeCallbackInvocationOfKind:(int)callbackKind;
{
	// only one kind of invocation for now, but more complex callbacks will be possible in the future
	
	SEL callbackSelector;
	NSInvocation *callback;

	switch ( callbackKind )
	{
		case SVNXCallbackExtractedToFileSystem:
		
			callbackSelector = @selector(extractedItemsCallback:);

		break;
		
		case SVNXCallbackCopy:
		case SVNXCallbackMove:
		case SVNXCallbackMkdir:
		case SVNXCallbackDelete:
		case SVNXCallbackImport:
		
			callbackSelector = @selector(svnCommandComplete:);

		break;
	}
	
	callback = [NSInvocation invocationWithMethodSignature:[MyRepository instanceMethodSignatureForSelector:callbackSelector]];
	[callback setSelector:callbackSelector];
	[callback setTarget:self];

	return callback;
}

#pragma mark -
#pragma mark Document delegate

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo
{
	// tell the task center to cancel pending callbacks to prevent crash
	[[Tasks sharedInstance] cancelCallbacksOnTarget:self];

	[super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
}

#pragma mark -
#pragma mark Tab View delegate

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	//[svnLogView removeObserver:self forKeyPath:@"currentRevision"];
	svnLogView = [[[tabViewItem view] subviews] objectAtIndex:0];

	[svnLogView setSvnOptionsInvocation:[self makeSvnOptionInvocation]];
	[svnLogView setUrl:[self url]];
	[svnLogView setCurrentRevision:[self revision]];

	//[svnLogView addObserver:self forKeyPath:@"currentRevision" options:NSKeyValueChangeSetting context:nil];
	[svnLogView fetchSvnLog];
	
}

#pragma mark -
#pragma mark Accessors

- (NSInvocation *)svnOptionsInvocation
{
	return [self makeSvnOptionInvocation];
}

//  displayedTaskObj 
- (NSMutableDictionary *) displayedTaskObj {
    return displayedTaskObj; 
}
- (void) setDisplayedTaskObj: (NSMutableDictionary *) aDisplayedTaskObj {
    id old = [self displayedTaskObj];
    displayedTaskObj = [aDisplayedTaskObj retain];
    [old release];
}

// - url:
- (NSURL *)url {
    return url; 
}
- (void)setUrl:(NSURL *)anUrl {
    id old = [self url];
    url = [anUrl retain];
    [old release];
}

// - revision:
- (NSString *)revision {
    return revision; 
}
- (void)setRevision:(NSString *)aRevision {
    id old = [self revision];
    revision = [aRevision retain];
    [old release];
}

// - user name:
- (NSString *) user { return user; }
- (void) setUser: (NSString *) aUser {
    id old = [self user];
    user = [aUser retain];
    [old release];
}

// - user password:
- (NSString *) pass { return pass; }
- (void) setPass: (NSString *) aPass {
    id old = [self pass];
    pass = [aPass retain];
    [old release];
}

// - windowTitle:
- (NSString *) windowTitle { return windowTitle; }
- (void) setWindowTitle: (NSString *) aWindowTitle {
    id old = [self windowTitle];
    windowTitle = [aWindowTitle retain];
    [old release];
}


// - url:
- (BOOL)operationInProgress {
    return operationInProgress; 
}

// - setUrl:
- (void)setOperationInProgress:(BOOL)aBool {
	operationInProgress = aBool;
}

// - logViewKind:
- (NSString *)logViewKind { return logViewKind; }

// - setLogViewKind:
- (void)setLogViewKind:(NSString *)aLogViewKind {
    id old = [self logViewKind];
    logViewKind = [aLogViewKind retain];
    [old release];
}

@end
