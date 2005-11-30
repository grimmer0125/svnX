
#import <Foundation/Foundation.h>

@class MyRepository;

@interface MyRepositoryToolbar : NSObject
{

    NSToolbar *toolbar;
    IBOutlet id window;
    IBOutlet MyRepository *document;
	
    NSMutableDictionary *items; // all items that are allowed to be in the toolbar
}

@end
