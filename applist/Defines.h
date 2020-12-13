#define FM [NSFileManager defaultManager]

@interface NSObject (wrekt)
-(NSURL *)resourcesDirectoryURL;
-(NSURL *)dataContainerURL;
+(id)applicationProxyForIdentifier:(id)arg1; //LSApplicationProxy
-(id)staticDiskUsage;
-(id)dynamicDiskUsage;
-(id)diskUsage; //_LSDiskUsage
@end

@interface _LSDiskUsage: NSObject
- (id)staticUsage;
- (id)dynamicUsage;
@end

@interface LSApplicationWorkspace: NSObject
-(id)allInstalledApplications;
-(NSArray *)applicationsOfType:(unsigned long long)arg1 ;
-(id)allApplications;
-(id)placeholderApplications;
-(id)unrestrictedApplications;
-(void)openApplicationWithBundleID:(NSString *)string;
+(id)defaultWorkspace;
-(BOOL)uninstallApplication:(id)arg1 withOptions:(id)arg2;
@end
