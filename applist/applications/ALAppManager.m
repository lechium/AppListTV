
#import "ALAppManager.h"
#import "ALFindProcess.h"
#import <objc/runtime.h>
#import "NSTask.h"
#import "Defines.h"
@interface ALAppManager() {
    NSDictionary *__rawDaemonDetails;
    NSArray *__allApplicationCache;
    BOOL _needsRefresh;
}
@end

@implementation ALAppManager

- (NSInteger)lazyApplicationCount {
    return [[[self defaultWorkspace] allInstalledApplications] count];
}

+ (id)sharedManager {
    static dispatch_once_t onceToken;
    static ALAppManager *shared = nil;
    if(shared == nil){
        dispatch_once(&onceToken, ^{
            shared = [[ALAppManager alloc] init];
        });
    }
    return shared;
}

- (void)setNeedsRefresh {
    _needsRefresh = true;
}

- (ALApplication *)applicationWithDisplayIdentifier:(NSString *)identifier {
    id prox = [LSApplicationProxy applicationProxyForIdentifier:identifier];
    return [[ALApplication alloc] initWithProxy:prox];
}

- (NSArray <ALApplication *> *)applicationsFromArray:(NSArray *)applications filterHidden:(BOOL)filter {
    
    __block NSMutableArray *ntvApps = [NSMutableArray new];
    [applications enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        ALApplication *app = [[ALApplication alloc] initWithProxy:obj];
        if (app){
            //NSLog(@"filter: %d hidden: %d", filter, app.hidden);
            if ((filter == true) && (app.hidden == true)){
                //NSLog(@"filtering out hidden app: %@", app);
            } else {
                [ntvApps addObject:app];
                
            }
        }
    }];
    return ntvApps;
}

+ (int)killProcess:(NSString *)processName {
    
    pid_t fp = [ALFindProcess find_process:processName.UTF8String fuzzy:true];
    if (fp != 0){
        NSLog(@"found %@ at pid %d", processName, fp);
        return kill(fp, 9);
    }
    return -1;
}

+ (int)killApplication:(ALApplication *)app {
    
    int status = kill([app pid], 9);
    [app resetPid];
    return status;
}

- (void)runProcess:(NSString *)call withCompletion:(void(^)(NSString *output, NSInteger returnStatus))block {

    NSArray *args = [call componentsSeparatedByString:@" "];
    NSString *taskBinary = args[0];
    NSArray *taskArguments = [args subarrayWithRange:NSMakeRange(1, args.count-1)];
    //NSLog(@"%@ %@", taskBinary, [taskArguments componentsJoinedByString:@" "]);
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [[NSPipe alloc] init];
    NSFileHandle *handle = [pipe fileHandleForReading];
    
    [task setLaunchPath:taskBinary];
    [task setArguments:taskArguments];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];
    
    [task launch];
    
    NSData *outData = nil;
    NSString *temp = nil;
    while((outData = [handle readDataToEndOfFile]) && [outData length])
    {
        temp = [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
        
    }
    [handle closeFile];
    [task waitUntilExit];
    int termStatus = [task terminationStatus];
    task = nil;
    if (block){
        block(temp, termStatus);
    }
}

+ (int)killRunningProcess:(ALRunningProcess *)app {
    
    int status = 0;
    if (app.uid == 0){
        NSLog(@"can't kill privledged processes!");
        return -1;
    } else {
        status = kill([app pid], 9);
        
    }
    [app resetPid];
    return status;
}

+ (NSArray *)arrayReturnForTask:(NSString *)taskBinary withArguments:(NSArray *)taskArguments {
    if (![[NSFileManager defaultManager] fileExistsAtPath:taskBinary]){
        return nil;
    }
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [[NSPipe alloc] init];
    NSFileHandle *handle = [pipe fileHandleForReading];
    
    [task setEnvironment:@{@"APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE": [NSNumber numberWithBool:TRUE]}];
    [task setLaunchPath:taskBinary];
    [task setArguments:taskArguments];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];
    
    [task launch];
    
    NSData *outData = nil;
    NSString *temp = nil;
    while((outData = [handle readDataToEndOfFile]) && [outData length]) {
        temp = [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
        
    }
    [handle closeFile];
    task = nil;
    return [temp componentsSeparatedByString:@"\n"];
}

+ (int)killAllProcesses:(NSArray <ALRunningProcess *> *)metas root:(BOOL)priv{
    if (priv == true){
        NSLog(@"can't kill privledged processes!");
        return -1;
    } else {
        [metas enumerateObjectsUsingBlock:^(ALRunningProcess * _Nonnull proc, NSUInteger idx, BOOL * _Nonnull stop) {
            int status = kill([proc pid], 9);
            NSLog(@"kill %@ returned status %i", proc.name, status);
            [proc resetPid];
        }];
    }
    
    
    return 0;
}


- (void)launchApplication:(ALApplication *)app {
    [[self defaultWorkspace] performSelector:@selector(openApplicationWithBundleID:) withObject:(id) app.bundleID ];
}

- (BOOL)deleteApplication:(ALApplication *)app {
    
    return [[self defaultWorkspace] uninstallApplication:app.bundleID withOptions:nil];
}

