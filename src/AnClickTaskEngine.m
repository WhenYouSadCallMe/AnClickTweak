#import "AnClickTaskEngine.h"
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>
#import <math.h>

@interface AnClickTaskEngine ()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *jumpVisitCounts;
@property (nonatomic, strong, nullable) NSTimer *runtimeTimer;
@property (nonatomic, assign) CFTimeInterval runtimeStartTime;
@property (nonatomic, assign) NSTimeInterval accumulatedRuntime;
@property (nonatomic, assign) CFTimeInterval lastListRefreshTime;
@property (nonatomic, assign) NSUInteger scheduledCallbackGeneration;
@end

@implementation AnClickTaskEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _minInfiniteLoopInterval = 0.100;
        _minJumpContinuationInterval = 0.030;
        _maxJumpVisitsPerRun = 96;
        _listRefreshMinInterval = 0.75;
        _jumpVisitCounts = [NSMutableDictionary dictionary];
        _lastListRefreshTime = 0.0;
        _scheduledCallbackGeneration = 1;
    }
    return self;
}

- (void)dealloc {
    [self invalidateScheduledCallbacks];
    [_runtimeTimer invalidate];
}

- (void)startRuntimeReset:(BOOL)reset {
    if (reset) {
        _accumulatedRuntime = 0.0;
    }
    [_runtimeTimer invalidate];
    _runtimeStartTime = CACurrentMediaTime();
    _runtimeTimer = [NSTimer timerWithTimeInterval:1.0
                                            target:self
                                          selector:@selector(handleRuntimeTimer:)
                                          userInfo:nil
                                           repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:_runtimeTimer forMode:NSRunLoopCommonModes];
    [self emitRuntime];
}

- (void)pauseRuntime {
    [self stopRuntimeReset:NO];
}

- (void)stopRuntimeReset:(BOOL)reset {
    if (_runtimeStartTime > 0.0) {
        _accumulatedRuntime += MAX(0.0, CACurrentMediaTime() - _runtimeStartTime);
    }
    _runtimeStartTime = 0.0;
    [_runtimeTimer invalidate];
    _runtimeTimer = nil;
    if (reset) {
        _accumulatedRuntime = 0.0;
    }
    [self emitRuntime];
}

- (NSTimeInterval)runtime {
    NSTimeInterval duration = MAX(0.0, _accumulatedRuntime);
    if (_runtimeStartTime > 0.0) {
        duration += MAX(0.0, CACurrentMediaTime() - _runtimeStartTime);
    }
    return duration;
}

- (NSString *)formattedRuntime {
    NSInteger totalSeconds = MAX(0, (NSInteger)floor([self runtime]));
    NSInteger hours = totalSeconds / 3600;
    NSInteger minutes = (totalSeconds / 60) % 60;
    NSInteger seconds = totalSeconds % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
}

- (void)handleRuntimeTimer:(__unused NSTimer *)timer {
    [self emitRuntime];
}

- (void)emitRuntime {
    if (_runtimeHandler) {
        _runtimeHandler([self runtime]);
    }
}

- (void)resetJumpGuard {
    [_jumpVisitCounts removeAllObjects];
}

- (void)invalidateScheduledCallbacks {
    _scheduledCallbackGeneration++;
    if (_scheduledCallbackGeneration == 0) {
        _scheduledCallbackGeneration = 1;
    }
}

- (BOOL)recordJumpVisitForTaskIndex:(NSUInteger)index taskCount:(NSUInteger)taskCount {
    NSNumber *key = @(index);
    NSUInteger visits = [_jumpVisitCounts[key] unsignedIntegerValue] + 1;
    _jumpVisitCounts[key] = @(visits);
    NSUInteger limit = MAX(_maxJumpVisitsPerRun, taskCount * 8);
    return visits <= limit;
}

- (BOOL)recordJumpVisitForTaskIndex:(NSUInteger)index
                           taskCount:(NSUInteger)taskCount
                       failureStatus:(NSString * _Nullable * _Nullable)failureStatus {
    BOOL allowed = [self recordJumpVisitForTaskIndex:index taskCount:taskCount];
    if (!allowed && failureStatus) {
        *failureStatus = [NSString stringWithFormat:@"检测到跳转循环 任务%lu", (unsigned long)index + 1];
    }
    return allowed;
}

- (void)resetListRefreshThrottle {
    _lastListRefreshTime = 0.0;
}

- (BOOL)shouldRefreshListNow {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - _lastListRefreshTime < _listRefreshMinInterval) {
        return NO;
    }
    _lastListRefreshTime = now;
    return YES;
}

