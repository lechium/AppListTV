//#import "Common.h"
#import <TVSettingKit/TVSettingKit.h>

// Make sure our path is specified so our tweak knows where to store all of the settings :)
#define PLIST_PATH @"/var/mobile/Library/Preferences/com.nito.applist.plist"

//preferences interface notice that it is of Tyoe TSKViewController and not of PSListController!
@interface ALRootListController : TSKViewController
+ (NSArray *)standardSectionDescriptors;
@property (nonatomic, strong) NSDictionary *specifier;
@property (nonatomic, copy) NSArray *sectionDescriptors;
@end


// this is here so we can launch a task that "resprings" the Apple TV.
@interface NSTask : NSObject
@property (copy) NSArray *arguments;
@property (copy) NSString *currentDirectoryPath;
@property (copy) NSDictionary *environment;
@property (copy) NSString *launchPath;
@property (readonly) int processIdentifier;
@property (retain) id standardError;
@property (retain) id standardInput;
@property (retain) id standardOutput;
+ (id)currentTaskDictionary;
+ (id)launchedTaskWithDictionary:(id)arg1;
+ (id)launchedTaskWithLaunchPath:(id)arg1 arguments:(id)arg2;
- (id)init;
- (void)interrupt;
- (bool)isRunning;
- (void)launch;
- (bool)resume;
- (bool)suspend;
- (void)terminate;
@end

extern const NSString *ALSectionDescriptorTitleKey;
extern const NSString *ALSectionDescriptorFooterTitleKey;
extern const NSString *ALSectionDescriptorPredicateKey;
extern const NSString *ALSectionDescriptorCellClassNameKey;
extern const NSString *ALSectionDescriptorIconSizeKey;
extern const NSString *ALSectionDescriptorSuppressHiddenAppsKey;
extern const NSString *ALSectionDescriptorVisibilityPredicateKey;

extern const NSString *ALItemDescriptorTextKey;
extern const NSString *ALItemDescriptorDetailTextKey;
extern const NSString *ALItemDescriptorImageKey;
