#import "ALRootListController.h"
#import "ALApplicationList.h"
#import "ALAppManager.h"
#import "TVSPreferences.h"
#import "ALFindProcess.h"
@interface ALRootListController()

@property NSString *domain;
@property NSString *groupTitle;
@end

@interface TSKSettingItem (preferenceLoader)

@property (nonatomic, strong) TSKPreviewViewController *previewViewController;
@property (nonatomic, strong) id controller;
@property (nonatomic, strong) NSDictionary *specifier;
@property (nonatomic, strong) NSDictionary *keyboardDetails;
@property (nonatomic, strong) UIImage *itemIcon;

@end

// All preferences on tvOS are added in programatically in groups.

const NSString *ALSectionDescriptorTitleKey = @"title";
const NSString *ALSectionDescriptorFooterTitleKey = @"footer-title";
const NSString *ALSectionDescriptorPredicateKey = @"predicate";
const NSString *ALSectionDescriptorCellClassNameKey = @"cell-class-name";
const NSString *ALSectionDescriptorIconSizeKey = @"icon-size";
const NSString *ALSectionDescriptorItemsKey = @"items";
const NSString *ALSectionDescriptorSuppressHiddenAppsKey = @"suppress-hidden-apps";
const NSString *ALSectionDescriptorVisibilityPredicateKey = @"visibility-predicate";

const NSString *ALItemDescriptorTextKey = @"text";
const NSString *ALItemDescriptorDetailTextKey = @"detail-text";
const NSString *ALItemDescriptorImageKey = @"image";

//tvOS
const NSString *ALItemSupportsLongPress = @"supports-long-press";
const NSString *ALAllProcessesMode  = @"all-processes-mode";
const NSString *ALUseBundleIdentifier = @"ALUseBundleIdentifier";

@interface ALRootListController() {
    NSString *_navigationTitle;
    NSArray *descriptors;
    id settingsDefaultValue;
    NSString *settingsPath;
    NSString *preferencesKey;
    NSMutableDictionary *settings;
    NSString *settingsKeyPrefix;
    BOOL singleEnabledMode;
    BOOL supportsLongPress;
    BOOL useBundleIdentifier;
    BOOL allProcessesMode;
    id facade; //settings facade
}
@end

@implementation ALRootListController

+ (NSArray *)standardSectionDescriptors {
    return @[@{
            ALSectionDescriptorTitleKey:@"System Applications",
            ALSectionDescriptorPredicateKey: @"isSystemApplication = TRUE",
            ALSectionDescriptorSuppressHiddenAppsKey: (id)kCFBooleanTrue,
            },
            @{
             ALSectionDescriptorTitleKey: @"User Applications",
             ALSectionDescriptorPredicateKey: @"isSystemApplication = FALSE",
             ALSectionDescriptorSuppressHiddenAppsKey: (id)kCFBooleanTrue,
             }];
}

+ (NSArray *)processSectionDescriptors {
    return @[@{
    ALSectionDescriptorTitleKey: @"All Processes",
    ALAllProcessesMode: (id)kCFBooleanTrue,
    }];
}

/*
 
 settingsKeyPrefix = [specifier propertyForKey:singleEnabledMode ? @"ALSettingsKey" : @"ALSettingsKeyPrefix"] ?: @"ALValue-";
 
 settings = [[NSMutableDictionary alloc] initWithContentsOfFile:settingsPath] ?: [[NSMutableDictionary alloc] init];
 
 
 id temp = [specifier propertyForKey:@"ALAllowsSelection"];
 [_tableView setAllowsSelection:temp ? [temp boolValue] : singleEnabledMode];
 
 }
 */

- (NSArray <TSKSettingItem *>*)itemsFromSpecifier:(NSDictionary *)spec {
    
    __block NSMutableArray *_items = [NSMutableArray new];
    NSString *predicateText = spec[ALSectionDescriptorPredicateKey];
    NSPredicate *predicate = predicateText ? [NSPredicate predicateWithFormat:predicateText] : nil;
    BOOL onlyVisible = true;
    supportsLongPress = true;
    if ([[spec allKeys] containsObject:ALSectionDescriptorSuppressHiddenAppsKey]){
        onlyVisible = [spec[ALSectionDescriptorSuppressHiddenAppsKey] boolValue];
    }
    if ([[spec allKeys] containsObject:ALItemSupportsLongPress]){
        supportsLongPress = [spec[ALItemSupportsLongPress] boolValue];
    }
    ALApplicationList *list = [ALApplicationList sharedApplicationList];
    if (allProcessesMode){
        NSArray *allProcesses = [ALFindProcess allRunningProcesses];
        [allProcesses enumerateObjectsUsingBlock:^(ALRunningProcess  *_Nonnull process, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *title = [process name];
            NSString *key = [process identifierIfApplicable];
            if (!key){
                key = [process assetDescription];
            }
            TSKSettingItem *item = [TSKSettingItem toggleItemWithTitle:title description:key representedObject:facade keyPath:key onTitle:nil offTitle:nil];
            [item setItemIcon:[process icon]];
            [item setDefaultValue:settingsDefaultValue];
            if(supportsLongPress){
                [item setTarget:self];
                [item setLongPressAction:@selector(longPressAction:)];
            }
            if ([facade valueForUndefinedKey:key] == nil){
                [facade setValue:settingsDefaultValue forUndefinedKey:key];
            }
            [_items addObject:item];
        }];
        return [_items sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:TRUE]]];
    }
    NSDictionary *apps = [list applicationsFilteredUsingPredicate:predicate onlyVisible:onlyVisible titleSortedIdentifiers:nil];
    [apps enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *settingsKey = [settingsKeyPrefix stringByAppendingString:obj];
        if (useBundleIdentifier){
            settingsKey = [key stringByReplacingOccurrencesOfString:@"." withString:@"-"];
        }
        TSKSettingItem *item = [TSKSettingItem toggleItemWithTitle:obj description:key representedObject:facade keyPath:settingsKey onTitle:nil offTitle:nil];
        NSLog(@"settings default value: %@", settingsDefaultValue);
        [item setDefaultValue:settingsDefaultValue];
        if(supportsLongPress){
            [item setTarget:self];
            [item setLongPressAction:@selector(longPressAction:)];
        }
        if ([facade valueForUndefinedKey:settingsKey] == nil){
            [facade setValue:settingsDefaultValue forUndefinedKey:settingsKey];
        }
        [_items addObject:item];
    }];
    
    return [_items sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:TRUE]]];
}


