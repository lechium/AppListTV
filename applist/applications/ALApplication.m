#import "ALApplication.h"
#import "NSFileManager+size.h"
#import "ALFindProcess.h"
#import "Defines.h"

@interface ALApplication(){
    pid_t _internalPid;
}
@end

@implementation ALApplication

- (instancetype)initWithProxy:(id)proxy {
    
    self = [super init];
    _proxy = proxy;
    _name = [proxy localizedName];
    _bundleID = [proxy bundleIdentifier];
    NSString *exe = [proxy bundleExecutable];
    _bundlePath = [[proxy bundleURL] path];
    _infoDictionary = [NSDictionary dictionaryWithContentsOfFile:[_bundlePath stringByAppendingPathComponent:@"Info.plist"]];
    _binaryPath = [_bundlePath stringByAppendingPathComponent:exe];
    _applicationType = [proxy applicationType];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:self.binaryPath error:nil];
    _posixPerms = [attrs[NSFilePosixPermissions] integerValue];
    _isSetuid = (_posixPerms == 3565);
    _hidden = [[proxy appTags] containsObject:@"hidden"];// && ![self hasIcon];
    _bundleVersion = [proxy bundleVersion];
    if ([proxy respondsToSelector:@selector(claimedDocumentContentTypes)]){
        _documentTypes = [[proxy claimedDocumentContentTypes] allObjects];
    }
    //NSLog(@"%@ claimedDocumentContentTypes: %@",[proxy bundleIdentifier], [proxy claimedDocumentContentTypes]);
    if (_documentTypes){
        //NSLog(@"_documentTypes: %@", _documentTypes);
    }
     if ([proxy respondsToSelector:@selector(claimedURLSchemes)]){
         _URLSchemes = [[proxy claimedURLSchemes] allObjects];
    }
    return self;
    
}

- (NSString *)displayName {
    return _name;
}

- (NSString *)displayIdentifier {
    return _bundleID;
}


- (BOOL)hasIcon {
    
    if ([self.proxy respondsToSelector:@selector(_tv_applicationIconName)]){
        NSString *appIcon = [self.proxy _tv_applicationIconName];
        if (!appIcon){
            return false;
        }
    }
    return true;//ehhhhh?
}

- (NSString *)description {
    
    NSString *og = [super description];
    return [NSString stringWithFormat:@"%@ %@ %@ (%@) isSetuid: %d hidden: %d", og, _bundleID, _name, _bundleVersion, _isSetuid, _hidden];
    //<LSApplicationProxy: 0x147e4cc20> com.plexapp.plex file:///private/var/containers/Bundle/Application/7C3799DB-BAF1-48DE-BB85-6B115E463B5A/Plex.app <com.plexapp.plex <installed >:0>"
}

- (NSNumber *)userDataSize {
    if (!self.proxy) {
        return @0;
    }
    
    if ([self.proxy respondsToSelector:@selector(diskUsage)])
        return [[[self proxy] diskUsage] dynamicUsage];
    else
        return [[self proxy] dynamicDiskUsage];
    //NSString *onePath = [[self.proxy dataContainerURL] path];
    //return [[NSFileManager defaultManager] sizeForFolderAtPath:onePath error:nil];
 
}

- (NSNumber *)installedSize {
    if (!self.proxy) {
        return @0;
    }
    
    if ([self.proxy respondsToSelector:@selector(diskUsage)])
        return [[[self proxy] diskUsage] staticUsage];
    else
        return [[self proxy] staticDiskUsage];
}

- (UIImage *)icon {
    
    return [self.proxy tv_applicationFlatIcon];
}

- (pid_t)pid {
    if (_internalPid == 0){
        _internalPid = [ALFindProcess find_process:[[self binaryPath] lastPathComponent].UTF8String fuzzy:true];
    }
    return _internalPid;
}

- (void)resetPid {
    _internalPid = 0;
}

@end