- (id)defaultWorkspace {
    return [objc_getClass("LSApplicationWorkspace") defaultWorkspace];
}

- (NSArray <ALApplication *> *)systemApplications {
    return [self applicationsFromArray:[[self defaultWorkspace] applicationsOfType:1] filterHidden:false];
}

- (BOOL)cacheHasChanged {
    if (__allApplicationCache){
        if ([__allApplicationCache count] != [self lazyApplicationCount]){
            return true;
        } else {
            return false;
        }
    }
    return true; //doesnt exist yet
}

- (NSArray <ALApplication *> *)allInstalledApplications {
    if ([self cacheHasChanged]){
       __allApplicationCache = [self applicationsFromArray:[[self defaultWorkspace] allInstalledApplications] filterHidden:false];
    }
    return __allApplicationCache;
}

- (NSArray <ALApplication *> *)userInstalledApplications {
    return [self applicationsFromArray:[[self defaultWorkspace] applicationsOfType:0] filterHidden:false];
}

- (NSDictionary *)rawDaemonDetails {
    if ((__rawDaemonDetails != nil) && (_needsRefresh == false)){
        return __rawDaemonDetails;
    }
    NSMutableDictionary *finalDict = [NSMutableDictionary new];
    NSString *systemPath = @"/System/Library/LaunchDaemons/";
    NSString *libPath = @"/Library/LaunchDaemons/";
    NSArray *systemDaemons = [FM contentsOfDirectoryAtPath:systemPath error:nil];
    NSArray *libraryDaemons = [FM contentsOfDirectoryAtPath:libPath error:nil];
    [systemDaemons enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([[obj pathExtension] isEqualToString:@"plist"]){
            NSDictionary *dirtyDeeds = [NSDictionary dictionaryWithContentsOfFile:[systemPath stringByAppendingPathComponent:obj]];
            if (dirtyDeeds){
                NSString *dictKey = nil;
                if ([[dirtyDeeds allKeys] containsObject:@"Program"]){
                    //NSLog(@"program: %@", obj);
                    dictKey = [dirtyDeeds[@"Program"] lastPathComponent];
                } else if ([[dirtyDeeds allKeys] containsObject:@"ProgramArguments"]){
                    //NSLog(@"programArgs: %@", obj);
                    dictKey = [[dirtyDeeds[@"ProgramArguments"] firstObject] lastPathComponent];
                }
                //NSLog(@"dictKey: %@", dictKey);
                if (dictKey != nil && dirtyDeeds != nil){
                    finalDict[dictKey] = dirtyDeeds;
                }
                
            }
            
        }
        
    }];
    
    [libraryDaemons enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([[obj pathExtension] isEqualToString:@"plist"]){
            NSDictionary *dirtyDeeds = [NSDictionary dictionaryWithContentsOfFile:[libPath stringByAppendingPathComponent:obj]];
            if (dirtyDeeds){
                NSString *dictKey = nil;
                if ([[dirtyDeeds allKeys] containsObject:@"Program"]){
                    //NSLog(@"program: %@", obj);
                    dictKey = [dirtyDeeds[@"Program"] lastPathComponent];
                } else if ([[dirtyDeeds allKeys] containsObject:@"ProgramArguments"]){
                    //NSLog(@"programArgs: %@", obj);
                    dictKey = [[dirtyDeeds[@"ProgramArguments"] firstObject] lastPathComponent];
                }
                //NSLog(@"dictKey: %@", dictKey);
                if (dictKey != nil && dirtyDeeds != nil){
                    finalDict[dictKey] = dirtyDeeds;
                }
                
            }
            
        }
        
    }];
    __rawDaemonDetails = finalDict;
    
    return __rawDaemonDetails;
}

+ (NSString *)userForID:(NSInteger)uid {
    
    switch (uid){
        case 0:
            return @"root";
        case 24:
            return @"_networkd";
        case 25:
            return @"_wireless";
        case 33:
            return @"_installd";
        case 64:
            return @"_securityd";
        case 65:
            return @"_mdnsresponder";
        case 241:
            return @"_distnote";
        case 501:
            return @"mobile";
        case 263:
            return @"_analyticsd";
        case 266:
            return @"_timed";
    }
    return [NSString stringWithFormat:@"%ld", (long)uid];
}

+ (NSString *)groupForID:(NSInteger)gid {
    
    switch (gid){
        case 0:
            return @"wheel";
        case 1:
            return @"daemon";
        case 2:
            return @"kmem";
        case 3:
            return @"sys";
        case 4:
            return @"tty";
        case 5:
            return @"operator";
        case 8:
            return @"procview";
        case 9:
            return @"procmod";
        case 20:
            return @"staff";
        case 24:
            return @"_networkd";
        case 25:
            return @"_wireless";
        case 29:
            return @"certusers";
        case 33:
            return @"_installd";
        case 64:
            return @"_securityd";
        case 65:
            return @"_mdnsresponder";
        case 80:
            return @"admin";
        case 241:
            return @"_distnote";
        case 263:
            return @"_analyticsd";
        case 266:
            return @"_timed";
        case 501:
            return @"mobile";
    }
    return [NSString stringWithFormat:@"%ld", (long)gid];
}

@end
