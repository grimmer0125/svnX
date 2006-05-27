#import "MySVN.h"

@implementation MySvn


#pragma mark New-style svn calls (>=0.8)

+(NSMutableDictionary *)fileMergeItems:(NSArray *)itemsPaths generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [MySvn bundleScriptPath:@"svnfilemerge.sh"];
	NSMutableArray *arguments       = [NSMutableArray array];

	// 0: FileMerge, 1: TextWrangler, 2: CodeWarrior, 3: BBEdit
	int defaultSvnApplicationIndex = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"defaultDiffApplication"] intValue];
	
	[arguments			 addObject: [[MySvn svnPath] stringByAppendingPathComponent:@"svn"]];
	[arguments			 addObject: [MySvn bundleScriptPath:@"svndiff.sh"]];
	[arguments			 addObject: [NSString stringWithFormat:@"%d", defaultSvnApplicationIndex]];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments addObjectsFromArray: itemsPaths];

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"FileMerge" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)genericCommand:(NSString *)command arguments:(NSArray *)args generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray arrayWithObject:command];
	
	[arguments addObjectsFromArray: args];

	if ( ![command isEqualToString:@"info"] && ![command isEqualToString:@"revert"] && ![command isEqualToString:@"add"] && ![command isEqualToString:@"move"] && ![command isEqualToString:@"resolved"] )
		[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"svn %@", command] forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)moveMultiple:(NSArray *)files destination:(NSString *)destinationPath generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [MySvn bundleScriptPath:@"svnmove.sh"];
	NSMutableArray *arguments       = [NSMutableArray arrayWithObject:[[MySvn svnPath] stringByAppendingPathComponent:@"svn"]];
	
	[arguments addObject: [options componentsJoinedByString:@" "]]; // see svnmove.sh
	[arguments addObject: destinationPath]; // see svnmove.sh
//	[arguments addObject: [self joinedOptions:[self optionsFromSvnOptionsInvocation:generalOptions] andOptions:options]]; // see svnmove.sh
	[arguments addObjectsFromArray:files];

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn move multiple" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)copyMultiple:(NSArray *)files destination:(NSString *)destinationPath generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [MySvn bundleScriptPath:@"svncopy.sh"];
	NSMutableArray *arguments       = [NSMutableArray arrayWithObject:[[MySvn svnPath] stringByAppendingPathComponent:@"svn"]];

//	[arguments addObject: [self joinedOptions:[self optionsFromSvnOptionsInvocation:generalOptions] andOptions:options]]; // see svncopy.sh
	[arguments addObject: [options componentsJoinedByString:@" "]]; // see svnmove.sh
	[arguments addObject: destinationPath]; // see svnmove.sh
	[arguments addObjectsFromArray:files];

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn copy multiple" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)log:(NSString *)path generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];
	
	[arguments			 addObject: @"log"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: path];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn log" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)list:(NSString *)path generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];
	
	[arguments			 addObject: @"list"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: path];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn list" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)statusAtWorkingCopyPath:(NSString *)path generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];
	
	[arguments			 addObject: @"status"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: path];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn status" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)updateAtWorkingCopyPath:(NSString *)path generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];
	
	[arguments			 addObject: @"update"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: path];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn update" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)checkout:(NSString *)file destination:(NSString *)destinationPath generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"checkout"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: file];	
	[arguments			 addObject: destinationPath];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn checkout" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)extractItems:(NSArray *)items generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [MySvn bundleScriptPath:@"svnextract.sh"];
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: [[MySvn svnPath] stringByAppendingPathComponent:@"svn"]];
	
	[arguments addObject: [self joinedOptions:[self optionsFromSvnOptionsInvocation:generalOptions] andOptions:options]]; // see svnextract.sh
	[arguments addObjectsFromArray: items];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"extract" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)import:(NSString *)file destination:(NSString *)destinationPath generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"import"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: file];	
	[arguments			 addObject: destinationPath];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn import" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)copy:(NSString *)file destination:(NSString *)destinationPath generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"copy"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: file];	
	[arguments			 addObject: destinationPath];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn copy" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)move:(NSString *)file destination:(NSString *)destinationPath generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"move"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments			 addObject: file];	
	[arguments			 addObject: destinationPath];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn move" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)mkdir:(NSArray *)files generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"mkdir"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments addObjectsFromArray: files];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn mkdir" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

