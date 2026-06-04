#import "ANTaskRunner.h"
#import "ANSystemTouch.h"

@interface AnClickCore : NSObject
+ (NSDictionary *)findTemplateImageMatch:(UIImage *)templateImage threshold:(double)threshold;
+ (NSDictionary *)findColorMatchWithRed:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue tolerance:(double)tolerance;
+ (NSDictionary *)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points tolerance:(double)tolerance;
@end

@interface AnClickOCR : NSObject
+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode;
@end

typedef NS_ENUM(NSInteger, ANPureActionMode) {
    ANPureActionModeTap = 0,
    ANPureActionModeDoubleTap = 1,
    ANPureActionModeLongPress = 2,
    ANPureActionModeSwipe = 3,
    ANPureActionModeImage = 8,
    ANPureActionModeMacro = 9,
    ANPureActionModeOCR = 10,
    ANPureActionModeColor = 11,
    ANPureActionModeNetwork = 12,
};

@interface ANTaskRunner ()
@property (nonatomic, assign, getter=isRunning) BOOL running;
@property (nonatomic, strong) NSArray<NSDictionary *> *tasks;
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTask;
@end

@implementation ANTaskRunner

- (instancetype)init {
    self = [super init];
    if (self) {
        _backgroundTask = UIBackgroundTaskInvalid;
    }
    return self;
}

- (void)log:(NSString *)message {
    NSLog(@"[AnClickPureIPA] %@", message);
    if (self.logBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.logBlock(message);
        });
    }
}

- (NSString *)trimmedString:(id)value {
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (double)doubleValueForTask:(NSDictionary *)task key:(NSString *)key fallback:(double)fallback {
    id value = task[key];
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : fallback;
}

- (NSInteger)integerValueForTask:(NSDictionary *)task key:(NSString *)key fallback:(NSInteger)fallback {
    id value = task[key];
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : fallback;
}

- (ANPureActionMode)modeForTask:(NSDictionary *)task {
    id rawMode = task[@"mode"];
    if ([rawMode respondsToSelector:@selector(integerValue)]) {
        return (ANPureActionMode)[rawMode integerValue];
    }
    NSString *mode = [[self trimmedString:rawMode] lowercaseString];
    if ([mode isEqualToString:@"tap"] || [mode isEqualToString:@"点击"]) {
        return ANPureActionModeTap;
    }
    if ([mode isEqualToString:@"doubletap"] || [mode isEqualToString:@"double_tap"] || [mode isEqualToString:@"双击"]) {
        return ANPureActionModeDoubleTap;
    }
    if ([mode isEqualToString:@"longpress"] || [mode isEqualToString:@"long_press"] || [mode isEqualToString:@"长按"]) {
        return ANPureActionModeLongPress;
    }
    if ([mode isEqualToString:@"swipe"] || [mode isEqualToString:@"滑动"]) {
        return ANPureActionModeSwipe;
    }
    if ([mode isEqualToString:@"image"] || [mode isEqualToString:@"识图"]) {
        return ANPureActionModeImage;
    }
    if ([mode isEqualToString:@"ocr"] || [mode isEqualToString:@"text"] || [mode isEqualToString:@"识字"]) {
        return ANPureActionModeOCR;
    }
    if ([mode isEqualToString:@"color"] || [mode isEqualToString:@"识色"]) {
        return ANPureActionModeColor;
    }
    if ([mode isEqualToString:@"network"] || [mode isEqualToString:@"网络"]) {
        return ANPureActionModeNetwork;
    }
    return ANPureActionModeTap;
}

- (ANPureActionMode)successActionModeForTask:(NSDictionary *)task {
    id rawActionMode = task[@"imageActionMode"];
    if ([rawActionMode respondsToSelector:@selector(integerValue)]) {
        return (ANPureActionMode)[rawActionMode integerValue];
    }
    NSString *action = [[self trimmedString:task[@"action"]] lowercaseString];
    if ([action isEqualToString:@"network"] || [action isEqualToString:@"网络"]) {
        return ANPureActionModeNetwork;
    }
    if ([action isEqualToString:@"doubletap"] || [action isEqualToString:@"double_tap"] || [action isEqualToString:@"双击"]) {
        return ANPureActionModeDoubleTap;
    }
    if ([action isEqualToString:@"longpress"] || [action isEqualToString:@"long_press"] || [action isEqualToString:@"长按"]) {
        return ANPureActionModeLongPress;
    }
    if ([action isEqualToString:@"swipe"] || [action isEqualToString:@"滑动"]) {
        return ANPureActionModeSwipe;
    }
    return ANPureActionModeTap;
}

- (CGPoint)pointForTask:(NSDictionary *)task fallback:(CGPoint)fallback {
    id pointValue = task[@"point"];
    if ([pointValue isKindOfClass:NSValue.class]) {
        return [pointValue CGPointValue];
    }
    BOOL hasX = [task[@"x"] respondsToSelector:@selector(doubleValue)] || [task[@"pointX"] respondsToSelector:@selector(doubleValue)];
    BOOL hasY = [task[@"y"] respondsToSelector:@selector(doubleValue)] || [task[@"pointY"] respondsToSelector:@selector(doubleValue)];
    if (hasX && hasY) {
        CGFloat x = [task[@"x"] respondsToSelector:@selector(doubleValue)] ? [task[@"x"] doubleValue] : [task[@"pointX"] doubleValue];
        CGFloat y = [task[@"y"] respondsToSelector:@selector(doubleValue)] ? [task[@"y"] doubleValue] : [task[@"pointY"] doubleValue];
        return CGPointMake(x, y);
    }
    return fallback;
}

- (NSString *)documentsPathForFileName:(NSString *)fileName {
    NSURL *documentsURL = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[documentsURL path] stringByAppendingPathComponent:fileName ?: @""];
}

