#import "ALApplicationList-private.h"

#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import "ALAppManager.h"
#import "ALApplication.h"

NSString *const ALIconLoadedNotification = @"ALIconLoadedNotification";
NSString *const ALDisplayIdentifierKey = @"ALDisplayIdentifier";
NSString *const ALIconSizeKey = @"ALIconSize";

static ALApplicationList *sharedApplicationList;
static NSMutableDictionary *cachedIcons;

@implementation ALApplicationList

static inline NSMutableDictionary *dictionaryOfApplicationsList(id<NSFastEnumeration> applications)
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (ALApplication *app in applications) {
        NSString *displayName = [[app displayName] description];
        if (displayName) {
            NSString *displayIdentifier = [[app displayIdentifier] description];
            if (displayIdentifier) {
                [result setObject:displayName forKey:displayIdentifier];
            }
        }
    }
    return result;
}

static NSInteger DictionaryTextComparator(id a, id b, void *context) {
    return [[(__bridge NSDictionary *)context objectForKey:a] localizedCaseInsensitiveCompare:[(__bridge NSDictionary *)context objectForKey:b]];
}

+ (void)initialize
{
    if (self == [ALApplicationList class]) { //} && !%c(SBIconModel)) {
        sharedApplicationList = [[self alloc] init];
    }
}

+ (ALApplicationList *)sharedApplicationList
{
    return sharedApplicationList;
}

- (id)init{
    if ((self = [super init])) {
        if (sharedApplicationList) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Only one instance of ALApplicationList is permitted at a time! Use [ALApplicationList sharedApplicationList] instead." userInfo:nil];
        }
        @autoreleasepool {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        }
    }
    return self;
}

- (NSInteger)applicationCount {
    return [[[ALAppManager sharedManager] allInstalledApplications] count];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<ALApplicationList: %p applicationCount=%ld>", self, (long)self.applicationCount];
}

- (void)didReceiveMemoryWarning{
    cachedIcons = nil;
}

- (NSDictionary *)applications {
    return dictionaryOfApplicationsList([[ALAppManager sharedManager] allInstalledApplications]);
}


- (NSDictionary *)applicationsFilteredUsingPredicate:(NSPredicate *)predicate {
    NSArray *apps = [[ALAppManager sharedManager] allInstalledApplications];
    if (predicate)
        apps = [apps filteredArrayUsingPredicate:predicate];
    return dictionaryOfApplicationsList(apps);
}
- (NSDictionary *)applicationsFilteredUsingPredicate:(NSPredicate *)predicate onlyVisible:(BOOL)onlyVisible titleSortedIdentifiers:(NSArray **)outSortedByTitle {
    NSArray *apps = [[ALAppManager sharedManager] allInstalledApplications];
    if (predicate)
        apps = [apps filteredArrayUsingPredicate:predicate];
    NSMutableDictionary *result;
    if (onlyVisible) {
        result = dictionaryOfApplicationsList([[ALAppManager sharedManager] applicationsFromArray:apps filterHidden:TRUE]);
    } else {
        result = dictionaryOfApplicationsList(apps);
    }
    if (outSortedByTitle) {
        // Generate a sorted list of apps
        *outSortedByTitle = [[result allKeys] sortedArrayUsingFunction:DictionaryTextComparator context:(__bridge void * _Nullable)(result)];
    }
    return result;
}

- (id)valueForKeyPath:(NSString *)keyPath forDisplayIdentifier:(NSString *)displayIdentifier {
    ALApplication *app = [[ALAppManager sharedManager] applicationWithDisplayIdentifier:displayIdentifier];
    return [app valueForKeyPath:keyPath];
}
- (id)valueForKey:(NSString *)keyPath forDisplayIdentifier:(NSString *)displayIdentifier {
    ALApplication *app = [[ALAppManager sharedManager] applicationWithDisplayIdentifier:displayIdentifier];
    return [app valueForKey:keyPath];
}
- (BOOL)applicationWithDisplayIdentifierIsHidden:(NSString *)displayIdentifier {
    ALApplication *app = [[ALAppManager sharedManager] applicationWithDisplayIdentifier:displayIdentifier];
    return [app hidden];
}

- (CGImageRef)copyIconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier {
    
    NSString *key = [displayIdentifier stringByAppendingFormat:@"#%f", (CGFloat)iconSize];
    CGImageRef result = (__bridge CGImageRef)[cachedIcons objectForKey:key];
    if (result) {
        result = CGImageRetain(result);
        return result;
    }
    if (!cachedIcons) {
        cachedIcons = [[NSMutableDictionary alloc] init];
    }
    ALApplication *app = [[ALAppManager sharedManager] applicationWithDisplayIdentifier:displayIdentifier];
    UIImage *image = [app icon];
    result = [image CGImage];
    [cachedIcons setObject:(__bridge id)result forKey:key];
    return CGImageRetain([image CGImage]);
}
- (UIImage *)iconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier {

    CGImageRef image = [self copyIconOfSize:iconSize forDisplayIdentifier:displayIdentifier];
    if (!image)
        return nil;
    UIImage *result;
    if ([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]) {
        CGFloat scale = (CGImageGetWidth(image) + CGImageGetHeight(image)) / (CGFloat)(iconSize + iconSize);
        result = [UIImage imageWithCGImage:image scale:scale orientation:0];
    } else {
        result = [UIImage imageWithCGImage:image];
    }
    CGImageRelease(image);
    return result;
}
- (BOOL)hasCachedIconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier {
    NSString *key = [displayIdentifier stringByAppendingFormat:@"#%f", (CGFloat)iconSize];
    id result = [cachedIcons objectForKey:key];
    return result != nil;
}

- (void)postNotificationWithUserInfo:(NSDictionary *)userInfo {
    [[NSNotificationCenter defaultCenter] postNotificationName:ALIconLoadedNotification object:self userInfo:userInfo];
}

@end

