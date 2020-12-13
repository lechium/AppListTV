#import "ALRootListController.h"
#import "ALApplicationList.h"
#import "TVSPreferences.h"
@interface ALRootListController()

@property NSString *domain;
@end

// All preferences on tvOS are added in programatically in groups.

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
    NSDictionary *apps = [list applications];
    NSDictionary *spec = [self specifier];
    //NSString *navTitle = spec[@"ALNavigationTitle"];
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
        TSKSettingItem *item = [TSKSettingItem toggleItemWithTitle:obj description:key representedObject:facade keyPath:settingsKey onTitle:@"On" offTitle:@"Off"];
        NSLog(@"settings default value: %@", settingsDefaultValue);
        [item setDefaultValue:settingsDefaultValue];
        
        if ([facade valueForUndefinedKey:settingsKey] == nil){
            [facade setValue:settingsDefaultValue forUndefinedKey:settingsKey];
        }
        [_apps addObject:item];
    }];
    
    return [_apps sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:TRUE]]];
}

// Lets load our prefs!
- (id)loadSettingGroups {
    
    NSMutableArray *_backingArray = [NSMutableArray new];
    NSArray *items = [self applicationsFromAppList];
    TSKSettingGroup *group = [TSKSettingGroup groupWithTitle:@"Applications" settingItems:items];
    [_backingArray addObject:group];
    [self setValue:_backingArray forKey:@"_settingGroups"];
    
    return _backingArray;
    
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
    return item;
}

@end
