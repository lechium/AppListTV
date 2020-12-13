#import "ALRootListController.h"


// All preferences on tvOS are added in programatically in groups.

@implementation ALRootListController

// this is to make sure our tweak's property list is loaded and all settings values are changed.
inline NSString *GetPrefVal(NSString *key){
    return [[NSDictionary dictionaryWithContentsOfFile:PLIST_PATH] valueForKey:key];
}


// Lets load our prefs!
- (id)loadSettingGroups {
    
    id facade = [[NSClassFromString(@"TVSettingsPreferenceFacade") alloc] initWithDomain:@"com.nito.applist" notifyChanges:TRUE];
    
    NSMutableArray *_backingArray = [NSMutableArray new];
    
    // to add more settings add them like so...
    kEnabled = [TSKSettingItem toggleItemWithTitle:@"Enable Tweak" description:@"" representedObject:facade keyPath:@"kEnabled" onTitle:@"Enabled" offTitle:@"Disabled"];
    
    
    // Respring Button here baby!
    kRespringButton = [TSKSettingItem actionItemWithTitle:@"Respring" description:@"Apply Changes with a Respring!" representedObject:facade keyPath:PLIST_PATH target:self action:@selector(respring)];
    
    
    // you add your settings to a group basically an NSArray so the Settings app can see them.
    TSKSettingGroup *group = [TSKSettingGroup groupWithTitle:@"Enable Tweak" settingItems:@[kEnabled]];
    
    
    TSKSettingGroup *group2 = [TSKSettingGroup groupWithTitle:@"Apply Changes" settingItems:@[kRespringButton]];
    
    [_backingArray addObject:group];
    [_backingArray addObject:group2];
    
    [self setValue:_backingArray forKey:@"_settingGroups"];
    
    return _backingArray;
    
}


-(void)respring {
    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:@"/usr/bin/killall"];
    [task setArguments:[NSArray arrayWithObjects:@"backboardd", nil]];
    [task launch];
    
}

// this is to make sure our preferences our loaded
- (TVSPreferences *)ourPreferences {
    return [TVSPreferences preferencesWithDomain:@"com.nito.applist"];
}


// This is to show our preferences in the tweaks section of tvOS.
- (void)showViewController:(TSKSettingItem *)item {
    TSKTextInputViewController *testObject = [[TSKTextInputViewController alloc] init];
    
    testObject.headerText = @"AppList";
    testObject.initialText = [[self ourPreferences] stringForKey:item.keyPath];
    
    if ([testObject respondsToSelector:@selector(setEditingDelegate:)]){
        [testObject setEditingDelegate:self];
    }
    [testObject setEditingItem:item];
    [self.navigationController pushViewController:testObject animated:TRUE];
}

- (void)editingController:(id)arg1 didCancelForSettingItem:(TSKSettingItem *)arg2 {
    [super editingController:arg1 didCancelForSettingItem:arg2];
}
- (void)editingController:(id)arg1 didProvideValue:(id)arg2 forSettingItem:(TSKSettingItem *)arg3 {
    [super editingController:arg1 didProvideValue:arg2 forSettingItem:arg3];
    
    TVSPreferences *prefs = [TVSPreferences preferencesWithDomain:@"com.nito.applist"];
    
    [prefs setObject:arg2 forKey:arg3.keyPath];
    [prefs synchronize];
    
}


// This is to show our tweak's icon instead of the boring Apple TV logo :)
-(id)previewForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    TSKPreviewViewController *item = [super previewForItemAtIndexPath:indexPath];
    
    NSString *imagePath = [[NSBundle bundleForClass:self.class] pathForResource:@"icon" ofType:@"png"];
    UIImage *icon = [UIImage imageWithContentsOfFile:imagePath];
    if (icon != nil) {
        TSKVibrantImageView *imageView = [[TSKVibrantImageView alloc] initWithImage:icon];
        [item setContentView:imageView];
        
    }
    
    return item;
    
}

@end
