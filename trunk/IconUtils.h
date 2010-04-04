//----------------------------------------------------------------------------------------
//	IconUtils.h - Common icon utilities
//
//	Copyright © Chris, 2003 - 2010.  All rights reserved.
//----------------------------------------------------------------------------------------

#pragma once

#import <Foundation/Foundation.h>
//#import <HIServices/HIServices.h>
#import "CommonUtils.h"


//----------------------------------------------------------------------------------------

void		InitIconCache			(void);
IconRef		GenericFolderIcon		(void);
IconRef		GenericFileIcon			(void);
IconRef		RepositoryIcon			(void);
IconRef		WorkingCopyIcon			(void);
IconRef		GetFileIcon				(ConstCStr path, Boolean* isDirectory);
IconRef		GetFileOrTypeIcon		(ConstCStr path, NSString* name, Boolean* isDirectory);
IconRef		GetFileTypeIcon			(NSString* fileType);
NSImage*	ImageFromIcon			(IconRef iconRef, GCoord size);


//----------------------------------------------------------------------------------------
// End of IconUtils.h
