#import "MySVN.h"
#import "Tasks.h"
#import "NSString+MyAdditions.h"
#import "CommonUtils.h"


// This file was patched by Yuichi Fujishige to provide better support for  UTF-16 filenames. (0.9.6)

//----------------------------------------------------------------------------------------
// Task dictionary object accessors

BOOL
isCompleted (NSDictionary* taskObj)
{
	return [[taskObj objectForKey: @"status"] isEqualToString: @"completed"];
}


//----------------------------------------------------------------------------------------

NSString*
stdErr (NSDictionary* taskObj)
{
	NSString* str = [taskObj objectForKey: @"stderr"];
	return (str && [str length] != 0) ? str : nil;
}


//----------------------------------------------------------------------------------------

NSString*
stdOut (NSDictionary* taskObj)
{
	return [taskObj objectForKey: @"stdout"];
}


//----------------------------------------------------------------------------------------

NSData*
stdOutData (NSDictionary* taskObj)
{
	return [taskObj objectForKey: @"stdoutData"];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

enum {
	kLogLevelNone	=	0,
	kLogLevelError	=	1,
	kLogLevelGlobal	=	2,
	kLogLevelLocal	=	3,
	kLogLevelAll	=	99
};

@implementation Tasks

static id sharedInstance;
static NSDictionary* gTextStyleStd = nil, *gTextStyleErr = nil;
static int gLogLevel = kLogLevelAll;


+ (id) sharedInstance
{
	return sharedInstance;
}


//----------------------------------------------------------------------------------------

- (id) init
{
	if ( self = [super init] )
	{
		sharedInstance = self;
	}

	if (gTextStyleStd == nil)
	{
		NSFont* txtFont = [NSFont fontWithName: @"Courier" size: 11];
		gTextStyleStd = [[NSDictionary dictionaryWithObjectsAndKeys:
											txtFont, NSFontAttributeName,
											[NSColor blackColor], NSForegroundColorAttributeName,
											nil] retain];
		gTextStyleErr = [[NSDictionary dictionaryWithObjectsAndKeys:
											txtFont, NSFontAttributeName,
											[NSColor redColor], NSForegroundColorAttributeName,
											nil] retain];
	}

	id loggingLevel = GetPreference(@"loggingLevel");
	gLogLevel = loggingLevel ? [loggingLevel intValue] : kLogLevelAll;

	return self;
}


//----------------------------------------------------------------------------------------

-(void)awakeFromNib
{
	[tasksAC addObserver:self forKeyPath:@"selection.newStdout" options:(NSKeyValueObservingOptionNew) context:nil];
	[tasksAC addObserver:self forKeyPath:@"selection.newStderr" options:(NSKeyValueObservingOptionNew) context:nil];
}


//----------------------------------------------------------------------------------------

- (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	#pragma unused(object, change, context)
	// This is an optimized way to display the log output. The incoming data is directly appended to
	// NSTextView's textstorage (see NSTextView+MyAdditions.m).
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
		else if ( [keyPath isEqualToString:@"selection.newStdout"] )
		{
			if (gLogLevel >= kLogLevelGlobal)
				[logTextView appendString:[taskObj objectForKey:@"newStdout"] isErrorStyle:NO];
		}
		else
		{
			if (gLogLevel >= kLogLevelError)
				[logTextView appendString:[taskObj objectForKey:@"newStderr"] isErrorStyle:YES];
		}
	}
	else
	{
		[logTextView setString:@""];
		currentTaskObj = nil;
	}
}


//----------------------------------------------------------------------------------------
#pragma mark -
#pragma mark IB actions

- (IBAction) stopTask: (id) sender
{
	#pragma unused(sender)
	const BOOL altPressed = AltOrShiftPressed();
	for_each(en, taskObj, [tasksAC arrangedObjects])
	{
		[MySvn killTask: taskObj force: altPressed];
	}
}


//----------------------------------------------------------------------------------------

