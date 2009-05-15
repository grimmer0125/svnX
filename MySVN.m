//
// MySVN.m
//
#import "MySVN.h"
#import "MyApp.h"
#import "CommonUtils.h"
#import "Tasks.h"
#import <unistd.h>


//----------------------------------------------------------------------------------------

static id
makeTaskInfo (NSString* name, NSString* commmandPath, NSArray* arguments)
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:
				name,															@"name",
				[NSString stringWithFormat:@"%@ %@",
					commmandPath, [arguments componentsJoinedByString: @" "]],	@"command",
				nil];
}


//----------------------------------------------------------------------------------------

static id
makeSvnInfo (NSString* name, NSArray* arguments)
{
	return makeTaskInfo(name, SvnCmdPath(), arguments);
}


//----------------------------------------------------------------------------------------

static NSString*
joinedOptions (NSArray* options1, NSArray* options2)
{
	return [NSString stringWithFormat:@"%@ %@", [options1 componentsJoinedByString: @" "],
												[options2 componentsJoinedByString: @" "]];
}


//----------------------------------------------------------------------------------------

static NSString*
concatOptions (NSInvocation* generalOptions, NSArray* options)
{
	return joinedOptions([MySvn optionsFromSvnOptionsInvocation: generalOptions], options);
}


//----------------------------------------------------------------------------------------

static void
addGeneralOptions (NSMutableArray* arguments, NSInvocation* generalOptions)
{
	[arguments addObjectsFromArray: [MySvn optionsFromSvnOptionsInvocation: generalOptions]];
}


//----------------------------------------------------------------------------------------

NSString*
SvnPath ()
{
	return GetPreference(@"svnBinariesFolder");
}


//----------------------------------------------------------------------------------------

NSString*
SvnCmdPath ()
{
	return [SvnPath() stringByAppendingPathComponent: @"svn"];
}


//----------------------------------------------------------------------------------------

NSString*
ShellScriptPath (NSString* script)
{
	return [[NSBundle mainBundle] pathForResource: script ofType: @"sh"];
}


//----------------------------------------------------------------------------------------

NSString*
GetDiffAppName ()
{
	// 0: FileMerge, 1: TextWrangler, 2: CodeWarrior, 3: BBEdit,
	// 4: Araxis Merge, 5: DiffMerge, 6: Changes
	static NSString* const diffAppNames[] = {
		@"opendiff", @"textwrangler", @"codewarrior", @"bbedit",
		@"araxissvndiff", @"diffmerge", @"changes"
	};

	int diffAppIndex = GetPreferenceInt(@"defaultDiffApplication");
	if (diffAppIndex < 0 || diffAppIndex >= sizeof(diffAppNames) / sizeof(diffAppNames[0]))
		diffAppIndex = 0;

	return diffAppNames[diffAppIndex];
}


//----------------------------------------------------------------------------------------
#pragma mark	-

@implementation MySvn

// New-style svn calls (>=0.8)

+ (NSMutableDictionary*) diffItems:      (NSArray*)      itemsPaths
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSMutableArray* arguments = [NSMutableArray arrayWithObjects:
										@"diff", @"--diff-cmd", ShellScriptPath(@"svndiff"),
										@"--extensions", GetDiffAppName(),
										nil];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments addObjectsFromArray: itemsPaths];

	NSString* taskLaunchPath = SvnCmdPath();
	id additionalTaskInfo = makeTaskInfo(@"svn diff", taskLaunchPath, arguments);

	// <svnCmdPath> diff --diff-cmd <svndiff.sh> --extensions <diffAppName> ...
	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) genericCommand: (NSString*)     command
						 arguments:      (NSArray*)      args
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray arrayWithObject:command];
	
	[arguments addObjectsFromArray: args];

	if (![command isEqualToString:@"info"] && ![command isEqualToString:@"revert"] &&
		![command isEqualToString:@"add"] && ![command isEqualToString:@"move"] &&
		![command isEqualToString:@"resolved"] )
		addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];

	id additionalTaskInfo = makeTaskInfo([@"svn " stringByAppendingString: command], taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) moveMultiple:   (NSArray*)      files
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	#pragma unused(generalOptions)
	NSString *taskLaunchPath		= ShellScriptPath(@"svnmove");
	NSMutableArray *arguments       = [NSMutableArray arrayWithObject: SvnCmdPath()];
	
	[arguments addObject: [options componentsJoinedByString:@" "]]; // see svnmove.sh
	[arguments addObject: destinationPath]; // see svnmove.sh
	[arguments addObjectsFromArray:files];

	id additionalTaskInfo = makeTaskInfo(@"svn move multiple", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) copyMultiple:  (NSArray*)      files
						 destination:   (NSString*)     destinationPath
						 generalOptions:(NSInvocation*) generalOptions
						 options:       (NSArray*)      options
						 callback:      (NSInvocation*) callback
						 callbackInfo:  (id)            callbackInfo
						 taskInfo:      (id)            taskInfo
{
	#pragma unused(generalOptions)
	NSString *taskLaunchPath		= ShellScriptPath(@"svncopy");
	NSMutableArray *arguments       = [NSMutableArray arrayWithObject: SvnCmdPath()];

	[arguments addObject: [options componentsJoinedByString:@" "]]; // see svncopy.sh
	[arguments addObject: destinationPath]; // see svncopy.sh
	[arguments addObjectsFromArray:files];

	id additionalTaskInfo = makeTaskInfo(@"svn copy multiple", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) log:            (NSString*)     path
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];
	
	[arguments			 addObject: @"log"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: path];	

	id additionalTaskInfo = makeTaskInfo(@"svn log", taskLaunchPath, arguments);
