//----------------------------------------------------------------------------------------
//	IconUtils.m - Common icon utilities
//
//	Copyright © Chris, 2003 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#import "IconUtils.h"
#import "NSString+MyAdditions.h"


//----------------------------------------------------------------------------------------

static IconRef gIconFolder = NULL,
			   gIconFile   = NULL,
			   gIconRepo   = NULL,
			   gIconWC     = NULL;
static CFMutableDictionaryRef gCache = NULL;


//----------------------------------------------------------------------------------------

static NSImage*
getImageForIcon (IconRef iconRef, const NSRect* rect)
{
	Assert(iconRef);

	NSImage* image = [[NSImage alloc] initWithSize: rect->size];
	[image lockFocus];
	CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
//	CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
	WarnIf(PlotIconRefInContext(ctx, (CGRect*) rect, kAlignNone, kTransformNone,
								NULL, kPlotIconRefNormalFlags, iconRef));
	[image unlockFocus];

	return image;
}


//----------------------------------------------------------------------------------------

static NSImage*
getImageForIconType (OSType iconType, GCoord size)
{
	IconRef iconRef;
	if (WarnIf(GetIconRef(kOnSystemDisk, kSystemIconsCreator, iconType, &iconRef)) == noErr)
	{
		NSImage* image = ImageFromIcon(iconRef, size);
		WarnIf(ReleaseIconRef(iconRef));
		return image;
	}

	return nil;
}


//----------------------------------------------------------------------------------------

static NSImage*
setImageForIconType (NSString* name, OSType iconType)
{
	NSImage* image = getImageForIconType(iconType, 32);
	if (image == nil || ![image setName: name])
		dprintf("WARNING: init image '%@' FAILED", name);

	return image;
}


//----------------------------------------------------------------------------------------

static void
loadIcon (IconRef* iconRef, NSString* name, OSType iconType, IconRef defaultIcon)
{
	name = [[NSBundle mainBundle] pathForResource: name ofType: @"icns"];
	FSRef fsRef;
	char path[2048];
	Boolean isDirectory;
	if (!ToUTF8(name, path, sizeof(path)) ||
			WarnIf(FSPathMakeRef((const UInt8*) path, &fsRef, &isDirectory)) ||
			WarnIf(RegisterIconRefFromFSRef('svnX', iconType, &fsRef, iconRef)))
		*iconRef = defaultIcon;
}


//----------------------------------------------------------------------------------------

static inline void
initIcon (IconRef* iconRef, OSType iconType)
{
	WarnIf(GetIconRef(kOnSystemDisk, kSystemIconsCreator, iconType, iconRef));
}


//----------------------------------------------------------------------------------------

static inline void
retain (IconRef iconRef)
{
	if (iconRef != NULL)
		WarnIf(AcquireIconRef(iconRef));
}


//----------------------------------------------------------------------------------------

static inline void
release (IconRef iconRef)
{
	if (iconRef != NULL)
		WarnIf(ReleaseIconRef(iconRef));
}


//----------------------------------------------------------------------------------------

static void
releaseIconRef (CFAllocatorRef allocator, const void* value)
{
	#pragma unused(allocator)
	release((IconRef) value);
}


//----------------------------------------------------------------------------------------

static double
nanoseconds (UInt64 t)
{
	Nanoseconds ns = AbsoluteToNanoseconds(*(AbsoluteTime*) &t);
	return *(SInt64*) &ns;
}


//----------------------------------------------------------------------------------------
#pragma mark	-
//----------------------------------------------------------------------------------------

