#import <Foundation/Foundation.h>
#import "AnClickTypes.h"
#import "AnClickTaskModel.h"

NS_ASSUME_NONNULL_BEGIN

@class AnClickTaskEngine;

typedef BOOL (^AnClickTaskEngineGuardBlock)(void);
typedef void (^AnClickTaskEngineScheduleBlock)(void);
typedef void (^AnClickTaskEngineRuntimeHandler)(NSTimeInterval runtime);
typedef void (^AnClickTaskEngineNetworkCompletion)(BOOL matched, BOOL requestSucceeded, BOOL blocked);
typedef void (^AnClickTaskEngineGlobalNetworkCompletion)(BOOL shouldRun, NSString *status);
typedef void (^AnClickTaskEngineRecognitionCompletion)(BOOL success, BOOL actionPerformed, NSTimeInterval actionDelay);
typedef void (^AnClickTaskEngineRecognitionCaptureBlock)(void);
typedef void (^AnClickTaskEngineActionDelayCompletion)(NSTimeInterval actionDelay);

typedef NS_ENUM(NSInteger, AnClickTaskEngineCursorDecision) {
    AnClickTaskEngineCursorDecisionRunTask = 0,
    AnClickTaskEngineCursorDecisionSingleStepComplete,
    AnClickTaskEngineCursorDecisionRepeatList,
    AnClickTaskEngineCursorDecisionListFinished,
};

typedef NS_ENUM(NSInteger, AnClickTaskEngineNetworkDecision) {
    AnClickTaskEngineNetworkDecisionContinueSuccess = 0,
    AnClickTaskEngineNetworkDecisionContinueFailure,
    AnClickTaskEngineNetworkDecisionRetry,
    AnClickTaskEngineNetworkDecisionStop,
};

typedef NS_ENUM(NSInteger, AnClickTaskEngineRecognitionFailureDecision) {
    AnClickTaskEngineRecognitionFailureDecisionContinueFailure = 0,
    AnClickTaskEngineRecognitionFailureDecisionRetry,
};