//	[additionalTaskInfo setObject: kNSTrue forKey: @"outputToData"];

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: YES];
}


+ (NSMutableDictionary*) list:           (NSString*)     path
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];
	
	[arguments			 addObject: @"list"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: path];	

	id additionalTaskInfo = makeTaskInfo(@"svn list", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: YES];
}


+ (NSMutableDictionary*) statusAtWorkingCopyPath: (NSString*)     path
						 generalOptions:          (NSInvocation*) generalOptions
						 options:                 (NSArray*)      options
						 callback:                (NSInvocation*) callback
						 callbackInfo:            (id)            callbackInfo
						 taskInfo:                (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];
	
	[arguments			 addObject: @"status"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: path];	

	id additionalTaskInfo = makeTaskInfo(@"svn status", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) updateAtWorkingCopyPath: (NSString*)     path
						 generalOptions:          (NSInvocation*) generalOptions
						 options:                 (NSArray*)      options
						 callback:                (NSInvocation*) callback
						 callbackInfo:            (id)            callbackInfo
						 taskInfo:                (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];
	
	[arguments			 addObject: @"update"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: path];	

	id additionalTaskInfo = makeTaskInfo(@"svn update", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) checkout:       (NSString*)     file
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"checkout"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: file];	
	[arguments			 addObject: destinationPath];	

	id additionalTaskInfo = makeTaskInfo(@"svn checkout", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) extractItems:   (NSArray*)      items
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= ShellScriptPath(@"svnextract");
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments           addObject: SvnCmdPath()];
	[arguments           addObject: concatOptions(generalOptions, options)];
	[arguments addObjectsFromArray: items];	

	id additionalTaskInfo = makeTaskInfo(@"extract", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) import:         (NSString*)     file
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"import"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: file];	
	[arguments			 addObject: destinationPath];	

	id additionalTaskInfo = makeTaskInfo(@"svn import", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) copy:           (NSString*)     file
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"copy"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: file];	
	[arguments			 addObject: destinationPath];	

	id additionalTaskInfo = makeTaskInfo(@"svn copy", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) move:           (NSString*)     file
						 destination:    (NSString*)     destinationPath
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"move"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: file];	
	[arguments			 addObject: destinationPath];	

	id additionalTaskInfo = makeTaskInfo(@"svn move", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) mkdir:          (NSArray*)      files
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"mkdir"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments addObjectsFromArray: files];	

	id additionalTaskInfo = makeTaskInfo(@"svn mkdir", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


+ (NSMutableDictionary*) delete:         (NSArray*)      files
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSString *taskLaunchPath		= SvnCmdPath();
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"delete"];
	addGeneralOptions(arguments, generalOptions);
	[arguments addObjectsFromArray: options];
	[arguments addObjectsFromArray: files];	

	id additionalTaskInfo = makeTaskInfo(@"svn delete", taskLaunchPath, arguments);

	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


//----------------------------------------------------------------------------------------

+ (NSMutableDictionary*) blame:          (NSArray*)      files
						 revision:       (NSString*)     revision
						 generalOptions: (NSInvocation*) generalOptions
						 options:        (NSArray*)      options
						 callback:       (NSInvocation*) callback
						 callbackInfo:   (id)            callbackInfo
						 taskInfo:       (id)            taskInfo
{
	NSMutableArray* arguments = [NSMutableArray arrayWithObjects:
						SvnCmdPath(), GetDiffAppName(), revision, concatOptions(generalOptions, options), nil];
	[arguments addObjectsFromArray: files];

	NSString* taskLaunchPath = ShellScriptPath(@"svnblame");
	id additionalTaskInfo = makeTaskInfo(@"svn blame", taskLaunchPath, arguments);

	// svnblame.sh <svn-tool> <diff-app> <revision> <options> <url...>
	return [MySvn launchTask: taskLaunchPath arguments: arguments callback: callback callbackInfo: callbackInfo
				  taskInfo: taskInfo additionalTaskInfo: additionalTaskInfo outputToData: NO];
}


