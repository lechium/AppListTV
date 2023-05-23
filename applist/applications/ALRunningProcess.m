
#import "ALRunningProcess.h"
#import "ALFindProcess.h"
#import "ALAppManager.h"

@interface ALRunningProcess() {
    NSString *_cachedIdentifier;
    UIImage *_cachedIcon;
}
@end

@implementation ALRunningProcess

- (instancetype)initWithProcess:(struct proc_bsdshortinfo)proc path:(NSString *)fullPath children:(NSArray <NSNumber *> *)childPids {
    
    self = [super init];
    if (self){
        self.name = fullPath.lastPathComponent;
        self.imagePath = @"ExecutableBinaryIcon";
        self.assetDescription = fullPath;
        self.pid = proc.pbsi_pid;
        self.ppid = proc.pbsi_ppid;
        self.parent  = [NSString stringWithFormat:@"%@ (%ld)",[ALFindProcess processNameFromPID:self.ppid], (long)self.ppid];
        self.user = [ALAppManager userForID:proc.pbsi_uid];
        self.group = [ALAppManager groupForID:proc.pbsi_gid];
        self.assetDescription = fullPath;
        self.path = fullPath;
        _children = childPids;
        if (childPids.count > 0){
            //NSLog(@"process %@ has %lu children", self.name, childPids.count);
        }
        [self _determineType];
        
    }
    return self;
  
}

- (NSString *)description {
    NSString *sup = [super description];
    return [NSString stringWithFormat:@"%@, name: %@ type: %@ pid: %d", sup, self.name, self.stringForType, self.pid];
}

- (NSString *)identifierIfApplicable {
    
    if (_cachedIdentifier != nil) return _cachedIdentifier;
    
    switch (_type) {
        case ProcessTypeApplication:
            _cachedIdentifier = self.associatedApplication.bundleID;
            break;
        case ProcessTypeDaemon:
            _cachedIdentifier = self.infoDictionary[@"Label"];
            break;
        default:
            return _cachedIdentifier;
    }
    return _cachedIdentifier;
}

- (NSString *)stringForType {
    
    switch(_type){
            case ProcessTypeGeneric: return @"Generic";
            case ProcessTypeApplication: return @"Application";
            case ProcessTypeDaemon: return @"LaunchDaemon";
            case ProcessTypeUndefined: return @"Unknown";
    }
    return @"Unknown";
}

- (void)_determineType {
    
    NSDictionary *packages = [[ALAppManager sharedManager] rawDaemonDetails];
    self.infoDictionary = packages[self.name];
    if (self.infoDictionary != nil){
        //NSLog(@"%@ is a daemon!", self.name);
        _type = ProcessTypeDaemon; //this logic might be bunk
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.binaryPath == %@",self.path];
        NSArray *apps = [[[ALAppManager sharedManager] allInstalledApplications] filteredArrayUsingPredicate:predicate];
        if (apps.count > 0){
             //NSLog(@"%@ is a application!", self.name);
            _type = ProcessTypeApplication;
            self.associatedApplication = [apps firstObject];
            self.infoDictionary = self.associatedApplication.infoDictionary;
        } else {
             //NSLog(@"%@ is generic!", self.name);
            _type = ProcessTypeGeneric;
        }
    }
    
}

- (UIImage *)icon {
    if (_cachedIcon != nil) return _cachedIcon;{
        
        if (_type == ProcessTypeApplication) {
            _cachedIcon = self.associatedApplication.icon;
            return _cachedIcon;
        }
        _cachedIcon = [UIImage imageWithContentsOfFile:_imagePath];
        if (_cachedIcon == nil){
            _cachedIcon = [UIImage imageWithContentsOfFile:@"/fs/jb/Library/PreferenceBundles/AppList.bundle/ExecutableBinaryIcon.png"];
        }
    }
    return _cachedIcon;
}


- (void)resetPid {
    self.pid = -1;
    self.ppid = -1;
}

@end