- (AnClickTaskEngineCursorDecision)decisionForTaskIndex:(NSUInteger)index
                                              taskCount:(NSUInteger)taskCount
                                    singleStepStopIndex:(NSInteger)singleStepStopIndex
                                           currentCycle:(NSInteger *)currentCycle
                                            repeatLimit:(NSInteger)repeatLimit {
    if (singleStepStopIndex >= 0 && (NSInteger)index != singleStepStopIndex) {
        return AnClickTaskEngineCursorDecisionSingleStepComplete;
    }
    if (index < taskCount) {
        return AnClickTaskEngineCursorDecisionRunTask;
    }

    NSInteger nextCycle = currentCycle ? *currentCycle + 1 : 1;
    if (currentCycle) {
        *currentCycle = nextCycle;
    }
    NSInteger normalizedRepeatLimit = MAX(0, repeatLimit);
    if (normalizedRepeatLimit == 0 || nextCycle < normalizedRepeatLimit) {
        return AnClickTaskEngineCursorDecisionRepeatList;
    }
    return AnClickTaskEngineCursorDecisionListFinished;
}

- (AnClickTaskEngineNetworkDecision)networkDecisionWithWaitsForCondition:(BOOL)waitsForCondition
                                                              retryForever:(BOOL)retryForever
                                                                retryLimit:(NSInteger)retryLimit
                                                                   attempt:(NSInteger)attempt
                                                                   matched:(BOOL)matched
                                                          requestSucceeded:(BOOL)requestSucceeded
                                                                   blocked:(BOOL)blocked
                                                             hasSuccessRule:(BOOL)hasSuccessRule
                                                            hasFailurePath:(BOOL)hasFailurePath {
    (void)hasFailurePath;

    BOOL shouldContinue = waitsForCondition
        ? (hasSuccessRule ? (matched && !blocked) : (requestSucceeded && !blocked))
        : requestSucceeded;
    if (shouldContinue) {
        return AnClickTaskEngineNetworkDecisionContinueSuccess;
    }
    if (!retryForever && attempt >= MAX(1, retryLimit)) {
        return AnClickTaskEngineNetworkDecisionStop;
    }
    return AnClickTaskEngineNetworkDecisionRetry;
}

- (AnClickTaskEngineRecognitionFailureDecision)recognitionFailureDecisionWithRetryUntilFound:(BOOL)retryUntilFound
                                                                                 repeatCount:(NSInteger)repeatCount
                                                                                     attempt:(NSInteger)attempt {
    if (retryUntilFound) {
        return AnClickTaskEngineRecognitionFailureDecisionRetry;
    }
    if (attempt >= MAX(1, repeatCount)) {
        return AnClickTaskEngineRecognitionFailureDecisionContinueFailure;
    }
    return AnClickTaskEngineRecognitionFailureDecisionRetry;
}

- (BOOL)recognitionAttemptExceedsLimit:(NSInteger)attempt
                           repeatCount:(NSInteger)repeatCount
                       retryUntilFound:(BOOL)retryUntilFound {
    return !retryUntilFound && attempt > MAX(1, repeatCount);
}

- (AnClickActionMode)modeForTask:(NSDictionary *)task {
    id value = task[@"mode"] ?: task[@"actionMode"];
    if (![value respondsToSelector:@selector(integerValue)]) {
        return AnClickActionModeNone;
    }
    NSInteger mode = [value integerValue];
    if (mode < AnClickActionModeNone || mode >= AnClickActionModeCount) {
        return AnClickActionModeNone;
    }
    return (AnClickActionMode)mode;
}

