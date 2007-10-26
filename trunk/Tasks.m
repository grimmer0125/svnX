#import "Tasks.h"

// This file was patched by Yuichi Fujishige to provide better support for  UTF-16 filenames. (0.9.6)

@implementation Tasks
static id sharedInstance;

+(id)sharedInstance
{
	return sharedInstance;
}

-(id)init
{
	if ( self = [super init] )
	{
		sharedInstance = self;
	}
	
	return self;
}

-(void)awakeFromNib
{
	[tasksAC addObserver:self forKeyPath:@"selection.newStdout" options:(NSKeyValueObservingOptionNew) context:nil];
	[tasksAC addObserver:self forKeyPath:@"selection.newStderr" options:(NSKeyValueObservingOptionNew) context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// This is an optimized way to display the log output. The incoming data is directly appended to NSTextView's textstorage ( see NSTextView+MyAdditions.m ).
	// With a classical binding, NSTextView would have to redisplay its content each time...
	
	NSArray *selectedTasks = [tasksAC selectedObjects];

	if ( [selectedTasks count] == 1 )
	{
		NSDictionary *taskObj = [selectedTasks objectAtIndex:0];

		if ( taskObj != currentTaskObj ) // the selection must have changed
		{
			[[logTextView textStorage] setAttributedString:[taskObj valueForKey:@"combinedLog"]];
			currentTaskObj = taskObj;
		}
		else
		if ( [keyPath isEqualToString:@"selection.newStdout"] )
		{
			[logTextView appendString:[taskObj objectForKey:@"newStdout"] isErrorStyle:NO];
		
		} else
		{
			[logTextView appendString:[taskObj objectForKey:@"newStderr"] isErrorStyle:YES];
		}
	
	} else
	{
		[logTextView setString:@""];
		currentTaskObj = nil;
	}
}


#pragma mark -
#pragma mark IB actions

- (IBAction)stopTask:(id)sender
{
	NSArray *selectedTasks = [tasksAC selectedObjects];
	NSEnumerator *e = [selectedTasks objectEnumerator];
	id taskObj;
	
	while ( taskObj = [e nextObject] )
	{
		if ( [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask ) // if Alt is pressed, use kill -9 to kill.
		{
			[MySvn killProcess:[taskObj valueForKey:@"pid"]];
		
		} else
		{
			[[taskObj valueForKey:@"task"] terminate];
		}	
	}
}

- (IBAction)clearCompleted:(id)sender
{
	NSArray *tasks = [tasksAC arrangedObjects];
	NSEnumerator *e = [tasks objectEnumerator];
	id taskObj;

	while ( taskObj = [e nextObject] )
	{
		if ( [[taskObj valueForKey:@"canBeKilled"] boolValue] == NO ) // tasks that can't be killed are already killed :-)
		{
			[tasksAC removeObject:taskObj];
		}
	}
}

#pragma mark -
#pragma mark tasks control

-(void)newTaskWithDictionary:(NSMutableDictionary *)taskObj
{
	NSTask *task = [taskObj objectForKey:@"task"];
    NSFileHandle *handle = [taskObj objectForKey:@"handle"];
    NSFileHandle *errorHandle = [taskObj objectForKey:@"errorHandle"];
	NSAttributedString *attrStr = [[[NSAttributedString alloc] initWithString:@"" attributes:[NSDictionary dictionaryWithObjectsAndKeys:
											[NSFont fontWithName:@"Courier" size:11],
											NSFontAttributeName, [NSColor blackColor],
											NSForegroundColorAttributeName, nil]] autorelease];

	[taskObj setValue:[NSMutableString string] forKey:@"stdout"];
	[taskObj setValue:[NSString string] forKey:@"newStdout"];		// will contain the incoming chunk to be appended to stdout
	[taskObj setValue:[NSMutableString string] forKey:@"stderr"];
	[taskObj setValue:[NSString string] forKey:@"newStderr"];		// see above
	[taskObj setValue:[NSDate date] forKey:@"date"];

	[taskObj setValue:[NSMutableData data] forKey:@"restRowStdoutData"];	// row stdout data


	[taskObj setValue:[[NSMutableAttributedString alloc] initWithString:@"" attributes:[NSDictionary dictionaryWithObjectsAndKeys:
											[NSFont fontWithName:@"Courier" size:11],
											NSFontAttributeName, [NSColor blackColor],
											NSForegroundColorAttributeName, nil]] forKey:@"combinedLog"];
											

	[taskObj setValue:[NSNumber numberWithBool:YES] forKey:@"canBeKilled"];
	[taskObj setObject:[[[NSLock alloc] init] autorelease] forKey:@"lock"];

	[tasksAC addObject:taskObj];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDataAvailable:) name:NSFileHandleReadCompletionNotification object:handle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDataAvailable:) name:NSFileHandleReadCompletionNotification object:errorHandle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskCompleted:) name:NSTaskDidTerminateNotification object:task];

