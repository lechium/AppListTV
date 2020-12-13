
#import "NSFileManager+size.h"

@implementation NSFileManager(Util)

- (NSNumber *)sizeForFolderAtPath:(NSString *) source error:(NSError **)error
{
    NSArray * contents;
    unsigned long long size = 0;
    NSEnumerator * enumerator;
    NSString * path;
    BOOL isDirectory;
    
    // Determine Paths to Add
    if ([self fileExistsAtPath:source isDirectory:&isDirectory] && isDirectory)
    {
        contents = [self subpathsAtPath:source];
    }
    else
    {
        contents = [NSArray array];
    }
    // Add Size Of All Paths
    enumerator = [contents objectEnumerator];
    while (path = [enumerator nextObject])
    {
        NSDictionary * fattrs = [self attributesOfItemAtPath: [ source stringByAppendingPathComponent:path ] error:error];
        size += [[fattrs objectForKey:NSFileSize] unsignedLongLongValue];
    }
    // Return Total Size in MB
    
    return [ NSNumber numberWithUnsignedLongLong:size/1024/1024];
}

@end