- (NSUInteger)jumpTargetIndexForTask:(NSDictionary *)task {
    id value = task[@"jumpTaskIndex"] ?: task[@"targetTaskIndex"] ?: task[@"jumpTaskId"];
    return (NSUInteger)MAX(0, [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0);
}

- (BOOL)textHasContent:(NSString *)text {
    if (![text isKindOfClass:NSString.class]) {
        return NO;
    }
    return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0;
}

- (void)runTaskAtIndex:(NSUInteger)index host:(id)host generation:(NSUInteger)generation {
    id<AnClickTaskEngineDelegate> delegate = self.delegate;
    if (!delegate) {
        return;
    }
    if (![delegate taskEngine:self canContinueWithGeneration:generation fallbackHost:host status:@"窗口变化停止"]) {
        return;
    }
    if (![delegate taskEngineCanUseCurrentScene:self]) {
        return;
    }

    id currentHost = [delegate taskEngine:self currentHostWithFallback:host];
    BOOL scheduled = [delegate taskEngineResumeScheduled:self];
    [delegate taskEngine:self rememberResumeIndex:index globalNetworkGate:NO scheduled:scheduled];

    NSInteger repeatLimit = MAX(0, [delegate taskEngineRepeatLimit:self]);
    NSInteger *currentCycle = [delegate taskEngineCurrentCyclePointer:self];
    AnClickTaskEngineCursorDecision cursorDecision = [self decisionForTaskIndex:index
                                                                      taskCount:[delegate taskEngineTaskCount:self]
                                                            singleStepStopIndex:[delegate taskEngineSingleStepStopIndex:self]
                                                                   currentCycle:currentCycle
                                                                    repeatLimit:repeatLimit];
    switch (cursorDecision) {
        case AnClickTaskEngineCursorDecisionSingleStepComplete:
            [delegate taskEngineFinishSingleStep:self status:@"单步测试完成"];
            return;
        case AnClickTaskEngineCursorDecisionRepeatList: {
            [delegate taskEngine:self rememberResumeIndex:0 globalNetworkGate:NO scheduled:scheduled];
            [self resetJumpGuard];
            NSTimeInterval loopInterval = [self coercedLoopInterval:[delegate taskEngineLoopInterval:self]
                                                        repeatLimit:repeatLimit];
            __weak typeof(self) weakSelf = self;
            [self scheduleAfter:loopInterval guard:^BOOL{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
                if (!strongSelf || !strongDelegate) {
                    return NO;
                }
                return [strongDelegate taskEngine:strongSelf
                        canContinueWithGeneration:generation
                                     fallbackHost:currentHost
                                           status:@"窗口变化停止"];
            } block:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
                if (!strongSelf || !strongDelegate) {
                    return;
                }
                id loopHost = [strongDelegate taskEngine:strongSelf currentHostWithFallback:currentHost];
                [strongSelf runTaskAtIndex:0 host:loopHost generation:generation];
            }];
            return;
        }
        case AnClickTaskEngineCursorDecisionListFinished:
        {
            NSString *currentStatus = [delegate taskEngineCurrentStatus:self] ?: @"";
            BOOL preservesRecognitionStatus = [currentStatus containsString:@"识图"] ||
                [currentStatus containsString:@"识字"] ||
                [currentStatus containsString:@"识色"] ||
                [currentStatus containsString:@"识别"] ||
                [currentStatus containsString:@"文字识别"];
            NSString *finishStatus = preservesRecognitionStatus
                ? [NSString stringWithFormat:@"%@ · 完成", currentStatus]
                : @"任务完成";
            [delegate taskEngine:self finishWithStatus:finishStatus showToast:YES restorePanel:YES];
            return;
        }
        case AnClickTaskEngineCursorDecisionRunTask:
            break;
    }

    AnClickTaskModel *taskModel = [delegate taskEngine:self taskModelAtIndex:index];
    NSMutableDictionary *task = taskModel ? [delegate taskEngine:self dictionaryForModel:taskModel] : nil;
    if (!task) {
        [delegate taskEngine:self finishWithStatus:@"任务数据无效" showToast:YES restorePanel:YES];
        return;
    }

    AnClickActionMode mode = [self modeForTask:task];
    [delegate taskEngine:self showToastForTask:task index:index];
    if (mode == AnClickActionModeJump) {
        NSString *failureStatus = nil;
        if (![self recordJumpVisitForTaskIndex:index
                                     taskCount:[delegate taskEngineTaskCount:self]
                                 failureStatus:&failureStatus]) {
            [delegate taskEngine:self setStatus:(failureStatus.length > 0 ? failureStatus : @"检测到跳转循环")];
            [delegate taskEngine:self finishWithStatus:(failureStatus.length > 0 ? failureStatus : @"检测到跳转循环")
                                             showToast:YES
                                          restorePanel:YES];
            return;
        }
        if (![delegate taskEngine:self taskModelIsComplete:taskModel]) {
            NSString *status = [delegate taskEngineCurrentStatus:self] ?: @"任务数据无效";
            [delegate taskEngine:self finishWithStatus:(status.length > 0 ? status : @"任务数据无效") showToast:YES restorePanel:YES];
            [delegate taskEngineExpandPanel:self];
            return;
        }
        NSUInteger targetIndex = [self jumpTargetIndexForTask:task];
        [delegate taskEngine:self setStatus:[NSString stringWithFormat:@"跳转任务%lu", (unsigned long)targetIndex + 1]];
        __weak typeof(self) weakSelf = self;
        [self scheduleAfter:self.minJumpContinuationInterval guard:^BOOL{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
            if (!strongSelf || !strongDelegate) {
                return NO;
            }
            return [strongDelegate taskEngine:strongSelf
                    canContinueWithGeneration:generation
                                 fallbackHost:currentHost
                                       status:@"窗口变化停止"];
        } block:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
            if (!strongSelf || !strongDelegate) {
                return;
            }
            id jumpHost = [strongDelegate taskEngine:strongSelf currentHostWithFallback:currentHost];
            [strongSelf runTaskAtIndex:targetIndex host:jumpHost generation:generation];
        }];
        return;
    }

    [self resetJumpGuard];
    if (mode == AnClickActionModeNetwork || mode == AnClickActionModeConditionWait) {
        if (![delegate taskEngine:self taskModelIsComplete:taskModel]) {
            NSString *status = [delegate taskEngineCurrentStatus:self] ?: @"任务数据无效";
            [delegate taskEngine:self finishWithStatus:(status.length > 0 ? status : @"任务数据无效") showToast:YES restorePanel:YES];
            [delegate taskEngineExpandPanel:self];
            return;
        }
        [self runNetworkTaskModel:taskModel atIndex:index host:currentHost generation:generation];
        return;
    }

    if ([delegate taskEngine:self modeIsRecognitionTask:mode]) {
        if (![delegate taskEngine:self taskModelIsComplete:taskModel]) {
            NSString *status = [delegate taskEngineCurrentStatus:self] ?: @"任务数据无效";
            [delegate taskEngine:self finishWithStatus:(status.length > 0 ? status : @"任务数据无效") showToast:YES restorePanel:YES];
            [delegate taskEngineExpandPanel:self];
            return;
        }
        [self runRecognitionTaskModel:taskModel atIndex:index host:currentHost generation:generation];
        return;
    }

    NSTimeInterval duration = [delegate taskEngine:self performTaskModel:taskModel host:currentHost generation:generation];
    if (duration <= 0) {
        NSString *status = [delegate taskEngineCurrentStatus:self] ?: @"任务执行失败";
        [delegate taskEngine:self finishWithStatus:(status.length > 0 ? status : @"任务执行失败") showToast:YES restorePanel:YES];
        [delegate taskEngineExpandPanel:self];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self scheduleAfter:duration guard:^BOOL{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return NO;
        }
        return [strongDelegate taskEngine:strongSelf
                canContinueWithGeneration:generation
                             fallbackHost:currentHost
                                   status:@"窗口变化停止"];
    } block:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return;
        }
        id delayedHost = [strongDelegate taskEngine:strongSelf currentHostWithFallback:currentHost];
        [strongSelf continueTaskRunToIndex:index + 1 host:delayedHost generation:generation];
    }];
}

