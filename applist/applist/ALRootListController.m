#import "ALRootListController.h"
#import "ALApplicationList.h"
#import "ALAppManager.h"
#import "TVSPreferences.h"
#import "ALFindProcess.h"

@interface UIView (preferenceLoader)
- (NSArray *)siblingsInclusive:(BOOL)include;// inclusive means we include ourselves as well
@end

@interface TSKTableView (priv)
- (id)_focusedCell;
@end

@interface TSKTableViewController (preferenceLoader)
- (NSArray *)tableViewCells;
- (UITableViewCell *)cellFromSettingsItem:(TSKSettingItem *)settingsItem;
@end


@interface ALRootListController(){
    BOOL _pleaseWaitView;
    BOOL _specifierLoaded;
    NSMutableArray *_backingArray;
}

@property NSString *domain;
@property NSString *groupTitle;
@property (nonatomic, strong) TSKSettingItem *loadingItem;
@end

@interface UINavigationController (preferenceLoader)
- (TSKTableViewController *)previousViewController;
@end

@interface TSKSettingItem (preferenceLoader)

@property (nonatomic, strong) TSKPreviewViewController *previewViewController;
@property (nonatomic, strong) id controller;
@property (nonatomic, strong) NSDictionary *specifier;
@property (nonatomic, strong) NSDictionary *keyboardDetails;
@property (nonatomic, strong) UIImage *itemIcon;
@end

@interface ALSettingsFacade: TSKPreferencesFacade
@end

/**
 This is a bit... unclean, but it works. since 'toggle' TSKSettingItems have a keyPath associated with them for the preference facade it doesn't jive well with bundle identifiers due to the nature of keyPaths.
 ie VPEnabled-com.apple.TVHomeSharing will actually resolve to [facade valueForKey:@"VPEnabled-com"] , which yields nothing. Therefore the default functionality of tracking and setting defaults is
 completely broken with those kind of keys (which is what iOS applist creates by default), I work around this by creating our own settings facade and try to detect app instances by looking for
 com., net. or org. in the keyPath and then either call valueForKey or setValue:forKey respectively to avoid processing the 'paths' in the key. the periods are added so we dont erroneously sweep up
 properties that have those words but dont contain any periods.

 */

@implementation ALSettingsFacade
 
- (id)valueForKeyPath:(id)keyPath {
    
    if ([keyPath respondsToSelector:@selector(length)]){
        if ([keyPath containsString:@"com."] || [keyPath containsString:@"net."] || [keyPath containsString:@"org."]){
            id val = [super valueForKey:keyPath];
            //NSLog(@"[AppList] returning value: %@ of type: %@ forKeyPath: %@", val, [val class], keyPath);
            return val;
        }
    }
    id og = [super valueForKeyPath:keyPath];
    //NSLog(@"[AppList] returning value: %@ of type: %@ forKeyPath: %@", og, [og class], keyPath);
    return og;
}

- (void)setValue:(id)value forKeyPath:(id)keyPath {
    
    if ([keyPath respondsToSelector:@selector(length)]){
        if ([keyPath containsString:@"com."] || [keyPath containsString:@"net."] || [keyPath containsString:@"org."]){
            [super setValue:value forKey:keyPath];
            //NSLog(@"[AppList] setting value: %@ of type: %@ forKey: %@", value, [value class], keyPath);
            return;
        }
    }
    //NSLog(@"[AppList] setting value: %@ of type: %@ forKeyPath: %@", value, [value class], keyPath);
    [super setValue:value forKeyPath:keyPath];
}

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

const NSString *ALSingleEnabledMode = @"ALSingleEnabledMode";

//tvOS
const NSString *ALItemSupportsLongPress = @"supports-long-press";
const NSString *ALAllProcessesMode  = @"ALAllProcessesMode";
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

- (id)init {
    self = [super init];
    if (self){
        self.loadingItem = [TSKSettingItem titleItemWithTitle:@"Loading please wait..." description:@"Loading all processes this may take a moment please wait." representedObject:nil keyPath:nil];
    }
    return self;
}

