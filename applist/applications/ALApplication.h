#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface LSApplicationProxy : NSObject
- (NSString *)bundleExecutable;

-(id)tv_applicationFlatIcon;
-(id)tv_supportedUserInterfaceStyles;
-(id)_tv_applicationIconName;
-(id)_tv_uncachedAssetManager;
-(id)_tv_cachedFlatApplicationIcon;
-(id)_tv_cachedSmallFlatApplicationIcon;
-(id)_tv_assetManager;

+(id)_tv_placeholderIconImage;
+(id)tv_placeholderLayeredIcon;
+(void)tv_initializeFlatIconCache;
+(void)tv_disableLSWorkspaceInstallHandling;
+(id)_tvsui_placeholderLayeredIconAtSystemScale;
+(id)_tvsui_placeholderIconImage;
+(id)tvsui_placeholderLayeredIcon;
+(void)tvsui_initializeFlatIconCache;
+(void)tvsui_disableLSWorkspaceInstallHandling;
-(NSArray *)appTags;
@property (nonatomic,readonly) BOOL iconIsPrerendered;
@property (nonatomic,readonly) BOOL iconUsesAssetCatalog;
@property (nonatomic,readonly) NSSet * claimedDocumentContentTypes;
@property (nonatomic,readonly) NSSet * claimedURLSchemes;
@end

//@class LSApplicationProxy;

@interface ALApplication : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *bundleID;
@property (nonatomic, strong) NSString *applicationType;
@property (nonatomic, strong) NSDictionary *infoDictionary;
@property (nonatomic, strong) NSDictionary *bundleVersion;
@property (nonatomic, strong) NSString *bundlePath;
@property (nonatomic, strong) NSString *binaryPath;
@property (readwrite, assign) BOOL isSetuid;
@property (readwrite, assign) BOOL hidden;
@property (readwrite, assign) NSInteger posixPerms;
@property (nonatomic, strong) NSArray *documentTypes;
@property (nonatomic, strong) NSArray *URLSchemes;
@property (nonatomic, strong) id proxy; //LSApplicationProxy

//applist compat
- (NSString *)displayName;
- (NSString *)displayIdentifier;

- (BOOL)hasIcon;
- (UIImage *)icon;
- (NSNumber *)installedSize;
- (NSNumber *)userDataSize;
- (instancetype)initWithProxy:(id)proxy;
- (pid_t)pid;
- (void)resetPid;
@end

