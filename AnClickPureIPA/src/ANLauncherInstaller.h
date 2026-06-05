#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ANLauncherInstaller : NSObject

+ (NSArray<NSString *> *)candidateInjectionDirectories;
+ (NSString *)installedStatusText;
+ (BOOL)loadBundledDylibWithLog:(void (^ _Nullable)(NSString *message))logBlock;
+ (BOOL)showLoadedPanelWithLog:(void (^ _Nullable)(NSString *message))logBlock;
+ (BOOL)installBundledDylibWithLog:(void (^ _Nullable)(NSString *message))logBlock;

@end

NS_ASSUME_NONNULL_END