- (UIImage *)templateImageForTask:(NSDictionary *)task {
    NSString *templatePath = [self trimmedString:task[@"templatePath"]];
    if (templatePath.length == 0) {
        NSString *templateName = [self trimmedString:task[@"templateName"]];
        if (templateName.length > 0) {
            templatePath = [self documentsPathForFileName:templateName];
        }
    }
    if (templatePath.length > 0) {
        UIImage *image = [UIImage imageWithContentsOfFile:templatePath];
        if (image) {
            return image;
        }
    }
    NSString *base64 = [self trimmedString:task[@"templateBase64"]];
    if (base64.length > 0) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:base64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
        if (data.length > 0) {
            return [UIImage imageWithData:data];
        }
    }
    return nil;
}

- (void)beginBackgroundTask {
    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        return;
    }
    self.backgroundTask = [UIApplication.sharedApplication beginBackgroundTaskWithName:@"AnClickPureIPA.Runner" expirationHandler:^{
        [self log:@"后台时间结束，已停止"];
        [self stop];
    }];
}

- (void)endBackgroundTask {
    if (self.backgroundTask == UIBackgroundTaskInvalid) {
        return;
    }
    [UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];
    self.backgroundTask = UIBackgroundTaskInvalid;
}

- (void)startWithTasks:(NSArray<NSDictionary *> *)tasks startDelay:(NSTimeInterval)startDelay {
    if (tasks.count == 0) {
        [self log:@"任务为空，无法运行"];
        return;
    }
    self.tasks = [tasks copy];
    self.running = YES;
    self.generation++;
    NSUInteger generation = self.generation;
    [self beginBackgroundTask];
    if (self.stateBlock) {
        self.stateBlock(YES);
    }
    [self log:[NSString stringWithFormat:@"准备运行 %lu 个任务，%.1f 秒后开始", (unsigned long)tasks.count, MAX(0.0, startDelay)]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0.0, startDelay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.running || generation != self.generation) {
            return;
        }
        [self runTaskAtIndex:0 generation:generation];
    });
}

