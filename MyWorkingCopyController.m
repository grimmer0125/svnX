#import "MyWorkingCopyController.h"

@implementation MyWorkingCopyController

- (void)dealloc
{
	[document removeObserver:self forKeyPath:@"flatMode"];
    [super dealloc];
}


- (void)awakeFromNib
{
	isDisplayingErrorSheet = NO;
	
	[document   addObserver:self forKeyPath:@"flatMode"
				options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];

	[self adjustOutlineView];
	
	[drawerLogView setDocument:document];
	[drawerLogView setUp];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ( [keyPath isEqualToString:@"flatMode"] )
	{
		[self adjustOutlineView];
	}

}

- (void)cleanup
{
	[drawerLogView unload];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)openAWorkingCopy:(id)sender;
{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setCanChooseDirectories:YES];
	[oPanel setCanChooseFiles:NO];

	[oPanel beginSheetForDirectory:NSHomeDirectory() file:nil types:nil modalForWindow:[self window]
				modalDelegate: self
				didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
				contextInfo:nil
		];
}
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSString *pathToFile = nil;

    if (returnCode == NSOKButton) {

        pathToFile = [[[sheet filenames] objectAtIndex:0] copy];

		[[self document] setWorkingCopyPath:pathToFile];
		[workingCopyPath setStringValue:[[self document] workingCopyPath]];
    }
}

- (IBAction) refresh:(id)sender;
{	
	[self fetchSvnInfo];
	[self fetchSvnStatus];
}

- (IBAction) toggleView:(id)sender;
{		
	//[[self document] setFlatMode:!([[self document] flatMode])];

//	[self adjustOutlineView];
}

- (IBAction)performAction:(id)sender;
{
	NSDictionary *command;

	switch ( [[sender selectedCell] tag] )
	{
		case 0:			// Add Selected
			
			command = [NSDictionary dictionaryWithObjectsAndKeys:@"add", @"command",  
																@"add", @"verb", nil]; 
		break;

		case 1:		// Delete Selected

			command = [NSDictionary dictionaryWithObjectsAndKeys:@"remove", @"command",
																@"remove", @"verb", nil]; 

		break;

		case 2:		// Update Selected

			command = [NSDictionary dictionaryWithObjectsAndKeys:@"update", @"command",
																@"update", @"verb", nil]; 

		break;

		case 3:		// Revert Selected

			command = [NSDictionary dictionaryWithObjectsAndKeys:@"revert", @"command",
																@"revert", @"verb", nil]; 

		break;

		case 4:		// Resolved Selected

			command = [NSDictionary dictionaryWithObjectsAndKeys:@"resolved", @"command",
																	@"resolve", @"verb", nil]; 

		break;

		case 5:		// Commit Selected

			command = [NSDictionary dictionaryWithObjectsAndKeys:@"commit", @"command",
																	@"commit", @"verb",nil]; 

		break;

		case 6:		// Lock Selected

			command = [NSDictionary dictionaryWithObjectsAndKeys:@"lock", @"command",
																	@"lock", @"verb",nil]; 

		break;

		case 7:		// Unlock Selected

			command = [NSDictionary dictionaryWithObjectsAndKeys:@"unlock", @"command",
																	@"unlock", @"verb",nil]; 

		break;
	}

	[self runAlertBeforePerformingAction:command];
}

- (void) doubleClickInTableView:(id)sender
{
	if ([[svnFilesAC selectedObjects] count] == 1 )
	{
		[[NSWorkspace sharedWorkspace] openFile:[[[svnFilesAC selectedObjects] objectAtIndex:0] objectForKey:@"fullPath"]];
	}
}

- (void) adjustOutlineView
{
	if ( [[self document] flatMode] )
	{
		[self closeOutlineView];
	
	} else
	{
		[self openOutlineView];
	}
}