- (IBAction) clearCompleted: (id) sender
{
	#pragma unused(sender)
	for_each(en, taskObj, [tasksAC arrangedObjects])
	{
		if (![[taskObj objectForKey: @"canBeKilled"] boolValue])	// tasks that can't be killed are already killed :-)
		{
			[tasksAC removeObject: taskObj];
		}
	}
}


//----------------------------------------------------------------------------------------
#pragma mark -
#pragma mark Helpers


- (void) invokeCallBackForTask: (id) taskObj
{
	NSInvocation *callback = [taskObj objectForKey:@"callback"];
	id status = @"completed";

	if ( ![[taskObj objectForKey:@"status"] isEqualToString:@"error"] )
	{
		int exitCode = 0;
		if ( ![[taskObj objectForKey:@"task"] isRunning] )
			exitCode = [[taskObj objectForKey:@"task"] terminationStatus];
		
		[taskObj setValue:[NSNumber numberWithInt:exitCode] forKey:@"exitCode"];
		
		// in case taskCompleted is late, which is likely, we set status value here too
		if (exitCode)
			status = @"stopped";
	}

	if (stdErr(taskObj))
		status = @"error";

	[taskObj setValue: status forKey: @"status"];
	[taskObj setValue: kNSFalse forKey: @"canBeKilled"];

	[[taskObj objectForKey:@"handle"] closeFile];
	[[taskObj objectForKey:@"errorHandle"] closeFile];

	// see file://localhost/Developer/ADC%20Reference%20Library/documentation/Cocoa/Conceptual/DistrObjects/Tasks/invocations.html
	[callback setArgument:&taskObj atIndex:2]; // index 2 because of the two hidden default arguments (see NSInvocation doc).

	if ( [callback target] )
	{
		[callback invoke]; // target may have been cancelled by cancelCallbacksOnTarget
		[callback setTarget: nil];
	}
}


- (NSMutableAttributedString*) appendString:       (NSString*)                  string
							   toAttributedString: (NSMutableAttributedString*) otherString
							   errorStyle:         (BOOL)                       isError
{
	NSDictionary* txtDict = isError ? gTextStyleErr : gTextStyleStd;

	NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:string attributes:txtDict];
	[otherString appendAttributedString:attrStr];
	[attrStr release];
	
	return otherString;
}


- (void) taskIsDone: (NSMutableDictionary*) taskObj
{
	// we want to make sure the callback will not be called twice (by the stdout finishing, and by the stderr)
	// so we need a lock. Moreover, stderr can finish first. So we want both to be finished before we call the callback.
	NSLock* taskLock = [taskObj objectForKey: @"lock"];
	[taskLock lock];

	if ([[taskObj valueForKey: @"otherStdDone"] boolValue])
		[self invokeCallBackForTask: taskObj];
	else
		[taskObj setValue: kNSTrue forKey: @"otherStdDone"];

	[taskLock unlock];
}


- (void) stdoutDataAvailable: (NSNotification*) aNotification
{
	[self taskDataAvailable: aNotification isError: NO];
}


- (void) stderrDataAvailable: (NSNotification*) aNotification
{
	[self taskDataAvailable: aNotification isError: YES];
}


//----------------------------------------------------------------------------------------
#pragma mark -
#pragma mark tasks control