- (void)stop {
    if (!self.running) {
        return;
    }
    self.running = NO;
    self.generation++;
    [self endBackgroundTask];
    [self log:@"已停止"];
    if (self.stateBlock) {
        self.stateBlock(NO);
    }
}

- (void)finishIfNeededWithGeneration:(NSUInteger)generation {
    if (!self.running || generation != self.generation) {
        return;
    }
    self.running = NO;
    [self endBackgroundTask];
    [self log:@"全部任务完成"];
    if (self.stateBlock) {
        self.stateBlock(NO);
    }
}

- (void)runTaskAtIndex:(NSUInteger)index generation:(NSUInteger)generation {
    if (!self.running || generation != self.generation) {
        return;
    }
    if (index >= self.tasks.count) {
        [self finishIfNeededWithGeneration:generation];
        return;
    }
    NSDictionary *task = self.tasks[index];
    NSTimeInterval delay = MAX(0.0, [self doubleValueForTask:task key:@"delay" fallback:0.0]);
    NSString *desc = [self trimmedString:task[@"desc"]];
    if (desc.length == 0) {
        desc = [self titleForTask:task index:index];
    }
    [self log:[NSString stringWithFormat:@"任务%lu：%@", (unsigned long)index + 1, desc]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.running || generation != self.generation) {
            return;
        }
        [self performTask:task index:index generation:generation completion:^(BOOL continueRun) {
            if (!self.running || generation != self.generation) {
                return;
            }
            if (!continueRun) {
                [self log:@"当前任务不满足，停止后续任务"];
                [self stop];
                return;
            }
            [self runTaskAtIndex:index + 1 generation:generation];
        }];
    });
}

- (NSString *)titleForTask:(NSDictionary *)task index:(NSUInteger)index {
    switch ([self modeForTask:task]) {
        case ANPureActionModeTap:
            return @"点击";
        case ANPureActionModeDoubleTap:
            return @"双击";
        case ANPureActionModeLongPress:
            return @"长按";
        case ANPureActionModeSwipe:
            return @"滑动";
        case ANPureActionModeImage:
            return @"识图";
        case ANPureActionModeOCR:
            return [NSString stringWithFormat:@"识字 %@", [self trimmedString:task[@"text"]].length ? [self trimmedString:task[@"text"]] : [self trimmedString:task[@"ocrText"]]];
        case ANPureActionModeColor:
            return @"识色";
        case ANPureActionModeNetwork:
            return @"网络";
        default:
            return [NSString stringWithFormat:@"任务%lu", (unsigned long)index + 1];
    }
}

- (void)performTask:(NSDictionary *)task index:(NSUInteger)index generation:(NSUInteger)generation completion:(void (^)(BOOL continueRun))completion {
    NSInteger repeat = MAX(1, [self integerValueForTask:task key:@"repeat" fallback:1]);
    [self performTask:task repeatIndex:0 repeatCount:repeat generation:generation completion:completion];
}

- (void)performTask:(NSDictionary *)task repeatIndex:(NSInteger)repeatIndex repeatCount:(NSInteger)repeatCount generation:(NSUInteger)generation completion:(void (^)(BOOL continueRun))completion {
    if (!self.running || generation != self.generation) {
        return;
    }
    [self performSingleTask:task generation:generation completion:^(BOOL continueRun) {
        if (!continueRun || repeatIndex + 1 >= repeatCount) {
            completion(continueRun);
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.16 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self performTask:task repeatIndex:repeatIndex + 1 repeatCount:repeatCount generation:generation completion:completion];
        });
    }];
}

