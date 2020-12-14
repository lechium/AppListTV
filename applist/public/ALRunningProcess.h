#import <Foundation/Foundation.h>
#include <libproc.h>
#import "ALApplication.h"

typedef enum {
    ProcessTypeUndefined = -1,
    ProcessTypeGeneric = 0,
    ProcessTypeDaemon = 1,
    ProcessTypeApplication = 2,
} ProcessType;

@interface ALRunningProcess : NSObject

@property NSString *name;
@property NSString *imagePath;
@property NSString *assetDescription;
@property pid_t ppid;
@property pid_t pid;
@property NSInteger uid;
@property NSInteger gid;
@property NSString *parent;
@property NSString *path;
@property NSString *user;
@property NSString *group;
@property ProcessType type;
@property NSDictionary *infoDictionary;
@property NSArray <NSNumber *> *children;
@property ALApplication *associatedApplication;

- (UIImage *)icon;
- (NSString *)identifierIfApplicable;
- (NSString *)stringForType;
- (instancetype)initWithProcess:(struct proc_bsdshortinfo)proc path:(NSString *)fullPath children:(NSArray <NSNumber *> *)childPids;
- (void)resetPid;
@end