/*
 
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
    NSDictionary *apps = [list applicationsFilteredUsingPredicate:predicate onlyVisible:onlyVisible titleSortedIdentifiers:nil];
    [apps enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        TSKSettingItem *item = nil;
        NSString *settingsKey = [settingsKeyPrefix stringByAppendingString:key];
        if (singleEnabledMode){
            settingsKey = settingsKeyPrefix;
            item = [TSKSettingItem actionItemWithTitle:obj description:key representedObject:nil keyPath:key target:self action:@selector(rowSelected:)];
        } else {
            item = [TSKSettingItem toggleItemWithTitle:obj description:key representedObject:facade keyPath:settingsKey onTitle:nil offTitle:nil];
            [item setDefaultValue:settingsDefaultValue];
            if ([facade valueForUndefinedKey:settingsKey] == nil){
                [facade setValue:settingsDefaultValue forUndefinedKey:settingsKey];
            }
            
        }
        if(supportsLongPress){
            [item setTarget:self];
            [item setLongPressAction:@selector(longPressAction:)];
        }
        
        TSKKonamiCode *test = [TSKKonamiCode new];
        NSArray *sequence = @[@6,@6,@6];
        [test setSequence:sequence];
        [test setAction:@selector(doRandomAction:)];
        [item addKonamiCode:test];
        [_items addObject:item];
    }];
    
    return [_items sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:TRUE]]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"did select row");
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (TSKTableViewTextCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TSKTableViewTextCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    if (singleEnabledMode){
        NSString *enabledApp = [[facade valueForKey:@"_prefs"] objectForKey:settingsKeyPrefix];
        NSString *cellName = [[cell item] localizedTitle];
        if ([enabledApp isEqualToString:cellName]){
            [cell setAccessoryType:3];
        } else {
            [cell setAccessoryType:0];
        }
    }
    if (_pleaseWaitView){
        UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: 100];
        [view startAnimating];
        [view setColor:[UIColor grayColor]];
        [cell setAccessoryView:view];
    }
    //NSLog(@"cell: %@", cell);
    return cell;
}

- (TVSPreferences *)preferences {
    return [facade valueForKey:@"_prefs"];
}

- (void)rowSelected:(id)sender {
    UITableViewCell *chosenOne = [(TSKTableView*)[self tableView] _focusedCell];//[self cellFromSettingsItem:sender];
    [chosenOne setAccessoryType:3];
    NSString *value = [sender localizedTitle];
    if ([sender keyPath]){
        value = [sender keyPath];
    }
    TVSPreferences *tvprefs = [self preferences];
    [tvprefs setObject:value forKey:settingsKeyPrefix];
    [tvprefs synchronize];
    NSArray *sibs = [chosenOne siblingsInclusive:false];
    [sibs enumerateObjectsUsingBlock:^(TSKTableViewTextCell  *_Nonnull cell, NSUInteger idx, BOOL * _Nonnull stop) {
        [cell setAccessoryType:0];
    }];
}

- (void)loadSpecifier:(NSDictionary *)spec {
    if (_specifierLoaded) return;
    
    supportsLongPress = true;
    useBundleIdentifier = false;
    allProcessesMode = false;
    singleEnabledMode = false;
    NSString *navTitle = spec[@"ALNavigationTitle"];
    if (!navTitle){
        navTitle = spec[@"label"];
    }
    self.title = navTitle;
    settingsDefaultValue = spec[@"ALSettingsDefaultValue"];
    if ([settingsDefaultValue respondsToSelector:@selector(length)]){
        //it should be an integer for on or off!
        settingsDefaultValue = [NSNumber numberWithInteger:[settingsDefaultValue integerValue]];
    }
    settingsPath = spec[@"ALSettingsPath"];
    if ((kCFCoreFoundationVersionNumber >= 1000) && [settingsPath hasPrefix:@"/var/mobile/Library/Preferences/"] && [settingsPath hasSuffix:@".plist"]) {
        _domain = [[settingsPath lastPathComponent] stringByDeletingPathExtension];
    } else {
        _domain = nil;
    }
    NSLog(@"app domain: %@", _domain);
    
    if ([[spec allKeys] containsObject:ALSingleEnabledMode]){
        singleEnabledMode = [spec[ALSingleEnabledMode] boolValue];
    }
    //settingsKeyPrefix = spec[@"ALSettingsKeyPrefix"];
    settingsKeyPrefix = [spec objectForKey:singleEnabledMode ? @"ALSettingsKey" : @"ALSettingsKeyPrefix"] ?: @"ALValue-";
    NSLog(@"settingsKeyPrefix: %@", settingsKeyPrefix);
    if (_domain){
        facade = [[NSClassFromString(@"ALSettingsFacade") alloc] initWithDomain:_domain notifyChanges:TRUE];
    }
    if ([[spec allKeys] containsObject:ALItemSupportsLongPress]){
        supportsLongPress = [spec[ALItemSupportsLongPress] boolValue];
    }
    if ([[spec allKeys] containsObject:ALAllProcessesMode]){
        NSLog(@"all processes mode!");
        allProcessesMode = [spec[ALAllProcessesMode] boolValue];
        _pleaseWaitView = true;
    }
    
    //this was well intentioned by keyPath / key gets screwy because of the periods in the bundleId
    /*
     if ([[spec allKeys] containsObject:ALUseBundleIdentifier]){
     useBundleIdentifier = [spec[ALUseBundleIdentifier] boolValue];
     }*/
    _specifierLoaded = true;
}