- (void)performSingleTask:(NSDictionary *)task generation:(NSUInteger)generation completion:(void (^)(BOOL continueRun))completion {
    switch ([self modeForTask:task]) {
        case ANPureActionModeTap: {
            CGPoint point = [self pointForTask:task fallback:CGPointZero];
            [self log:[NSString stringWithFormat:@"点击 %.0f, %.0f", point.x, point.y]];
            [ANSystemTouch tapAtPoint:point];
            [self finishAfter:0.22 completion:completion];
            break;
        }
        case ANPureActionModeDoubleTap: {
            CGPoint point = [self pointForTask:task fallback:CGPointZero];
            [self log:[NSString stringWithFormat:@"双击 %.0f, %.0f", point.x, point.y]];
            [ANSystemTouch doubleTapAtPoint:point];
            [self finishAfter:0.42 completion:completion];
            break;
        }
        case ANPureActionModeLongPress: {
            CGPoint point = [self pointForTask:task fallback:CGPointZero];
            NSTimeInterval duration = MAX(0.35, [self doubleValueForTask:task key:@"duration" fallback:1.0]);
            [self log:[NSString stringWithFormat:@"长按 %.0f, %.0f", point.x, point.y]];
            [ANSystemTouch longPressAtPoint:point duration:duration];
            [self finishAfter:duration + 0.12 completion:completion];
            break;
        }
        case ANPureActionModeSwipe: {
            CGPoint start = [self pointForTask:task fallback:CGPointZero];
            CGPoint end = CGPointMake([self doubleValueForTask:task key:@"endX" fallback:start.x],
                                      [self doubleValueForTask:task key:@"endY" fallback:start.y]);
            NSTimeInterval duration = MAX(0.12, [self doubleValueForTask:task key:@"duration" fallback:0.45]);
            [self log:[NSString stringWithFormat:@"滑动 %.0f,%.0f -> %.0f,%.0f", start.x, start.y, end.x, end.y]];
            [ANSystemTouch playPath:@[[NSValue valueWithCGPoint:start], [NSValue valueWithCGPoint:end]] duration:duration];
            [self finishAfter:duration + 0.12 completion:completion];
            break;
        }
        case ANPureActionModeImage:
            [self performImageTask:task generation:generation completion:completion];
            break;
        case ANPureActionModeOCR:
            [self performOCRTask:task generation:generation completion:completion];
            break;
        case ANPureActionModeColor:
            [self performColorTask:task generation:generation completion:completion];
            break;
        case ANPureActionModeNetwork:
            [self pollNetworkTask:task generation:generation attempt:1 completion:completion];
            break;
        default:
            [self log:@"暂不支持该任务"];
            completion(YES);
            break;
    }
}

- (void)finishAfter:(NSTimeInterval)delay completion:(void (^)(BOOL continueRun))completion {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0.0, delay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        completion(YES);
    });
}

- (void)performImageTask:(NSDictionary *)task generation:(NSUInteger)generation completion:(void (^)(BOOL continueRun))completion {
    UIImage *templateImage = [self templateImageForTask:task];
    if (!templateImage) {
        [self log:@"识图模板未找到"];
        completion(NO);
        return;
    }
    double threshold = MIN(1.0, MAX(0.0, [self doubleValueForTask:task key:@"threshold" fallback:0.80]));
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDictionary *match = [AnClickCore findTemplateImageMatch:templateImage threshold:threshold];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.running || generation != self.generation) {
                return;
            }
            if (!match) {
                [self log:@"识图未命中"];
                completion(NO);
                return;
            }
            CGPoint point = [match[@"point"] CGPointValue];
            [self log:[NSString stringWithFormat:@"识图命中 %.0f, %.0f", point.x, point.y]];
            [self performSuccessActionForTask:task matchPoint:point generation:generation completion:completion];
        });
    });
}

