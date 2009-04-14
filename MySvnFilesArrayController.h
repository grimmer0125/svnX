/* MySvnFilesArrayController */

#import <Cocoa/Cocoa.h>

@class MyWorkingCopy;

/*" ArrayController that holds the files of the WorkingCopy "*/

@interface MySvnFilesArrayController : NSArrayController
{
	NSString*				searchString;

	IBOutlet MyWorkingCopy*	document;
	BOOL					committable;
}

- (void)      search: (id) sender;
- (NSString*) searchString;
- (void)      setSearchString: (NSString*) newSearchString;
- (BOOL)      committable;
- (void)      setCommittable: (BOOL) isCommittable;

@end
