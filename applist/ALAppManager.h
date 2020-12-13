#import <Foundation/Foundation.h>
#import "ALApplication.h"
#import "ALRunningProcess.h"

@interface ALAppManager : NSObject
+ (id)sharedManager;
- (id)defaultWorkspace;
- (NSDictionary *)rawDaemonDetails;
- (void)setNeedsRefresh;
+ (int)killProcess:(NSString *)processName;
- (void)launchApplication:(ALApplication *)app;
- (NSArray <ALApplication *> *)applicationsFromArray:(NSArray *)applications filterHidden:(BOOL)filter;
- (BOOL)deleteApplication:(ALApplication *)app;
- (NSArray <ALApplication *> *)systemApplications;
- (NSArray <ALApplication *> *)allInstalledApplications;
- (NSArray <ALApplication *> *)userInstalledApplications;
- (NSDictionary *)rawDaemonDetails;
+ (int)killRunningProcess:(ALRunningProcess *)app;
+ (NSString *)userForID:(NSInteger)uid;
+ (NSString *)groupForID:(NSInteger)gid;
- (ALApplication *)applicationWithDisplayIdentifier:(NSString *)identifier;
@end


