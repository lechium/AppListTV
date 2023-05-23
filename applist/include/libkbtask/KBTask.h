#import "NSTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface KBTask : NSObject
- (id)init;

// set parameters
// these methods can only be done before a launch
- (void)setLaunchPath:(NSString *)path;
- (void)setArguments:(NSArray *)arguments;
- (void)setEnvironment:(NSDictionary *)dict;
    // if not set, use current
- (void)setCurrentDirectoryPath:(NSString *)path;
    // if not set, use current

// set standard I/O channels; may be either an NSFileHandle or an NSPipe
- (void)setStandardInput:(id)input;
- (void)setStandardOutput:(id)output;
- (void)setStandardError:(id)error;

// get parameters
- (NSString *)launchPath;
- (NSArray *)arguments;
- (NSDictionary *)environment;
- (NSString *)currentDirectoryPath;

// get standard I/O channels; could be either an NSFileHandle or an NSPipe
- (id)standardInput;
- (id)standardOutput;
- (id)standardError;

// actions
- (void)launch;

- (void)interrupt; // Not always possible. Sends SIGINT.
- (void)terminate; // Not always possible. Sends SIGTERM.

- (BOOL)suspend;
- (BOOL)resume;

// status
- (int)processIdentifier;
- (BOOL)isRunning;

- (int)terminationStatus;
@property(readonly) long long terminationReason;
@end

@interface KBTask (KBTaskConveniences)

+ (NSTask *)launchedTaskWithLaunchPath:(NSString *)path arguments:(NSArray *)arguments;
    // convenience; create and launch

- (void)waitUntilExit;
    // poll the runLoop in defaultMode until task completes

@end

NS_ASSUME_NONNULL_END