- (void)loadSpecifier:(NSDictionary *)spec {
    NSString *navTitle = spec[@"ALNavigationTitle"];
    if (!navTitle){
        navTitle = spec[@"label"];
    }
    self.title = navTitle;
    settingsDefaultValue = spec[@"ALSettingsDefaultValue"];
    settingsPath = spec[@"ALSettingsPath"];
    if ((kCFCoreFoundationVersionNumber >= 1000) && [settingsPath hasPrefix:@"/var/mobile/Library/Preferences/"] && [settingsPath hasSuffix:@".plist"]) {
        _domain = [[settingsPath lastPathComponent] stringByDeletingPathExtension];
    } else {
        _domain = nil;
    }
    NSLog(@"app domain: %@", _domain);
    settingsKeyPrefix = spec[@"ALSettingsKeyPrefix"];
    facade = [[NSClassFromString(@"TSKPreferencesFacade") alloc] initWithDomain:_domain notifyChanges:TRUE];
    if ([[spec allKeys] containsObject:ALItemSupportsLongPress]){
        supportsLongPress = [spec[ALItemSupportsLongPress] boolValue];
    }
    if ([[spec allKeys] containsObject:ALAllProcessesMode]){
        allProcessesMode = [spec[ALAllProcessesMode] boolValue];
    }
    //this was well intentioned by keyPath / key gets screwy because of the periods in the bundleId
    /*
    if ([[spec allKeys] containsObject:ALUseBundleIdentifier]){
        useBundleIdentifier = [spec[ALUseBundleIdentifier] boolValue];
    }*/
}

- (id)loadSettingGroups {
    
    supportsLongPress = true;
    useBundleIdentifier = false;
    allProcessesMode = false;
    NSDictionary *spec = [self specifier];
    [self loadSpecifier:spec];
    self.sectionDescriptors = spec[@"ALSectionDescriptors"];
    
    if (!self.sectionDescriptors){
        self.sectionDescriptors = [ALRootListController standardSectionDescriptors];
    }
    if (allProcessesMode == true){
        self.sectionDescriptors = [ALRootListController processSectionDescriptors];
    }
    NSMutableArray *_backingArray = [NSMutableArray new];
    [self.sectionDescriptors enumerateObjectsUsingBlock:^(NSDictionary  *_Nonnull groupDescriptor, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *groupTitle = groupDescriptor[ALSectionDescriptorTitleKey];
        NSArray *settingsItems = [self itemsFromSpecifier:groupDescriptor];
        TSKSettingGroup *group = [TSKSettingGroup groupWithTitle:groupTitle settingItems:settingsItems];
        [_backingArray addObject:group];
    }];
    [self setValue:_backingArray forKey:@"_settingGroups"];
    
    return _backingArray;
    
}

- (void)longPressAction:(TSKSettingItem *)item {
    NSLog(@"long press occured: %@", item);
    
    NSString *ident = [item localizedDescription];
    ALApplication *app = [[ALAppManager sharedManager] applicationWithDisplayIdentifier:ident];
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:[item localizedTitle] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *open = [UIAlertAction actionWithTitle:@"Open" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        [[ALAppManager sharedManager] launchApplication:app];
        
    }];
    [ac addAction:open];
    pid_t pid = [app pid];
    if (pid != 0){
        NSLog(@"pid: %d", pid);
        UIAlertAction *quitAction = [UIAlertAction actionWithTitle:@"Quit Application" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            
            [ALAppManager killApplication:app];
            
        }];
        [ac addAction:quitAction];
    }
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [ac addAction:cancel];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:ac animated:TRUE completion:nil];
    });
}


-(id)previewForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    TSKAppIconPreviewViewController *item = [super previewForItemAtIndexPath:indexPath];
    TSKSettingGroup *currentGroup = self.settingGroups[indexPath.section];
    TSKSettingItem *currentItem = currentGroup.settingItems[indexPath.row];
    NSString *desc = [currentItem localizedDescription];
    if (allProcessesMode){
        item = (TSKAppIconPreviewViewController*)[TSKPreviewViewController new];
        TSKVibrantImageView *imageView = [[TSKVibrantImageView alloc] initWithImage:[currentItem itemIcon]];
        [item setContentView:imageView];
        [item setDescriptionText:desc];
        return item;
    }
    item = [[TSKAppIconPreviewViewController alloc] initWithApplicationBundleIdentifier:desc];
    NSString *appDetails = [NSString stringWithFormat:@"%@\n\nLong press for more options.", desc];
    [item setDescriptionText:appDetails];
    return item;
}

@end