- (void)continueTaskRunToIndex:(NSUInteger)nextIndex host:(id)host generation:(NSUInteger)generation {
    id<AnClickTaskEngineDelegate> delegate = self.delegate;
    if (!delegate) {
        return;
    }
    NSTimeInterval globalDelay = MAX(0.0, [delegate taskEngineGlobalDelay:self]);
    __weak typeof(self) weakSelf = self;
    [self scheduleAfter:globalDelay guard:^BOOL{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return NO;
        }
        return [strongDelegate taskEngine:strongSelf
                canContinueWithGeneration:generation
                             fallbackHost:host
                                   status:@"窗口变化停止"];
    } block:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return;
        }
        id currentHost = [strongDelegate taskEngine:strongSelf currentHostWithFallback:host];
        [strongSelf runTaskAtIndex:nextIndex host:currentHost generation:generation];
    }];
}

- (void)monitorGlobalNetworkGateWithHost:(id)host scheduled:(BOOL)scheduled generation:(NSUInteger)generation {
    id<AnClickTaskEngineDelegate> delegate = self.delegate;
    if (!delegate) {
        return;
    }
    if (![delegate taskEngine:self canContinueWithGeneration:generation fallbackHost:host status:@"窗口变化停止"]) {
        return;
    }
    if (![delegate taskEngineCanUseCurrentScene:self]) {
        return;
    }

    id currentHost = [delegate taskEngine:self currentHostWithFallback:host];
    [delegate taskEngine:self rememberResumeIndex:0 globalNetworkGate:YES scheduled:scheduled];
    __weak typeof(self) callbackWeakSelf = self;
    [delegate taskEngine:self performGlobalNetworkGateRequestWithGeneration:generation completion:^(BOOL shouldRun, NSString *status) {
        __strong typeof(callbackWeakSelf) callbackSelf = callbackWeakSelf;
        id<AnClickTaskEngineDelegate> callbackDelegate = callbackSelf.delegate;
        if (!callbackSelf || !callbackDelegate) {
            return;
        }
        if (![callbackDelegate taskEngine:callbackSelf canContinueWithGeneration:generation fallbackHost:currentHost status:@"窗口变化停止"]) {
            return;
        }

        id callbackHost = [callbackDelegate taskEngine:callbackSelf currentHostWithFallback:currentHost];
        NSString *statusText = shouldRun
            ? (scheduled ? @"定时命中运行" : @"命中运行")
            : (status.length > 0 ? status : @"未命中运行 继续监控");
        [callbackDelegate taskEngine:callbackSelf showRunStatus:statusText];
        if (shouldRun) {
            [callbackSelf runTaskAtIndex:0 host:callbackHost generation:generation];
            return;
        }

        __weak typeof(callbackSelf) weakSelf = callbackSelf;
        [callbackSelf scheduleAfter:3.0 guard:^BOOL{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
            if (!strongSelf || !strongDelegate) {
                return NO;
            }
            return [strongDelegate taskEngine:strongSelf
                    canContinueWithGeneration:generation
                                 fallbackHost:callbackHost
                                       status:@"窗口变化停止"];
        } block:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
            if (!strongSelf || !strongDelegate) {
                return;
            }
            id retryHost = [strongDelegate taskEngine:strongSelf currentHostWithFallback:callbackHost];
            [strongSelf monitorGlobalNetworkGateWithHost:retryHost scheduled:scheduled generation:generation];
        }];
    }];
}

- (void)scheduleRecognitionCaptureWithHost:(id)host
                                generation:(NSUInteger)generation
                                     delay:(NSTimeInterval)delay
                                     block:(AnClickTaskEngineRecognitionCaptureBlock)block {
    if (!block) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self scheduleAfter:delay guard:^BOOL{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return NO;
        }
        if (generation == 0) {
            return YES;
        }
        return [strongDelegate taskEngine:strongSelf
                canContinueWithGeneration:generation
                             fallbackHost:host
                                   status:@"窗口变化停止"];
    } block:block];
}

