/* RepositoriesController */

#import <Cocoa/Cocoa.h>
#import "EditListResponder.h"

@interface RepositoriesController : EditListResponder
{
}

- (void) openRepositoryBrowser: (NSString*) url
		 title:                 (NSString*) title
		 user:                  (NSString*) user
		 pass:                  (NSString*) pass;

- (void) openRepository: (NSString*) url;

@end