- (void) newTaskWithDictionary: (NSMutableDictionary*) taskObj
{
	NSTask *task = [taskObj objectForKey:@"task"];
	NSFileHandle *handle = [taskObj objectForKey:@"handle"];
	NSFileHandle *errorHandle = [taskObj objectForKey:@"errorHandle"];

	[taskObj setValue:[NSMutableString string] forKey:@"stdout"];
	[taskObj setValue:[NSString string] forKey:@"newStdout"];		// will contain the incoming chunk to be appended to stdout
	[taskObj setValue:[NSMutableString string] forKey:@"stderr"];
	[taskObj setValue:[NSString string] forKey:@"newStderr"];		// see above
	[taskObj setValue:[NSDate date] forKey:@"date"];

	[taskObj setValue:[NSMutableData data] forKey:@"stdoutData"];	// row stdout data

	const id combinedLog = [[NSMutableAttributedString alloc] initWithString: @"" attributes: gTextStyleStd];
	[taskObj setValue:combinedLog forKey:@"combinedLog"];
	[combinedLog release];

	[taskObj setValue: kNSTrue forKey: @"canBeKilled"];
	[taskObj setObject:[[[NSLock alloc] init] autorelease] forKey:@"lock"];

	[tasksAC addObject:taskObj];

	NSNotificationCenter* notifier = [NSNotificationCenter defaultCenter];
	[notifier addObserver: self selector: @selector(stdoutDataAvailable:)
								name: NSFileHandleReadCompletionNotification object: handle];
	[notifier addObserver: self selector: @selector(stderrDataAvailable:)
								name: NSFileHandleReadCompletionNotification object: errorHandle];
	[notifier addObserver: self selector: @selector(taskCompleted:)
								name: NSTaskDidTerminateNotification         object: task];

//	[activityWindow makeKeyAndOrderFront:self];
//	[logDrawer open];

	[handle readInBackgroundAndNotify];
	[errorHandle readInBackgroundAndNotify];

	@try
	{
		[task launch];
	}
	@catch (id exception)
	{
		dprintf("%@ %@\n    CAUGHT %@", [task launchPath], [task arguments], exception);
		if ([exception name] == NSInvalidArgumentException)
		{
			[taskObj setValue: [NSString stringWithFormat: @"Problem launching svn binary.\n"
															"Make sure an svn binary is present at path:\n"
															"'%@'.\nIs Subversion client installed?"
															" If so, make sure the path is properly set in the preferences.",
															[task launchPath]]
					forKey: @"stderr"];
			[taskObj setValue:@"error" forKey:@"status"];			
			[self invokeCallBackForTask:taskObj];
		}
	}
}