- (void)performOCRTask:(NSDictionary *)task generation:(NSUInteger)generation completion:(void (^)(BOOL continueRun))completion {
    NSString *text = [self trimmedString:task[@"text"]];
    if (text.length == 0) {
        text = [self trimmedString:task[@"ocrText"]];
    }
    if (text.length == 0) {
        [self log:@"识字内容未填写"];
        completion(NO);
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDictionary *match = [AnClickOCR findText:text mode:0];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.running || generation != self.generation) {
                return;
            }
            if (!match || match[@"error"]) {
                [self log:[NSString stringWithFormat:@"识字未命中 %@", text]];
                completion(NO);
                return;
            }
            CGPoint point = [match[@"point"] CGPointValue];
            [self log:[NSString stringWithFormat:@"识字命中 %.0f, %.0f", point.x, point.y]];
            [self performSuccessActionForTask:task matchPoint:point generation:generation completion:completion];
        });
    });
}

- (void)performColorTask:(NSDictionary *)task generation:(NSUInteger)generation completion:(void (^)(BOOL continueRun))completion {
    double tolerance = MIN(255.0, MAX(0.0, [self doubleValueForTask:task key:@"tolerance" fallback:[self doubleValueForTask:task key:@"colorTolerance" fallback:12.0]]));
    NSArray *points = [task[@"colorPoints"] isKindOfClass:NSArray.class] ? task[@"colorPoints"] : nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDictionary *match = nil;
        if (points.count > 0) {
            match = [AnClickCore findColorPatternMatchWithPoints:points tolerance:tolerance];
        } else {
            NSInteger red = [self integerValueForTask:task key:@"red" fallback:[self integerValueForTask:task key:@"colorRed" fallback:-1]];
            NSInteger green = [self integerValueForTask:task key:@"green" fallback:[self integerValueForTask:task key:@"colorGreen" fallback:-1]];
            NSInteger blue = [self integerValueForTask:task key:@"blue" fallback:[self integerValueForTask:task key:@"colorBlue" fallback:-1]];
            if (red >= 0 && green >= 0 && blue >= 0) {
                match = [AnClickCore findColorMatchWithRed:red green:green blue:blue tolerance:tolerance];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.running || generation != self.generation) {
                return;
            }
            if (!match) {
                [self log:@"识色未命中"];
                completion(NO);
                return;
            }
            CGPoint point = [match[@"point"] CGPointValue];
            [self log:[NSString stringWithFormat:@"识色命中 %.0f, %.0f", point.x, point.y]];
            [self performSuccessActionForTask:task matchPoint:point generation:generation completion:completion];
        });
    });
}

- (void)performSuccessActionForTask:(NSDictionary *)task matchPoint:(CGPoint)matchPoint generation:(NSUInteger)generation completion:(void (^)(BOOL continueRun))completion {
    BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
    CGPoint actionPoint = useMatchPoint ? matchPoint : [self pointForTask:task fallback:matchPoint];
    ANPureActionMode actionMode = [self successActionModeForTask:task];
    if (actionMode == ANPureActionModeNetwork) {
        [self performNetworkRequestForTask:task requireJudgement:NO generation:generation completion:^(BOOL matched, BOOL succeeded, BOOL blocked) {
            if (blocked || !succeeded) {
                [self log:@"成功后网络请求失败"];
                completion(NO);
                return;
            }
            completion(YES);
        }];
        return;
    }
    if (actionMode == ANPureActionModeDoubleTap) {
        [ANSystemTouch doubleTapAtPoint:actionPoint];
        [self finishAfter:0.42 completion:completion];
    } else if (actionMode == ANPureActionModeLongPress) {
        NSTimeInterval duration = MAX(0.35, [self doubleValueForTask:task key:@"duration" fallback:1.0]);
        [ANSystemTouch longPressAtPoint:actionPoint duration:duration];
        [self finishAfter:duration + 0.12 completion:completion];
    } else if (actionMode == ANPureActionModeSwipe) {
        CGPoint end = CGPointMake([self doubleValueForTask:task key:@"endX" fallback:actionPoint.x],
                                  [self doubleValueForTask:task key:@"endY" fallback:actionPoint.y]);
        NSTimeInterval duration = MAX(0.12, [self doubleValueForTask:task key:@"duration" fallback:0.45]);
        [ANSystemTouch playPath:@[[NSValue valueWithCGPoint:actionPoint], [NSValue valueWithCGPoint:end]] duration:duration];
        [self finishAfter:duration + 0.12 completion:completion];
    } else {
        [ANSystemTouch tapAtPoint:actionPoint];
        [self finishAfter:0.22 completion:completion];
    }
}