- (void) openOutlineView
{
	NSView *leftView = [[splitView subviews] objectAtIndex:0];
	[leftView setFrameSize:NSMakeSize(200, [leftView frame].size.height)];
	
	[leftView setHidden:NO];

	[splitView adjustSubviews];
	[splitView display];
}

- (void) closeOutlineView
{
	NSView *leftView = [[splitView subviews] objectAtIndex:0];
	[leftView setFrameSize:NSMakeSize(0, [leftView frame].size.height)];
	[splitView adjustSubviews];
	[splitView display];
}



- (void)fetchSvnStatus
{
	[self startProgressIndicator];

	if ( [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask )
	{
		[[self document] setShowUpdates:YES];
	
	} else
	{
		[[self document] setShowUpdates:NO];
	}

	[[self document] fetchSvnStatusVerbose];
}
- (void)fetchSvnInfo
{
	[self startProgressIndicator];

	[[self document] fetchSvnInfo];
}
//
//- (void) fetchSvnStatusReceiveDataFinished
//{
//	[self stopProgressIndicator];
//	[textResult setString:[[self document] resultString]];
//	
//	svnStatusPending = NO;
//}
//
- (void) fetchSvnStatusVerboseReceiveDataFinished
{
	
	[self stopProgressIndicator];
//	[textResult setString:[[self document] resultString]];
//	[tableResult reloadData];


	[outliner setIndentationPerLevel:8];
	
	NSIndexSet *selectedRows = [outliner selectedRowIndexes];
	[outliner reloadData];
	[outliner expandItem:[outliner itemAtRow:0] expandChildren:YES];
	[outliner selectRowIndexes:selectedRows byExtendingSelection:NO];
	if ( [selectedRows count] )
		[outliner scrollRowToVisible:[selectedRows firstIndex]];
	
	svnStatusPending = NO;
}

- (IBAction)changeFilter:(id)sender
{
	int tag = [[sender selectedItem] tag];																		

	[[self document] setFilterMode:tag];
}

- (IBAction)openRepository:(id)sender
{
	[[NSApp delegate] openRepository:[[self document] repositoryUrl] user:[[self document] user] pass:[[self document] pass]];
}

- (IBAction)toggleSidebar:(id)sender
{
	[sidebar toggle:sender];
}


#pragma mark -
#pragma mark Split View delegate

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	NSView *leftView = [[splitView subviews] objectAtIndex:0];
	
	if ( subview == leftView )
	{
		return NO; // I would like to return YES here, but can't find a way to uncollapse a view programmatically.
				   // Collasping a view is obviously not setting its width to 0 ONLY.
				   // If I allow user collapsing here, I won't be able to expand the left view with the "toggle button"
				   // (it will remain closed, in spite of a size.width > 0);
	
	} else
	{
		return NO;
	}
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{	
	if ( offset == 0 )
	{
		if ( [document flatMode] ) return 0;
	}	
	return proposedMax;
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	//NSView *leftView = [[splitView subviews] objectAtIndex:0];
	if ( [document flatMode] ) return (float)0;
	
	return (float)140;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
    // how to resize a horizontal split view so that the left frame stays a constant size
    NSView *left = [[sender subviews] objectAtIndex:0];      // get the two sub views
    NSView *right = [[sender subviews] objectAtIndex:1];
    float dividerThickness = [sender dividerThickness];         // and the divider thickness
    NSRect newFrame = [sender frame];                           // get the new size of the whole splitView
    NSRect leftFrame = [left frame];                            // current size of the left subview
    NSRect rightFrame = [right frame];                          // ...and the right
    leftFrame.size.height = newFrame.size.height;               // resize the height of the left
    leftFrame.origin = NSMakePoint(0,0);                        // don't think this is needed
    rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dividerThickness;  // the rest of the width
    rightFrame.size.height = newFrame.size.height;              // the whole height
    rightFrame.origin.x = leftFrame.size.width + dividerThickness;  // 
    [left setFrame:leftFrame];
    [right setFrame:rightFrame];
}

#pragma mark -
#pragma mark svn operations requests
#pragma mark 

#pragma mark svn update

- (void)svnUpdate:(id)sender
{
	[[NSAlert alertWithMessageText:[NSString stringWithFormat:@"Are you sure you want to update this working copy to the latest revision ?", @"update"]
					 defaultButton:@"Yes"
				   alternateButton:@"No"
					   otherButton:nil
		 informativeTextWithFormat:@""]
		
		beginSheetModalForWindow:[self window]
				   modalDelegate:self
				  didEndSelector:@selector(updateWorkingCopyPanelDidEnd:returnCode:contextInfo:)
					 contextInfo:nil];					 
}

- (void)updateWorkingCopyPanelDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{	
	if ( returnCode == 0 ) return;

	[document svnUpdate];
}

#pragma mark FileMerge

- (void)svnFileMerge:(id)sender
{
	if ( [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask )
	{

		if ( [[svnFilesAC selectedObjects] count ] != 1 )
		{
			[self svnError:@"Please select exactly one item."];
			return;	
		} 

		id item = [[svnFilesAC selectedObjects] objectAtIndex:0];

		if ( [NSBundle loadNibNamed:@"svnFileMerge" owner:fileMergeController] )
		{
			[fileMergeController setPath:[item objectForKey:@"fullPath"]];
			[fileMergeController setSvnOptionsInvocation:[[self document] svnOptionsInvocation]];
			[fileMergeController setSourceItem:item];
			[fileMergeController setup]; 

			[NSApp beginSheet:[fileMergeController window]
			   modalForWindow:[document windowForSheet]
				modalDelegate:self
			   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
				  contextInfo:nil];
		}	
	}
	else
	{
		[[self document] fileMergeItems:[[svnFilesAC selectedObjects] mutableArrayValueForKey:@"fullPath"]];
	}
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	[sheet orderOut:nil];
	
	if ( returnCode == 1 )
	{
	}
	
	[fileMergeController unload];
}

#pragma mark Rename (svn move)

- (void) requestSvnRenameSelectedItemTo:(NSString *)destination
{
	[self runAlertBeforePerformingAction:[NSDictionary dictionaryWithObjectsAndKeys:	@"rename", @"command", 
																						@"rename", @"verb", 
																						destination, @"destination",
																						nil]];
}

#pragma mark svn move

- (void)requestSvnMoveSelectedItemsToDestination:(NSString *)destination
{
	NSMutableDictionary *action = [NSMutableDictionary dictionaryWithObjectsAndKeys:	@"move", @"command", 
																						@"move", @"verb", 
																						destination, @"destination",
																						nil];
	if ( [[svnFilesAC selectedObjects] count] == 1 )
	{
		[renamePanel setTitle:@"Move and rename"];
		[renamePanelTextField setStringValue:[[[[svnFilesAC selectedObjects] objectAtIndex:0] valueForKey:@"path"] lastPathComponent]];
		[NSApp beginSheet:renamePanel modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(renamePanelDidEnd:returnCode:contextInfo:) contextInfo:[action retain]];
	
	} else [self runAlertBeforePerformingAction:action];
}

#pragma mark svn copy

- (void) requestSvnCopySelectedItemsToDestination:(NSString *)destination
{
	NSMutableDictionary *action = [NSMutableDictionary dictionaryWithObjectsAndKeys:	@"copy", @"command", 
																						@"copy", @"verb", 
																						destination, @"destination",
																						nil];
	if ( [[svnFilesAC selectedObjects] count] == 1 )
	{
		[renamePanel setTitle:@"Copy and rename"];
		[renamePanelTextField setStringValue:[[[[svnFilesAC selectedObjects] objectAtIndex:0] valueForKey:@"path"] lastPathComponent]];
		[NSApp beginSheet:renamePanel modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(renamePanelDidEnd:returnCode:contextInfo:) contextInfo:[action retain]];
	
	} else
	[self runAlertBeforePerformingAction:action];
}

#pragma mark svn copy & svn move common 
- (void)renamePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:nil];
	NSMutableDictionary *action = contextInfo;
	
	[action setObject:[[contextInfo objectForKey:@"destination"] stringByAppendingPathComponent:[renamePanelTextField stringValue]] forKey:@"destination"];
	
	if ( returnCode == 1 )
	{
		[self runAlertBeforePerformingAction:action];
	}
	
	[contextInfo release];																					
}

