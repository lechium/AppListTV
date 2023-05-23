
#import <Foundation/Foundation.h>

@interface NSFileManager(Util)

- (NSNumber *)sizeForFolderAtPath:(NSString *)source error:(NSError **)error;

@end