//	[activityWindow makeKeyAndOrderFront:self];
//	[logDrawer open];

	[handle readInBackgroundAndNotify];
	[errorHandle readInBackgroundAndNotify];

	NS_DURING
		[task launch];
	NS_HANDLER
		if ( [localException name] == NSInvalidArgumentException )
		{
			[taskObj setValue:[NSString stringWithFormat:@"Problem launching svn binary.\nMake sure svn binary is present at path :\n%@.\nIs Subversion client installed ? If so, make sure the path is properly set in the preferences.", [task launchPath]] forKey:@"stderr"];
			[taskObj setValue:@"error" forKey:@"status"];			
			[self invokeCallBackForTask:taskObj];
		}
	NS_ENDHANDLER
}

/*
UCS Code (Hex)	Binary UTF-8 Format			Legal UTF-8 Values (Hex)
00-7F			0xxxxxxx					00-7F
80-7FF			110xxxxx 10xxxxxx			C2-DF 80-BF
800-FFF			1110xxxx 10xxxxxx 10xxxxxx	E0 A0*-BF 80-BF
1000-FFFF		1110xxxx 10xxxxxx 10xxxxxx	E1-EF 80-BF 80-BF
*/
- (void)taskDataAvailable:(NSNotification*)aNotification
{
    NSData *incomingData = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
	NSString *string;
	NSFileHandle *taskHandle = [aNotification object];
	
	NSEnumerator *e = [[tasksAC arrangedObjects] objectEnumerator];
	NSMutableDictionary *taskObj;
	BOOL found = NO;
	BOOL isError = NO;
	
	while ( taskObj = [e nextObject] ) // check if this this a handle that we know about
	{
		 if ( taskHandle == [taskObj objectForKey:@"handle"] )
		 {
			found = YES;
			break;
		 }
	}
	
	if ( found == NO )	// if not, is this an error handle that we know about ?
	{
		NSEnumerator *e = [[tasksAC arrangedObjects] objectEnumerator];
		while ( taskObj = [e nextObject] )
		{
			 if ( taskHandle == [taskObj objectForKey:@"errorHandle"] )
			 {
				found = YES;
				isError = YES;
				break;
			 }
		}
	}
	
	if ( found == NO ) return; 

    if ( incomingData && [incomingData length] )
	{	
		if ( isError )
		{
			// As LANG environment variable set to "en_US.UTF-8", 
			// error messages will be English only.
			// We don't have to modify incomingData.
			string = [[NSString alloc] initWithData:incomingData encoding:NSUTF8StringEncoding];

			NSLock *taskLock = [taskObj objectForKey:@"lock"]; // I'm not sure about the need for a lock here
			[taskLock lock];

			NSMutableString *currentStderr = [taskObj objectForKey:@"stderr"];

			[taskObj willChangeValueForKey:@"stderr"]; // there is currently no observer, but there could be in the future
			[currentStderr appendString:string];
			[taskObj didChangeValueForKey:@"stderr"];

			[taskObj setValue:string forKey:@"newStderr"]; // this key is observed. This will trigger this new chunk to be appended directly in the NSTextView log

			[taskLock unlock];
			
		}
		else
		{
			NSData *restRowStdoutData = [taskObj objectForKey:@"restRowStdoutData"];
			NSMutableData *tmpIncomingData;
			
			if(restRowStdoutData == nil) {
				tmpIncomingData = [NSMutableData dataWithData:incomingData];
			} else {				
				tmpIncomingData = [NSMutableData dataWithData:restRowStdoutData];
				[tmpIncomingData appendData:incomingData];
				NSLock *taskLock = [taskObj objectForKey:@"lock"];
				[taskLock lock];
				[taskObj setValue:nil forKey:@"restRowStdoutData"];
				[taskLock unlock];
			}
			
			const unsigned char* tmpIncomingDataBytes = (const unsigned char*)[tmpIncomingData bytes];
			const unsigned int incominDataLength = [tmpIncomingData length];
			unsigned int offset = incominDataLength -1;
			if(tmpIncomingDataBytes[offset] & 0x80) {
				int noFirstBytesLength = 0;
				while((tmpIncomingDataBytes[offset] & 0xc0) == 0x80) {
					noFirstBytesLength++;
					offset--;
				}
				
				int excessLength = noFirstBytesLength + 1;
				
				NSData *excessData = [NSData dataWithBytes:(tmpIncomingDataBytes + incominDataLength - excessLength)
													length:excessLength];
				//NSLog(@"excessData:%@", excessData);
				
				[tmpIncomingData setLength:incominDataLength - excessLength];
				incomingData = tmpIncomingData;
				
				NSLock *taskLock = [taskObj objectForKey:@"lock"];
				[taskLock lock];
				[taskObj setValue:excessData forKey:@"restRowStdoutData"];
				[taskLock unlock];
			}

			string = [[NSString alloc] initWithData:tmpIncomingData encoding:NSUTF8StringEncoding];

			NSAssert(string != nil, @"stdin incomingData failed to convert");


			NSLock *taskLock = [taskObj objectForKey:@"lock"];
			[taskLock lock];

			NSMutableString *currentStdout = [taskObj objectForKey:@"stdout"];

			[taskObj willChangeValueForKey:@"stdout"];
			[currentStdout appendString:string];
			[taskObj didChangeValueForKey:@"stdout"];

			[taskObj setValue:string forKey:@"newStdout"];

			[taskLock unlock];
		}
		

		NSMutableAttributedString *combinedLog = [taskObj objectForKey:@"combinedLog"]; // this is the combined log

		[taskObj willChangeValueForKey:@"combinedLog"];
		[self appendString:string toAttributedString:combinedLog errorStyle:isError]; // error are appended in red
		[taskObj didChangeValueForKey:@"combinedLog"];



		
		if ( [[taskObj valueForKey:@"status"] isEqualToString:@"stopped"] ) // set in taskCompleted
		{
			// We want to make sure the callback will not be called twice (by the stdout finishing, and by the stderr)
			// so we need a lock. Moreover, stderr can finish first. So we want both to be finished before we call the callback.

			NSLock *taskLock = [taskObj objectForKey:@"lock"];
			[taskLock lock];
			
			if ( ![[taskObj valueForKey:@"otherStdDone"] boolValue] )
			{
				[taskObj setValue:[NSNumber numberWithBool:YES] forKey:@"otherStdDone"];		
			}
			else [self invokeCallBackForTask:taskObj];

			[taskLock unlock];
			
		} else
		{
			[taskHandle readInBackgroundAndNotify];
		}
		
        [string release];		
    }
	else // We're finished with the task
	{
		// we want to make sure the callback will not be called twice (by the stdout finishing, and by the stderr)
		NSLock *taskLock = [taskObj objectForKey:@"lock"];
		[taskLock lock];

		if ( ![[taskObj valueForKey:@"otherStdDone"] boolValue] )
		{
			[taskObj setValue:[NSNumber numberWithBool:YES] forKey:@"otherStdDone"];		
		}
		else [self invokeCallBackForTask:taskObj];

		[taskLock unlock];
	}
}