- (IBAction)renamePanelValidate:(id)sender;
{
	[NSApp endSheet:renamePanel returnCode:[sender tag]];
}

#pragma mark svn switch (called from MyDragSupportWindow)

-(void)requestSwitchToRepositoryPath:(NSDictionary *)repositoryPathObj
{
//	NSLog(@"%@", repositoryPathObj);
	NSString *path = [repositoryPathObj valueForKeyPath:@"url.absoluteString"];
	NSString *revision = [repositoryPathObj valueForKey:@"revision"];

	NSMutableDictionary *action = [NSMutableDictionary dictionaryWithObjectsAndKeys:	@"switch", @"command", 
																						@"switch", @"verb", 
																						path, @"destination",
																						revision, @"revision",
																						nil];

	[switchPanel setTitle:@"Switch"];
	[switchPanelSourceTextField setStringValue:[NSString stringWithFormat:@"%@  (rev. %@)", [[self document] repositoryUrl], [[self document] revision]]];
	[switchPanelDestinationTextField setStringValue:[NSString stringWithFormat:@"%@  (rev. %@)", path, revision]];
	
	[NSApp beginSheet:switchPanel modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(switchPanelDidEnd:returnCode:contextInfo:) contextInfo:[action retain]];

}

- (IBAction)switchPanelValidate:(id)sender;
{
	[NSApp endSheet:switchPanel returnCode:[sender tag]];
}

