#import "ALRootListController.h"
#import "ALApplicationList.h"
#import "ALAppManager.h"
#import "TVSPreferences.h"
@interface ALRootListController()

@property NSString *domain;
@property NSString *groupTitle;
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


@implementation ALRootListController

/*
 
 settingsKeyPrefix = [specifier propertyForKey:singleEnabledMode ? @"ALSettingsKey" : @"ALSettingsKeyPrefix"] ?: @"ALValue-";
 
 settings = [[NSMutableDictionary alloc] initWithContentsOfFile:settingsPath] ?: [[NSMutableDictionary alloc] init];
 
 
 id temp = [specifier propertyForKey:@"ALAllowsSelection"];
 [_tableView setAllowsSelection:temp ? [temp boolValue] : singleEnabledMode];
 
 }
 */

- (NSArray <TSKSettingItem *>*)applicationsFromAppList{
    
    __block NSMutableArray *_apps = [NSMutableArray new];
    ALApplicationList *list = [ALApplicationList sharedApplicationList];
    
    NSDictionary *spec = [self specifier];
    NSArray *sectionDescriptors = spec[@"ALSectionDescriptors"];
    NSString *navTitle = spec[@"ALNavigationTitle"];
    NSPredicate *predicate = nil;
    BOOL onlyVisible = true;
    if ([sectionDescriptors count] > 0){
        //for now just handle the first one
        NSDictionary *firstDesc = [sectionDescriptors firstObject];
        NSString *predicateText = firstDesc[ALSectionDescriptorPredicateKey];
        predicate = predicateText ? [NSPredicate predicateWithFormat:predicateText] : nil;
        if ([[firstDesc allKeys] containsObject:ALSectionDescriptorSuppressHiddenAppsKey]){
            onlyVisible = [firstDesc[ALSectionDescriptorSuppressHiddenAppsKey] boolValue];
        }
        NSString *_gt = firstDesc[@"title"];
        if (_gt){
            self.groupTitle = _gt;
        }
    }
    NSDictionary *apps = [list applicationsFilteredUsingPredicate:predicate onlyVisible:onlyVisible titleSortedIdentifiers:nil];
    
    if (!navTitle){
        navTitle = spec[@"label"];
    }
    self.title = navTitle;
    id settingsDefaultValue = spec[@"ALSettingsDefaultValue"];
    if ([settingsDefaultValue respondsToSelector:@selector(length)]){
        NSNumber *number = [NSNumber numberWithInteger:[settingsDefaultValue integerValue]];
        settingsDefaultValue = number;
    }
    NSString *settingsPath = spec[@"ALSettingsPath"];
    if ((kCFCoreFoundationVersionNumber >= 1000) && [settingsPath hasPrefix:@"/var/mobile/Library/Preferences/"] && [settingsPath hasSuffix:@".plist"]) {
        _domain = [[settingsPath lastPathComponent] stringByDeletingPathExtension];
    } else {
        _domain = nil;
    }
    NSLog(@"app domain: %@", _domain);
    //BOOL singleEnabledMode = [spec[@"ALSingleEnabledMode"] boolValue];
    NSString *settingsKeyPrefix = spec[@"ALSettingsKeyPrefix"];
    id facade = [[NSClassFromString(@"TSKPreferencesFacade") alloc] initWithDomain:_domain notifyChanges:TRUE];
    
    [apps enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *settingsKey = [settingsKeyPrefix stringByAppendingString:obj];
        TSKSettingItem *item = [TSKSettingItem toggleItemWithTitle:obj description:key representedObject:facade keyPath:settingsKey onTitle:nil offTitle:nil];
        NSLog(@"settings default value: %@", settingsDefaultValue);
        [item setDefaultValue:settingsDefaultValue];
        [item setTarget:self];
        [item setLongPressAction:@selector(longPressAction:)];
        if ([facade valueForUndefinedKey:settingsKey] == nil){
            [facade setValue:settingsDefaultValue forUndefinedKey:settingsKey];
        }
        [_apps addObject:item];
    }];
    
    return [_apps sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:TRUE]]];
}

// Lets load our prefs!
- (id)loadSettingGroups {
    
    self.groupTitle = @"Applications";
    NSMutableArray *_backingArray = [NSMutableArray new];
    NSArray *items = [self applicationsFromAppList];
    TSKSettingGroup *group = [TSKSettingGroup groupWithTitle:self.groupTitle settingItems:items];
    [_backingArray addObject:group];
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
    
    pid_t pid = [app pid];
    if (pid != 0){
        NSLog(@"pid: %d", pid);
        UIAlertAction *quitAction = [UIAlertAction actionWithTitle:@"Quit Application" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            
            [ALAppManager killApplication:app];
            
        }];
        [ac addAction:quitAction];
    }
    
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    [ac addAction:open];
    [ac addAction:cancel];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:ac animated:TRUE completion:nil];
    });
}


// this is to make sure our preferences our loaded
- (TVSPreferences *)ourPreferences {
    return [TVSPreferences preferencesWithDomain:_domain];
}


// This is to show our tweak's icon instead of the boring Apple TV logo :)
-(id)previewForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    TSKAppIconPreviewViewController *item = [super previewForItemAtIndexPath:indexPath];
    TSKSettingGroup *currentGroup = self.settingGroups[indexPath.section];
    TSKSettingItem *currentItem = currentGroup.settingItems[indexPath.row];
    NSString *desc = [currentItem localizedDescription];
    //NSString *desc = [item descriptionText];
    item = [[TSKAppIconPreviewViewController alloc] initWithApplicationBundleIdentifier:desc];
    NSString *appDetails = [NSString stringWithFormat:@"%@\n\nLong press for more options.", desc];
    [item setDescriptionText:appDetails];
    return item;
}

@end
