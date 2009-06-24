
#import "SvnFileStatusToColourTransformer.h"
#import "CommonUtils.h"


typedef enum { kColorModified = 0, kColorNew, kColorMissing, kColorConflict } FileStatusColor;

static NSColor* gColors[4] = { nil };
static NSString* const gKeys[4] = {
	@"svnFileStatusModifiedColor",
	@"svnFileStatusNewColor",
	@"svnFileStatusMissingColor",
	@"svnFileStatusConflictColor"
};


//----------------------------------------------------------------------------------------

@implementation SvnFileStatusToColourTransformer


//----------------------------------------------------------------------------------------

+ (void) initColor: (FileStatusColor)      index
			 color: (NSColor*)             color
			 prefs: (NSMutableDictionary*) prefs
{
	NSString* const key = gKeys[index];
	[prefs setObject: [NSArchiver archivedDataWithRootObject: color] forKey: key];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver: self
		 forKeyPath:  [@"values." stringByAppendingString: key]
		 options:     NSKeyValueObservingOptionNew
		 context:     (void*) index];
	gColors[index] = [color retain];
}


//----------------------------------------------------------------------------------------

+ (void) initialize: (NSMutableDictionary*) prefs
{
	[self initColor: kColorModified color: [NSColor blackColor  ] prefs: prefs];
	[self initColor: kColorNew      color: [NSColor blueColor   ] prefs: prefs];
	[self initColor: kColorMissing  color: [NSColor redColor    ] prefs: prefs];
	[self initColor: kColorConflict color: [NSColor magentaColor] prefs: prefs];
}


//----------------------------------------------------------------------------------------

+ (void) update: (unsigned int) color
{
	Assert(color <= kColorConflict);
	id data = GetPreference(gKeys[color]);

	if ([data isKindOfClass: [NSData class]])
	{
		[gColors[color] release];
		gColors[color] = [[NSUnarchiver unarchiveObjectWithData: data] retain];
	}
}


//----------------------------------------------------------------------------------------

+ (void) update
{
	for (unsigned int color = kColorModified; color <= kColorConflict; ++color)
		[self update: color];
}


//----------------------------------------------------------------------------------------

+ (void) observeValueForKeyPath: (NSString*)     keyPath
		 ofObject:               (id)            object
		 change:                 (NSDictionary*) change
		 context:                (void*)         context
{
	#pragma unused(keyPath, object, change)
	[self update: (unsigned int) context];
}


//----------------------------------------------------------------------------------------

+ (Class) transformedValueClass
{
	return [NSColor class];
}


+ (BOOL) allowsReverseTransformation
{
	return NO;
}


- (id) transformedValue: (id) aString
{
	if ([aString length] == 1)
	{
		switch ([aString characterAtIndex: 0])
		{
			case 'M':	return gColors[kColorModified];
			case '?':	return gColors[kColorNew];
			case '!':	return gColors[kColorMissing];
			case 'C':	return gColors[kColorConflict];
		}
	}

	return [NSColor blackColor];
}


@end

