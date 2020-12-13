#import "ALFindProcess.h"
#import "ALRunningProcess.h"
//#import "BaseMetaData.h"

//extern char*** _NSGetEnviron(void);
extern int proc_listallpids(void*, int);
extern int proc_pidpath(int, void*, uint32_t);
extern int proc_listchildpids(pid_t ppid, void * buffer, size_t buffersize);
static int process_buffer_size = 4096;

@implementation ALFindProcess

+ (NSArray <NSNumber *> *)childProcessIds:(pid_t)pid{
    NSMutableArray *_ourPids = [NSMutableArray new];
    pid_t *pids = NULL;
    size_t len = sizeof(pid_t) * 1000;
    int i = 0, kp_cnt = 0;
    if ((pids = malloc(len)) == NULL) {
        return nil;
    }
    kp_cnt = proc_listchildpids(pid, pids, len);
    for (i = 0; i < kp_cnt; i++) {
        pid_t currentPid = pids[i];
        [_ourPids addObject:[NSNumber numberWithInt:currentPid]];
        //NSLog(@"current child pid: %i at index %i", currentPid, i);
    }
    return _ourPids;
}

+ (NSArray <ALRunningProcess *> *)allRunningProcesses{
    pid_t *pid_buffer;
    char path_buffer[MAXPATHLEN];
    int count, i, ret;
    pid_buffer = (pid_t*)calloc(1, process_buffer_size);
    assert(pid_buffer != NULL);
    NSMutableArray *processes = [NSMutableArray new];
    count = proc_listallpids(pid_buffer, process_buffer_size);
    NSLog(@"process count: %d", count);
    if(count) {
        for(i = 0; i < count; i++) {
            pid_t pid = pid_buffer[i];
            
            ret = proc_pidpath(pid, (void*)path_buffer, sizeof(path_buffer));
            if(ret < 0) {
                printf("(%s:%d) proc_pidinfo() call failed.\n", __FILE__, __LINE__);
                continue;
            }
            struct proc_bsdshortinfo proc;
            proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 0,
                                  &proc, PROC_PIDT_SHORTBSDINFO_SIZE);
            NSString *processPath = [NSString stringWithUTF8String:path_buffer];
            //NSLog(@"checking child ids for %@", [processPath lastPathComponent]);
            NSArray *chidrens = [self childProcessIds:pid];
            ALRunningProcess *process = [[ALRunningProcess alloc] initWithProcess:proc path:processPath children:chidrens];
            //BaseMetaData *md = [[BaseMetaData alloc] initWithRunningProcess:process];
            [processes addObject:process];
          }
    }
    
    free(pid_buffer);
    return [processes sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:TRUE]]];
}


+ (NSString *)processNameFromPID:(pid_t)ppid {
    //pid_t *pid_buffer;
    char path_buffer[MAXPATHLEN];
    proc_pidpath(ppid, (void*)path_buffer, sizeof(path_buffer));
    return [NSString stringWithUTF8String:path_buffer];
}

//plucked and modified from AppSyncUnified

+ (pid_t) find_process:(const char*) name fuzzy:(boolean_t)fuzzy {
    pid_t *pid_buffer;
    char path_buffer[MAXPATHLEN];
    int count, i, ret;
    boolean_t res = FALSE;
    pid_t ppid_ret = 0;
    pid_buffer = (pid_t*)calloc(1, process_buffer_size);
    assert(pid_buffer != NULL);
    
    count = proc_listallpids(pid_buffer, process_buffer_size);
    NSLog(@"process count: %d", count);
    if(count) {
        for(i = 0; i < count; i++) {
            pid_t ppid = pid_buffer[i];
            
            ret = proc_pidpath(ppid, (void*)path_buffer, sizeof(path_buffer));
            if(ret < 0) {
                printf("(%s:%d) proc_pidinfo() call failed.\n", __FILE__, __LINE__);
                continue;
            }
            
            //NSString *pb = [NSString stringWithUTF8String:path_buffer];
            //NSLog(@"process %@ for pid: %lu", pb, ppid);
            //NSLog(@"comparing %@ to %@", pb, [NSString stringWithUTF8String:name]);
            
            /*
            if (fuzzy){
                res = (strncmp(path_buffer, name, strlen(path_buffer)) == 0);
            } else {
                res = (strstr(path_buffer, name));
            }
            if (res){
                ppid_ret = ppid;
                break;
            }
             */
            /*
            if (strncmp(path_buffer, name, strlen(path_buffer)) == 0){
                res = TRUE;
                ppid_ret = ppid;
                break;
            }
            */
            if(strstr(path_buffer, name)) {
                res = TRUE;
                ppid_ret = ppid;
                break;
            }
        }
    }
    
    free(pid_buffer);
    return ppid_ret;
}

@end