- (void)runNetworkTaskModel:(AnClickTaskModel *)model atIndex:(NSUInteger)index host:(id)host generation:(NSUInteger)generation {
    id<AnClickTaskEngineDelegate> delegate = self.delegate;
    if (!delegate || !model) {
        return;
    }
    if (![delegate taskEngine:self canContinueWithGeneration:generation fallbackHost:host status:@"窗口变化停止"]) {
        return;
    }
    if (![delegate taskEngineCanUseCurrentScene:self]) {
        return;
    }

    id currentHost = [delegate taskEngine:self currentHostWithFallback:host];
    [delegate taskEngine:self setStatus:(model.actionMode == AnClickActionModeConditionWait ? @"条件等待" : @"网络请求")];
    NSTimeInterval delay = MAX(0.0, model.delay);
    __weak typeof(self) weakSelf = self;
    [self scheduleAfter:delay guard:^BOOL{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return NO;
        }
        return [strongDelegate taskEngine:strongSelf
                canContinueWithGeneration:generation
                             fallbackHost:currentHost
                                   status:@"窗口变化停止"];
    } block:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return;
        }
        id requestHost = [strongDelegate taskEngine:strongSelf currentHostWithFallback:currentHost];
        [strongSelf pollNetworkTaskModel:model atIndex:index host:requestHost generation:generation attempt:1];
    }];
}

- (void)pollNetworkTaskModel:(AnClickTaskModel *)model
                     atIndex:(NSUInteger)index
                        host:(id)host
                  generation:(NSUInteger)generation
                     attempt:(NSInteger)attempt {
    id<AnClickTaskEngineDelegate> delegate = self.delegate;
    if (!delegate || !model) {
        return;
    }
    if (![delegate taskEngine:self canContinueWithGeneration:generation fallbackHost:host status:@"窗口变化停止"]) {
        return;
    }

    BOOL waitsForCondition = !model.networkRequestOnly;
    BOOL retryForever = model.networkRetryForever;
    NSInteger retryLimit = MAX(1, model.networkRetryLimit);
    [delegate taskEngine:self performNetworkRequestForModel:model generation:generation completion:^(BOOL matched, BOOL requestSucceeded, BOOL blocked) {
        id<AnClickTaskEngineDelegate> callbackDelegate = self.delegate;
        if (!callbackDelegate) {
            return;
        }
        if (![callbackDelegate taskEngine:self canContinueWithGeneration:generation fallbackHost:host status:@"窗口变化停止"]) {
            return;
        }
        id currentHost = [callbackDelegate taskEngine:self currentHostWithFallback:host];
        AnClickTaskEngineNetworkDecision decision = [self networkDecisionWithWaitsForCondition:waitsForCondition
                                                                                  retryForever:retryForever
                                                                                    retryLimit:retryLimit
                                                                                       attempt:attempt
                                                                                       matched:matched
                                                                              requestSucceeded:requestSucceeded
                                                                                       blocked:blocked
                                                                                hasSuccessRule:[self textHasContent:model.networkContains]
                                                                                hasFailurePath:NO];
        switch (decision) {
            case AnClickTaskEngineNetworkDecisionContinueSuccess:
                [callbackDelegate taskEngine:self
                 continueAfterNetworkTaskModel:model
                                       atIndex:index
                                          host:currentHost
                                    generation:generation
                                       success:YES];
                return;
            case AnClickTaskEngineNetworkDecisionContinueFailure:
                [callbackDelegate taskEngine:self
                 continueAfterNetworkTaskModel:model
                                       atIndex:index
                                          host:currentHost
                                    generation:generation
                                       success:NO];
                return;
            case AnClickTaskEngineNetworkDecisionStop: {
                NSString *stateText = blocked ? @"命中不运行" : (requestSucceeded ? @"网络不运行" : @"网络重试中");
                [callbackDelegate taskEngine:self
                            finishWithStatus:[NSString stringWithFormat:@"%@ 达到%ld次", stateText, (long)retryLimit]
                                    showToast:YES
                                 restorePanel:YES];
                return;
            }
            case AnClickTaskEngineNetworkDecisionRetry:
                break;
        }

        NSString *stateText = blocked ? @"命中不运行" : (requestSucceeded ? @"网络不运行" : @"网络重试中");
        NSString *status = retryForever
            ? [NSString stringWithFormat:@"%@ 继续判断", stateText]
            : [NSString stringWithFormat:@"%@ %ld/%ld", stateText, (long)attempt, (long)retryLimit];
        [callbackDelegate taskEngine:self setStatus:status];
        __weak typeof(self) weakSelf = self;
        [self scheduleAfter:3.0 guard:^BOOL{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
            if (!strongSelf || !strongDelegate) {
                return NO;
            }
            return [strongDelegate taskEngine:strongSelf
                    canContinueWithGeneration:generation
                                 fallbackHost:currentHost
                                       status:@"窗口变化停止"];
        } block:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
            if (!strongSelf || !strongDelegate) {
                return;
            }
            id retryHost = [strongDelegate taskEngine:strongSelf currentHostWithFallback:currentHost];
            [strongSelf pollNetworkTaskModel:model
                                      atIndex:index
                                         host:retryHost
                                   generation:generation
                                      attempt:attempt + 1];
        }];
    }];
}