- (void)switchPanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:nil];
	NSMutableDictionary *action = contextInfo;
	
	if ( returnCode == 1 )
	{
		if ( [switchPanelRelocateButton intValue] == 1 )//  --relocate
		{
			[[self document] svnCommand:@"switch" options:[NSArray arrayWithObjects:@"-r",
															[contextInfo objectForKey:@"revision"],
															@"--relocate",
															[[[self document] repositoryUrl] absoluteString],
															[contextInfo objectForKey:@"destination"],
															[document workingCopyPath],
															nil] info:nil];
		
		} else
		{
			[[self document] svnCommand:@"switch" options:[NSArray arrayWithObjects:@"-r",
															[contextInfo objectForKey:@"revision"],
															[contextInfo objectForKey:@"destination"],
															[document workingCopyPath],
															//[contextInfo objectForKey:@"source"],
															nil] info:nil];
		}
	}
	
	[contextInfo release];																					
}



#pragma mark common methods

- (void)runAlertBeforePerformingAction:(NSDictionary *)command;
{
	if ( [[command objectForKey:@"command"] isEqualToString:@"commit"] )
	{
		[self startCommitMessage:@"selected"];

	} else
	{

		[[NSAlert alertWithMessageText:[NSString stringWithFormat:@"Are you sure you want to %@ selected items ?", [command objectForKey:@"verb"]]
			defaultButton:@"Yes"
			alternateButton:@"No"
			otherButton:nil
			informativeTextWithFormat:@""]
			
			beginSheetModalForWindow:window
						modalDelegate:self
						didEndSelector:@selector(commandPanelDidEnd:returnCode:contextInfo:)
						contextInfo:[command retain]];
	}
	
	return;
}