/*
UCS Code (Hex)	Binary UTF-8 Format			Legal UTF-8 Values (Hex)
00-7F			0xxxxxxx					00-7F
80-7FF			110xxxxx 10xxxxxx			C2-DF 80-BF
800-FFF			1110xxxx 10xxxxxx 10xxxxxx	E0 A0*-BF 80-BF
1000-FFFF		1110xxxx 10xxxxxx 10xxxxxx	E1-EF 80-BF 80-BF
*/
- (void) taskDataAvailable: (NSNotification*) aNotification isError: (BOOL) isError
{
    NSData* const incomingData = [[aNotification userInfo] objectForKey: NSFileHandleNotificationDataItem];
	NSFileHandle* const taskHandle = [aNotification object];

	BOOL found   = NO,
		 doLog   = (gLogLevel > kLogLevelNone);

	NSString* const key = isError ? @"errorHandle" : @"handle";
	NSEnumerator *e = [[tasksAC arrangedObjects] objectEnumerator];
	NSMutableDictionary *taskObj;
	while ( taskObj = [e nextObject] )
	{
		if ( taskHandle == [taskObj objectForKey: key] )
		{
			found = YES;
			break;
		}
	}

	if (!found)
		;
    else if ( incomingData && [incomingData length] )
	{
		NSLock* const taskLock = [taskObj objectForKey: @"lock"];
		NSString *string = nil;
		if ( isError )
		{
			if (gLogLevel >= kLogLevelError)
			{
				// As LANG environment variable set to "en_US.UTF-8", error messages will be English only.
				// We don't have to modify incomingData.
				string = [[NSString alloc] initWithData:incomingData encoding:NSUTF8StringEncoding];

				[taskLock lock];	// I'm not sure about the need for a lock here

				NSMutableString *currentStderr = [taskObj objectForKey:@"stderr"];

				[taskObj willChangeValueForKey:@"stderr"]; // there is currently no observer, but there could be in the future
				[currentStderr appendString:string];
				[taskObj didChangeValueForKey:@"stderr"];

				[taskObj setValue:string forKey:@"newStderr"];	// this key is observed. This will trigger this new
																// chunk to be appended directly in the NSTextView log
				[taskLock unlock];
			}
		}
		else
		{
			NSMutableData *restRowStdoutData = [taskObj objectForKey:@"stdoutData"];
			NSMutableData *tmpIncomingData;

			if (restRowStdoutData == nil)
			{
				tmpIncomingData = [NSMutableData dataWithData:incomingData];
			}
			else if ([taskObj objectForKey: @"outputToData"] == kNSTrue)
			{
				[restRowStdoutData appendData: incomingData];
				doLog = NO;
			}
			else
			{
				tmpIncomingData = [NSMutableData dataWithData:restRowStdoutData];
				[tmpIncomingData appendData:incomingData];
				[taskLock lock];
				[taskObj setValue:nil forKey:@"stdoutData"];
				[taskLock unlock];
			}

			if (doLog)
			{
				const unsigned char* tmpIncomingDataBytes = (const unsigned char*)[tmpIncomingData bytes];
				const unsigned int incominDataLength = [tmpIncomingData length];
				unsigned int offset = incominDataLength - 1;
				if (tmpIncomingDataBytes[offset] & 0x80)
				{
					int noFirstBytesLength = 0;
					while ((tmpIncomingDataBytes[offset] & 0xc0) == 0x80)
					{
						noFirstBytesLength++;
						offset--;
					}
					
					int excessLength = noFirstBytesLength + 1;
					
					NSData *excessData = [NSData dataWithBytes:(tmpIncomingDataBytes + incominDataLength - excessLength)
														length:excessLength];
					//NSLog(@"excessData:%@", excessData);
					
					[tmpIncomingData setLength:incominDataLength - excessLength];
				//	incomingData = tmpIncomingData;
					
					[taskLock lock];
					[taskObj setValue:excessData forKey:@"stdoutData"];
					[taskLock unlock];
				}

				string = [[NSString alloc] initWithData: tmpIncomingData encoding: NSUTF8StringEncoding];
				Assert(string != nil);	// stdin incomingData failed to convert

				[taskLock lock];

				NSMutableString *currentStdout = [taskObj objectForKey:@"stdout"];

				[taskObj willChangeValueForKey:@"stdout"];
				[currentStdout appendString:string];
				[taskObj didChangeValueForKey:@"stdout"];

				[taskObj setValue:string forKey:@"newStdout"];

				[taskLock unlock];
			}
		}

		if (doLog && gLogLevel >= kLogLevelGlobal)
		{
			NSMutableAttributedString *combinedLog = [taskObj objectForKey:@"combinedLog"]; // this is the combined log

			[taskObj willChangeValueForKey:@"combinedLog"];
			[self appendString:string toAttributedString:combinedLog errorStyle:isError]; // error are appended in red
			[taskObj didChangeValueForKey:@"combinedLog"];
		}

		if ( [[taskObj valueForKey:@"status"] isEqualToString:@"stopped"] ) // set in taskCompleted
		{
			[self taskIsDone: taskObj];
		}
		else
		{
			[taskHandle readInBackgroundAndNotify];
		}
		
        [string release];		
    }
	else // We're finished with the task
	{
		[self taskIsDone: taskObj];
	}
}


- (void) taskCompleted: (NSNotification*) aNotification
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

	if (found)
	{
		int exitCode = [[aNotification object] terminationStatus];
		id status = stdErr(taskObj) ? @"error" : (exitCode ? @"stopped" : @"completed");
		[taskObj setValue: status forKey: @"status"];
		[taskObj setValue: kNSFalse forKey: @"canBeKilled"];
		[taskObj setValue: [NSNumber numberWithInt: exitCode] forKey: @"exitCode"];
	}
}


-(void) cancelCallbacksOnTarget: (id) target
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


@end	// Tasks


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

@implementation Task


//----------------------------------------------------------------------------------------
// Create a default environment dictionary for each & every task