+(NSMutableDictionary *)delete:(NSArray *)files generalOptions:(NSInvocation *)generalOptions options:(NSArray *)options callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo
{
	NSString *taskLaunchPath		= [[MySvn svnPath] stringByAppendingPathComponent:@"svn"];
	NSMutableArray *arguments       = [NSMutableArray array];

	[arguments			 addObject: @"delete"];
	[arguments addObjectsFromArray: [self optionsFromSvnOptionsInvocation:generalOptions]];
	[arguments addObjectsFromArray: options];
	[arguments addObjectsFromArray: files];	

	NSMutableDictionary *additionalTaskInfo = [NSMutableDictionary dictionary];
	[additionalTaskInfo setObject:@"svn delete" forKey:@"name"];
	[additionalTaskInfo setObject:[NSString stringWithFormat:@"%@ %@", taskLaunchPath, [arguments componentsJoinedByString:@" "]] forKey:@"command"];
	
	return [MySvn launchTask:taskLaunchPath arguments:arguments callback:callback callbackInfo:callbackInfo taskInfo:taskInfo additionalTaskInfo:additionalTaskInfo];
}

#pragma mark -
#pragma mark Helpers

+(NSArray *)optionsFromSvnOptionsInvocation:(NSInvocation *)invocation
{
	NSMutableDictionary *dic;
	[invocation invoke];
	[invocation getReturnValue:&dic];
	
	NSMutableArray *arr = [NSMutableArray array];
	NSString *username = [dic objectForKey:@"user"];
	NSString *password = [dic objectForKey:@"pass"];
	
	if ( username != nil && ![username isEqualToString:@""]  )
	{
		[arr addObject:@"--username"];
		[arr addObject:username];

		if ( password != nil && ![password isEqualToString:@""] )
		{
			[arr addObject:@"--password"];
			[arr addObject:password];		
		}
	}

	[arr addObject:@"--non-interactive"];
		
	return arr;
}

+(NSString *)joinedOptions:(NSArray *)options1 andOptions:(NSArray *)options2
{
	return [NSString stringWithFormat:@"%@ %@", [options1 componentsJoinedByString:@" "], [options2 componentsJoinedByString:@" "]];
}

+(NSMutableDictionary *)launchTask:(NSString *)taskLaunchPath arguments:(NSArray *)arguments callback:(NSInvocation *)callback callbackInfo:(id)callbackInfo taskInfo:(id)taskInfo additionalTaskInfo:(id)additionalTaskInfo
{
	NSTask *task=[[NSTask alloc] init];
    NSPipe *pipe=[[NSPipe alloc] init];
    NSPipe *errorPipe = [[NSPipe alloc] init];
    NSFileHandle *handle;
    NSFileHandle *errorHandle;

	NSDictionary *defaultEnvironment = [[NSProcessInfo processInfo] environment];
    NSMutableDictionary *environment = [[NSMutableDictionary alloc] initWithDictionary:defaultEnvironment];

    [environment setObject:@"YES" forKey:@"NSUnbufferedIO"];
    [environment setObject:@"en_US.UTF-8" forKey:@"LC_CTYPE"];
    [environment setObject:@"en_US.UTF-8" forKey:@"LANG"];
    [task setEnvironment:environment];	

	[task setLaunchPath:taskLaunchPath];
    [task setArguments:arguments];

    [task setStandardOutput:pipe];
    [task setStandardError:errorPipe];
    handle=[pipe fileHandleForReading];
    errorHandle=[errorPipe fileHandleForReading];
    
	// this will be done by Tasks
//    [task launch]; 

	NSMutableDictionary *taskObj = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								@"pending", @"status",
								task, @"task",
								handle, @"handle",
								errorHandle, @"errorHandle",
								[NSNumber numberWithInt:[task processIdentifier]], @"pid",
								callback, @"callback",
								((callbackInfo==nil)?[NSDictionary dictionary]:callbackInfo), @"callbackInfo",
								((taskInfo==nil)?[NSDictionary dictionary]:taskInfo), @"taskInfo",
								((additionalTaskInfo==nil)?[NSDictionary dictionary]:additionalTaskInfo), @"additionalTaskInfo",
								nil];
								
	[[NSApp delegate] newTaskWithDictionary:taskObj];

    [errorPipe release];
    [pipe release];
    [task release];
	
	return taskObj;
}