@protocol AnClickTaskEngineDelegate <NSObject>
- (BOOL)taskEngine:(AnClickTaskEngine *)engine canContinueWithGeneration:(NSUInteger)generation fallbackHost:(id _Nullable)host status:(NSString *)status;
- (BOOL)taskEngineCanUseCurrentScene:(AnClickTaskEngine *)engine;
- (id _Nullable)taskEngine:(AnClickTaskEngine *)engine currentHostWithFallback:(id _Nullable)host;
- (void)taskEngine:(AnClickTaskEngine *)engine rememberResumeIndex:(NSUInteger)index globalNetworkGate:(BOOL)globalNetworkGate scheduled:(BOOL)scheduled;
- (BOOL)taskEngineResumeScheduled:(AnClickTaskEngine *)engine;
- (NSInteger)taskEngineSingleStepStopIndex:(AnClickTaskEngine *)engine;
- (NSInteger)taskEngineRepeatLimit:(AnClickTaskEngine *)engine;
- (NSInteger *)taskEngineCurrentCyclePointer:(AnClickTaskEngine *)engine;
- (NSTimeInterval)taskEngineLoopInterval:(AnClickTaskEngine *)engine;
- (NSTimeInterval)taskEngineGlobalDelay:(AnClickTaskEngine *)engine;
- (NSUInteger)taskEngineTaskCount:(AnClickTaskEngine *)engine;
- (AnClickTaskModel *_Nullable)taskEngine:(AnClickTaskEngine *)engine taskModelAtIndex:(NSUInteger)index;
- (NSMutableDictionary *_Nullable)taskEngine:(AnClickTaskEngine *)engine dictionaryForModel:(AnClickTaskModel *)model;
- (BOOL)taskEngine:(AnClickTaskEngine *)engine taskModelIsComplete:(AnClickTaskModel *)model;
- (BOOL)taskEngine:(AnClickTaskEngine *)engine modeIsRecognitionTask:(AnClickActionMode)mode;
- (void)taskEngine:(AnClickTaskEngine *)engine showToastForTask:(NSDictionary *)task index:(NSUInteger)index;
- (void)taskEngine:(AnClickTaskEngine *)engine setStatus:(NSString *)status;
- (void)taskEngine:(AnClickTaskEngine *)engine showRunStatus:(NSString *)status;
- (NSString *_Nullable)taskEngineCurrentStatus:(AnClickTaskEngine *)engine;
- (void)taskEngine:(AnClickTaskEngine *)engine finishWithStatus:(NSString *)status showToast:(BOOL)showToast restorePanel:(BOOL)restorePanel;
- (void)taskEngineFinishSingleStep:(AnClickTaskEngine *)engine status:(NSString *)status;
- (void)taskEngineExpandPanel:(AnClickTaskEngine *)engine;
- (NSTimeInterval)taskEngine:(AnClickTaskEngine *)engine performTaskModel:(AnClickTaskModel *)model host:(id)host generation:(NSUInteger)generation;
- (void)taskEngine:(AnClickTaskEngine *)engine performGlobalNetworkGateRequestWithGeneration:(NSUInteger)generation completion:(AnClickTaskEngineGlobalNetworkCompletion)completion;
- (void)taskEngine:(AnClickTaskEngine *)engine performNetworkRequestForModel:(AnClickTaskModel *)model generation:(NSUInteger)generation completion:(AnClickTaskEngineNetworkCompletion)completion;
- (BOOL)taskEngine:(AnClickTaskEngine *)engine networkTaskModelHasFailurePath:(AnClickTaskModel *)model;
- (void)taskEngine:(AnClickTaskEngine *)engine continueAfterNetworkTaskModel:(AnClickTaskModel *)model atIndex:(NSUInteger)index host:(id)host generation:(NSUInteger)generation success:(BOOL)success;
- (void)taskEngine:(AnClickTaskEngine *)engine performRecognitionTaskModel:(AnClickTaskModel *)model host:(id)host generation:(NSUInteger)generation completion:(AnClickTaskEngineRecognitionCompletion)completion;
- (void)taskEngine:(AnClickTaskEngine *)engine performRecognitionBranchActionForModel:(AnClickTaskModel *)model success:(BOOL)success host:(id)host generation:(NSUInteger)generation completion:(AnClickTaskEngineActionDelayCompletion)completion;
- (void)taskEngine:(AnClickTaskEngine *)engine performRecognitionFailureActionForModel:(AnClickTaskModel *)model host:(id)host generation:(NSUInteger)generation completion:(AnClickTaskEngineActionDelayCompletion)completion;
- (NSTimeInterval)taskEngine:(AnClickTaskEngine *)engine delayForRecognitionTaskModel:(AnClickTaskModel *)model;
- (NSTimeInterval)taskEngine:(AnClickTaskEngine *)engine actionIntervalForRecognitionTaskModel:(AnClickTaskModel *)model;
- (NSTimeInterval)taskEngine:(AnClickTaskEngine *)engine retryIntervalForRecognitionTaskModel:(AnClickTaskModel *)model;
- (NSTimeInterval)taskEngine:(AnClickTaskEngine *)engine postSuccessDelayForRecognitionTaskModel:(AnClickTaskModel *)model;
- (NSInteger)taskEngine:(AnClickTaskEngine *)engine repeatCountForRecognitionTaskModel:(AnClickTaskModel *)model;
- (BOOL)taskEngine:(AnClickTaskEngine *)engine retryUntilFoundForRecognitionTaskModel:(AnClickTaskModel *)model;
- (AnClickActionMode)taskEngine:(AnClickTaskEngine *)engine failureActionModeForRecognitionTaskModel:(AnClickTaskModel *)model;
- (NSInteger)taskEngine:(AnClickTaskEngine *)engine failureJumpIndexForRecognitionTaskModel:(AnClickTaskModel *)model;
- (NSUInteger)taskEngine:(AnClickTaskEngine *)engine nextIndexAfterRecognitionTaskModel:(AnClickTaskModel *)model currentIndex:(NSUInteger)index success:(BOOL)success;
- (NSString *)taskEngine:(AnClickTaskEngine *)engine displayNameForRecognitionTaskModel:(AnClickTaskModel *)model;
- (NSString *)taskEngine:(AnClickTaskEngine *)engine durationTextForRecognitionDelay:(NSTimeInterval)delay;
@end