+ (NSMutableDictionary*) createEnvironment: (BOOL) isUnbuffered
{
	// If there's a 'TaskEnvironment' dict in the plist then add its elements to the Task's environment.
	static id kTaskEnvironment = nil;
	static BOOL inited = FALSE;
	if (!inited)
	{
		inited = TRUE;
		kTaskEnvironment = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"TaskEnvironment"];
		if (![kTaskEnvironment isKindOfClass: [NSDictionary class]])
			kTaskEnvironment = nil;
	}

	NSMutableDictionary* env = [NSMutableDictionary dictionaryWithDictionary:
												[[NSProcessInfo processInfo] environment]];
	if (isUnbuffered)
		[env setObject: @"YES"     forKey: @"NSUnbufferedIO"];
//	[env setObject: @"en_US.UTF-8" forKey: @"LC_CTYPE"];
//	[env setObject: @"en_US.UTF-8" forKey: @"LANG"];
	[env setObject: @"en_US.UTF-8" forKey: @"LC_ALL"];
	[env setObject: @""            forKey: @"DYLD_LIBRARY_PATH"];
	if (kTaskEnvironment)
	{
		for_each_key(en, key, kTaskEnvironment)
			[env setObject: [kTaskEnvironment objectForKey: key] forKey: key];
	}

	return env;
}


//----------------------------------------------------------------------------------------

+ (id) task
{
	return [self taskWithDelegate: nil object: nil];
}


//----------------------------------------------------------------------------------------

+ (id) taskWithDelegate: (id<TaskDelegate>) target
	   object:           (id)               object
{
	return [[Task alloc] initWithDelegate: target object: object];
}


//----------------------------------------------------------------------------------------

- (id) initWithDelegate: (id<TaskDelegate>) target
	   object:           (id)               object
{
	if (self = [super init])
	{
		fTask     = [[NSTask alloc] init];
		fDelegate = [target retain];
		fObject   = [object retain];
		[fTask setEnvironment: [Task createEnvironment: FALSE]];
	}

	return self;
}


//----------------------------------------------------------------------------------------

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter]
			removeObserver: self name: NSTaskDidTerminateNotification object: fTask];
	[fObject   release];
	[fDelegate release];
	[fTask     release];

	[super dealloc];
}


//----------------------------------------------------------------------------------------

- (NSTask*) task
{
	return fTask;
}


//----------------------------------------------------------------------------------------

- (void) launch:    (NSString*) path
		 arguments: (NSArray*)  arguments
{
	[fTask setLaunchPath: path];
	[fTask setArguments: arguments];

	[[NSNotificationCenter defaultCenter]
			addObserver: self selector: @selector(completed:)
			name: NSTaskDidTerminateNotification object: fTask];
	[fTask launch];
//	NSLog(@"launch: %@", fTask);
}


//----------------------------------------------------------------------------------------

- (void) launch:    (NSString*) path
		 arguments: (NSArray*)  arguments
		 stdOutput: (NSString*) stdOutput
{
	if (stdOutput != nil)
		[fTask setStandardOutput: [NSFileHandle fileHandleForWritingAtPath: stdOutput]];

	[self launch: path arguments: arguments];
}


//----------------------------------------------------------------------------------------

- (void) setStandardOutput: (id) file
{
	[fTask setStandardOutput: file];
}


//----------------------------------------------------------------------------------------
// Calls [fDelegate taskCompleted: (Task*) self object: (id) fObject]

- (void) completed: (NSNotification*) aNotification
{
	#pragma unused(aNotification)
	id delegate = fDelegate;
	if (delegate)
	{
		Assert([delegate respondsToSelector: @selector(taskCompleted:object:)]);
		id object = fObject;
		fDelegate = nil;
		fObject   = nil;
		[delegate taskCompleted: self object: object];
		[object   release];
		[delegate release];
	}
	[self release];
}


//----------------------------------------------------------------------------------------

- (void) kill
{
	WarnIf(kill([fTask processIdentifier], SIGKILL));
}


//----------------------------------------------------------------------------------------

- (void) terminate: (BOOL) force
{
	if (force)
	{
		[self kill];
	}
	else
	{
		[fTask terminate];
	}
}


//----------------------------------------------------------------------------------------

- (void) terminate
{
	[fTask terminate];
}


@end	// Task

