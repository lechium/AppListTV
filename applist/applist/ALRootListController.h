#import <TVSettingKit/TVSettingKit.h>


@interface ALRootListController : TSKViewController
+ (NSArray *)standardSectionDescriptors;
@property (nonatomic, strong) NSDictionary *specifier;
@property (nonatomic, copy) NSArray *sectionDescriptors;
@end


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

//tvOS specific
extern const NSString *ALItemSupportsLongPress;
extern const NSString *ALAllProcessesMode;
extern const NSString *ALUseBundleIdentifier;