- (void)runRecognitionTaskModel:(AnClickTaskModel *)model atIndex:(NSUInteger)index host:(id)host generation:(NSUInteger)generation {
    id<AnClickTaskEngineDelegate> delegate = self.delegate;
    if (!delegate || !model) {
        return;
    }
    if (![delegate taskEngine:self canContinueWithGeneration:generation fallbackHost:host status:@"窗口变化停止"]) {
        return;
    }
    [self scheduleRecognitionTaskModel:model
                               atIndex:index
                                  host:host
                            generation:generation
                               attempt:1
                                 delay:[delegate taskEngine:self delayForRecognitionTaskModel:model]];
}

- (void)scheduleRecognitionTaskModel:(AnClickTaskModel *)model
                              atIndex:(NSUInteger)index
                                 host:(id)host
                           generation:(NSUInteger)generation
                              attempt:(NSInteger)attempt
                                delay:(NSTimeInterval)delay {
    __weak typeof(self) weakSelf = self;
    [self scheduleAfter:delay guard:^BOOL{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return NO;
        }
        return [strongDelegate taskEngine:strongSelf
                canContinueWithGeneration:generation
                             fallbackHost:host
                                   status:@"窗口变化停止"];
    } block:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return;
        }
        id currentHost = [strongDelegate taskEngine:strongSelf currentHostWithFallback:host];
        [strongSelf runRecognitionTaskAttemptForModel:model
                                              atIndex:index
                                                 host:currentHost
                                           generation:generation
                                              attempt:attempt];
    }];
}

- (void)runRecognitionTaskAttemptForModel:(AnClickTaskModel *)model
                                  atIndex:(NSUInteger)index
                                     host:(id)host
                               generation:(NSUInteger)generation
                                  attempt:(NSInteger)attempt {
    id<AnClickTaskEngineDelegate> delegate = self.delegate;
    if (!delegate || !model) {
        return;
    }
    if (![delegate taskEngine:self canContinueWithGeneration:generation fallbackHost:host status:@"窗口变化停止"]) {
        return;
    }
    if (![delegate taskEngineCanUseCurrentScene:self]) {
        return;
    }

    BOOL retryUntilFound = [delegate taskEngine:self retryUntilFoundForRecognitionTaskModel:model];
    NSInteger repeatCount = [delegate taskEngine:self repeatCountForRecognitionTaskModel:model];
    if ([self recognitionAttemptExceedsLimit:attempt repeatCount:repeatCount retryUntilFound:retryUntilFound]) {
        [self continueAfterRecognitionTaskModel:model
                                        atIndex:index
                                           host:host
                                     generation:generation
                                        success:NO
                                          delay:[delegate taskEngine:self actionIntervalForRecognitionTaskModel:model]];
        return;
    }

    [delegate taskEngine:self performRecognitionTaskModel:model host:host generation:generation completion:^(BOOL success, BOOL actionPerformed, NSTimeInterval actionDelay) {
        id<AnClickTaskEngineDelegate> callbackDelegate = self.delegate;
        if (!callbackDelegate) {
            return;
        }
        if (![callbackDelegate taskEngine:self canContinueWithGeneration:generation fallbackHost:host status:@"窗口变化停止"]) {
            return;
        }
        id currentHost = [callbackDelegate taskEngine:self currentHostWithFallback:host];
        if (success) {
            NSTimeInterval successDelay = [callbackDelegate taskEngine:self postSuccessDelayForRecognitionTaskModel:model];
            if (actionPerformed) {
                NSTimeInterval nextDelay = MAX(0.0, actionDelay);
                if (retryUntilFound || attempt >= repeatCount) {
                    [self scheduleAfter:nextDelay guard:^BOOL{
                        id<AnClickTaskEngineDelegate> guardDelegate = self.delegate;
                        return guardDelegate &&
                            [guardDelegate taskEngine:self
                            canContinueWithGeneration:generation
                                         fallbackHost:currentHost
                                               status:@"窗口变化停止"];
                    } block:^{
                        id<AnClickTaskEngineDelegate> finishDelegate = self.delegate;
                        if (!finishDelegate) {
                            return;
                        }
                        id nextHost = [finishDelegate taskEngine:self currentHostWithFallback:currentHost];
                        NSUInteger nextIndex = [finishDelegate taskEngine:self
                                      nextIndexAfterRecognitionTaskModel:model
                                                            currentIndex:index
                                                                 success:YES];
                        [self continueTaskRunToIndex:nextIndex host:nextHost generation:generation];
                    }];
                    return;
                }
                [self scheduleRecognitionTaskModel:model
                                           atIndex:index
                                              host:currentHost
                                        generation:generation
                                           attempt:attempt + 1
                                             delay:MAX(nextDelay, successDelay)];
                return;
            }
            if (retryUntilFound || attempt >= repeatCount) {
                [self continueAfterRecognitionTaskModel:model
                                                atIndex:index
                                                   host:currentHost
                                             generation:generation
                                                success:YES
                                                  delay:0.0];
                return;
            }
            [self scheduleRecognitionTaskModel:model
                                       atIndex:index
                                          host:currentHost
                                    generation:generation
                                       attempt:attempt + 1
                                         delay:successDelay];
            return;
        }

        AnClickActionMode failureActionMode = [callbackDelegate taskEngine:self failureActionModeForRecognitionTaskModel:model];
        if (failureActionMode == AnClickActionModeJump) {
            [self continueAfterRecognitionFailureForModel:model
                                                  atIndex:index
                                                     host:currentHost
                                               generation:generation
                                                  attempt:attempt
                                       failureActionDelay:0.0];
            return;
        }
        if ([callbackDelegate taskEngine:self modeIsRecognitionTask:failureActionMode]) {
            [callbackDelegate taskEngine:self
 performRecognitionBranchActionForModel:model
                                 success:NO
                                    host:currentHost
                              generation:generation
                              completion:^(NSTimeInterval failureActionDelay) {
                id<AnClickTaskEngineDelegate> nestedDelegate = self.delegate;
                if (!nestedDelegate ||
                    ![nestedDelegate taskEngine:self canContinueWithGeneration:generation fallbackHost:currentHost status:@"窗口变化停止"]) {
                    return;
                }
                id failureHost = [nestedDelegate taskEngine:self currentHostWithFallback:currentHost];
                [self continueAfterRecognitionFailureForModel:model
                                                      atIndex:index
                                                         host:failureHost
                                                   generation:generation
                                                      attempt:attempt
                                           failureActionDelay:failureActionDelay];
            }];
            return;
        }
        if (failureActionMode != AnClickActionModeNone) {
            [callbackDelegate taskEngine:self
 performRecognitionFailureActionForModel:model
                                    host:currentHost
                              generation:generation
                              completion:^(NSTimeInterval failureActionDelay) {
                id<AnClickTaskEngineDelegate> nestedDelegate = self.delegate;
                if (!nestedDelegate ||
                    ![nestedDelegate taskEngine:self canContinueWithGeneration:generation fallbackHost:currentHost status:@"窗口变化停止"]) {
                    return;
                }
                id failureHost = [nestedDelegate taskEngine:self currentHostWithFallback:currentHost];
                [self continueAfterRecognitionFailureForModel:model
                                                      atIndex:index
                                                         host:failureHost
                                                   generation:generation
                                                      attempt:attempt
                                           failureActionDelay:failureActionDelay];
            }];
            return;
        }

        [self continueAfterRecognitionFailureForModel:model
                                              atIndex:index
                                                 host:currentHost
                                           generation:generation
                                              attempt:attempt
                                   failureActionDelay:0.0];
    }];
}

