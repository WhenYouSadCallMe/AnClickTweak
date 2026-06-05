#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ANLauncherInstaller : NSObject

+ (NSArray<NSString *> *)candidateInjectionDirectories;
+ (NSString *)installedStatusText;
+ (BOOL)installBundledDylibWithLog:(void (^)(NSString *message))logBlock;

@end

NS_ASSUME_NONNULL_END