- (NSString *)networkMethodForTask:(NSDictionary *)task {
    NSString *method = [[self trimmedString:task[@"method"]] uppercaseString];
    if (method.length == 0) {
        method = [[self trimmedString:task[@"networkMethod"]] uppercaseString];
    }
    return [method isEqualToString:@"POST"] ? @"POST" : @"GET";
}

- (NSURLRequest *)networkRequestForTask:(NSDictionary *)task requireJudgement:(BOOL)requireJudgement errorMessage:(NSString **)errorMessage {
    NSString *urlString = [self trimmedString:task[@"url"]];
    if (urlString.length == 0) {
        urlString = [self trimmedString:task[@"networkURL"]];
    }
    if (urlString.length == 0) {
        if (errorMessage) {
            *errorMessage = @"网络链接未填写";
        }
        return nil;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url.scheme || !url.host) {
        if (errorMessage) {
            *errorMessage = @"网络链接格式错误";
        }
        return nil;
    }
    NSTimeInterval timeout = MIN(60.0, MAX(1.0, [self doubleValueForTask:task key:@"timeout" fallback:[self doubleValueForTask:task key:@"networkTimeout" fallback:5.0]]));
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    NSString *method = [self networkMethodForTask:task];
    request.HTTPMethod = method;
    if ([method isEqualToString:@"POST"]) {
        NSString *body = [self trimmedString:task[@"postBody"]];
        if (body.length == 0) {
            body = [self trimmedString:task[@"networkPostBody"]];
        }
        request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
        NSString *contentType = [body hasPrefix:@"{"] || [body hasPrefix:@"["] ? @"application/json;charset=utf-8" : @"application/x-www-form-urlencoded;charset=utf-8";
        [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    }
    [request setValue:@"AnClickPureIPA/1.0" forHTTPHeaderField:@"User-Agent"];
    return request;
}

- (BOOL)body:(NSString *)body containsRule:(NSString *)rule regex:(BOOL)regex {
    if (rule.length == 0) {
        return NO;
    }
    if (!regex) {
        return [body rangeOfString:rule options:NSCaseInsensitiveSearch].location != NSNotFound;
    }
    NSError *error = nil;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:rule options:NSRegularExpressionCaseInsensitive error:&error];
    if (error || !expression) {
        [self log:[NSString stringWithFormat:@"正则错误：%@", rule]];
        return NO;
    }
    NSRange range = NSMakeRange(0, body.length);
    return [expression firstMatchInString:body options:0 range:range] != nil;
}

- (NSNumber *)statusBooleanFromJSONBody:(NSString *)body {
    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length == 0) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    id status = [(NSDictionary *)object objectForKey:@"status"];
    if ([status isKindOfClass:NSNumber.class]) {
        return status;
    }
    if ([status isKindOfClass:NSString.class]) {
        NSString *value = [(NSString *)status lowercaseString];
        if ([value isEqualToString:@"true"]) {
            return @(YES);
        }
        if ([value isEqualToString:@"false"]) {
            return @(NO);
        }
    }
    return nil;
}