- (void)taskCompleted:(NSNotification*)aNotification
{
	// IMPORTANT : taskCompleted may be called before the task's output is totally read !
	// This is the reason why the callback should be called from taskDataAvailable, when an empty NSData is finally returned;

	NSTask *notifTask = [aNotification object];
	NSEnumerator *e = [[tasksAC arrangedObjects] objectEnumerator];
	NSMutableDictionary *taskObj;
	BOOL found = NO;
	
	while ( taskObj = [e nextObject] )
	{
		 if ( notifTask == [taskObj objectForKey:@"task"] )
		 {
			found = YES;
			break;
		 }
	}
	
	if ( found == NO ) return;
	int exitCode = [[aNotification object] terminationStatus];
	

	if ( exitCode == 0 )
	{
		[taskObj setValue:@"completed" forKey:@"status"];
	
	} else
	{
		[taskObj setValue:@"stopped" forKey:@"status"];	
	}
	
	if ( [[taskObj objectForKey:@"stderr"] length] > 0 )
	{
		[taskObj setValue:@"error" forKey:@"status"];		
	}
	
	[taskObj setValue:[NSNumber numberWithBool:NO] forKey:@"canBeKilled"];
	[taskObj setValue:[NSNumber numberWithInt:exitCode] forKey:@"exitCode"];
}