//----------------------------------------------------------------------------------------
#pragma mark	-
#pragma mark	Helpers
//----------------------------------------------------------------------------------------

static NSDictionary*
ensureDict (NSDictionary* dictOrNil)
{
	return dictOrNil ? dictOrNil : [NSDictionary dictionary];
}


+ (NSArray*) optionsFromSvnOptionsInvocation: (NSInvocation*) invocation
{
	NSMutableDictionary *dic;
	[invocation invoke];
	[invocation getReturnValue:&dic];
	
	NSMutableArray *arr = [NSMutableArray array];
	NSString *username = [dic objectForKey:@"user"];
	NSString *password = [dic objectForKey:@"pass"];
	
	if ([username length])
	{
		[arr addObject:@"--username"];
		[arr addObject:username];

		if ([password length])
		{
			[arr addObject:@"--password"];
			[arr addObject:password];		
		}
	}

	[arr addObject:@"--non-interactive"];
		
	return arr;
}


//----------------------------------------------------------------------------------------

+ (NSMutableDictionary*) launchTask:         (NSString*)     taskLaunchPath
						 arguments:          (NSArray*)      arguments
						 callback:           (NSInvocation*) callback
						 callbackInfo:       (id)            callbackInfo
						 taskInfo:           (id)            taskInfo
						 additionalTaskInfo: (id)            additionalTaskInfo
						 outputToData:       (BOOL)          outputToData
{
//	NSLog(@"launchTask: '%@' arguments=%@", taskLaunchPath, arguments);
	NSTask* task = [[NSTask alloc] init];
	NSPipe* pipe = [[NSPipe alloc] init];
	NSPipe* errorPipe = [[NSPipe alloc] init];

	[task setEnvironment: [Task createEnvironment: TRUE]];	
	[task setLaunchPath: taskLaunchPath];
	[task setArguments: arguments];

	[task setStandardOutput: pipe];
	[task setStandardError: errorPipe];
	NSFileHandle* handle      = [pipe      fileHandleForReading];
	NSFileHandle* errorHandle = [errorPipe fileHandleForReading];

	// this will be done by Tasks
//	[task launch]; 

	NSMutableDictionary *taskObj = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								@"pending",											@"status",
								task,												@"task",
								handle,												@"handle",
								errorHandle,										@"errorHandle",
						//		[NSNumber numberWithInt:[task processIdentifier]],	@"pid",
								callback,											@"callback",
								ensureDict(callbackInfo),							@"callbackInfo",
								ensureDict(taskInfo),								@"taskInfo",
								ensureDict(additionalTaskInfo),						@"additionalTaskInfo",
								NSBool(outputToData),								@"outputToData",
								nil];

	[errorPipe release];
	[pipe release];
	[task release];

	[[NSApp delegate] newTaskWithDictionary: taskObj];

	return taskObj;
}


//----------------------------------------------------------------------------------------
#pragma mark -
//----------------------------------------------------------------------------------------

+ (void) killTask: (NSDictionary*) taskObj
			force: (BOOL)          force
{
	NSTask* const task = [taskObj objectForKey: @"task"];
//	dprintf("task=%@ force=%d taskObj=%@", task, force, [taskObj objectForKey: @"pid"]);
//	dprintf("task=%@ force=%d", task, force);
	AssertClass(task, NSTask);

	if ([task isRunning])
	{
		if (force)		// Use kill -9 to kill.
		{
			pid_t pid = [task processIdentifier];
			if (kill(pid, SIGKILL))
				dprintf("kill(%d) => errno=%d", pid, errno);
		}
		else
		{
			[task terminate];
		}
	}
}


//----------------------------------------------------------------------------------------

enum {
	kCacheMaxSize				=	400,
	kCacheMinAge				=	3600 * 8,	// seconds
	kCacheMaxDeletableFileSize	=	32 * 1024,	// bytes
	kCacheDeleteCount			=	8
};


//----------------------------------------------------------------------------------------
// Try to delete up to kCacheDeleteCount entries & their files.
// Called if adding an entry to the cache with grow it past kCacheMaxSize.
// Only delete entries older than kCacheMinAge that have no file or whose size is <= kCacheMaxDeletableFileSize.
// Deletes the least recently accessed entries first.

