#import "ANLauncherInstaller.h"
#import <dlfcn.h>
#import <sys/stat.h>
#import <spawn.h>

extern char **environ;

@implementation ANLauncherInstaller

static void *ANLauncherLoadedDylibHandle = NULL;

+ (NSArray<NSString *> *)candidateInjectionDirectories {
    return @[
        @"/var/jb/Library/MobileSubstrate/DynamicLibraries",
        @"/var/jb/Library/TweakInject",
        @"/var/jb/usr/lib/TweakInject",
        @"/Library/MobileSubstrate/DynamicLibraries",
        @"/Library/TweakInject",
        @"/usr/lib/TweakInject",
    ];
}

+ (NSString *)bundledDylibPath {
    return [NSBundle.mainBundle pathForResource:@"AnClick" ofType:@"dylib"] ?: @"";
}

+ (NSString *)bundledFilterPath {
    return [NSBundle.mainBundle pathForResource:@"Filter" ofType:@"plist"] ?: @"";
}

+ (BOOL)fileExistsAtPath:(NSString *)path {
    return path.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:path];
}

+ (NSString *)installedStatusText {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *bundleState = [self fileExistsAtPath:[self bundledDylibPath]] ? @"IPA内置dylib: 有" : @"IPA内置dylib: 无";
    [parts addObject:bundleState];
    NSString *processState = NSClassFromString(@"AnClickUI") ? @"当前进程悬浮窗: 可用" : @"当前进程悬浮窗: 未加载";
    [parts addObject:processState];
    NSUInteger installedCount = 0;
    for (NSString *directory in [self candidateInjectionDirectories]) {
        NSString *dylibPath = [directory stringByAppendingPathComponent:@"AnClick.dylib"];
        NSString *filterPath = [directory stringByAppendingPathComponent:@"AnClick.plist"];
        if ([self fileExistsAtPath:dylibPath] && [self fileExistsAtPath:filterPath]) {
            installedCount++;
            [parts addObject:[NSString stringWithFormat:@"已安装: %@", directory]];
        }
    }
    if (installedCount == 0) {
        [parts addObject:@"未发现已安装注入文件"];
    }
    return [parts componentsJoinedByString:@"\n"];
}

+ (BOOL)copyItemAtPath:(NSString *)sourcePath toPath:(NSString *)targetPath permissions:(NSNumber *)permissions log:(void (^)(NSString *message))logBlock {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    if (![fileManager fileExistsAtPath:sourcePath]) {
        if (logBlock) {
            logBlock([NSString stringWithFormat:@"源文件不存在: %@", sourcePath]);
        }
        return NO;
    }

    NSError *error = nil;
    if ([fileManager fileExistsAtPath:targetPath] && ![fileManager removeItemAtPath:targetPath error:&error]) {
        if (logBlock) {
            logBlock([NSString stringWithFormat:@"删除旧文件失败: %@ %@", targetPath, error.localizedDescription ?: @""]);
        }
        return NO;
    }
    error = nil;
    if (![fileManager copyItemAtPath:sourcePath toPath:targetPath error:&error]) {
        if (logBlock) {
            logBlock([NSString stringWithFormat:@"复制失败: %@ %@", targetPath, error.localizedDescription ?: @""]);
        }
        return NO;
    }
    if (permissions) {
        NSError *permissionError = nil;
        if (![fileManager setAttributes:@{NSFilePosixPermissions: permissions} ofItemAtPath:targetPath error:&permissionError] && logBlock) {
            logBlock([NSString stringWithFormat:@"设置权限失败: %@ %@", targetPath, permissionError.localizedDescription ?: @""]);
        }
    }
    if (![fileManager fileExistsAtPath:targetPath]) {
        if (logBlock) {
            logBlock([NSString stringWithFormat:@"复制后未找到目标文件: %@", targetPath]);
        }
        return NO;
    }
    return YES;
}

+ (BOOL)directoryLooksInstallable:(NSString *)directory log:(void (^)(NSString *message))logBlock {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:directory isDirectory:&isDirectory] && isDirectory) {
        return YES;
    }

    NSString *requiredRoot = nil;
    if ([directory hasPrefix:@"/var/jb/"]) {
        requiredRoot = @"/var/jb";
    } else if ([directory hasPrefix:@"/usr/lib/"]) {
        requiredRoot = @"/usr/lib";
    } else if ([directory hasPrefix:@"/Library/"]) {
        requiredRoot = @"/Library";
    }

    BOOL rootIsDirectory = NO;
    if (requiredRoot.length > 0 && (![fileManager fileExistsAtPath:requiredRoot isDirectory:&rootIsDirectory] || !rootIsDirectory)) {
        if (logBlock) {
            logBlock([NSString stringWithFormat:@"跳过不存在的注入环境: %@", directory]);
        }
        return NO;
    }

    NSError *createError = nil;
    if (![fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&createError]) {
        if (logBlock) {
            logBlock([NSString stringWithFormat:@"目录不可写: %@ %@", directory, createError.localizedDescription ?: @""]);
        }
        return NO;
    }
    return YES;
}

+ (BOOL)loadBundledDylibWithLog:(void (^ _Nullable)(NSString *message))logBlock {
    if (NSClassFromString(@"AnClickUI")) {
        if (logBlock) {
            logBlock(@"AnClickUI 已存在，直接使用当前进程里的悬浮窗");
        }
        return YES;
    }

    if (ANLauncherLoadedDylibHandle) {
        if (logBlock) {
            logBlock(@"内置 dylib 已加载");
        }
        return YES;
    }

    NSString *sourceDylib = [self bundledDylibPath];
    if (![self fileExistsAtPath:sourceDylib]) {
        if (logBlock) {
            logBlock(@"IPA 内没有 AnClick.dylib，无法显示同款悬浮窗");
        }
        return NO;
    }

    ANLauncherLoadedDylibHandle = dlopen(sourceDylib.UTF8String, RTLD_NOW | RTLD_GLOBAL);
    if (!ANLauncherLoadedDylibHandle) {
        if (logBlock) {
            const char *error = dlerror();
            NSString *errorText = error ? [NSString stringWithUTF8String:error] : @"未知错误";
            logBlock([NSString stringWithFormat:@"加载内置 dylib 失败: %@", errorText]);
        }
        return NO;
    }

    if (logBlock) {
        logBlock(@"已加载内置 dylib，悬浮窗会按注入版逻辑显示");
    }
    return YES;
}

