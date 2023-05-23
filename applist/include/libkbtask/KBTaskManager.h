
#import <Foundation/Foundation.h>
#import "NSTask.h"

#define FM [NSFileManager defaultManager]

@interface KBTaskManager: NSObject
@property (nonatomic, strong) NSString *prefixPath;
@property (readwrite, assign) BOOL usePrefixes;
+ (id)sharedManager;
+ (NSString *)kb_task_environmentPath;
+ (NSDictionary *)kb_task_executableEnvironment;
+ (NSString *)kb_task_returnForProcess:(NSString *)process;
@end
