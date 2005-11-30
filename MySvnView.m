#import "MySvnView.h"

@class Tasks;

@implementation MySvnView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil)
	{

	}
	return self;
}

- (void)dealloc
{
//	NSLog(@"dealloc svn view");

    [self setPendingTask: nil]; 
    [self setUrl: nil]; 
    [self setRevision: nil]; 

    [super dealloc];
}

- (void)unload
{
	// tell the task center to cancel pending callbacks to prevent crash
	[[Tasks sharedInstance] cancelCallbacksOnTarget:self];

    [self setPendingTask: nil]; 
//    [self setUrl: nil]; 
//    [self setRevision: nil]; 
	
	[_view release];	// the nib is responsible for releasing its top-level objects

	// these objects are bound to the file owner and retain it
	// we need to unbind them 
	[progress unbind:@"animate"];		// -> self retainCount -1
	[refetch unbind:@"value"];		// -> self retainCount -1

}


- (IBAction)refetch:(id)sender
{
	if ( [sender state] == NSOnState )
	{
		[self fetchSvn];
	
	} else
	{
		[self setIsFetching:FALSE];

		if ( [self pendingTask] != nil )
		{
			NSTask *task = [[self pendingTask] valueForKey:@"task"];
			
			if ( [task isRunning] )
			{
				[task terminate];
			}
		}

		[self setPendingTask:nil];
	}
}

#pragma mark -
#pragma mark svn related methods

- (void)fetchSvn
{
	[self setIsFetching:TRUE];
}

- (void)svnCommandComplete:(id)taskObj
{
//		NSLog(@"hom %@", [taskObj valueForKey:@"stdout"]);
	if ( [[taskObj valueForKey:@"status"] isEqualToString:@"completed"] )
	{
		[self performSelectorOnMainThread:@selector(fetchSvnReceiveDataFinished:) withObject:taskObj waitUntilDone:YES];
//		[self fetchSvnReceiveDataFinished:taskObj];
		
	} else
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
	
 	[self setIsFetching:NO];
	
	if ( [self window] != nil )
	{
		[alert			
			beginSheetModalForWindow:[self window]
						modalDelegate:self
						didEndSelector:nil
						contextInfo:nil];
	} else
	{
		[alert runModal];
	}
}

- (void)fetchSvnReceiveDataFinished:(id)taskObj
{
	[self setIsFetching:FALSE];
}

#pragma mark -
#pragma mark Helpers

- (NSInvocation *)makeCallbackInvocationOfKind:(int)callbackKind;
{
	// only one kind of invocation for now, but more complex callbacks will be possible in the future
	
	SEL callbackSelector;
	NSInvocation *callback;
		
	callbackSelector = @selector(svnCommandComplete:);
	callback = [NSInvocation invocationWithMethodSignature:[MySvnView instanceMethodSignatureForSelector:callbackSelector]];
	[callback setSelector:callbackSelector];
	[callback setTarget:self];

	return callback;
}

#pragma mark -
#pragma mark Accessors

- (NSInvocation *) svnOptionsInvocation { return svnOptionsInvocation; }
- (void) setSvnOptionsInvocation: (NSInvocation *) aSvnOptionsInvocation {
    id old = [self svnOptionsInvocation];
    svnOptionsInvocation = [aSvnOptionsInvocation retain];
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

// - isFetching:
- (BOOL)isFetching { return isFetching; }
- (void)setIsFetching:(BOOL)flag {
    isFetching = flag;
}

// - pendingTask:
- (id)pendingTask { return pendingTask; }
- (void)setPendingTask:(id)aPendingTask {
    id old = [self pendingTask];
    pendingTask = [aPendingTask retain];
    [old release];
}

@end