void
InitIconCache ()
{
	if (gIconFolder == NULL)	// do only once
	{
		initIcon(&gIconFolder, kGenericFolderIcon);
		initIcon(&gIconFile, kGenericDocumentIcon);
		loadIcon(&gIconRepo, @"Repository", 'Repo', gIconFolder);
		
		IconRef badge;
	//	WarnIf(GetIconRef(kOnAppropriateDisk, 'svnX', 'APPL', &badge));
		loadIcon(&badge, @"svnBadge", 'APPL', NULL);
		WarnIf(CompositeIconRef(gIconFolder, badge, &gIconWC));

		// Named icons
		if (![ImageFromIcon(gIconFolder, 32) setName: @"FolderRef"])
			dprintf("WARNING: init image 'FolderRef' FAILED");
		setImageForIconType(@"Finder", kFinderIcon);
		setImageForIconType(@"delete", kToolbarDeleteIcon);
		NSImage* image = setImageForIconType(@"mkdir", kGenericFolderIcon);
		[image lockFocus];
		[[NSImage imageNamed: @"PlusTopRight"] compositeToPoint: NSZeroPoint
													  operation: NSCompositeSourceOver];
		[image unlockFocus];

		// Cache
		const CFDictionaryValueCallBacks valueCallBacks = {
			0, NULL, &releaseIconRef, NULL, NULL
		};
		gCache = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
										   &kCFTypeDictionaryKeyCallBacks,
										   &valueCallBacks);
		CFDictionaryAddValue(gCache, @"", gIconFile);
		retain(gIconFile);
	}
}


//----------------------------------------------------------------------------------------

IconRef
GetFileIcon (ConstCStr path, Boolean* isDirectory)
{
	IconRef iconRef = NULL;
	FSRef fsRef;
	if (WarnIfNot(FSPathMakeRef((const UInt8*) path, &fsRef, isDirectory), fnfErr) == noErr)
		WarnIf(GetIconRefFromFileInfo(&fsRef, 0, NULL,
									  kFSCatInfoNone, NULL,
									  kIconServicesNormalUsageFlag, &iconRef, NULL));

	if (iconRef == NULL)
		retain(iconRef = *isDirectory ? gIconFolder : gIconFile);

	return iconRef;
}


//----------------------------------------------------------------------------------------
// Try to get the icon for the specified path.
// If we can't then use isDirectory & name's file extension.
// Returns a retained IconRef.

IconRef
GetFileOrTypeIcon (ConstCStr path, NSString* name, Boolean* isDirectory)
{
	IconRef iconRef = NULL;
	FSRef fsRef;
	if (WarnIfNot(FSPathMakeRef((const UInt8*) path, &fsRef, isDirectory), fnfErr) == noErr)
		WarnIf(GetIconRefFromFileInfo(&fsRef, 0, NULL,
									  kFSCatInfoNone, NULL,
									  kIconServicesNormalUsageFlag, &iconRef, NULL));

	if (iconRef == NULL)
		retain(iconRef = *isDirectory ? gIconFolder
									  : GetFileTypeIcon([name pathExtension]));

	return iconRef;
}


//----------------------------------------------------------------------------------------

IconRef
GenericFolderIcon ()
{
	Assert(gIconFolder);
	return gIconFolder;
}


//----------------------------------------------------------------------------------------

IconRef
GenericFileIcon ()
{
	Assert(gIconFile);
	return gIconFile;
}


//----------------------------------------------------------------------------------------

IconRef
RepositoryIcon ()
{
	Assert(gIconRepo);
	return gIconRepo;
}


//----------------------------------------------------------------------------------------

IconRef
WorkingCopyIcon ()
{
	Assert(gIconWC);
	return gIconWC;
}


//----------------------------------------------------------------------------------------

IconRef
GetFileTypeIcon (NSString* fileType)
{
	Assert(fileType != nil);
	Assert(gCache != NULL);

	IconRef iconRef = (IconRef) CFDictionaryGetValue(gCache, fileType);

	if (iconRef == NULL)
	{
		WarnIf(GetIconRefFromTypeInfo(0, 0, (CFStringRef) fileType, NULL,
									  kIconServicesNormalUsageFlag, &iconRef));
		if (iconRef == NULL)
			retain(iconRef = gIconFile);
		CFDictionarySetValue(gCache, fileType, iconRef);
	}

	return iconRef;
}


//----------------------------------------------------------------------------------------

NSImage*
ImageFromIcon (IconRef iconRef, GCoord size)
{
	const NSRect rect = { 0, 0, size, size };

	return getImageForIcon(iconRef, &rect);
}


//----------------------------------------------------------------------------------------
// End of IconUtils.m