- (void)doRandomAction:(id)sender {
    NSLog(@"triggered: %@", sender);
}

- (id)loadingPleaseWaitGroup {
    return [TSKSettingGroup groupWithTitle:@"" settingItems:@[self.loadingItem]];
}

- (void)loadAllProcessSpecifierInBackground:(NSDictionary *)groupDescriptor {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSMutableArray *_items = [NSMutableArray new];
        NSArray *allProcesses = [ALFindProcess allRunningProcesses];
        [allProcesses enumerateObjectsUsingBlock:^(ALRunningProcess  *_Nonnull process, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *title = [process name];
            NSString *desc = [process identifierIfApplicable];
            NSString *key = desc;
            if (!desc){
                desc = [process assetDescription];
                key = [desc lastPathComponent];
            }
            TSKSettingItem *item = nil;
            if (!singleEnabledMode){
                item = [TSKSettingItem toggleItemWithTitle:title description:desc representedObject:facade keyPath:title onTitle:nil offTitle:nil];
                [item setDefaultValue:settingsDefaultValue];
                if ([facade valueForUndefinedKey:key] == nil){
                    [facade setValue:settingsDefaultValue forUndefinedKey:key];
                }
            } else {
                item = [TSKSettingItem actionItemWithTitle:title description:desc representedObject:process keyPath:key target:self action:@selector(rowSelected:)];
            }
            [item setItemIcon:[process icon]];
            if(supportsLongPress){
                [item setTarget:self];
                [item setLongPressAction:@selector(longPressAction:)];
            }
            
            [_items addObject:item];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            _pleaseWaitView = false;
            NSString *groupTitle = groupDescriptor[ALSectionDescriptorTitleKey];
            NSArray *settingsItems = [_items sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:TRUE]]];
            TSKSettingGroup *group = [TSKSettingGroup groupWithTitle:groupTitle settingItems:settingsItems];
            _backingArray = [NSMutableArray new];
            [_backingArray addObject:group];
            [self reloadSettings];
        });
    });
    
}

- (id)loadSettingGroups {
    
    NSDictionary *spec = [self specifier];
    [self loadSpecifier:spec];
    self.sectionDescriptors = spec[@"ALSectionDescriptors"];
    
    if (!self.sectionDescriptors){
        self.sectionDescriptors = [ALRootListController standardSectionDescriptors];
    }
    
    if (allProcessesMode == true){
        self.sectionDescriptors = [ALRootListController processSectionDescriptors];
        if (_pleaseWaitView){
            [self loadAllProcessSpecifierInBackground:self.sectionDescriptors[0]];
            return @[[self loadingPleaseWaitGroup]];
        } else {
            [self setValue:_backingArray forKey:@"_settingGroups"];
            return _backingArray;
        }
    }
    if (!_backingArray){
        _backingArray = [NSMutableArray new];
    } else {
        [_backingArray removeAllObjects];
    }
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
    
    ALApplication *app = nil;
    NSString *ident = [item localizedDescription];
    if ([[item representedObject] isKindOfClass:[ALRunningProcess class]]){
        ALRunningProcess *process = [item representedObject];
        NSLog(@"process: %@", process);
        if ([process associatedApplication]){
            app = [process associatedApplication];
            ident = [app bundleID];
        } else {
            return;
        }
    } else {
        app = [[ALAppManager sharedManager] applicationWithDisplayIdentifier:ident];
    }
    if (!app) {
        NSLog(@"[AppList] no app found!");
        return;
    }
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
    if (_pleaseWaitView){
        item =  (TSKAppIconPreviewViewController*)[[[self navigationController] previousViewController] defaultPreviewViewController];
        [item setDescriptionText:desc];
        return item;
    }
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