- (void)continueAfterRecognitionTaskModel:(AnClickTaskModel *)model
                                  atIndex:(NSUInteger)index
                                     host:(id)host
                               generation:(NSUInteger)generation
                                  success:(BOOL)success
                                    delay:(NSTimeInterval)delay {
    __weak typeof(self) weakSelf = self;
    [self scheduleAfter:delay guard:^BOOL{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return NO;
        }
        return [strongDelegate taskEngine:strongSelf
                canContinueWithGeneration:generation
                             fallbackHost:host
                                   status:@"窗口变化停止"];
    } block:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id<AnClickTaskEngineDelegate> strongDelegate = strongSelf.delegate;
        if (!strongSelf || !strongDelegate) {
            return;
        }
        id currentHost = [strongDelegate taskEngine:strongSelf currentHostWithFallback:host];
        [strongDelegate taskEngine:strongSelf
 performRecognitionBranchActionForModel:model
                            success:success
                               host:currentHost
                         generation:generation
                         completion:^(NSTimeInterval actionDelay) {
            id<AnClickTaskEngineDelegate> nestedDelegate = strongSelf.delegate;
            if (!nestedDelegate ||
                ![nestedDelegate taskEngine:strongSelf canContinueWithGeneration:generation fallbackHost:currentHost status:@"窗口变化停止"]) {
                return;
            }
            __weak typeof(strongSelf) nestedWeakSelf = strongSelf;
            [strongSelf scheduleAfter:actionDelay guard:^BOOL{
                __strong typeof(nestedWeakSelf) nestedSelf = nestedWeakSelf;
                id<AnClickTaskEngineDelegate> guardDelegate = nestedSelf.delegate;
                if (!nestedSelf || !guardDelegate) {
                    return NO;
                }
                return [guardDelegate taskEngine:nestedSelf
                       canContinueWithGeneration:generation
                                    fallbackHost:currentHost
                                          status:@"窗口变化停止"];
            } block:^{
                __strong typeof(nestedWeakSelf) nestedSelf = nestedWeakSelf;
                id<AnClickTaskEngineDelegate> finishDelegate = nestedSelf.delegate;
                if (!nestedSelf || !finishDelegate) {
                    return;
                }
                id nextHost = [finishDelegate taskEngine:nestedSelf currentHostWithFallback:currentHost];
                NSUInteger nextIndex = [finishDelegate taskEngine:nestedSelf
                              nextIndexAfterRecognitionTaskModel:model
                                                    currentIndex:index
                                                         success:success];
                [nestedSelf continueTaskRunToIndex:nextIndex host:nextHost generation:generation];
            }];
        }];
    }];
}