static void
removeOldEntries (NSMutableDictionary* cacheDict, NSString* cacheDir,
				  NSFileManager* fileMgr, CFAbsoluteTime now)
{
	struct Desc
	{
		CFAbsoluteTime	time;
		id				key;
		id				path;
	};
	typedef struct Desc Desc;
	int count = 0, i;
	Desc descs[kCacheDeleteCount + 1];

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	CFAbsoluteTime time0 = now - kCacheMinAge;
	id key, fattrs;
	NSEnumerator* enumerator = [cacheDict keyEnumerator];
	while ((key = [enumerator nextObject]))
	{
		NSDictionary* cacheEntry = [cacheDict objectForKey: key];
		CFAbsoluteTime time = [[cacheEntry objectForKey: @"time"] doubleValue];
		if (time < time0)
		{
			NSString* path = [cacheDir stringByAppendingPathComponent:
											[cacheEntry objectForKey: @"name"]];
			if ((fattrs = [fileMgr fileAttributesAtPath: path traverseLink: NO]) == nil ||
				[fattrs fileSize] <= kCacheMaxDeletableFileSize)
			{
				const Desc d = { time, key, fattrs ? path : nil };
				descs[count] = d;
				for (i = count - 1; i >= 0; --i)
				{
					if (time >= descs[i].time)
						break;
					descs[i + 1] = descs[i];
					descs[i] = d;
				}

				if (count < kCacheDeleteCount)
					++count;
				else
					time0 = descs[kCacheDeleteCount - 1].time;
			}
		}
	}

//	NSLog(@"removeOldEntries: count=%d", count);
	for (i = 0; i < count; ++i)
	{
		Desc* d = &descs[i];
		if (d->path)
			if (![fileMgr removeFileAtPath: d->path handler: nil])
				continue;
		[cacheDict removeObjectForKey: d->key];
//		NSLog(@"\n    %f '%@'", d->time, d->key);
	}

	[pool release];
}


//----------------------------------------------------------------------------------------

+ (NSString*) cachePathForKey: (NSString*) key
{
	static NSMutableDictionary* cacheDict;	// this dictionary contains the cache
	static NSString* cacheDir;				// the path to the cache directory
	static unsigned int nextIndex = 0;

	NSFileManager* const fileMgr = [NSFileManager defaultManager];
	NSUserDefaults* const prefs = [NSUserDefaults standardUserDefaults];
	if (cacheDict == nil)
	{
		id obj = [prefs dictionaryForKey: @"cacheFilesDict"];
		cacheDict = obj ? [obj mutableCopyWithZone: nil] : [[NSMutableDictionary alloc] init];

		if ((obj = [prefs objectForKey: @"cacheNextIndex"]))
			nextIndex = [obj unsignedIntValue];
	}

	// Find or create the cache directory
	if (cacheDir == nil)
	{
		NSArray* libraryDirectories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, TRUE);
		NSString* cachesFolder = [libraryDirectories objectAtIndex: 0];
		cacheDir = [cachesFolder stringByAppendingPathComponent: [[NSBundle mainBundle] bundleIdentifier]];
		[cacheDir retain];

		BOOL isDir;
		if ([fileMgr fileExistsAtPath: cacheDir isDirectory: &isDir])
		{
			if (!isDir)
				return nil;
		}
		else	// create directory
		{
			if (![fileMgr createDirectoryAtPath: cacheDir attributes: nil])
				return nil;
		}
	}

	NSString* name = nil;
	NSDictionary* cacheEntry = [cacheDict objectForKey: key];
	if (cacheEntry)
	{
		name = [cacheEntry objectForKey: @"name"];
	}

	const CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
	if (name == nil)
	{
		const unichar kCacheFormat = 'A';		// cache format 'A'

		do {
			name = [NSString stringWithFormat: @"%C%09u.cache", kCacheFormat, nextIndex++];
		}
		while ([fileMgr fileExistsAtPath: [cacheDir stringByAppendingPathComponent: name]]);
	}

	if (cacheEntry == nil && [cacheDict count] >= kCacheMaxSize)
		removeOldEntries(cacheDict, cacheDir, fileMgr, now);

	cacheEntry = [NSDictionary dictionaryWithObjectsAndKeys: name, @"name",
															 [NSNumber numberWithDouble: now], @"time",
															 nil];
	[cacheDict setValue: cacheEntry forKey: key];
	[prefs setObject: cacheDict forKey: @"cacheFilesDict"];
	[prefs setObject: [NSNumber numberWithUnsignedInt: nextIndex] forKey: @"cacheNextIndex"];
	[prefs synchronize];

	NSString* resultString = [cacheDir stringByAppendingPathComponent: name];

//	NSLog(@"cacheDict=%@", cacheDict);
//	NSLog(@"cachePathForKey('%@') => '%@'", key, name);
	return resultString;
}


@end