- (void)commandPanelDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	NSString *command = [contextInfo objectForKey:@"command"];

	if ( returnCode == 0 )
	{
		[svnFilesAC discardEditing]; // cancel editing, useful to revert a row being renamed (see TableViewDelegate).
		[contextInfo release];
		return;
	}
	
	if ( [command isEqualToString:@"rename"] )
	{
		[[self document] svnCommand:@"rename" options:[contextInfo objectForKey:@"options"] info:contextInfo];
	
	} else
	if ( [command isEqualToString:@"move"] )
	{
		[[self document] svnCommand:@"move" options:[contextInfo objectForKey:@"options"] info:contextInfo];
	
	} else
	if ( [command isEqualToString:@"copy"] )
	{
		[[self document] svnCommand:@"copy" options:[contextInfo objectForKey:@"options"] info:contextInfo];
	
	} else
	if ( [command isEqualToString:@"remove"] )
	{
		[[self document] svnCommand:@"remove" options:[NSArray arrayWithObject:@"--force"] info:nil];
		
	} else
	if ( [command isEqualToString:@"commit"] )
	{
		[self startCommitMessage:@"selected"];
	
	} else
	{
		[[self document] svnCommand:command options:nil info:nil];
	}

	[contextInfo release];

}

- (void)startCommitMessage:(NSString *)selectedOrAll
{
	[NSApp beginSheet:commitPanel   modalForWindow:[self window]
									modalDelegate:self
									didEndSelector:@selector(commitPanelDidEnd:returnCode:contextInfo:)
									contextInfo:[selectedOrAll retain]];
}
- (void)commitPanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
{
	if ( returnCode == 1 )
	{
		[[self document] svnCommand:@"commit" options:[NSArray arrayWithObjects:@"-m", [commitPanelText string], nil] info:nil];
	}
	[contextInfo release];	
	[sheet close];
}

#pragma Error sheet

- (void)svnError:(NSString*)errorString
{
	// close any existing sheet that is not an svnError sheet (workaround a "double sheet" effect that can occur because svn info and svn status are launched simultaneously)
	if ( !isDisplayingErrorSheet && [window attachedSheet] != nil ) [NSApp endSheet:[window attachedSheet]];
	
 	[self stopProgressIndicator];
	
	if ( !isDisplayingErrorSheet )
	{
		isDisplayingErrorSheet = YES;

		NSAlert *alert = [NSAlert alertWithMessageText:@"Error"
				defaultButton:@"OK"
				alternateButton:nil
				otherButton:nil
				informativeTextWithFormat:errorString];

		[alert setAlertStyle:NSCriticalAlertStyle];

		[alert	beginSheetModalForWindow:window
						   modalDelegate:self
						  didEndSelector:@selector(svnErrorSheetEnded:returnCode:contextInfo:)
						     contextInfo:nil];
	}
}
- (void)svnErrorSheetEnded:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	isDisplayingErrorSheet = NO;
}

- (IBAction)commitPanelValidate:(id)sender
{
	[NSApp endSheet:commitPanel returnCode:1];
}

- (IBAction)commitPanelCancel:(id)sender
{
	[NSApp endSheet:commitPanel returnCode:0];
}

- (void)startProgressIndicator
{
	[progressIndicator startAnimation:self];
}
- (void)stopProgressIndicator
{
	[progressIndicator stopAnimation:self];
}

//- (NSDictionary *)performActionMenusDict
//{
//	if ( performActionMenusDict == nil )
//	{
//		performActionMenusDict = [[NSDictionary dictionaryWithContentsOfFile:[[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Resources/" ]
//								stringByAppendingPathComponent:@"performMenus.plist"]] retain];
//	}
//	
//	return performActionMenusDict;
//}
#pragma mark -
#pragma mark Convenience accessors

-(MyWorkingCopy*)document
{
	return document;
}
-(NSWindow*)window
{
	return window;
}

// Have the Finder show the parent folder for the selected files.
- (void)revealInFinder:(id)sender
{
	NSEnumerator *enumerator = [[svnFilesAC selectedObjects] objectEnumerator];
	id file;
			
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	while(file = [enumerator nextObject]) 
	{
		NSURL *fileURL = [NSURL fileURLWithPath:[file valueForKey:@"fullPath"]];
		[ws selectFile:[fileURL path] inFileViewerRootedAtPath:nil];
	}	
}

@end