-(void)cancelCallbacksOnTarget:(id)target
{
	// This is called from the target, before it's closed, because a callback on a closing target is likely to crash.
	// The task is not stopped, though.
	
	NSEnumerator *e = [[[tasksAC arrangedObjects] valueForKey:@"callback"] objectEnumerator];
	NSInvocation *callback;
	
	while ( callback = [e nextObject] )
	{
		 if ( target == [callback target] )
		 {
			[callback setTarget:nil];
		 }
	}

}

#pragma mark -
#pragma mark Helpers

- (void)invokeCallBackForTask:(id)taskObj
{
	NSInvocation *callback = [taskObj objectForKey:@"callback"];
	
	
	if ( ![[taskObj objectForKey:@"status"] isEqualToString:@"error"] )
	{
		int exitCode = 0;
		if ( ![[taskObj objectForKey:@"task"] isRunning] )
			exitCode = [[taskObj objectForKey:@"task"] terminationStatus];
		
		[taskObj setValue:[NSNumber numberWithInt:exitCode] forKey:@"exitCode"];
		
		// in case taskCompleted is late, which is likely, we set status value here too
		if ( exitCode == 0 )
		{
			[taskObj setValue:@"completed" forKey:@"status"];
		
		} else
		{
			[taskObj setValue:@"stopped" forKey:@"status"];	
		}
	
	}
	
	if ( [[taskObj objectForKey:@"stderr"] length] > 0 )
	{
		[taskObj setValue:@"error" forKey:@"status"];		
	}
	
	[taskObj setValue:[NSNumber numberWithBool:NO] forKey:@"canBeKilled"];
	
	[[taskObj objectForKey:@"handle"] closeFile];
	[[taskObj objectForKey:@"errorHandle"] closeFile];

	//see file:///Developer/ADC%20Reference%20Library/documentation/Cocoa/Conceptual/DistrObjects/Tasks/invocations.html#//apple_ref/doc/uid/20000744/CJBBACJH
	[callback setArgument:&taskObj atIndex:2]; // index 2 because of the two hidden default arguments (see NSInvocation doc).
	
	if ( [callback target] )
	{
		[callback invoke]; // target may have been cancelled by cancelCallbacksOnTarget
	}
}

- (NSMutableAttributedString*)appendString:(NSString *)string toAttributedString:(NSMutableAttributedString *)otherString errorStyle:(BOOL)isError
{
	NSFont *txtFont = [NSFont fontWithName:@"Courier" size:11];
	NSDictionary *txtDict;
	
	if ( isError )
	{
		txtDict = [NSDictionary dictionaryWithObjectsAndKeys:txtFont, NSFontAttributeName, [NSColor redColor], NSForegroundColorAttributeName, nil];
	
	} else
	{
		txtDict = [NSDictionary dictionaryWithObjectsAndKeys:txtFont, NSFontAttributeName, [NSColor blackColor], NSForegroundColorAttributeName, nil];
	}
	
	NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:string attributes:txtDict];
	[otherString appendAttributedString:attrStr];
	[attrStr release];
	
	return otherString;
}


@end
