#import "ALRootListController.h"
#import "ALApplicationList.h"
#import "ALAppManager.h"
#import "TVSPreferences.h"
#import "ALFindProcess.h"
#import "UIView+RecursiveFind.h"

@interface UIView (science)
- (NSArray *)siblingsInclusive:(BOOL)include;// inclusive means we include ourselves as well
@end

@implementation UIView (science)
- (NSArray *)siblingsInclusive:(BOOL)include {
    UIView *superview = [self superview];
    if (!superview) return nil;
    if (include){
        return [superview subviews];
    }
    NSMutableArray *sibs = [[superview subviews] mutableCopy];
    [sibs removeObject:self];
    return sibs;
}

@end

@interface TSKTableViewController (science)
- (NSArray *)tableViewCells;
- (UITableViewCell *)cellFromSettingsItem:(TSKSettingItem *)settingsItem;
@end

@implementation TSKTableViewController (science)

-(UITableViewCell *)cellFromSettingsItem:(TSKSettingItem *)settingsItem {
    NSArray *cells = [self tableViewCells];
    __block id object = nil;
    [cells enumerateObjectsUsingBlock:^(TSKTableViewTextCell  *_Nonnull cell, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([cell item] == settingsItem){
            object = cell;
            *stop = true;
        }
    }];
    return object;
}

- (NSArray *)tableViewCells {
    UITableView *tv = [self tableView];
    UITableViewCell *firstCell = (UITableViewCell*)[tv findFirstSubviewWithClass:[UITableViewCell class]];
    if (firstCell){
        return [firstCell siblingsInclusive:true];
    }
    return nil;
}
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
    NSDictionary *apps = [list applicationsFilteredUsingPredicate:predicate onlyVisible:onlyVisible titleSortedIdentifiers:nil];
    [apps enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        TSKSettingItem *item = nil;
        NSString *settingsKey = [settingsKeyPrefix stringByAppendingString:obj];
        if (singleEnabledMode){
            settingsKey = settingsKeyPrefix;
            item = [TSKSettingItem actionItemWithTitle:obj description:key representedObject:facade keyPath:settingsKey target:self action:@selector(rowSelected:)];
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
        //[item setValue:@[test] forKey:@"_konamiCodes"];
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

- (void)rowSelected:(id)sender {
    NSLog(@"rowSelected: %@", sender);
    UITableViewCell *chosenOne = [self cellFromSettingsItem:sender];
    NSLog(@"found the cell: %@", chosenOne);
    [chosenOne setAccessoryType:3];
    NSString *value = [sender localizedTitle];
    TVSPreferences *tvprefs = [facade valueForKey:@"_prefs"];
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
    settingsPath = spec[@"ALSettingsPath"];
    if ((kCFCoreFoundationVersionNumber >= 1000) && [settingsPath hasPrefix:@"/var/mobile/Library/Preferences/"] && [settingsPath hasSuffix:@".plist"]) {
        _domain = [[settingsPath lastPathComponent] stringByDeletingPathExtension];
    } else {
        _domain = nil;
    }
    NSLog(@"app domain: %@", _domain);
    
    if ([[spec allKeys] containsObject:ALSingleEnabledMode]){
        singleEnabledMode = true;
    }
    //settingsKeyPrefix = spec[@"ALSettingsKeyPrefix"];
    settingsKeyPrefix = [spec objectForKey:singleEnabledMode ? @"ALSettingsKey" : @"ALSettingsKeyPrefix"] ?: @"ALValue-";
    NSLog(@"settingsKeyPrefix: %@", settingsKeyPrefix);
    if (_domain){
        facade = [[NSClassFromString(@"TSKPreferencesFacade") alloc] initWithDomain:_domain notifyChanges:TRUE];
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

- (id)loadingCell {
    TSKTableViewTextCell *cell = [[TSKTableViewTextCell alloc] initWithStyle:[TSKTableViewTextCell preferredCellStyle] reuseIdentifier:@"loading-cell"];
    [cell setItem:self.loadingItem];
    [cell _updateTextLabels];
    UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: 100];
    [view startAnimating];
    [view setColor:[UIColor grayColor]];
    [cell setAccessoryView:view];
    return cell;
}

- (id)loadingPleaseWaitGroup {
    NSLog(@"loadingPleaseWaitGroup");
    return [TSKSettingGroup groupWithTitle:@"" settingItems:@[self.loadingItem]];
}

- (void)loadAllProcessSpecifierInBackground:(NSDictionary *)groupDescriptor {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"loadAllProcessSpecifierInBackground");
        NSMutableArray *_items = [NSMutableArray new];
        NSArray *allProcesses = [ALFindProcess allRunningProcesses];
        [allProcesses enumerateObjectsUsingBlock:^(ALRunningProcess  *_Nonnull process, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *title = [process name];
            NSString *key = [process identifierIfApplicable];
            if (!key){
                key = [process assetDescription];
            }
            TSKSettingItem *item = nil;
            if (!singleEnabledMode){
                item = [TSKSettingItem toggleItemWithTitle:title description:key representedObject:facade keyPath:key onTitle:nil offTitle:nil];
                [item setDefaultValue:settingsDefaultValue];
                if ([facade valueForUndefinedKey:key] == nil){
                    [facade setValue:settingsDefaultValue forUndefinedKey:key];
                }
            } else {
                item = [TSKSettingItem actionItemWithTitle:title description:key representedObject:process keyPath:nil target:self action:@selector(rowSelected:)];
            }
            [item setItemIcon:[process icon]];
            if(supportsLongPress){
                [item setTarget:self];
                [item setLongPressAction:@selector(longPressAction:)];
            }
            
            [_items addObject:item];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"out here?");
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
    //ALApplication *app = [[ALAppManager sharedManager] applicationWithDisplayIdentifier:ident];
    
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