- (void)performNetworkRequestForTask:(NSDictionary *)task
                    requireJudgement:(BOOL)requireJudgement
                          generation:(NSUInteger)generation
                          completion:(void (^)(BOOL matched, BOOL succeeded, BOOL blocked))completion {
    NSString *runRule = [self trimmedString:task[@"contains"]];
    if (runRule.length == 0) {
        runRule = [self trimmedString:task[@"networkContains"]];
    }
    NSString *blockRule = [self trimmedString:task[@"blockContains"]];
    if (blockRule.length == 0) {
        blockRule = [self trimmedString:task[@"networkFalse"]];
    }
    BOOL regex = [task[@"regex"] boolValue] || [task[@"useRegex"] boolValue] || [task[@"networkUseRegex"] boolValue];
    BOOL requestOnly = [task[@"requestOnly"] boolValue] || [task[@"networkRequestOnly"] boolValue] || !requireJudgement;
    if (requireJudgement && !requestOnly && runRule.length == 0 && blockRule.length == 0) {
        [self log:@"网络判断需要填写运行关键字或不运行关键字"];
        completion(NO, NO, YES);
        return;
    }

    NSString *errorMessage = nil;
    NSURLRequest *request = [self networkRequestForTask:task requireJudgement:requireJudgement errorMessage:&errorMessage];
    if (!request) {
        [self log:errorMessage ?: @"网络请求配置错误"];
        completion(NO, NO, YES);
        return;
    }

    [self log:[NSString stringWithFormat:@"网络%@ %@", request.HTTPMethod, request.URL.absoluteString]];
    NSURLSessionDataTask *dataTask = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.running || generation != self.generation) {
                return;
            }
            if (error) {
                [self log:[NSString stringWithFormat:@"网络失败：%@", error.localizedDescription]];
                completion(NO, NO, NO);
                return;
            }
            NSString *body = [[NSString alloc] initWithData:data ?: [NSData data] encoding:NSUTF8StringEncoding] ?: @"";
            if (requestOnly) {
                [self log:@"网络仅请求完成"];
                completion(YES, YES, NO);
                return;
            }

            NSNumber *jsonStatus = [self statusBooleanFromJSONBody:body];
            if (jsonStatus) {
                if (jsonStatus.boolValue) {
                    [self log:@"网络命中运行：status=true"];
                    completion(YES, YES, NO);
                } else {
                    [self log:@"网络命中不运行：status=false"];
                    completion(NO, YES, NO);
                }
                return;
            }

            if ([self body:body containsRule:blockRule regex:regex]) {
                [self log:[NSString stringWithFormat:@"网络命中不运行：%@", blockRule]];
                completion(NO, YES, NO);
                return;
            }
            if ([self body:body containsRule:runRule regex:regex]) {
                [self log:[NSString stringWithFormat:@"网络命中运行：%@", runRule]];
                completion(YES, YES, NO);
                return;
            }

            [self log:@"网络未命中"];
            completion(NO, YES, NO);
        });
    }];
    [dataTask resume];
}

- (void)pollNetworkTask:(NSDictionary *)task generation:(NSUInteger)generation attempt:(NSInteger)attempt completion:(void (^)(BOOL continueRun))completion {
    BOOL requestOnly = [task[@"requestOnly"] boolValue] || [task[@"networkRequestOnly"] boolValue];
    NSInteger limit = MAX(1, [self integerValueForTask:task key:@"retryLimit" fallback:[self integerValueForTask:task key:@"networkRetryLimit" fallback:1]]);
    BOOL forever = [task[@"retryForever"] boolValue] || [task[@"networkRetryForever"] boolValue];
    [self performNetworkRequestForTask:task requireJudgement:!requestOnly generation:generation completion:^(BOOL matched, BOOL succeeded, BOOL blocked) {
        if (blocked || requestOnly) {
            completion(succeeded && !blocked);
            return;
        }
        if (matched) {
            completion(YES);
            return;
        }
        if (!forever && attempt >= limit) {
            [self log:[NSString stringWithFormat:@"网络判断已达 %ld 次，停止", (long)limit]];
            completion(NO);
            return;
        }
        NSTimeInterval interval = MAX(0.2, [self doubleValueForTask:task key:@"retryInterval" fallback:1.0]);
        [self log:[NSString stringWithFormat:@"网络继续判断 第%ld次", (long)attempt + 1]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self pollNetworkTask:task generation:generation attempt:attempt + 1 completion:completion];
        });
    }];
}

@end
