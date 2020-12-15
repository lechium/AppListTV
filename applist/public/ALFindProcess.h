
#import <Foundation/Foundation.h>
#include <libproc.h>
#include <mach/mach_time.h>
#include <sys/sysctl.h>
#include <mach-o/ldsyms.h>
@class ALRunningProcess;
@interface ALFindProcess : NSObject
+ (NSString *)processNameFromPID:(pid_t)ppid;
+ (pid_t) find_process:(const char*)name fuzzy:(boolean_t)fuzzy;
+ (NSArray <ALRunningProcess *> *)allRunningProcesses;
+ (int)totalProcessCount;
@end