- (void)continueAfterRecognitionFailureForModel:(AnClickTaskModel *)model
                                        atIndex:(NSUInteger)index
                                           host:(id)host
                                     generation:(NSUInteger)generation
                                        attempt:(NSInteger)attempt
                             failureActionDelay:(NSTimeInterval)failureActionDelay {
    id<AnClickTaskEngineDelegate> delegate = self.delegate;
    if (!delegate || !model) {
        return;
    }
    if (![delegate taskEngine:self canContinueWithGeneration:generation fallbackHost:host status:@"窗口变化停止"]) {
        return;
    }

    BOOL retryUntilFound = [delegate taskEngine:self retryUntilFoundForRecognitionTaskModel:model];
    NSInteger repeatCount = [delegate taskEngine:self repeatCountForRecognitionTaskModel:model];
    NSString *taskName = [delegate taskEngine:self displayNameForRecognitionTaskModel:model];
    NSTimeInterval interval = [delegate taskEngine:self actionIntervalForRecognitionTaskModel:model];
    NSTimeInterval continuationDelay = MAX(failureActionDelay > 0.001 ? failureActionDelay : interval, 0.10);
    NSInteger failureBranchIndex = [delegate taskEngine:self failureJumpIndexForRecognitionTaskModel:model];
    if (failureBranchIndex >= 0) {
        [delegate taskEngine:self setStatus:[NSString stringWithFormat:@"%@ 未命中 失败后跳转任务%ld", taskName, (long)failureBranchIndex + 1]];
        [self continueAfterRecognitionTaskModel:model
                                        atIndex:index
                                           host:host
                                     generation:generation
                                        success:NO
                                          delay:continuationDelay];
        return;
    }

    AnClickTaskEngineRecognitionFailureDecision failureDecision = [self recognitionFailureDecisionWithRetryUntilFound:retryUntilFound
                                                                                                           repeatCount:repeatCount
                                                                                                               attempt:attempt];
    if (failureDecision == AnClickTaskEngineRecognitionFailureDecisionRetry && retryUntilFound) {
        NSTimeInterval retryInterval = [delegate taskEngine:self retryIntervalForRecognitionTaskModel:model];
        NSTimeInterval retryDelay = failureActionDelay > 0.001 ? MAX(failureActionDelay, retryInterval) : retryInterval;
        NSString *delayText = [delegate taskEngine:self durationTextForRecognitionDelay:retryDelay];
        [delegate taskEngine:self setStatus:[NSString stringWithFormat:@"%@ 未命中  %@后继续", taskName, delayText]];
        [self scheduleRecognitionTaskModel:model
                                   atIndex:index
                                      host:host
                                generation:generation
                                   attempt:attempt + 1
                                     delay:retryDelay];
        return;
    }

    if (failureDecision == AnClickTaskEngineRecognitionFailureDecisionContinueFailure) {
        [self continueAfterRecognitionTaskModel:model
                                        atIndex:index
                                           host:host
                                     generation:generation
                                        success:NO
                                          delay:continuationDelay];
        return;
    }

    [delegate taskEngine:self setStatus:[NSString stringWithFormat:@"%@ 重试 %ld/%ld", taskName, (long)attempt, (long)repeatCount]];
    [self scheduleRecognitionTaskModel:model
                               atIndex:index
                                  host:host
                            generation:generation
                               attempt:attempt + 1
                                 delay:continuationDelay];
}

- (NSTimeInterval)coercedLoopInterval:(NSTimeInterval)interval repeatLimit:(NSInteger)repeatLimit {
    NSTimeInterval result = isfinite(interval) ? MAX(0.0, interval) : 0.0;
    NSTimeInterval minimumInterval = repeatLimit == 0 ? _minInfiniteLoopInterval : 0.030;
    if (result < minimumInterval) {
        result = minimumInterval;
    }
    return result;
}

- (void)scheduleAfter:(NSTimeInterval)delay
                guard:(AnClickTaskEngineGuardBlock)guardBlock
                block:(AnClickTaskEngineScheduleBlock)block {
    if (!block) {
        return;
    }
    NSTimeInterval safeDelay = isfinite(delay) ? MAX(0.0, delay) : 0.0;
    NSUInteger scheduleGeneration = _scheduledCallbackGeneration;
    if (safeDelay <= 0.0005) {
        if (guardBlock && !guardBlock()) {
            return;
        }
        block();
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(safeDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || scheduleGeneration != strongSelf->_scheduledCallbackGeneration) {
            return;
        }
        if (guardBlock && !guardBlock()) {
            return;
        }
        block();
    });
}

@end