#pragma mark -

+(void)killProcess:(int)pid
{
	NSTask *task=[[NSTask alloc] init];
    NSPipe *pipe=[[NSPipe alloc] init];
    NSPipe *errorPipe = [[NSPipe alloc] init];

    NSFileHandle *handle;
    NSFileHandle *errorHandle;

	
	[task setLaunchPath:@"/bin/kill"];
	[task setArguments:[NSArray arrayWithObjects:@"-9", [NSString stringWithFormat:@"%d", pid], nil]];

    [task setStandardOutput:pipe];
    [task setStandardError:errorPipe];

    handle=[pipe fileHandleForReading];
    errorHandle=[errorPipe fileHandleForReading];
    
    [task launch];
    
    [errorPipe release];
    [pipe release];
    [task release];

}

+ (NSString *)cachePathForUrl:(NSURL *)url;
{
	return [self cachePathForUrl:url revision:nil];
}


/*
+ (NSString *)cachePathForUrl:(NSURL *)url revision:(NSString *)revision;
Uses a php script (hmm, yeah, I know... ) to create a path where to store cached information.
This is used by the repository browser to cache the previously retrieved logs and visited directories.
*/
+ (NSString *)cachePathForUrl:(NSURL *)url revision:(NSString *)revision;
{
	static NSMutableDictionary *cacheDict; // this dictionary will cache the results of this method to avoid repetitive calls to the php script
	
	if ( cacheDict == nil )
	{
		cacheDict = [[NSMutableDictionary alloc] init];
	
	}
	
	NSString *key = [NSString stringWithFormat:@"%@::%@", [url absoluteString], revision];
	NSString *resultString;
		
	if ( resultString = [cacheDict objectForKey:key] )
	{
		return resultString;
	
	} else
	{
		NSArray *libraryDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask,  FALSE);
		
		NSString *cachesFolder= [[[libraryDirectories objectAtIndex: 0 ] stringByAppendingPathComponent:@"/Caches"] stringByExpandingTildeInPath];
		NSString *resultString;

		NSTask *aTask=[[NSTask alloc] init];
		NSPipe *pipe=[[NSPipe alloc] init];
		NSPipe *errorPipe = [[NSPipe alloc] init];
		
		NSFileHandle *handle;
		NSFileHandle *errorHandle;

		NSArray *argumentsArray;

		
		if ( revision == nil )
		{	
			argumentsArray = [NSArray arrayWithObjects:cachesFolder, [url absoluteString], nil]; // see getCachePathForUrl.php

		} else
		{
			argumentsArray = [NSArray arrayWithObjects:cachesFolder, [url absoluteString], revision, nil]; // see getCachePathForUrl.php
		}
		
		//NSLog(@"fetching %@", [url absoluteString]);
		
		[aTask setLaunchPath:[MySvn bundleScriptPath:@"getCachePathForUrl.php"]];
		
		[aTask setArguments:argumentsArray];
		[aTask setStandardOutput:pipe];
		[aTask setStandardError:errorPipe];
		
		handle = [pipe fileHandleForReading];
		errorHandle = [errorPipe fileHandleForReading];
		
		[aTask launch];
		[aTask waitUntilExit];
		resultString = [[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];

		[errorPipe release];
		[pipe release];
		[aTask release];
		
		[cacheDict setValue:resultString forKey:key];
		
		return resultString;
	}
}
// CLASS VARIABLES ACCESSORS
+ (NSString *)bundleScriptPath:(NSString *)script
{
		return [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"/Contents/Resources/" ]
								stringByAppendingPathComponent:script];
}
+ (NSString *)svnPath
{
    static NSString *svnPath;
	
	return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"svnBinariesFolder"];
}
+ (void) setSvnPath: (NSString *) aSvnPath
{
    static NSString *svnPath;

    id old = [self svnPath];
    svnPath = [aSvnPath retain];
    [old release];
}

@end