@interface AnClickTaskEngine : NSObject

@property (nonatomic, weak, nullable) id<AnClickTaskEngineDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval minInfiniteLoopInterval;
@property (nonatomic, assign) NSTimeInterval minJumpContinuationInterval;
@property (nonatomic, assign) NSUInteger maxJumpVisitsPerRun;
@property (nonatomic, assign) CFTimeInterval listRefreshMinInterval;
@property (nonatomic, copy, nullable) AnClickTaskEngineRuntimeHandler runtimeHandler;

- (void)startRuntimeReset:(BOOL)reset;
- (void)pauseRuntime;
- (void)stopRuntimeReset:(BOOL)reset;
- (NSTimeInterval)runtime;
- (NSString *)formattedRuntime;

- (void)resetJumpGuard;
- (BOOL)recordJumpVisitForTaskIndex:(NSUInteger)index taskCount:(NSUInteger)taskCount;

- (void)invalidateScheduledCallbacks;
- (void)resetListRefreshThrottle;
- (BOOL)shouldRefreshListNow;

- (AnClickTaskEngineCursorDecision)decisionForTaskIndex:(NSUInteger)index
                                              taskCount:(NSUInteger)taskCount
                                    singleStepStopIndex:(NSInteger)singleStepStopIndex
                                           currentCycle:(NSInteger *)currentCycle
                                            repeatLimit:(NSInteger)repeatLimit;

- (BOOL)recordJumpVisitForTaskIndex:(NSUInteger)index
                           taskCount:(NSUInteger)taskCount
                       failureStatus:(NSString * _Nullable * _Nullable)failureStatus;

- (AnClickTaskEngineNetworkDecision)networkDecisionWithWaitsForCondition:(BOOL)waitsForCondition
                                                              retryForever:(BOOL)retryForever
                                                                retryLimit:(NSInteger)retryLimit
                                                                   attempt:(NSInteger)attempt
                                                                   matched:(BOOL)matched
                                                          requestSucceeded:(BOOL)requestSucceeded
                                                                   blocked:(BOOL)blocked
                                                             hasSuccessRule:(BOOL)hasSuccessRule
                                                            hasFailurePath:(BOOL)hasFailurePath;

- (AnClickTaskEngineRecognitionFailureDecision)recognitionFailureDecisionWithRetryUntilFound:(BOOL)retryUntilFound
                                                                                 repeatCount:(NSInteger)repeatCount
                                                                                     attempt:(NSInteger)attempt;

- (BOOL)recognitionAttemptExceedsLimit:(NSInteger)attempt
                           repeatCount:(NSInteger)repeatCount
                       retryUntilFound:(BOOL)retryUntilFound;

- (void)runTaskAtIndex:(NSUInteger)index host:(id _Nullable)host generation:(NSUInteger)generation;
- (void)continueTaskRunToIndex:(NSUInteger)nextIndex host:(id _Nullable)host generation:(NSUInteger)generation;
- (void)monitorGlobalNetworkGateWithHost:(id _Nullable)host scheduled:(BOOL)scheduled generation:(NSUInteger)generation;
- (void)scheduleRecognitionCaptureWithHost:(id _Nullable)host generation:(NSUInteger)generation delay:(NSTimeInterval)delay block:(AnClickTaskEngineRecognitionCaptureBlock)block;
- (void)runNetworkTaskModel:(AnClickTaskModel *)model atIndex:(NSUInteger)index host:(id _Nullable)host generation:(NSUInteger)generation;
- (void)runRecognitionTaskModel:(AnClickTaskModel *)model atIndex:(NSUInteger)index host:(id _Nullable)host generation:(NSUInteger)generation;

- (NSTimeInterval)coercedLoopInterval:(NSTimeInterval)interval repeatLimit:(NSInteger)repeatLimit;
- (void)scheduleAfter:(NSTimeInterval)delay
                guard:(nullable AnClickTaskEngineGuardBlock)guardBlock
                block:(AnClickTaskEngineScheduleBlock)block;

@end

NS_ASSUME_NONNULL_END