+ (BOOL)showLoadedPanelWithLog:(void (^ _Nullable)(NSString *message))logBlock {
    if (![self loadBundledDylibWithLog:logBlock]) {
        return NO;
    }

    Class uiClass = NSClassFromString(@"AnClickUI");
    SEL sharedSelector = NSSelectorFromString(@"shared");
    if (!uiClass || ![uiClass respondsToSelector:sharedSelector]) {
        if (logBlock) {
            logBlock(@"内置 dylib 已加载，但没有找到 AnClickUI");
        }
        return NO;
    }

    id (*sharedIMP)(id, SEL) = (id (*)(id, SEL))[uiClass methodForSelector:sharedSelector];
    id ui = sharedIMP ? sharedIMP(uiClass, sharedSelector) : nil;
    SEL showSelector = NSSelectorFromString(@"show");
    if (!ui || ![ui respondsToSelector:showSelector]) {
        if (logBlock) {
            logBlock(@"内置 dylib 已加载，但无法调用悬浮窗");
        }
        return NO;
    }

    void (*showIMP)(id, SEL) = (void (*)(id, SEL))[ui methodForSelector:showSelector];
    if (!showIMP) {
        if (logBlock) {
            logBlock(@"内置 dylib 已加载，但悬浮窗入口不可用");
        }
        return NO;
    }

    showIMP(ui, showSelector);
    if (logBlock) {
        logBlock(@"已调用同款悬浮窗");
    }
    return YES;
}

+ (BOOL)installBundledDylibWithLog:(void (^ _Nullable)(NSString *message))logBlock {
    NSString *sourceDylib = [self bundledDylibPath];
    NSString *sourceFilter = [self bundledFilterPath];
    if (![self fileExistsAtPath:sourceDylib]) {
        if (logBlock) {
            logBlock(@"IPA 内没有 AnClick.dylib，请先用 GitHub Actions 产物安装");
        }
        return NO;
    }
    if (![self fileExistsAtPath:sourceFilter]) {
        if (logBlock) {
            logBlock(@"IPA 内没有 Filter.plist，无法安装注入规则");
        }
        return NO;
    }

    NSUInteger installCount = 0;
    for (NSString *directory in [self candidateInjectionDirectories]) {
        if (![self directoryLooksInstallable:directory log:logBlock]) {
            continue;
        }

        NSString *targetDylib = [directory stringByAppendingPathComponent:@"AnClick.dylib"];
        NSString *targetFilter = [directory stringByAppendingPathComponent:@"AnClick.plist"];
        NSNumber *dylibPermissions = @(S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
        NSNumber *filterPermissions = @(S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
        BOOL copiedDylib = [self copyItemAtPath:sourceDylib toPath:targetDylib permissions:dylibPermissions log:logBlock];
        BOOL copiedFilter = copiedDylib && [self copyItemAtPath:sourceFilter toPath:targetFilter permissions:filterPermissions log:logBlock];
        if (copiedDylib && copiedFilter) {
            installCount++;
            if (logBlock) {
                logBlock([NSString stringWithFormat:@"已安装到: %@", directory]);
            }
        }
    }

    if (installCount > 0) {
        if (logBlock) {
            logBlock([NSString stringWithFormat:@"安装完成，共 %lu 个注入目录", (unsigned long)installCount]);
            logBlock(@"请重启界面或 respring，让 SpringBoard 和目标 App 重新加载 AnClick.dylib");
        }
        return YES;
    }

    if (logBlock) {
        logBlock(@"安装失败：没有可写注入目录。纯 TrollStore 只能内置文件，仍需要设备有可加载 dylib 的注入环境。");
    }
    return NO;
}

+ (BOOL)restartSpringBoardWithLog:(void (^ _Nullable)(NSString *message))logBlock {
    NSArray<NSString *> *commands = @[
        @"/usr/bin/sbreload",
        @"/var/jb/usr/bin/sbreload",
        @"/usr/bin/killall",
        @"/var/jb/usr/bin/killall",
    ];

    NSFileManager *fileManager = NSFileManager.defaultManager;
    for (NSString *command in commands) {
        if (![fileManager fileExistsAtPath:command]) {
            continue;
        }

        pid_t pid = 0;
        int status = 0;
        if ([command hasSuffix:@"sbreload"]) {
            char *argv[] = {(char *)command.UTF8String, NULL};
            status = posix_spawn(&pid, command.UTF8String, NULL, NULL, argv, environ);
        } else {
            char *argv[] = {(char *)command.UTF8String, "SpringBoard", NULL};
            status = posix_spawn(&pid, command.UTF8String, NULL, NULL, argv, environ);
        }

        if (status == 0) {
            if (logBlock) {
                logBlock([NSString stringWithFormat:@"已请求重启界面: %@", command]);
            }
            return YES;
        }

        if (logBlock) {
            logBlock([NSString stringWithFormat:@"重启命令失败: %@ (%d)", command, status]);
        }
    }

    if (logBlock) {
        logBlock(@"未找到 sbreload/killall，请手动 respring 或重启目标 App");
    }
    return NO;
}

@end
