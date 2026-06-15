#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <sys/proc.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import <math.h>
#import "AnClickTypes.h"
#import "AnClickTaskModel.h"
#import "AnClickTaskEngine.h"
#import "AnClickNetworkService.h"
#import "AnClickRecognitionService.h"
#import "AnClickPickerService.h"
#import "AnClickTemplateCaptureView.h"
#import "AnClickPointPickerView.h"
#import "AnClickColorPickerView.h"
#import "AnClickTaskEditorView.h"

#if ANCLICK_RELEASE_SILENT
#undef NSLog
#define NSLog(...) do {} while (0)
#endif

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef uint32_t IOHIDEventType;
typedef uint32_t IOHIDEventField;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientScheduleWithRunLoop(IOHIDEventSystemClientRef client, CFRunLoopRef runLoop, CFStringRef runLoopMode);
extern void IOHIDEventSystemClientRegisterEventCallback(IOHIDEventSystemClientRef client,
                                                        void (*callback)(void *target, void *refcon, IOHIDServiceClientRef service, IOHIDEventRef event),
                                                        void *target,
                                                        void *refcon);
extern IOHIDEventType IOHIDEventGetType(IOHIDEventRef event);
extern CFArrayRef IOHIDEventGetChildren(IOHIDEventRef event);
extern NSInteger IOHIDEventGetIntegerValue(IOHIDEventRef event, IOHIDEventField field);

static const NSUInteger AnClickMacroMaxTrajectoryPoints = 2400;
static const NSTimeInterval AnClickMacroMaxPlaybackDuration = 600.0;
static const double AnClickMacroMinPlaybackSpeed = 0.1;
static const double AnClickMacroMaxPlaybackSpeed = 10.0;
static const NSTimeInterval AnClickDefaultTapPressDuration = 0.030;
static const NSTimeInterval AnClickDefaultDoubleTapInterval = 0.100;
static const NSTimeInterval AnClickDefaultSwipeDuration = 0.300;
static const NSTimeInterval AnClickDefaultLongPressDuration = 0.500;
static const NSTimeInterval AnClickMinLongPressDuration = 0.500;
static const NSTimeInterval AnClickMaxLongPressDuration = 10.000;
static const NSTimeInterval AnClickMinInfiniteLoopInterval = 0.100;
static const NSTimeInterval AnClickRunProgressToastMinInterval = 1.200;
static const NSTimeInterval AnClickRunTraceMinInterval = 0.300;
static const NSTimeInterval AnClickMinJumpContinuationInterval = 0.030;
static const NSUInteger AnClickMaxJumpVisitsPerRun = 96;
static const CFTimeInterval AnClickRunListRefreshMinInterval = 0.75;
static const NSInteger AnClickBranchSuccessSuccessActionTagBase = 21000;
static const NSInteger AnClickBranchSuccessFailureActionTagBase = 22000;
static const NSInteger AnClickBranchFailureSuccessActionTagBase = 23000;
static const NSInteger AnClickBranchFailureFailureActionTagBase = 24000;
static const NSInteger AnClickBackdropBlurViewTag = 77001;
static char AnClickVolumeObservationContext;
static const IOHIDEventType AnClickHIDEventTypeKeyboard = 3;
#define AnClickHIDEventFieldBase(type) ((type) << 16)
static const IOHIDEventField AnClickHIDEventFieldKeyboardUsagePage = AnClickHIDEventFieldBase(AnClickHIDEventTypeKeyboard);
static const IOHIDEventField AnClickHIDEventFieldKeyboardUsage = AnClickHIDEventFieldBase(AnClickHIDEventTypeKeyboard) + 1;
static const IOHIDEventField AnClickHIDEventFieldKeyboardDown = AnClickHIDEventFieldBase(AnClickHIDEventTypeKeyboard) + 2;
static const NSInteger AnClickHIDUsagePageConsumer = 0x0C;
static const NSInteger AnClickHIDUsageConsumerVolumeIncrement = 0xE9;
static const NSInteger AnClickHIDUsageConsumerVolumeDecrement = 0xEA;
static const NSInteger AnClickSpringBoardVolumeUpButtonType = 102;
static const NSInteger AnClickSpringBoardVolumeDownButtonType = 103;
static const NSUInteger AnClickColorPickMaxSamples = 32;
static const NSUInteger AnClickMultiTapMaxPoints = 32;
static const NSUInteger ACPostPairLimit = 8;
static NSString * const AnClickTaskExpandedKey = @"isExpanded";
static NSString * const AnClickTaskListCellIdentifier = @"AnClickTaskListCell";
static const NSInteger AnClickTaskListEditButtonTagBase = 51000;
static const NSInteger AnClickTaskListRunButtonTagBase = 52000;
static const NSInteger AnClickTaskListCollapseButtonTagBase = 53000;
static const NSInteger AnClickHomeRunLabelTag = 54001;
static const NSInteger AnClickHomeStopLabelTag = 54002;
static const NSInteger AnClickHomeRecordLabelTag = 54003;
static const NSInteger AnClickHomeAddLabelTag = 54004;
static const NSInteger AnClickHomeDeleteLabelTag = 54005;
static const NSInteger AnClickHomeTimeLabelTag = 54006;
static const NSInteger AnClickHomeLoopLabelTag = 54007;
static const NSInteger AnClickHomeSaveLabelTag = 54008;
static const NSInteger AnClickHomeMonitorLabelTag = 54009;
static const NSInteger AnClickHomeOptionPanelTimeTag = 54101;
static const NSInteger AnClickHomeOptionPanelLoopTag = 54102;
static const NSInteger AnClickHomeOptionPanelSaveTag = 54103;
static const NSInteger AnClickHomeOptionPanelMonitorTag = 54104;
static const NSTimeInterval AnClickRecognitionCaptureDelay = 0.18;
static void (*AnClickOriginalWindowSendEvent)(id self, SEL _cmd, UIEvent *event);
static void (*AnClickOriginalSpringBoardHandlePhysicalButtonEvent)(id self, SEL _cmd, id event);

#ifndef P_TRACED
#define P_TRACED 0x00000800
#endif
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

extern int ptrace(int request, pid_t pid, void *addr, int data);

static NSTimeInterval AnClickLocalExpiryUnixTime(void) {
    const uint8_t encoded[] = {0x26, 0xA7, 0x1F, 0xF8, 0x0F, 0xC4, 0x78, 0xB3};
    const uint8_t masks[] = {0xA6, 0x31, 0x5D, 0x92, 0x0F, 0xC4, 0x78, 0xB3};
    uint64_t value = 0;
    for (size_t i = 0; i < sizeof(encoded); i++) {
        value |= ((uint64_t)(encoded[i] ^ masks[i])) << (8 * i);
    }
    if (((uint32_t)value ^ 0xA70C91EFu) != 0xCD4E076Fu ||
        value < 1600000000ULL ||
        value > 2200000000ULL) {
        return 1.0;
    }
    return (NSTimeInterval)value;
}

static NSString *AnClickLocalClockKey(void) {
    static NSString *clockKey = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const uint8_t encoded[] = {
            0x39, 0x35, 0x37, 0x74, 0x3B, 0x34, 0x39, 0x36, 0x33,
            0x39, 0x31, 0x74, 0x36, 0x35, 0x39, 0x3B, 0x36, 0x74,
            0x3D, 0x2F, 0x3B, 0x28, 0x3E, 0x74, 0x37, 0x3B, 0x22,
        };
        char decoded[sizeof(encoded) + 1];
        for (size_t i = 0; i < sizeof(encoded); i++) {
            decoded[i] = (char)(encoded[i] ^ 0x5A);
        }
        decoded[sizeof(encoded)] = '\0';
        clockKey = [[NSString alloc] initWithBytes:decoded length:sizeof(encoded) encoding:NSUTF8StringEncoding];
    });
    return clockKey;
}

static CFStringRef AnClickDecodedCFString(const uint8_t *encoded, size_t length, uint8_t mask) {
    if (!encoded || length == 0 || length > 96) {
        return CFSTR("");
    }
    UInt8 decoded[96];
    for (size_t i = 0; i < length; i++) {
        decoded[i] = (UInt8)(encoded[i] ^ mask);
    }
    return CFStringCreateWithBytes(kCFAllocatorDefault, decoded, (CFIndex)length, kCFStringEncodingUTF8, false);
}

static CFStringRef AnClickVolumeShortcutNotification(NSInteger direction) {
    static CFStringRef downName = NULL;
    static CFStringRef upName = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const uint8_t down[] = {
            0x48, 0x44, 0x46, 0x05, 0x4A, 0x45, 0x48, 0x47, 0x42, 0x48, 0x40, 0x05,
            0x5D, 0x44, 0x47, 0x5E, 0x46, 0x4E, 0x05, 0x4F, 0x44, 0x5C, 0x45,
        };
        const uint8_t up[] = {
            0x48, 0x44, 0x46, 0x05, 0x4A, 0x45, 0x48, 0x47, 0x42, 0x48, 0x40, 0x05,
            0x5D, 0x44, 0x47, 0x5E, 0x46, 0x4E, 0x05, 0x5E, 0x5B,
        };
        downName = AnClickDecodedCFString(down, sizeof(down), 0x2B);
        upName = AnClickDecodedCFString(up, sizeof(up), 0x2B);
    });
    return direction < 0 ? downName : upName;
}

static BOOL AnClickDebuggerAttached(void) {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    size_t size = sizeof(info);
    memset(&info, 0, sizeof(info));
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) {
        return NO;
    }
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

static void AnClickHardenLocalRuntime(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        (void)ptrace(PT_DENY_ATTACH, 0, NULL, 0);
    });
}

@class AnClickUI;
static void AnClickHardwareButtonEventCallback(void *target, void *refcon, IOHIDServiceClientRef service, IOHIDEventRef event);
static void AnClickVolumeDarwinNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static BOOL AnClickProcessIsSpringBoard(void);
static NSInteger AnClickVolumeShortcutDirectionFromPressesEvent(id event);
static NSInteger AnClickVolumeShortcutDirectionFromPhysicalButtonEvent(id event);
static NSNumber *AnClickNumberValueForObjectKeys(id object, NSArray<NSString *> *keys);
static void AnClickPostVolumeShortcutDirection(NSInteger direction);
static void AnClickInstallWindowPressEventHook(void);
static void AnClickInstallSpringBoardPhysicalButtonHook(void);
static void AnClickInstallSpringBoardVolumeControlHook(void);

@interface UIEvent (AnClickPressesEvent)
- (NSSet<UIPress *> *)allPresses;
@end

@interface AnClickFakeTouch : NSObject
+ (void)fastTapAtPoint:(CGPoint)point;
+ (void)fastDoubleTapAtPoint:(CGPoint)point;
+ (void)fastMultiTapAtPoints:(NSArray<NSValue *> *)points;
+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration;
+ (void)beginHoldAtPoint:(CGPoint)point;
+ (void)endHold;
+ (void)cancelHold;
+ (void)cancelAll;
+ (BOOL)isHolding;
+ (void)playPath:(NSArray<NSValue *> *)points duration:(NSTimeInterval)duration;
+ (void)playRecordedEvents:(NSArray<NSDictionary *> *)events;
+ (void)playRecordedEvents:(NSArray<NSDictionary *> *)events playbackSpeed:(NSTimeInterval)playbackSpeed;
+ (void)twoFingerTapAtPoint:(CGPoint)point distance:(CGFloat)distance;
+ (void)pinchAtPoint:(CGPoint)center fromDistance:(CGFloat)fromDistance toDistance:(CGFloat)toDistance duration:(NSTimeInterval)duration;
+ (void)rotateAtPoint:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle duration:(NSTimeInterval)duration;
@end

@interface AnClickRecorder : NSObject
+ (instancetype)shared;
- (void)startRecording;
- (NSArray *)stopRecording;
- (NSArray<NSDictionary *> *)serializedEvents;
@property (nonatomic, assign, getter=isRecording) BOOL recording;
@end

@interface AnClickUI : NSObject <UITextFieldDelegate, UIGestureRecognizerDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UITableViewDataSource, UITableViewDelegate, AnClickTaskEditorViewDelegate, AnClickTaskEngineDelegate, AnClickTemplateCaptureViewDelegate, AnClickPointPickerViewDelegate, AnClickColorPickerViewDelegate>
+ (instancetype)shared;
- (void)show;
- (void)handleScreenGeometryChanged;
- (void)handleHardwareButtonHIDEvent:(IOHIDEventRef)event;
- (void)handleWindowPressesEvent:(UIEvent *)event;
- (void)handleExternalVolumeShortcutDirection:(NSInteger)direction;
- (void)handleApplicationDidBecomeActive;
- (void)handleApplicationWillLeaveForeground;
- (void)applyScreenGeometryRefreshAllowHeavyRefresh:(BOOL)allowHeavyRefresh;
- (void)reclampPanelWindowForCurrentScreenAllowHeavyRefresh:(BOOL)allowHeavyRefresh;
- (void)refreshActivePanelOverlayLayoutAllowHeavyRefresh:(BOOL)allowHeavyRefresh;
- (void)refreshTaskEditorViewFromCurrentState;
- (void)updateStatusForCurrentConfig;
- (BOOL)screenCoordinateSizeIsValid:(CGSize)size;
- (CGSize)currentScreenCoordinateSize;
- (NSValue *)currentScreenCoordinateSizeValue;
- (CGSize)screenCoordinateSizeFromObject:(id)object;
- (NSArray<NSDictionary *> *)colorSamples:(NSArray<NSDictionary *> *)samples mappedFromScreenSize:(CGSize)sourceSize toScreenSize:(CGSize)targetSize;
- (CGSize)inferredRotatedSourceSizeForPoint:(CGPoint)point targetSize:(CGSize)targetSize;
- (void)showFunctionMenu;
- (void)showGlobalSettings;
- (void)showSaveTaskConfigNamePrompt;
- (void)showSavedConfigListForDeleting:(BOOL)deleting;
- (void)showDeleteSavedConfigConfirmationAtIndex:(NSInteger)index name:(NSString *)name taskCount:(NSUInteger)taskCount;
- (void)registerKeyboardAvoidanceObserversIfNeeded;
- (BOOL)currentEditorUsesNetworkPostPairs;
- (BOOL)currentEditorNetworkPostAllowsRecognitionResult;
- (void)cleanupScreenInteractionStateRestoringPanel:(BOOL)restorePanel;
- (void)showToast:(NSString *)message;
- (void)performSelectedActionAtPoint:(CGPoint)point inWindow:(UIWindow *)hostWindow preparePanel:(BOOL)preparePanel;
- (BOOL)panelCanUseCurrentScene;
- (void)clearTaskRunPauseState;
- (void)cancelRunningTaskSideEffects;
- (void)cancelActiveNetworkTasks;
- (void)stopTaskRunWithStatus:(NSString *)status showToast:(BOOL)showToast;
- (NSMutableDictionary *)taskDictionaryForModel:(AnClickTaskModel *)model;
- (BOOL)taskModelIsComplete:(AnClickTaskModel *)model;
- (NSTimeInterval)estimatedActionDurationForTask:(NSDictionary *)task success:(BOOL)success actionMode:(AnClickActionMode)actionMode depth:(NSUInteger)depth;
- (NSTimeInterval)estimatedActionDurationForTaskModel:(AnClickTaskModel *)model success:(BOOL)success actionMode:(AnClickActionMode)actionMode depth:(NSUInteger)depth;
- (NSTimeInterval)estimatedTaskDurationForTask:(NSDictionary *)task depth:(NSUInteger)depth;
- (NSTimeInterval)estimatedTaskDurationForTaskModel:(AnClickTaskModel *)model depth:(NSUInteger)depth;
@end

@implementation AnClickUI {
    UIWindow *_panelWindow;
    UIWindow *_toastWindow;
    UIView *_panelView;
    UIView *_homeBrandView;
    UIView *_homeOutputView;
    UIView *_toastView;
    UIView *_hostToastView;
    UIButton *_collapsedButton;
    UIButton *_addTaskButton;
    UIButton *_deleteTaskButton;
    UIButton *_runTasksButton;
    UIButton *_collapseButton;
    UIButton *_homeCloseButton;
    UIButton *_homeTimeButton;
    UIButton *_homeLoopButton;
    UIButton *_homeMonitorButton;
    UIButton *_homeSaveConfigButton;
    UIButton *_authorFollowButton;
    UIButton *_globalSettingsButton;
    UITableView *_taskListView;
    AnClickTaskEditorView *_taskEditorView;
    AnClickTaskModel *_editingTaskModel;
    UILabel *_statusLabel;
    UILabel *_toastLabel;
    UILabel *_hostToastLabel;
    UILabel *_toolTitleLabel;
    UILabel *_collapsedRuntimeLabel;
    NSString *_lastRunProgressToastText;
    CFTimeInterval _lastRunProgressToastTime;
    CFTimeInterval _lastRunTraceTime;
    AnClickTemplateCaptureView *_captureOverlay;
    AnClickPointPickerView *_pointPickOverlay;
    UIWindow *_pointPickWindow;
    UIWindow *_colorPickWindow;
    AnClickColorPickerView *_colorPickOverlay;
    UIImage *_captureSnapshot;
    UIImage *_pointPickSnapshot;
    UIImage *_colorPickImage;
    NSMutableData *_colorPickPixelData;
    UIView *_tapMarkerView;
    UIView *_recognitionBoxView;
    UIView *_operationTraceView;
    UIView *_trajectoryView;
    UIView *_taskReorderSnapshotView;
    CAShapeLayer *_trajectoryLayer;
    UIView *_functionMenuView;
    UIView *_configPromptView;
    UIView *_globalSettingsView;
    UIScrollView *_globalSettingsScrollView;
    UITextField *_globalDelayField;
    UITextField *_globalRepeatField;
    UITextField *_configNameField;
    UITextField *_globalNetworkURLField;
    UITextField *_globalNetworkContainsField;
    UITextField *_globalNetworkFalseField;
    UIButton *_globalStartTimeButton;
    UIButton *_globalStopTimeButton;
    UIButton *_globalNetworkGateButton;
    UIView *_globalTimePickerView;
    UIPickerView *_globalTimePicker;
    UIScrollView *_configListView;
    NSMutableArray<NSMutableDictionary *> *_networkPostPairs;
    NSMutableArray<NSValue *> *_multiTapPoints;
    NSMutableArray<NSValue *> *_recordedSwipePoints;
    NSMutableArray<NSValue *> *_liveSwipePoints;
    NSArray<NSDictionary *> *_recordedMacroEvents;
    NSMutableArray<AnClickTaskModel *> *_taskItems;
    NSInteger _selectedTaskIndex;
    NSInteger _editingTaskIndex;
    NSInteger _draggingTaskIndex;
    NSInteger _pendingConfigDeleteIndex;
    CGFloat _taskReorderStartLocationY;
    CGFloat _taskReorderStartCenterY;
    BOOL _taskReordering;
    BOOL _configListDeleting;
    CGPoint _manualActionPoints[AnClickActionModeCount];
    BOOL _hasManualActionPoint[AnClickActionModeCount];
    CGPoint _manualSwipeAnchor;
    BOOL _hasManualSwipeAnchor;
    CGPoint _manualSwipeEndPoint;
    BOOL _hasManualSwipeEndPoint;
    CGPoint _successActionPoint;
    BOOL _hasSuccessActionPoint;
    CGPoint _failureActionPoint;
    BOOL _hasFailureActionPoint;
    CGSize _manualCoordinateScreenSize;
    BOOL _hasManualCoordinateScreenSize;
    BOOL _pickingSwipeEndPoint;
    BOOL _pickingFailureActionPoint;
    CGPoint _pendingPointPickPoint;
    BOOL _hasPendingPointPickPoint;
    BOOL _longPressHolding;
    BOOL _pickingSuccessActionPoint;
    BOOL _templateSearchInProgress;
    BOOL _branchTemplateCaptureActive;
    BOOL _branchTemplateCaptureSuccess;
    CGRect _collapsedPanelFrame;
    CGPoint _collapsedPanelOriginRatio;
    CGSize _collapsedPanelScreenSize;
    BOOL _hasCollapsedPanelFrame;
    BOOL _hasCollapsedPanelOriginRatio;
    CGRect _expandedPanelFrame;
    CGPoint _expandedPanelOriginRatio;
    CGSize _expandedPanelScreenSize;
    BOOL _hasExpandedPanelFrame;
    BOOL _hasExpandedPanelOriginRatio;
    BOOL _panelExpanded;
    BOOL _taskEditorVisible;
    BOOL _imageUsesMatchPoint;
    BOOL _ocrUsesMatchPoint;
    BOOL _returnToEditorAfterRecording;
    BOOL _globalStartEnabled;
    BOOL _globalStopEnabled;
    BOOL _globalNetworkGateEnabled;
    BOOL _networkRequestOnly;
    BOOL _networkUsesPost;
    BOOL _networkPostBodyUsesOCRResult;
    BOOL _networkRetryForever;
    BOOL _recognitionRetryUntilFound;
    BOOL _recognitionRetryDropdownVisible;
    BOOL _actionRandomDelayEnabled;
    BOOL _globalTimePickerEditingStartTime;
    BOOL _taskRunActive;
    BOOL _taskRunPausedForForeground;
    BOOL _taskRunResumeInGlobalNetworkGate;
    BOOL _taskRunResumeScheduled;
    BOOL _panelHiddenForSingleStepTest;
    BOOL _volumeShortcutRegistered;
    BOOL _volumeKVORegistered;
    BOOL _volumeDarwinObserverRegistered;
    BOOL _hardwareVolumeButtonObserverRegistered;
    BOOL _keyboardAvoidanceObserversRegistered;
    BOOL _keyboardVisible;
    BOOL _hasObservedSystemVolume;
    BOOL _volumeShortcutRunSuppressToasts;
    BOOL _suppressTemplatePreviewRefresh;
    NSUInteger _panelRestoreGeneration;
    NSUInteger _taskRunGeneration;
    NSUInteger _toastGeneration;
    NSUInteger _screenGeometryGeneration;
    NSUInteger _screenGeometryRefreshGeneration;
    CGSize _lastAppliedScreenGeometrySize;
    CGSize _recordedMacroScreenSize;
    CFTimeInterval _toastDeferNonVolumeUntil;
    CFTimeInterval _lastVolumeShortcutTime;
    CFTimeInterval _ignoreVolumeEventsUntil;
    NSInteger _globalDelayMilliseconds;
    NSInteger _globalRunRepeatCount;
    NSInteger _globalLoopIntervalSeconds;
    NSInteger _globalStartHour;
    NSInteger _globalStartMinute;
    NSInteger _globalStartSecond;
    NSInteger _globalStartMillisecond;
    NSInteger _globalStopHour;
    NSInteger _globalStopMinute;
    NSInteger _globalStopSecond;
    NSInteger _globalStopMillisecond;
    NSInteger _currentGlobalRunCycle;
    NSInteger _taskRunSingleStepStopIndex;
    NSInteger _taskRunResumeCycle;
    NSUInteger _taskRunResumeIndex;
    AnClickTaskEngine *_taskEngine;
    NSInteger _targetColorRed;
    NSInteger _targetColorGreen;
    NSInteger _targetColorBlue;
    NSInteger _pendingColorRed;
    NSInteger _pendingColorGreen;
    NSInteger _pendingColorBlue;
    BOOL _hasTargetColor;
    size_t _colorPickPixelWidth;
    size_t _colorPickPixelHeight;
    size_t _colorPickPixelBytesPerRow;
    float _lastObservedSystemVolume;
    CGPoint _pendingColorPickPoint;
    BOOL _hasPendingColorPickPoint;
    BOOL _hasRecordedMacroScreenSize;
    NSInteger _selectedColorPickSampleIndex;
    NSTimeInterval _networkTimeout;
    NSTimeInterval _recognitionRetryInterval;
    double _macroPlaybackSpeed;
    NSTimeInterval _longPressDuration;
    NSTimeInterval _actionInterval;
    CGFloat _actionJitterRadius;
    double _colorTolerance;
    NSTimer *_globalStartTimer;
    NSTimer *_globalStopTimer;
    IOHIDEventSystemClientRef _hardwareVolumeButtonClient;
    MPVolumeView *_volumeView;
    UISlider *_volumeSlider;
    double _matchThreshold;
    NSTimeInterval _actionDelay;
    NSInteger _actionRepeatCount;
    NSInteger _recognitionSuccessBranchIndex;
    NSInteger _recognitionFailureBranchIndex;
    NSInteger _editingBranchOwnerTaskIndex;
    AnClickTaskModel *_editingNestedBranchParentModel;
    NSString *_currentTemplatePath;
    NSCache<NSString *, UIImage *> *_templateImageCache;
    NSMutableDictionary<NSString *, NSDate *> *_templateImageModificationDates;
    NSString *_actionDescription;
    NSString *_ocrTargetText;
    NSString *_networkURL;
    NSString *_networkContainsText;
    NSString *_networkFalseText;
    NSString *_networkPostBody;
    NSString *_globalNetworkURL;
    NSString *_globalNetworkContainsText;
    NSString *_globalNetworkFalseText;
    AnClickNetworkService *_networkService;
    AnClickRecognitionService *_recognitionService;
    AnClickPickerService *_pickerService;
    UITextField *_activeConfigTextField;
    CGRect _keyboardFrameInScreen;
    NSMutableArray<NSDictionary *> *_targetColorSamples;
    NSMutableArray<NSDictionary *> *_pendingColorPickSamples;
    AnClickActionMode _actionMode;
    AnClickActionMode _imageActionMode;
    AnClickActionMode _failureActionMode;
    AnClickActionMode _editingBranchActionMode;
    AnClickActionMode _editingNestedBranchActionMode;
    AnClickActionMode _branchTemplateCaptureMode;
    AnClickActionMode _branchColorPickMode;
    AnClickOCRMode _ocrMode;
    AnClickOCRMatchMode _ocrMatchMode;
    UIWindow *_pointPickHostWindow;
    BOOL _panelSceneUnavailable;
    BOOL _editingBranchRecognitionConfig;
    BOOL _editingBranchRecognitionSuccess;
    BOOL _editingNestedBranchActionConfig;
    BOOL _editingNestedBranchActionSuccess;
    BOOL _branchColorPickActive;
    BOOL _branchColorPickSuccess;
    BOOL _pickingBranchRecognitionResultPoint;
    BOOL _pickingBranchRecognitionResultSuccess;
}

- (UIColor *)themeHighlightColor {
    return [UIColor colorWithRed:0.00 green:0.42 blue:1.00 alpha:1.0];
}

- (UIColor *)themeDangerColor {
    return [UIColor colorWithRed:1.00 green:0.22 blue:0.20 alpha:1.0];
}

- (UIColor *)themeSuccessColor {
    return [UIColor colorWithRed:0.12 green:0.68 blue:0.37 alpha:1.0];
}

- (UIColor *)themeWarningColor {
    return [UIColor colorWithRed:1.00 green:0.58 blue:0.12 alpha:1.0];
}

- (UIColor *)themePurpleColor {
    return [UIColor colorWithRed:0.46 green:0.34 blue:0.90 alpha:1.0];
}

- (UIColor *)themeTealColor {
    return [UIColor colorWithRed:0.00 green:0.63 blue:0.72 alpha:1.0];
}

- (UIColor *)floatingButtonIdleColor {
    return [UIColor colorWithRed:0.03 green:0.78 blue:0.28 alpha:0.98];
}

- (UIColor *)floatingButtonIdleBorderColor {
    return [UIColor colorWithRed:0.82 green:1.00 blue:0.28 alpha:0.95];
}

- (UIColor *)floatingButtonIdleShadowColor {
    return [UIColor colorWithRed:0.08 green:0.95 blue:0.34 alpha:1.0];
}

- (UIColor *)themePanelDarkColor {
    return [UIColor colorWithRed:0.955 green:0.970 blue:0.992 alpha:0.88];
}

- (UIColor *)themeSurfaceColor {
    return [UIColor colorWithRed:1.000 green:1.000 blue:1.000 alpha:0.78];
}

- (UIColor *)themeControlFillColor {
    return [UIColor colorWithRed:0.965 green:0.975 blue:0.992 alpha:0.72];
}

- (UIColor *)themePrimaryTextColor {
    return [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0];
}

- (UIColor *)themeSecondaryTextColor {
    return [UIColor colorWithRed:0.38 green:0.39 blue:0.44 alpha:1.0];
}

- (UIColor *)themeSeparatorColor {
    return [UIColor colorWithRed:0.76 green:0.80 blue:0.88 alpha:1.0];
}

- (UIColor *)glassHighlightBorderColor {
    return [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:0.72];
}

- (UIColor *)neumorphicShadowColor {
    return [UIColor colorWithRed:0.40 green:0.48 blue:0.62 alpha:1.0];
}

- (UIColor *)branchRoleColorForSuccess:(BOOL)success {
    return success
        ? [UIColor colorWithRed:0.02 green:0.52 blue:0.23 alpha:1.0]
        : [UIColor colorWithRed:0.86 green:0.07 blue:0.10 alpha:1.0];
}

- (UIColor *)branchRoleFillColorForSuccess:(BOOL)success {
    UIColor *color = [self branchRoleColorForSuccess:success];
    return [color colorWithAlphaComponent:success ? 0.13 : 0.12];
}

- (UIColor *)editorSectionTintColorAtIndex:(NSUInteger)index {
    switch (index % 6) {
        case 0:
            return [UIColor colorWithRed:1.000 green:1.000 blue:1.000 alpha:0.72];
        case 1:
            return [UIColor colorWithRed:0.930 green:0.970 blue:1.000 alpha:0.70];
        case 2:
            return [UIColor colorWithRed:0.930 green:0.990 blue:0.965 alpha:0.70];
        case 3:
            return [UIColor colorWithRed:1.000 green:0.965 blue:0.920 alpha:0.70];
        case 4:
            return [UIColor colorWithRed:0.950 green:0.940 blue:1.000 alpha:0.70];
        case 5:
            return [UIColor colorWithRed:0.925 green:0.990 blue:1.000 alpha:0.70];
        default:
            return [self themeSurfaceColor];
    }
}

- (UIColor *)editorSectionBorderColorAtIndex:(NSUInteger)index {
    switch (index % 6) {
        case 0:
            return [[self themeSeparatorColor] colorWithAlphaComponent:0.82];
        case 1:
            return [UIColor colorWithRed:0.68 green:0.84 blue:1.00 alpha:1.0];
        case 2:
            return [UIColor colorWithRed:0.68 green:0.90 blue:0.76 alpha:1.0];
        case 3:
            return [UIColor colorWithRed:1.00 green:0.78 blue:0.58 alpha:1.0];
        case 4:
            return [UIColor colorWithRed:0.76 green:0.72 blue:1.00 alpha:1.0];
        case 5:
            return [UIColor colorWithRed:0.62 green:0.86 blue:0.94 alpha:1.0];
        default:
            return [[self themeSeparatorColor] colorWithAlphaComponent:0.72];
    }
}

- (UIColor *)accentColorForActionMode:(AnClickActionMode)mode {
    switch (mode) {
        case AnClickActionModeTap:
        case AnClickActionModeDoubleTap:
        case AnClickActionModeTwoFingerTap:
            return [self themeSuccessColor];
        case AnClickActionModeLongPress:
        case AnClickActionModeSwipe:
        case AnClickActionModeMacro:
            return [self themeWarningColor];
        case AnClickActionModeImage:
            return [self themeHighlightColor];
        case AnClickActionModeOCR:
            return [self themePurpleColor];
        case AnClickActionModeColor:
            return [self themeTealColor];
        case AnClickActionModeNetwork:
            return [UIColor colorWithRed:0.10 green:0.55 blue:0.95 alpha:1.0];
        case AnClickActionModeJump:
            return [UIColor colorWithRed:0.44 green:0.42 blue:0.86 alpha:1.0];
        case AnClickActionModeDelay:
            return [self themeWarningColor];
        default:
            return [self themeHighlightColor];
    }
}

- (UIColor *)accentColorForButton:(UIButton *)button {
    if (!button) {
        return [self themeHighlightColor];
    }
    NSString *title = button.currentTitle ?: button.titleLabel.text ?: @"";
    if ([title containsString:@"识字"] || [title containsString:@"正则"] || [title containsString:@"文字"]) {
        return [self themePurpleColor];
    }
    if ([title containsString:@"识色"] || [title containsString:@"颜色"] || [title containsString:@"取色"]) {
        return [self themeTealColor];
    }
    if ([title containsString:@"网络"] || [title containsString:@"请求"] || [title containsString:@"GET"] || [title containsString:@"POST"]) {
        return [UIColor colorWithRed:0.10 green:0.55 blue:0.95 alpha:1.0];
    }
    if ([title containsString:@"跳转"]) {
        return [self themePurpleColor];
    }
    if ([title containsString:@"删除"] || [title containsString:@"清空"] || [title containsString:@"失败"] || [title containsString:@"停止"]) {
        return [self themeDangerColor];
    }
    if ([title containsString:@"录制"] || [title containsString:@"滑动"] || [title containsString:@"长按"]) {
        return [self themeWarningColor];
    }
    if ([title containsString:@"点击"] || [title containsString:@"双击"] || [title containsString:@"多指"] || [title containsString:@"触点"] || [title containsString:@"取点"] || [title containsString:@"位置"] || [title containsString:@"执行"]) {
        return [self themeSuccessColor];
    }
    return [self themeHighlightColor];
}

- (NSString *)toolDisplayName {
    return @"安姐点击器V2.0";
}

- (void)markPanelSceneUnavailable {
    _panelSceneUnavailable = YES;
    _volumeShortcutRunSuppressToasts = NO;
    [self cancelRunningTaskSideEffects];
    if (_taskRunActive || _taskRunPausedForForeground) {
        _taskRunActive = NO;
        [self clearTaskRunPauseState];
        _currentGlobalRunCycle = 0;
        _taskRunGeneration++;
        [self resetTaskRunJumpGuard];
        [self stopTaskRunRuntimeTimerReset:YES];
    }
    _panelWindow.hidden = YES;
    _toastWindow.hidden = YES;
    _toastView.hidden = YES;
    _hostToastView.hidden = YES;
    [self refreshCollapsedButtonTitle];
    [self refreshTaskList];
}

- (BOOL)panelCanUseCurrentScene {
    BOOL blocked = NO;
    if (AnClickDebuggerAttached()) {
        blocked = YES;
    } else {
        NSTimeInterval expiry = AnClickLocalExpiryUnixTime();
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        if (expiry <= 1.0 || now < 978307200.0) {
            blocked = YES;
        } else {
            NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
            NSString *clockKey = AnClickLocalClockKey();
            NSTimeInterval maxSeen = [defaults doubleForKey:clockKey];
            if (now > maxSeen + 30.0) {
                [defaults setDouble:now forKey:clockKey];
                [defaults synchronize];
                maxSeen = now;
            }
            if (maxSeen >= expiry) {
                blocked = YES;
            } else if (maxSeen > 0.0 && now + 600.0 < maxSeen) {
                blocked = YES;
            } else if (now >= expiry) {
                blocked = YES;
            }
        }
    }
    if (blocked || _panelSceneUnavailable) {
        [self markPanelSceneUnavailable];
        return NO;
    }
    return YES;
}

- (NSMutableArray<NSDictionary *> *)mutableColorSamplesArrayFromObject:(id)object {
    NSMutableArray<NSDictionary *> *samples = [NSMutableArray array];
    if (![object isKindOfClass:NSArray.class]) {
        return samples;
    }

    for (NSDictionary *sample in (NSArray *)object) {
        if (![sample isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSNumber *redNumber = AnClickNumberValueForObjectKeys(sample, @[@"red", @"r"]);
        NSNumber *greenNumber = AnClickNumberValueForObjectKeys(sample, @[@"green", @"g"]);
        NSNumber *blueNumber = AnClickNumberValueForObjectKeys(sample, @[@"blue", @"b"]);
        NSNumber *xNumber = AnClickNumberValueForObjectKeys(sample, @[@"x"]);
        NSNumber *yNumber = AnClickNumberValueForObjectKeys(sample, @[@"y"]);
        NSNumber *dxNumber = AnClickNumberValueForObjectKeys(sample, @[@"dx"]);
        NSNumber *dyNumber = AnClickNumberValueForObjectKeys(sample, @[@"dy"]);
        if (!redNumber || !greenNumber || !blueNumber) {
            continue;
        }
        NSMutableDictionary *normalized = [@{
            @"red": @(MIN(255, MAX(0, redNumber.integerValue))),
            @"green": @(MIN(255, MAX(0, greenNumber.integerValue))),
            @"blue": @(MIN(255, MAX(0, blueNumber.integerValue))),
        } mutableCopy];
        if (xNumber && yNumber) {
            normalized[@"x"] = @(xNumber.doubleValue);
            normalized[@"y"] = @(yNumber.doubleValue);
        }
        if (dxNumber && dyNumber) {
            normalized[@"dx"] = @(dxNumber.doubleValue);
            normalized[@"dy"] = @(dyNumber.doubleValue);
        }
        [samples addObject:normalized];
        if (samples.count >= AnClickColorPickMaxSamples) {
            break;
        }
    }
    return samples;
}

- (NSArray<NSDictionary *> *)colorSamplesForPersistence:(NSArray<NSDictionary *> *)samples {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    for (NSDictionary *sample in [self mutableColorSamplesArrayFromObject:samples]) {
        [result addObject:[sample copy]];
    }
    return result;
}

- (NSArray<NSDictionary *> *)effectiveTargetColorSamples {
    if (_targetColorSamples.count > 0) {
        return [self colorSamplesForPersistence:_targetColorSamples];
    }
    if (!_hasTargetColor) {
        return @[];
    }
    return @[@{
        @"dx": @(0.0),
        @"dy": @(0.0),
        @"red": @(_targetColorRed),
        @"green": @(_targetColorGreen),
        @"blue": @(_targetColorBlue),
    }];
}

- (void)applyTargetColorSamples:(NSArray<NSDictionary *> *)samples {
    _targetColorSamples = [[self mutableColorSamplesArrayFromObject:samples] mutableCopy];
    NSDictionary *anchor = _targetColorSamples.firstObject;
    if (anchor) {
        _targetColorRed = MIN(255, MAX(0, [anchor[@"red"] integerValue]));
        _targetColorGreen = MIN(255, MAX(0, [anchor[@"green"] integerValue]));
        _targetColorBlue = MIN(255, MAX(0, [anchor[@"blue"] integerValue]));
        _hasTargetColor = YES;
    } else {
        _targetColorRed = 0;
        _targetColorGreen = 0;
        _targetColorBlue = 0;
        _hasTargetColor = NO;
    }
}

- (NSString *)colorHexStringForSample:(NSDictionary *)sample {
    NSInteger red = MIN(255, MAX(0, [sample[@"red"] integerValue]));
    NSInteger green = MIN(255, MAX(0, [sample[@"green"] integerValue]));
    NSInteger blue = MIN(255, MAX(0, [sample[@"blue"] integerValue]));
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX", (long)red, (long)green, (long)blue];
}

- (UIColor *)uiColorForColorSample:(NSDictionary *)sample fallback:(UIColor *)fallback {
    if (![sample isKindOfClass:NSDictionary.class]) {
        return fallback ?: [UIColor colorWithWhite:1 alpha:0.10];
    }
    NSInteger red = MIN(255, MAX(0, [sample[@"red"] integerValue]));
    NSInteger green = MIN(255, MAX(0, [sample[@"green"] integerValue]));
    NSInteger blue = MIN(255, MAX(0, [sample[@"blue"] integerValue]));
    return [UIColor colorWithRed:red / 255.0
                           green:green / 255.0
                            blue:blue / 255.0
                           alpha:1.0];
}

- (NSString *)targetColorShortDescription {
    NSArray<NSDictionary *> *samples = [self effectiveTargetColorSamples];
    if (samples.count == 0) {
        return @"先取色";
    }
    if (samples.count == 1) {
        return [self colorHexStringForSample:samples.firstObject];
    }
    return [NSString stringWithFormat:@"%@ +%lu点", [self colorHexStringForSample:samples.firstObject], (unsigned long)samples.count - 1];
}

- (NSString *)targetColorDetailedDescription {
    NSArray<NSDictionary *> *samples = [self effectiveTargetColorSamples];
    if (samples.count == 0) {
        return @"先取色";
    }
    if (samples.count == 1) {
        return [NSString stringWithFormat:@"%@ 点击点", [self colorHexStringForSample:samples.firstObject]];
    }
    return [NSString stringWithFormat:@"已取%lu点 %@为点击点", (unsigned long)samples.count, [self colorHexStringForSample:samples.firstObject]];
}

- (NSArray<NSDictionary *> *)normalizedColorPatternPointsForTask:(NSDictionary *)task {
    NSArray<NSDictionary *> *samples = [self mutableColorSamplesArrayFromObject:task[@"colorPoints"]];
    if (samples.count > 0) {
        CGSize sourceSize = [self screenCoordinateSizeFromObject:task[@"colorPointScreenSize"]];
        CGSize targetSize = [self currentScreenCoordinateSize];
        if (![self screenCoordinateSizeIsValid:sourceSize]) {
            NSDictionary *anchor = samples.firstObject;
            if ([anchor[@"x"] respondsToSelector:@selector(doubleValue)] &&
                [anchor[@"y"] respondsToSelector:@selector(doubleValue)]) {
                CGPoint anchorPoint = CGPointMake([anchor[@"x"] doubleValue], [anchor[@"y"] doubleValue]);
                sourceSize = [self inferredRotatedSourceSizeForPoint:anchorPoint targetSize:targetSize];
            }
        }
        samples = [self colorSamples:samples mappedFromScreenSize:sourceSize toScreenSize:targetSize];
    }
    if (samples.count > 0) {
        NSMutableArray<NSDictionary *> *points = [NSMutableArray arrayWithCapacity:samples.count];
        NSDictionary *anchor = samples.firstObject;
        CGFloat anchorX = [anchor[@"x"] respondsToSelector:@selector(doubleValue)] ? [anchor[@"x"] doubleValue] : 0.0;
        CGFloat anchorY = [anchor[@"y"] respondsToSelector:@selector(doubleValue)] ? [anchor[@"y"] doubleValue] : 0.0;
        for (NSDictionary *sample in samples) {
            CGFloat dx = [sample[@"dx"] respondsToSelector:@selector(doubleValue)] ? [sample[@"dx"] doubleValue] : 0.0;
            CGFloat dy = [sample[@"dy"] respondsToSelector:@selector(doubleValue)] ? [sample[@"dy"] doubleValue] : 0.0;
            NSNumber *xNumber = [sample[@"x"] respondsToSelector:@selector(doubleValue)] ? @([sample[@"x"] doubleValue]) : nil;
            NSNumber *yNumber = [sample[@"y"] respondsToSelector:@selector(doubleValue)] ? @([sample[@"y"] doubleValue]) : nil;
            if (![sample[@"dx"] respondsToSelector:@selector(doubleValue)] &&
                [sample[@"x"] respondsToSelector:@selector(doubleValue)] &&
                [sample[@"y"] respondsToSelector:@selector(doubleValue)]) {
                dx = [sample[@"x"] doubleValue] - anchorX;
                dy = [sample[@"y"] doubleValue] - anchorY;
            }
            NSMutableDictionary *point = [@{
                @"dx": @(dx),
                @"dy": @(dy),
                @"red": @([sample[@"red"] integerValue]),
                @"green": @([sample[@"green"] integerValue]),
                @"blue": @([sample[@"blue"] integerValue]),
            } mutableCopy];
            if (xNumber && yNumber) {
                point[@"x"] = xNumber;
                point[@"y"] = yNumber;
            }
            [points addObject:point];
        }
        return points;
    }

    if (![task[@"colorRed"] respondsToSelector:@selector(integerValue)] ||
        ![task[@"colorGreen"] respondsToSelector:@selector(integerValue)] ||
        ![task[@"colorBlue"] respondsToSelector:@selector(integerValue)]) {
        return @[];
    }
    return @[@{
        @"dx": @(0.0),
        @"dy": @(0.0),
        @"red": @([task[@"colorRed"] integerValue]),
        @"green": @([task[@"colorGreen"] integerValue]),
        @"blue": @([task[@"colorBlue"] integerValue]),
    }];
}

- (NSString *)colorPatternSummaryForTask:(NSDictionary *)task {
    NSArray<NSDictionary *> *points = [self normalizedColorPatternPointsForTask:task];
    if (points.count == 0) {
        return @"未取色";
    }
    NSString *hex = [self colorHexStringForSample:points.firstObject];
    if (points.count <= 1) {
        return hex;
    }
    return [NSString stringWithFormat:@"%@ +%lu点", hex, (unsigned long)points.count - 1];
}

- (NSSet *)archiveAllowedClasses {
    return [NSSet setWithObjects:
            NSArray.class,
            NSMutableArray.class,
            NSDictionary.class,
            NSMutableDictionary.class,
            NSString.class,
            NSNumber.class,
            NSValue.class,
            AnClickTaskModel.class,
            nil];
}

- (dispatch_queue_t)diskIOQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

- (void)installDarkBlurInView:(UIView *)view cornerRadius:(CGFloat)cornerRadius {
    if (!view) {
        return;
    }

    [[view viewWithTag:AnClickBackdropBlurViewTag] removeFromSuperview];
    view.backgroundColor = [[self themePanelDarkColor] colorWithAlphaComponent:0.78];
    UIBlurEffect *effect = nil;
    if (@available(iOS 13.0, *)) {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
    } else {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.tag = AnClickBackdropBlurViewTag;
    blurView.frame = view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.userInteractionEnabled = NO;
    blurView.layer.cornerRadius = cornerRadius;
    blurView.clipsToBounds = YES;
    blurView.contentView.backgroundColor = [[self themePanelDarkColor] colorWithAlphaComponent:0.38];
    [view insertSubview:blurView atIndex:0];
}

- (void)applyFrostedRoundButtonStyle:(UIButton *)button {
    button.backgroundColor = [[self themeControlFillColor] colorWithAlphaComponent:0.78];
    button.layer.cornerRadius = MAX(8.0, button.layer.cornerRadius);
    button.layer.masksToBounds = NO;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [[self glassHighlightBorderColor] colorWithAlphaComponent:0.80].CGColor;
    button.layer.shadowColor = [self neumorphicShadowColor].CGColor;
    button.layer.shadowOffset = CGSizeMake(3, 4);
    button.layer.shadowRadius = 8.0;
    button.layer.shadowOpacity = 0.10;
    [button setTitleColor:[self themeHighlightColor] forState:UIControlStateNormal];
    button.tintColor = [self themeHighlightColor];
    [self updateButtonShadowPath:button];
}

+ (instancetype)shared {
    static AnClickUI *ui = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ui = [[AnClickUI alloc] init];
    });
    return ui;
}

- (void)show {
    void (^showBlock)(void) = ^{
        if (![self panelCanUseCurrentScene]) {
            return;
        }
        if (self->_panelWindow) {
            [self attachPanelWindowToActiveSceneIfNeeded];
            [self registerVolumeShortcutObserver];
            [self scheduleGlobalTimers];
            self->_panelWindow.hidden = NO;
            [self reclampPanelWindowForCurrentScreen];
            [self refreshCollapsedButtonTitle];
            return;
        }
        [self buildPanel];
    };
    if (NSThread.isMainThread) {
        showBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), showBlock);
    }
}

- (void)registerVolumeShortcutObserver {
    [self activateVolumeShortcutAudioSession];
    [self installVolumeShortcutControl];
    [self registerVolumeOutputObserverIfNeeded];
    [self registerVolumeDarwinObserverIfNeeded];
    [self registerHardwareVolumeButtonObserverIfNeeded];

    if (_volumeShortcutRegistered) {
        return;
    }

    _volumeShortcutRegistered = YES;
    _lastObservedSystemVolume = AVAudioSession.sharedInstance.outputVolume;
    _hasObservedSystemVolume = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSystemVolumeDidChange:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
}

- (void)registerVolumeDarwinObserverIfNeeded {
    if (_volumeDarwinObserverRegistered) {
        return;
    }

    _volumeDarwinObserverRegistered = YES;
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center,
                                    (__bridge const void *)self,
                                    AnClickVolumeDarwinNotificationCallback,
                                    AnClickVolumeShortcutNotification(-1),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center,
                                    (__bridge const void *)self,
                                    AnClickVolumeDarwinNotificationCallback,
                                    AnClickVolumeShortcutNotification(1),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (void)registerHardwareVolumeButtonObserverIfNeeded {
    if (_hardwareVolumeButtonObserverRegistered) {
        return;
    }

    _hardwareVolumeButtonClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!_hardwareVolumeButtonClient) {
        NSLog(@"[AnClick] Hardware volume shortcut HID client unavailable");
        return;
    }

    IOHIDEventSystemClientRegisterEventCallback(_hardwareVolumeButtonClient,
                                                AnClickHardwareButtonEventCallback,
                                                (__bridge void *)self,
                                                NULL);
    IOHIDEventSystemClientScheduleWithRunLoop(_hardwareVolumeButtonClient,
                                              CFRunLoopGetMain(),
                                              kCFRunLoopCommonModes);
    _hardwareVolumeButtonObserverRegistered = YES;
}

- (void)registerVolumeOutputObserverIfNeeded {
    if (_volumeKVORegistered) {
        return;
    }

    _volumeKVORegistered = YES;
    [AVAudioSession.sharedInstance addObserver:self
                                    forKeyPath:@"outputVolume"
                                       options:NSKeyValueObservingOptionNew
                                       context:&AnClickVolumeObservationContext];
}

- (void)activateVolumeShortcutAudioSession {
    AVAudioSession *session = AVAudioSession.sharedInstance;
    NSError *error = nil;
    if (![session setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error]) {
        NSLog(@"[AnClick] Volume shortcut audio category error: %@", error);
    }
    error = nil;
    if (![session setActive:YES error:&error]) {
        NSLog(@"[AnClick] Volume shortcut audio active error: %@", error);
    }
}

- (UISlider *)volumeSliderInView:(UIView *)view {
    if ([view isKindOfClass:UISlider.class]) {
        return (UISlider *)view;
    }
    for (UIView *subview in view.subviews) {
        UISlider *slider = [self volumeSliderInView:subview];
        if (slider) {
            return slider;
        }
    }
    return nil;
}

- (void)refreshVolumeSliderReference {
    _volumeSlider = _volumeView ? [self volumeSliderInView:_volumeView] : nil;
}

- (void)installVolumeShortcutControl {
    UIWindow *hostWindow = [self hostWindow];
    UIView *hostView = hostWindow.rootViewController.view;
    if (!hostView) {
        hostView = hostWindow;
    }
    if (!hostView) {
        hostView = _panelWindow.rootViewController.view;
    }
    if (!hostView) {
        hostView = _panelWindow;
    }
    if (!hostView) {
        return;
    }

    if (!_volumeView) {
        _volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
        _volumeView.alpha = 0.01;
        _volumeView.userInteractionEnabled = NO;
        _volumeView.showsVolumeSlider = YES;
        _volumeView.accessibilityElementsHidden = YES;
    }
    if (_volumeView.superview != hostView) {
        [_volumeView removeFromSuperview];
        [hostView insertSubview:_volumeView atIndex:0];
    }
    [_volumeView setNeedsLayout];
    [_volumeView layoutIfNeeded];
    [self refreshVolumeSliderReference];
    [_volumeSlider removeTarget:self action:@selector(handleVolumeSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_volumeSlider addTarget:self action:@selector(handleVolumeSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    float currentVolume = AVAudioSession.sharedInstance.outputVolume;
    _lastObservedSystemVolume = currentVolume;
    _hasObservedSystemVolume = YES;

    if (!_volumeSlider) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf refreshVolumeSliderReference];
            [strongSelf->_volumeSlider removeTarget:strongSelf action:@selector(handleVolumeSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
            [strongSelf->_volumeSlider addTarget:strongSelf action:@selector(handleVolumeSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
            float delayedVolume = AVAudioSession.sharedInstance.outputVolume;
            strongSelf->_lastObservedSystemVolume = delayedVolume;
            strongSelf->_hasObservedSystemVolume = YES;
        });
    }
}

- (void)handleVolumeSliderValueChanged:(UISlider *)slider {
    [self handleObservedVolume:slider.value];
}

- (void)handleVolumeShortcutPlay {
    if (![self panelCanUseCurrentScene]) {
        [self refreshCollapsedButtonTitle];
        return;
    }
    if ([AnClickRecorder shared].isRecording) {
        _statusLabel.text = @"录制中无法播放";
        [self showVolumeShortcutToast:@"音量- 录制中无法播放"];
        [self refreshCollapsedButtonTitle];
        return;
    }
    if (_taskRunActive) {
        _statusLabel.text = @"播放中";
        [self refreshCollapsedButtonTitle];
        return;
    }
    if (_taskItems.count == 0) {
        _statusLabel.text = @"先加任务";
        [self showVolumeShortcutToast:@"音量- 先加任务"];
        [self refreshCollapsedButtonTitle];
        return;
    }
    if (![self hostWindow]) {
        _statusLabel.text = @"无窗口";
        [self showVolumeShortcutToast:@"音量- 无窗口"];
        [self refreshCollapsedButtonTitle];
        return;
    }
    NSString *networkValidationMessage = [self globalNetworkGateValidationMessage];
    if (networkValidationMessage.length > 0) {
        _statusLabel.text = networkValidationMessage;
        [self showVolumeShortcutToast:[NSString stringWithFormat:@"音量- %@", networkValidationMessage]];
        [self refreshCollapsedButtonTitle];
        return;
    }
    _volumeShortcutRunSuppressToasts = YES;
    [self showVolumeShortcutToast:@"音量- 播放"];
    [self startTaskListRunScheduled:NO];
}

- (void)handleVolumeShortcutStop {
    if ([AnClickRecorder shared].isRecording) {
        [self showVolumeShortcutToast:@"音量+ 停止录制"];
        [self toggleMacroRecording];
        _statusLabel.text = @"音量停止录制";
        [self refreshCollapsedButtonTitle];
        return;
    }
    if (_taskRunActive || _taskRunPausedForForeground) {
        [self showVolumeShortcutToast:@"音量+ 停止"];
        [self stopTaskRunWithStatus:@"音量停止" showToast:NO];
        _volumeShortcutRunSuppressToasts = NO;
        return;
    }
    _volumeShortcutRunSuppressToasts = NO;
    _statusLabel.text = @"未播放";
    [self showVolumeShortcutToast:@"音量+ 未播放"];
    [self refreshCollapsedButtonTitle];
}

- (void)handleSystemVolumeDidChange:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *reason = [userInfo[@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"] isKindOfClass:NSString.class]
        ? userInfo[@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"]
        : nil;
    if (reason.length > 0 && ![reason isEqualToString:@"ExplicitVolumeChange"]) {
        return;
    }

    NSNumber *volumeNumber = [userInfo[@"AVSystemController_AudioVolumeNotificationParameter"] isKindOfClass:NSNumber.class]
        ? userInfo[@"AVSystemController_AudioVolumeNotificationParameter"]
        : nil;
    if (!volumeNumber) {
        return;
    }

    [self handleObservedVolume:volumeNumber.floatValue explicitPress:YES];
}

- (void)handleWindowPressesEvent:(UIEvent *)event {
    NSInteger direction = AnClickVolumeShortcutDirectionFromPressesEvent(event);
    if (direction == 0) {
        return;
    }

    [self triggerVolumeShortcutDirection:direction];
}

- (void)handleExternalVolumeShortcutDirection:(NSInteger)direction {
    if (direction == 0) {
        return;
    }
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return;
    }

    [self triggerVolumeShortcutDirection:direction];
}

- (void)handleHardwareButtonHIDEvent:(IOHIDEventRef)event {
    NSInteger direction = [self volumeShortcutDirectionForHIDEvent:event];
    if (direction == 0) {
        return;
    }

    [self triggerVolumeShortcutDirection:direction];
}

- (NSInteger)volumeShortcutDirectionForHIDEvent:(IOHIDEventRef)event {
    if (!event) {
        return 0;
    }

    IOHIDEventType type = IOHIDEventGetType(event);
    if (type == AnClickHIDEventTypeKeyboard) {
        NSInteger usagePage = IOHIDEventGetIntegerValue(event, AnClickHIDEventFieldKeyboardUsagePage);
        NSInteger usage = IOHIDEventGetIntegerValue(event, AnClickHIDEventFieldKeyboardUsage);
        NSInteger down = IOHIDEventGetIntegerValue(event, AnClickHIDEventFieldKeyboardDown);
        if (usagePage != AnClickHIDUsagePageConsumer || down == 0) {
            return 0;
        }
        if (usage == AnClickHIDUsageConsumerVolumeDecrement) {
            return -1;
        }
        if (usage == AnClickHIDUsageConsumerVolumeIncrement) {
            return 1;
        }
        return 0;
    }

    CFArrayRef children = IOHIDEventGetChildren(event);
    if (!children) {
        return 0;
    }

    CFIndex childCount = CFArrayGetCount(children);
    for (CFIndex i = 0; i < childCount; i++) {
        IOHIDEventRef childEvent = (IOHIDEventRef)CFArrayGetValueAtIndex(children, i);
        NSInteger direction = [self volumeShortcutDirectionForHIDEvent:childEvent];
        if (direction != 0) {
            return direction;
        }
    }
    return 0;
}

- (void)handleObservedVolume:(float)volume {
    [self handleObservedVolume:volume explicitPress:NO];
}

- (void)handleObservedVolume:(float)volume explicitPress:(BOOL)explicitPress {
    CFTimeInterval now = CACurrentMediaTime();
    if (_ignoreVolumeEventsUntil > now) {
        _lastObservedSystemVolume = volume;
        _hasObservedSystemVolume = YES;
        return;
    }

    if (!_hasObservedSystemVolume) {
        _lastObservedSystemVolume = volume;
        _hasObservedSystemVolume = YES;
        if (!explicitPress || (volume > 0.001f && volume < 0.999f)) {
            return;
        }
    }

    float delta = volume - _lastObservedSystemVolume;
    _lastObservedSystemVolume = volume;
    NSInteger direction = 0;
    if (delta < -0.005f) {
        direction = -1;
    } else if (delta > 0.005f) {
        direction = 1;
    } else if (explicitPress && volume <= 0.001f) {
        direction = -1;
    } else if (explicitPress && volume >= 0.999f) {
        direction = 1;
    }
    if (direction == 0) {
        return;
    }

    [self triggerVolumeShortcutDirection:direction];
}

- (void)triggerVolumeShortcutDirection:(NSInteger)direction {
    if (direction == 0) {
        return;
    }

    CFTimeInterval now = CACurrentMediaTime();
    if (_lastVolumeShortcutTime > 0 && now - _lastVolumeShortcutTime < 0.35) {
        return;
    }
    _lastVolumeShortcutTime = now;
    _ignoreVolumeEventsUntil = now + 0.95;

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (direction < 0) {
            [strongSelf handleVolumeShortcutPlay];
        } else {
            [strongSelf handleVolumeShortcutStop];
        }
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (context == &AnClickVolumeObservationContext) {
        NSNumber *volumeNumber = [change[NSKeyValueChangeNewKey] isKindOfClass:NSNumber.class]
            ? change[NSKeyValueChangeNewKey]
            : nil;
        if (volumeNumber) {
            [self handleObservedVolume:volumeNumber.floatValue];
        }
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (UIWindowScene *)activeWindowScene {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *fallback = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                return windowScene;
            }
            if (!fallback && scene.activationState == UISceneActivationStateForegroundInactive) {
                fallback = windowScene;
            }
        }
        return fallback;
    }
    return nil;
}

- (void)attachPanelWindowToActiveSceneIfNeeded {
    if (@available(iOS 13.0, *)) {
        if (_panelWindow.windowScene) {
            return;
        }
        UIWindowScene *scene = [self activeWindowScene];
        if (scene) {
            _panelWindow.windowScene = scene;
        }
    }
}

- (void)handleScreenGeometryChanged {
    void (^geometryBlock)(void) = ^{
        NSUInteger generation = ++self->_screenGeometryRefreshGeneration;
        [self applyScreenGeometryRefreshAllowHeavyRefresh:NO];

        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.22 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || generation != strongSelf->_screenGeometryRefreshGeneration) {
                return;
            }
            [strongSelf applyScreenGeometryRefreshAllowHeavyRefresh:YES];
        });
    };

    if (NSThread.isMainThread) {
        geometryBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), geometryBlock);
    }
}

- (void)buildPanel {
    CGSize initialPanelSize = [self expandedPanelSizeForEditorVisible:NO];
    CGFloat panelWidth = initialPanelSize.width;
    CGFloat panelHeight = initialPanelSize.height;
    _actionMode = AnClickActionModeNone;
    _selectedTaskIndex = -1;
    _editingTaskIndex = -1;
    _draggingTaskIndex = -1;
    _taskReordering = NO;
    _taskReorderStartLocationY = 0.0;
    _taskReorderStartCenterY = 0.0;
    _imageUsesMatchPoint = YES;
    _ocrUsesMatchPoint = YES;
    _imageActionMode = AnClickActionModeTap;
    _failureActionMode = AnClickActionModeNone;
    _ocrMode = AnClickOCRModeAppleVision;
    _ocrMatchMode = AnClickOCRMatchModeContains;
    _colorTolerance = 18.0;
    _matchThreshold = 0.80;
    _actionDelay = 0;
    _actionRepeatCount = 1;
    _actionInterval = AnClickDefaultTapPressDuration;
    _recognitionSuccessBranchIndex = -1;
    _recognitionFailureBranchIndex = -1;
    _editingBranchOwnerTaskIndex = -1;
    _editingNestedBranchActionMode = AnClickActionModeNone;
    _editingBranchActionMode = AnClickActionModeNone;
    _taskRunSingleStepStopIndex = -1;
    _globalDelayMilliseconds = 0;
    _globalRunRepeatCount = 1;
    _globalLoopIntervalSeconds = 0;
    _globalStartEnabled = NO;
    _globalStopEnabled = NO;
    _globalNetworkGateEnabled = NO;
    _networkRequestOnly = NO;
    _networkUsesPost = NO;
    _networkPostBodyUsesOCRResult = NO;
    _networkRetryForever = YES;
    _networkTimeout = 8.0;
    _recognitionRetryUntilFound = NO;
    _recognitionRetryDropdownVisible = NO;
    _recognitionRetryInterval = 1.0;
    _actionRandomDelayEnabled = NO;
    _actionJitterRadius = 0.0;
    _globalStartHour = 8;
    _globalStartMinute = 0;
    _globalStartSecond = 0;
    _globalStartMillisecond = 0;
    _globalStopHour = 23;
    _globalStopMinute = 0;
    _globalStopSecond = 0;
    _globalStopMillisecond = 0;
    _currentGlobalRunCycle = 0;
    _taskRunActive = NO;
    _taskRunPausedForForeground = NO;
    _taskRunResumeInGlobalNetworkGate = NO;
    _taskRunResumeScheduled = NO;
    _taskRunResumeCycle = 0;
    _taskRunResumeIndex = 0;
    _taskEngine = [[AnClickTaskEngine alloc] init];
    _taskEngine.minInfiniteLoopInterval = AnClickMinInfiniteLoopInterval;
    _taskEngine.minJumpContinuationInterval = AnClickMinJumpContinuationInterval;
    _taskEngine.maxJumpVisitsPerRun = AnClickMaxJumpVisitsPerRun;
    _taskEngine.listRefreshMinInterval = AnClickRunListRefreshMinInterval;
    _taskEngine.delegate = self;
    __weak typeof(self) weakSelf = self;
    _taskEngine.runtimeHandler = ^(__unused NSTimeInterval runtime) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf refreshTaskRunRuntimeLabel];
    };
    _networkService = [[AnClickNetworkService alloc] init];
    _recognitionService = [[AnClickRecognitionService alloc] init];
    _pickerService = [[AnClickPickerService alloc] init];
    _templateImageCache = [[NSCache alloc] init];
    _templateImageCache.countLimit = 12;
    _templateImageModificationDates = [NSMutableDictionary dictionary];
    _volumeShortcutRegistered = NO;
    _hasObservedSystemVolume = NO;
    _volumeShortcutRunSuppressToasts = NO;
    _ignoreVolumeEventsUntil = 0;
    _pendingConfigDeleteIndex = -1;
    [self loadGlobalSettings];
    [self registerVolumeShortcutObserver];
    if (!_recordedSwipePoints) {
        _recordedSwipePoints = [NSMutableArray array];
    }
    if (!_taskItems) {
        _taskItems = [self savedCurrentTaskList];
    }

    _collapsedPanelFrame = [self defaultCollapsedPanelFrame];
    _collapsedPanelOriginRatio = [self originRatioForWindowFrame:_collapsedPanelFrame floating:YES];
    _collapsedPanelScreenSize = [self currentScreenBounds].size;
    _lastAppliedScreenGeometrySize = _collapsedPanelScreenSize;
    _hasCollapsedPanelFrame = YES;
    _hasCollapsedPanelOriginRatio = YES;
    _panelWindow = [[UIWindow alloc] initWithFrame:_collapsedPanelFrame];
    [self attachPanelWindowToActiveSceneIfNeeded];
    _panelWindow.windowLevel = UIWindowLevelAlert + 1000;
    _panelWindow.backgroundColor = UIColor.clearColor;
    _panelWindow.hidden = NO;

    UIViewController *controller = [[UIViewController alloc] init];
    _panelWindow.rootViewController = controller;
    [self registerKeyboardAvoidanceObserversIfNeeded];
    [self installVolumeShortcutControl];

    _collapsedButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _collapsedButton.frame = CGRectMake(0, 0, 48, 48);
    _collapsedButton.backgroundColor = [self floatingButtonIdleColor];
    _collapsedButton.layer.cornerRadius = 24;
    _collapsedButton.layer.borderWidth = 2.0;
    _collapsedButton.layer.borderColor = [self floatingButtonIdleBorderColor].CGColor;
    _collapsedButton.layer.shadowColor = [self floatingButtonIdleShadowColor].CGColor;
    _collapsedButton.layer.shadowOpacity = 0.58;
    _collapsedButton.layer.shadowRadius = 10.0;
    _collapsedButton.layer.shadowOffset = CGSizeZero;
    _collapsedButton.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    [_collapsedButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [_collapsedButton addTarget:self action:@selector(handleCollapsedTap) forControlEvents:UIControlEventTouchUpInside];
    [controller.view addSubview:_collapsedButton];

    _collapsedRuntimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _collapsedRuntimeLabel.text = @"00:00:00";
    _collapsedRuntimeLabel.textColor = UIColor.whiteColor;
    _collapsedRuntimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:10.0 weight:UIFontWeightSemibold];
    _collapsedRuntimeLabel.textAlignment = NSTextAlignmentCenter;
    _collapsedRuntimeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.56];
    _collapsedRuntimeLabel.layer.cornerRadius = 6.0;
    _collapsedRuntimeLabel.layer.masksToBounds = YES;
    [controller.view addSubview:_collapsedRuntimeLabel];
    [self layoutCollapsedControls];

    UILongPressGestureRecognizer *collapsedLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleCollapsedLongPress:)];
    collapsedLongPress.minimumPressDuration = 0.45;
    [_collapsedButton addGestureRecognizer:collapsedLongPress];
    UIPanGestureRecognizer *collapsedPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    collapsedPan.delegate = self;
    [_collapsedButton addGestureRecognizer:collapsedPan];

    _panelView = [[UIView alloc] initWithFrame:_panelWindow.bounds];
    [self installDarkBlurInView:_panelView cornerRadius:16.0];
    _panelView.layer.cornerRadius = 16.0;
    _panelView.layer.borderWidth = 1.2;
    _panelView.layer.borderColor = [[self glassHighlightBorderColor] colorWithAlphaComponent:0.86].CGColor;
    _panelView.layer.shadowColor = [self neumorphicShadowColor].CGColor;
    _panelView.layer.shadowOpacity = 0.22;
    _panelView.layer.shadowRadius = 24.0;
    _panelView.layer.shadowOffset = CGSizeMake(8, 12);
    [controller.view addSubview:_panelView];

    UIPanGestureRecognizer *panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    panelPan.delegate = self;
    [_panelView addGestureRecognizer:panelPan];
    UITapGestureRecognizer *keyboardDismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelTapToDismissKeyboard:)];
    keyboardDismissTap.cancelsTouchesInView = NO;
    [_panelView addGestureRecognizer:keyboardDismissTap];

    CGFloat gap = 12.0;
    CGFloat buttonWidth = floor((panelWidth - gap * 5.0) / 4.0);
    _addTaskButton = [self panelButtonWithTitle:@"＋0" action:@selector(addTaskFromCurrentConfig)];
    _addTaskButton.frame = CGRectMake(gap, 8, buttonWidth, 38);
    [_panelView addSubview:_addTaskButton];

    _deleteTaskButton = [self panelButtonWithTitle:@"删除" action:@selector(deleteSelectedTaskFromHomeButton)];
    _deleteTaskButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 8, buttonWidth, 38);
    [_panelView addSubview:_deleteTaskButton];

    _runTasksButton = [self panelButtonWithTitle:@"播放" action:@selector(runTaskList)];
    _runTasksButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 8, buttonWidth, 38);
    [_panelView addSubview:_runTasksButton];

    _collapseButton = [self panelButtonWithTitle:@"收起" action:@selector(handleMoreOrCloseButton)];
    _collapseButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 8, buttonWidth, 38);
    [_panelView addSubview:_collapseButton];

    _homeCloseButton = [self panelButtonWithTitle:@"×" action:@selector(collapsePanel)];
    _homeCloseButton.frame = CGRectMake(panelWidth - 50, 8, 38, 38);
    [_panelView addSubview:_homeCloseButton];

    _globalSettingsButton = [self panelButtonWithTitle:@"⚙" action:@selector(showHomeMonitorSettings)];
    _globalSettingsButton.frame = CGRectMake(10, 8, 34, 34);
    [_panelView addSubview:_globalSettingsButton];

    _homeTimeButton = [self panelButtonWithTitle:@"定时" action:@selector(showHomeTimeSettings)];
    [_panelView addSubview:_homeTimeButton];
    _homeLoopButton = [self panelButtonWithTitle:@"循环" action:@selector(showHomeLoopSettings)];
    [_panelView addSubview:_homeLoopButton];
    _homeMonitorButton = [self panelButtonWithTitle:@"监控" action:@selector(showHomeMonitorSettings)];
    [_panelView addSubview:_homeMonitorButton];
    _homeSaveConfigButton = [self panelButtonWithTitle:@"保存" action:@selector(showHomeSaveConfigMenu)];
    [_panelView addSubview:_homeSaveConfigButton];
    _networkPostPairs = [NSMutableArray array];

    _homeBrandView = [[UIView alloc] initWithFrame:CGRectZero];
    _homeBrandView.backgroundColor = [[self themeControlFillColor] colorWithAlphaComponent:0.76];
    _homeBrandView.layer.cornerRadius = 9.0;
    _homeBrandView.layer.borderWidth = 1.0;
    _homeBrandView.layer.borderColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.42].CGColor;
    [controller.view addSubview:_homeBrandView];

    UIPanGestureRecognizer *brandPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    brandPan.delegate = self;
    [_homeBrandView addGestureRecognizer:brandPan];

    _toolTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 8, panelWidth - 100, 22)];
    _toolTitleLabel.text = [self toolDisplayName];
    _toolTitleLabel.textColor = [self themePrimaryTextColor];
    _toolTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    _toolTitleLabel.adjustsFontSizeToFitWidth = YES;
    _toolTitleLabel.minimumScaleFactor = 0.45;
    _toolTitleLabel.numberOfLines = 1;
    _toolTitleLabel.lineBreakMode = NSLineBreakByClipping;
    _toolTitleLabel.textAlignment = NSTextAlignmentLeft;
    [_homeBrandView addSubview:_toolTitleLabel];

    _authorFollowButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_authorFollowButton setTitle:@"点击关注UP主" forState:UIControlStateNormal];
    [_authorFollowButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _authorFollowButton.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    _authorFollowButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    _authorFollowButton.titleLabel.minimumScaleFactor = 0.72;
    _authorFollowButton.backgroundColor = [self themeHighlightColor];
    _authorFollowButton.layer.cornerRadius = 8.0;
    _authorFollowButton.layer.shadowColor = [self themeHighlightColor].CGColor;
    _authorFollowButton.layer.shadowOpacity = 0.20;
    _authorFollowButton.layer.shadowRadius = 5.0;
    _authorFollowButton.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    [_authorFollowButton addTarget:self action:@selector(openBilibiliProfile) forControlEvents:UIControlEventTouchUpInside];
    [_homeBrandView addSubview:_authorFollowButton];

    _homeOutputView = [[UIView alloc] initWithFrame:CGRectZero];
    _homeOutputView.backgroundColor = [[self themeControlFillColor] colorWithAlphaComponent:0.76];
    _homeOutputView.layer.cornerRadius = 9.0;
    _homeOutputView.layer.borderWidth = 1.0;
    _homeOutputView.layer.borderColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.42].CGColor;
    _homeOutputView.hidden = YES;
    [controller.view addSubview:_homeOutputView];
    UIPanGestureRecognizer *outputPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [_homeOutputView addGestureRecognizer:outputPan];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusLabel.text = @"";
    _statusLabel.textColor = [self themeSecondaryTextColor];
    _statusLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    _statusLabel.adjustsFontSizeToFitWidth = YES;
    _statusLabel.minimumScaleFactor = 0.6;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [_homeOutputView addSubview:_statusLabel];

    _taskEditorView = [[AnClickTaskEditorView alloc] initWithFrame:_panelView.bounds];
    _taskEditorView.delegate = self;
    _taskEditorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _taskEditorView.hidden = YES;
    [_panelView addSubview:_taskEditorView];

    _taskListView = [[UITableView alloc] initWithFrame:CGRectMake(8, 84, panelWidth - 16, panelHeight - 92) style:UITableViewStylePlain];
    _taskListView.backgroundColor = UIColor.clearColor;
    _taskListView.dataSource = self;
    _taskListView.delegate = self;
    _taskListView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _taskListView.estimatedRowHeight = 60.0;
    _taskListView.rowHeight = UITableViewAutomaticDimension;
    _taskListView.showsVerticalScrollIndicator = YES;
    _taskListView.alwaysBounceVertical = YES;
    _taskListView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _taskListView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 4.0, 0.0);
    _taskListView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    _taskListView.layer.cornerRadius = 10.0;
    _taskListView.clipsToBounds = YES;
    if (@available(iOS 11.0, *)) {
        _taskListView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [_taskListView registerClass:UITableViewCell.class forCellReuseIdentifier:AnClickTaskListCellIdentifier];
    UILongPressGestureRecognizer *taskReorderLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTaskListLongPressReorder:)];
    taskReorderLongPress.minimumPressDuration = 0.28;
    [_taskListView addGestureRecognizer:taskReorderLongPress];
    [_panelView addSubview:_taskListView];
    [self refreshTaskList];
    [self setTaskEditorVisible:NO];
    [self scheduleGlobalTimers];

    _panelWindow.hidden = NO;
    [self collapsePanel];
    NSLog(@"[AnClick] Panel shown");
}

- (void)updateButtonShadowPath:(UIButton *)button {
    if (!button || CGRectIsEmpty(button.bounds)) {
        return;
    }

    CGFloat cornerRadius = button.layer.cornerRadius;
    button.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:button.bounds cornerRadius:cornerRadius].CGPath;
}

- (void)applyObsidian3DStyleToButton:(UIButton *)button selected:(BOOL)selected {
    UIColor *accentColor = [self accentColorForButton:button];
    button.layer.cornerRadius = 8.0;
    button.layer.masksToBounds = NO;
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];

    if (selected) {
        button.backgroundColor = [accentColor colorWithAlphaComponent:0.92];
        button.layer.borderWidth = 1.2;
        button.layer.borderColor = [[self glassHighlightBorderColor] colorWithAlphaComponent:0.82].CGColor;
        button.layer.shadowColor = accentColor.CGColor;
        button.layer.shadowOffset = CGSizeMake(0, 4);
        button.layer.shadowRadius = 10.0;
        button.layer.shadowOpacity = 0.24;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.tintColor = UIColor.whiteColor;
    } else {
        button.backgroundColor = [[self themeControlFillColor] colorWithAlphaComponent:0.82];
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [accentColor colorWithAlphaComponent:0.28].CGColor;
        button.layer.shadowColor = [self neumorphicShadowColor].CGColor;
        button.layer.shadowOffset = CGSizeMake(3, 4);
        button.layer.shadowRadius = 8.0;
        button.layer.shadowOpacity = 0.07;
        [button setTitleColor:[self themePrimaryTextColor] forState:UIControlStateNormal];
        button.tintColor = accentColor;
    }

    [self updateButtonShadowPath:button];
}

- (void)applyBranchRoleStyleToView:(UIView *)view success:(BOOL)success strong:(BOOL)strong {
    if (!view) {
        return;
    }
    UIColor *roleColor = [self branchRoleColorForSuccess:success];
    view.layer.cornerRadius = MAX(view.layer.cornerRadius, 8.0);
    view.layer.masksToBounds = NO;
    view.layer.borderWidth = strong ? 1.8 : 1.3;
    view.layer.borderColor = [roleColor colorWithAlphaComponent:strong ? 0.94 : 0.78].CGColor;
    view.layer.shadowColor = roleColor.CGColor;
    view.layer.shadowOffset = CGSizeMake(0, strong ? 4.0 : 2.0);
    view.layer.shadowRadius = strong ? 9.0 : 6.0;
    view.layer.shadowOpacity = strong ? 0.20 : 0.12;
}

- (void)applyBranchRoleStyleToButton:(UIButton *)button success:(BOOL)success strong:(BOOL)strong {
    [self applyBranchRoleStyleToView:button success:success strong:strong];
    UIColor *roleColor = [self branchRoleColorForSuccess:success];
    button.backgroundColor = [[self branchRoleFillColorForSuccess:success] colorWithAlphaComponent:strong ? 0.18 : 0.14];
    [button setTitleColor:roleColor forState:UIControlStateNormal];
    button.tintColor = roleColor;
    [self updateButtonShadowPath:button];
}

- (void)applyBranchRoleStyleToLabel:(UILabel *)label success:(BOOL)success strong:(BOOL)strong {
    if (!label) {
        return;
    }
    [self applyBranchRoleStyleToView:label success:success strong:strong];
    label.backgroundColor = [self branchRoleFillColorForSuccess:success];
    label.textColor = strong ? [self branchRoleColorForSuccess:success] : [self themePrimaryTextColor];
    label.clipsToBounds = YES;
}

- (void)setStyledPlaceholder:(NSString *)placeholder forField:(UITextField *)field alpha:(CGFloat)alpha {
    if (!field) {
        return;
    }
    field.placeholder = placeholder;
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @""
                                                                  attributes:@{NSForegroundColorAttributeName: [[self themeSecondaryTextColor] colorWithAlphaComponent:MIN(1.0, MAX(0.20, alpha))]}];
}

- (void)applyObsidianInputStyleToField:(UITextField *)field placeholder:(NSString *)placeholder monospaced:(BOOL)monospaced {
    field.textColor = [self themePrimaryTextColor];
    field.tintColor = [self themeHighlightColor];
    field.font = monospaced
        ? [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightSemibold]
        : [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    field.backgroundColor = [[self themeControlFillColor] colorWithAlphaComponent:0.80];
    field.layer.cornerRadius = 8.0;
    field.layer.borderWidth = 1.0;
    field.layer.borderColor = [[self glassHighlightBorderColor] colorWithAlphaComponent:0.76].CGColor;
    field.layer.shadowColor = [self neumorphicShadowColor].CGColor;
    field.layer.shadowOffset = CGSizeMake(2, 3);
    field.layer.shadowRadius = 7.0;
    field.layer.shadowOpacity = 0.06;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    [self setStyledPlaceholder:placeholder forField:field alpha:0.42];
}

- (void)setCenteredIconForButton:(UIButton *)button systemName:(NSString *)systemName fallbackTitle:(NSString *)fallbackTitle fontSize:(CGFloat)fontSize {
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    button.contentEdgeInsets = UIEdgeInsetsZero;
    button.titleEdgeInsets = UIEdgeInsetsZero;
    button.imageEdgeInsets = UIEdgeInsetsZero;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightBold];
    [button setAttributedTitle:nil forState:UIControlStateNormal];
    [button setImage:nil forState:UIControlStateNormal];

    if (@available(iOS 13.0, *)) {
        UIImage *image = [UIImage systemImageNamed:systemName];
        if (image) {
            UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:fontSize weight:UIImageSymbolWeightBold];
            image = [image imageWithConfiguration:configuration];
            [button setTitle:nil forState:UIControlStateNormal];
            [button setImage:image forState:UIControlStateNormal];
            button.tintColor = [self themeHighlightColor];
            button.imageView.contentMode = UIViewContentModeScaleAspectFit;
            return;
        }
    }

    [button setTitle:fallbackTitle forState:UIControlStateNormal];
    [button setTitleColor:[self themeHighlightColor] forState:UIControlStateNormal];
}

- (UIButton *)panelButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[self themePrimaryTextColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.72;
    [self applyObsidian3DStyleToButton:button selected:NO];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UITextField *)configTextFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
    field.placeholder = placeholder;
    [self applyObsidianInputStyleToField:field placeholder:placeholder monospaced:YES];
    [self configureConfigTextField:field];
    return field;
}

- (void)configureConfigTextField:(UITextField *)field {
    field.delegate = self;
    field.returnKeyType = UIReturnKeyDone;
    field.inputAccessoryView = nil;
}

- (void)registerKeyboardAvoidanceObserversIfNeeded {
    if (_keyboardAvoidanceObserversRegistered) {
        return;
    }
    _keyboardAvoidanceObserversRegistered = YES;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(handleKeyboardWillChangeFrame:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleKeyboardWillHide:)
                   name:UIKeyboardWillHideNotification
                 object:nil];
}

- (UIScrollView *)keyboardAvoidanceScrollViewForField:(UITextField *)field {
    if (!field) {
        return nil;
    }
    if (_globalSettingsScrollView && [field isDescendantOfView:_globalSettingsScrollView]) {
        return _globalSettingsScrollView;
    }
    return nil;
}

- (UIEdgeInsets)verticalIndicatorInsetsForScrollView:(UIScrollView *)scrollView {
    if (!scrollView) {
        return UIEdgeInsetsZero;
    }
    if (@available(iOS 13.0, *)) {
        return scrollView.verticalScrollIndicatorInsets;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return scrollView.scrollIndicatorInsets;
#pragma clang diagnostic pop
}

- (void)setVerticalIndicatorInsets:(UIEdgeInsets)insets forScrollView:(UIScrollView *)scrollView {
    if (!scrollView) {
        return;
    }
    if (@available(iOS 13.0, *)) {
        scrollView.verticalScrollIndicatorInsets = insets;
        return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    scrollView.scrollIndicatorInsets = insets;
#pragma clang diagnostic pop
}

- (void)setKeyboardAvoidanceBottomInset:(CGFloat)bottomInset forScrollView:(UIScrollView *)scrollView {
    if (!scrollView) {
        return;
    }
    UIEdgeInsets contentInset = scrollView.contentInset;
    contentInset.bottom = bottomInset;
    scrollView.contentInset = contentInset;

    UIEdgeInsets indicatorInsets = [self verticalIndicatorInsetsForScrollView:scrollView];
    indicatorInsets.bottom = bottomInset;
    [self setVerticalIndicatorInsets:indicatorInsets forScrollView:scrollView];
}

- (void)resetKeyboardAvoidanceInsetsExceptScrollView:(UIScrollView *)activeScrollView {
    NSMutableArray<UIScrollView *> *scrollViews = [NSMutableArray array];
    if (_globalSettingsScrollView) {
        [scrollViews addObject:_globalSettingsScrollView];
    }
    for (UIScrollView *scrollView in scrollViews) {
        if (scrollView != activeScrollView) {
            [self setKeyboardAvoidanceBottomInset:0.0 forScrollView:scrollView];
        }
    }
}

- (void)applyKeyboardAvoidanceAnimated:(BOOL)animated duration:(NSTimeInterval)duration curve:(UIViewAnimationCurve)curve {
    UIScrollView *scrollView = [self keyboardAvoidanceScrollViewForField:_activeConfigTextField];
    [self resetKeyboardAvoidanceInsetsExceptScrollView:scrollView];
    if (!_keyboardVisible || !scrollView || !_panelWindow || CGRectIsEmpty(_keyboardFrameInScreen)) {
        [self setKeyboardAvoidanceBottomInset:0.0 forScrollView:scrollView];
        return;
    }

    CGRect keyboardFrame = [_panelWindow convertRect:_keyboardFrameInScreen fromWindow:nil];
    CGRect scrollFrame = [scrollView.superview convertRect:scrollView.frame toView:_panelWindow];
    CGFloat overlap = CGRectGetMaxY(scrollFrame) - CGRectGetMinY(keyboardFrame);
    CGFloat bottomInset = MAX(0.0, overlap + 14.0);
    void (^updates)(void) = ^{
        [self setKeyboardAvoidanceBottomInset:bottomInset forScrollView:scrollView];
        if (self->_activeConfigTextField &&
            [self->_activeConfigTextField isDescendantOfView:scrollView] &&
            !self->_activeConfigTextField.hidden) {
            CGRect fieldRect = [self->_activeConfigTextField.superview convertRect:self->_activeConfigTextField.frame toView:scrollView];
            CGFloat topPadding = 12.0;
            CGFloat bottomPadding = 18.0;
            CGFloat visibleMinY = scrollView.contentOffset.y;
            CGFloat visibleMaxY = visibleMinY + scrollView.bounds.size.height - bottomInset;
            CGFloat targetOffsetY = scrollView.contentOffset.y;
            if (CGRectGetMaxY(fieldRect) + bottomPadding > visibleMaxY) {
                targetOffsetY += CGRectGetMaxY(fieldRect) + bottomPadding - visibleMaxY;
            }
            if (CGRectGetMinY(fieldRect) - topPadding < targetOffsetY) {
                targetOffsetY = CGRectGetMinY(fieldRect) - topPadding;
            }
            CGFloat maxOffsetY = MAX(-scrollView.contentInset.top,
                                     scrollView.contentSize.height + scrollView.contentInset.bottom - scrollView.bounds.size.height);
            CGFloat minOffsetY = -scrollView.contentInset.top;
            targetOffsetY = MIN(MAX(targetOffsetY, minOffsetY), MAX(minOffsetY, maxOffsetY));
            scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, targetOffsetY);
        }
    };

    if (animated) {
        UIViewAnimationOptions options = ((NSUInteger)curve << 16) | UIViewAnimationOptionBeginFromCurrentState;
        [UIView animateWithDuration:MAX(0.05, duration) delay:0 options:options animations:updates completion:nil];
    } else {
        updates();
    }
}

- (void)applyKeyboardAvoidanceAnimated:(BOOL)animated {
    [self applyKeyboardAvoidanceAnimated:animated duration:0.20 curve:UIViewAnimationCurveEaseInOut];
}

- (void)handleKeyboardWillChangeFrame:(NSNotification *)notification {
    NSValue *frameValue = notification.userInfo[UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardFrame = frameValue ? frameValue.CGRectValue : CGRectZero;
    CGRect screenBounds = [self currentScreenBounds];
    _keyboardFrameInScreen = keyboardFrame;
    _keyboardVisible = !CGRectIsEmpty(keyboardFrame) &&
        CGRectIntersectsRect(screenBounds, keyboardFrame) &&
        CGRectGetMinY(keyboardFrame) < CGRectGetMaxY(screenBounds);

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = (UIViewAnimationCurve)[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [self applyKeyboardAvoidanceAnimated:YES duration:duration curve:curve];
}

- (void)handleKeyboardWillHide:(NSNotification *)notification {
    _keyboardVisible = NO;
    _keyboardFrameInScreen = CGRectZero;
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = (UIViewAnimationCurve)[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [self applyKeyboardAvoidanceAnimated:YES duration:duration curve:curve];
}

- (UILabel *)configCaptionLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.textColor = [[self themeSecondaryTextColor] colorWithAlphaComponent:0.90];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.7;
    return label;
}

- (UIWindowScene *)toastWindowScene {
    if (@available(iOS 13.0, *)) {
        if (_panelWindow.windowScene) {
            return _panelWindow.windowScene;
        }
        UIWindow *hostWindow = [self hostWindow];
        if (hostWindow.windowScene) {
            return hostWindow.windowScene;
        }
        return [self activeWindowScene];
    }
    return nil;
}

- (CGRect)currentScreenBounds {
    CGRect bounds = CGRectZero;
    if (@available(iOS 13.0, *)) {
        UIWindow *hostWindow = [self hostWindow];
        UIWindowScene *scene = hostWindow.windowScene ? hostWindow.windowScene : _panelWindow.windowScene;
        if (!scene) {
            scene = [self activeWindowScene];
        }
        if (scene) {
            bounds = scene.coordinateSpace.bounds;
        }
        if (CGRectIsEmpty(bounds) && !CGRectIsEmpty(hostWindow.bounds)) {
            bounds = hostWindow.bounds;
        }
    }
    if (CGRectIsEmpty(bounds)) {
        bounds = UIScreen.mainScreen.bounds;
    }
    bounds.origin = CGPointZero;
    return CGRectStandardize(bounds);
}

- (CGRect)screenBoundsForWindow:(UIWindow *)window {
    CGRect bounds = CGRectZero;
    if (window && !CGRectIsEmpty(window.bounds)) {
        bounds = window.bounds;
    }
    if (CGRectIsEmpty(bounds)) {
        bounds = [self currentScreenBounds];
    }
    bounds.origin = CGPointZero;
    return CGRectStandardize(bounds);
}

- (BOOL)screenGeometrySize:(CGSize)lhs isCloseToSize:(CGSize)rhs {
    return fabs(lhs.width - rhs.width) < 0.5 && fabs(lhs.height - rhs.height) < 0.5;
}

- (BOOL)screenCoordinateSizeIsValid:(CGSize)size {
    return isfinite(size.width) && isfinite(size.height) && size.width > 1.0 && size.height > 1.0;
}

- (CGSize)currentScreenCoordinateSize {
    CGSize size = [self currentScreenBounds].size;
    if (![self screenCoordinateSizeIsValid:size]) {
        size = UIScreen.mainScreen.bounds.size;
    }
    return size;
}

- (NSValue *)currentScreenCoordinateSizeValue {
    return [NSValue valueWithCGSize:[self currentScreenCoordinateSize]];
}

- (CGSize)screenCoordinateSizeFromObject:(id)object {
    if ([object isKindOfClass:NSValue.class]) {
        CGSize size = [(NSValue *)object CGSizeValue];
        if ([self screenCoordinateSizeIsValid:size]) {
            return size;
        }
    }
    return CGSizeZero;
}

- (CGPoint)point:(CGPoint)point mappedFromScreenSize:(CGSize)sourceSize toScreenSize:(CGSize)targetSize {
    if (![self screenCoordinateSizeIsValid:sourceSize] ||
        ![self screenCoordinateSizeIsValid:targetSize] ||
        [self screenGeometrySize:sourceSize isCloseToSize:targetSize]) {
        return point;
    }

    point.x = point.x / sourceSize.width * targetSize.width;
    point.y = point.y / sourceSize.height * targetSize.height;
    point.x = MIN(MAX(point.x, 0.0), targetSize.width);
    point.y = MIN(MAX(point.y, 0.0), targetSize.height);
    return point;
}

- (NSArray<NSValue *> *)path:(NSArray<NSValue *> *)path mappedFromScreenSize:(CGSize)sourceSize toScreenSize:(CGSize)targetSize {
    if (![path isKindOfClass:NSArray.class] || path.count == 0) {
        return @[];
    }
    if (![self screenCoordinateSizeIsValid:sourceSize] ||
        ![self screenCoordinateSizeIsValid:targetSize] ||
        [self screenGeometrySize:sourceSize isCloseToSize:targetSize]) {
        return path;
    }

    NSMutableArray<NSValue *> *mappedPath = [NSMutableArray arrayWithCapacity:path.count];
    for (NSValue *value in path) {
        if (![value isKindOfClass:NSValue.class]) {
            continue;
        }
        CGPoint point = [self point:value.CGPointValue mappedFromScreenSize:sourceSize toScreenSize:targetSize];
        [mappedPath addObject:[NSValue valueWithCGPoint:point]];
    }
    return mappedPath;
}

- (NSArray<NSDictionary *> *)events:(NSArray<NSDictionary *> *)events mappedFromScreenSize:(CGSize)sourceSize toScreenSize:(CGSize)targetSize {
    if (![events isKindOfClass:NSArray.class] || events.count == 0) {
        return @[];
    }
    if (![self screenCoordinateSizeIsValid:sourceSize] ||
        ![self screenCoordinateSizeIsValid:targetSize] ||
        [self screenGeometrySize:sourceSize isCloseToSize:targetSize]) {
        return events;
    }

    NSMutableArray<NSDictionary *> *mappedEvents = [NSMutableArray arrayWithCapacity:events.count];
    for (NSDictionary *event in events) {
        if (![event isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSMutableDictionary *mappedEvent = [event mutableCopy];
        NSNumber *xNumber = event[@"x"];
        NSNumber *yNumber = event[@"y"];
        if ([xNumber respondsToSelector:@selector(doubleValue)] && [yNumber respondsToSelector:@selector(doubleValue)]) {
            CGPoint point = CGPointMake(xNumber.doubleValue, yNumber.doubleValue);
            point = [self point:point mappedFromScreenSize:sourceSize toScreenSize:targetSize];
            mappedEvent[@"x"] = @(point.x);
            mappedEvent[@"y"] = @(point.y);
        }
        [mappedEvents addObject:mappedEvent];
    }
    return mappedEvents;
}

- (NSArray<NSDictionary *> *)colorSamples:(NSArray<NSDictionary *> *)samples mappedFromScreenSize:(CGSize)sourceSize toScreenSize:(CGSize)targetSize {
    NSArray<NSDictionary *> *normalizedSamples = [self mutableColorSamplesArrayFromObject:samples];
    if (normalizedSamples.count == 0) {
        return @[];
    }
    if (![self screenCoordinateSizeIsValid:sourceSize] ||
        ![self screenCoordinateSizeIsValid:targetSize] ||
        [self screenGeometrySize:sourceSize isCloseToSize:targetSize]) {
        return normalizedSamples;
    }

    CGFloat xScale = targetSize.width / sourceSize.width;
    CGFloat yScale = targetSize.height / sourceSize.height;
    NSMutableArray<NSDictionary *> *mappedSamples = [NSMutableArray arrayWithCapacity:normalizedSamples.count];
    for (NSDictionary *sample in normalizedSamples) {
        NSMutableDictionary *mappedSample = [sample mutableCopy];
        if ([sample[@"x"] respondsToSelector:@selector(doubleValue)] &&
            [sample[@"y"] respondsToSelector:@selector(doubleValue)]) {
            CGPoint point = CGPointMake([sample[@"x"] doubleValue], [sample[@"y"] doubleValue]);
            point = [self point:point mappedFromScreenSize:sourceSize toScreenSize:targetSize];
            mappedSample[@"x"] = @(point.x);
            mappedSample[@"y"] = @(point.y);
        }
        if ([sample[@"dx"] respondsToSelector:@selector(doubleValue)] &&
            [sample[@"dy"] respondsToSelector:@selector(doubleValue)]) {
            mappedSample[@"dx"] = @([sample[@"dx"] doubleValue] * xScale);
            mappedSample[@"dy"] = @([sample[@"dy"] doubleValue] * yScale);
        }
        [mappedSamples addObject:mappedSample];
    }
    return mappedSamples;
}

- (CGSize)inferredRotatedSourceSizeForPoint:(CGPoint)point targetSize:(CGSize)targetSize {
    if (![self screenCoordinateSizeIsValid:targetSize]) {
        return CGSizeZero;
    }
    CGSize rotatedSize = CGSizeMake(targetSize.height, targetSize.width);
    BOOL outsideCurrent = point.x > targetSize.width + 1.0 || point.y > targetSize.height + 1.0;
    BOOL fitsRotated = point.x >= -1.0 && point.y >= -1.0 && point.x <= rotatedSize.width + 1.0 && point.y <= rotatedSize.height + 1.0;
    return outsideCurrent && fitsRotated ? rotatedSize : CGSizeZero;
}

- (CGSize)inferredRotatedSourceSizeForPath:(NSArray<NSValue *> *)path targetSize:(CGSize)targetSize {
    if (![path isKindOfClass:NSArray.class] || path.count == 0) {
        return CGSizeZero;
    }
    BOOL outsideCurrent = NO;
    CGSize rotatedSize = CGSizeMake(targetSize.height, targetSize.width);
    for (NSValue *value in path) {
        if (![value isKindOfClass:NSValue.class]) {
            continue;
        }
        CGPoint point = value.CGPointValue;
        if (point.x > targetSize.width + 1.0 || point.y > targetSize.height + 1.0) {
            outsideCurrent = YES;
        }
        if (point.x < -1.0 || point.y < -1.0 || point.x > rotatedSize.width + 1.0 || point.y > rotatedSize.height + 1.0) {
            return CGSizeZero;
        }
    }
    return outsideCurrent ? rotatedSize : CGSizeZero;
}

- (CGSize)inferredRotatedSourceSizeForEvents:(NSArray<NSDictionary *> *)events targetSize:(CGSize)targetSize {
    if (![events isKindOfClass:NSArray.class] || events.count == 0) {
        return CGSizeZero;
    }
    BOOL outsideCurrent = NO;
    CGSize rotatedSize = CGSizeMake(targetSize.height, targetSize.width);
    for (NSDictionary *event in events) {
        if (![event isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSNumber *xNumber = event[@"x"];
        NSNumber *yNumber = event[@"y"];
        if (![xNumber respondsToSelector:@selector(doubleValue)] || ![yNumber respondsToSelector:@selector(doubleValue)]) {
            continue;
        }
        CGPoint point = CGPointMake(xNumber.doubleValue, yNumber.doubleValue);
        if (point.x > targetSize.width + 1.0 || point.y > targetSize.height + 1.0) {
            outsideCurrent = YES;
        }
        if (point.x < -1.0 || point.y < -1.0 || point.x > rotatedSize.width + 1.0 || point.y > rotatedSize.height + 1.0) {
            return CGSizeZero;
        }
    }
    return outsideCurrent ? rotatedSize : CGSizeZero;
}

- (CGPoint)resolvedPointForTask:(NSDictionary *)task fallbackPoint:(CGPoint)point {
    CGSize sourceSize = [self screenCoordinateSizeFromObject:task[@"pointScreenSize"]];
    CGSize targetSize = [self currentScreenCoordinateSize];
    if (![self screenCoordinateSizeIsValid:sourceSize]) {
        sourceSize = [self inferredRotatedSourceSizeForPoint:point targetSize:targetSize];
    }
    return [self point:point mappedFromScreenSize:sourceSize toScreenSize:targetSize];
}

- (NSArray<NSValue *> *)resolvedPathForTask:(NSDictionary *)task {
    NSArray<NSValue *> *path = [task[@"path"] isKindOfClass:NSArray.class] ? task[@"path"] : @[];
    CGSize sourceSize = [self screenCoordinateSizeFromObject:task[@"pathScreenSize"]];
    CGSize targetSize = [self currentScreenCoordinateSize];
    if (![self screenCoordinateSizeIsValid:sourceSize]) {
        sourceSize = [self inferredRotatedSourceSizeForPath:path targetSize:targetSize];
    }
    return [self path:path mappedFromScreenSize:sourceSize toScreenSize:targetSize];
}

- (NSArray<NSValue *> *)pointValuesArrayFromObject:(id)object maxCount:(NSUInteger)maxCount {
    if (![object isKindOfClass:NSArray.class]) {
        return @[];
    }
    NSMutableArray<NSValue *> *points = [NSMutableArray array];
    for (id item in (NSArray *)object) {
        if (![item isKindOfClass:NSValue.class]) {
            continue;
        }
        [points addObject:item];
        if (points.count >= maxCount) {
            break;
        }
    }
    return points;
}

- (NSArray<NSValue *> *)storedMultiTapPointsForTask:(NSDictionary *)task {
    NSArray<NSValue *> *points = [self pointValuesArrayFromObject:task[@"multiPoints"] maxCount:AnClickMultiTapMaxPoints];
    if (points.count > 0) {
        return points;
    }
    NSValue *pointValue = task[@"point"];
    if ([pointValue isKindOfClass:NSValue.class]) {
        return @[pointValue];
    }
    return @[];
}

- (NSArray<NSValue *> *)resolvedMultiTapPointsForTask:(NSDictionary *)task {
    NSArray<NSValue *> *points = [self storedMultiTapPointsForTask:task];
    if (points.count == 0) {
        return @[];
    }
    BOOL hasMultiPoints = [task[@"multiPoints"] isKindOfClass:NSArray.class];
    CGSize sourceSize = [self screenCoordinateSizeFromObject:task[hasMultiPoints ? @"multiPointScreenSize" : @"pointScreenSize"]];
    CGSize targetSize = [self currentScreenCoordinateSize];
    if (![self screenCoordinateSizeIsValid:sourceSize]) {
        sourceSize = [self inferredRotatedSourceSizeForPath:points targetSize:targetSize];
    }
    return [self path:points mappedFromScreenSize:sourceSize toScreenSize:targetSize];
}

- (NSArray<NSDictionary *> *)resolvedRecordedEvents:(NSArray<NSDictionary *> *)events fromScreenSize:(CGSize)sourceSize {
    CGSize targetSize = [self currentScreenCoordinateSize];
    if (![self screenCoordinateSizeIsValid:sourceSize]) {
        sourceSize = [self inferredRotatedSourceSizeForEvents:events targetSize:targetSize];
    }
    return [self events:events mappedFromScreenSize:sourceSize toScreenSize:targetSize];
}

- (NSArray<NSDictionary *> *)resolvedRecordedEventsForTask:(NSDictionary *)task {
    NSArray<NSDictionary *> *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
    CGSize sourceSize = [self screenCoordinateSizeFromObject:task[@"eventsScreenSize"]];
    return [self resolvedRecordedEvents:events fromScreenSize:sourceSize];
}

- (void)rememberManualCoordinateScreenSize {
    _manualCoordinateScreenSize = [self currentScreenCoordinateSize];
    _hasManualCoordinateScreenSize = YES;
}

- (void)remapEditorCoordinatesFromScreenSize:(CGSize)sourceSize toScreenSize:(CGSize)targetSize {
    if (![self screenCoordinateSizeIsValid:sourceSize] ||
        ![self screenCoordinateSizeIsValid:targetSize] ||
        [self screenGeometrySize:sourceSize isCloseToSize:targetSize]) {
        return;
    }

    for (NSUInteger i = 0; i < (NSUInteger)AnClickActionModeCount; i++) {
        if (_hasManualActionPoint[i]) {
            _manualActionPoints[i] = [self point:_manualActionPoints[i] mappedFromScreenSize:sourceSize toScreenSize:targetSize];
        }
    }
    if (_hasManualSwipeAnchor) {
        _manualSwipeAnchor = [self point:_manualSwipeAnchor mappedFromScreenSize:sourceSize toScreenSize:targetSize];
    }
    if (_hasManualSwipeEndPoint) {
        _manualSwipeEndPoint = [self point:_manualSwipeEndPoint mappedFromScreenSize:sourceSize toScreenSize:targetSize];
    }
    if (_hasSuccessActionPoint) {
        _successActionPoint = [self point:_successActionPoint mappedFromScreenSize:sourceSize toScreenSize:targetSize];
    }
    if (_hasFailureActionPoint) {
        _failureActionPoint = [self point:_failureActionPoint mappedFromScreenSize:sourceSize toScreenSize:targetSize];
    }
    if (_recordedSwipePoints.count > 0) {
        _recordedSwipePoints = [[self path:_recordedSwipePoints mappedFromScreenSize:sourceSize toScreenSize:targetSize] mutableCopy];
    }
    if (_multiTapPoints.count > 0) {
        _multiTapPoints = [[self path:_multiTapPoints mappedFromScreenSize:sourceSize toScreenSize:targetSize] mutableCopy];
    }
    if (_targetColorSamples.count > 0) {
        _targetColorSamples = [[self colorSamples:_targetColorSamples mappedFromScreenSize:sourceSize toScreenSize:targetSize] mutableCopy];
    }
    if (_recordedMacroEvents.count > 0 && _hasRecordedMacroScreenSize) {
        _recordedMacroEvents = [self events:_recordedMacroEvents mappedFromScreenSize:_recordedMacroScreenSize toScreenSize:targetSize];
        _recordedMacroScreenSize = targetSize;
    }
    if (_hasManualActionPoint[(NSUInteger)AnClickActionModeImage] ||
        _hasManualActionPoint[(NSUInteger)AnClickActionModeOCR] ||
        _hasManualSwipeAnchor ||
        _hasSuccessActionPoint ||
        _hasFailureActionPoint ||
        _multiTapPoints.count > 0 ||
        _recordedSwipePoints.count > 0 ||
        _targetColorSamples.count > 0) {
        _manualCoordinateScreenSize = targetSize;
        _hasManualCoordinateScreenSize = YES;
    }
}

- (void)applyScreenGeometryRefreshAllowHeavyRefresh:(BOOL)allowHeavyRefresh {
    CGSize screenSize = [self currentScreenBounds].size;
    if (!allowHeavyRefresh &&
        [self screenGeometrySize:screenSize isCloseToSize:_lastAppliedScreenGeometrySize]) {
        return;
    }
    CGSize previousScreenSize = _lastAppliedScreenGeometrySize;
    BOOL geometryChanged = [self screenCoordinateSizeIsValid:previousScreenSize] &&
        ![self screenGeometrySize:screenSize isCloseToSize:previousScreenSize];
    if (geometryChanged) {
        _screenGeometryGeneration++;
    }
    if (geometryChanged && (_captureOverlay || _pointPickWindow || _colorPickWindow || _liveSwipePoints)) {
        [self cleanupScreenInteractionStateRestoringPanel:YES];
        _statusLabel.text = @"屏幕已变化 请重新取点";
        [self showToast:_statusLabel.text];
    }
    if (geometryChanged) {
        CGSize manualSourceSize = _hasManualCoordinateScreenSize ? _manualCoordinateScreenSize : previousScreenSize;
        [self remapEditorCoordinatesFromScreenSize:manualSourceSize toScreenSize:screenSize];
    }
    _lastAppliedScreenGeometrySize = screenSize;

    [self attachPanelWindowToActiveSceneIfNeeded];
    if (allowHeavyRefresh) {
        [self installVolumeShortcutControl];
    }

    [UIView performWithoutAnimation:^{
        if (self->_toastWindow) {
            [self ensureToastWindow];
        }
        [self reclampPanelWindowForCurrentScreenAllowHeavyRefresh:allowHeavyRefresh];
        [self relayoutScreenInteractionOverlays];

        NSString *toastText = self->_toastLabel.text;
        [self layoutToastWithMessage:toastText.length > 0 ? toastText : @""];
        UIWindow *hostWindow = [self hostWindow];
        if (hostWindow) {
            NSString *hostToastText = self->_hostToastLabel.text;
            [self layoutHostToastWithMessage:hostToastText.length > 0 ? hostToastText : @"" inWindow:hostWindow];
        }
        [self->_panelView layoutIfNeeded];
        [self->_panelWindow.rootViewController.view layoutIfNeeded];
    }];
}

- (void)ensureToastWindow {
    CGRect bounds = [self currentScreenBounds];
    if (!_toastWindow) {
        _toastWindow = [[UIWindow alloc] initWithFrame:bounds];
        if (@available(iOS 13.0, *)) {
            _toastWindow.windowScene = [self toastWindowScene];
        }
        _toastWindow.windowLevel = UIWindowLevelAlert + 3000;
        _toastWindow.backgroundColor = UIColor.clearColor;
        _toastWindow.userInteractionEnabled = NO;
        _toastWindow.rootViewController = [[UIViewController alloc] init];
        _toastWindow.rootViewController.view.userInteractionEnabled = NO;
        _toastWindow.rootViewController.view.backgroundColor = UIColor.clearColor;

        _toastView = [[UIView alloc] initWithFrame:CGRectZero];
        _toastView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.82];
        _toastView.layer.cornerRadius = 10.0;
        _toastView.layer.borderWidth = 1.0;
        _toastView.layer.borderColor = [[self themeHighlightColor] colorWithAlphaComponent:0.35].CGColor;
        _toastView.layer.shadowColor = UIColor.blackColor.CGColor;
        _toastView.layer.shadowOpacity = 0.45;
        _toastView.layer.shadowRadius = 12.0;
        _toastView.layer.shadowOffset = CGSizeMake(0, 6);
        _toastView.alpha = 0.0;
        [_toastWindow.rootViewController.view addSubview:_toastView];

        _toastLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _toastLabel.textColor = UIColor.whiteColor;
        _toastLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        _toastLabel.textAlignment = NSTextAlignmentCenter;
        _toastLabel.numberOfLines = 2;
        _toastLabel.adjustsFontSizeToFitWidth = YES;
        _toastLabel.minimumScaleFactor = 0.72;
        [_toastView addSubview:_toastLabel];
    }

    _toastWindow.frame = bounds;
    _toastWindow.rootViewController.view.frame = bounds;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self toastWindowScene];
        if (scene && _toastWindow.windowScene != scene) {
            _toastWindow.hidden = YES;
            _toastWindow.windowScene = scene;
        }
    }
}

- (void)layoutToastWithMessage:(NSString *)message {
    if (!_toastWindow || !_toastView || !_toastLabel) {
        return;
    }

    CGRect bounds = _toastWindow.bounds;
    CGFloat horizontalMargin = 18.0;
    CGFloat maxWidth = MIN(bounds.size.width - horizontalMargin * 2.0, 340.0);
    CGSize fittingSize = [message boundingRectWithSize:CGSizeMake(maxWidth - 28.0, 44.0)
                                               options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                            attributes:@{NSFontAttributeName: _toastLabel.font}
                                               context:nil].size;
    CGFloat width = MIN(maxWidth, MAX(138.0, ceil(fittingSize.width) + 30.0));
    CGFloat height = MAX(42.0, ceil(fittingSize.height) + 18.0);
    CGFloat safeBottom = 0.0;
    if (@available(iOS 11.0, *)) {
        safeBottom = _toastWindow.safeAreaInsets.bottom;
    }
    CGFloat y = bounds.size.height - safeBottom - height - 78.0;
    if (y < 40.0) {
        y = MAX(20.0, bounds.size.height - height - 24.0);
    }
    _toastView.frame = CGRectMake((bounds.size.width - width) * 0.5, y, width, height);
    _toastLabel.frame = CGRectInset(_toastView.bounds, 14.0, 7.0);
    _toastView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_toastView.bounds cornerRadius:_toastView.layer.cornerRadius].CGPath;
}

- (void)applyToastStyleToView:(UIView *)view label:(UILabel *)label {
    view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.84];
    view.userInteractionEnabled = NO;
    view.layer.cornerRadius = 10.0;
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [[self themeHighlightColor] colorWithAlphaComponent:0.42].CGColor;
    view.layer.shadowColor = UIColor.blackColor.CGColor;
    view.layer.shadowOpacity = 0.45;
    view.layer.shadowRadius = 12.0;
    view.layer.shadowOffset = CGSizeMake(0, 6);

    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.72;
    label.userInteractionEnabled = NO;
}

- (void)ensureHostToastInWindow:(UIWindow *)hostWindow {
    if (!hostWindow) {
        return;
    }

    if (!_hostToastView) {
        _hostToastView = [[UIView alloc] initWithFrame:CGRectZero];
        _hostToastView.alpha = 0.0;
        _hostToastLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [self applyToastStyleToView:_hostToastView label:_hostToastLabel];
        [_hostToastView addSubview:_hostToastLabel];
    }

    if (_hostToastView.superview != hostWindow) {
        [_hostToastView removeFromSuperview];
        [hostWindow addSubview:_hostToastView];
    }
    [hostWindow bringSubviewToFront:_hostToastView];
}

- (void)layoutHostToastWithMessage:(NSString *)message inWindow:(UIWindow *)hostWindow {
    if (!_hostToastView || !_hostToastLabel || !hostWindow) {
        return;
    }

    CGRect bounds = hostWindow.bounds;
    CGFloat horizontalMargin = 18.0;
    CGFloat maxWidth = MIN(bounds.size.width - horizontalMargin * 2.0, 340.0);
    CGSize fittingSize = [message boundingRectWithSize:CGSizeMake(maxWidth - 28.0, 44.0)
                                               options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                            attributes:@{NSFontAttributeName: _hostToastLabel.font}
                                               context:nil].size;
    CGFloat width = MIN(maxWidth, MAX(138.0, ceil(fittingSize.width) + 30.0));
    CGFloat height = MAX(42.0, ceil(fittingSize.height) + 18.0);
    CGFloat safeBottom = 0.0;
    if (@available(iOS 11.0, *)) {
        safeBottom = hostWindow.safeAreaInsets.bottom;
    }
    CGFloat y = bounds.size.height - safeBottom - height - 78.0;
    if (y < 40.0) {
        y = MAX(20.0, bounds.size.height - height - 24.0);
    }
    _hostToastView.frame = CGRectMake((bounds.size.width - width) * 0.5, y, width, height);
    _hostToastLabel.frame = CGRectInset(_hostToastView.bounds, 14.0, 7.0);
    _hostToastView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_hostToastView.bounds cornerRadius:_hostToastView.layer.cornerRadius].CGPath;
}

- (void)showToast:(NSString *)message {
    NSString *text = [self trimmedActionDescription:message];
    if (text.length == 0) {
        return;
    }

    BOOL volumeShortcutToast = [text hasPrefix:@"音量"];
    if (!volumeShortcutToast && _volumeShortcutRunSuppressToasts) {
        return;
    }
    CFTimeInterval now = CACurrentMediaTime();
    NSTimeInterval delay = (!volumeShortcutToast && _toastDeferNonVolumeUntil > now)
        ? (_toastDeferNonVolumeUntil - now)
        : 0.0;
    void (^presentToast)(void) = ^{
        if (!volumeShortcutToast && self->_volumeShortcutRunSuppressToasts) {
            return;
        }
        if (!volumeShortcutToast) {
            CFTimeInterval currentTime = CACurrentMediaTime();
            if (self->_toastDeferNonVolumeUntil > currentTime) {
                NSTimeInterval nextDelay = self->_toastDeferNonVolumeUntil - currentTime;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(nextDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self showToast:text];
                });
                return;
            }
        }
        [self ensureToastWindow];
        UIWindow *hostWindow = [self hostWindow];
        if (hostWindow) {
            [self ensureHostToastInWindow:hostWindow];
            self->_hostToastView.hidden = NO;
            self->_hostToastLabel.text = text;
            [self layoutHostToastWithMessage:text inWindow:hostWindow];
        }
        if (self->_toastWindow) {
            self->_toastView.hidden = NO;
            self->_toastLabel.text = text;
            [self layoutToastWithMessage:text];
            self->_toastWindow.hidden = NO;
        }
        NSUInteger generation = ++self->_toastGeneration;
        [self->_toastView.layer removeAllAnimations];
        [self->_hostToastView.layer removeAllAnimations];
        self->_toastView.alpha = 1.0;
        self->_hostToastView.alpha = hostWindow ? 1.0 : 0.0;
        self->_toastView.transform = CGAffineTransformMakeScale(0.98, 0.98);
        self->_hostToastView.transform = CGAffineTransformMakeScale(0.98, 0.98);
        [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^{
            self->_toastView.transform = CGAffineTransformIdentity;
            self->_hostToastView.transform = CGAffineTransformIdentity;
        } completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self->_toastGeneration) {
                return;
            }
            [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn animations:^{
                self->_toastView.alpha = 0.0;
                self->_hostToastView.alpha = 0.0;
            } completion:^(BOOL finished) {
                if (finished && generation == self->_toastGeneration) {
                    self->_toastWindow.hidden = YES;
                }
            }];
        });
    };

    if (delay > 0.01) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), presentToast);
    } else {
        dispatch_async(dispatch_get_main_queue(), presentToast);
    }
}

- (void)hideToastForRecognitionCapture {
    _toastGeneration++;
    _toastDeferNonVolumeUntil = MAX(_toastDeferNonVolumeUntil, CACurrentMediaTime() + 0.16);
    [_toastView.layer removeAllAnimations];
    [_hostToastView.layer removeAllAnimations];
    _toastView.alpha = 0.0;
    _hostToastView.alpha = 0.0;
    _toastView.hidden = YES;
    _hostToastView.hidden = YES;
    _toastWindow.hidden = YES;
}

- (void)clearRecognitionBox {
    [_recognitionBoxView.layer removeAllAnimations];
    [_recognitionBoxView removeFromSuperview];
    _recognitionBoxView = nil;
}

- (void)cancelActiveNetworkTasks {
    [_networkService cancelActiveTasks];
}

- (void)cancelRunningTaskSideEffects {
    [_taskEngine invalidateScheduledCallbacks];
    [AnClickFakeTouch cancelAll];
    [self cancelActiveNetworkTasks];
    [_recognitionService cancelPendingRequests];
    [self invalidatePendingPanelRestore];
    [self clearRecognitionBox];

    [_tapMarkerView.layer removeAllAnimations];
    [_tapMarkerView removeFromSuperview];
    _tapMarkerView = nil;
    [_operationTraceView.layer removeAllAnimations];
    [_operationTraceView removeFromSuperview];
    _operationTraceView = nil;
    [_trajectoryView.layer removeAllAnimations];
    [_trajectoryView removeFromSuperview];
    _trajectoryView = nil;
    _trajectoryLayer = nil;
    _liveSwipePoints = nil;
    _longPressHolding = NO;
    _templateSearchInProgress = NO;
}

- (BOOL)hideOwnUIForRecognitionCaptureWithHostWindow:(UIWindow *)hostWindow {
    BOOL shouldRestorePanel = _panelWindow && (!_panelWindow.hidden || _taskRunActive || _taskRunPausedForForeground);
    [self clearRecognitionBox];
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    [self hideToastForRecognitionCapture];
    return shouldRestorePanel;
}

- (void)keepRunningCollapsedPanelVisible {
    if (!_panelWindow || !_collapsedButton || !_panelView) {
        return;
    }

    [self invalidatePendingPanelRestore];
    [self attachPanelWindowToActiveSceneIfNeeded];
    _panelWindow.windowLevel = UIWindowLevelAlert + 1000;
    _panelWindow.alpha = 1.0;
    _panelWindow.userInteractionEnabled = YES;
    _panelWindow.hidden = NO;
    [self collapsePanel];
    [self refreshTaskRunRuntimeLabel];
    [self refreshCollapsedButtonTitle];
}

- (void)restorePanelAfterRecognitionCaptureIfNeeded:(BOOL)shouldRestore delay:(NSTimeInterval)delay {
    if (!shouldRestore) {
        return;
    }
    [self restorePanelAfterScreenDelay:MAX(0.05, delay)];
}

- (void)showVolumeShortcutToast:(NSString *)message {
    CFTimeInterval holdUntil = CACurrentMediaTime() + 0.55;
    _toastDeferNonVolumeUntil = MAX(_toastDeferNonVolumeUntil, holdUntil);
    [self showToast:message];
}

- (CGSize)expandedPanelSize {
    return [self expandedPanelSizeForEditorVisible:_taskEditorVisible];
}

- (CGFloat)homeBrandHeaderHeight {
    return 34.0;
}

- (CGFloat)homeBrandHeaderGap {
    return 7.0;
}

- (CGFloat)homeOutputFooterHeight {
    return 25.0;
}

- (CGFloat)homeOutputFooterGap {
    return 7.0;
}

- (CGFloat)homeBrandHeaderTotalHeightForEditorVisible:(BOOL)editorVisible {
    return editorVisible ? 0.0 : ([self homeBrandHeaderHeight] + [self homeBrandHeaderGap]);
}

- (CGFloat)homeOutputFooterTotalHeightForEditorVisible:(BOOL)editorVisible {
    return editorVisible ? 0.0 : ([self homeOutputFooterHeight] + [self homeOutputFooterGap]);
}

- (CGRect)panelContentFrameForBounds:(CGRect)bounds editorVisible:(BOOL)editorVisible {
    CGFloat topOffset = [self homeBrandHeaderTotalHeightForEditorVisible:editorVisible];
    CGFloat bottomOffset = [self homeOutputFooterTotalHeightForEditorVisible:editorVisible];
    return CGRectMake(0.0,
                      topOffset,
                      bounds.size.width,
                      MAX(1.0, bounds.size.height - topOffset - bottomOffset));
}

- (CGSize)expandedPanelSizeForEditorVisible:(BOOL)editorVisible {
    CGSize screenSize = [self currentScreenBounds].size;
    BOOL landscape = screenSize.width > screenSize.height;
    CGFloat widthLimit = editorVisible ? 380.0 : 340.0;
    CGFloat width = floor(MIN(widthLimit, MAX(220.0, screenSize.width - 10.0)));
    CGFloat verticalPadding = landscape ? 52.0 : 60.0;
    CGFloat availableHeight = MAX(260.0, screenSize.height - verticalPadding);
    CGFloat editorPreferredHeight = landscape ? availableHeight : 760.0;
    CGFloat editorMinHeight = landscape ? 320.0 : 660.0;
    CGFloat preferredHeight = MIN(editorVisible ? editorPreferredHeight : 420.0, availableHeight);
    CGFloat minHeight = MIN(editorVisible ? editorMinHeight : 340.0, availableHeight);
    CGFloat totalHeight = MAX(minHeight, preferredHeight) +
        [self homeBrandHeaderTotalHeightForEditorVisible:editorVisible] +
        [self homeOutputFooterTotalHeightForEditorVisible:editorVisible];
    return CGSizeMake(width, floor(MIN(availableHeight, totalHeight)));
}

- (CGRect)clampedPanelFrame:(CGRect)frame {
    CGRect bounds = [self currentScreenBounds];
    UIEdgeInsets safeInsets = [self panelSafeAreaInsets];
    BOOL landscape = bounds.size.width > bounds.size.height;
    CGFloat minX = MAX(4.0, safeInsets.left + 4.0);
    CGFloat minY = landscape ? MAX(4.0, safeInsets.top + 4.0) : MAX(24.0, safeInsets.top + 4.0);
    CGFloat maxWidth = MAX(180.0, bounds.size.width - minX - MAX(4.0, safeInsets.right + 4.0));
    CGFloat maxHeight = MAX(180.0, bounds.size.height - minY - MAX(4.0, safeInsets.bottom + 4.0));
    frame.size.width = floor(MIN(MAX(1.0, frame.size.width), maxWidth));
    frame.size.height = floor(MIN(MAX(1.0, frame.size.height), maxHeight));
    CGFloat maxX = bounds.size.width - frame.size.width - MAX(4.0, safeInsets.right + 4.0);
    CGFloat maxY = bounds.size.height - frame.size.height - MAX(4.0, safeInsets.bottom + 4.0);
    frame.origin.x = MIN(MAX(frame.origin.x, minX), MAX(minX, maxX));
    frame.origin.y = MIN(MAX(frame.origin.y, minY), MAX(minY, maxY));
    return frame;
}

- (CGRect)clampedFloatingFrame:(CGRect)frame {
    CGRect bounds = [self currentScreenBounds];
    UIEdgeInsets safeInsets = [self panelSafeAreaInsets];
    BOOL landscape = bounds.size.width > bounds.size.height;
    CGFloat minX = MAX(6.0, safeInsets.left + 6.0);
    CGFloat minY = landscape ? MAX(4.0, safeInsets.top + 4.0) : MAX(6.0, safeInsets.top + 8.0);
    CGFloat maxWidth = MAX(44.0, bounds.size.width - minX - MAX(6.0, safeInsets.right + 6.0));
    CGFloat maxHeight = MAX(44.0, bounds.size.height - minY - MAX(6.0, safeInsets.bottom + 8.0));
    frame.size.width = floor(MIN(MAX(1.0, frame.size.width), maxWidth));
    frame.size.height = floor(MIN(MAX(1.0, frame.size.height), maxHeight));
    CGFloat maxX = bounds.size.width - frame.size.width - MAX(6.0, safeInsets.right + 6.0);
    CGFloat maxY = bounds.size.height - frame.size.height - MAX(6.0, safeInsets.bottom + 8.0);
    frame.origin.x = MIN(MAX(frame.origin.x, minX), MAX(minX, maxX));
    frame.origin.y = MIN(MAX(frame.origin.y, minY), MAX(minY, maxY));
    return frame;
}

- (void)layoutLimitsForFrame:(CGRect)frame floating:(BOOL)floating minX:(CGFloat *)minX minY:(CGFloat *)minY maxX:(CGFloat *)maxX maxY:(CGFloat *)maxY {
    CGRect bounds = [self currentScreenBounds];
    UIEdgeInsets safeInsets = [self panelSafeAreaInsets];
    BOOL landscape = bounds.size.width > bounds.size.height;
    CGFloat horizontalMargin = floating ? 6.0 : 4.0;
    CGFloat minTop = floating ? 6.0 : 24.0;
    CGFloat landscapeMinTop = floating ? 4.0 : 4.0;
    CGFloat bottomMargin = floating ? 8.0 : 4.0;
    CGFloat left = MAX(horizontalMargin, safeInsets.left + horizontalMargin);
    CGFloat top = landscape ? MAX(landscapeMinTop, safeInsets.top + landscapeMinTop) : MAX(minTop, safeInsets.top + (floating ? 8.0 : 4.0));
    CGFloat right = bounds.size.width - frame.size.width - MAX(horizontalMargin, safeInsets.right + horizontalMargin);
    CGFloat bottom = bounds.size.height - frame.size.height - MAX(floating ? 6.0 : 4.0, safeInsets.bottom + bottomMargin);

    if (minX) {
        *minX = left;
    }
    if (minY) {
        *minY = top;
    }
    if (maxX) {
        *maxX = MAX(left, right);
    }
    if (maxY) {
        *maxY = MAX(top, bottom);
    }
}

- (CGFloat)clampedUnitValue:(CGFloat)value {
    if (!isfinite(value)) {
        return 0.0;
    }
    return MIN(MAX(value, 0.0), 1.0);
}

- (CGPoint)originRatioForWindowFrame:(CGRect)frame floating:(BOOL)floating {
    CGFloat minX = 0.0;
    CGFloat minY = 0.0;
    CGFloat maxX = 0.0;
    CGFloat maxY = 0.0;
    [self layoutLimitsForFrame:frame floating:floating minX:&minX minY:&minY maxX:&maxX maxY:&maxY];
    CGFloat xRange = maxX - minX;
    CGFloat yRange = maxY - minY;
    CGFloat xRatio = xRange > 0.5 ? (frame.origin.x - minX) / xRange : 0.5;
    CGFloat yRatio = yRange > 0.5 ? (frame.origin.y - minY) / yRange : 0.0;
    return CGPointMake([self clampedUnitValue:xRatio], [self clampedUnitValue:yRatio]);
}

- (CGRect)windowFrameWithSize:(CGSize)size originRatio:(CGPoint)originRatio floating:(BOOL)floating {
    CGRect frame = CGRectMake(0.0, 0.0, size.width, size.height);
    CGFloat minX = 0.0;
    CGFloat minY = 0.0;
    CGFloat maxX = 0.0;
    CGFloat maxY = 0.0;
    [self layoutLimitsForFrame:frame floating:floating minX:&minX minY:&minY maxX:&maxX maxY:&maxY];
    frame.origin.x = minX + (maxX - minX) * [self clampedUnitValue:originRatio.x];
    frame.origin.y = minY + (maxY - minY) * [self clampedUnitValue:originRatio.y];
    return floating ? [self clampedFloatingFrame:frame] : [self clampedPanelFrame:frame];
}

- (CGSize)collapsedPanelSize {
    return CGSizeMake(64.0, 72.0);
}

- (CGRect)collapsedButtonFrameForPanelSize:(CGSize)size {
    CGFloat buttonSide = 48.0;
    return CGRectMake(MAX(0.0, floor((size.width - buttonSide) * 0.5)),
                      0.0,
                      buttonSide,
                      buttonSide);
}

- (void)layoutCollapsedControls {
    if (!_panelWindow || !_collapsedButton) {
        return;
    }

    CGSize size = _panelWindow.bounds.size;
    CGRect buttonFrame = [self collapsedButtonFrameForPanelSize:size];
    _collapsedButton.frame = buttonFrame;
    if (_collapsedRuntimeLabel) {
        CGFloat labelY = CGRectGetMaxY(buttonFrame) + 4.0;
        _collapsedRuntimeLabel.frame = CGRectMake(0.0, labelY, size.width, 18.0);
        _collapsedRuntimeLabel.hidden = !(_taskRunActive || _taskRunPausedForForeground);
    }
    [self refreshTaskRunRuntimeLabel];
    [self refreshCollapsedButtonTitle];
}

- (CGRect)defaultCollapsedPanelFrame {
    CGRect bounds = [self currentScreenBounds];
    UIEdgeInsets safeInsets = [self panelSafeAreaInsets];
    CGSize size = [self collapsedPanelSize];
    CGFloat x = bounds.size.width - size.width - MAX(12.0, safeInsets.right + 12.0);
    CGFloat y = MAX(118.0, safeInsets.top + 36.0);
    return [self clampedFloatingFrame:CGRectMake(x, y, size.width, size.height)];
}

- (void)rememberCollapsedPanelFrame:(CGRect)frame {
    frame.size = [self collapsedPanelSize];
    _collapsedPanelFrame = [self clampedFloatingFrame:frame];
    _collapsedPanelOriginRatio = [self originRatioForWindowFrame:_collapsedPanelFrame floating:YES];
    _collapsedPanelScreenSize = [self currentScreenBounds].size;
    _hasCollapsedPanelFrame = YES;
    _hasCollapsedPanelOriginRatio = YES;
}

- (CGRect)rememberedCollapsedPanelFrame {
    CGSize currentSize = [self currentScreenBounds].size;
    CGRect frame = _hasCollapsedPanelFrame ? _collapsedPanelFrame : (_panelWindow ? _panelWindow.frame : [self defaultCollapsedPanelFrame]);
    if (_hasCollapsedPanelOriginRatio &&
        (![self screenGeometrySize:currentSize isCloseToSize:_collapsedPanelScreenSize] || !_hasCollapsedPanelFrame)) {
        CGSize size = [self collapsedPanelSize];
        CGFloat xRatio = [self clampedUnitValue:_collapsedPanelOriginRatio.x];
        if (xRatio <= 0.08) {
            xRatio = 0.0;
        } else if (xRatio >= 0.92) {
            xRatio = 1.0;
        }
        CGPoint ratio = CGPointMake(xRatio, [self clampedUnitValue:_collapsedPanelOriginRatio.y]);
        frame = [self windowFrameWithSize:size originRatio:ratio floating:YES];
    }
    [self rememberCollapsedPanelFrame:frame];
    return _collapsedPanelFrame;
}

- (void)rememberExpandedPanelFrame:(CGRect)frame {
    _expandedPanelFrame = [self clampedPanelFrame:frame];
    _expandedPanelOriginRatio = [self originRatioForWindowFrame:_expandedPanelFrame floating:NO];
    _expandedPanelScreenSize = [self currentScreenBounds].size;
    _hasExpandedPanelFrame = YES;
    _hasExpandedPanelOriginRatio = YES;
}

- (CGRect)rememberedExpandedPanelFrameWithSize:(CGSize)size fallbackFrame:(CGRect)fallbackFrame {
    CGSize currentSize = [self currentScreenBounds].size;
    CGRect frame = _hasExpandedPanelFrame ? _expandedPanelFrame : fallbackFrame;
    frame.size = size;
    if (_hasExpandedPanelOriginRatio &&
        (![self screenGeometrySize:currentSize isCloseToSize:_expandedPanelScreenSize] || !_hasExpandedPanelFrame)) {
        frame = [self windowFrameWithSize:size
                              originRatio:CGPointMake([self clampedUnitValue:_expandedPanelOriginRatio.x],
                                                      [self clampedUnitValue:_expandedPanelOriginRatio.y])
                                  floating:NO];
    } else {
        frame = [self clampedPanelFrame:frame];
    }
    [self rememberExpandedPanelFrame:frame];
    return _expandedPanelFrame;
}

- (UIEdgeInsets)panelSafeAreaInsets {
    UIEdgeInsets insets = UIEdgeInsetsZero;
    CGSize screenSize = [self currentScreenBounds].size;
    BOOL landscape = screenSize.width > screenSize.height;
    UIWindow *hostWindow = [self hostWindow];
    if (@available(iOS 11.0, *)) {
        if (hostWindow) {
            insets = hostWindow.safeAreaInsets;
        }
    }
    if (UIEdgeInsetsEqualToEdgeInsets(insets, UIEdgeInsetsZero)) {
        UIWindow *window = _panelWindow;
        if (@available(iOS 11.0, *)) {
            if (window) {
                insets = window.safeAreaInsets;
            }
        }
    }
    CGFloat statusHeight = 0.0;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = hostWindow.windowScene;
        if (!scene) {
            scene = _panelWindow.windowScene;
        }
        if (!scene) {
            scene = [self activeWindowScene];
        }
        statusHeight = scene.statusBarManager.statusBarFrame.size.height;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        statusHeight = UIApplication.sharedApplication.statusBarFrame.size.height;
#pragma clang diagnostic pop
    }

    if (landscape) {
        insets.top = 0.0;
    } else {
        insets.top = MAX(insets.top, statusHeight);
        if (insets.top > 0.0) {
            insets.top += 6.0;
        }
    }
    return insets;
}

- (UIEdgeInsets)overlaySafeAreaInsetsForView:(UIView *)view window:(UIWindow *)window {
    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        if (view) {
            insets = view.safeAreaInsets;
        }
        if (window) {
            UIEdgeInsets windowInsets = window.safeAreaInsets;
            insets.top = MAX(insets.top, windowInsets.top);
            insets.left = MAX(insets.left, windowInsets.left);
            insets.bottom = MAX(insets.bottom, windowInsets.bottom);
            insets.right = MAX(insets.right, windowInsets.right);
        }
        UIWindow *hostWindow = [self hostWindow];
        if (hostWindow) {
            UIEdgeInsets hostInsets = hostWindow.safeAreaInsets;
            insets.top = MAX(insets.top, hostInsets.top);
            insets.left = MAX(insets.left, hostInsets.left);
            insets.bottom = MAX(insets.bottom, hostInsets.bottom);
            insets.right = MAX(insets.right, hostInsets.right);
        }
    }

    CGSize screenSize = view ? view.bounds.size : [self currentScreenBounds].size;
    if (screenSize.width <= 0.0 || screenSize.height <= 0.0) {
        screenSize = [self currentScreenBounds].size;
    }
    CGFloat shortSide = MIN(screenSize.width, screenSize.height);
    CGFloat longSide = MAX(screenSize.width, screenSize.height);
    BOOL likelyNotchedPhone = shortSide <= 430.0 && longSide >= 812.0;
    BOOL landscape = screenSize.width > screenSize.height;
    if (likelyNotchedPhone) {
        if (landscape) {
            if (insets.left <= 0.0) {
                insets.left = 46.0;
            }
            if (insets.right <= 0.0) {
                insets.right = 46.0;
            }
            if (insets.bottom <= 0.0) {
                insets.bottom = 16.0;
            }
        } else {
            if (insets.top <= 0.0) {
                insets.top = 54.0;
            }
            if (insets.bottom <= 0.0) {
                insets.bottom = 21.0;
            }
        }
    }
    return insets;
}

- (void)relayoutScreenInteractionOverlays {
    CGRect screenBounds = [self currentScreenBounds];
    if (_captureOverlay) {
        _captureOverlay.frame = screenBounds;
        [_captureOverlay setNeedsLayout];
    }
    if (_pointPickWindow) {
        _pointPickWindow.frame = screenBounds;
        _pointPickWindow.rootViewController.view.frame = _pointPickWindow.bounds;
        _pointPickOverlay.frame = _pointPickWindow.rootViewController.view.bounds;
        [self updatePointPickCursor];
        if (_actionMode == AnClickActionModeSwipe && _hasManualSwipeAnchor) {
            [self showPointPickSwipeStartMarker];
        }
    }
    if (_colorPickWindow) {
        _colorPickWindow.frame = screenBounds;
        UIView *root = _colorPickWindow.rootViewController.view;
        root.frame = _colorPickWindow.bounds;
        _colorPickOverlay.frame = root.bounds;
        [_colorPickOverlay setNeedsLayout];
    }
}

- (void)refreshActivePanelOverlayLayoutAllowHeavyRefresh:(BOOL)allowHeavyRefresh {
    if (!_panelView) {
        return;
    }

    BOOL hadGlobalSettings = _globalSettingsView != nil;
    BOOL hadFunctionMenu = _functionMenuView != nil;
    BOOL hadConfigList = _configListView != nil;
    BOOL configListDeleting = _configListDeleting;
    BOOL hadSaveConfigPrompt = _configNameField != nil;
    NSString *configNameText = _configNameField.text ?: @"";
    NSInteger pendingDeleteIndex = _pendingConfigDeleteIndex;
    BOOL hadDeleteConfigPrompt = _configPromptView != nil && pendingDeleteIndex >= 0 && !hadSaveConfigPrompt;

    if (hadGlobalSettings && allowHeavyRefresh) {
        [self syncGlobalSettingsFromFields];
        CGFloat preferredHeight = [self homeFloatingPanelPreferredHeightForTag:_globalSettingsView.tag
                                                                      fallback:CGRectGetHeight(_globalSettingsView.bounds)];
        [self layoutHomeFloatingPanel:_globalSettingsView preferredHeight:preferredHeight];
        return;
    }

    if (hadFunctionMenu && allowHeavyRefresh) {
        [self layoutHomeFloatingPanel:_functionMenuView
                       preferredHeight:[self homeFloatingPanelPreferredHeightForTag:_functionMenuView.tag
                                                                           fallback:CGRectGetHeight(_functionMenuView.bounds)]];
        if (hadConfigList) {
            [self showSavedConfigListForDeleting:configListDeleting];
        } else {
            [self showFunctionMenu];
        }

        if (hadSaveConfigPrompt) {
            [self showSaveTaskConfigNamePrompt];
            _configNameField.text = configNameText;
        } else if (hadDeleteConfigPrompt) {
            NSArray *configs = [self savedTaskConfigs];
            if (pendingDeleteIndex >= 0 && pendingDeleteIndex < (NSInteger)configs.count) {
                NSDictionary *config = configs[(NSUInteger)pendingDeleteIndex];
                NSString *name = [config[@"name"] isKindOfClass:NSString.class] ? config[@"name"] : [NSString stringWithFormat:@"配置%lu", (unsigned long)pendingDeleteIndex + 1];
                NSArray *tasks = [config[@"tasks"] isKindOfClass:NSArray.class] ? config[@"tasks"] : @[];
                [self showDeleteSavedConfigConfirmationAtIndex:pendingDeleteIndex name:name taskCount:tasks.count];
            }
        }
        return;
    }

    if (_globalSettingsView) {
        [self layoutHomeFloatingPanel:_globalSettingsView
                       preferredHeight:[self homeFloatingPanelPreferredHeightForTag:_globalSettingsView.tag
                                                                           fallback:CGRectGetHeight(_globalSettingsView.bounds)]];
    }
    if (_functionMenuView) {
        [self layoutHomeFloatingPanel:_functionMenuView
                       preferredHeight:[self homeFloatingPanelPreferredHeightForTag:_functionMenuView.tag
                                                                           fallback:CGRectGetHeight(_functionMenuView.bounds)]];
    }
    _configPromptView.frame = _functionMenuView.bounds;
}

- (void)reclampPanelWindowForCurrentScreen {
    [self reclampPanelWindowForCurrentScreenAllowHeavyRefresh:YES];
}

- (void)reclampPanelWindowForCurrentScreenAllowHeavyRefresh:(BOOL)allowHeavyRefresh {
    if (!_panelWindow) {
        return;
    }

    if (_panelWindow.userInteractionEnabled && !_captureOverlay && !_pointPickWindow && !_colorPickWindow) {
        _panelWindow.hidden = NO;
    }

    BOOL previousSuppressPreview = _suppressTemplatePreviewRefresh;
    _suppressTemplatePreviewRefresh = previousSuppressPreview || !allowHeavyRefresh;
    CGRect frame = _panelWindow.frame;
    if (_panelExpanded) {
        _collapsedButton.hidden = YES;
        _collapsedRuntimeLabel.hidden = YES;
        _homeBrandView.hidden = _taskEditorVisible;
        _homeOutputView.hidden = _taskEditorVisible;
        _panelView.hidden = NO;
        frame = [self rememberedExpandedPanelFrameWithSize:[self expandedPanelSize] fallbackFrame:frame];
        _panelWindow.frame = frame;
        _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
        _panelView.frame = [self panelContentFrameForBounds:_panelWindow.bounds editorVisible:_taskEditorVisible];
        if (_taskEditorVisible) {
            [self refreshEditorConfigControls];
        } else {
            [self layoutTaskHomeControls];
            if (allowHeavyRefresh) {
                [self refreshTaskList];
            }
        }
        [self refreshActivePanelOverlayLayoutAllowHeavyRefresh:allowHeavyRefresh];
        _suppressTemplatePreviewRefresh = previousSuppressPreview;
        return;
    }

    frame = [self rememberedCollapsedPanelFrame];
    _panelWindow.frame = frame;
    _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
    _collapsedButton.hidden = NO;
    _homeBrandView.hidden = YES;
    _homeOutputView.hidden = YES;
    _panelView.hidden = YES;
    [self layoutCollapsedControls];
    _suppressTemplatePreviewRefresh = previousSuppressPreview;
}

- (void)refreshCollapsedButtonTitle {
    if ([AnClickRecorder shared].isRecording) {
        _collapsedButton.layer.cornerRadius = CGRectGetWidth(_collapsedButton.bounds) * 0.5;
        _collapsedButton.layer.borderWidth = 2.0;
        _collapsedButton.backgroundColor = [UIColor colorWithRed:0.92 green:0.05 blue:0.08 alpha:0.98];
        _collapsedButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.64 blue:0.48 alpha:0.95].CGColor;
        _collapsedButton.layer.shadowColor = [UIColor colorWithRed:1.0 green:0.12 blue:0.08 alpha:1.0].CGColor;
        _collapsedButton.layer.shadowOpacity = 0.62;
        _collapsedButton.layer.shadowRadius = 10.0;
        _collapsedButton.layer.shadowOffset = CGSizeZero;
        [self setCenteredIconForButton:_collapsedButton systemName:@"stop.fill" fallbackTitle:@"■" fontSize:20];
        _collapsedButton.tintColor = UIColor.whiteColor;
        [_collapsedButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [self updateButtonShadowPath:_collapsedButton];
        return;
    }
    if (_taskRunActive) {
        _collapsedButton.layer.cornerRadius = CGRectGetWidth(_collapsedButton.bounds) * 0.5;
        _collapsedButton.layer.borderWidth = 2.0;
        _collapsedButton.backgroundColor = [UIColor colorWithRed:0.92 green:0.05 blue:0.08 alpha:0.98];
        _collapsedButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.64 blue:0.48 alpha:0.95].CGColor;
        _collapsedButton.layer.shadowColor = [UIColor colorWithRed:1.0 green:0.12 blue:0.08 alpha:1.0].CGColor;
        _collapsedButton.layer.shadowOpacity = 0.62;
        _collapsedButton.layer.shadowRadius = 10.0;
        _collapsedButton.layer.shadowOffset = CGSizeZero;
        [self setCenteredIconForButton:_collapsedButton systemName:@"stop.fill" fallbackTitle:@"■" fontSize:20];
        _collapsedButton.tintColor = UIColor.whiteColor;
        [_collapsedButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [self updateButtonShadowPath:_collapsedButton];
        return;
    }
    _collapsedButton.layer.cornerRadius = CGRectGetWidth(_collapsedButton.bounds) * 0.5;
    _collapsedButton.layer.borderWidth = 2.0;
    _collapsedButton.backgroundColor = [self floatingButtonIdleColor];
    _collapsedButton.layer.borderColor = [self floatingButtonIdleBorderColor].CGColor;
    _collapsedButton.layer.shadowColor = [self floatingButtonIdleShadowColor].CGColor;
    _collapsedButton.layer.shadowOpacity = 0.58;
    _collapsedButton.layer.shadowRadius = 10.0;
    _collapsedButton.layer.shadowOffset = CGSizeZero;
    [self setCenteredIconForButton:_collapsedButton systemName:@"play.circle.fill" fallbackTitle:@"▶" fontSize:25];
    _collapsedButton.tintColor = UIColor.whiteColor;
    [_collapsedButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self updateButtonShadowPath:_collapsedButton];
}

- (NSString *)formattedTaskRunDuration {
    return [_taskEngine formattedRuntime];
}

- (void)refreshTaskRunRuntimeLabel {
    if (!_collapsedRuntimeLabel) {
        return;
    }
    _collapsedRuntimeLabel.text = [self formattedTaskRunDuration];
    _collapsedRuntimeLabel.hidden = !(_taskRunActive || _taskRunPausedForForeground);
}

- (void)startTaskRunRuntimeTimerReset:(BOOL)reset {
    [_taskEngine startRuntimeReset:reset];
    [self refreshTaskRunRuntimeLabel];
}

- (void)stopTaskRunRuntimeTimerReset:(BOOL)reset {
    [_taskEngine stopRuntimeReset:reset];
    [self refreshTaskRunRuntimeLabel];
}

- (void)setTaskEditorVisible:(BOOL)visible {
    _taskEditorVisible = visible;
    if (_panelExpanded && _panelWindow && _panelView) {
        CGRect frame = _panelWindow.frame;
        frame = [self rememberedExpandedPanelFrameWithSize:[self expandedPanelSizeForEditorVisible:visible] fallbackFrame:frame];
        _panelWindow.frame = frame;
        _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
        _panelView.frame = [self panelContentFrameForBounds:_panelWindow.bounds editorVisible:visible];
    }

    _addTaskButton.hidden = visible;
    _deleteTaskButton.hidden = visible;
    _runTasksButton.hidden = visible;
    _homeCloseButton.hidden = visible;
    _globalSettingsButton.hidden = visible;
    _homeBrandView.hidden = visible;
    _authorFollowButton.hidden = visible;
    _homeOutputView.hidden = visible;
    [_panelView viewWithTag:AnClickHomeAddLabelTag].hidden = visible;
    [_panelView viewWithTag:AnClickHomeDeleteLabelTag].hidden = visible;
    [_panelView viewWithTag:AnClickHomeRunLabelTag].hidden = visible;
    [_panelView viewWithTag:AnClickHomeStopLabelTag].hidden = visible;
    [_panelView viewWithTag:AnClickHomeRecordLabelTag].hidden = visible;
    _homeTimeButton.hidden = visible;
    _homeLoopButton.hidden = visible;
    _homeMonitorButton.hidden = visible;
    _homeSaveConfigButton.hidden = visible;
    [_panelView viewWithTag:AnClickHomeTimeLabelTag].hidden = visible;
    [_panelView viewWithTag:AnClickHomeLoopLabelTag].hidden = visible;
    [_panelView viewWithTag:AnClickHomeMonitorLabelTag].hidden = visible;
    [_panelView viewWithTag:AnClickHomeSaveLabelTag].hidden = visible;
    _collapseButton.hidden = visible;
    _taskListView.hidden = visible;
    _taskEditorView.hidden = !visible;

    if (visible) {
        [self hideGlobalSettings];
        [self refreshTaskEditorViewFromCurrentState];
        [_panelView bringSubviewToFront:_taskEditorView];
    } else {
        _recognitionRetryDropdownVisible = NO;
        [self layoutTaskHomeControls];
    }
}

- (void)styleHomeTopIconButton:(UIButton *)button blueCircle:(BOOL)blueCircle {
    if (!button) {
        return;
    }
    button.backgroundColor = blueCircle ? [self themeHighlightColor] : [self themeControlFillColor];
    button.tintColor = blueCircle ? UIColor.whiteColor : [self themePrimaryTextColor];
    [button setTitleColor:button.tintColor forState:UIControlStateNormal];
    button.layer.cornerRadius = CGRectGetHeight(button.bounds) * 0.5;
    button.layer.borderWidth = blueCircle ? 0.0 : 1.0;
    button.layer.borderColor = [self themeSeparatorColor].CGColor;
    button.layer.shadowColor = [self neumorphicShadowColor].CGColor;
    button.layer.shadowOpacity = blueCircle ? 0.20 : 0.12;
    button.layer.shadowRadius = 4.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    [self updateButtonShadowPath:button];
}

- (UILabel *)homeToolbarLabelWithTag:(NSInteger)tag text:(NSString *)text {
    UILabel *label = [_panelView viewWithTag:tag];
    if (![label isKindOfClass:UILabel.class]) {
        [label removeFromSuperview];
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.tag = tag;
        [_panelView addSubview:label];
    }
    label.hidden = NO;
    label.text = text ?: @"";
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [self themeSecondaryTextColor];
    label.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightSemibold];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.72;
    return label;
}

- (void)layoutTaskHomeControls {
    if (!_panelView) {
        return;
    }

    CGFloat width = _panelView.bounds.size.width;
    CGFloat height = _panelView.bounds.size.height;
    CGFloat side = 10.0;
    CGFloat brandHeight = 34.0;
    CGFloat topY = 9.0;
    CGFloat smallSide = 25.0;
    CGFloat brandY = 0.0;
    CGFloat actionLabelWidth = MIN(31.0, floor((width - 18.0) / 9.0));
    CGFloat actionGap = MAX(1.0, floor((width - actionLabelWidth * 9.0 - 19.0) / 8.0));
    CGFloat startX = 9.5;
    CGFloat (^slotX)(NSUInteger) = ^CGFloat(NSUInteger index) {
        return startX + (actionLabelWidth + actionGap) * index;
    };
    CGFloat (^buttonX)(NSUInteger) = ^CGFloat(NSUInteger index) {
        return slotX(index) + (actionLabelWidth - smallSide) * 0.5;
    };
    [_panelView viewWithTag:8811].hidden = YES;

    [_collapseButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [_collapseButton addTarget:self action:@selector(stopTaskRunFromHomeButton) forControlEvents:UIControlEventTouchUpInside];
    [_homeCloseButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [_homeCloseButton addTarget:self action:@selector(collapsePanel) forControlEvents:UIControlEventTouchUpInside];

    _homeBrandView.hidden = NO;
    _homeBrandView.frame = CGRectMake(side, brandY, width - side * 2.0, brandHeight);
    _homeBrandView.backgroundColor = [[self themeControlFillColor] colorWithAlphaComponent:0.76];
    _homeBrandView.layer.borderColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.42].CGColor;

    CGFloat followWidth = MIN(106.0, MAX(92.0, floor(width * 0.30)));
    _authorFollowButton.hidden = NO;
    _authorFollowButton.frame = CGRectMake(CGRectGetWidth(_homeBrandView.bounds) - followWidth - 7.0,
                                           6.0,
                                           followWidth,
                                           brandHeight - 12.0);
    _authorFollowButton.backgroundColor = [self themeHighlightColor];
    _authorFollowButton.layer.shadowColor = [self themeHighlightColor].CGColor;
    [self updateButtonShadowPath:_authorFollowButton];

    _toolTitleLabel.hidden = NO;
    _toolTitleLabel.text = [self toolDisplayName];
    CGFloat titleX = 9.0;
    CGFloat titleWidth = CGRectGetMinX(_authorFollowButton.frame) - titleX - 8.0;
    _toolTitleLabel.frame = CGRectMake(titleX,
                                       0.0,
                                       MAX(80.0, titleWidth),
                                       brandHeight);
    _toolTitleLabel.textColor = [self themePrimaryTextColor];
    _toolTitleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightHeavy];
    _toolTitleLabel.textAlignment = NSTextAlignmentLeft;

    CGFloat outputHeight = [self homeOutputFooterHeight];
    _homeOutputView.hidden = NO;
    _homeOutputView.frame = CGRectMake(side,
                                       CGRectGetHeight(_panelWindow.rootViewController.view.bounds) - outputHeight,
                                       width - side * 2.0,
                                       outputHeight);
    _homeOutputView.backgroundColor = [[self themeControlFillColor] colorWithAlphaComponent:0.76];
    _homeOutputView.layer.borderColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.42].CGColor;
    _statusLabel.hidden = NO;
    _statusLabel.frame = CGRectInset(_homeOutputView.bounds, 10.0, 3.0);
    _statusLabel.textColor = [self themeSecondaryTextColor];
    _statusLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];

    [self setCenteredIconForButton:_addTaskButton systemName:@"plus" fallbackTitle:@"+" fontSize:21];
    _addTaskButton.frame = CGRectMake(buttonX(0), topY + 1.0, smallSide, smallSide);
    [self styleHomeTopIconButton:_addTaskButton blueCircle:YES];
    UILabel *addLabel = [self homeToolbarLabelWithTag:AnClickHomeAddLabelTag text:@"添加"];
    addLabel.textColor = [[self themeHighlightColor] colorWithAlphaComponent:0.92];
    addLabel.frame = CGRectMake(slotX(0), topY + smallSide + 3.0, actionLabelWidth, 13.0);

    [self setCenteredIconForButton:_deleteTaskButton systemName:@"trash" fallbackTitle:@"删" fontSize:15];
    _deleteTaskButton.frame = CGRectMake(buttonX(1), topY + 1.0, smallSide, smallSide);
    [self styleHomeTopIconButton:_deleteTaskButton blueCircle:NO];
    _deleteTaskButton.tintColor = [self themeDangerColor];
    [_deleteTaskButton setTitleColor:[self themeDangerColor] forState:UIControlStateNormal];
    UILabel *deleteLabel = [self homeToolbarLabelWithTag:AnClickHomeDeleteLabelTag text:@"删除"];
    deleteLabel.textColor = [[self themeDangerColor] colorWithAlphaComponent:0.92];
    deleteLabel.frame = CGRectMake(slotX(1), topY + smallSide + 3.0, actionLabelWidth, 13.0);

    [self setCenteredIconForButton:_homeTimeButton systemName:@"clock.fill" fallbackTitle:@"时" fontSize:13];
    _homeTimeButton.frame = CGRectMake(buttonX(2), topY + 1.0, smallSide, smallSide);
    [self styleHomeTopIconButton:_homeTimeButton blueCircle:NO];
    UILabel *timeLabel = [self homeToolbarLabelWithTag:AnClickHomeTimeLabelTag text:@"定时"];
    timeLabel.frame = CGRectMake(slotX(2), topY + smallSide + 3.0, actionLabelWidth, 13.0);

    [self setCenteredIconForButton:_homeLoopButton systemName:@"repeat" fallbackTitle:@"循" fontSize:13];
    _homeLoopButton.frame = CGRectMake(buttonX(3), topY + 1.0, smallSide, smallSide);
    [self styleHomeTopIconButton:_homeLoopButton blueCircle:NO];
    UILabel *loopLabel = [self homeToolbarLabelWithTag:AnClickHomeLoopLabelTag text:@"循环"];
    loopLabel.frame = CGRectMake(slotX(3), topY + smallSide + 3.0, actionLabelWidth, 13.0);

    [self setCenteredIconForButton:_homeMonitorButton systemName:@"antenna.radiowaves.left.and.right" fallbackTitle:@"监" fontSize:12];
    _homeMonitorButton.frame = CGRectMake(buttonX(4), topY + 1.0, smallSide, smallSide);
    [self styleHomeTopIconButton:_homeMonitorButton blueCircle:NO];
    UILabel *monitorLabel = [self homeToolbarLabelWithTag:AnClickHomeMonitorLabelTag text:@"监控"];
    monitorLabel.frame = CGRectMake(slotX(4), topY + smallSide + 3.0, actionLabelWidth, 13.0);

    [self setCenteredIconForButton:_homeSaveConfigButton systemName:@"tray.and.arrow.down.fill" fallbackTitle:@"存" fontSize:12];
    _homeSaveConfigButton.frame = CGRectMake(buttonX(5), topY + 1.0, smallSide, smallSide);
    [self styleHomeTopIconButton:_homeSaveConfigButton blueCircle:NO];
    UILabel *saveLabel = [self homeToolbarLabelWithTag:AnClickHomeSaveLabelTag text:@"保存"];
    saveLabel.frame = CGRectMake(slotX(5), topY + smallSide + 3.0, actionLabelWidth, 13.0);

    [self setCenteredIconForButton:_runTasksButton systemName:@"play.fill" fallbackTitle:@"▶" fontSize:13];
    _runTasksButton.frame = CGRectMake(buttonX(6), topY + 1.0, smallSide, smallSide);
    [self styleHomeTopIconButton:_runTasksButton blueCircle:YES];
    UILabel *runLabel = [self homeToolbarLabelWithTag:AnClickHomeRunLabelTag text:@"运行"];
    runLabel.frame = CGRectMake(slotX(6), topY + smallSide + 3.0, actionLabelWidth, 13.0);

    [self setCenteredIconForButton:_collapseButton systemName:@"stop.fill" fallbackTitle:@"■" fontSize:11];
    _collapseButton.frame = CGRectMake(buttonX(7), topY + 1.0, smallSide, smallSide);
    [self styleHomeTopIconButton:_collapseButton blueCircle:YES];
    UILabel *stopLabel = [self homeToolbarLabelWithTag:AnClickHomeStopLabelTag text:@"停止"];
    stopLabel.frame = CGRectMake(slotX(7), topY + smallSide + 3.0, actionLabelWidth, 13.0);

    [self setCenteredIconForButton:_homeCloseButton systemName:@"xmark" fallbackTitle:@"×" fontSize:13];
    _homeCloseButton.frame = CGRectMake(buttonX(8), topY + 1.0, smallSide, smallSide);
    [self styleHomeTopIconButton:_homeCloseButton blueCircle:YES];
    UILabel *recordLabel = [self homeToolbarLabelWithTag:AnClickHomeRecordLabelTag text:@"关闭"];
    recordLabel.frame = CGRectMake(slotX(8), topY + smallSide + 3.0, actionLabelWidth, 13.0);

    _globalSettingsButton.hidden = YES;

    _taskListView.frame = CGRectMake(10.0, 56.0, width - 20.0, MAX(80.0, height - 66.0));
    if (_globalSettingsView) {
        [self layoutHomeFloatingPanel:_globalSettingsView
                       preferredHeight:[self homeFloatingPanelPreferredHeightForTag:_globalSettingsView.tag
                                                                           fallback:CGRectGetHeight(_globalSettingsView.bounds)]];
        [_panelView bringSubviewToFront:_globalSettingsView];
    } else if (_functionMenuView) {
        [self layoutHomeFloatingPanel:_functionMenuView
                       preferredHeight:[self homeFloatingPanelPreferredHeightForTag:_functionMenuView.tag
                                                                           fallback:CGRectGetHeight(_functionMenuView.bounds)]];
        [_panelView bringSubviewToFront:_functionMenuView];
    } else {
        [_panelWindow.rootViewController.view bringSubviewToFront:_homeBrandView];
        [_panelWindow.rootViewController.view bringSubviewToFront:_homeOutputView];
        [_panelView bringSubviewToFront:_addTaskButton];
        [_panelView bringSubviewToFront:_deleteTaskButton];
        [_panelView bringSubviewToFront:_homeTimeButton];
        [_panelView bringSubviewToFront:_homeLoopButton];
        [_panelView bringSubviewToFront:_homeMonitorButton];
        [_panelView bringSubviewToFront:_homeSaveConfigButton];
        [_panelView bringSubviewToFront:_runTasksButton];
        [_panelView bringSubviewToFront:_collapseButton];
        [_panelView bringSubviewToFront:_homeCloseButton];
        [_panelView bringSubviewToFront:addLabel];
        [_panelView bringSubviewToFront:deleteLabel];
        [_panelView bringSubviewToFront:timeLabel];
        [_panelView bringSubviewToFront:loopLabel];
        [_panelView bringSubviewToFront:saveLabel];
        [_panelView bringSubviewToFront:runLabel];
        [_panelView bringSubviewToFront:stopLabel];
        [_panelView bringSubviewToFront:recordLabel];
    }
}

- (void)showTaskHome {
    _editingNestedBranchActionConfig = NO;
    _editingNestedBranchActionSuccess = NO;
    _editingNestedBranchActionMode = AnClickActionModeNone;
    _editingNestedBranchParentModel = nil;
    if (_editingBranchRecognitionConfig) {
        NSInteger ownerIndex = _editingBranchOwnerTaskIndex;
        _editingBranchRecognitionConfig = NO;
        _editingBranchRecognitionSuccess = NO;
        _editingBranchOwnerTaskIndex = -1;
        _editingBranchActionMode = AnClickActionModeNone;
        if (ownerIndex >= 0 && ownerIndex < (NSInteger)_taskItems.count) {
            [self selectTaskAtIndex:ownerIndex];
            return;
        }
    }
    [self hideFunctionMenu];
    [self hideGlobalSettings];
    _editingTaskModel = nil;
    _editingTaskIndex = -1;
    [self setTaskEditorVisible:NO];
    [self refreshTaskList];
    _statusLabel.text = @"";
}

- (void)handleMoreOrCloseButton {
    if (_taskEditorVisible) {
        [self collapsePanel];
        return;
    }

    [self showFunctionMenu];
}

- (NSString *)savedTaskConfigsPath {
    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[documentsURL path] stringByAppendingPathComponent:@"anclick_task_configs.archive"];
}

- (NSString *)currentTaskListPath {
    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[documentsURL path] stringByAppendingPathComponent:@"anclick_current_tasks.archive"];
}

- (NSMutableArray<AnClickTaskModel *> *)savedCurrentTaskList {
    NSString *path = [self currentTaskListPath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) {
        return [NSMutableArray array];
    }

    NSError *error = nil;
    id object = [NSKeyedUnarchiver unarchivedObjectOfClasses:[self archiveAllowedClasses] fromData:data error:&error];
    if (error) {
        NSLog(@"[AnClick] Current task list unarchive failed: %@", error.localizedDescription);
        return [NSMutableArray array];
    }

    NSArray *tasks = nil;
    if ([object isKindOfClass:NSArray.class]) {
        tasks = (NSArray *)object;
    } else if ([object isKindOfClass:NSDictionary.class]) {
        id savedTasks = [(NSDictionary *)object objectForKey:@"tasks"];
        tasks = [savedTasks isKindOfClass:NSArray.class] ? savedTasks : nil;
    }
    return [self mutableTasksFromSavedTasks:tasks ?: @[]];
}

- (void)persistCurrentTaskList {
    NSArray *tasksSnapshot = [[self copyTaskItemsForSaving] copy];
    NSString *path = [self currentTaskListPath];
    dispatch_async([self diskIOQueue], ^{
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:tasksSnapshot requiringSecureCoding:YES error:&error];
        if (!data || error) {
            NSLog(@"[AnClick] Current task list archive failed: %@", error.localizedDescription);
            return;
        }
        if (![data writeToFile:path atomically:YES]) {
            NSLog(@"[AnClick] Current task list write failed: %@", path);
        }
    });
}

- (NSMutableArray<NSMutableDictionary *> *)savedTaskConfigs {
    NSString *path = [self savedTaskConfigsPath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) {
        return [NSMutableArray array];
    }

    NSError *error = nil;
    id object = [NSKeyedUnarchiver unarchivedObjectOfClasses:[self archiveAllowedClasses] fromData:data error:&error];
    if (error) {
        NSLog(@"[AnClick] Saved task configs unarchive failed: %@", error.localizedDescription);
        return [NSMutableArray array];
    }
    if (![object isKindOfClass:NSArray.class]) {
        return [NSMutableArray array];
    }

    NSMutableArray *configs = [NSMutableArray array];
    for (NSDictionary *config in (NSArray *)object) {
        if ([config isKindOfClass:NSDictionary.class]) {
            [configs addObject:[config mutableCopy]];
        }
    }
    return configs;
}

- (void)writeSavedTaskConfigs:(NSArray *)configs {
    NSArray *configsSnapshot = [configs copy] ?: @[];
    NSString *path = [self savedTaskConfigsPath];
    dispatch_async([self diskIOQueue], ^{
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:configsSnapshot requiringSecureCoding:YES error:&error];
        if (!data || error) {
            NSLog(@"[AnClick] Saved task configs archive failed: %@", error.localizedDescription);
            return;
        }
        if (![data writeToFile:path atomically:YES]) {
            NSLog(@"[AnClick] Saved task configs write failed: %@", path);
        }
    });
}

- (NSMutableArray<NSDictionary *> *)copyTaskItemsForSaving {
    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:_taskItems.count];
    for (AnClickTaskModel *model in _taskItems) {
        NSMutableDictionary *task = [self taskDictionaryForModel:model];
        if (task) {
            [tasks addObject:task];
        }
    }
    return tasks;
}

- (NSMutableArray<AnClickTaskModel *> *)mutableTasksFromSavedTasks:(NSArray *)tasks {
    NSMutableArray *result = [NSMutableArray array];
    for (id task in tasks) {
        AnClickTaskModel *model = nil;
        if ([task isKindOfClass:AnClickTaskModel.class]) {
            model = [task copy];
        } else if ([task isKindOfClass:NSDictionary.class]) {
            model = [[AnClickTaskModel alloc] initWithDictionary:task];
        }
        if (model) {
            [result addObject:model];
        }
    }
    return result;
}

- (NSString *)savedGlobalSettingsPath {
    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[documentsURL path] stringByAppendingPathComponent:@"anclick_global_settings.archive"];
}

- (NSDictionary *)currentGlobalSettingsDictionary {
    return @{
        @"delayMilliseconds": @0,
        @"runRepeatCount": @(_globalRunRepeatCount),
        @"loopIntervalSeconds": @(_globalLoopIntervalSeconds),
        @"startEnabled": @(_globalStartEnabled),
        @"stopEnabled": @(_globalStopEnabled),
        @"startHour": @(_globalStartHour),
        @"startMinute": @(_globalStartMinute),
        @"startSecond": @(_globalStartSecond),
        @"startMillisecond": @(_globalStartMillisecond),
        @"stopHour": @(_globalStopHour),
        @"stopMinute": @(_globalStopMinute),
        @"stopSecond": @(_globalStopSecond),
        @"stopMillisecond": @(_globalStopMillisecond),
        @"networkGateEnabled": @NO,
        @"networkURL": @"",
        @"networkContains": @"",
        @"networkFalse": @"",
    };
}

- (void)applyGlobalSettingsDictionary:(NSDictionary *)settings {
    if (![settings isKindOfClass:NSDictionary.class]) {
        return;
    }

    _globalDelayMilliseconds = 0;
    _globalRunRepeatCount = MIN(9999, MAX(0, [settings[@"runRepeatCount"] integerValue]));
    id loopIntervalValue = settings[@"loopIntervalSeconds"];
    if (![loopIntervalValue respondsToSelector:@selector(integerValue)]) {
        loopIntervalValue = settings[@"delayMilliseconds"];
        _globalLoopIntervalSeconds = [loopIntervalValue respondsToSelector:@selector(integerValue)]
            ? MIN(86400, MAX(0, [loopIntervalValue integerValue] / 1000))
            : 0;
    } else {
        _globalLoopIntervalSeconds = MIN(86400, MAX(0, [loopIntervalValue integerValue]));
    }
    _globalStartEnabled = [settings[@"startEnabled"] boolValue];
    _globalStopEnabled = [settings[@"stopEnabled"] boolValue];
    _globalStartHour = MIN(23, MAX(0, [settings[@"startHour"] integerValue]));
    _globalStartMinute = MIN(59, MAX(0, [settings[@"startMinute"] integerValue]));
    _globalStartSecond = MIN(59, MAX(0, [settings[@"startSecond"] integerValue]));
    _globalStartMillisecond = MIN(999, MAX(0, [settings[@"startMillisecond"] integerValue]));
    _globalStopHour = MIN(23, MAX(0, [settings[@"stopHour"] integerValue]));
    _globalStopMinute = MIN(59, MAX(0, [settings[@"stopMinute"] integerValue]));
    _globalStopSecond = MIN(59, MAX(0, [settings[@"stopSecond"] integerValue]));
    _globalStopMillisecond = MIN(999, MAX(0, [settings[@"stopMillisecond"] integerValue]));
    _globalNetworkGateEnabled = NO;
    _globalNetworkURL = nil;
    _globalNetworkContainsText = nil;
    _globalNetworkFalseText = nil;
}

- (void)loadGlobalSettings {
    NSString *path = [self savedGlobalSettingsPath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) {
        return;
    }

    NSError *error = nil;
    id object = [NSKeyedUnarchiver unarchivedObjectOfClasses:[self archiveAllowedClasses] fromData:data error:&error];
    if (error) {
        NSLog(@"[AnClick] Global settings unarchive failed: %@", error.localizedDescription);
        return;
    }
    if (![object isKindOfClass:NSDictionary.class]) {
        return;
    }

    [self applyGlobalSettingsDictionary:(NSDictionary *)object];
}

- (void)writeGlobalSettings {
    NSDictionary *settings = [[self currentGlobalSettingsDictionary] copy];
    NSString *path = [self savedGlobalSettingsPath];
    dispatch_async([self diskIOQueue], ^{
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:settings requiringSecureCoding:YES error:&error];
        if (!data || error) {
            NSLog(@"[AnClick] Global settings archive failed: %@", error.localizedDescription);
            return;
        }
        if (![data writeToFile:path atomically:YES]) {
            NSLog(@"[AnClick] Global settings write failed: %@", path);
        }
    });
}

- (void)persistGlobalSettings {
    [self writeGlobalSettings];
    [self scheduleGlobalTimers];
}

- (NSDate *)dateTodayWithHour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second millisecond:(NSInteger)millisecond {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[NSDate date]];
    components.hour = hour;
    components.minute = minute;
    components.second = second;
    components.nanosecond = MIN(999, MAX(0, millisecond)) * 1000000;
    NSDate *date = [calendar dateFromComponents:components];
    return date ? date : [NSDate date];
}

- (NSDate *)nextFireDateForHour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second millisecond:(NSInteger)millisecond {
    NSDate *date = [self dateTodayWithHour:hour minute:minute second:second millisecond:millisecond];
    if ([date timeIntervalSinceNow] <= 0.5) {
        date = [date dateByAddingTimeInterval:24.0 * 60.0 * 60.0];
    }
    return date;
}

- (void)scheduleGlobalTimers {
    [_globalStartTimer invalidate];
    [_globalStopTimer invalidate];
    _globalStartTimer = nil;
    _globalStopTimer = nil;

    if (_globalStartEnabled) {
        NSDate *startDate = [self nextFireDateForHour:_globalStartHour minute:_globalStartMinute second:_globalStartSecond millisecond:_globalStartMillisecond];
        _globalStartTimer = [[NSTimer alloc] initWithFireDate:startDate interval:0 target:self selector:@selector(handleGlobalStartTimer:) userInfo:nil repeats:NO];
        [NSRunLoop.mainRunLoop addTimer:_globalStartTimer forMode:NSRunLoopCommonModes];
    }
    if (_globalStopEnabled) {
        NSDate *stopDate = [self nextFireDateForHour:_globalStopHour minute:_globalStopMinute second:_globalStopSecond millisecond:_globalStopMillisecond];
        _globalStopTimer = [[NSTimer alloc] initWithFireDate:stopDate interval:0 target:self selector:@selector(handleGlobalStopTimer:) userInfo:nil repeats:NO];
        [NSRunLoop.mainRunLoop addTimer:_globalStopTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)handleGlobalStartTimer:(__unused NSTimer *)timer {
    _globalStartTimer = nil;
    [self scheduleGlobalTimers];
    if (!_taskRunActive && !_taskRunPausedForForeground) {
        [self startTaskListRunScheduled:YES];
    }
}

- (void)handleGlobalStopTimer:(__unused NSTimer *)timer {
    _globalStopTimer = nil;
    [self scheduleGlobalTimers];
    if (_taskRunActive || _taskRunPausedForForeground) {
        [self stopTaskRunWithStatus:@"定时停止"];
    }
}

- (NSString *)globalDelayFieldText {
    return _globalLoopIntervalSeconds > 0 ? [NSString stringWithFormat:@"%ld", (long)_globalLoopIntervalSeconds] : @"";
}

- (NSString *)globalRepeatFieldText {
    return _globalRunRepeatCount > 0 ? [NSString stringWithFormat:@"%ld", (long)_globalRunRepeatCount] : @"";
}

- (NSString *)globalTimeTitleEnabled:(BOOL)enabled hour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second millisecond:(NSInteger)millisecond {
    return enabled ? [NSString stringWithFormat:@"%02ld:%02ld:%02ld.%03ld", (long)hour, (long)minute, (long)second, (long)millisecond] : @"关闭";
}

- (UITextField *)globalSettingsTextFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [self configTextFieldWithPlaceholder:placeholder];
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 22, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    [self setStyledPlaceholder:placeholder forField:field alpha:0.72];
    [field addTarget:self action:@selector(globalSettingsFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [field addTarget:self action:@selector(globalSettingsFieldEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    return field;
}

- (UIButton *)globalSettingsValueButtonWithAction:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.55;
    button.titleLabel.lineBreakMode = NSLineBreakByClipping;
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 22, 0, 22);
    button.backgroundColor = [self themeControlFillColor];
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [self themeSeparatorColor].CGColor;
    [button setTitleColor:[self themePrimaryTextColor] forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UITextField *)globalSettingsNetworkTextFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [self configTextFieldWithPlaceholder:placeholder];
    field.keyboardType = UIKeyboardTypeURL;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    [self setStyledPlaceholder:placeholder forField:field alpha:0.72];
    [field addTarget:self action:@selector(globalSettingsFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [field addTarget:self action:@selector(globalSettingsFieldEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    return field;
}

- (void)refreshGlobalSettingsControls {
    if (_globalDelayField && !_globalDelayField.isFirstResponder) {
        _globalDelayField.text = [self globalDelayFieldText];
    }
    if (_globalRepeatField && !_globalRepeatField.isFirstResponder) {
        _globalRepeatField.text = [self globalRepeatFieldText];
    }
    [_globalStartTimeButton setTitle:[self globalTimeTitleEnabled:_globalStartEnabled hour:_globalStartHour minute:_globalStartMinute second:_globalStartSecond millisecond:_globalStartMillisecond] forState:UIControlStateNormal];
    [_globalStopTimeButton setTitle:[self globalTimeTitleEnabled:_globalStopEnabled hour:_globalStopHour minute:_globalStopMinute second:_globalStopSecond millisecond:_globalStopMillisecond] forState:UIControlStateNormal];
    _globalStartTimeButton.alpha = _globalStartEnabled ? 1.0 : 0.78;
    _globalStopTimeButton.alpha = _globalStopEnabled ? 1.0 : 0.78;
    [_globalNetworkGateButton setTitle:_globalNetworkGateEnabled ? @"开启" : @"关闭" forState:UIControlStateNormal];
    _globalNetworkGateButton.alpha = _globalNetworkGateEnabled ? 1.0 : 0.78;
    if (_globalNetworkURLField && !_globalNetworkURLField.isFirstResponder) {
        _globalNetworkURLField.text = _globalNetworkURL ?: @"";
    }
    if (_globalNetworkContainsField && !_globalNetworkContainsField.isFirstResponder) {
        _globalNetworkContainsField.text = _globalNetworkContainsText ?: @"";
    }
    if (_globalNetworkFalseField && !_globalNetworkFalseField.isFirstResponder) {
        _globalNetworkFalseField.text = _globalNetworkFalseText ?: @"";
    }
}

- (void)syncGlobalSettingsFromFields {
    if (_globalDelayField) {
        NSString *delayText = [_globalDelayField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        _globalLoopIntervalSeconds = delayText.length > 0 ? MIN(86400, MAX(0, delayText.integerValue)) : 0;
    }
    if (_globalRepeatField) {
        NSString *repeatText = [_globalRepeatField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        _globalRunRepeatCount = repeatText.length > 0 ? MIN(9999, MAX(0, repeatText.integerValue)) : 0;
    }
    if (_globalNetworkURLField) {
        _globalNetworkURL = [self trimmedActionDescription:_globalNetworkURLField.text];
    }
    if (_globalNetworkContainsField) {
        _globalNetworkContainsText = [self trimmedActionDescription:_globalNetworkContainsField.text];
    }
    if (_globalNetworkFalseField) {
        _globalNetworkFalseText = [self trimmedActionDescription:_globalNetworkFalseField.text];
    }
}

- (void)refreshGlobalSettingsFieldsIfNeeded {
    if (_globalDelayField && !_globalDelayField.isFirstResponder) {
        _globalDelayField.text = [self globalDelayFieldText];
    }
    if (_globalRepeatField && !_globalRepeatField.isFirstResponder) {
        _globalRepeatField.text = [self globalRepeatFieldText];
    }
    if (_globalNetworkURLField && !_globalNetworkURLField.isFirstResponder) {
        _globalNetworkURLField.text = _globalNetworkURL ?: @"";
    }
    if (_globalNetworkContainsField && !_globalNetworkContainsField.isFirstResponder) {
        _globalNetworkContainsField.text = _globalNetworkContainsText ?: @"";
    }
    if (_globalNetworkFalseField && !_globalNetworkFalseField.isFirstResponder) {
        _globalNetworkFalseField.text = _globalNetworkFalseText ?: @"";
    }
}

- (void)globalSettingsFieldChanged:(__unused UITextField *)textField {
    [self syncGlobalSettingsFromFields];
    [self persistGlobalSettings];
}

- (void)globalSettingsFieldEditingDidEnd:(__unused UITextField *)textField {
    [self syncGlobalSettingsFromFields];
    [self refreshGlobalSettingsFieldsIfNeeded];
    [self persistGlobalSettings];
}

- (void)toggleGlobalNetworkGate {
    [self syncGlobalSettingsFromFields];
    _globalNetworkGateEnabled = !_globalNetworkGateEnabled;
    [self refreshGlobalSettingsControls];
    [self persistGlobalSettings];
}

- (void)hideGlobalTimePicker {
    [_globalTimePickerView removeFromSuperview];
    _globalTimePickerView = nil;
    _globalTimePicker = nil;
}

- (void)hideGlobalSettings {
    if (_globalDelayField || _globalRepeatField || _globalNetworkURLField || _globalNetworkContainsField || _globalNetworkFalseField) {
        [self syncGlobalSettingsFromFields];
        [self persistGlobalSettings];
    }
    [_panelView endEditing:YES];
    [self hideGlobalTimePicker];
    [_globalSettingsView removeFromSuperview];
    _globalSettingsView = nil;
    _globalSettingsScrollView = nil;
    _globalDelayField = nil;
    _globalRepeatField = nil;
    _globalNetworkURLField = nil;
    _globalNetworkContainsField = nil;
    _globalNetworkFalseField = nil;
    _globalStartTimeButton = nil;
    _globalStopTimeButton = nil;
    _globalNetworkGateButton = nil;
}

- (void)openBilibiliProfile {
    NSURL *appURL = [NSURL URLWithString:@"bilibili://space/399301044"];
    NSURL *webURL = [NSURL URLWithString:@"https://b23.tv/fXw1dto"];
    if (!appURL && !webURL) {
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    void (^openWebURL)(void) = ^{
        if (webURL) {
            [application openURL:webURL options:@{} completionHandler:nil];
        }
    };
    if (!appURL) {
        openWebURL();
        return;
    }
    [application openURL:appURL options:@{} completionHandler:^(BOOL success) {
        if (!success) {
            openWebURL();
        }
    }];
}

- (void)scrollGlobalSettingsToControl:(UIView *)control focus:(BOOL)focus {
    if (!_globalSettingsScrollView || !control) {
        return;
    }
    CGRect rect = [control.superview convertRect:control.frame toView:_globalSettingsScrollView];
    rect = CGRectInset(rect, 0.0, -24.0);
    [_globalSettingsScrollView scrollRectToVisible:rect animated:YES];
    if (focus && [control respondsToSelector:@selector(becomeFirstResponder)]) {
        [control becomeFirstResponder];
    }
}

- (CGRect)homeFloatingPanelFrameForHeight:(CGFloat)preferredHeight {
    (void)preferredHeight;
    return _panelView.bounds;
}

- (void)layoutHomeFloatingPanel:(UIView *)panel preferredHeight:(CGFloat)preferredHeight {
    if (!panel) {
        return;
    }
    panel.frame = [self homeFloatingPanelFrameForHeight:preferredHeight];
}

- (CGFloat)homeFloatingPanelPreferredHeightForTag:(NSInteger)tag fallback:(CGFloat)fallback {
    if (tag == AnClickHomeOptionPanelTimeTag) {
        return 352.0;
    }
    if (tag == AnClickHomeOptionPanelLoopTag) {
        return 344.0;
    }
    if (tag == AnClickHomeOptionPanelSaveTag) {
        return 336.0;
    }
    if (tag == AnClickHomeOptionPanelMonitorTag) {
        return 392.0;
    }
    return fallback;
}

- (UIView *)showHomeOptionPanelWithTitle:(NSString *)title preferredHeight:(CGFloat)preferredHeight tag:(NSInteger)tag {
    [self dismissKeyboard];
    [self hideFunctionMenu];
    [self hideGlobalSettings];

    _globalSettingsView = [[UIView alloc] initWithFrame:_panelView.bounds];
    _globalSettingsView.tag = tag;
    [self installDarkBlurInView:_globalSettingsView cornerRadius:_panelView.layer.cornerRadius];
    _globalSettingsView.layer.cornerRadius = _panelView.layer.cornerRadius;
    _globalSettingsView.layer.borderWidth = 0.0;
    _globalSettingsView.layer.shadowOpacity = 0.0;
    _globalSettingsView.clipsToBounds = YES;
    [_panelView addSubview:_globalSettingsView];

    CGFloat width = _globalSettingsView.bounds.size.width;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(54.0, 13.0, width - 108.0, 34.0)];
    titleLabel.text = title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [self themePrimaryTextColor];
    titleLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightBold];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.68;
    [_globalSettingsView addSubview:titleLabel];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(width - 52.0, 10.0, 40.0, 40.0);
    closeButton.layer.cornerRadius = 20.0;
    closeButton.titleLabel.font = [UIFont systemFontOfSize:27.0 weight:UIFontWeightBold];
    [closeButton setTitle:@"×" forState:UIControlStateNormal];
    [self applyFrostedRoundButtonStyle:closeButton];
    [closeButton addTarget:self action:@selector(hideGlobalSettings) forControlEvents:UIControlEventTouchUpInside];
    [_globalSettingsView addSubview:closeButton];

    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(0.0, 60.0, width, 1.0)];
    divider.backgroundColor = [self themeSeparatorColor];
    [_globalSettingsView addSubview:divider];

    return _globalSettingsView;
}

- (UILabel *)homeOptionCaptionWithText:(NSString *)text frame:(CGRect)frame {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.textColor = [self themeSecondaryTextColor];
    label.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    return label;
}

- (UIView *)homeOptionCardWithFrame:(CGRect)frame {
    UIView *card = [[UIView alloc] initWithFrame:frame];
    card.backgroundColor = [self themeSurfaceColor];
    card.layer.cornerRadius = 10.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [self themeSeparatorColor].CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = 0.10;
    card.layer.shadowRadius = 8.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    return card;
}

- (void)addHomeTimeRowToCard:(UIView *)card title:(NSString *)title detail:(NSString *)detail button:(UIButton *)button y:(CGFloat)y {
    CGFloat width = card.bounds.size.width;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14.0, y, width - 28.0, 22.0)];
    titleLabel.text = title;
    titleLabel.textColor = [self themePrimaryTextColor];
    titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
    titleLabel.numberOfLines = 1;
    [card addSubview:titleLabel];

    UILabel *detailLabel = [[UILabel alloc] initWithFrame:CGRectMake(14.0, y + 24.0, width - 28.0, 34.0)];
    detailLabel.text = detail;
    detailLabel.textColor = [self themeSecondaryTextColor];
    detailLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    detailLabel.numberOfLines = 0;
    detailLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [card addSubview:detailLabel];

    button.frame = CGRectMake(14.0, y + 62.0, width - 28.0, 46.0);
    [card addSubview:button];
}

- (void)showHomeTimeSettings {
    UIView *panel = [self showHomeOptionPanelWithTitle:@"定时设置" preferredHeight:352.0 tag:AnClickHomeOptionPanelTimeTag];
    CGFloat width = panel.bounds.size.width;
    CGFloat side = 14.0;
    CGFloat contentWidth = width - side * 2.0;

    UILabel *caption = [self homeOptionCaptionWithText:@"只设置任务列表的定时运行和定时结束，精确到毫秒。"
                                                 frame:CGRectMake(side, 62.0, contentWidth, 30.0)];
    [panel addSubview:caption];

    UIView *card = [self homeOptionCardWithFrame:CGRectMake(side, 98.0, contentWidth, 248.0)];
    [panel addSubview:card];

    _globalStartTimeButton = [self globalSettingsValueButtonWithAction:@selector(showGlobalStartTimePicker)];
    _globalStopTimeButton = [self globalSettingsValueButtonWithAction:@selector(showGlobalStopTimePicker)];
    [self addHomeTimeRowToCard:card
                         title:@"定时运行"
                        detail:@"到达设置时间后自动开始运行任务列表"
                        button:_globalStartTimeButton
                             y:14.0];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14.0, 125.0, contentWidth - 28.0, 1.0)];
    line.backgroundColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.72];
    [card addSubview:line];
    [self addHomeTimeRowToCard:card
                        title:@"定时结束"
                        detail:@"到达设置时间后停止当前任务运行"
                        button:_globalStopTimeButton
                             y:138.0];
    [self refreshGlobalSettingsControls];
}

- (void)showHomeLoopSettings {
    UIView *panel = [self showHomeOptionPanelWithTitle:@"循环设置" preferredHeight:344.0 tag:AnClickHomeOptionPanelLoopTag];
    CGFloat width = panel.bounds.size.width;
    CGFloat side = 14.0;
    CGFloat contentWidth = width - side * 2.0;

    UILabel *caption = [self homeOptionCaptionWithText:@"设置整个任务列表循环次数和每轮循环之间的等待时间。次数填 0 或留空表示无限循环。"
                                                 frame:CGRectMake(side, 62.0, contentWidth, 48.0)];
    [panel addSubview:caption];

    UIView *card = [self homeOptionCardWithFrame:CGRectMake(side, 116.0, contentWidth, 168.0)];
    [panel addSubview:card];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14.0, 16.0, contentWidth - 28.0, 22.0)];
    titleLabel.text = @"任务列表循环次数";
    titleLabel.textColor = [self themePrimaryTextColor];
    titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
    [card addSubview:titleLabel];

    _globalRepeatField = [self globalSettingsTextFieldWithPlaceholder:@"无限循环"];
    _globalRepeatField.frame = CGRectMake(14.0, 52.0, contentWidth - 28.0, 50.0);
    [card addSubview:_globalRepeatField];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14.0, 116.0, contentWidth - 28.0, 1.0)];
    line.backgroundColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.72];
    [card addSubview:line];

    UILabel *intervalLabel = [[UILabel alloc] initWithFrame:CGRectMake(14.0, 128.0, floor((contentWidth - 42.0) * 0.46), 28.0)];
    intervalLabel.text = @"循环间隔";
    intervalLabel.textColor = [self themePrimaryTextColor];
    intervalLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
    [card addSubview:intervalLabel];

    _globalDelayField = [self globalSettingsTextFieldWithPlaceholder:@"0"];
    _globalDelayField.frame = CGRectMake(CGRectGetMaxX(intervalLabel.frame) + 8.0,
                                         124.0,
                                         contentWidth - CGRectGetMaxX(intervalLabel.frame) - 30.0,
                                         36.0);
    _globalDelayField.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
    _globalDelayField.textAlignment = NSTextAlignmentRight;
    [card addSubview:_globalDelayField];

    UILabel *unitLabel = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMaxX(_globalDelayField.frame) + 4.0, 128.0, 18.0, 28.0)];
    unitLabel.text = @"秒";
    unitLabel.textColor = [self themeSecondaryTextColor];
    unitLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [card addSubview:unitLabel];

    UIButton *doneButton = [self configPromptButtonWithTitle:@"完成" action:@selector(hideGlobalSettings) destructive:NO];
    doneButton.frame = CGRectMake(side, CGRectGetMaxY(card.frame) + 14.0, contentWidth, 42.0);
    [self applyObsidian3DStyleToButton:doneButton selected:YES];
    [panel addSubview:doneButton];

    [self refreshGlobalSettingsControls];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_globalRepeatField becomeFirstResponder];
    });
}

- (void)showHomeMonitorSettings {
    UIView *panel = [self showHomeOptionPanelWithTitle:@"网络监控" preferredHeight:392.0 tag:AnClickHomeOptionPanelMonitorTag];
    CGFloat width = panel.bounds.size.width;
    CGFloat side = 14.0;
    CGFloat contentWidth = width - side * 2.0;

    UILabel *caption = [self homeOptionCaptionWithText:@"运行前先监控接口。命中运行条件后开始任务列表，命中不运行条件则继续等待。"
                                                 frame:CGRectMake(side, 62.0, contentWidth, 46.0)];
    [panel addSubview:caption];

    UIView *card = [self homeOptionCardWithFrame:CGRectMake(side, 112.0, contentWidth, 214.0)];
    [panel addSubview:card];

    UILabel *gateLabel = [[UILabel alloc] initWithFrame:CGRectMake(14.0, 14.0, floor((contentWidth - 42.0) * 0.52), 36.0)];
    gateLabel.text = @"全局网络监控";
    gateLabel.textColor = [self themePrimaryTextColor];
    gateLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
    [card addSubview:gateLabel];

    _globalNetworkGateButton = [self globalSettingsValueButtonWithAction:@selector(toggleGlobalNetworkGate)];
    _globalNetworkGateButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    _globalNetworkGateButton.titleEdgeInsets = UIEdgeInsetsZero;
    _globalNetworkGateButton.frame = CGRectMake(CGRectGetMaxX(gateLabel.frame) + 8.0,
                                                10.0,
                                                contentWidth - CGRectGetMaxX(gateLabel.frame) - 30.0,
                                                42.0);
    [card addSubview:_globalNetworkGateButton];

    UIView *line0 = [[UIView alloc] initWithFrame:CGRectMake(14.0, 62.0, contentWidth - 28.0, 1.0)];
    line0.backgroundColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.72];
    [card addSubview:line0];

    _globalNetworkURLField = [self globalSettingsNetworkTextFieldWithPlaceholder:@"https://example.com/check"];
    _globalNetworkURLField.frame = CGRectMake(14.0, 76.0, contentWidth - 28.0, 40.0);
    [card addSubview:_globalNetworkURLField];

    _globalNetworkContainsField = [self globalSettingsNetworkTextFieldWithPlaceholder:@"命中运行内容，可留空"];
    _globalNetworkContainsField.keyboardType = UIKeyboardTypeDefault;
    _globalNetworkContainsField.frame = CGRectMake(14.0, 126.0, floor((contentWidth - 36.0) * 0.5), 40.0);
    [card addSubview:_globalNetworkContainsField];

    _globalNetworkFalseField = [self globalSettingsNetworkTextFieldWithPlaceholder:@"命中不运行内容"];
    _globalNetworkFalseField.keyboardType = UIKeyboardTypeDefault;
    _globalNetworkFalseField.frame = CGRectMake(CGRectGetMaxX(_globalNetworkContainsField.frame) + 8.0,
                                                126.0,
                                                contentWidth - CGRectGetMaxX(_globalNetworkContainsField.frame) - 30.0,
                                                40.0);
    [card addSubview:_globalNetworkFalseField];

    UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(14.0, 174.0, contentWidth - 28.0, 28.0)];
    hintLabel.text = @"运行内容为空时，请求成功且未命中不运行内容也会启动任务。";
    hintLabel.textColor = [self themeSecondaryTextColor];
    hintLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    hintLabel.numberOfLines = 2;
    [card addSubview:hintLabel];

    UIButton *doneButton = [self configPromptButtonWithTitle:@"完成" action:@selector(hideGlobalSettings) destructive:NO];
    doneButton.frame = CGRectMake(side, CGRectGetMaxY(card.frame) + 14.0, contentWidth, 42.0);
    [self applyObsidian3DStyleToButton:doneButton selected:YES];
    [panel addSubview:doneButton];

    [self refreshGlobalSettingsControls];
    if (_globalNetworkURL.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_globalNetworkURLField becomeFirstResponder];
        });
    }
}

- (void)showHomeSaveConfigMenu {
    [self showFunctionMenu];
}

- (void)showGlobalSettings {
    [self showHomeMonitorSettings];
}

- (void)showGlobalStartTimePicker {
    [self showGlobalTimePickerForStart:YES];
}

- (void)showGlobalStopTimePicker {
    [self showGlobalTimePickerForStart:NO];
}

- (NSDate *)defaultGlobalTimePickerDateForStart:(BOOL)startTime {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute fromDate:[NSDate date]];
    components.second = 0;
    NSDate *currentMinute = [calendar dateFromComponents:components] ?: [NSDate date];
    return [currentMinute dateByAddingTimeInterval:(startTime ? 60.0 : 120.0)];
}

- (NSInteger)globalTimePickerRowCountForComponent:(NSInteger)component {
    if (component == 0) {
        return 24;
    }
    if (component == 1 || component == 2) {
        return 60;
    }
    if (component == 3) {
        return 1000;
    }
    return 0;
}

- (NSString *)globalTimePickerUnitForComponent:(NSInteger)component {
    if (component == 0) {
        return @"时";
    }
    if (component == 1) {
        return @"分";
    }
    if (component == 2) {
        return @"秒";
    }
    if (component == 3) {
        return @"毫秒";
    }
    return @"";
}

- (NSInteger)globalTimePickerSelectedValueForComponent:(NSInteger)component {
    NSInteger rows = [self globalTimePickerRowCountForComponent:component];
    if (!_globalTimePicker || rows <= 0) {
        return 0;
    }
    return MIN(rows - 1, MAX(0, [_globalTimePicker selectedRowInComponent:component]));
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return pickerView == _globalTimePicker ? 4 : 0;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return pickerView == _globalTimePicker ? [self globalTimePickerRowCountForComponent:component] : 0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (pickerView != _globalTimePicker) {
        return @"";
    }
    NSString *number = component == 3
        ? [NSString stringWithFormat:@"%03ld", (long)row]
        : [NSString stringWithFormat:@"%02ld", (long)row];
    return [NSString stringWithFormat:@"%@ %@", number, [self globalTimePickerUnitForComponent:component]];
}

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSString *title = [self pickerView:pickerView titleForRow:row forComponent:component];
    return [[NSAttributedString alloc] initWithString:title
                                          attributes:@{
                                              NSForegroundColorAttributeName: [self themePrimaryTextColor],
                                              NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:20 weight:UIFontWeightSemibold]
                                          }];
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return pickerView == _globalTimePicker ? 34.0 : 0.0;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    if (pickerView != _globalTimePicker || component < 0 || component > 3) {
        return 0.0;
    }
    return floor((pickerView.bounds.size.width - 18.0) / 4.0);
}

- (void)showGlobalTimePickerForStart:(BOOL)startTime {
    if (!_globalSettingsView) {
        return;
    }
    [self dismissKeyboard];
    [self hideGlobalTimePicker];
    _globalTimePickerEditingStartTime = startTime;

    UIView *overlay = [[UIView alloc] initWithFrame:_globalSettingsView.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.42];
    [_globalSettingsView addSubview:overlay];
    _globalTimePickerView = overlay;

    CGFloat width = overlay.bounds.size.width;
    CGFloat height = overlay.bounds.size.height;
    CGFloat cardHeight = MIN(396.0, height - 32.0);
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, MAX(40.0, (height - cardHeight) * 0.5), width, cardHeight)];
    card.backgroundColor = [self themeSurfaceColor];
    card.layer.cornerRadius = 22;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [self themeSeparatorColor].CGColor;
    card.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        card.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    }
    [overlay addSubview:card];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 20, width - 32, 34)];
    titleLabel.text = [NSString stringWithFormat:@"%@ %@", [self toolDisplayName], startTime ? @"启动时间" : @"停止时间"];
    titleLabel.textColor = [self themePrimaryTextColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.68;
    [card addSubview:titleLabel];

    CGFloat buttonY = cardHeight - 66.0;
    CGFloat pickerY = 68.0;
    CGFloat pickerHeight = MAX(150.0, buttonY - pickerY - 18.0);
    _globalTimePicker = [[UIPickerView alloc] initWithFrame:CGRectMake(10.0, pickerY, width - 20.0, pickerHeight)];
    _globalTimePicker.dataSource = self;
    _globalTimePicker.delegate = self;
    if (@available(iOS 13.0, *)) {
        _globalTimePicker.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    }
    [card addSubview:_globalTimePicker];
    BOOL hasStoredTime = startTime ? _globalStartEnabled : _globalStopEnabled;
    NSInteger hour = startTime ? _globalStartHour : _globalStopHour;
    NSInteger minute = startTime ? _globalStartMinute : _globalStopMinute;
    NSInteger second = startTime ? _globalStartSecond : _globalStopSecond;
    NSInteger millisecond = startTime ? _globalStartMillisecond : _globalStopMillisecond;
    if (!hasStoredTime) {
        NSDate *defaultDate = [self defaultGlobalTimePickerDateForStart:startTime];
        NSDateComponents *defaultComponents = [NSCalendar.currentCalendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitNanosecond fromDate:defaultDate];
        hour = defaultComponents.hour;
        minute = defaultComponents.minute;
        second = defaultComponents.second;
        millisecond = defaultComponents.nanosecond / 1000000;
    }
    [_globalTimePicker selectRow:MIN(23, MAX(0, hour)) inComponent:0 animated:NO];
    [_globalTimePicker selectRow:MIN(59, MAX(0, minute)) inComponent:1 animated:NO];
    [_globalTimePicker selectRow:MIN(59, MAX(0, second)) inComponent:2 animated:NO];
    [_globalTimePicker selectRow:MIN(999, MAX(0, millisecond)) inComponent:3 animated:NO];

    CGFloat buttonWidth = width / 3.0;
    NSArray<NSString *> *titles = @[@"关闭", @"取消", @"确定"];
    NSArray<NSString *> *selectors = @[@"disableGlobalPickedTime", @"cancelGlobalTimePicker", @"confirmGlobalTimePicker"];
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(buttonWidth * i, buttonY, buttonWidth, 66.0);
        button.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:(i == 2 ? [self themeHighlightColor] : [self themeSecondaryTextColor]) forState:UIControlStateNormal];
        [button addTarget:self action:NSSelectorFromString(selectors[i]) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:button];
        if (i > 0) {
            UIView *line = [[UIView alloc] initWithFrame:CGRectMake(buttonWidth * i, buttonY, 1, 66.0)];
            line.backgroundColor = [self themeSeparatorColor];
            [card addSubview:line];
        }
    }
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, buttonY, width, 1)];
    topLine.backgroundColor = [self themeSeparatorColor];
    [card addSubview:topLine];
}

- (void)disableGlobalPickedTime {
    if (_globalTimePickerEditingStartTime) {
        _globalStartEnabled = NO;
    } else {
        _globalStopEnabled = NO;
    }
    [self hideGlobalTimePicker];
    [self refreshGlobalSettingsControls];
    [self persistGlobalSettings];
}

- (void)cancelGlobalTimePicker {
    [self hideGlobalTimePicker];
}

- (void)confirmGlobalTimePicker {
    NSInteger hour = [self globalTimePickerSelectedValueForComponent:0];
    NSInteger minute = [self globalTimePickerSelectedValueForComponent:1];
    NSInteger second = [self globalTimePickerSelectedValueForComponent:2];
    NSInteger millisecond = [self globalTimePickerSelectedValueForComponent:3];
    if (_globalTimePickerEditingStartTime) {
        _globalStartEnabled = YES;
        _globalStartHour = hour;
        _globalStartMinute = minute;
        _globalStartSecond = second;
        _globalStartMillisecond = millisecond;
    } else {
        _globalStopEnabled = YES;
        _globalStopHour = hour;
        _globalStopMinute = minute;
        _globalStopSecond = second;
        _globalStopMillisecond = millisecond;
    }
    [self hideGlobalTimePicker];
    [self refreshGlobalSettingsControls];
    [self persistGlobalSettings];
}

- (void)hideFunctionMenu {
    [self hideConfigPrompt];
    [_functionMenuView removeFromSuperview];
    _functionMenuView = nil;
    _configListView = nil;
    _configListDeleting = NO;
}

- (UIButton *)functionMenuRowWithTitle:(NSString *)title subtitle:(NSString *)subtitle color:(UIColor *)color action:(SEL)action tag:(NSInteger)tag {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = tag;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.65;
    NSString *text = subtitle.length > 0 ? [NSString stringWithFormat:@"%@\n%@", title, subtitle] : title;
    NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:text];
    [attributed addAttribute:NSForegroundColorAttributeName value:[self themePrimaryTextColor] range:NSMakeRange(0, title.length)];
    [attributed addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold] range:NSMakeRange(0, title.length)];
    if (subtitle.length > 0) {
        NSRange subtitleRange = NSMakeRange(title.length + 1, subtitle.length);
        [attributed addAttribute:NSForegroundColorAttributeName value:[self themeSecondaryTextColor] range:subtitleRange];
        [attributed addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:13 weight:UIFontWeightMedium] range:subtitleRange];
    }
    [button setAttributedTitle:attributed forState:UIControlStateNormal];
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 34);
    button.backgroundColor = color;
    button.layer.cornerRadius = 10;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.82].CGColor;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOffset = CGSizeMake(0, 1);
    button.layer.shadowRadius = 3.0;
    button.layer.shadowOpacity = 0.035;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UILabel *chevron = [[UILabel alloc] initWithFrame:CGRectZero];
    chevron.tag = 9001;
    chevron.text = @">";
    chevron.textColor = [self themeHighlightColor];
    chevron.font = [UIFont systemFontOfSize:30 weight:UIFontWeightSemibold];
    chevron.textAlignment = NSTextAlignmentCenter;
    chevron.userInteractionEnabled = NO;
    [button addSubview:chevron];
    return button;
}

- (void)layoutFunctionMenuRows:(NSArray<UIButton *> *)rows startY:(CGFloat)startY {
    CGFloat side = 14.0;
    CGFloat width = _functionMenuView.bounds.size.width - side * 2.0;
    CGFloat rowHeight = 68.0;
    CGFloat gap = 12.0;
    for (NSUInteger i = 0; i < rows.count; i++) {
        UIButton *row = rows[i];
        row.frame = CGRectMake(side, startY + (rowHeight + gap) * i, width, rowHeight);
        UILabel *chevron = (UILabel *)[row viewWithTag:9001];
        chevron.frame = CGRectMake(width - 44.0, 0, 34.0, rowHeight);
        [self updateButtonShadowPath:row];
    }
}

- (void)showFunctionMenu {
    [self dismissKeyboard];
    [self hideGlobalSettings];
    [self hideFunctionMenu];

    _functionMenuView = [[UIView alloc] initWithFrame:_panelView.bounds];
    _functionMenuView.tag = AnClickHomeOptionPanelSaveTag;
    _configListDeleting = NO;
    [self installDarkBlurInView:_functionMenuView cornerRadius:_panelView.layer.cornerRadius];
    _functionMenuView.layer.cornerRadius = _panelView.layer.cornerRadius;
    _functionMenuView.layer.borderWidth = 0.0;
    _functionMenuView.layer.shadowOpacity = 0.0;
    _functionMenuView.clipsToBounds = YES;
    [_panelView addSubview:_functionMenuView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(54, 14, _functionMenuView.bounds.size.width - 108, 34)];
    titleLabel.text = @"任务配置";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [self themePrimaryTextColor];
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.68;
    [_functionMenuView addSubview:titleLabel];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(_functionMenuView.bounds.size.width - 54, 10, 40, 40);
    closeButton.layer.cornerRadius = 20;
    closeButton.titleLabel.font = [UIFont systemFontOfSize:27 weight:UIFontWeightBold];
    [closeButton setTitle:@"×" forState:UIControlStateNormal];
    [self applyFrostedRoundButtonStyle:closeButton];
    [closeButton addTarget:self action:@selector(hideFunctionMenu) forControlEvents:UIControlEventTouchUpInside];
    [_functionMenuView addSubview:closeButton];

    UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(18, 70, _functionMenuView.bounds.size.width - 36, 22)];
    caption.text = @"保存 / 导入 / 删除";
    caption.textColor = [self themeSecondaryTextColor];
    caption.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [_functionMenuView addSubview:caption];

    UIButton *saveRow = [self functionMenuRowWithTitle:@"保存当前任务列表"
                                             subtitle:@"可自定义名字保存任务和设置"
                                                color:[self themeSurfaceColor]
                                               action:@selector(saveCurrentTaskConfig)
                                                  tag:0];
    UIButton *chooseRow = [self functionMenuRowWithTitle:@"选择任务配置"
                                               subtitle:@"加载已保存的任务列表"
                                                  color:[self themeSurfaceColor]
                                                 action:@selector(showSavedConfigChooser)
                                                    tag:0];
    UIButton *deleteRow = [self functionMenuRowWithTitle:@"删除任务配置"
                                               subtitle:@"删除前会再次确认"
                                                  color:[self themeSurfaceColor]
                                                 action:@selector(showSavedConfigDeleter)
                                                    tag:0];
    [_functionMenuView addSubview:saveRow];
    [_functionMenuView addSubview:chooseRow];
    [_functionMenuView addSubview:deleteRow];
    [self layoutFunctionMenuRows:@[saveRow, chooseRow, deleteRow] startY:108.0];
}

- (NSString *)defaultTaskConfigName {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MM-dd HH:mm";
    return [NSString stringWithFormat:@"配置 %@  %lu项", [formatter stringFromDate:[NSDate date]], (unsigned long)_taskItems.count];
}

- (UIButton *)configPromptButtonWithTitle:(NSString *)title action:(SEL)action destructive:(BOOL)destructive {
    UIButton *button = [self panelButtonWithTitle:title action:action];
    if (destructive) {
        button.backgroundColor = [self themeDangerColor];
        button.layer.borderColor = [[self themeDangerColor] colorWithAlphaComponent:0.85].CGColor;
        button.layer.shadowColor = UIColor.blackColor.CGColor;
        button.layer.shadowOffset = CGSizeMake(0, 2);
        button.layer.shadowRadius = 4.0;
        button.layer.shadowOpacity = 0.12;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.tintColor = UIColor.whiteColor;
    }
    return button;
}

- (void)hideConfigPrompt {
    [_configNameField resignFirstResponder];
    [_configPromptView removeFromSuperview];
    _configPromptView = nil;
    _configNameField = nil;
    _pendingConfigDeleteIndex = -1;
}

- (UIView *)showConfigPromptBaseWithTitle:(NSString *)title message:(NSString *)message {
    if (!_functionMenuView) {
        [self showFunctionMenu];
    }
    [self hideConfigPrompt];

    UIView *overlay = [[UIView alloc] initWithFrame:_functionMenuView.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.66];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_functionMenuView addSubview:overlay];
    _configPromptView = overlay;

    CGFloat side = 18.0;
    CGFloat width = overlay.bounds.size.width - side * 2.0;
    CGFloat cardHeight = 236.0;
    CGFloat cardY = MAX(70.0, (overlay.bounds.size.height - cardHeight) * 0.42);
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(side, cardY, width, cardHeight)];
    card.backgroundColor = [self themeSurfaceColor];
    card.layer.cornerRadius = 12;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [self themeSeparatorColor].CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = 0.18;
    card.layer.shadowRadius = 14.0;
    card.layer.shadowOffset = CGSizeMake(0, 8);
    [overlay addSubview:card];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, width - 32, 28)];
    titleLabel.text = title;
    titleLabel.textColor = [self themePrimaryTextColor];
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.72;
    [card addSubview:titleLabel];

    UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 48, width - 32, 44)];
    messageLabel.text = message;
    messageLabel.textColor = [self themeSecondaryTextColor];
    messageLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    messageLabel.numberOfLines = 2;
    [card addSubview:messageLabel];

    return card;
}

- (void)showSaveTaskConfigNamePrompt {
    if (_taskItems.count == 0) {
        [self hideFunctionMenu];
        return;
    }

    NSString *defaultName = [self defaultTaskConfigName];
    UIView *card = [self showConfigPromptBaseWithTitle:@"保存配置" message:@"可以修改保存配置名字，方便下次选择。"];
    CGFloat width = card.bounds.size.width;
    _configNameField = [[UITextField alloc] initWithFrame:CGRectMake(16, 98, width - 32, 42)];
    _configNameField.text = defaultName;
    _configNameField.returnKeyType = UIReturnKeyDone;
    [self applyObsidianInputStyleToField:_configNameField placeholder:@"配置名称" monospaced:NO];
    [self configureConfigTextField:_configNameField];
    [card addSubview:_configNameField];

    CGFloat buttonY = CGRectGetMaxY(_configNameField.frame) + 20.0;
    CGFloat gap = 12.0;
    CGFloat buttonWidth = floor((width - 32.0 - gap) / 2.0);
    UIButton *cancelButton = [self configPromptButtonWithTitle:@"取消" action:@selector(hideConfigPrompt) destructive:NO];
    cancelButton.frame = CGRectMake(16, buttonY, buttonWidth, 42);
    [card addSubview:cancelButton];

    UIButton *saveButton = [self configPromptButtonWithTitle:@"保存" action:@selector(confirmSaveCurrentTaskConfig) destructive:NO];
    saveButton.frame = CGRectMake(16 + buttonWidth + gap, buttonY, buttonWidth, 42);
    [self applyObsidian3DStyleToButton:saveButton selected:YES];
    [card addSubview:saveButton];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_configNameField becomeFirstResponder];
        [self->_configNameField selectAll:nil];
    });
}

- (NSString *)trimmedConfigNameFromField {
    NSString *name = [_configNameField.text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return name.length > 0 ? name : [self defaultTaskConfigName];
}

- (void)confirmSaveCurrentTaskConfig {
    NSMutableArray *configs = [self savedTaskConfigs];
    NSString *name = [self trimmedConfigNameFromField];
    NSMutableDictionary *config = [@{
        @"name": name,
        @"createdAt": @([NSDate date].timeIntervalSince1970),
        @"tasks": [self copyTaskItemsForSaving],
        @"globalSettings": [self currentGlobalSettingsDictionary],
    } mutableCopy];
    [configs insertObject:config atIndex:0];
    [self writeSavedTaskConfigs:configs];
    [self hideFunctionMenu];
    _statusLabel.text = @"";
}

- (void)saveCurrentTaskConfig {
    [self showSaveTaskConfigNamePrompt];
}

- (void)showSavedConfigChooser {
    [self showSavedConfigListForDeleting:NO];
}

- (void)showSavedConfigDeleter {
    [self showSavedConfigListForDeleting:YES];
}

- (void)showSavedConfigListForDeleting:(BOOL)deleting {
    [self showSavedConfigListForDeleting:deleting configsOverride:nil];
}

- (void)showSavedConfigListForDeleting:(BOOL)deleting configsOverride:(NSArray *)configsOverride {
    if (!_functionMenuView) {
        [self showFunctionMenu];
    }
    _configListDeleting = deleting;
    for (UIView *view in [_functionMenuView.subviews copy]) {
        if (view.tag != AnClickBackdropBlurViewTag) {
            [view removeFromSuperview];
        }
    }

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 14, _functionMenuView.bounds.size.width - 76, 34)];
    titleLabel.text = [NSString stringWithFormat:@"%@ %@", [self toolDisplayName], deleting ? @"删除配置" : @"选择配置"];
    titleLabel.textColor = [self themePrimaryTextColor];
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.68;
    [_functionMenuView addSubview:titleLabel];

    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    backButton.frame = CGRectMake(_functionMenuView.bounds.size.width - 54, 10, 40, 40);
    backButton.layer.cornerRadius = 20;
    backButton.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    [backButton setTitle:@"×" forState:UIControlStateNormal];
    [self applyFrostedRoundButtonStyle:backButton];
    [backButton addTarget:self action:@selector(showFunctionMenu) forControlEvents:UIControlEventTouchUpInside];
    [_functionMenuView addSubview:backButton];

    _configListView = [[UIScrollView alloc] initWithFrame:CGRectMake(12, 66, _functionMenuView.bounds.size.width - 24, _functionMenuView.bounds.size.height - 78)];
    _configListView.backgroundColor = UIColor.clearColor;
    [_functionMenuView addSubview:_configListView];

    NSArray *configs = configsOverride ?: [self savedTaskConfigs];
    if (configs.count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, _configListView.bounds.size.width - 20, 60)];
        empty.text = @"暂无已保存配置";
        empty.textColor = [self themeSecondaryTextColor];
        empty.textAlignment = NSTextAlignmentCenter;
        empty.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        [_configListView addSubview:empty];
        return;
    }

    CGFloat rowHeight = 62.0;
    for (NSUInteger i = 0; i < configs.count; i++) {
        NSDictionary *config = configs[i];
        NSString *name = [config[@"name"] isKindOfClass:NSString.class] ? config[@"name"] : [NSString stringWithFormat:@"配置%lu", (unsigned long)i + 1];
        NSArray *tasks = [config[@"tasks"] isKindOfClass:NSArray.class] ? config[@"tasks"] : @[];
        UIButton *row = [self functionMenuRowWithTitle:name
                                              subtitle:[NSString stringWithFormat:@"%lu 个任务", (unsigned long)tasks.count]
                                                 color:deleting ? [[UIColor systemRedColor] colorWithAlphaComponent:0.10] : [self themeSurfaceColor]
                                                action:deleting ? @selector(deleteSavedConfigButton:) : @selector(loadSavedConfigButton:)
                                                   tag:(NSInteger)i];
        row.frame = CGRectMake(0, 4.0 + (rowHeight + 10.0) * i, _configListView.bounds.size.width, rowHeight);
        UILabel *chevron = (UILabel *)[row viewWithTag:9001];
        chevron.frame = CGRectMake(_configListView.bounds.size.width - 44.0, 0, 34.0, rowHeight);
        [_configListView addSubview:row];
    }
    _configListView.contentSize = CGSizeMake(_configListView.bounds.size.width, 12.0 + (rowHeight + 10.0) * configs.count);
}

- (void)loadSavedConfigButton:(UIButton *)sender {
    NSArray *configs = [self savedTaskConfigs];
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)configs.count) {
        _statusLabel.text = @"配置不存在";
        return;
    }

    NSDictionary *config = configs[(NSUInteger)index];
    NSArray *tasks = [config[@"tasks"] isKindOfClass:NSArray.class] ? config[@"tasks"] : @[];
    _taskItems = [self mutableTasksFromSavedTasks:tasks];
    NSDictionary *globalSettings = [config[@"globalSettings"] isKindOfClass:NSDictionary.class] ? config[@"globalSettings"] : nil;
    if (globalSettings) {
        [self applyGlobalSettingsDictionary:globalSettings];
        [self persistGlobalSettings];
    }
    _selectedTaskIndex = -1;
    [self resetCurrentActionConfiguration];
    [self hideFunctionMenu];
    [self showTaskHome];
    [self persistCurrentTaskList];
    _statusLabel.text = @"";
}

- (void)deleteSavedConfigButton:(UIButton *)sender {
    NSMutableArray *configs = [self savedTaskConfigs];
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)configs.count) {
        _statusLabel.text = @"配置不存在";
        return;
    }

    NSDictionary *config = configs[(NSUInteger)index];
    NSString *name = [config[@"name"] isKindOfClass:NSString.class] ? config[@"name"] : [NSString stringWithFormat:@"配置%lu", (unsigned long)index + 1];
    NSArray *tasks = [config[@"tasks"] isKindOfClass:NSArray.class] ? config[@"tasks"] : @[];
    [self showDeleteSavedConfigConfirmationAtIndex:index name:name taskCount:tasks.count];
}

- (void)showDeleteSavedConfigConfirmationAtIndex:(NSInteger)index name:(NSString *)name taskCount:(NSUInteger)taskCount {
    NSString *message = [NSString stringWithFormat:@"确定删除“%@”？包含 %lu 个任务。", name ?: @"配置", (unsigned long)taskCount];
    UIView *card = [self showConfigPromptBaseWithTitle:@"删除配置" message:message];
    _pendingConfigDeleteIndex = index;
    CGFloat width = card.bounds.size.width;

    UILabel *warningLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 104, width - 32, 28)];
    warningLabel.text = @"删除后不可恢复";
    warningLabel.textColor = [UIColor colorWithRed:1.0 green:0.56 blue:0.42 alpha:0.94];
    warningLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    warningLabel.textAlignment = NSTextAlignmentCenter;
    [card addSubview:warningLabel];

    CGFloat buttonY = 154.0;
    CGFloat gap = 12.0;
    CGFloat buttonWidth = floor((width - 32.0 - gap) / 2.0);
    UIButton *cancelButton = [self configPromptButtonWithTitle:@"取消" action:@selector(hideConfigPrompt) destructive:NO];
    cancelButton.frame = CGRectMake(16, buttonY, buttonWidth, 42);
    [card addSubview:cancelButton];

    UIButton *deleteButton = [self configPromptButtonWithTitle:@"删除" action:@selector(confirmDeleteSavedConfig) destructive:YES];
    deleteButton.frame = CGRectMake(16 + buttonWidth + gap, buttonY, buttonWidth, 42);
    [card addSubview:deleteButton];
}

- (void)confirmDeleteSavedConfig {
    NSMutableArray *configs = [self savedTaskConfigs];
    NSInteger index = _pendingConfigDeleteIndex;
    if (index < 0 || index >= (NSInteger)configs.count) {
        [self hideConfigPrompt];
        _statusLabel.text = @"配置不存在";
        return;
    }

    [configs removeObjectAtIndex:(NSUInteger)index];
    [self writeSavedTaskConfigs:configs];
    [self hideConfigPrompt];
    [self showSavedConfigListForDeleting:YES configsOverride:configs];
    _statusLabel.text = @"";
}

- (void)resetEditorActionState {
    for (NSUInteger i = 0; i < (NSUInteger)AnClickActionModeCount; i++) {
        _manualActionPoints[i] = CGPointZero;
        _hasManualActionPoint[i] = NO;
    }
    _manualSwipeAnchor = CGPointZero;
    _manualSwipeEndPoint = CGPointZero;
    _hasManualSwipeAnchor = NO;
    _hasManualSwipeEndPoint = NO;
    _successActionPoint = CGPointZero;
    _hasSuccessActionPoint = NO;
    _failureActionPoint = CGPointZero;
    _hasFailureActionPoint = NO;
    _pickingSuccessActionPoint = NO;
    _pickingFailureActionPoint = NO;
    _manualCoordinateScreenSize = CGSizeZero;
    _hasManualCoordinateScreenSize = NO;
    if (_recordedSwipePoints) {
        [_recordedSwipePoints removeAllObjects];
    } else {
        _recordedSwipePoints = [NSMutableArray array];
    }
    if (_multiTapPoints) {
        [_multiTapPoints removeAllObjects];
    } else {
        _multiTapPoints = [NSMutableArray array];
    }
    _currentTemplatePath = nil;
    _imageUsesMatchPoint = YES;
    _ocrUsesMatchPoint = YES;
    _imageActionMode = AnClickActionModeTap;
    _failureActionMode = AnClickActionModeNone;
    _ocrMode = AnClickOCRModeAppleVision;
    _ocrMatchMode = AnClickOCRMatchModeContains;
    _ocrTargetText = nil;
    _networkURL = nil;
    _networkContainsText = nil;
    _networkFalseText = nil;
    _networkPostBody = nil;
    _networkPostPairs = [NSMutableArray arrayWithObject:[self blankNetworkPostPair]];
    _networkRequestOnly = NO;
    _networkUsesPost = NO;
    _networkPostBodyUsesOCRResult = NO;
    _networkRetryForever = YES;
    _networkTimeout = 8.0;
    _recognitionRetryUntilFound = NO;
    _recognitionRetryDropdownVisible = NO;
    _recognitionRetryInterval = 1.0;
    _actionRandomDelayEnabled = NO;
    _actionJitterRadius = 0.0;
    _macroPlaybackSpeed = 1.0;
    _longPressDuration = AnClickDefaultLongPressDuration;
    _hasTargetColor = NO;
    _targetColorSamples = [NSMutableArray array];
    _pendingColorPickSamples = [NSMutableArray array];
    _selectedColorPickSampleIndex = -1;
    _targetColorRed = 0;
    _targetColorGreen = 0;
    _targetColorBlue = 0;
    _colorTolerance = 18.0;
    _recordedMacroEvents = nil;
    _recordedMacroScreenSize = CGSizeZero;
    _hasRecordedMacroScreenSize = NO;
    _matchThreshold = 0.80;
    _actionDescription = nil;
    _actionDelay = 0;
    _actionRepeatCount = 1;
    _actionInterval = AnClickDefaultTapPressDuration;
    _recognitionSuccessBranchIndex = -1;
    _recognitionFailureBranchIndex = -1;
}

- (void)resetCurrentActionConfiguration {
    [self resetEditorActionState];
    _actionMode = AnClickActionModeNone;
    _imageUsesMatchPoint = YES;
    _ocrUsesMatchPoint = YES;
    _imageActionMode = AnClickActionModeTap;
    _ocrMatchMode = AnClickOCRMatchModeContains;
    _templateSearchInProgress = NO;
    [self refreshModeButtons];
    [self refreshTemplatePreview];
}

- (void)collapsePanel {
    if (!_panelWindow || !_collapsedButton || !_panelView) {
        return;
    }

    [self hideGlobalSettings];
    [self hideFunctionMenu];
    _panelExpanded = NO;
    _taskEditorVisible = NO;
    CGRect frame = [self rememberedCollapsedPanelFrame];
    _panelWindow.frame = frame;
    _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
    _collapsedButton.hidden = NO;
    _homeCloseButton.hidden = YES;
    _homeBrandView.hidden = YES;
    _homeOutputView.hidden = YES;
    _panelView.hidden = YES;
    [self layoutCollapsedControls];
}

- (void)showCollapsedRecordingButton {
    if (!_panelWindow || !_collapsedButton || !_panelView) {
        return;
    }

    _panelExpanded = NO;
    CGRect frame = [self rememberedCollapsedPanelFrame];
    _panelWindow.frame = frame;
    _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
    _collapsedButton.hidden = NO;
    _homeCloseButton.hidden = YES;
    _homeBrandView.hidden = YES;
    _homeOutputView.hidden = YES;
    _panelView.hidden = YES;
    _panelWindow.hidden = NO;
    _panelWindow.userInteractionEnabled = YES;
    [self layoutCollapsedControls];
}

- (void)expandPanel {
    if (!_panelWindow || !_collapsedButton || !_panelView) {
        return;
    }

    CGRect frame = _panelWindow.frame;
    if (!_panelExpanded) {
        [self rememberCollapsedPanelFrame:frame];
    }
    _panelExpanded = YES;
    frame = [self rememberedExpandedPanelFrameWithSize:[self expandedPanelSize] fallbackFrame:frame];
    _panelWindow.frame = frame;
    _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
    _panelView.frame = [self panelContentFrameForBounds:_panelWindow.bounds editorVisible:_taskEditorVisible];
    _collapsedButton.hidden = YES;
    _collapsedRuntimeLabel.hidden = YES;
    _homeBrandView.hidden = _taskEditorVisible;
    _homeOutputView.hidden = _taskEditorVisible;
    _panelView.hidden = NO;
    [self setTaskEditorVisible:_taskEditorVisible];
    [self refreshTaskList];
    [self refreshTemplatePreview];
}

- (void)handleCollapsedTap {
    if ([AnClickRecorder shared].isRecording) {
        [self toggleMacroRecording];
        return;
    }
    [self runTaskList];
}

- (void)handleCollapsedLongPress:(UILongPressGestureRecognizer *)recognizer {
    if ([AnClickRecorder shared].isRecording || _taskRunActive) {
        return;
    }
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _taskEditorVisible = NO;
        [self expandPanel];
        [self showTaskHome];
    }
}

- (void)selectActionModeValue:(AnClickActionMode)nextMode {
    AnClickActionMode previousMode = _actionMode;
    CGPoint reusablePoint = CGPointZero;
    BOOL hasReusablePoint = [self isReusablePointActionMode:previousMode] && [self hasManualPointForMode:previousMode];
    if (hasReusablePoint) {
        reusablePoint = _manualActionPoints[(NSUInteger)previousMode];
    }

    _actionMode = nextMode;
    if (_editingTaskModel) {
        AnClickTaskModel *updatedModel = [_editingTaskModel copy];
        updatedModel.actionMode = nextMode;
        _editingTaskModel = updatedModel;
    }
    [self clearTransientEditorStateForActionMode:nextMode];
    if ([self isReusablePointActionMode:nextMode] && ![self hasManualPointForMode:nextMode] && hasReusablePoint) {
        _manualActionPoints[(NSUInteger)nextMode] = reusablePoint;
        _hasManualActionPoint[(NSUInteger)nextMode] = YES;
    }
    [self refreshModeButtons];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
}

- (void)refreshModeButtons {
    if (_taskEditorVisible && _taskEditorView) {
        [_taskEditorView reloadForm];
    }
}

- (NSString *)currentActionName {
    return [self actionNameForMode:_actionMode];
}

- (void)updateStatusForCurrentConfig {
    if (!_statusLabel || _taskRunActive) {
        return;
    }
    _statusLabel.text = @"";
}

- (void)clearSuccessBranchTargetSelection {
    _recognitionSuccessBranchIndex = -1;
    _successActionPoint = CGPointZero;
    _hasSuccessActionPoint = NO;
}

- (void)clearFailureBranchTargetSelection {
    _recognitionFailureBranchIndex = -1;
    _failureActionPoint = CGPointZero;
    _hasFailureActionPoint = NO;
}

- (NSString *)branchRecognitionContextTitle {
    if (_editingNestedBranchActionConfig && _editingNestedBranchActionMode != AnClickActionModeNone) {
        return [NSString stringWithFormat:@"%@后%@",
                _editingNestedBranchActionSuccess ? @"成功" : @"失败",
                [self actionNameForMode:_editingNestedBranchActionMode]];
    }
    if (!_editingBranchRecognitionConfig || _editingBranchActionMode == AnClickActionModeNone) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@后%@",
            _editingBranchRecognitionSuccess ? @"成功" : @"失败",
            [self actionNameForMode:_editingBranchActionMode]];
}

- (NSString *)actionNameForMode:(AnClickActionMode)mode {
    switch (mode) {
        case AnClickActionModeTap:
            return @"点击";
        case AnClickActionModeDoubleTap:
            return @"双击";
        case AnClickActionModeLongPress:
            return @"长按";
        case AnClickActionModeSwipe:
            return @"滑动";
        case AnClickActionModeTwoFingerTap:
            return @"多指";
        case AnClickActionModeImage:
            return @"识图";
        case AnClickActionModeMacro:
            return @"录制";
        case AnClickActionModeOCR:
            return @"识字";
        case AnClickActionModeColor:
            return @"识色";
        case AnClickActionModeNetwork:
            return @"网络";
        case AnClickActionModeJump:
            return @"跳转";
        case AnClickActionModeDelay:
            return @"延时";
        default:
            return @"动作";
    }
}

- (AnClickTaskModel *)taskEditorModelByMergingRuntimeState {
    AnClickTaskModel *model = _editingTaskModel ? [_editingTaskModel copy] : [[AnClickTaskModel alloc] init];
    model.actionMode = _actionMode;
    model.delay = _actionMode == AnClickActionModeDelay ? MAX(0.0, _actionDelay) : 0.0;
    model.repeatCount = MAX(1, _actionRepeatCount);
    model.interval = MIN(30.0, MAX(0.0, _actionInterval));
    model.randomDelay = NO;
    model.jitterRadius = _actionJitterRadius;
    model.taskDescription = _actionDescription ?: @"";
    model.templatePath = [self activeTemplatePath] ?: @"";
    model.useMatchPoint = _actionMode == AnClickActionModeOCR ? _ocrUsesMatchPoint : _imageUsesMatchPoint;
    model.successActionMode = [self normalizedImageActionMode:_imageActionMode];
    model.failureActionMode = [self normalizedFailureActionMode:_failureActionMode];
    model.threshold = MIN(1.0, MAX(0.0, _matchThreshold));
    model.ocrMode = _ocrMode;
    model.ocrMatchMode = _ocrMatchMode;
    model.ocrText = _ocrTargetText ?: @"";
    model.colorTolerance = MIN(255.0, MAX(0.0, _colorTolerance));
    model.networkURL = _networkURL ?: @"";
    model.networkContains = _networkContainsText ?: @"";
    model.networkFalse = _networkFalseText ?: @"";
    model.networkPostBody = _networkPostBody ?: @"";
    model.networkUsesPost = _networkUsesPost;
    model.networkRequestOnly = _networkRequestOnly;
    model.networkRetryForever = _networkRetryForever;
    model.networkTimeout = _networkTimeout;
    model.networkPostPairs = _networkPostPairs ?: @[];
    model.recognitionRetryUntilFound = _recognitionRetryUntilFound;
    model.recognitionRetryInterval = _recognitionRetryInterval;

    if ([self hasManualPointForMode:_actionMode]) {
        model.point = [NSValue valueWithCGPoint:_manualActionPoints[(NSUInteger)_actionMode]];
        model.pointScreenSize = [self currentScreenCoordinateSizeValue];
    }
    if (_actionMode == AnClickActionModeSwipe) {
        model.path = [self manualSwipePath] ?: @[];
        model.pathScreenSize = [self currentScreenCoordinateSizeValue];
    }
    if (_actionMode == AnClickActionModeTwoFingerTap) {
        model.multiPoints = _multiTapPoints ?: @[];
        model.multiPointScreenSize = [self currentScreenCoordinateSizeValue];
    }
    if (_actionMode == AnClickActionModeMacro) {
        model.events = _recordedMacroEvents ?: @[];
        model.eventsScreenSize = [NSValue valueWithCGSize:_hasRecordedMacroScreenSize ? _recordedMacroScreenSize : [self currentScreenCoordinateSize]];
        model.macroSpeed = [self normalizedMacroPlaybackSpeed:_macroPlaybackSpeed];
    }

    NSArray<NSDictionary *> *colorSamples = [self effectiveTargetColorSamples];
    NSDictionary *anchor = colorSamples.firstObject;
    if (anchor) {
        model.colorRed = MIN(255, MAX(0, [anchor[@"red"] integerValue]));
        model.colorGreen = MIN(255, MAX(0, [anchor[@"green"] integerValue]));
        model.colorBlue = MIN(255, MAX(0, [anchor[@"blue"] integerValue]));
        model.colorPoints = colorSamples;
        model.colorPointScreenSize = [self currentScreenCoordinateSizeValue];
        if ([anchor[@"x"] respondsToSelector:@selector(doubleValue)] &&
            [anchor[@"y"] respondsToSelector:@selector(doubleValue)]) {
            if (model.useMatchPoint || !model.point) {
                model.point = [NSValue valueWithCGPoint:CGPointMake([anchor[@"x"] doubleValue], [anchor[@"y"] doubleValue])];
                model.pointScreenSize = model.colorPointScreenSize;
            }
        }
    } else {
        model.colorRed = _targetColorRed;
        model.colorGreen = _targetColorGreen;
        model.colorBlue = _targetColorBlue;
    }

    model.longPressDuration = [self normalizedLongPressDuration:_longPressDuration];
    model.successBranchIndex = _recognitionSuccessBranchIndex;
    model.failureBranchIndex = _recognitionFailureBranchIndex;
    return model;
}

- (void)syncTaskEditorModelFromRuntimeState {
    _editingTaskModel = [self taskEditorModelByMergingRuntimeState];
}

- (void)refreshTaskEditorAfterExternalResult {
    [self syncTaskEditorModelFromRuntimeState];
    [self refreshEditorConfigControls];
}

- (void)stageTaskEditorModelForRuntime:(AnClickTaskModel *)model {
    if (![model isKindOfClass:AnClickTaskModel.class]) {
        return;
    }

    [self resetEditorActionState];
    _actionMode = model.actionMode;
    _actionDelay = model.actionMode == AnClickActionModeDelay ? MAX(0.0, model.delay) : 0.0;
    _actionRepeatCount = MAX(1, model.repeatCount);
    _actionInterval = MIN(30.0, MAX(0.0, model.interval));
    _actionRandomDelayEnabled = NO;
    _actionJitterRadius = MIN(200.0, MAX(0.0, model.jitterRadius));
    _actionDescription = [self trimmedActionDescription:model.taskDescription];
    _currentTemplatePath = model.templatePath.length > 0 ? model.templatePath : nil;
    if (model.actionMode == AnClickActionModeOCR) {
        _ocrUsesMatchPoint = model.useMatchPoint;
    } else {
        _imageUsesMatchPoint = model.useMatchPoint;
    }
    _imageActionMode = [self normalizedImageActionMode:model.successActionMode];
    _failureActionMode = [self normalizedFailureActionMode:model.failureActionMode];
    _matchThreshold = MIN(1.0, MAX(0.0, model.threshold));
    _ocrMode = model.ocrMode;
    _ocrMatchMode = model.ocrMatchMode;
    _ocrTargetText = [self trimmedActionDescription:model.ocrText];
    _networkURL = [self trimmedActionDescription:model.networkURL];
    _networkContainsText = [self trimmedActionDescription:model.networkContains];
    _networkFalseText = [self trimmedActionDescription:model.networkFalse];
    _networkPostBody = [self trimmedActionDescription:model.networkPostBody];
    _networkUsesPost = model.networkUsesPost;
    _networkRequestOnly = model.networkRequestOnly;
    _networkRetryForever = model.networkRetryForever;
    _networkTimeout = MIN(60.0, MAX(1.0, model.networkTimeout));
    _colorTolerance = MIN(255.0, MAX(0.0, model.colorTolerance));

    if (model.point && [self isReusablePointActionMode:model.actionMode]) {
        _manualActionPoints[(NSUInteger)model.actionMode] = model.point.CGPointValue;
        _hasManualActionPoint[(NSUInteger)model.actionMode] = YES;
        [self rememberManualCoordinateScreenSize];
    }
    if (model.actionMode == AnClickActionModeSwipe && model.path.count >= 2) {
        _recordedSwipePoints = [model.path mutableCopy];
        _manualSwipeAnchor = [model.path.firstObject CGPointValue];
        _manualSwipeEndPoint = [model.path.lastObject CGPointValue];
        _hasManualSwipeAnchor = YES;
        _hasManualSwipeEndPoint = YES;
        [self rememberManualCoordinateScreenSize];
    }
    if (model.actionMode == AnClickActionModeTwoFingerTap && model.multiPoints.count > 0) {
        _multiTapPoints = [model.multiPoints mutableCopy];
        [self rememberManualCoordinateScreenSize];
    }
    if (model.actionMode == AnClickActionModeMacro) {
        _recordedMacroEvents = model.events.count > 0 ? [model.events copy] : nil;
        _recordedMacroScreenSize = [self screenCoordinateSizeFromObject:model.eventsScreenSize];
        _hasRecordedMacroScreenSize = [self screenCoordinateSizeIsValid:_recordedMacroScreenSize];
        _macroPlaybackSpeed = [self normalizedMacroPlaybackSpeed:model.macroSpeed];
    }

    _targetColorRed = MIN(255, MAX(0, model.colorRed));
    _targetColorGreen = MIN(255, MAX(0, model.colorGreen));
    _targetColorBlue = MIN(255, MAX(0, model.colorBlue));
    if (model.colorPoints.count > 0) {
        [self applyTargetColorSamples:model.colorPoints];
    } else if (_actionMode == AnClickActionModeColor) {
        _hasTargetColor = YES;
        _targetColorSamples = [NSMutableArray array];
    }

    _longPressDuration = [self normalizedLongPressDuration:model.longPressDuration];
    _recognitionRetryUntilFound = model.recognitionRetryUntilFound;
    _recognitionRetryInterval = MIN(30.0, MAX(0.2, model.recognitionRetryInterval));
    _recognitionSuccessBranchIndex = model.successBranchIndex;
    _recognitionFailureBranchIndex = model.failureBranchIndex;
    if (_recognitionSuccessBranchIndex >= 0 &&
        (_actionMode == AnClickActionModeImage || _actionMode == AnClickActionModeOCR || _actionMode == AnClickActionModeColor)) {
        _imageActionMode = AnClickActionModeJump;
    }
    if (_recognitionFailureBranchIndex >= 0 &&
        (_actionMode == AnClickActionModeImage || _actionMode == AnClickActionModeOCR || _actionMode == AnClickActionModeColor)) {
        _failureActionMode = AnClickActionModeJump;
    }

    [self updateStatusForCurrentConfig];
}

- (BOOL)isSelectableActionMode:(AnClickActionMode)mode {
    return mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeTwoFingerTap ||
        mode == AnClickActionModeSwipe ||
        mode == AnClickActionModeImage ||
        mode == AnClickActionModeMacro ||
        mode == AnClickActionModeOCR ||
        mode == AnClickActionModeColor ||
        mode == AnClickActionModeNetwork ||
        mode == AnClickActionModeJump ||
        mode == AnClickActionModeDelay;
}

- (BOOL)isReusablePointActionMode:(AnClickActionMode)mode {
    return mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeImage ||
        mode == AnClickActionModeOCR ||
        mode == AnClickActionModeColor;
}

- (void)clearTransientEditorStateForActionMode:(AnClickActionMode)mode {
    _recognitionRetryDropdownVisible = NO;
    _pickingFailureActionPoint = NO;
    _pickingSwipeEndPoint = NO;
    if (mode != AnClickActionModeNetwork &&
        mode != AnClickActionModeImage &&
        mode != AnClickActionModeOCR &&
        mode != AnClickActionModeColor) {
        [self hideNetworkPostPairControls];
    }
}

- (AnClickOCRMode)ocrModeForTask:(__unused NSDictionary *)task {
    return AnClickOCRModeAppleVision;
}

- (BOOL)ocrTextHasRegexPrefix:(NSString *)text {
    if (text.length == 0) {
        return NO;
    }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray<NSString *> *prefixes = @[@"re:", @"regex:", @"正则:", @"re：", @"regex：", @"正则："];
    for (NSString *prefix in prefixes) {
        if ([trimmed rangeOfString:prefix options:NSCaseInsensitiveSearch].location == 0) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)ocrTextByRemovingRegexPrefix:(NSString *)text {
    if (text.length == 0) {
        return @"";
    }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray<NSString *> *prefixes = @[@"re:", @"regex:", @"正则:", @"re：", @"regex：", @"正则："];
    for (NSString *prefix in prefixes) {
        if ([trimmed rangeOfString:prefix options:NSCaseInsensitiveSearch].location == 0) {
            return [[trimmed substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        }
    }
    return trimmed;
}

- (BOOL)ocrRegexPatternIsValid:(NSString *)pattern {
    NSString *regexText = [self ocrTextByRemovingRegexPrefix:pattern ?: @""];
    if (regexText.length == 0) {
        return NO;
    }
    regexText = [regexText stringByFoldingWithOptions:NSWidthInsensitiveSearch locale:nil];
    NSError *regexError = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexText
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&regexError];
    return regex != nil && regexError == nil;
}

- (NSString *)ocrDisplayTextForText:(NSString *)text matchMode:(AnClickOCRMatchMode)matchMode {
    NSString *targetText = [self trimmedActionDescription:text];
    if (matchMode == AnClickOCRMatchModeRegex) {
        targetText = [self ocrTextByRemovingRegexPrefix:targetText];
    }
    if (targetText.length > 0) {
        return targetText;
    }
    if (matchMode == AnClickOCRMatchModeRegex) {
        return @"先填正则表达式";
    }
    return @"先填文字";
}

- (AnClickOCRMatchMode)ocrMatchModeForTask:(NSDictionary *)task {
    NSNumber *modeNumber = task[@"ocrMatchMode"];
    if (modeNumber) {
        if (modeNumber.integerValue == AnClickOCRMatchModeRegex) {
            return AnClickOCRMatchModeRegex;
        }
        return AnClickOCRMatchModeContains;
    }
    NSString *targetText = [self trimmedActionDescription:task[@"ocrText"]];
    if ([self ocrTextHasRegexPrefix:targetText ?: @""]) {
        return AnClickOCRMatchModeRegex;
    }
    return AnClickOCRMatchModeContains;
}

- (BOOL)ocrTaskUsesRegexMatching:(NSDictionary *)task {
    return [self ocrMatchModeForTask:task] == AnClickOCRMatchModeRegex;
}

- (AnClickOCRMatchMode)effectiveOCRMatchModeForText:(__unused NSString *)text {
    if (_ocrMatchMode == AnClickOCRMatchModeRegex) {
        return AnClickOCRMatchModeRegex;
    }
    return AnClickOCRMatchModeContains;
}

- (NSString *)ocrMatchModeTitleForMode:(AnClickOCRMatchMode)mode {
    if (mode == AnClickOCRMatchModeRegex) {
        return @"正则匹配";
    }
    return @"包含匹配";
}

- (NSString *)normalizedComparableOCRText:(NSString *)text {
    NSString *trimmed = [self trimmedActionDescription:text] ?: @"";
    NSString *folded = [trimmed stringByFoldingWithOptions:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch | NSWidthInsensitiveSearch)
                                                    locale:nil];
    return [folded stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (BOOL)ocrRecognizedText:(NSString *)recognizedText equalsTargetText:(NSString *)targetText {
    NSString *recognized = [self normalizedComparableOCRText:recognizedText];
    NSString *target = [self normalizedComparableOCRText:targetText];
    return recognized.length > 0 && target.length > 0 && [recognized isEqualToString:target];
}

- (AnClickActionMode)modeForTask:(NSDictionary *)task {
    NSNumber *modeNumber = task[@"mode"];
    if (!modeNumber) {
        return AnClickActionModeNone;
    }

    AnClickActionMode mode = (AnClickActionMode)modeNumber.integerValue;
    return [self isSelectableActionMode:mode] ? mode : AnClickActionModeNone;
}

- (NSArray<NSNumber *> *)imageActionModes {
    if (_editingBranchRecognitionConfig) {
        return [self branchRecognitionSuccessActionModes];
    }
    return @[
        @(AnClickActionModeTap),
        @(AnClickActionModeDoubleTap),
        @(AnClickActionModeLongPress),
        @(AnClickActionModeTwoFingerTap),
        @(AnClickActionModeSwipe),
        @(AnClickActionModeNetwork),
        @(AnClickActionModeImage),
        @(AnClickActionModeOCR),
        @(AnClickActionModeColor),
        @(AnClickActionModeMacro),
        @(AnClickActionModeJump),
    ];
}

- (AnClickActionMode)normalizedImageActionMode:(AnClickActionMode)mode {
    for (NSNumber *modeNumber in [self imageActionModes]) {
        if (modeNumber.integerValue == mode) {
            return mode;
        }
    }
    return AnClickActionModeTap;
}

- (NSArray<NSNumber *> *)failureActionModes {
    if (_editingBranchRecognitionConfig) {
        return [self branchRecognitionFailureActionModes];
    }
    return @[
        @(AnClickActionModeNone),
        @(AnClickActionModeTap),
        @(AnClickActionModeDoubleTap),
        @(AnClickActionModeLongPress),
        @(AnClickActionModeTwoFingerTap),
        @(AnClickActionModeSwipe),
        @(AnClickActionModeNetwork),
        @(AnClickActionModeImage),
        @(AnClickActionModeOCR),
        @(AnClickActionModeColor),
        @(AnClickActionModeMacro),
        @(AnClickActionModeJump),
    ];
}

- (AnClickActionMode)normalizedFailureActionMode:(AnClickActionMode)mode {
    for (NSNumber *modeNumber in [self failureActionModes]) {
        if (modeNumber.integerValue == mode) {
            return mode;
        }
    }
    return AnClickActionModeNone;
}

- (NSArray<NSNumber *> *)branchRecognitionSuccessActionModes {
    return @[
        @(AnClickActionModeTap),
        @(AnClickActionModeDoubleTap),
        @(AnClickActionModeLongPress),
        @(AnClickActionModeSwipe),
        @(AnClickActionModeNetwork),
        @(AnClickActionModeTwoFingerTap),
        @(AnClickActionModeMacro),
        @(AnClickActionModeJump),
    ];
}

- (NSArray<NSNumber *> *)branchRecognitionFailureActionModes {
    return @[
        @(AnClickActionModeNone),
        @(AnClickActionModeTap),
        @(AnClickActionModeDoubleTap),
        @(AnClickActionModeLongPress),
        @(AnClickActionModeSwipe),
        @(AnClickActionModeNetwork),
        @(AnClickActionModeTwoFingerTap),
        @(AnClickActionModeMacro),
        @(AnClickActionModeJump),
    ];
}

- (AnClickActionMode)branchRecognitionActionModeForButton:(UIButton *)button {
    NSInteger tag = button.tag;
    NSArray<NSNumber *> *bases = @[
        @(AnClickBranchSuccessSuccessActionTagBase),
        @(AnClickBranchSuccessFailureActionTagBase),
        @(AnClickBranchFailureSuccessActionTagBase),
        @(AnClickBranchFailureFailureActionTagBase),
    ];
    for (NSNumber *baseNumber in bases) {
        NSInteger base = baseNumber.integerValue;
        NSInteger value = tag - base;
        if (value >= AnClickActionModeNone && value < AnClickActionModeCount) {
            return (AnClickActionMode)value;
        }
    }
    return AnClickActionModeNone;
}

- (BOOL)branchRecognitionButtonOwnsSuccessBranch:(UIButton *)button {
    NSInteger tag = button.tag;
    NSInteger successBases[] = {
        AnClickBranchSuccessSuccessActionTagBase,
        AnClickBranchSuccessFailureActionTagBase,
    };
    NSUInteger count = sizeof(successBases) / sizeof(NSInteger);
    for (NSUInteger i = 0; i < count; i++) {
        NSInteger base = successBases[i];
        NSInteger value = tag - base;
        if (value >= AnClickActionModeNone && value < AnClickActionModeCount) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)trimmedActionDescription:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length > 0 ? trimmed : nil;
}

- (BOOL)hasManualPointForMode:(AnClickActionMode)mode {
    if (mode < AnClickActionModeTap || mode >= AnClickActionModeCount || mode == AnClickActionModeSwipe) {
        return NO;
    }
    return _hasManualActionPoint[(NSUInteger)mode];
}

- (void)dismissConfigKeyboardAndSync {
    [self syncGlobalSettingsFromFields];
    [_panelView endEditing:YES];
}

- (void)dismissKeyboard {
    [self dismissConfigKeyboardAndSync];
    _activeConfigTextField = nil;
    if (!_keyboardVisible) {
        [self resetKeyboardAvoidanceInsetsExceptScrollView:nil];
    }
    [self refreshGlobalSettingsFieldsIfNeeded];
    if (_taskEditorVisible) {
        [self updateStatusForCurrentConfig];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self dismissKeyboard];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    _activeConfigTextField = textField;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyKeyboardAvoidanceAnimated:YES];
    });
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (_activeConfigTextField == textField) {
        _activeConfigTextField = nil;
    }
}

- (void)handlePanelTapToDismissKeyboard:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self dismissKeyboard];
    }
}

- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    if (_taskEditorVisible) {
        return;
    }

    CGPoint translation = [recognizer translationInView:_panelWindow];
    CGRect frame = _panelWindow.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    _panelWindow.frame = _panelExpanded ? [self clampedPanelFrame:frame] : [self clampedFloatingFrame:frame];
    if (_panelExpanded) {
        [self rememberExpandedPanelFrame:_panelWindow.frame];
    } else {
        [self rememberCollapsedPanelFrame:_panelWindow.frame];
    }
    [recognizer setTranslation:CGPointZero inView:_panelWindow];

    if (recognizer.state == UIGestureRecognizerStateEnded ||
        recognizer.state == UIGestureRecognizerStateCancelled ||
        recognizer.state == UIGestureRecognizerStateFailed) {
        [UIView animateWithDuration:0.16
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             [self reclampPanelWindowForCurrentScreen];
                         }
                         completion:nil];
    }
}

- (NSString *)templatePath {
    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[documentsURL path] stringByAppendingPathComponent:@"anclick_template.png"];
}

- (NSString *)newTemplatePath {
    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSString *name = [NSString stringWithFormat:@"anclick_template_%lld.png", (long long)([NSDate date].timeIntervalSince1970 * 1000.0)];
    return [[documentsURL path] stringByAppendingPathComponent:name];
}

- (NSString *)activeTemplatePath {
    return _currentTemplatePath;
}

- (NSString *)writableTemplatePath {
    if (!_currentTemplatePath.length) {
        _currentTemplatePath = [self newTemplatePath];
    }
    return _currentTemplatePath;
}

- (BOOL)currentTemplateExists {
    NSString *path = [self activeTemplatePath];
    return path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSString *)commonConfigSummary {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (_actionMode == AnClickActionModeDelay) {
        [parts addObject:[NSString stringWithFormat:@"等待%@", [self millisecondsSummaryTextForDuration:_actionDelay]]];
    }
    if (_actionMode == AnClickActionModeTap || _actionMode == AnClickActionModeTwoFingerTap) {
        [parts addObject:[NSString stringWithFormat:@"重复%ld次", (long)MAX(1, _actionRepeatCount)]];
        if (_actionRepeatCount > 1 && _actionInterval > 0.001) {
            [parts addObject:[NSString stringWithFormat:@"间隔%@", [self millisecondsSummaryTextForDuration:_actionInterval]]];
        }
    }
    if (_actionJitterRadius > 0.001 &&
        (_actionMode == AnClickActionModeTap ||
         _actionMode == AnClickActionModeDoubleTap ||
         _actionMode == AnClickActionModeLongPress ||
         _actionMode == AnClickActionModeSwipe ||
         _actionMode == AnClickActionModeTwoFingerTap ||
         _actionMode == AnClickActionModeMacro)) {
        [parts addObject:[NSString stringWithFormat:@"抖%.0fpx", _actionJitterRadius]];
    }
    if (_actionMode == AnClickActionModeMacro && fabs([self normalizedMacroPlaybackSpeed:_macroPlaybackSpeed] - 1.0) > 0.001) {
        [parts addObject:[NSString stringWithFormat:@"速%@", [self macroPlaybackSpeedSummaryText:_macroPlaybackSpeed]]];
    }
    if (_actionMode == AnClickActionModeLongPress) {
        [parts addObject:[NSString stringWithFormat:@"长%@", [self longPressDurationSummaryText:_longPressDuration]]];
    }
    return parts.count > 0 ? [parts componentsJoinedByString:@" "] : @"已设置";
}

- (void)syncActionDescriptionFromField {
}

- (void)actionDescriptionChanged:(UITextField *)textField {
    _actionDescription = [self trimmedActionDescription:textField.text];
    [self autosaveSelectedTaskIfPossible];
}

- (NSString *)delayFieldText {
    if (_actionDelay <= 0.001) {
        return @"0";
    }
    return [NSString stringWithFormat:@"%ld", (long)llround(_actionDelay * 1000.0)];
}

- (NSString *)repeatFieldText {
    return [NSString stringWithFormat:@"%ld", (long)MAX(1, _actionRepeatCount)];
}

- (NSString *)millisecondsFieldTextForDuration:(NSTimeInterval)duration
                               defaultDuration:(NSTimeInterval)defaultDuration
                                       minimum:(NSTimeInterval)minimum
                                       maximum:(NSTimeInterval)maximum {
    NSTimeInterval safeDuration = (!isfinite(duration) || duration < 0.0) ? defaultDuration : duration;
    NSTimeInterval clamped = MIN(maximum, MAX(minimum, safeDuration));
    return [NSString stringWithFormat:@"%ld", (long)llround(clamped * 1000.0)];
}

- (NSString *)millisecondsSummaryTextForDuration:(NSTimeInterval)duration {
    NSTimeInterval safeDuration = (!isfinite(duration) || duration < 0.0) ? 0.0 : duration;
    NSInteger milliseconds = (NSInteger)llround(safeDuration * 1000.0);
    return [NSString stringWithFormat:@"%ld毫秒", (long)MAX(0, milliseconds)];
}

- (NSString *)actionIntervalFieldText {
    return [self millisecondsFieldTextForDuration:_actionInterval
                                  defaultDuration:AnClickDefaultTapPressDuration
                                          minimum:AnClickDefaultTapPressDuration
                                          maximum:30.0];
}

- (double)normalizedMacroPlaybackSpeed:(double)speed {
    if (!isfinite(speed) || speed <= 0.0) {
        return 1.0;
    }
    return MIN(AnClickMacroMaxPlaybackSpeed, MAX(AnClickMacroMinPlaybackSpeed, speed));
}

- (double)macroPlaybackSpeedForTask:(NSDictionary *)task {
    id value = task[@"macroSpeed"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return [self normalizedMacroPlaybackSpeed:[value doubleValue]];
    }
    return 1.0;
}

- (NSString *)macroPlaybackSpeedSummaryText:(double)speed {
    double normalizedSpeed = [self normalizedMacroPlaybackSpeed:speed];
    double rounded = round(normalizedSpeed);
    if (fabs(normalizedSpeed - rounded) < 0.005) {
        return [NSString stringWithFormat:@"%.0fx", rounded];
    }
    double oneDecimal = round(normalizedSpeed * 10.0) / 10.0;
    if (fabs(normalizedSpeed - oneDecimal) < 0.005) {
        return [NSString stringWithFormat:@"%.1fx", oneDecimal];
    }
    return [NSString stringWithFormat:@"%.2fx", normalizedSpeed];
}

- (NSString *)macroPlaybackSpeedFieldText {
    double speed = [self normalizedMacroPlaybackSpeed:_macroPlaybackSpeed];
    if (fabs(speed - 1.0) < 0.001) {
        return @"";
    }
    double rounded = round(speed);
    if (fabs(speed - rounded) < 0.005) {
        return [NSString stringWithFormat:@"%.0f", rounded];
    }
    double oneDecimal = round(speed * 10.0) / 10.0;
    if (fabs(speed - oneDecimal) < 0.005) {
        return [NSString stringWithFormat:@"%.1f", oneDecimal];
    }
    return [NSString stringWithFormat:@"%.2f", speed];
}

- (NSTimeInterval)normalizedLongPressDuration:(NSTimeInterval)duration {
    if (!isfinite(duration) || duration <= 0.0) {
        return AnClickDefaultLongPressDuration;
    }
    return MIN(AnClickMaxLongPressDuration, MAX(AnClickMinLongPressDuration, duration));
}

- (NSTimeInterval)longPressDurationForTask:(NSDictionary *)task {
    id millisecondValue = task[@"pressDurationMs"];
    if ([millisecondValue respondsToSelector:@selector(doubleValue)]) {
        return [self normalizedLongPressDuration:[millisecondValue doubleValue] / 1000.0];
    }
    id value = task[@"pressDuration"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return [self normalizedLongPressDuration:[value doubleValue]];
    }
    return AnClickDefaultLongPressDuration;
}

- (NSTimeInterval)swipeDurationForTask:(NSDictionary *)task {
    id value = task[@"swipeDuration"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return MIN(10.0, MAX(0.05, [value doubleValue]));
    }
    return AnClickDefaultSwipeDuration;
}

- (NSTimeInterval)doubleTapIntervalForTask:(NSDictionary *)task {
    id value = task[@"doubleTapInterval"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return MIN(2.0, MAX(0.02, [value doubleValue]));
    }
    return AnClickDefaultDoubleTapInterval;
}

- (NSTimeInterval)doubleTapOperationDurationForTask:(NSDictionary *)task {
    return AnClickDefaultTapPressDuration + [self doubleTapIntervalForTask:task] + AnClickDefaultTapPressDuration;
}

- (NSTimeInterval)longPressOperationDurationForDuration:(NSTimeInterval)pressDuration {
    return [self normalizedLongPressDuration:pressDuration] + 0.10;
}

- (NSString *)longPressDurationFieldText {
    NSTimeInterval duration = [self normalizedLongPressDuration:_longPressDuration];
    return [NSString stringWithFormat:@"%ld", (long)llround(duration * 1000.0)];
}

- (NSString *)longPressDurationSummaryText:(NSTimeInterval)duration {
    NSTimeInterval normalizedDuration = [self normalizedLongPressDuration:duration];
    NSInteger milliseconds = (NSInteger)llround(normalizedDuration * 1000.0);
    return [NSString stringWithFormat:@"%ld毫秒", (long)milliseconds];
}

- (NSString *)jitterFieldText {
    if (_actionJitterRadius <= 0.001) {
        return @"";
    }
    return [NSString stringWithFormat:@"%.0f", MIN(200.0, MAX(0.0, _actionJitterRadius))];
}

- (NSString *)recognitionBranchFieldTextForIndex:(NSInteger)index {
    if (index < 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"%ld", (long)index + 1];
}

- (NSString *)recognitionRetryIntervalFieldText {
    NSTimeInterval interval = MIN(30.0, MAX(0.2, _recognitionRetryInterval));
    return [self millisecondsFieldTextForDuration:interval
                                  defaultDuration:1.0
                                          minimum:0.2
                                          maximum:30.0];
}

- (NSString *)recognitionRetryModeTitle {
    return _recognitionRetryUntilFound ? @"当前：识别到为止 ▾" : @"当前：执行次数 ▾";
}

- (NSString *)recognitionRetryStatusSummary {
    return _recognitionRetryUntilFound
        ? [NSString stringWithFormat:@" 识别到为止 识别间隔%@", [self millisecondsSummaryTextForDuration:MIN(30.0, MAX(0.2, _recognitionRetryInterval))]]
        : [NSString stringWithFormat:@" 次%ld", (long)MAX(1, _actionRepeatCount)];
}

- (NSString *)thresholdFieldText {
    if (_actionMode == AnClickActionModeNetwork) {
        return [NSString stringWithFormat:@"%.0f", MAX(1.0, _networkTimeout)];
    }
    if (_actionMode == AnClickActionModeColor) {
        return [NSString stringWithFormat:@"%.0f", _colorTolerance];
    }
    return [NSString stringWithFormat:@"%.2f", _matchThreshold];
}

- (BOOL)currentActionIsRecognitionMode {
    return _actionMode == AnClickActionModeImage ||
        _actionMode == AnClickActionModeOCR ||
        _actionMode == AnClickActionModeColor;
}

- (BOOL)currentEditorUsesNetworkPostPairs {
    if (!_taskEditorVisible || !_networkUsesPost) {
        return NO;
    }
    if (_actionMode == AnClickActionModeNetwork) {
        return YES;
    }
    return (_actionMode == AnClickActionModeImage ||
            _actionMode == AnClickActionModeOCR ||
            _actionMode == AnClickActionModeColor) &&
        (_imageActionMode == AnClickActionModeNetwork ||
         _failureActionMode == AnClickActionModeNetwork);
}

- (BOOL)currentEditorNetworkPostAllowsRecognitionResult {
    return _taskEditorVisible &&
        _networkUsesPost &&
        _actionMode == AnClickActionModeOCR &&
        _imageActionMode == AnClickActionModeNetwork;
}

- (BOOL)currentRecognitionEditorUsesNetworkAction {
    return (_actionMode == AnClickActionModeImage ||
            _actionMode == AnClickActionModeOCR ||
            _actionMode == AnClickActionModeColor) &&
        (_imageActionMode == AnClickActionModeNetwork ||
         _failureActionMode == AnClickActionModeNetwork);
}

- (NSMutableDictionary *)blankNetworkPostPair {
    return [@{
        @"key": @"",
        @"value": @"",
        @"useResult": @NO,
    } mutableCopy];
}

- (void)ensureNetworkPostPairs {
    if (!_networkPostPairs) {
        _networkPostPairs = [NSMutableArray array];
    }
    while (_networkPostPairs.count > ACPostPairLimit) {
        [_networkPostPairs removeLastObject];
    }
    if (_networkPostPairs.count == 0) {
        [_networkPostPairs addObject:[self blankNetworkPostPair]];
    }
}

- (void)hideNetworkPostPairControls {
}

- (BOOL)networkPostPairValueUsesResult:(NSDictionary *)pair {
    return [pair[@"useResult"] boolValue];
}

- (BOOL)networkPostValueTextMeansResult:(NSString *)value {
    NSString *text = [self trimmedActionDescription:value];
    NSArray<NSString *> *tokens = @[@"{{result}}", @"{{识别结果}}", @"{{识字结果}}", @"{{正则结果}}", @"{{正则识别结果}}"];
    for (NSString *token in tokens) {
        if ([text isEqualToString:token]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)networkPostSelfFilledValueFromText:(NSString *)text {
    NSString *value = [self trimmedActionDescription:text];
    NSArray<NSString *> *staleDisplayLabels = @[@"识别结果", @"使用识别结果"];
    for (NSString *label in staleDisplayLabels) {
        if ([value isEqualToString:label]) {
            return @"";
        }
    }
    return value ?: @"";
}

- (NSString *)unquotedNetworkPostText:(NSString *)text {
    NSString *trimmed = [self trimmedActionDescription:text];
    if (trimmed.length >= 2) {
        unichar first = [trimmed characterAtIndex:0];
        unichar last = [trimmed characterAtIndex:trimmed.length - 1];
        if ((first == '"' && last == '"') || (first == '\'' && last == '\'')) {
            return [trimmed substringWithRange:NSMakeRange(1, trimmed.length - 2)];
        }
    }
    return trimmed;
}

- (void)syncNetworkPostPairsFromFields {
}

- (NSArray<NSDictionary *> *)configuredNetworkPostPairs {
    [self ensureNetworkPostPairs];
    NSMutableArray<NSDictionary *> *pairs = [NSMutableArray array];
    BOOL allowResultValue = [self currentEditorNetworkPostAllowsRecognitionResult];
    for (NSDictionary *pair in _networkPostPairs) {
        NSString *key = [self trimmedActionDescription:pair[@"key"]];
        BOOL usesResult = allowResultValue && [self networkPostPairValueUsesResult:pair];
        NSString *value = usesResult ? @"" : [self networkPostSelfFilledValueFromText:pair[@"value"]];
        if (key.length == 0 && value.length == 0 && !usesResult) {
            continue;
        }
        if (key.length == 0) {
            continue;
        }
        [pairs addObject:@{
            @"key": key,
            @"value": value ?: @"",
            @"useResult": @(usesResult),
        }];
    }
    return pairs;
}

- (NSArray<NSDictionary *> *)networkPostPairsFromKeyValueText:(NSString *)text {
    NSString *rule = [self trimmedActionDescription:text];
    if (rule.length == 0) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *pairs = [NSMutableArray array];
    NSCharacterSet *pairSeparators = [NSCharacterSet characterSetWithCharactersInString:@"&;\n；"];
    for (NSString *rawPair in [rule componentsSeparatedByCharactersInSet:pairSeparators]) {
        NSString *pairText = [self trimmedActionDescription:rawPair];
        if (pairText.length == 0) {
            continue;
        }
        NSRange separatorRange = [pairText rangeOfString:@"="];
        if (separatorRange.location == NSNotFound) {
            separatorRange = [pairText rangeOfString:@":"];
        }
        if (separatorRange.location == NSNotFound) {
            continue;
        }
        NSString *key = [self unquotedNetworkPostText:[pairText substringToIndex:separatorRange.location]];
        NSString *value = [self unquotedNetworkPostText:[pairText substringFromIndex:NSMaxRange(separatorRange)]];
        if (key.length == 0) {
            continue;
        }
        BOOL usesResult = [self networkPostValueTextMeansResult:value];
        [pairs addObject:@{
            @"key": key,
            @"value": usesResult ? @"" : (value ?: @""),
            @"useResult": @(usesResult),
        }];
        if (pairs.count >= ACPostPairLimit) {
            break;
        }
    }
    return pairs;
}

- (NSMutableArray<NSMutableDictionary *> *)mutableNetworkPostPairsFromTask:(NSDictionary *)task {
    NSMutableArray<NSMutableDictionary *> *pairs = [NSMutableArray array];
    id savedPairs = task[@"networkPostPairs"];
    if ([savedPairs isKindOfClass:NSArray.class]) {
        for (NSDictionary *pair in (NSArray *)savedPairs) {
            if (![pair isKindOfClass:NSDictionary.class]) {
                continue;
            }
            NSString *key = [self trimmedActionDescription:pair[@"key"]];
            NSString *value = [self trimmedActionDescription:pair[@"value"]];
            BOOL usesResult = [pair[@"useResult"] boolValue] || [self networkPostValueTextMeansResult:value];
            [pairs addObject:[@{
                @"key": key ?: @"",
                @"value": usesResult ? @"" : [self networkPostSelfFilledValueFromText:value],
                @"useResult": @(usesResult),
            } mutableCopy]];
            if (pairs.count >= ACPostPairLimit) {
                break;
            }
        }
    }
    if (pairs.count == 0) {
        for (NSDictionary *pair in [self networkPostPairsFromKeyValueText:task[@"networkPostExtraFields"]]) {
            [pairs addObject:[pair mutableCopy]];
        }
    }
    if (pairs.count == 0) {
        for (NSDictionary *pair in [self networkPostPairsFromKeyValueText:task[@"networkPostBody"]]) {
            [pairs addObject:[pair mutableCopy]];
        }
    }
    if (pairs.count == 0) {
        [pairs addObject:[self blankNetworkPostPair]];
    }
    return pairs;
}

- (NSString *)pointSummaryForMode:(AnClickActionMode)mode emptyTitle:(NSString *)emptyTitle {
    if (mode == AnClickActionModeTwoFingerTap) {
        return [self multiTapPointSummary];
    }
    if (mode == AnClickActionModeSwipe) {
        if (_hasManualSwipeAnchor && _hasManualSwipeEndPoint) {
            return [NSString stringWithFormat:@"起 %.0f,%.0f  终 %.0f,%.0f",
                    _manualSwipeAnchor.x,
                    _manualSwipeAnchor.y,
                    _manualSwipeEndPoint.x,
                    _manualSwipeEndPoint.y];
        }
        if (_hasManualSwipeAnchor) {
            return [NSString stringWithFormat:@"起点 %.0f,%.0f，继续选择终点", _manualSwipeAnchor.x, _manualSwipeAnchor.y];
        }
        return emptyTitle;
    }

    if ([self hasManualPointForMode:mode]) {
        CGPoint point = _manualActionPoints[(NSUInteger)mode];
        return [NSString stringWithFormat:@"已选 %.0f,%.0f", point.x, point.y];
    }
    return emptyTitle;
}

- (NSString *)multiTapPointSummary {
    NSUInteger count = MIN(_multiTapPoints.count, AnClickMultiTapMaxPoints);
    if (count == 0) {
        return @"添加触点";
    }
    return [NSString stringWithFormat:@"已取%lu点 继续添加", (unsigned long)count];
}

- (void)clearMultiTapPoints {
    if (_actionMode != AnClickActionModeTwoFingerTap) {
        return;
    }
    [_multiTapPoints removeAllObjects];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
    [self autosaveSelectedTaskIfPossible];
}

- (BOOL)currentFailureActionNeedsPoint {
    AnClickActionMode failureMode = [self normalizedFailureActionMode:_failureActionMode];
    return [self currentActionIsRecognitionMode] &&
        [self failureActionModeNeedsPoint:failureMode] &&
        [self currentStoredBranchActionConfigForSuccess:NO mode:failureMode] == nil;
}

- (BOOL)currentSuccessActionNeedsPoint {
    AnClickActionMode successMode = [self normalizedImageActionMode:_imageActionMode];
    return [self currentActionIsRecognitionMode] &&
        [self recognitionActionModeNeedsPoint:successMode] &&
        [self currentStoredBranchActionConfigForSuccess:YES mode:successMode] == nil;
}

- (NSString *)successActionPointSummary {
    AnClickActionMode successMode = [self normalizedImageActionMode:_imageActionMode];
    NSString *name = [self actionNameForMode:successMode];
    if (_hasSuccessActionPoint) {
        return [NSString stringWithFormat:@"成功%@坐标 %.0f,%.0f", name, _successActionPoint.x, _successActionPoint.y];
    }
    return [NSString stringWithFormat:@"选择成功%@坐标", name];
}

- (NSString *)failureActionPointSummary {
    AnClickActionMode failureMode = [self normalizedFailureActionMode:_failureActionMode];
    NSString *name = [self actionNameForMode:failureMode];
    if (_hasFailureActionPoint) {
        return [NSString stringWithFormat:@"失败%@坐标 %.0f,%.0f", name, _failureActionPoint.x, _failureActionPoint.y];
    }
    return [NSString stringWithFormat:@"选择失败%@坐标", name];
}

- (NSString *)targetColorSummary {
    if ([self effectiveTargetColorSamples].count == 0) {
        return @"截图取色";
    }
    return [self targetColorDetailedDescription];
}

- (UIColor *)targetUIColor {
    NSDictionary *anchor = [self effectiveTargetColorSamples].firstObject;
    return [self uiColorForColorSample:anchor fallback:[UIColor colorWithWhite:1 alpha:0.10]];
}

- (void)refreshEditorConfigControls {
    if (!_taskEditorVisible) {
        return;
    }
    if (_taskEditorView) {
        _taskEditorView.hidden = NO;
        _taskEditorView.frame = _panelView.bounds;
        [_panelView bringSubviewToFront:_taskEditorView];
        [self refreshTaskEditorViewFromCurrentState];
    }
}

- (void)refreshTaskEditorViewFromCurrentState {
    if (!_taskEditorView) {
        return;
    }

    AnClickTaskModel *model = _editingTaskModel ?: [self taskEditorModelByMergingRuntimeState];
    NSInteger displayTaskIndex = (_editingTaskIndex >= 0 && _editingTaskIndex < (NSInteger)_taskItems.count)
        ? _editingTaskIndex
        : _selectedTaskIndex;
    [_taskEditorView configureWithModel:model
                              taskIndex:displayTaskIndex
                            branchTitle:[self branchRecognitionContextTitle]
                             actionName:[self currentActionName]];
}

- (void)selectImageActionMode:(UIButton *)sender {
    AnClickActionMode nextMode = [self normalizedImageActionMode:(AnClickActionMode)sender.tag];
    BOOL changed = nextMode != _imageActionMode;
    if (changed) {
        [self clearSuccessBranchTargetSelection];
    }
    _imageActionMode = nextMode;
    if (_imageActionMode != AnClickActionModeNetwork &&
        _failureActionMode != AnClickActionModeNetwork) {
        _networkPostBodyUsesOCRResult = NO;
    }
    if ([self modeIsRecognitionTask:_imageActionMode]) {
        [self ensureMutableBranchActionConfigForSuccess:YES mode:_imageActionMode];
    }
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
    [self autosaveSelectedTaskIfPossible];
}

- (void)selectFailureActionMode:(UIButton *)sender {
    if (![self currentActionIsRecognitionMode]) {
        _failureActionMode = AnClickActionModeNone;
        _recognitionRetryDropdownVisible = NO;
        [self refreshEditorConfigControls];
        [self updateStatusForCurrentConfig];
        return;
    }
    AnClickActionMode nextMode = [self normalizedFailureActionMode:(AnClickActionMode)sender.tag];
    BOOL changed = nextMode != _failureActionMode;
    if (changed) {
        [self clearFailureBranchTargetSelection];
    }
    _failureActionMode = nextMode;
    if (_imageActionMode != AnClickActionModeNetwork &&
        _failureActionMode != AnClickActionModeNetwork) {
        _networkPostBodyUsesOCRResult = NO;
    }
    if ([self modeIsRecognitionTask:_failureActionMode]) {
        [self ensureMutableBranchActionConfigForSuccess:NO mode:_failureActionMode];
    }
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
    [self autosaveSelectedTaskIfPossible];
}

- (void)selectBranchRecognitionSuccessActionMode:(UIButton *)sender {
    BOOL ownerSuccess = [self branchRecognitionButtonOwnsSuccessBranch:sender];
    AnClickActionMode ownerMode = ownerSuccess
        ? [self normalizedImageActionMode:_imageActionMode]
        : [self normalizedFailureActionMode:_failureActionMode];
    if (![self modeIsRecognitionTask:ownerMode]) {
        return;
    }
    AnClickActionMode nextMode = [self normalizedImageActionMode:[self branchRecognitionActionModeForButton:sender]];
    if ([self modeIsRecognitionTask:nextMode]) {
        nextMode = AnClickActionModeTap;
    }
    NSMutableDictionary *config = [self ensureMutableBranchActionConfigForSuccess:ownerSuccess mode:ownerMode];
    if (!config) {
        return;
    }
    config[@"imageActionMode"] = @(nextMode);
    [self storeBranchActionConfig:config success:ownerSuccess mode:ownerMode];
    [self refreshEditorConfigControls];
    [self refreshTaskList];
    [self updateStatusForCurrentConfig];
}

- (void)selectBranchRecognitionFailureActionMode:(UIButton *)sender {
    BOOL ownerSuccess = [self branchRecognitionButtonOwnsSuccessBranch:sender];
    AnClickActionMode ownerMode = ownerSuccess
        ? [self normalizedImageActionMode:_imageActionMode]
        : [self normalizedFailureActionMode:_failureActionMode];
    if (![self modeIsRecognitionTask:ownerMode]) {
        return;
    }
    AnClickActionMode nextMode = [self normalizedFailureActionMode:[self branchRecognitionActionModeForButton:sender]];
    if ([self modeIsRecognitionTask:nextMode]) {
        nextMode = AnClickActionModeNone;
    }
    NSMutableDictionary *config = [self ensureMutableBranchActionConfigForSuccess:ownerSuccess mode:ownerMode];
    if (!config) {
        return;
    }
    config[@"failureActionMode"] = @(nextMode);
    [self storeBranchActionConfig:config success:ownerSuccess mode:ownerMode];
    [self refreshEditorConfigControls];
    [self refreshTaskList];
    [self updateStatusForCurrentConfig];
}

- (void)editSuccessRecognitionActionTask {
    if (![self currentActionIsRecognitionMode]) {
        _statusLabel.text = @"识别动作才有成功配置";
        return;
    }
    [self dismissConfigKeyboardAndSync];
    AnClickActionMode successMode = [self normalizedImageActionMode:_imageActionMode];
    if (successMode == AnClickActionModeJump) {
        _statusLabel.text = @"跳转任务请在下方选择目标";
        return;
    }

    [self beginEditingRecognitionActionConfigForSuccess:YES mode:successMode];
}

- (void)editFailureRecognitionActionTask {
    if (![self currentActionIsRecognitionMode]) {
        _statusLabel.text = @"识别动作才有失败配置";
        return;
    }
    [self dismissConfigKeyboardAndSync];
    AnClickActionMode failureMode = [self normalizedFailureActionMode:_failureActionMode];
    if (failureMode == AnClickActionModeNone) {
        _statusLabel.text = @"先选择失败后动作";
        return;
    }
    if (failureMode == AnClickActionModeJump) {
        _statusLabel.text = @"跳转任务请在下方选择目标";
        return;
    }

    [self beginEditingRecognitionActionConfigForSuccess:NO mode:failureMode];
}

- (void)decreaseActionDelay {
    _actionDelay = MAX(0.0, _actionDelay - 0.1);
    _actionDelay = round(_actionDelay * 1000.0) / 1000.0;
    [self updateStatusForCurrentConfig];
}

- (void)increaseActionDelay {
    _actionDelay = MIN(30.0, _actionDelay + 0.1);
    _actionDelay = round(_actionDelay * 1000.0) / 1000.0;
    [self updateStatusForCurrentConfig];
}

- (void)decreaseActionRepeatCount {
    _actionRepeatCount = MAX(1, _actionRepeatCount - 1);
    [self updateStatusForCurrentConfig];
}

- (void)increaseActionRepeatCount {
    _actionRepeatCount = MIN(99, _actionRepeatCount + 1);
    [self updateStatusForCurrentConfig];
}

- (UIWindow *)hostWindow {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self activeWindowScene];
        for (UIWindow *window in scene.windows) {
            if (window != _panelWindow && window.windowLevel < UIWindowLevelAlert && window.isKeyWindow && !window.hidden && window.alpha > 0.01) {
                return window;
            }
        }
        for (UIWindow *window in scene.windows) {
            if (window != _panelWindow && window.windowLevel < UIWindowLevelAlert && !window.hidden && window.alpha > 0.01) {
                return window;
            }
        }
        return nil;
    }

    NSArray<UIWindow *> *windows = [UIApplication.sharedApplication valueForKey:@"windows"];
    for (UIWindow *window in windows) {
        if (window != _panelWindow && window.windowLevel < UIWindowLevelAlert && window.isKeyWindow && !window.hidden && window.alpha > 0.01) {
            return window;
        }
    }
    for (UIWindow *window in windows) {
        if (window != _panelWindow && window.windowLevel < UIWindowLevelAlert && !window.hidden && window.alpha > 0.01) {
            return window;
        }
    }
    return nil;
}

- (BOOL)applicationIsActiveForTaskRun {
    return UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
}

- (BOOL)hostWindowIsUsableForTaskRun:(UIWindow *)window {
    if (!window ||
        window == _panelWindow ||
        window == _toastWindow ||
        window == _pointPickWindow ||
        window == _colorPickWindow ||
        window.hidden ||
        window.alpha <= 0.01 ||
        window.windowLevel >= UIWindowLevelAlert ||
        CGRectIsEmpty(window.bounds)) {
        return NO;
    }

    if (@available(iOS 13.0, *)) {
        if (window.windowScene && window.windowScene.activationState != UISceneActivationStateForegroundActive) {
            return NO;
        }
    }
    return YES;
}

- (UIWindow *)currentUsableHostWindowForTaskRunFallback:(UIWindow *)fallbackWindow {
    (void)fallbackWindow;
    if (![self applicationIsActiveForTaskRun]) {
        return nil;
    }

    UIWindow *currentWindow = [self hostWindow];
    if ([self hostWindowIsUsableForTaskRun:currentWindow]) {
        return currentWindow;
    }
    return nil;
}

- (void)clearTaskRunPauseState {
    _taskRunPausedForForeground = NO;
    _taskRunResumeInGlobalNetworkGate = NO;
    _taskRunResumeScheduled = NO;
    _taskRunResumeCycle = 0;
    _taskRunResumeIndex = 0;
    [self refreshTaskRunRuntimeLabel];
}

- (void)rememberTaskRunResumePointAtIndex:(NSUInteger)index inGlobalNetworkGate:(BOOL)inGlobalNetworkGate scheduled:(BOOL)scheduled {
    _taskRunResumeIndex = index;
    _taskRunResumeCycle = _currentGlobalRunCycle;
    _taskRunResumeInGlobalNetworkGate = inGlobalNetworkGate;
    _taskRunResumeScheduled = scheduled;
}

- (void)resetTaskRunJumpGuard {
    [_taskEngine resetJumpGuard];
}

- (void)resetRunProgressToastThrottle {
    _lastRunProgressToastText = nil;
    _lastRunProgressToastTime = 0.0;
    _lastRunTraceTime = 0.0;
}

- (BOOL)shouldShowRunProgressToastText:(NSString *)text {
    if (!_taskRunActive || _taskRunSingleStepStopIndex >= 0) {
        return YES;
    }
    CFTimeInterval now = CACurrentMediaTime();
    NSString *safeText = text ?: @"";
    BOOL sameText = _lastRunProgressToastText && [_lastRunProgressToastText isEqualToString:safeText];
    if (sameText && now - _lastRunProgressToastTime < AnClickRunProgressToastMinInterval) {
        return NO;
    }
    if (!sameText && now - _lastRunProgressToastTime < AnClickRunProgressToastMinInterval) {
        return NO;
    }
    _lastRunProgressToastText = [safeText copy];
    _lastRunProgressToastTime = now;
    return YES;
}

- (BOOL)shouldShowRunTraceNow {
    if (!_taskRunActive || _taskRunSingleStepStopIndex >= 0) {
        return YES;
    }
    CFTimeInterval now = CACurrentMediaTime();
    if (now - _lastRunTraceTime < AnClickRunTraceMinInterval) {
        return NO;
    }
    _lastRunTraceTime = now;
    return YES;
}

- (void)clearTemplateImageCache {
    [_templateImageCache removeAllObjects];
    [_templateImageModificationDates removeAllObjects];
}

- (UIImage *)cachedTemplateImageAtPath:(NSString *)path {
    NSString *templatePath = [self trimmedActionDescription:path];
    if (templatePath.length == 0) {
        return nil;
    }

    NSDictionary<NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:templatePath error:nil];
    NSDate *modificationDate = attributes[NSFileModificationDate];
    if (!modificationDate) {
        [_templateImageCache removeObjectForKey:templatePath];
        [_templateImageModificationDates removeObjectForKey:templatePath];
        return nil;
    }

    NSDate *cachedDate = _templateImageModificationDates[templatePath];
    UIImage *cachedImage = [_templateImageCache objectForKey:templatePath];
    if (cachedImage && cachedDate && [cachedDate isEqualToDate:modificationDate]) {
        return cachedImage;
    }

    UIImage *image = [UIImage imageWithContentsOfFile:templatePath];
    if (!image) {
        [_templateImageCache removeObjectForKey:templatePath];
        [_templateImageModificationDates removeObjectForKey:templatePath];
        return nil;
    }

    [_templateImageCache setObject:image forKey:templatePath];
    _templateImageModificationDates[templatePath] = modificationDate;
    return image;
}

- (void)refreshTaskListDuringRunIfNeeded {
    if (![_taskEngine shouldRefreshListNow]) {
        return;
    }
    [self refreshTaskList];
}

- (BOOL)taskEngine:(__unused AnClickTaskEngine *)engine canContinueWithGeneration:(NSUInteger)generation fallbackHost:(id)host status:(NSString *)status {
    return [self taskRunIsStillValidWithGeneration:generation fallbackWindow:(UIWindow *)host status:status];
}

- (BOOL)taskEngineCanUseCurrentScene:(__unused AnClickTaskEngine *)engine {
    return [self panelCanUseCurrentScene];
}

- (id)taskEngine:(__unused AnClickTaskEngine *)engine currentHostWithFallback:(id)host {
    return [self currentUsableHostWindowForTaskRunFallback:(UIWindow *)host];
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine rememberResumeIndex:(NSUInteger)index globalNetworkGate:(BOOL)globalNetworkGate scheduled:(BOOL)scheduled {
    [self rememberTaskRunResumePointAtIndex:index inGlobalNetworkGate:globalNetworkGate scheduled:scheduled];
}

- (BOOL)taskEngineResumeScheduled:(__unused AnClickTaskEngine *)engine {
    return _taskRunResumeScheduled;
}

- (NSInteger)taskEngineSingleStepStopIndex:(__unused AnClickTaskEngine *)engine {
    return _taskRunSingleStepStopIndex;
}

- (NSInteger)taskEngineRepeatLimit:(__unused AnClickTaskEngine *)engine {
    return MAX(0, _globalRunRepeatCount);
}

- (NSInteger *)taskEngineCurrentCyclePointer:(__unused AnClickTaskEngine *)engine {
    return &_currentGlobalRunCycle;
}

- (NSTimeInterval)taskEngineLoopInterval:(__unused AnClickTaskEngine *)engine {
    return (NSTimeInterval)_globalLoopIntervalSeconds;
}

- (NSTimeInterval)taskEngineGlobalDelay:(__unused AnClickTaskEngine *)engine {
    return MAX(0.0, _globalDelayMilliseconds / 1000.0);
}

- (NSUInteger)taskEngineTaskCount:(__unused AnClickTaskEngine *)engine {
    return _taskItems.count;
}

- (AnClickTaskModel *)taskEngine:(__unused AnClickTaskEngine *)engine taskModelAtIndex:(NSUInteger)index {
    return [self taskModelAtIndex:index];
}

- (NSMutableDictionary *)taskEngine:(__unused AnClickTaskEngine *)engine dictionaryForModel:(AnClickTaskModel *)model {
    return [self taskDictionaryForModel:model];
}

- (BOOL)taskEngine:(__unused AnClickTaskEngine *)engine taskModelIsComplete:(AnClickTaskModel *)model {
    return [self taskModelIsComplete:model];
}

- (BOOL)taskEngine:(__unused AnClickTaskEngine *)engine modeIsRecognitionTask:(AnClickActionMode)mode {
    return [self modeIsRecognitionTask:mode];
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine showToastForTask:(NSDictionary *)task index:(NSUInteger)index {
    NSString *text = [self toastTextForTask:task index:index];
    _statusLabel.text = text;
    if ([self shouldShowRunProgressToastText:text]) {
        [self showToast:text];
    }
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine setStatus:(NSString *)status {
    _statusLabel.text = status ?: @"";
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine showRunStatus:(NSString *)status {
    _statusLabel.text = status ?: @"";
    [self showToast:_statusLabel.text];
    [self refreshCollapsedButtonTitle];
}

- (NSString *)taskEngineCurrentStatus:(__unused AnClickTaskEngine *)engine {
    return _statusLabel.text;
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine finishWithStatus:(NSString *)status showToast:(BOOL)showToast restorePanel:(BOOL)restorePanel {
    [self finishTaskRunWithStatus:status showToast:showToast restorePanel:restorePanel];
}

- (void)taskEngineFinishSingleStep:(__unused AnClickTaskEngine *)engine status:(NSString *)status {
    [self finishSingleStepTaskRunWithStatus:status];
}

- (void)taskEngineExpandPanel:(__unused AnClickTaskEngine *)engine {
    [self expandPanel];
}

- (NSTimeInterval)taskEngine:(__unused AnClickTaskEngine *)engine performTaskModel:(AnClickTaskModel *)model host:(id)host generation:(NSUInteger)generation {
    return [self performTaskModel:model inWindow:(UIWindow *)host runGeneration:generation];
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine
performGlobalNetworkGateRequestWithGeneration:(NSUInteger)generation
        completion:(AnClickTaskEngineGlobalNetworkCompletion)completion {
    NSString *url = _globalNetworkURL;
    NSString *contains = _globalNetworkContainsText;
    NSString *falseText = _globalNetworkFalseText;
    __weak typeof(self) weakSelf = self;
    [self performNetworkRequestWithURLString:url
                                      method:@"GET"
                                     headers:nil
                                    postBody:nil
                                    trueText:contains
                                   falseText:falseText
                         defaultExpectedTrue:NO
                                     timeout:8.0
                                  completion:^(BOOL matched, BOOL requestSucceeded, NSString *body, NSInteger statusCode, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !completion) {
            return;
        }
        if (![strongSelf taskRunIsStillValidWithGeneration:generation fallbackWindow:nil status:@"窗口变化停止"]) {
            return;
        }
        NSString *runRule = [strongSelf trimmedActionDescription:contains];
        BOOL blocked = requestSucceeded && [strongSelf networkBody:body matchesBlockText:falseText defaultExpectedTrue:NO];
        BOOL shouldRun = runRule.length > 0 ? matched : (requestSucceeded && !blocked);
        NSString *status = blocked
            ? @"命中不运行 继续监控"
            : (requestSucceeded
                ? @"未命中运行 继续监控"
                : [strongSelf networkStatusTextWithMatched:NO requestSucceeded:requestSucceeded statusCode:statusCode error:error]);
        completion(shouldRun, status);
    }];
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine
performNetworkRequestForModel:(AnClickTaskModel *)model
        generation:(NSUInteger)generation
        completion:(AnClickTaskEngineNetworkCompletion)completion {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    if (!task) {
        if (completion) {
            completion(NO, NO, NO);
        }
        return;
    }
    [self performNetworkRequestTask:task runGeneration:generation completion:completion];
}

- (BOOL)taskEngine:(__unused AnClickTaskEngine *)engine networkTaskModelHasFailurePath:(AnClickTaskModel *)model {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    if (!task) {
        return NO;
    }
    return [self failureActionModeForTask:task] != AnClickActionModeNone ||
        [self validRecognitionJumpIndexForTask:task success:NO] >= 0;
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine
continueAfterNetworkTaskModel:(AnClickTaskModel *)model
           atIndex:(NSUInteger)index
              host:(id)host
        generation:(NSUInteger)generation
           success:(BOOL)success {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    if (!task) {
        [self stopTaskRunWithStatus:@"任务数据无效" showToast:YES];
        return;
    }
    [self scheduleTaskContinuationAfterRecognitionTask:task
                                               atIndex:index
                                              inWindow:(UIWindow *)host
                                            generation:generation
                                               success:success
                                                 delay:0.0];
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine
performRecognitionTaskModel:(AnClickTaskModel *)model
              host:(id)host
        generation:(NSUInteger)generation
        completion:(AnClickTaskEngineRecognitionCompletion)completion {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    if (!task) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    [self performRecognitionNetworkTask:task inWindow:(UIWindow *)host generation:generation completion:completion];
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine
performRecognitionBranchActionForModel:(AnClickTaskModel *)model
           success:(BOOL)success
              host:(id)host
        generation:(NSUInteger)generation
        completion:(AnClickTaskEngineActionDelayCompletion)completion {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    if (!task) {
        if (completion) {
            completion(0.0);
        }
        return;
    }
    [self performRecognitionBranchActionForTask:task
                                        success:success
                                       inWindow:(UIWindow *)host
                                     generation:generation
                                     completion:completion];
}

- (void)taskEngine:(__unused AnClickTaskEngine *)engine
performRecognitionFailureActionForModel:(AnClickTaskModel *)model
              host:(id)host
        generation:(NSUInteger)generation
        completion:(AnClickTaskEngineActionDelayCompletion)completion {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    if (!task) {
        if (completion) {
            completion(0.0);
        }
        return;
    }
    [self performRecognitionFailureActionForTask:task
                                        inWindow:(UIWindow *)host
                                      generation:generation
                                      completion:completion];
}

- (NSTimeInterval)taskEngine:(__unused AnClickTaskEngine *)engine delayForRecognitionTaskModel:(AnClickTaskModel *)model {
    return [self delayForTask:[self taskDictionaryForModel:model]];
}

- (NSTimeInterval)taskEngine:(__unused AnClickTaskEngine *)engine actionIntervalForRecognitionTaskModel:(AnClickTaskModel *)model {
    return [self actionIntervalForTask:[self taskDictionaryForModel:model]];
}

- (NSTimeInterval)taskEngine:(__unused AnClickTaskEngine *)engine retryIntervalForRecognitionTaskModel:(AnClickTaskModel *)model {
    return [self recognitionRetryIntervalForTask:[self taskDictionaryForModel:model]];
}

- (NSTimeInterval)taskEngine:(__unused AnClickTaskEngine *)engine postSuccessDelayForRecognitionTaskModel:(AnClickTaskModel *)model {
    return [self postRecognitionSuccessDelayForTask:[self taskDictionaryForModel:model]];
}

- (NSInteger)taskEngine:(__unused AnClickTaskEngine *)engine repeatCountForRecognitionTaskModel:(AnClickTaskModel *)model {
    return [self repeatCountForTask:[self taskDictionaryForModel:model]];
}

- (BOOL)taskEngine:(__unused AnClickTaskEngine *)engine retryUntilFoundForRecognitionTaskModel:(AnClickTaskModel *)model {
    return [self recognitionRetryUntilFoundForTask:[self taskDictionaryForModel:model]];
}

- (AnClickActionMode)taskEngine:(__unused AnClickTaskEngine *)engine failureActionModeForRecognitionTaskModel:(AnClickTaskModel *)model {
    return [self failureActionModeForTask:[self taskDictionaryForModel:model]];
}

- (NSInteger)taskEngine:(__unused AnClickTaskEngine *)engine failureJumpIndexForRecognitionTaskModel:(AnClickTaskModel *)model {
    return [self validRecognitionJumpIndexForTask:[self taskDictionaryForModel:model] success:NO];
}

- (NSUInteger)taskEngine:(__unused AnClickTaskEngine *)engine
nextIndexAfterRecognitionTaskModel:(AnClickTaskModel *)model
            currentIndex:(NSUInteger)index
                 success:(BOOL)success {
    return [self nextTaskIndexAfterRecognitionTask:[self taskDictionaryForModel:model] currentIndex:index success:success];
}

- (NSString *)taskEngine:(__unused AnClickTaskEngine *)engine displayNameForRecognitionTaskModel:(AnClickTaskModel *)model {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    return [self actionNameForMode:[self modeForTask:task]];
}

- (NSString *)taskEngine:(__unused AnClickTaskEngine *)engine durationTextForRecognitionDelay:(NSTimeInterval)delay {
    return [self millisecondsSummaryTextForDuration:delay];
}

- (void)pauseTaskRunForForegroundLoss {
    if (!_taskRunActive) {
        return;
    }

    _taskRunActive = NO;
    _taskRunPausedForForeground = YES;
    _taskRunResumeCycle = _currentGlobalRunCycle;
    _taskRunGeneration++;
    [self resetRunProgressToastThrottle];
    [self cancelRunningTaskSideEffects];
    [self stopTaskRunRuntimeTimerReset:NO];
    _statusLabel.text = @"应用切出暂停";
    _volumeShortcutRunSuppressToasts = NO;
    [self refreshCollapsedButtonTitle];
    [self refreshTaskList];
}

- (void)cleanupScreenInteractionStateRestoringPanel:(BOOL)restorePanel {
    [_taskEngine invalidateScheduledCallbacks];
    [_recognitionService cancelPendingRequests];
    [self cancelActiveNetworkTasks];
    [self invalidatePendingPanelRestore];
    [_pickerService cancelPendingCaptures];

    _captureOverlay.delegate = nil;
    [_captureOverlay removeFromSuperview];
    _captureOverlay = nil;
    _captureSnapshot = nil;

    _pointPickOverlay.delegate = nil;
    [_pointPickOverlay removeFromSuperview];
    _pointPickOverlay = nil;
    [_pickerService dismissOverlayWindow:_pointPickWindow];
    _pointPickWindow = nil;
    _pointPickSnapshot = nil;
    _pointPickHostWindow = nil;
    _hasPendingPointPickPoint = NO;
    _pickingSwipeEndPoint = NO;

    _colorPickOverlay.delegate = nil;
    [_colorPickOverlay removeFromSuperview];
    _colorPickOverlay = nil;
    [_pickerService dismissOverlayWindow:_colorPickWindow];
    _colorPickWindow = nil;
    _colorPickImage = nil;
    _pendingColorPickSamples = [NSMutableArray array];
    _selectedColorPickSampleIndex = -1;
    _hasPendingColorPickPoint = NO;
    [self clearColorPickPixelData];

    [_tapMarkerView removeFromSuperview];
    _tapMarkerView = nil;
    [_recognitionBoxView removeFromSuperview];
    _recognitionBoxView = nil;
    [_operationTraceView removeFromSuperview];
    _operationTraceView = nil;
    [_trajectoryView removeFromSuperview];
    _trajectoryView = nil;
    _trajectoryLayer = nil;
    _liveSwipePoints = nil;

    [_hostToastView removeFromSuperview];
    _hostToastView = nil;
    _hostToastLabel = nil;
    _toastWindow.hidden = YES;
    _toastGeneration++;

    [AnClickFakeTouch cancelAll];
    _longPressHolding = NO;
    _templateSearchInProgress = NO;

    if (restorePanel && [self applicationIsActiveForTaskRun]) {
        [self restorePanelAfterExternalTap];
    }
}

- (BOOL)taskRunIsStillValidWithGeneration:(NSUInteger)runGeneration
                            fallbackWindow:(UIWindow *)fallbackWindow
                                    status:(NSString *)status {
    if (!_taskRunActive || runGeneration != _taskRunGeneration) {
        return NO;
    }

    if (![self applicationIsActiveForTaskRun]) {
        [self pauseTaskRunForForegroundLoss];
        [self cleanupScreenInteractionStateRestoringPanel:NO];
        return NO;
    }

    if (![self currentUsableHostWindowForTaskRunFallback:fallbackWindow]) {
        [self stopTaskRunWithStatus:status.length > 0 ? status : @"窗口变化停止" showToast:YES];
        [self cleanupScreenInteractionStateRestoringPanel:YES];
        return NO;
    }
    return YES;
}

- (UIWindow *)hostWindowForCallbackWithFallback:(UIWindow *)fallbackWindow
                                  runGeneration:(NSUInteger)runGeneration
                                         status:(NSString *)status {
    if (![self applicationIsActiveForTaskRun]) {
        if (runGeneration != 0) {
            [self pauseTaskRunForForegroundLoss];
            [self cleanupScreenInteractionStateRestoringPanel:NO];
        }
        return nil;
    }

    if (runGeneration != 0) {
        if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:fallbackWindow status:status]) {
            return nil;
        }
        return [self currentUsableHostWindowForTaskRunFallback:fallbackWindow];
    }

    UIWindow *currentWindow = [self hostWindow];
    if ([self hostWindowIsUsableForTaskRun:currentWindow]) {
        return currentWindow;
    }
    if ([self hostWindowIsUsableForTaskRun:fallbackWindow]) {
        return fallbackWindow;
    }
    return nil;
}

- (BOOL)recognitionGeometryStillValidFromGeneration:(NSUInteger)geometryGeneration
                                      runGeneration:(NSUInteger)runGeneration
                                       restorePanel:(BOOL)restorePanel {
    if (geometryGeneration == _screenGeometryGeneration) {
        return YES;
    }

    _templateSearchInProgress = NO;
    if (runGeneration != 0 && (!_taskRunActive || runGeneration != _taskRunGeneration)) {
        return NO;
    }
    if (runGeneration != 0 && _taskRunActive && runGeneration == _taskRunGeneration) {
        [self cleanupScreenInteractionStateRestoringPanel:YES];
        [self stopTaskRunWithStatus:@"屏幕已变化停止"];
    } else {
        _statusLabel.text = @"屏幕已变化 请重试";
        if (restorePanel) {
            [self restorePanelAfterExternalTap];
        }
        [self showToast:_statusLabel.text];
    }
    return NO;
}

- (void)resumePausedTaskRunAttempt:(NSInteger)attempt {
    if (!_taskRunPausedForForeground || _taskRunActive) {
        return;
    }
    if (![self applicationIsActiveForTaskRun]) {
        return;
    }

    UIWindow *hostWindow = [self currentUsableHostWindowForTaskRunFallback:nil];
    if (!hostWindow) {
        if (attempt < 10) {
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf resumePausedTaskRunAttempt:attempt + 1];
            });
            return;
        }

        [self clearTaskRunPauseState];
        _currentGlobalRunCycle = 0;
        _statusLabel.text = @"恢复无窗口";
        [self showToast:_statusLabel.text];
        [self refreshCollapsedButtonTitle];
        [self refreshTaskList];
        return;
    }

    if (_taskItems.count == 0) {
        [self clearTaskRunPauseState];
        _currentGlobalRunCycle = 0;
        _statusLabel.text = @"恢复无任务";
        [self showToast:_statusLabel.text];
        [self refreshCollapsedButtonTitle];
        [self refreshTaskList];
        return;
    }

    if ([AnClickRecorder shared].isRecording) {
        [self clearTaskRunPauseState];
        _currentGlobalRunCycle = 0;
        _statusLabel.text = @"录制中无法恢复";
        [self showToast:_statusLabel.text];
        [self refreshCollapsedButtonTitle];
        [self refreshTaskList];
        return;
    }

    BOOL resumeInGlobalNetworkGate = _taskRunResumeInGlobalNetworkGate;
    BOOL scheduled = _taskRunResumeScheduled;
    NSUInteger resumeIndex = MIN(_taskRunResumeIndex, _taskItems.count);
    NSInteger resumeCycle = MAX(0, _taskRunResumeCycle);

    if (resumeInGlobalNetworkGate) {
        NSString *networkValidationMessage = [self globalNetworkGateValidationMessage];
        if (networkValidationMessage.length > 0) {
            [self clearTaskRunPauseState];
            _currentGlobalRunCycle = 0;
            _statusLabel.text = networkValidationMessage;
            [self showToast:_statusLabel.text];
            [self refreshCollapsedButtonTitle];
            [self refreshTaskList];
            return;
        }
    }

    _taskRunPausedForForeground = NO;
    _taskRunActive = YES;
    _currentGlobalRunCycle = resumeCycle;
    NSUInteger runGeneration = ++_taskRunGeneration;
    [self resetRunProgressToastThrottle];
    [self startTaskRunRuntimeTimerReset:NO];
    _statusLabel.text = resumeInGlobalNetworkGate ? @"恢复网络监控" : @"恢复播放";
    [self showToast:_statusLabel.text];
    [self refreshTaskList];
    [self collapsePanel];

    if (resumeInGlobalNetworkGate) {
        [self rememberTaskRunResumePointAtIndex:0 inGlobalNetworkGate:YES scheduled:scheduled];
        [_taskEngine monitorGlobalNetworkGateWithHost:hostWindow scheduled:scheduled generation:runGeneration];
        return;
    }

    [self rememberTaskRunResumePointAtIndex:resumeIndex inGlobalNetworkGate:NO scheduled:scheduled];
    [self runTaskAtIndex:resumeIndex inWindow:hostWindow generation:runGeneration];
}

- (void)handleApplicationDidBecomeActive {
    [self show];
    if (!_taskRunPausedForForeground) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf resumePausedTaskRunAttempt:0];
    });
}

- (void)handleApplicationWillLeaveForeground {
    BOOL wasRunning = _taskRunActive;
    if (wasRunning) {
        [self pauseTaskRunForForegroundLoss];
    } else if (!_taskRunPausedForForeground) {
        _taskRunGeneration++;
    }
    [self cleanupScreenInteractionStateRestoringPanel:NO];
    if (wasRunning) {
        _statusLabel.text = @"应用切出暂停";
    }
    _volumeShortcutRunSuppressToasts = NO;
    [self refreshCollapsedButtonTitle];
    [self refreshTaskList];
}

- (void)beginTemplateCapture {
    if (![self panelCanUseCurrentScene]) {
        _branchTemplateCaptureActive = NO;
        _branchTemplateCaptureMode = AnClickActionModeNone;
        return;
    }
    if (!_branchTemplateCaptureActive) {
        if (_actionMode == AnClickActionModeNone) {
            _actionMode = AnClickActionModeImage;
            _imageUsesMatchPoint = YES;
            [self refreshModeButtons];
            [self refreshEditorConfigControls];
        }
        if (_actionMode != AnClickActionModeImage) {
            _actionMode = AnClickActionModeImage;
            _imageUsesMatchPoint = YES;
            [self refreshModeButtons];
            [self refreshEditorConfigControls];
        }
    }

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _branchTemplateCaptureActive = NO;
        _branchTemplateCaptureMode = AnClickActionModeNone;
        _statusLabel.text = @"无窗口";
        return;
    }

    _statusLabel.text = @"截图中";
    [_pickerService cancelPendingCaptures];
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    __weak typeof(self) weakSelf = self;
    [_pickerService captureAfterDelay:0.16 completion:^(UIImage *image, UIWindow *capturedWindow) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf->_captureSnapshot = image;
        if (!strongSelf->_captureSnapshot.CGImage) {
            strongSelf->_branchTemplateCaptureActive = NO;
            strongSelf->_branchTemplateCaptureMode = AnClickActionModeNone;
            [strongSelf restorePanelAfterExternalTap];
            strongSelf->_statusLabel.text = @"截图失败";
            return;
        }
        UIWindow *overlayWindow = capturedWindow ?: hostWindow;
        if (![strongSelf->_pickerService capturedImage:strongSelf->_captureSnapshot matchesWindow:overlayWindow]) {
            strongSelf->_branchTemplateCaptureActive = NO;
            strongSelf->_branchTemplateCaptureMode = AnClickActionModeNone;
            [strongSelf restorePanelAfterExternalTap];
            strongSelf->_captureSnapshot = nil;
            strongSelf->_statusLabel.text = @"截图方向异常 请重试";
            [strongSelf showToast:strongSelf->_statusLabel.text];
            return;
        }
        [strongSelf showCaptureOverlayInWindow:overlayWindow];
    }];
}

- (void)showCaptureOverlayInWindow:(UIWindow *)hostWindow {
    _captureOverlay.delegate = nil;
    [_captureOverlay removeFromSuperview];
    _captureOverlay = [[AnClickTemplateCaptureView alloc] initWithFrame:hostWindow.bounds image:_captureSnapshot];
    _captureOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _captureOverlay.delegate = self;
    [hostWindow addSubview:_captureOverlay];
}

- (void)saveSelectedTemplate {
    if (!_captureSnapshot.CGImage || !_captureOverlay || CGRectIsEmpty(_captureOverlay.selectionFrame)) {
        [self cancelTemplateCapture];
        _statusLabel.text = @"先框选区域";
        return;
    }

    UIImage *templateImage = [_pickerService croppedImageFromImage:_captureSnapshot selectionFrame:_captureOverlay.selectionFrame];
    if (!templateImage.CGImage) {
        [self cancelTemplateCapture];
        _statusLabel.text = @"区域错误";
        return;
    }
    if (_branchTemplateCaptureActive) {
        BOOL success = _branchTemplateCaptureSuccess;
        AnClickActionMode mode = _branchTemplateCaptureMode;
        NSString *path = [self newTemplatePath];
        BOOL saved = [_pickerService saveImage:templateImage toPath:path];
        if (saved) {
            [self clearTemplateImageCache];
            NSMutableDictionary *config = [self ensureMutableBranchActionConfigForSuccess:success mode:mode];
            if (config) {
                config[@"templatePath"] = path;
                config[@"useMatchPoint"] = @YES;
                if (![config[@"threshold"] respondsToSelector:@selector(doubleValue)]) {
                    config[@"threshold"] = @0.80;
                }
                [self storeBranchActionConfig:config success:success mode:mode];
            } else {
                saved = NO;
            }
        }
        [self finishTemplateCapture];
        [self stageTaskEditorModelForRuntime:_editingTaskModel];
        [self refreshEditorConfigControls];
        [self refreshTaskList];
        [self updateStatusForCurrentConfig];
        if (!saved) {
            _statusLabel.text = @"保存失败";
        }
        return;
    }
    BOOL saved = [_pickerService saveImage:templateImage toPath:[self writableTemplatePath]];
    if (saved) {
        [self clearTemplateImageCache];
    }
    [self finishTemplateCapture];
    [self refreshTaskEditorAfterExternalResult];
    [self autosaveSelectedTaskIfPossible];
    if (!saved) {
        _statusLabel.text = @"保存失败";
    }
}

- (void)cancelTemplateCapture {
    _branchTemplateCaptureActive = NO;
    _branchTemplateCaptureMode = AnClickActionModeNone;
    [self finishTemplateCapture];
    _statusLabel.text = @"取消";
}

- (void)finishTemplateCapture {
    _captureOverlay.delegate = nil;
    [_captureOverlay removeFromSuperview];
    _captureOverlay = nil;
    _captureSnapshot = nil;
    _branchTemplateCaptureActive = NO;
    _branchTemplateCaptureMode = AnClickActionModeNone;
    [self restorePanelAfterExternalTap];
}

- (void)templateCaptureView:(__unused AnClickTemplateCaptureView *)view didSelectFrame:(__unused CGRect)selectionFrame {
    [self saveSelectedTemplate];
}

- (void)templateCaptureViewDidCancel:(__unused AnClickTemplateCaptureView *)view {
    [self cancelTemplateCapture];
}

- (void)refreshTemplatePreview {
    if (_taskEditorVisible && _taskEditorView) {
        [self refreshTaskEditorViewFromCurrentState];
    }
}

- (NSUInteger)invalidatePendingPanelRestore {
    _panelRestoreGeneration++;
    return _panelRestoreGeneration;
}

- (void)preparePanelForExternalTapWithHostWindow:(UIWindow *)hostWindow {
    [self dismissConfigKeyboardAndSync];
    [self invalidatePendingPanelRestore];
    if (hostWindow && !hostWindow.isKeyWindow) {
        [hostWindow makeKeyWindow];
    }
    if (_panelWindow) {
        [self collapsePanel];
        _panelWindow.alpha = 1.0;
        _panelWindow.userInteractionEnabled = YES;
        _panelWindow.hidden = NO;
    }
}

- (void)hidePanelForScreenInteractionWithHostWindow:(UIWindow *)hostWindow {
    [self dismissConfigKeyboardAndSync];
    [self invalidatePendingPanelRestore];
    if (hostWindow && !hostWindow.isKeyWindow) {
        [hostWindow makeKeyWindow];
    }
    if (_panelWindow) {
        _panelWindow.alpha = 1.0;
        _panelWindow.userInteractionEnabled = NO;
        _panelWindow.hidden = YES;
    }
}

- (UIImage *)captureImageForHostWindow:(UIWindow *)hostWindow {
    if (!hostWindow) {
        return nil;
    }

    UIGraphicsBeginImageContextWithOptions(hostWindow.bounds.size, NO, UIScreen.mainScreen.scale);
    BOOL drawn = [hostWindow drawViewHierarchyInRect:hostWindow.bounds afterScreenUpdates:YES];
    if (!drawn) {
        [hostWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)restorePanelAfterScreenDelay:(NSTimeInterval)delay {
    NSUInteger restoreGeneration = [self invalidatePendingPanelRestore];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(delay, 0.05) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (restoreGeneration != strongSelf->_panelRestoreGeneration || [AnClickRecorder shared].isRecording) {
            return;
        }
        [strongSelf restorePanelAfterExternalTap];
    });
}

- (void)restorePanelAfterExternalTap {
    if (!_panelWindow) {
        return;
    }

    [self invalidatePendingPanelRestore];
    [self attachPanelWindowToActiveSceneIfNeeded];
    _panelWindow.windowLevel = UIWindowLevelAlert + 1000;
    _panelWindow.alpha = 1.0;
    _panelWindow.userInteractionEnabled = YES;
    _panelWindow.hidden = NO;
    if (_panelExpanded) {
        [self expandPanel];
    } else {
        [self collapsePanel];
    }
}

- (void)showTapMarkerAtScreenPoint:(CGPoint)screenPoint inWindow:(UIWindow *)hostWindow {
    [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow duration:0.75];
}

- (void)showTapMarkerAtScreenPoint:(CGPoint)screenPoint inWindow:(UIWindow *)hostWindow duration:(NSTimeInterval)duration {
    if (![self shouldShowRunTraceNow]) {
        return;
    }
    [_tapMarkerView removeFromSuperview];
    if (!hostWindow) {
        return;
    }

    CGPoint windowPoint = [hostWindow convertPoint:screenPoint fromWindow:nil];
    CGFloat size = 34.0;
    UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    marker.center = windowPoint;
    marker.userInteractionEnabled = NO;
    marker.backgroundColor = UIColor.clearColor;
    marker.layer.cornerRadius = size * 0.5;
    marker.layer.borderWidth = 2.0;
    marker.layer.borderColor = UIColor.systemOrangeColor.CGColor;

    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(size * 0.5 - 3, size * 0.5 - 3, 6, 6)];
    dot.backgroundColor = UIColor.systemOrangeColor;
    dot.layer.cornerRadius = 3;
    dot.userInteractionEnabled = NO;
    [marker addSubview:dot];

    [hostWindow addSubview:marker];
    _tapMarkerView = marker;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(duration, 0.4) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [marker removeFromSuperview];
        if (strongSelf->_tapMarkerView == marker) {
            strongSelf->_tapMarkerView = nil;
        }
    });
}

- (void)showRecognitionBoxForScreenRect:(CGRect)screenRect score:(double)score inWindow:(UIWindow *)hostWindow duration:(NSTimeInterval)duration {
    if (![self shouldShowRunTraceNow]) {
        return;
    }
    [_recognitionBoxView removeFromSuperview];
    if (!hostWindow || CGRectIsEmpty(screenRect)) {
        return;
    }

    CGPoint topLeft = [hostWindow convertPoint:screenRect.origin fromWindow:nil];
    CGPoint bottomRight = [hostWindow convertPoint:CGPointMake(CGRectGetMaxX(screenRect), CGRectGetMaxY(screenRect)) fromWindow:nil];
    CGRect windowRect = CGRectStandardize(CGRectMake(topLeft.x,
                                                     topLeft.y,
                                                     bottomRight.x - topLeft.x,
                                                     bottomRight.y - topLeft.y));

    UIView *overlay = [[UIView alloc] initWithFrame:hostWindow.bounds];
    overlay.userInteractionEnabled = NO;
    overlay.backgroundColor = UIColor.clearColor;

    UIView *box = [[UIView alloc] initWithFrame:CGRectInset(windowRect, -2, -2)];
    box.userInteractionEnabled = NO;
    box.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.08];
    box.layer.borderColor = UIColor.systemRedColor.CGColor;
    box.layer.borderWidth = 3.0;
    box.layer.cornerRadius = 3;
    [overlay addSubview:box];

    UILabel *scoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(MAX(4.0, CGRectGetMinX(windowRect)),
                                                                    MAX(4.0, CGRectGetMinY(windowRect) - 24.0),
                                                                    108.0,
                                                                    20.0)];
    scoreLabel.text = [NSString stringWithFormat:@"%.2f", score];
    scoreLabel.textColor = UIColor.whiteColor;
    scoreLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    scoreLabel.textAlignment = NSTextAlignmentCenter;
    scoreLabel.backgroundColor = [UIColor colorWithRed:0.82 green:0.06 blue:0.05 alpha:0.88];
    scoreLabel.layer.cornerRadius = 4;
    scoreLabel.clipsToBounds = YES;
    [overlay addSubview:scoreLabel];

    [hostWindow addSubview:overlay];
    _recognitionBoxView = overlay;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(duration, 0.6) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [overlay removeFromSuperview];
        if (strongSelf->_recognitionBoxView == overlay) {
            strongSelf->_recognitionBoxView = nil;
        }
    });
}

- (void)beginSuccessBranchTemplateCapture {
    [self beginBranchTemplateCaptureForSuccess:YES];
}

- (void)beginFailureBranchTemplateCapture {
    [self beginBranchTemplateCaptureForSuccess:NO];
}

- (void)beginBranchTemplateCaptureForSuccess:(BOOL)success {
    if (![self currentActionIsRecognitionMode]) {
        _statusLabel.text = success ? @"识别动作才有成功后截图" : @"识别动作才有失败后截图";
        return;
    }
    AnClickActionMode mode = success
        ? [self normalizedImageActionMode:_imageActionMode]
        : [self normalizedFailureActionMode:_failureActionMode];
    if (mode != AnClickActionModeImage) {
        _statusLabel.text = success ? @"先选择成功后识图" : @"先选择失败后识图";
        return;
    }
    if (![self ensureMutableBranchActionConfigForSuccess:success mode:mode]) {
        _statusLabel.text = @"先保存主任务";
        return;
    }
    _branchTemplateCaptureActive = YES;
    _branchTemplateCaptureSuccess = success;
    _branchTemplateCaptureMode = mode;
    [self beginTemplateCapture];
}

- (void)showMultiTapMarkersForScreenPoints:(NSArray<NSValue *> *)points inWindow:(UIWindow *)hostWindow duration:(NSTimeInterval)duration {
    if (![self shouldShowRunTraceNow]) {
        return;
    }
    [_operationTraceView removeFromSuperview];
    if (points.count == 0 || !hostWindow) {
        return;
    }

    UIView *overlay = [[UIView alloc] initWithFrame:hostWindow.bounds];
    overlay.userInteractionEnabled = NO;
    overlay.backgroundColor = UIColor.clearColor;
    NSUInteger count = MIN(points.count, AnClickMultiTapMaxPoints);
    for (NSUInteger i = 0; i < count; i++) {
        NSValue *value = points[i];
        if (![value isKindOfClass:NSValue.class]) {
            continue;
        }
        CGPoint center = [hostWindow convertPoint:value.CGPointValue fromWindow:nil];
        CGFloat size = 32.0;
        UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
        marker.center = center;
        marker.userInteractionEnabled = NO;
        marker.backgroundColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.12 alpha:0.12];
        marker.layer.cornerRadius = size * 0.5;
        marker.layer.borderWidth = 2.0;
        marker.layer.borderColor = UIColor.systemOrangeColor.CGColor;

        UILabel *label = [[UILabel alloc] initWithFrame:marker.bounds];
        label.text = [NSString stringWithFormat:@"%lu", (unsigned long)i + 1];
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.65;
        [marker addSubview:label];
        [overlay addSubview:marker];
    }

    [hostWindow addSubview:overlay];
    _operationTraceView = overlay;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(duration, 0.4) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [overlay removeFromSuperview];
        if (strongSelf->_operationTraceView == overlay) {
            strongSelf->_operationTraceView = nil;
        }
    });
}

- (void)showOperationTraceForMode:(AnClickActionMode)mode atPoint:(CGPoint)screenPoint inWindow:(UIWindow *)hostWindow duration:(NSTimeInterval)duration {
    if (!hostWindow) {
        return;
    }

    if (mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeSwipe) {
        [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow duration:duration];
        return;
    }

    if (![self shouldShowRunTraceNow]) {
        return;
    }
    [_operationTraceView removeFromSuperview];

    UIView *overlay = [[UIView alloc] initWithFrame:hostWindow.bounds];
    overlay.userInteractionEnabled = NO;
    overlay.backgroundColor = UIColor.clearColor;

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.frame = overlay.bounds;
    layer.strokeColor = UIColor.systemOrangeColor.CGColor;
    layer.fillColor = UIColor.clearColor.CGColor;
    layer.lineWidth = 3.0;
    layer.lineCap = kCALineCapRound;
    layer.lineJoin = kCALineJoinRound;

    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint center = [hostWindow convertPoint:screenPoint fromWindow:nil];
    if (mode == AnClickActionModeTwoFingerTap) {
        CGFloat distance = 72.0;
        CGPoint left = CGPointMake(center.x - distance * 0.5, center.y);
        CGPoint right = CGPointMake(center.x + distance * 0.5, center.y);
        [path moveToPoint:left];
        [path addLineToPoint:right];
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(left.x - 8, left.y - 8, 16, 16)]];
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(right.x - 8, right.y - 8, 16, 16)]];
    }

    layer.path = path.CGPath;
    [overlay.layer addSublayer:layer];
    [hostWindow addSubview:overlay];
    _operationTraceView = overlay;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(duration, 0.6) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [overlay removeFromSuperview];
        if (strongSelf->_operationTraceView == overlay) {
            strongSelf->_operationTraceView = nil;
        }
    });
}

- (void)performDoubleTapAtPoint:(CGPoint)point interval:(NSTimeInterval)interval {
    [AnClickFakeTouch fastTapAtPoint:point];
    NSTimeInterval safeInterval = MIN(2.0, MAX(0.02, interval));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(safeInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [AnClickFakeTouch fastTapAtPoint:point];
    });
}

- (UIBezierPath *)pathForScreenPoints:(NSArray<NSValue *> *)points inWindow:(UIWindow *)hostWindow {
    UIBezierPath *path = [UIBezierPath bezierPath];
    if (points.count == 0 || !hostWindow) {
        return path;
    }

    CGPoint first = [hostWindow convertPoint:points.firstObject.CGPointValue fromWindow:nil];
    [path moveToPoint:first];
    for (NSUInteger i = 1; i < points.count; i++) {
        CGPoint point = [hostWindow convertPoint:points[i].CGPointValue fromWindow:nil];
        [path addLineToPoint:point];
    }
    return path;
}

- (void)showTrajectoryForScreenPoints:(NSArray<NSValue *> *)points inWindow:(UIWindow *)hostWindow duration:(NSTimeInterval)duration {
    if (![self shouldShowRunTraceNow]) {
        return;
    }
    [_trajectoryView removeFromSuperview];
    if (points.count < 2 || !hostWindow) {
        return;
    }

    UIView *view = [[UIView alloc] initWithFrame:hostWindow.bounds];
    view.userInteractionEnabled = NO;
    view.backgroundColor = UIColor.clearColor;

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.frame = view.bounds;
    layer.path = [self pathForScreenPoints:points inWindow:hostWindow].CGPath;
    layer.strokeColor = UIColor.systemGreenColor.CGColor;
    layer.fillColor = UIColor.clearColor.CGColor;
    layer.lineWidth = 4.0;
    layer.lineCap = kCALineCapRound;
    layer.lineJoin = kCALineJoinRound;
    [view.layer addSublayer:layer];

    [hostWindow addSubview:view];
    _trajectoryView = view;
    _trajectoryLayer = layer;

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(duration, 0.4) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [view removeFromSuperview];
        if (strongSelf->_trajectoryView == view) {
            strongSelf->_trajectoryView = nil;
            strongSelf->_trajectoryLayer = nil;
        }
    });
}

- (void)updateLiveTrajectoryInWindow:(UIWindow *)hostWindow {
    if (!_trajectoryLayer || !hostWindow) {
        return;
    }
    _trajectoryLayer.path = [self pathForScreenPoints:_liveSwipePoints inWindow:hostWindow].CGPath;
}

- (NSArray<NSValue *> *)recordedSwipePointsAnchoredAtPoint:(CGPoint)anchorPoint {
    if (_recordedSwipePoints.count < 2) {
        return @[];
    }

    CGPoint first = _recordedSwipePoints.firstObject.CGPointValue;
    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:_recordedSwipePoints.count];
    for (NSValue *value in _recordedSwipePoints) {
        CGPoint point = value.CGPointValue;
        CGPoint anchored = CGPointMake(anchorPoint.x + point.x - first.x,
                                       anchorPoint.y + point.y - first.y);
        [points addObject:[NSValue valueWithCGPoint:anchored]];
    }
    return points;
}

- (void)performSelectedActionAtPoint:(CGPoint)point inWindow:(UIWindow *)hostWindow {
    [self performSelectedActionAtPoint:point inWindow:hostWindow preparePanel:YES];
}

- (void)performSelectedActionAtPoint:(CGPoint)point inWindow:(UIWindow *)hostWindow preparePanel:(BOOL)preparePanel {
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    if (_actionMode == AnClickActionModeNone) {
        _statusLabel.text = @"先选择动作";
        return;
    }

    if (preparePanel) {
        [self preparePanelForExternalTapWithHostWindow:hostWindow];
    }

    if (_actionMode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = (_hasManualSwipeAnchor && _hasManualSwipeEndPoint)
            ? [self manualSwipePath]
            : [self recordedSwipePointsAnchoredAtPoint:point];
        if (path.count < 2) {
            _statusLabel.text = _hasManualSwipeAnchor ? @"先取终点" : @"先取起点";
            return;
        }
        [self showTrajectoryForScreenPoints:path inWindow:hostWindow duration:AnClickDefaultSwipeDuration];
        [AnClickFakeTouch playPath:path duration:AnClickDefaultSwipeDuration];
        _statusLabel.text = [NSString stringWithFormat:@"滑 %.0f,%.0f", point.x, point.y];
        return;
    }

    NSTimeInterval pressDuration = [self normalizedLongPressDuration:_longPressDuration];
    NSTimeInterval operationTraceDuration = (_actionMode == AnClickActionModeLongPress) ? [self longPressOperationDurationForDuration:pressDuration] : 0.6;
    [self showOperationTraceForMode:_actionMode atPoint:point inWindow:hostWindow duration:operationTraceDuration];
    if (_actionMode == AnClickActionModeDoubleTap) {
        NSTimeInterval interval = _editingTaskModel ? [self doubleTapIntervalForTask:[self taskDictionaryForModel:_editingTaskModel]] : AnClickDefaultDoubleTapInterval;
        [self performDoubleTapAtPoint:point interval:interval];
        _statusLabel.text = [NSString stringWithFormat:@"双 %.0f,%.0f", point.x, point.y];
    } else if (_actionMode == AnClickActionModeLongPress) {
        _longPressHolding = YES;
        [AnClickFakeTouch longPressAtPoint:point duration:pressDuration];
        _statusLabel.text = [NSString stringWithFormat:@"长按%@ %.0f,%.0f", [self longPressDurationSummaryText:pressDuration], point.x, point.y];
        [self refreshModeButtons];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(operationTraceDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf->_longPressHolding = NO;
            if (strongSelf->_actionMode == AnClickActionModeLongPress) {
                strongSelf->_statusLabel.text = @"长按完成";
                [strongSelf refreshModeButtons];
            }
        });
    } else if (_actionMode == AnClickActionModeTwoFingerTap) {
        [AnClickFakeTouch twoFingerTapAtPoint:point distance:72.0];
        _statusLabel.text = [NSString stringWithFormat:@"二指 %.0f,%.0f", point.x, point.y];
    } else if (_actionMode == AnClickActionModeTap ||
               _actionMode == AnClickActionModeImage ||
               _actionMode == AnClickActionModeOCR ||
               _actionMode == AnClickActionModeColor) {
        [AnClickFakeTouch fastTapAtPoint:point];
        _statusLabel.text = [NSString stringWithFormat:@"点 %.0f,%.0f", point.x, point.y];
    } else {
        _statusLabel.text = @"动作不可用";
    }
}

- (NSArray<NSValue *> *)manualSwipePath {
    if (_hasManualSwipeAnchor && _hasManualSwipeEndPoint) {
        return @[
            [NSValue valueWithCGPoint:_manualSwipeAnchor],
            [NSValue valueWithCGPoint:_manualSwipeEndPoint],
        ];
    }
    if (_recordedSwipePoints.count < 2) {
        return @[];
    }
    if (_hasManualSwipeAnchor) {
        return [self recordedSwipePointsAnchoredAtPoint:_manualSwipeAnchor];
    }
    return [_recordedSwipePoints copy];
}

- (NSArray<NSValue *> *)trajectoryPointsForRecordedEvents:(NSArray<NSDictionary *> *)events {
    if (events.count == 0) {
        return @[];
    }

    NSMutableArray<NSValue *> *points = [NSMutableArray array];
    for (NSDictionary *event in events) {
        if (![event isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSNumber *typeNumber = event[@"type"];
        NSNumber *xNumber = event[@"x"];
        NSNumber *yNumber = event[@"y"];
        if (!typeNumber || !xNumber || !yNumber) {
            continue;
        }
        NSInteger type = typeNumber.integerValue;
        if (type == 0 || type == 1 || type == 2) {
            [points addObject:[NSValue valueWithCGPoint:CGPointMake(xNumber.doubleValue, yNumber.doubleValue)]];
            if (points.count >= AnClickMacroMaxTrajectoryPoints) {
                break;
            }
        }
    }
    return points;
}

- (NSArray<NSValue *> *)recordedMacroTrajectoryPoints {
    NSArray<NSDictionary *> *events = _hasRecordedMacroScreenSize
        ? [self resolvedRecordedEvents:_recordedMacroEvents fromScreenSize:_recordedMacroScreenSize]
        : (_recordedMacroEvents ?: @[]);
    return [self trajectoryPointsForRecordedEvents:events];
}

- (NSTimeInterval)durationForRecordedEvents:(NSArray<NSDictionary *> *)events {
    return [self durationForRecordedEvents:events playbackSpeed:1.0];
}

- (NSTimeInterval)durationForRecordedEvents:(NSArray<NSDictionary *> *)events playbackSpeed:(double)playbackSpeed {
    double speed = [self normalizedMacroPlaybackSpeed:playbackSpeed];
    NSTimeInterval duration = 0.0;
    for (NSDictionary *event in events) {
        if (![event isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSNumber *timestampNumber = event[@"timestamp"];
        if (timestampNumber) {
            duration = MIN(AnClickMacroMaxPlaybackDuration, MAX(duration, timestampNumber.doubleValue));
            if (duration >= AnClickMacroMaxPlaybackDuration) {
                break;
            }
        }
    }
    return MAX(0.35, duration / speed + 0.20);
}

- (void)autosaveSelectedTaskIfPossible {
    if (_editingBranchRecognitionConfig) {
        return;
    }
    if (!_taskEditorVisible ||
        _selectedTaskIndex < 0 ||
        _selectedTaskIndex >= (NSInteger)_taskItems.count ||
        ![self taskModelAtIndex:(NSUInteger)_selectedTaskIndex]) {
        return;
    }
    if (_actionMode == AnClickActionModeMacro && _recordedMacroEvents.count == 0) {
        return;
    }

    AnClickTaskModel *model = _editingTaskModel ?: [self taskEditorModelByMergingRuntimeState];
    _taskItems[(NSUInteger)_selectedTaskIndex] = [model copy];
    _editingTaskModel = [model copy];
    [self persistCurrentTaskList];
    [self refreshCollapsedButtonTitle];
}

- (BOOL)storeNetworkRequestConfigInTask:(NSMutableDictionary *)task requireComplete:(BOOL)requireComplete {
    if (_networkURL.length > 0) {
        if (![self normalizedNetworkURLString:_networkURL]) {
            _statusLabel.text = @"网络链接无效";
            return NO;
        }
        task[@"networkURL"] = _networkURL;
    } else if (requireComplete) {
        _statusLabel.text = @"先填网络链接";
        return NO;
    }
    task[@"networkMethod"] = [self normalizedNetworkMethodFromPostFlag:_networkUsesPost];
    task[@"networkUsesPost"] = @(_networkUsesPost);
    BOOL canUseOCRResult = _actionMode == AnClickActionModeOCR &&
        _imageActionMode == AnClickActionModeNetwork &&
        _networkUsesPost;
    task[@"networkPostBodyUsesOCRResult"] = @(canUseOCRResult);
    if (_networkUsesPost) {
        NSArray<NSDictionary *> *pairs = [self configuredNetworkPostPairs];
        if (pairs.count == 0) {
            if (requireComplete) {
                _statusLabel.text = @"先填POST键值";
            }
            return !requireComplete;
        }
        task[@"networkPostPairs"] = pairs;
    }
    if (!_networkUsesPost && _networkPostBody.length > 0) {
        task[@"networkPostBody"] = _networkPostBody;
    }
    return YES;
}

- (BOOL)networkHasJudgementConditionWithTrueText:(NSString *)trueText falseText:(NSString *)falseText {
    return [_networkService hasJudgementConditionWithTrueText:trueText falseText:falseText];
}

- (BOOL)currentNetworkJudgementHasCondition {
    return [self networkHasJudgementConditionWithTrueText:_networkContainsText falseText:_networkFalseText];
}

- (void)loadNetworkRequestConfigFromTask:(NSDictionary *)task {
    _networkURL = [self trimmedActionDescription:task[@"networkURL"]];
    _networkPostBody = [self trimmedActionDescription:task[@"networkPostBody"]];
    _networkUsesPost = [[self networkMethodForTask:task] isEqualToString:@"POST"];
    _networkPostPairs = [self mutableNetworkPostPairsFromTask:task];
    _networkPostBodyUsesOCRResult = _networkUsesPost &&
        [self modeForTask:task] == AnClickActionModeOCR &&
        ([task[@"networkPostBodyUsesOCRResult"] boolValue] || [task[@"networkPostPairs"] isKindOfClass:NSArray.class]);
}

- (NSString *)pointCoordinateText:(CGPoint)point {
    return [NSString stringWithFormat:@"%.0f,%.0f", point.x, point.y];
}

- (NSString *)recognitionActionPointTargetForTask:(NSDictionary *)task
                                       actionMode:(AnClickActionMode)actionMode
                                          success:(BOOL)success {
    if (![self recognitionActionModeNeedsPoint:actionMode]) {
        return nil;
    }

    NSDictionary *branchConfig = [self branchActionConfigForTask:task success:success expectedMode:actionMode];
    if (branchConfig) {
        return [self taskListPointSummaryForTask:branchConfig];
    }

    if (success) {
        NSValue *successPointValue = task[@"successPoint"];
        if (successPointValue) {
            CGPoint point = [self resolvedPoint:successPointValue.CGPointValue
                                        forTask:task
                                  screenSizeKey:@"successPointScreenSize"];
            return [self pointCoordinateText:point];
        }

        BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
        if (useMatchPoint) {
            return @"识别中心";
        }

        NSValue *customPointValue = task[@"point"];
        if (customPointValue) {
            CGPoint point = [self resolvedPointForTask:task fallbackPoint:customPointValue.CGPointValue];
            return [self pointCoordinateText:point];
        }
        return @"未取点";
    }

    CGPoint failurePoint = CGPointZero;
    if ([self failureActionPointForTask:task point:&failurePoint]) {
        return [self pointCoordinateText:failurePoint];
    }
    return @"未取点";
}

- (NSString *)recognitionBranchActionSummaryForTask:(NSDictionary *)task
                                            success:(BOOL)success
                                      includePrefix:(BOOL)includePrefix {
    return [self recognitionBranchActionSummaryForTask:task
                                               success:success
                                         includePrefix:includePrefix
                                                 depth:0];
}

- (NSString *)recognitionNestedSummaryForTask:(NSDictionary *)task depth:(NSUInteger)depth {
    if (depth >= 3) {
        return [self actionNameForMode:[self modeForTask:task]];
    }

    NSString *successText = [self recognitionBranchActionSummaryForTask:task
                                                                success:YES
                                                          includePrefix:NO
                                                                  depth:depth + 1] ?: @"无动作";
    NSString *failureText = [self recognitionBranchActionSummaryForTask:task
                                                                success:NO
                                                          includePrefix:NO
                                                                  depth:depth + 1] ?: @"无动作";
    return [NSString stringWithFormat:@"%@：成功->%@；失败->%@",
                                      [self actionNameForMode:[self modeForTask:task]],
                                      successText,
                                      failureText];
}

- (NSString *)inlineActionSummaryForTask:(NSDictionary *)task depth:(NSUInteger)depth {
    if (![task isKindOfClass:NSDictionary.class]) {
        return @"未设置";
    }
    AnClickActionMode mode = [self modeForTask:task];
    NSString *name = [self actionNameForMode:mode];
    if ([self modeIsRecognitionTask:mode]) {
        return [self recognitionNestedSummaryForTask:task depth:depth];
    }
    switch (mode) {
        case AnClickActionModeTap: {
            NSInteger repeat = [self repeatCountForTask:task];
            NSString *repeatText = repeat > 1 ? [NSString stringWithFormat:@" · %ld次", (long)repeat] : @"";
            return [NSString stringWithFormat:@"%@ %@%@", name, [self taskListPointSummaryForTask:task], repeatText];
        }
        case AnClickActionModeDoubleTap:
            return [NSString stringWithFormat:@"%@ %@ · 间隔%@",
                    name,
                    [self taskListPointSummaryForTask:task],
                    [self millisecondsSummaryTextForDuration:[self doubleTapIntervalForTask:task]]];
        case AnClickActionModeLongPress:
            return [NSString stringWithFormat:@"%@ %@ · %@",
                    name,
                    [self taskListPointSummaryForTask:task],
                    [self longPressDurationSummaryText:[self longPressDurationForTask:task]]];
        case AnClickActionModeTwoFingerTap: {
            NSUInteger count = [self storedMultiTapPointsForTask:task].count;
            return [NSString stringWithFormat:@"%@ %lu点", name, (unsigned long)count];
        }
        case AnClickActionModeSwipe:
            return [NSString stringWithFormat:@"%@ %@ -> %@ · %@",
                    name,
                    [self taskListSwipePointSummaryForTask:task index:0],
                    [self taskListSwipePointSummaryForTask:task index:1],
                    [self millisecondsSummaryTextForDuration:[self swipeDurationForTask:task]]];
        case AnClickActionModeNetwork: {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            return [NSString stringWithFormat:@"%@ %@ %@", name, [self networkMethodForTask:task], url.length > 0 ? url : @"未填链接"];
        }
        case AnClickActionModeDelay:
            return [NSString stringWithFormat:@"%@ %@", name, [self millisecondsSummaryTextForDuration:[self delayForTask:task]]];
        case AnClickActionModeMacro: {
            NSArray *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
            return [NSString stringWithFormat:@"%@ %lu步 %.2fx", name, (unsigned long)events.count, [self macroPlaybackSpeedForTask:task]];
        }
        case AnClickActionModeJump: {
            id value = task[@"jumpTaskIndex"] ?: task[@"targetTaskIndex"] ?: task[@"jumpTaskId"];
            NSInteger targetIndex = [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : -1;
            return targetIndex >= 0 ? [NSString stringWithFormat:@"跳转任务%ld", (long)targetIndex + 1] : @"跳转未选任务";
        }
        default:
            return name;
    }
}

- (NSString *)recognitionBranchActionSummaryForTask:(NSDictionary *)task
                                            success:(BOOL)success
                                      includePrefix:(BOOL)includePrefix
                                              depth:(NSUInteger)depth {
    if (![self modeIsJudgementTask:[self modeForTask:task]]) {
        return nil;
    }

    AnClickActionMode actionMode = success ? [self successActionModeForTask:task] : [self failureActionModeForTask:task];
    NSString *prefix = includePrefix ? (success ? @"成功后" : @"失败后") : @"";
    if (actionMode == AnClickActionModeNone) {
        return includePrefix ? [prefix stringByAppendingString:@"无动作"] : @"无动作 继续后续";
    }

    NSDictionary *config = [self branchActionConfigForTask:task success:success expectedMode:actionMode];
    if (config) {
        return [NSString stringWithFormat:@"%@%@", prefix, [self inlineActionSummaryForTask:config depth:depth + 1]];
    }

    if (actionMode == AnClickActionModeNetwork) {
        return [NSString stringWithFormat:@"%@网络未设置动作", prefix];
    }

    if (actionMode == AnClickActionModeJump) {
        NSInteger taskIndex = [self validRecognitionJumpIndexForTask:task success:success];
        return taskIndex >= 0
            ? [NSString stringWithFormat:@"%@跳转任务%ld", prefix, (long)taskIndex + 1]
            : [NSString stringWithFormat:@"%@跳转未选任务", prefix];
    }

    if ([self modeIsRecognitionTask:actionMode]) {
        return [NSString stringWithFormat:@"%@%@未设置动作", prefix, [self actionNameForMode:actionMode]];
    }

    NSString *pointTarget = [self recognitionActionPointTargetForTask:task actionMode:actionMode success:success];
    if (pointTarget.length > 0) {
        return [NSString stringWithFormat:@"%@%@ %@", prefix, [self actionNameForMode:actionMode], pointTarget];
    }
    return [NSString stringWithFormat:@"%@%@", prefix, [self actionNameForMode:actionMode]];
}

- (NSString *)recognitionFailureActionSummaryForTask:(NSDictionary *)task {
    return [self recognitionBranchActionSummaryForTask:task success:NO includePrefix:YES];
}

- (NSString *)recognitionSuccessActionSummaryForTask:(NSDictionary *)task {
    return [self recognitionBranchActionSummaryForTask:task success:YES includePrefix:YES];
}

- (NSString *)recognitionConditionSummaryForTask:(NSDictionary *)task {
    AnClickActionMode mode = [self modeForTask:task];
    if (mode == AnClickActionModeImage) {
        NSString *templatePath = task[@"templatePath"];
        BOOL hasTemplate = templatePath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:templatePath];
        double threshold = [task[@"threshold"] respondsToSelector:@selector(doubleValue)]
            ? MIN(1.0, MAX(0.0, [task[@"threshold"] doubleValue]))
            : 0.80;
        return [NSString stringWithFormat:@"识图 %@ · 阈值%.2f", hasTemplate ? @"已截图" : @"未截图", threshold];
    }
    if (mode == AnClickActionModeOCR) {
        NSString *text = [self trimmedActionDescription:task[@"ocrText"]];
        AnClickOCRMatchMode matchMode = [self ocrMatchModeForTask:task];
        return [NSString stringWithFormat:@"识字 %@ · %@", [self ocrMatchModeTitleForMode:matchMode], [self ocrDisplayTextForText:text matchMode:matchMode]];
    }
    if (mode == AnClickActionModeColor) {
        double tolerance = [task[@"colorTolerance"] respondsToSelector:@selector(doubleValue)]
            ? MIN(255.0, MAX(0.0, [task[@"colorTolerance"] doubleValue]))
            : 18.0;
        return [NSString stringWithFormat:@"识色 %@ · 容差%.0f", [self colorPatternSummaryForTask:task], tolerance];
    }
    return @"未设置";
}

- (NSString *)recognitionTimingFlowSummaryForTask:(NSDictionary *)task {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    if ([self recognitionRetryUntilFoundForTask:task]) {
        [parts addObject:@"识别到为止"];
        [parts addObject:[NSString stringWithFormat:@"识别间隔%@", [self millisecondsSummaryTextForDuration:[self recognitionRetryIntervalForTask:task]]]];
    } else {
        NSInteger repeat = MAX(1, [self repeatCountForTask:task]);
        [parts addObject:repeat > 1 ? [NSString stringWithFormat:@"尝试%ld次", (long)repeat] : @"识别一次"];
        NSTimeInterval interval = MAX([self actionIntervalForTask:task], AnClickRecognitionCaptureDelay);
        if (repeat > 1 && interval > 0.001) {
            [parts addObject:[NSString stringWithFormat:@"识别间隔%@", [self millisecondsSummaryTextForDuration:interval]]];
        }
    }

    CGFloat jitterRadius = [self jitterRadiusForTask:task];
    if (jitterRadius > 0.001) {
        [parts addObject:[NSString stringWithFormat:@"抖动%.0fpx", jitterRadius]];
    }
    return [parts componentsJoinedByString:@" · "];
}

- (NSArray<NSDictionary *> *)recognitionFlowRowsForTask:(NSDictionary *)task {
    return @[
        @{@"tag": @"成功",
          @"text": [self recognitionBranchActionSummaryForTask:task success:YES includePrefix:NO] ?: @"无动作",
          @"color": [self themeSuccessColor]},
        @{@"tag": @"失败",
          @"text": [self recognitionBranchActionSummaryForTask:task success:NO includePrefix:NO] ?: @"无动作 继续后续",
          @"color": [self themeDangerColor]},
    ];
}

- (NSString *)commonSuffixForTask:(NSDictionary *)task {
    if ([self modeIsRecognitionTask:[self modeForTask:task]]) {
        NSMutableArray<NSString *> *recognitionParts = [NSMutableArray array];
        NSString *successActionSummary = [self recognitionSuccessActionSummaryForTask:task];
        if (successActionSummary.length > 0) {
            [recognitionParts addObject:successActionSummary];
        }
        NSString *failureActionSummary = [self recognitionFailureActionSummaryForTask:task];
        if (failureActionSummary.length > 0) {
            [recognitionParts addObject:failureActionSummary];
        }
        return recognitionParts.count > 0 ? [@" " stringByAppendingString:[recognitionParts componentsJoinedByString:@" "]] : @"";
    }

    if ([self modeForTask:task] == AnClickActionModeDelay) {
        return @"";
    }

    NSTimeInterval delay = [task[@"delay"] doubleValue];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSInteger repeat = MAX(1, [task[@"repeat"] integerValue]);
    if (delay > 0.001) {
        if ([task[@"randomDelay"] boolValue]) {
            NSString *minimum = delay >= 1.0 ? @"1000毫秒" : @"0毫秒";
            [parts addObject:[NSString stringWithFormat:@"随机等待%@-%@", minimum, [self millisecondsSummaryTextForDuration:delay]]];
        } else {
            [parts addObject:[NSString stringWithFormat:@"等待%@", [self millisecondsSummaryTextForDuration:delay]]];
        }
    }
    if ([self recognitionRetryUntilFoundForTask:task]) {
        [parts addObject:@"识别到为止"];
        [parts addObject:[NSString stringWithFormat:@"识别间隔%@", [self millisecondsSummaryTextForDuration:[self recognitionRetryIntervalForTask:task]]]];
    } else {
        if (repeat > 1 || delay > 0.001) {
            [parts addObject:[NSString stringWithFormat:@"次%ld", (long)repeat]];
        }
    }
    AnClickActionMode mode = [self modeForTask:task];
    if ((mode == AnClickActionModeTap || mode == AnClickActionModeTwoFingerTap) &&
        repeat > 1 &&
        [task[@"interval"] respondsToSelector:@selector(doubleValue)]) {
        [parts addObject:[NSString stringWithFormat:@"点击间隔%@", [self millisecondsSummaryTextForDuration:[self actionIntervalForTask:task]]]];
    }
    if ([self modeForTask:task] == AnClickActionModeMacro) {
        double speed = [self macroPlaybackSpeedForTask:task];
        if (fabs(speed - 1.0) > 0.001) {
            [parts addObject:[NSString stringWithFormat:@"速%@", [self macroPlaybackSpeedSummaryText:speed]]];
        }
    }
    if ([self modeForTask:task] == AnClickActionModeLongPress) {
        [parts addObject:[NSString stringWithFormat:@"长%@", [self longPressDurationSummaryText:[self longPressDurationForTask:task]]]];
    }
    NSString *successActionSummary = [self recognitionSuccessActionSummaryForTask:task];
    if (successActionSummary.length > 0) {
        [parts addObject:successActionSummary];
    }
    NSString *failureActionSummary = [self recognitionFailureActionSummaryForTask:task];
    if (failureActionSummary.length > 0) {
        [parts addObject:failureActionSummary];
    }
    CGFloat jitterRadius = [self jitterRadiusForTask:task];
    if (jitterRadius > 0.001) {
        [parts addObject:[NSString stringWithFormat:@"抖%.0fpx", jitterRadius]];
    }
    if (parts.count == 0) {
        return @"";
    }
    return [@" " stringByAppendingString:[parts componentsJoinedByString:@" "]];
}

- (NSString *)titleForTask:(NSDictionary *)task index:(NSUInteger)index {
    AnClickActionMode mode = [self modeForTask:task];
    NSString *name = (mode == AnClickActionModeNone) ? @"未设置" : [self actionNameForMode:mode];
    NSString *desc = [self trimmedActionDescription:task[@"desc"]];
    NSString *subtitle = desc.length > 0 ? desc : (mode == AnClickActionModeNone ? @"未设置" : @"已设置");
    if (desc.length == 0 && mode == AnClickActionModeMacro) {
        NSArray *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
        double speed = [self macroPlaybackSpeedForTask:task];
        NSString *speedText = fabs(speed - 1.0) > 0.001
            ? [NSString stringWithFormat:@" · 速%@", [self macroPlaybackSpeedSummaryText:speed]]
            : @"";
        subtitle = events.count > 0 ? [NSString stringWithFormat:@"已录 %lu 步%@", (unsigned long)events.count, speedText] : @"未录制";
    } else if (desc.length == 0 && mode == AnClickActionModeTwoFingerTap) {
        NSUInteger count = [self storedMultiTapPointsForTask:task].count;
        subtitle = count >= 2
            ? [NSString stringWithFormat:@"同步点击 %lu 点", (unsigned long)count]
            : ([task[@"point"] isKindOfClass:NSValue.class] ? @"中心二指点击" : @"未取触点");
    } else if (desc.length == 0 && mode == AnClickActionModeOCR) {
        NSString *text = [self trimmedActionDescription:task[@"ocrText"]];
        AnClickOCRMatchMode matchMode = [self ocrMatchModeForTask:task];
        subtitle = text.length > 0
            ? [NSString stringWithFormat:@"识字 · %@ · %@", [self ocrMatchModeTitleForMode:matchMode], [self ocrDisplayTextForText:text matchMode:matchMode]]
            : @"未设置文字";
    } else if (desc.length == 0 && mode == AnClickActionModeColor) {
        subtitle = [self colorPatternSummaryForTask:task];
    } else if (desc.length == 0 && mode == AnClickActionModeImage) {
        subtitle = [NSString stringWithFormat:@"识图 · %@", [self recognitionTargetSummaryForTask:task]];
    } else if (desc.length == 0 && mode == AnClickActionModeNetwork) {
        NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
        NSString *contains = [self trimmedActionDescription:task[@"networkContains"]];
        NSString *falseText = [self trimmedActionDescription:task[@"networkFalse"]];
        NSString *method = [self networkMethodForTask:task];
        BOOL requestOnly = [task[@"networkRequestOnly"] boolValue];
        if (url.length == 0) {
            subtitle = @"未设置链接";
        } else if (requestOnly) {
            subtitle = [NSString stringWithFormat:@"%@ · %@ 请求一次", url, method];
        } else if (contains.length > 0) {
            subtitle = [NSString stringWithFormat:@"%@ · %@ · 包含 %@ 就运行", url, method, contains];
            if (falseText.length > 0) {
                subtitle = [subtitle stringByAppendingFormat:@" · 包含 %@ 就不运行", falseText];
            }
        } else if (falseText.length > 0) {
            subtitle = [NSString stringWithFormat:@"%@ · %@ · 未命中不运行就继续 · 包含 %@ 就不运行", url, method, falseText];
        } else {
            subtitle = [NSString stringWithFormat:@"%@ · %@ · 缺少判断条件", url, method];
        }
        if (!requestOnly && [self networkHasJudgementConditionWithTrueText:contains falseText:falseText]) {
            subtitle = [subtitle stringByAppendingFormat:@" · %@",
                        [self networkRetryForeverForTask:task]
                            ? @"一直判断"
                            : [NSString stringWithFormat:@"判断%ld次", (long)[self networkRetryLimitForTask:task]]];
        }
        subtitle = [subtitle stringByAppendingFormat:@" · 超时%.0f秒", [self networkTimeoutForTask:task]];
    } else if (desc.length == 0 && mode == AnClickActionModeDelay) {
        subtitle = [NSString stringWithFormat:@"等待%@", [self millisecondsSummaryTextForDuration:[self delayForTask:task]]];
    }
    if (mode != AnClickActionModeNetwork) {
        NSString *suffix = [self commonSuffixForTask:task];
        if (suffix.length > 0) {
            subtitle = [subtitle stringByAppendingString:suffix];
        }
    }
    return [NSString stringWithFormat:@"任务 %lu - %@\n%@", (unsigned long)index + 1, name, subtitle];
}

- (NSString *)shortToastDetail:(NSString *)detail maxLength:(NSUInteger)maxLength {
    NSString *text = [self trimmedActionDescription:detail];
    if (text.length == 0 || maxLength == 0) {
        return @"";
    }
    if (text.length <= maxLength) {
        return text;
    }
    return [[text substringToIndex:maxLength] stringByAppendingString:@"..."];
}

- (NSString *)toastTextForTask:(NSDictionary *)task index:(NSUInteger)index {
    AnClickActionMode mode = [self modeForTask:task];
    NSString *name = (mode == AnClickActionModeNone) ? @"动作" : [self actionNameForMode:mode];
    NSString *detail = [self trimmedActionDescription:task[@"desc"]];
    if (mode == AnClickActionModeOCR) {
        detail = @"定位中";
    } else if (detail.length == 0 && mode == AnClickActionModeTwoFingerTap) {
        detail = [NSString stringWithFormat:@"%lu点同步", (unsigned long)[self storedMultiTapPointsForTask:task].count];
    } else if (detail.length == 0 && mode == AnClickActionModeColor) {
        detail = [self colorPatternSummaryForTask:task];
    } else if (detail.length == 0 && mode == AnClickActionModeNetwork) {
        BOOL requestOnly = [self networkTaskIsOneShot:task];
        detail = [NSString stringWithFormat:@"%@ %@", [self networkMethodForTask:task], requestOnly ? @"仅请求" : @"判断返回"];
    } else if (detail.length == 0 && mode == AnClickActionModeDelay) {
        detail = [NSString stringWithFormat:@"等待%@", [self millisecondsSummaryTextForDuration:[self delayForTask:task]]];
    }

    NSString *prefix = [NSString stringWithFormat:@"任务%lu/%lu %@",
                        (unsigned long)index + 1,
                        (unsigned long)MAX((NSUInteger)1, _taskItems.count),
                        name];
    NSString *shortDetail = [self shortToastDetail:detail maxLength:14];
    return shortDetail.length > 0 ? [prefix stringByAppendingFormat:@" %@", shortDetail] : prefix;
}

- (NSString *)taskFlowTitleForTask:(NSDictionary *)task index:(NSUInteger)index {
    AnClickActionMode mode = [self modeForTask:task];
    NSString *name = (mode == AnClickActionModeNone) ? @"未设置" : [self actionNameForMode:mode];
    NSString *desc = [self trimmedActionDescription:task[@"desc"]];
    NSString *title = [NSString stringWithFormat:@"任务 %lu - %@", (unsigned long)index + 1, name];
    return desc.length > 0 ? [title stringByAppendingFormat:@" · %@", desc] : title;
}

- (UILabel *)taskFlowTagLabelWithText:(NSString *)text color:(UIColor *)color frame:(CGRect)frame {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    label.textColor = color ?: [self themeHighlightColor];
    label.backgroundColor = [(color ?: [self themeHighlightColor]) colorWithAlphaComponent:0.12];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.78;
    label.layer.cornerRadius = 6.0;
    label.clipsToBounds = YES;
    label.userInteractionEnabled = NO;
    return label;
}

- (UILabel *)branchRecognitionDetailLabel {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.hidden = YES;
    label.textColor = [self themePrimaryTextColor];
    label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    label.numberOfLines = 2;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.72;
    return label;
}

- (UILabel *)taskFlowTextLabelWithText:(NSString *)text color:(UIColor *)color frame:(CGRect)frame {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text.length > 0 ? text : @"未设置";
    label.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    label.textColor = color ?: [self themePrimaryTextColor];
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.72;
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    label.userInteractionEnabled = NO;
    return label;
}

- (void)addRecognitionFlowSubviewsToRow:(UIButton *)row task:(NSDictionary *)task index:(NSUInteger)index selected:(BOOL)selected {
    CGFloat width = row.bounds.size.width;
    UIColor *accent = [self accentColorForActionMode:[self modeForTask:task]];

    UIView *rail = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 4.0, row.bounds.size.height)];
    rail.backgroundColor = accent;
    rail.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;
    rail.userInteractionEnabled = NO;
    [row addSubview:rail];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14.0, 8.0, width - 28.0, 22.0)];
    titleLabel.text = [self taskFlowTitleForTask:task index:index];
    titleLabel.textColor = [self themePrimaryTextColor];
    titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    titleLabel.numberOfLines = 1;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.72;
    titleLabel.userInteractionEnabled = NO;
    [row addSubview:titleLabel];

    UIView *connector = [[UIView alloc] initWithFrame:CGRectMake(34.0, 50.0, 1.0, 61.0)];
    connector.backgroundColor = [[self themeSeparatorColor] colorWithAlphaComponent:selected ? 0.72 : 0.52];
    connector.userInteractionEnabled = NO;
    [row addSubview:connector];

    NSArray<NSDictionary *> *flowRows = [self recognitionFlowRowsForTask:task];
    CGFloat tagWidth = 42.0;
    CGFloat startY = 34.0;
    CGFloat step = 22.0;
    for (NSUInteger i = 0; i < flowRows.count; i++) {
        NSDictionary *entry = flowRows[i];
        UIColor *color = [entry[@"color"] isKindOfClass:UIColor.class] ? entry[@"color"] : accent;
        CGFloat y = startY + step * i;
        UILabel *tagLabel = [self taskFlowTagLabelWithText:entry[@"tag"] ?: @"流程"
                                                     color:color
                                                     frame:CGRectMake(14.0, y, tagWidth, 18.0)];
        [row addSubview:tagLabel];

        UILabel *textLabel = [self taskFlowTextLabelWithText:entry[@"text"] ?: @"未设置"
                                                       color:[self themePrimaryTextColor]
                                                       frame:CGRectMake(64.0, y - 1.0, width - 78.0, 20.0)];
        [row addSubview:textLabel];
    }
}

- (AnClickTaskModel *)taskModelAtIndex:(NSUInteger)index {
    if (index >= _taskItems.count) {
        return nil;
    }
    AnClickTaskModel *model = _taskItems[index];
    return [model isKindOfClass:AnClickTaskModel.class] ? model : nil;
}

- (NSMutableDictionary *)taskDictionaryAtIndex:(NSUInteger)index {
    AnClickTaskModel *model = [self taskModelAtIndex:index];
    return model ? [model dictionaryRepresentation] : nil;
}

- (NSString *)taskListHeaderTitleForTask:(NSDictionary *)task index:(NSUInteger)index {
    AnClickActionMode mode = [self modeForTask:task];
    NSString *name = mode == AnClickActionModeNone ? @"未设置" : [self actionNameForMode:mode];
    return [NSString stringWithFormat:@"%02lu %@", (unsigned long)index + 1, name];
}

- (NSString *)taskListSummaryForTask:(NSDictionary *)task index:(NSUInteger)index {
    NSString *title = [self titleForTask:task index:index];
    NSRange newline = [title rangeOfString:@"\n"];
    if (newline.location != NSNotFound && newline.location + 1 < title.length) {
        return [title substringFromIndex:newline.location + 1];
    }
    return title;
}

- (NSString *)taskListCollapsedLineForTask:(NSDictionary *)task index:(NSUInteger)index {
    NSString *summary = [self taskListSummaryForTask:task index:index];
    NSString *prefix = [self taskListHeaderTitleForTask:task index:index];
    if (summary.length == 0 || [summary isEqualToString:@"已设置"]) {
        return prefix;
    }
    return [NSString stringWithFormat:@"%@ · %@", prefix, summary];
}

- (NSString *)taskListExpandedHeaderForTask:(NSDictionary *)task index:(NSUInteger)index {
    AnClickActionMode mode = [self modeForTask:task];
    NSString *name = mode == AnClickActionModeNone ? @"未设置" : [self actionNameForMode:mode];
    if ([self modeIsRecognitionTask:mode]) {
        AnClickActionMode successMode = [self successActionModeForTask:task];
        AnClickActionMode failureMode = [self failureActionModeForTask:task];
        NSMutableArray<NSString *> *branchParts = [NSMutableArray array];
        if (successMode != AnClickActionModeNone) {
            [branchParts addObject:[NSString stringWithFormat:@"成:%@", [self actionNameForMode:successMode]]];
        }
        if (failureMode != AnClickActionModeNone) {
            [branchParts addObject:[NSString stringWithFormat:@"败:%@", [self actionNameForMode:failureMode]]];
        }
        if (branchParts.count > 0) {
            name = [NSString stringWithFormat:@"%@ · %@", name, [branchParts componentsJoinedByString:@" · "]];
        }
    }
    return [NSString stringWithFormat:@"%02lu 【%@】 点击查看详情", (unsigned long)index + 1, name];
}

- (NSString *)taskListIconNameForMode:(AnClickActionMode)mode {
    switch (mode) {
        case AnClickActionModeTap:
        case AnClickActionModeDoubleTap:
        case AnClickActionModeTwoFingerTap:
            return @"hand.tap.fill";
        case AnClickActionModeLongPress:
            return @"hand.point.up.left.fill";
        case AnClickActionModeSwipe:
            return @"arrow.left.and.right";
        case AnClickActionModeImage:
            return @"photo.fill";
        case AnClickActionModeMacro:
            return @"record.circle.fill";
        case AnClickActionModeOCR:
            return @"text.viewfinder";
        case AnClickActionModeColor:
            return @"eyedropper.full";
        case AnClickActionModeNetwork:
            return @"network";
        case AnClickActionModeJump:
            return @"arrow.triangle.branch";
        case AnClickActionModeDelay:
            return @"clock.fill";
        default:
            return @"circle";
    }
}

- (UILabel *)taskListLabelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color lines:(NSInteger)lines {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text ?: @"";
    label.font = font;
    label.textColor = color ?: [self themePrimaryTextColor];
    label.numberOfLines = lines;
    label.adjustsFontSizeToFitWidth = lines == 1;
    label.minimumScaleFactor = 0.72;
    label.lineBreakMode = lines == 1 ? NSLineBreakByTruncatingMiddle : NSLineBreakByWordWrapping;
    return label;
}

- (UIView *)taskListMetricViewWithTitle:(NSString *)title value:(NSString *)value tint:(UIColor *)tint {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.backgroundColor = [UIColor colorWithRed:0.944 green:0.947 blue:0.965 alpha:1.0];
    view.layer.cornerRadius = 6.0;
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.42].CGColor;

    UILabel *valueLabel = [self taskListLabelWithText:value.length > 0 ? value : @"-"
                                                font:[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium]
                                               color:tint ?: [self themePrimaryTextColor]
                                               lines:1];
    valueLabel.textAlignment = NSTextAlignmentCenter;
    [view addSubview:valueLabel];
    [NSLayoutConstraint activateConstraints:@[
        [valueLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:4.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:6.0],
        [valueLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-6.0],
        [valueLabel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-4.0],
        [view.heightAnchor constraintEqualToConstant:28.0],
    ]];
    return view;
}

- (UILabel *)taskListCaptionWithText:(NSString *)text {
    UILabel *label = [self taskListLabelWithText:text
                                            font:[UIFont systemFontOfSize:12 weight:UIFontWeightBold]
                                           color:[self themePrimaryTextColor]
                                           lines:1];
    return label;
}

- (UIButton *)taskListSmallButtonWithTitle:(NSString *)title tag:(NSInteger)tag action:(SEL)action tint:(UIColor *)tint {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = tag;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:tint ?: [self themeHighlightColor] forState:UIControlStateNormal];
    button.tintColor = tint ?: [self themeHighlightColor];
    button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    button.backgroundColor = [UIColor colorWithRed:0.940 green:0.943 blue:0.962 alpha:1.0];
    button.layer.cornerRadius = 7.0;
    button.layer.borderWidth = 0.0;
    button.layer.borderColor = UIColor.clearColor.CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIView *)taskListBranchLineWithTitle:(NSString *)title detail:(NSString *)detail success:(BOOL)success {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    UIColor *roleColor = [self branchRoleColorForSuccess:success];
    view.backgroundColor = [roleColor colorWithAlphaComponent:0.08];
    view.layer.cornerRadius = 7.0;
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [roleColor colorWithAlphaComponent:0.32].CGColor;

    UILabel *markLabel = [self taskListLabelWithText:success ? @"✓" : @"✕"
                                               font:[UIFont systemFontOfSize:14 weight:UIFontWeightBold]
                                              color:roleColor
                                              lines:1];
    UILabel *titleLabel = [self taskListLabelWithText:title
                                                font:[UIFont systemFontOfSize:12 weight:UIFontWeightBold]
                                               color:roleColor
                                               lines:1];
    UILabel *detailLabel = [self taskListLabelWithText:detail.length > 0 ? detail : @"未设置"
                                                 font:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium]
                                                color:[self themePrimaryTextColor]
                                                lines:0];
    detailLabel.textAlignment = NSTextAlignmentLeft;
    [view addSubview:markLabel];
    [view addSubview:titleLabel];
    [view addSubview:detailLabel];
    [NSLayoutConstraint activateConstraints:@[
        [view.heightAnchor constraintGreaterThanOrEqualToConstant:38.0],
        [markLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:8.0],
        [markLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:9.0],
        [markLabel.widthAnchor constraintEqualToConstant:15.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:markLabel.trailingAnchor constant:3.0],
        [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:9.0],
        [titleLabel.widthAnchor constraintEqualToConstant:39.0],
        [detailLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:5.0],
        [detailLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-8.0],
        [detailLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:8.0],
        [detailLabel.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-8.0],
    ]];
    return view;
}

- (BOOL)primaryPointForTask:(NSDictionary *)task point:(CGPoint *)point {
    NSValue *pointValue = task[@"point"];
    if ([pointValue isKindOfClass:NSValue.class]) {
        if (point) {
            *point = [self resolvedPointForTask:task fallbackPoint:pointValue.CGPointValue];
        }
        return YES;
    }
    NSArray *path = [task[@"path"] isKindOfClass:NSArray.class] ? task[@"path"] : nil;
    NSValue *pathPoint = path.firstObject;
    if ([pathPoint isKindOfClass:NSValue.class]) {
        if (point) {
            *point = pathPoint.CGPointValue;
        }
        return YES;
    }
    NSArray *multiPoints = [self storedMultiTapPointsForTask:task];
    NSValue *multiPoint = multiPoints.firstObject;
    if ([multiPoint isKindOfClass:NSValue.class]) {
        if (point) {
            *point = multiPoint.CGPointValue;
        }
        return YES;
    }
    return NO;
}

- (NSDictionary *)primaryColorSampleForTask:(NSDictionary *)task {
    NSArray<NSDictionary *> *samples = [self mutableColorSamplesArrayFromObject:task[@"colorPoints"]];
    if (samples.count > 0) {
        return samples.firstObject;
    }
    if ([task[@"colorRed"] respondsToSelector:@selector(integerValue)] &&
        [task[@"colorGreen"] respondsToSelector:@selector(integerValue)] &&
        [task[@"colorBlue"] respondsToSelector:@selector(integerValue)]) {
        return @{
            @"red": @([task[@"colorRed"] integerValue]),
            @"green": @([task[@"colorGreen"] integerValue]),
            @"blue": @([task[@"colorBlue"] integerValue]),
        };
    }
    return nil;
}

- (NSString *)thresholdSummaryForTask:(NSDictionary *)task {
    AnClickActionMode mode = [self modeForTask:task];
    if (mode == AnClickActionModeColor) {
        double tolerance = [task[@"colorTolerance"] respondsToSelector:@selector(doubleValue)]
            ? MIN(255.0, MAX(0.0, [task[@"colorTolerance"] doubleValue]))
            : 18.0;
        return [NSString stringWithFormat:@"%.0f", tolerance];
    }
    if (mode == AnClickActionModeImage) {
        double threshold = [task[@"threshold"] respondsToSelector:@selector(doubleValue)]
            ? MIN(1.0, MAX(0.0, [task[@"threshold"] doubleValue]))
            : 0.80;
        return [NSString stringWithFormat:@"%.0f%%", threshold * 100.0];
    }
    if (mode == AnClickActionModeOCR) {
        return [self ocrMatchModeTitleForMode:[self ocrMatchModeForTask:task]];
    }
    return @"-";
}

- (NSString *)recognitionTargetSummaryForTask:(NSDictionary *)task {
    AnClickActionMode mode = [self modeForTask:task];
    if (mode == AnClickActionModeImage) {
        return [task[@"templatePath"] isKindOfClass:NSString.class] ? @"已截图" : @"未截图";
    }
    if (mode == AnClickActionModeOCR) {
        NSString *text = [self trimmedActionDescription:task[@"ocrText"]];
        return text.length > 0 ? [self ocrDisplayTextForText:text matchMode:[self ocrMatchModeForTask:task]] : @"未设置";
    }
    if (mode == AnClickActionModeColor) {
        NSDictionary *sample = [self primaryColorSampleForTask:task];
        return sample ? [self colorHexStringForSample:sample] : @"未取色";
    }
    return @"-";
}

- (UIView *)taskListDetailLineWithTitle:(NSString *)title value:(NSString *)value tint:(UIColor *)tint {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.backgroundColor = [UIColor colorWithRed:0.944 green:0.947 blue:0.965 alpha:1.0];
    view.layer.cornerRadius = 7.0;
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [[self themeSeparatorColor] colorWithAlphaComponent:0.38].CGColor;

    UILabel *titleLabel = [self taskListLabelWithText:title
                                                font:[UIFont systemFontOfSize:12 weight:UIFontWeightBold]
                                               color:[self themeSecondaryTextColor]
                                               lines:1];
    UILabel *valueLabel = [self taskListLabelWithText:value.length > 0 ? value : @"-"
                                                font:[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]
                                               color:tint ?: [self themePrimaryTextColor]
                                               lines:1];
    valueLabel.textAlignment = NSTextAlignmentRight;
    [view addSubview:titleLabel];
    [view addSubview:valueLabel];
    [NSLayoutConstraint activateConstraints:@[
        [view.heightAnchor constraintEqualToConstant:30.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:8.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        [titleLabel.widthAnchor constraintEqualToConstant:78.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:6.0],
        [valueLabel.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-8.0],
        [valueLabel.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
    ]];
    return view;
}

- (void)addTaskListDetailRowWithTitle:(NSString *)title value:(NSString *)value tint:(UIColor *)tint rows:(NSMutableArray<NSDictionary *> *)rows {
    if (title.length == 0 || !rows) {
        return;
    }
    [rows addObject:@{
        @"title": title,
        @"value": value.length > 0 ? value : @"-",
        @"tint": tint ?: [self themePrimaryTextColor],
    }];
}

- (NSString *)taskListPointSummaryForTask:(NSDictionary *)task {
    CGPoint point = CGPointZero;
    if ([self primaryPointForTask:task point:&point]) {
        return [self pointCoordinateText:point];
    }
    if ([self modeIsRecognitionTask:[self modeForTask:task]] &&
        ([task[@"useMatchPoint"] boolValue] || task[@"useMatchPoint"] == nil)) {
        return @"识别中心";
    }
    return @"未取点";
}

- (NSString *)taskListSwipePointSummaryForTask:(NSDictionary *)task index:(NSUInteger)index {
    NSArray<NSValue *> *path = [self resolvedPathForTask:task];
    if (path.count > index && [path[index] isKindOfClass:NSValue.class]) {
        NSValue *value = path[index];
        return [self pointCoordinateText:value.CGPointValue];
    }
    return @"未取点";
}

- (NSString *)taskListRecognitionRetrySummaryForTask:(NSDictionary *)task {
    if ([self recognitionRetryUntilFoundForTask:task]) {
        return [NSString stringWithFormat:@"直到命中 · 间隔%@", [self millisecondsSummaryTextForDuration:[self recognitionRetryIntervalForTask:task]]];
    }
    NSInteger repeat = MAX(1, [self repeatCountForTask:task]);
    if (repeat <= 1) {
        return @"识别一次";
    }
    NSTimeInterval interval = [self actionIntervalForTask:task];
    return interval > 0.001
        ? [NSString stringWithFormat:@"尝试%ld次 · 间隔%@", (long)repeat, [self millisecondsSummaryTextForDuration:interval]]
        : [NSString stringWithFormat:@"尝试%ld次", (long)repeat];
}

- (NSString *)taskListDetailTitleForTask:(NSDictionary *)task {
    switch ([self modeForTask:task]) {
        case AnClickActionModeTap:
            return @"点击参数";
        case AnClickActionModeDoubleTap:
            return @"双击参数";
        case AnClickActionModeLongPress:
            return @"长按参数";
        case AnClickActionModeSwipe:
            return @"滑动参数";
        case AnClickActionModeTwoFingerTap:
            return @"多指点击参数";
        case AnClickActionModeImage:
            return @"识图参数";
        case AnClickActionModeOCR:
            return @"识字参数";
        case AnClickActionModeColor:
            return @"识色参数";
        case AnClickActionModeNetwork:
            return @"网络参数";
        case AnClickActionModeJump:
            return @"跳转参数";
        case AnClickActionModeDelay:
            return @"延时参数";
        case AnClickActionModeMacro:
            return @"录制参数";
        default:
            return @"动作参数";
    }
}

- (NSArray<NSDictionary *> *)taskListDetailRowsForTask:(NSDictionary *)task tint:(UIColor *)tint {
    NSMutableArray<NSDictionary *> *rows = [NSMutableArray array];
    AnClickActionMode mode = [self modeForTask:task];
    NSInteger repeat = MAX(1, [self repeatCountForTask:task]);
    CGFloat jitter = [self jitterRadiusForTask:task];

    switch (mode) {
        case AnClickActionModeTap:
            [self addTaskListDetailRowWithTitle:@"坐标" value:[self taskListPointSummaryForTask:task] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"重复" value:[NSString stringWithFormat:@"%ld次", (long)repeat] tint:tint rows:rows];
            if (repeat > 1) {
                [self addTaskListDetailRowWithTitle:@"点击间隔" value:[self millisecondsSummaryTextForDuration:[self actionIntervalForTask:task]] tint:tint rows:rows];
            }
            if (jitter > 0.001) {
                [self addTaskListDetailRowWithTitle:@"抖动" value:[NSString stringWithFormat:@"%.0fpx", jitter] tint:tint rows:rows];
            }
            break;
        case AnClickActionModeDoubleTap:
            [self addTaskListDetailRowWithTitle:@"坐标" value:[self taskListPointSummaryForTask:task] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"双击间隔" value:[self millisecondsSummaryTextForDuration:[self doubleTapIntervalForTask:task]] tint:tint rows:rows];
            if (jitter > 0.001) {
                [self addTaskListDetailRowWithTitle:@"抖动" value:[NSString stringWithFormat:@"%.0fpx", jitter] tint:tint rows:rows];
            }
            break;
        case AnClickActionModeLongPress:
            [self addTaskListDetailRowWithTitle:@"坐标" value:[self taskListPointSummaryForTask:task] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"长按时长" value:[self longPressDurationSummaryText:[self longPressDurationForTask:task]] tint:tint rows:rows];
            if (jitter > 0.001) {
                [self addTaskListDetailRowWithTitle:@"抖动" value:[NSString stringWithFormat:@"%.0fpx", jitter] tint:tint rows:rows];
            }
            break;
        case AnClickActionModeSwipe:
            [self addTaskListDetailRowWithTitle:@"起点" value:[self taskListSwipePointSummaryForTask:task index:0] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"终点" value:[self taskListSwipePointSummaryForTask:task index:1] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"滑动时长" value:[self millisecondsSummaryTextForDuration:[self swipeDurationForTask:task]] tint:tint rows:rows];
            if ([task[@"swipeStep"] respondsToSelector:@selector(doubleValue)]) {
                [self addTaskListDetailRowWithTitle:@"轨迹步长" value:[NSString stringWithFormat:@"%.0fpx", [task[@"swipeStep"] doubleValue]] tint:tint rows:rows];
            }
            if (jitter > 0.001) {
                [self addTaskListDetailRowWithTitle:@"抖动" value:[NSString stringWithFormat:@"%.0fpx", jitter] tint:tint rows:rows];
            }
            break;
        case AnClickActionModeTwoFingerTap: {
            NSUInteger count = [self storedMultiTapPointsForTask:task].count;
            [self addTaskListDetailRowWithTitle:@"触点" value:count > 0 ? [NSString stringWithFormat:@"%lu点", (unsigned long)count] : @"未取点" tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"重复" value:[NSString stringWithFormat:@"%ld次", (long)repeat] tint:tint rows:rows];
            if (repeat > 1) {
                [self addTaskListDetailRowWithTitle:@"点击间隔" value:[self millisecondsSummaryTextForDuration:[self actionIntervalForTask:task]] tint:tint rows:rows];
            }
            if (jitter > 0.001) {
                [self addTaskListDetailRowWithTitle:@"抖动" value:[NSString stringWithFormat:@"%.0fpx", jitter] tint:tint rows:rows];
            }
            break;
        }
        case AnClickActionModeImage: {
            [self addTaskListDetailRowWithTitle:@"识图目标" value:[self recognitionTargetSummaryForTask:task] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"相似度阈值" value:[self thresholdSummaryForTask:task] tint:tint rows:rows];
            NSString *clickTarget = [self recognitionActionPointTargetForTask:task actionMode:[self successActionModeForTask:task] success:YES];
            if (clickTarget.length > 0) {
                [self addTaskListDetailRowWithTitle:@"成功点击" value:clickTarget tint:tint rows:rows];
            }
            NSString *failureClickTarget = [self recognitionActionPointTargetForTask:task actionMode:[self failureActionModeForTask:task] success:NO];
            if (failureClickTarget.length > 0) {
                [self addTaskListDetailRowWithTitle:@"失败点击" value:failureClickTarget tint:tint rows:rows];
            }
            [self addTaskListDetailRowWithTitle:@"识别重试" value:[self taskListRecognitionRetrySummaryForTask:task] tint:tint rows:rows];
            break;
        }
        case AnClickActionModeOCR: {
            [self addTaskListDetailRowWithTitle:@"目标文字" value:[self recognitionTargetSummaryForTask:task] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"匹配模式" value:[self ocrMatchModeTitleForMode:[self ocrMatchModeForTask:task]] tint:tint rows:rows];
            double similarity = [task[@"ocrSimilarity"] respondsToSelector:@selector(doubleValue)] ? MIN(1.0, MAX(0.0, [task[@"ocrSimilarity"] doubleValue])) : 0.80;
            [self addTaskListDetailRowWithTitle:@"识字相似度" value:[NSString stringWithFormat:@"%.0f%%", similarity * 100.0] tint:tint rows:rows];
            NSString *clickTarget = [self recognitionActionPointTargetForTask:task actionMode:[self successActionModeForTask:task] success:YES];
            if (clickTarget.length > 0) {
                [self addTaskListDetailRowWithTitle:@"成功点击" value:clickTarget tint:tint rows:rows];
            }
            NSString *failureClickTarget = [self recognitionActionPointTargetForTask:task actionMode:[self failureActionModeForTask:task] success:NO];
            if (failureClickTarget.length > 0) {
                [self addTaskListDetailRowWithTitle:@"失败点击" value:failureClickTarget tint:tint rows:rows];
            }
            [self addTaskListDetailRowWithTitle:@"识别重试" value:[self taskListRecognitionRetrySummaryForTask:task] tint:tint rows:rows];
            break;
        }
        case AnClickActionModeColor: {
            [self addTaskListDetailRowWithTitle:@"目标颜色" value:[self recognitionTargetSummaryForTask:task] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"颜色容差" value:[self thresholdSummaryForTask:task] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"匹配模式" value:[task[@"colorMatchMode"] integerValue] == 1 ? @"不等" : @"相等" tint:tint rows:rows];
            NSString *clickTarget = [self recognitionActionPointTargetForTask:task actionMode:[self successActionModeForTask:task] success:YES];
            if (clickTarget.length > 0) {
                [self addTaskListDetailRowWithTitle:@"成功点击" value:clickTarget tint:tint rows:rows];
            }
            NSString *failureClickTarget = [self recognitionActionPointTargetForTask:task actionMode:[self failureActionModeForTask:task] success:NO];
            if (failureClickTarget.length > 0) {
                [self addTaskListDetailRowWithTitle:@"失败点击" value:failureClickTarget tint:tint rows:rows];
            }
            [self addTaskListDetailRowWithTitle:@"识别重试" value:[self taskListRecognitionRetrySummaryForTask:task] tint:tint rows:rows];
            break;
        }
        case AnClickActionModeNetwork: {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            [self addTaskListDetailRowWithTitle:@"请求地址" value:url.length > 0 ? url : @"未设置" tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"请求方法" value:[self networkMethodForTask:task] tint:tint rows:rows];
            BOOL oneShot = [self networkTaskIsOneShot:task];
            [self addTaskListDetailRowWithTitle:@"执行模式" value:oneShot ? @"仅请求一次" : @"判断返回" tint:tint rows:rows];
            NSString *contains = [self trimmedActionDescription:task[@"networkContains"]];
            NSString *falseText = [self trimmedActionDescription:task[@"networkFalse"]];
            if (contains.length > 0) {
                [self addTaskListDetailRowWithTitle:@"成功匹配" value:contains tint:tint rows:rows];
            }
            if (falseText.length > 0) {
                [self addTaskListDetailRowWithTitle:@"失败匹配" value:falseText tint:tint rows:rows];
            }
            if ([[self networkMethodForTask:task] isEqualToString:@"POST"]) {
                NSUInteger pairCount = [task[@"networkPostPairs"] isKindOfClass:NSArray.class] ? [(NSArray *)task[@"networkPostPairs"] count] : 0;
                NSString *postSummary = pairCount > 0
                    ? [NSString stringWithFormat:@"%lu组键值", (unsigned long)pairCount]
                    : ([self networkPostBodyForTask:task].length > 0 ? @"自定义请求体" : @"未设置");
                [self addTaskListDetailRowWithTitle:@"POST参数" value:postSummary tint:tint rows:rows];
            }
            [self addTaskListDetailRowWithTitle:@"重试" value:[self networkRetryForeverForTask:task] ? @"一直判断" : [NSString stringWithFormat:@"%ld次", (long)[self networkRetryLimitForTask:task]] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"超时" value:[NSString stringWithFormat:@"%.0f秒", [self networkTimeoutForTask:task]] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"成功后" value:[self recognitionBranchActionSummaryForTask:task success:YES includePrefix:NO depth:0] tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"失败后" value:[self recognitionBranchActionSummaryForTask:task success:NO includePrefix:NO depth:0] tint:tint rows:rows];
            break;
        }
        case AnClickActionModeJump: {
            id value = task[@"jumpTaskIndex"] ?: task[@"targetTaskIndex"] ?: task[@"jumpTaskId"];
            NSInteger targetIndex = [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : -1;
            [self addTaskListDetailRowWithTitle:@"跳转目标" value:targetIndex >= 0 ? [NSString stringWithFormat:@"任务%ld", (long)targetIndex + 1] : @"未设置" tint:tint rows:rows];
            break;
        }
        case AnClickActionModeDelay:
            [self addTaskListDetailRowWithTitle:@"等待时长" value:[self millisecondsSummaryTextForDuration:[self delayForTask:task]] tint:tint rows:rows];
            break;
        case AnClickActionModeMacro: {
            NSArray *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
            [self addTaskListDetailRowWithTitle:@"录制内容" value:events.count > 0 ? [NSString stringWithFormat:@"%lu步", (unsigned long)events.count] : @"未录制" tint:tint rows:rows];
            [self addTaskListDetailRowWithTitle:@"回放速度" value:[self macroPlaybackSpeedSummaryText:[self macroPlaybackSpeedForTask:task]] tint:tint rows:rows];
            if (events.count > 0) {
                [self addTaskListDetailRowWithTitle:@"预计时长" value:[self millisecondsSummaryTextForDuration:[self durationForRecordedEvents:events playbackSpeed:[self macroPlaybackSpeedForTask:task]]] tint:tint rows:rows];
            }
            break;
        }
        default:
            [self addTaskListDetailRowWithTitle:@"配置" value:@"未设置" tint:tint rows:rows];
            break;
    }
    return rows;
}

- (void)refreshTaskList {
    [self refreshCollapsedButtonTitle];
    BOOL hasTasks = _taskItems.count > 0;
    _deleteTaskButton.enabled = hasTasks;
    _deleteTaskButton.alpha = hasTasks ? 1.0 : 0.45;
    [_panelView viewWithTag:AnClickHomeDeleteLabelTag].alpha = hasTasks ? 1.0 : 0.45;
    _runTasksButton.enabled = hasTasks || _taskRunActive;
    _runTasksButton.alpha = (hasTasks || _taskRunActive) ? 1.0 : 0.45;
    [_panelView viewWithTag:AnClickHomeRunLabelTag].alpha = (hasTasks || _taskRunActive) ? 1.0 : 0.45;
    if (!_taskListView) {
        return;
    }

    if (_taskItems.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] initWithFrame:_taskListView.bounds];
        emptyLabel.text = @"暂无任务  点击添加";
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.textColor = [self themeSecondaryTextColor];
        emptyLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        emptyLabel.adjustsFontSizeToFitWidth = YES;
        emptyLabel.minimumScaleFactor = 0.7;
        _taskListView.backgroundView = emptyLabel;
    } else {
        _taskListView.backgroundView = nil;
    }
    [_taskListView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return tableView == _taskListView ? (NSInteger)_taskItems.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AnClickTaskListCellIdentifier forIndexPath:indexPath];
    for (UIView *view in cell.contentView.subviews) {
        [view removeFromSuperview];
    }
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.clipsToBounds = NO;
    cell.contentView.clipsToBounds = NO;

    if (indexPath.row < 0 || indexPath.row >= (NSInteger)_taskItems.count) {
        return cell;
    }

    AnClickTaskModel *model = [self taskModelAtIndex:(NSUInteger)indexPath.row];
    NSDictionary *task = [self taskDictionaryForModel:model];
    AnClickActionMode mode = [self modeForTask:task];
    BOOL expanded = model.expanded;
    BOOL selected = indexPath.row == _selectedTaskIndex;
    UIColor *accent = [self accentColorForActionMode:mode];

    UIView *cardView = [[UIView alloc] initWithFrame:CGRectZero];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = UIColor.whiteColor;
    cardView.layer.cornerRadius = 10.0;
    cardView.layer.borderWidth = selected || expanded ? 1.0 : 0.8;
    cardView.layer.borderColor = (selected || expanded
        ? [accent colorWithAlphaComponent:0.50]
        : [[self themeSeparatorColor] colorWithAlphaComponent:0.34]).CGColor;
    cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    cardView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    cardView.layer.shadowRadius = expanded ? 8.0 : 5.0;
    cardView.layer.shadowOpacity = expanded ? 0.12 : 0.09;
    [cell.contentView addSubview:cardView];

    UIView *accentRail = [[UIView alloc] initWithFrame:CGRectZero];
    accentRail.translatesAutoresizingMaskIntoConstraints = NO;
    accentRail.backgroundColor = accent;
    [cardView addSubview:accentRail];

    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = expanded ? UIColor.whiteColor : accent;
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:[self taskListIconNameForMode:mode]];
    }
    [cardView addSubview:iconView];

    UILabel *fallbackIconLabel = nil;
    if (!iconView.image) {
        fallbackIconLabel = [self taskListLabelWithText:@"●"
                                                  font:[UIFont systemFontOfSize:13 weight:UIFontWeightBold]
                                                 color:expanded ? UIColor.whiteColor : accent
                                                 lines:1];
        fallbackIconLabel.textAlignment = NSTextAlignmentCenter;
        [cardView addSubview:fallbackIconLabel];
    }

    UILabel *titleLabel = [self taskListLabelWithText:(expanded
            ? [self taskListExpandedHeaderForTask:task index:(NSUInteger)indexPath.row]
            : [self taskListCollapsedLineForTask:task index:(NSUInteger)indexPath.row])
                                                font:[UIFont systemFontOfSize:(expanded ? 14.0 : 13.0) weight:UIFontWeightBold]
                                               color:expanded ? UIColor.whiteColor : [self themePrimaryTextColor]
                                               lines:1];
    [cardView addSubview:titleLabel];

    UILabel *arrowLabel = [self taskListLabelWithText:expanded ? @"▲" : @"▼"
                                                font:[UIFont systemFontOfSize:13 weight:UIFontWeightBold]
                                               color:expanded ? UIColor.whiteColor : [self themeSecondaryTextColor]
                                               lines:1];
    arrowLabel.textAlignment = NSTextAlignmentCenter;
    [cardView addSubview:arrowLabel];

    UIView *headerFill = nil;
    if (expanded) {
        headerFill = [[UIView alloc] initWithFrame:CGRectZero];
        headerFill.translatesAutoresizingMaskIntoConstraints = NO;
        headerFill.backgroundColor = accent;
        headerFill.userInteractionEnabled = NO;
        [cardView insertSubview:headerFill atIndex:0];
    }

    NSLayoutYAxisAnchor *headerCenterAnchor = expanded ? headerFill.centerYAnchor : cardView.centerYAnchor;
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [cardView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4.0],
        [cardView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:5.0],
        [cardView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-5.0],
        [cardView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4.0],
        [accentRail.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [accentRail.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [accentRail.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],
        [accentRail.widthAnchor constraintEqualToConstant:expanded ? 0.0 : 4.0],
        [iconView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:13.0],
        [iconView.centerYAnchor constraintEqualToAnchor:headerCenterAnchor],
        [iconView.widthAnchor constraintEqualToConstant:16.0],
        [iconView.heightAnchor constraintEqualToConstant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:8.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:arrowLabel.leadingAnchor constant:-8.0],
        [arrowLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-12.0],
        [arrowLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
        [arrowLabel.widthAnchor constraintEqualToConstant:24.0],
    ]];
    if (fallbackIconLabel) {
        [constraints addObjectsFromArray:@[
            [fallbackIconLabel.centerXAnchor constraintEqualToAnchor:iconView.centerXAnchor],
            [fallbackIconLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
            [fallbackIconLabel.widthAnchor constraintEqualToAnchor:iconView.widthAnchor],
            [fallbackIconLabel.heightAnchor constraintEqualToAnchor:iconView.heightAnchor],
        ]];
    }
    if (headerFill) {
        [constraints addObjectsFromArray:@[
            [headerFill.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
            [headerFill.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
            [headerFill.topAnchor constraintEqualToAnchor:cardView.topAnchor],
            [headerFill.heightAnchor constraintEqualToConstant:36.0],
        ]];
    }

    UIView *lastView = titleLabel;
    if (expanded) {
        UILabel *detailTitle = [self taskListLabelWithText:[self taskListDetailTitleForTask:task]
                                                     font:[UIFont systemFontOfSize:13 weight:UIFontWeightBold]
                                                    color:[self themePrimaryTextColor]
                                                    lines:1];
        [cardView addSubview:detailTitle];

        UIStackView *detailStack = [[UIStackView alloc] initWithFrame:CGRectZero];
        detailStack.translatesAutoresizingMaskIntoConstraints = NO;
        detailStack.axis = UILayoutConstraintAxisVertical;
        detailStack.spacing = 6.0;
        [cardView addSubview:detailStack];

        for (NSDictionary *row in [self taskListDetailRowsForTask:task tint:accent]) {
            UIColor *rowTint = [row[@"tint"] isKindOfClass:UIColor.class] ? row[@"tint"] : accent;
            UIView *line = [self taskListDetailLineWithTitle:row[@"title"] value:row[@"value"] tint:rowTint];
            [detailStack addArrangedSubview:line];
        }

        UIButton *runButton = [self taskListSmallButtonWithTitle:@"单步测试"
                                                             tag:AnClickTaskListRunButtonTagBase + indexPath.row
                                                          action:@selector(runSingleTaskTestButtonAtIndex:)
                                                            tint:[self themeHighlightColor]];
        UIButton *editButton = [self taskListSmallButtonWithTitle:@"修改"
                                                              tag:AnClickTaskListEditButtonTagBase + indexPath.row
                                                           action:@selector(editTaskButtonAtIndex:)
                                                             tint:[self themeHighlightColor]];
        UIButton *collapseButton = [self taskListSmallButtonWithTitle:@"折叠 ▲"
                                                                 tag:AnClickTaskListCollapseButtonTagBase + indexPath.row
                                                               action:@selector(collapseTaskButtonAtIndex:)
                                                                 tint:[self themeHighlightColor]];
        [cardView addSubview:runButton];
        [cardView addSubview:editButton];
        [cardView addSubview:collapseButton];

        UILabel *logicCaption = nil;
        UIView *successLine = nil;
        UIView *failureLine = nil;
        if ([self modeIsRecognitionTask:mode]) {
            logicCaption = [self taskListCaptionWithText:@"逻辑跳转"];
            [cardView addSubview:logicCaption];
            successLine = [self taskListBranchLineWithTitle:@"成功"
                                                     detail:[self recognitionSuccessActionSummaryForTask:task]
                                                    success:YES];
            failureLine = [self taskListBranchLineWithTitle:@"失败"
                                                     detail:[self recognitionFailureActionSummaryForTask:task]
                                                    success:NO];
            [cardView addSubview:successLine];
            [cardView addSubview:failureLine];
        }

        CGFloat side = 14.0;
        CGFloat gap = 8.0;
        [constraints addObjectsFromArray:@[
            [detailTitle.topAnchor constraintEqualToAnchor:headerFill.bottomAnchor constant:9.0],
            [detailTitle.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:side],
            [detailTitle.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-side],

            [detailStack.topAnchor constraintEqualToAnchor:detailTitle.bottomAnchor constant:7.0],
            [detailStack.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:side],
            [detailStack.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-side],

            [runButton.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:side],
            [runButton.heightAnchor constraintEqualToConstant:34.0],
            [editButton.topAnchor constraintEqualToAnchor:runButton.topAnchor],
            [editButton.leadingAnchor constraintEqualToAnchor:runButton.trailingAnchor constant:gap],
            [editButton.widthAnchor constraintEqualToAnchor:runButton.widthAnchor multiplier:0.62],
            [editButton.heightAnchor constraintEqualToAnchor:runButton.heightAnchor],
            [collapseButton.topAnchor constraintEqualToAnchor:runButton.topAnchor],
            [collapseButton.leadingAnchor constraintEqualToAnchor:editButton.trailingAnchor constant:gap],
            [collapseButton.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-side],
            [collapseButton.widthAnchor constraintEqualToAnchor:runButton.widthAnchor multiplier:0.62],
            [collapseButton.heightAnchor constraintEqualToAnchor:runButton.heightAnchor],
        ]];
        if (logicCaption && successLine && failureLine) {
            [constraints addObjectsFromArray:@[
                [logicCaption.topAnchor constraintEqualToAnchor:detailStack.bottomAnchor constant:9.0],
                [logicCaption.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:side],
                [logicCaption.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-side],
                [successLine.topAnchor constraintEqualToAnchor:logicCaption.bottomAnchor constant:5.0],
                [successLine.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:side],
                [successLine.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-side],
                [failureLine.topAnchor constraintEqualToAnchor:successLine.bottomAnchor constant:6.0],
                [failureLine.leadingAnchor constraintEqualToAnchor:successLine.leadingAnchor],
                [failureLine.trailingAnchor constraintEqualToAnchor:successLine.trailingAnchor],
                [runButton.topAnchor constraintEqualToAnchor:failureLine.bottomAnchor constant:8.0],
            ]];
        } else {
            [constraints addObject:[runButton.topAnchor constraintEqualToAnchor:detailStack.bottomAnchor constant:9.0]];
        }
        lastView = runButton;
    }

    if (expanded) {
        [constraints addObject:[cardView.bottomAnchor constraintEqualToAnchor:lastView.bottomAnchor constant:12.0]];
    } else {
        [constraints addObject:[titleLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-10.0]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != _taskListView ||
        indexPath.row < 0 ||
        indexPath.row >= (NSInteger)_taskItems.count) {
        return;
    }

    AnClickTaskModel *model = [self taskModelAtIndex:(NSUInteger)indexPath.row];
    BOOL expanded = !model.expanded;
    NSMutableArray<NSIndexPath *> *reloadIndexPaths = [NSMutableArray arrayWithObject:indexPath];
    for (NSUInteger i = 0; i < _taskItems.count; i++) {
        if ((NSInteger)i == indexPath.row) {
            continue;
        }
        AnClickTaskModel *otherModel = [self taskModelAtIndex:i];
        if (otherModel.expanded) {
            otherModel.expanded = NO;
            [reloadIndexPaths addObject:[NSIndexPath indexPathForRow:(NSInteger)i inSection:0]];
        }
    }
    model.expanded = expanded;
    _selectedTaskIndex = indexPath.row;
    [tableView performBatchUpdates:^{
        [tableView reloadRowsAtIndexPaths:reloadIndexPaths withRowAnimation:UITableViewRowAnimationFade];
    } completion:nil];
    [self persistCurrentTaskList];
    _statusLabel.text = @"";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != _taskListView || editingStyle != UITableViewCellEditingStyleDelete) {
        return;
    }
    [self deleteTaskAtIndex:indexPath.row];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return tableView == _taskListView &&
        indexPath.row >= 0 &&
        indexPath.row < (NSInteger)_taskItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"删除";
}

- (BOOL)moveTaskFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex {
    if (sourceIndex < 0 ||
        destinationIndex < 0 ||
        sourceIndex >= (NSInteger)_taskItems.count ||
        destinationIndex >= (NSInteger)_taskItems.count ||
        sourceIndex == destinationIndex) {
        return NO;
    }

    AnClickTaskModel *model = [_taskItems[(NSUInteger)sourceIndex] copy];
    [_taskItems removeObjectAtIndex:(NSUInteger)sourceIndex];
    [_taskItems insertObject:model atIndex:(NSUInteger)destinationIndex];

    if (_selectedTaskIndex == sourceIndex) {
        _selectedTaskIndex = destinationIndex;
    } else if (sourceIndex < _selectedTaskIndex && _selectedTaskIndex <= destinationIndex) {
        _selectedTaskIndex--;
    } else if (destinationIndex <= _selectedTaskIndex && _selectedTaskIndex < sourceIndex) {
        _selectedTaskIndex++;
    }
    return YES;
}

- (void)deleteSelectedTaskFromHomeButton {
    if (_taskItems.count == 0) {
        return;
    }

    NSInteger index = _selectedTaskIndex;
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        for (NSUInteger i = 0; i < _taskItems.count; i++) {
            if ([self taskModelAtIndex:i].expanded) {
                index = (NSInteger)i;
                break;
            }
        }
    }
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        index = (NSInteger)_taskItems.count - 1;
    }
    [self deleteTaskAtIndex:index];
}

- (void)finishTaskListReorderAtLocation:(__unused CGPoint)location cancelled:(BOOL)cancelled {
    UITableViewCell *cell = nil;
    if (_draggingTaskIndex >= 0 && _draggingTaskIndex < (NSInteger)_taskItems.count) {
        cell = [_taskListView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_draggingTaskIndex inSection:0]];
    }
    CGRect targetFrame = cell ? cell.frame : _taskReorderSnapshotView.frame;
    _taskListView.scrollEnabled = YES;
    _taskReordering = NO;
    _draggingTaskIndex = -1;

    [UIView animateWithDuration:0.18 animations:^{
        self->_taskReorderSnapshotView.transform = CGAffineTransformIdentity;
        self->_taskReorderSnapshotView.alpha = 0.0;
        self->_taskReorderSnapshotView.frame = targetFrame;
    } completion:^(__unused BOOL finished) {
        cell.hidden = NO;
        [self->_taskReorderSnapshotView removeFromSuperview];
        self->_taskReorderSnapshotView = nil;
        [self->_taskListView reloadData];
    }];

    [self persistCurrentTaskList];
}

- (void)handleTaskListLongPressReorder:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.view != _taskListView || _taskItems.count < 2 || _taskRunActive) {
        return;
    }

    CGPoint location = [recognizer locationInView:_taskListView];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        NSIndexPath *indexPath = [_taskListView indexPathForRowAtPoint:location];
        if (!indexPath || indexPath.row < 0 || indexPath.row >= (NSInteger)_taskItems.count) {
            return;
        }

        UITableViewCell *cell = [_taskListView cellForRowAtIndexPath:indexPath];
        if (!cell) {
            return;
        }
        _taskReordering = YES;
        _draggingTaskIndex = indexPath.row;
        _selectedTaskIndex = indexPath.row;
        _taskReorderStartLocationY = location.y;
        _taskReorderStartCenterY = CGRectGetMidY(cell.frame);
        _taskReorderSnapshotView = [cell snapshotViewAfterScreenUpdates:NO];
        if (!_taskReorderSnapshotView) {
            _taskReordering = NO;
            _draggingTaskIndex = -1;
            return;
        }
        _taskReorderSnapshotView.frame = cell.frame;
        _taskReorderSnapshotView.layer.shadowColor = UIColor.blackColor.CGColor;
        _taskReorderSnapshotView.layer.shadowOpacity = 0.22;
        _taskReorderSnapshotView.layer.shadowRadius = 12.0;
        _taskReorderSnapshotView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
        [_taskListView addSubview:_taskReorderSnapshotView];
        cell.hidden = YES;
        _taskListView.scrollEnabled = NO;

        [UIView animateWithDuration:0.14 animations:^{
            self->_taskReorderSnapshotView.transform = CGAffineTransformMakeScale(1.02, 1.02);
            self->_taskReorderSnapshotView.alpha = 0.96;
        }];
        return;
    }

    if (!_taskReordering || !_taskReorderSnapshotView) {
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint center = _taskReorderSnapshotView.center;
        center.y = _taskReorderStartCenterY + (location.y - _taskReorderStartLocationY);
        _taskReorderSnapshotView.center = center;

        NSIndexPath *targetIndexPath = [_taskListView indexPathForRowAtPoint:location];
        if (!targetIndexPath ||
            targetIndexPath.row < 0 ||
            targetIndexPath.row >= (NSInteger)_taskItems.count ||
            targetIndexPath.row == _draggingTaskIndex) {
            return;
        }

        NSIndexPath *sourceIndexPath = [NSIndexPath indexPathForRow:_draggingTaskIndex inSection:0];
        if ([self moveTaskFromIndex:_draggingTaskIndex toIndex:targetIndexPath.row]) {
            _draggingTaskIndex = targetIndexPath.row;
            [_taskListView moveRowAtIndexPath:sourceIndexPath toIndexPath:targetIndexPath];
            for (UITableViewCell *visibleCell in _taskListView.visibleCells) {
                visibleCell.hidden = NO;
            }
            UITableViewCell *hiddenCell = [_taskListView cellForRowAtIndexPath:targetIndexPath];
            hiddenCell.hidden = YES;
        }
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self finishTaskListReorderAtLocation:location cancelled:NO];
    } else if (recognizer.state == UIGestureRecognizerStateCancelled ||
               recognizer.state == UIGestureRecognizerStateFailed) {
        [self finishTaskListReorderAtLocation:location cancelled:YES];
    }
}

- (void)editTaskButtonAtIndex:(UIButton *)sender {
    NSInteger index = sender.tag - AnClickTaskListEditButtonTagBase;
    [self selectTaskAtIndex:index];
}

- (void)collapseTaskButtonAtIndex:(UIButton *)sender {
    NSInteger index = sender.tag - AnClickTaskListCollapseButtonTagBase;
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        return;
    }
    [self taskModelAtIndex:(NSUInteger)index].expanded = NO;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    [_taskListView performBatchUpdates:^{
        [_taskListView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } completion:nil];
    [self persistCurrentTaskList];
}

- (void)runSingleTaskTestButtonAtIndex:(UIButton *)sender {
    NSInteger index = sender.tag - AnClickTaskListRunButtonTagBase;
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        _statusLabel.text = @"任务不存在";
        return;
    }
    if (_taskRunActive || _taskRunPausedForForeground) {
        [self stopTaskRunWithStatus:@"已停止"];
        return;
    }
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        [self showToast:@"无窗口"];
        return;
    }
    if ([AnClickRecorder shared].isRecording) {
        _statusLabel.text = @"录制中无法测试";
        [self showToast:@"录制中无法测试"];
        return;
    }

    AnClickTaskModel *model = [self taskModelAtIndex:(NSUInteger)index];
    if (![self taskModelIsComplete:model]) {
        [self selectTaskAtIndex:index];
        [self showToast:_statusLabel.text ?: @"先补全任务"];
        return;
    }

    [self cancelRunningTaskSideEffects];
    _selectedTaskIndex = index;
    _taskRunActive = YES;
    [self clearTaskRunPauseState];
    _taskRunSingleStepStopIndex = index;
    _currentGlobalRunCycle = 0;
    [self resetTaskRunJumpGuard];
    [self resetRunProgressToastThrottle];
    [_taskEngine resetListRefreshThrottle];
    NSUInteger runGeneration = ++_taskRunGeneration;
    [self startTaskRunRuntimeTimerReset:YES];
    [self refreshTaskListDuringRunIfNeeded];
    _panelHiddenForSingleStepTest = YES;
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    [self runTaskAtIndex:(NSUInteger)index inWindow:hostWindow generation:runGeneration];
}

- (void)addTaskFromCurrentConfig {
    [self resetCurrentActionConfiguration];
    _selectedTaskIndex = -1;
    _editingTaskIndex = -1;
    _editingTaskModel = [[AnClickTaskModel alloc] init];
    [self setTaskEditorVisible:YES];
}

- (void)deleteTaskAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        _statusLabel.text = @"任务不存在";
        return;
    }

    BOOL removedSelectedTask = _selectedTaskIndex == index;
    [_taskItems removeObjectAtIndex:(NSUInteger)index];
    if (_selectedTaskIndex == index) {
        _selectedTaskIndex = -1;
    } else if (_selectedTaskIndex > index) {
        _selectedTaskIndex--;
    }
    if (_selectedTaskIndex >= (NSInteger)_taskItems.count) {
        _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    }
    if (removedSelectedTask || _taskItems.count == 0) {
        _selectedTaskIndex = -1;
        [self resetCurrentActionConfiguration];
    }
    [self showTaskHome];
    [self persistCurrentTaskList];
    _statusLabel.text = @"";
}

- (void)restoreNestedBranchParentEditorWithStatus:(__unused NSString *)status {
    AnClickTaskModel *parentModel = [_editingNestedBranchParentModel copy];
    if (![parentModel isKindOfClass:AnClickTaskModel.class]) {
        parentModel = _editingTaskModel ? [_editingTaskModel copy] : [[AnClickTaskModel alloc] init];
    }
    _editingNestedBranchActionConfig = NO;
    _editingNestedBranchActionSuccess = NO;
    _editingNestedBranchActionMode = AnClickActionModeNone;
    _editingNestedBranchParentModel = nil;
    _editingTaskModel = parentModel;
    [self stageTaskEditorModelForRuntime:parentModel];
    [self setTaskEditorVisible:YES];
    [self refreshTaskEditorViewFromCurrentState];
}

- (void)beginEditingNestedBranchActionConfigFromEditorView:(AnClickTaskEditorView *)editorView success:(BOOL)success {
    AnClickTaskModel *parentModel = [editorView.model copy];
    AnClickActionMode mode = success
        ? [self normalizedImageActionMode:parentModel.successActionMode]
        : [self normalizedFailureActionMode:parentModel.failureActionMode];
    if (mode == AnClickActionModeNone || mode == AnClickActionModeJump) {
        [self showToast:success ? @"成功后动作无需配置" : @"失败后动作无需配置"];
        return;
    }
    if ([self modeIsRecognitionTask:mode]) {
        [self showToast:@"分支内不再嵌套识别动作"];
        return;
    }

    NSDictionary *existingConfig = success ? parentModel.successActionConfig : parentModel.failureActionConfig;
    NSMutableDictionary *childTask = ([existingConfig isKindOfClass:NSDictionary.class] &&
                                      [self modeForTask:existingConfig] == mode)
        ? [existingConfig mutableCopy]
        : [self draftActionTaskForMode:mode];
    childTask[@"mode"] = @(mode);
    _editingNestedBranchActionConfig = YES;
    _editingNestedBranchActionSuccess = success;
    _editingNestedBranchActionMode = mode;
    _editingNestedBranchParentModel = parentModel;
    _editingTaskModel = [[AnClickTaskModel alloc] initWithDictionary:childTask];
    [self stageTaskEditorModelForRuntime:_editingTaskModel];
    [self setTaskEditorVisible:YES];
    [self refreshTaskEditorViewFromCurrentState];
}

- (void)saveTaskEditorModel:(AnClickTaskModel *)model {
    if (![model isKindOfClass:AnClickTaskModel.class]) {
        [self showToast:@"编辑数据无效"];
        return;
    }
    _editingTaskModel = [model copy];
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    if (![self taskModelIsComplete:model]) {
        [self showToast:_statusLabel.text ?: @"先补全任务"];
        return;
    }
    if (_editingNestedBranchActionConfig) {
        AnClickTaskModel *parentModel = [_editingNestedBranchParentModel copy];
        if (![parentModel isKindOfClass:AnClickTaskModel.class]) {
            [self showToast:@"分支配置保存失败"];
            return;
        }
        if (_editingNestedBranchActionSuccess) {
            parentModel.successActionMode = _editingNestedBranchActionMode;
            parentModel.successActionConfig = task;
            parentModel.successRecognitionActionConfig = @{};
        } else {
            parentModel.failureActionMode = _editingNestedBranchActionMode;
            parentModel.failureActionConfig = task;
            parentModel.failureRecognitionActionConfig = @{};
        }
        _editingNestedBranchParentModel = parentModel;
        [self restoreNestedBranchParentEditorWithStatus:nil];
        return;
    }
    if (_editingBranchRecognitionConfig) {
        NSInteger ownerIndex = _editingBranchOwnerTaskIndex;
        BOOL success = _editingBranchRecognitionSuccess;
        AnClickActionMode branchMode = _editingBranchActionMode;
        if (ownerIndex < 0 || ownerIndex >= (NSInteger)_taskItems.count ||
            ![self isSelectableActionMode:branchMode] ||
            [self modeForTask:task] != branchMode) {
            _statusLabel.text = @"分支配置保存失败";
            return;
        }

        NSMutableDictionary *ownerTask = [self taskDictionaryAtIndex:(NSUInteger)ownerIndex];
        ownerTask[[self branchActionConfigKeyForSuccess:success]] = task;
        if ([self modeIsRecognitionTask:branchMode]) {
            ownerTask[[self recognitionActionConfigKeyForSuccess:success]] = task;
        }
        _taskItems[(NSUInteger)ownerIndex] = [[AnClickTaskModel alloc] initWithDictionary:ownerTask];
        _editingBranchRecognitionConfig = NO;
        _editingBranchRecognitionSuccess = NO;
        _editingBranchOwnerTaskIndex = -1;
        _editingBranchActionMode = AnClickActionModeNone;
        _editingTaskModel = [[AnClickTaskModel alloc] initWithDictionary:ownerTask];
        _selectedTaskIndex = ownerIndex;
        _editingTaskIndex = ownerIndex;
        [self persistCurrentTaskList];
        [self refreshTaskList];
        [self selectTaskAtIndex:ownerIndex];
        return;
    }
    NSInteger targetIndex = (_editingTaskIndex >= 0 && _editingTaskIndex < (NSInteger)_taskItems.count)
        ? _editingTaskIndex
        : -1;
    BOOL updatingExistingTask = targetIndex >= 0 &&
        targetIndex < (NSInteger)_taskItems.count &&
        [self taskModelAtIndex:(NSUInteger)targetIndex] != nil;
    model.expanded = updatingExistingTask && [self taskModelAtIndex:(NSUInteger)targetIndex].expanded;
    if (!updatingExistingTask) {
        [_taskItems addObject:[model copy]];
        _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    } else {
        _taskItems[(NSUInteger)targetIndex] = [model copy];
        _selectedTaskIndex = targetIndex;
    }
    _editingTaskIndex = _selectedTaskIndex;
    _editingTaskModel = [model copy];
    [self refreshTaskList];
    [self showTaskHome];
    [self persistCurrentTaskList];
}

- (void)saveSelectedTaskFromCurrentConfig {
    [self saveTaskEditorModel:_taskEditorView.model ?: _editingTaskModel];
}

- (void)taskEditorViewDidCancel:(__unused AnClickTaskEditorView *)editorView {
    if (_editingNestedBranchActionConfig) {
        [self restoreNestedBranchParentEditorWithStatus:nil];
        return;
    }
    _editingTaskModel = nil;
    _editingTaskIndex = -1;
    [self showTaskHome];
}

- (void)taskEditorViewDidClose:(__unused AnClickTaskEditorView *)editorView {
    _editingNestedBranchActionConfig = NO;
    _editingNestedBranchActionSuccess = NO;
    _editingNestedBranchActionMode = AnClickActionModeNone;
    _editingNestedBranchParentModel = nil;
    _editingTaskModel = nil;
    _editingTaskIndex = -1;
    [self collapsePanel];
}

- (void)taskEditorViewDidSave:(AnClickTaskEditorView *)editorView {
    [self saveTaskEditorModel:editorView.model];
}

- (void)taskEditorViewDidDeleteTask:(__unused AnClickTaskEditorView *)editorView {
    if (_selectedTaskIndex >= 0 && _selectedTaskIndex < (NSInteger)_taskItems.count) {
        [self deleteTaskAtIndex:_selectedTaskIndex];
        return;
    }
    [self showTaskHome];
}

- (void)taskEditorViewDidRequestPointPick:(AnClickTaskEditorView *)editorView {
    _editingTaskModel = [editorView.model copy];
    [self stageTaskEditorModelForRuntime:editorView.model];
    [self beginPointPicking];
}

- (void)taskEditorView:(AnClickTaskEditorView *)editorView didRequestRecognitionResultPointPickForSuccess:(BOOL)success {
    AnClickTaskModel *model = [editorView.model copy];
    AnClickActionMode branchMode = success
        ? [self normalizedImageActionMode:model.successActionMode]
        : [self normalizedFailureActionMode:model.failureActionMode];
    if (![self modeIsRecognitionTask:branchMode] &&
        ![self modeCanUseRecognitionPoint:branchMode]) {
        return;
    }
    _editingTaskModel = model;
    [self stageTaskEditorModelForRuntime:model];
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        [self showToast:@"无窗口"];
        return;
    }
    _pickingBranchRecognitionResultPoint = YES;
    _pickingBranchRecognitionResultSuccess = success;
    _pickingSuccessActionPoint = NO;
    _pickingFailureActionPoint = NO;
    _pickingSwipeEndPoint = NO;
    [self beginScreenPointPickingWithHostWindow:hostWindow];
}

- (void)storeBranchRecognitionResultPoint:(CGPoint)point success:(BOOL)success {
    AnClickTaskModel *model = _editingTaskModel ? [_editingTaskModel copy] : [[AnClickTaskModel alloc] init];
    AnClickActionMode branchMode = success
        ? [self normalizedImageActionMode:model.successActionMode]
        : [self normalizedFailureActionMode:model.failureActionMode];
    if (![self modeIsRecognitionTask:branchMode] &&
        ![self modeCanUseRecognitionPoint:branchMode]) {
        return;
    }

    NSDictionary *existingConfig = success ? model.successActionConfig : model.failureActionConfig;
    if (![existingConfig isKindOfClass:NSDictionary.class] ||
        [self modeForTask:existingConfig] != branchMode) {
        existingConfig = success ? model.successRecognitionActionConfig : model.failureRecognitionActionConfig;
    }
    NSMutableDictionary *config = ([existingConfig isKindOfClass:NSDictionary.class] &&
                                   [self modeForTask:existingConfig] == branchMode)
        ? [existingConfig mutableCopy]
        : [self draftActionTaskForMode:branchMode];
    config[@"mode"] = @(branchMode);
    config[@"point"] = [NSValue valueWithCGPoint:point];
    config[@"pointScreenSize"] = [self currentScreenCoordinateSizeValue];
    config[@"useMatchPoint"] = @NO;

    if (success) {
        model.successActionConfig = config;
        model.successRecognitionActionConfig = [self modeIsRecognitionTask:branchMode] ? config : @{};
    } else {
        model.failureActionConfig = config;
        model.failureRecognitionActionConfig = [self modeIsRecognitionTask:branchMode] ? config : @{};
    }
    _editingTaskModel = model;
}

- (void)taskEditorViewDidRequestColorPick:(AnClickTaskEditorView *)editorView {
    _editingTaskModel = [editorView.model copy];
    [self stageTaskEditorModelForRuntime:editorView.model];
    [self beginColorPicking];
}

- (void)taskEditorViewDidRequestTemplateCapture:(AnClickTaskEditorView *)editorView {
    _editingTaskModel = [editorView.model copy];
    [self stageTaskEditorModelForRuntime:editorView.model];
    [self beginTemplateCapture];
}

- (void)taskEditorViewDidRequestRecording:(AnClickTaskEditorView *)editorView {
    _editingTaskModel = [editorView.model copy];
    [self stageTaskEditorModelForRuntime:editorView.model];
    [self toggleMacroRecording];
}

- (void)taskEditorViewDidRequestSingleStepTest:(AnClickTaskEditorView *)editorView {
    _editingTaskModel = [editorView.model copy];
    [self stageTaskEditorModelForRuntime:_editingTaskModel];
    if (![self taskModelIsComplete:_editingTaskModel]) {
        [self showToast:_statusLabel.text ?: @"先补全任务"];
        return;
    }
    if (_editingBranchRecognitionConfig || _editingNestedBranchActionConfig) {
        if (_taskRunActive || _taskRunPausedForForeground) {
            [self stopTaskRunWithStatus:@"已停止"];
            return;
        }
        UIWindow *hostWindow = [self hostWindow];
        if (!hostWindow) {
            [self showToast:@"无窗口"];
            return;
        }
        [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
        NSTimeInterval duration = [self performTaskModel:_editingTaskModel inWindow:hostWindow runGeneration:0];
        [self restorePanelAfterScreenDelay:duration + 0.15];
        return;
    }
    NSInteger targetIndex = (_editingTaskIndex >= 0 && _editingTaskIndex < (NSInteger)_taskItems.count)
        ? _editingTaskIndex
        : _selectedTaskIndex;
    if (targetIndex < 0 || targetIndex >= (NSInteger)_taskItems.count) {
        [_taskItems addObject:[_editingTaskModel copy]];
        _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    } else {
        _editingTaskModel.expanded = [self taskModelAtIndex:(NSUInteger)targetIndex].expanded;
        _taskItems[(NSUInteger)targetIndex] = [_editingTaskModel copy];
        _selectedTaskIndex = targetIndex;
    }
    _editingTaskIndex = _selectedTaskIndex;
    [self persistCurrentTaskList];
    [self refreshTaskList];

    UIButton *sender = [UIButton buttonWithType:UIButtonTypeSystem];
    sender.tag = AnClickTaskListRunButtonTagBase + _selectedTaskIndex;
    [self runSingleTaskTestButtonAtIndex:sender];
}

- (void)beginEditingBranchActionConfigFromEditorView:(AnClickTaskEditorView *)editorView success:(BOOL)success {
    if (_editingBranchRecognitionConfig && !_editingNestedBranchActionConfig) {
        [self beginEditingNestedBranchActionConfigFromEditorView:editorView success:success];
        return;
    }

    AnClickTaskModel *ownerModel = [editorView.model copy];
    _editingTaskModel = ownerModel;
    [self stageTaskEditorModelForRuntime:ownerModel];
    if (![self currentActionIsRecognitionMode]) {
        [self showToast:@"识别任务才有成功/失败动作"];
        return;
    }

    AnClickActionMode mode = success
        ? [self normalizedImageActionMode:_imageActionMode]
        : [self normalizedFailureActionMode:_failureActionMode];
    if (mode == AnClickActionModeNone || mode == AnClickActionModeJump) {
        [self showToast:success ? @"成功后动作无需配置" : @"失败后动作无需配置"];
        return;
    }

    if (_selectedTaskIndex < 0 || _selectedTaskIndex >= (NSInteger)_taskItems.count) {
        [_taskItems addObject:[ownerModel copy]];
        _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    } else {
        AnClickTaskModel *existing = [self taskModelAtIndex:(NSUInteger)_selectedTaskIndex];
        ownerModel.expanded = existing.expanded;
        _taskItems[(NSUInteger)_selectedTaskIndex] = [ownerModel copy];
    }
    [self persistCurrentTaskList];
    [self refreshTaskList];

    if (mode == AnClickActionModeImage) {
        [self beginBranchTemplateCaptureForSuccess:success];
        return;
    }
    if (mode == AnClickActionModeColor) {
        [self beginBranchColorPickingForSuccess:success];
        return;
    }

    [self beginEditingRecognitionActionConfigForSuccess:success mode:mode];
}

- (void)taskEditorViewDidRequestSuccessActionConfig:(AnClickTaskEditorView *)editorView {
    [self beginEditingBranchActionConfigFromEditorView:editorView success:YES];
}

- (void)taskEditorViewDidRequestFailureActionConfig:(AnClickTaskEditorView *)editorView {
    [self beginEditingBranchActionConfigFromEditorView:editorView success:NO];
}

- (void)taskEditorView:(__unused AnClickTaskEditorView *)editorView didSelectActionMode:(AnClickActionMode)mode {
    [self selectActionModeValue:mode];
}

- (void)taskEditorView:(AnClickTaskEditorView *)editorView didUpdateModel:(AnClickTaskModel *)model {
    _editingTaskModel = [model copy];
    if (_editingTaskIndex < 0 && _selectedTaskIndex >= 0 && _selectedTaskIndex < (NSInteger)_taskItems.count) {
        _editingTaskIndex = _selectedTaskIndex;
    }
    [self stageTaskEditorModelForRuntime:model];
    if (editorView == _taskEditorView) {
        _editingTaskModel = [editorView.model copy];
    }
}

- (void)selectTaskAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        return;
    }

    _selectedTaskIndex = index;
    _editingTaskIndex = index;
    [self dismissConfigKeyboardAndSync];
    [self loadTaskConfigurationFromModel:[self taskModelAtIndex:(NSUInteger)index]
                              statusText:[NSString stringWithFormat:@"修改任务%ld", (long)index + 1]];
}

- (void)loadTaskConfigurationFromTask:(NSDictionary *)task statusText:(NSString *)statusText {
    [self loadTaskConfigurationFromModel:[[AnClickTaskModel alloc] initWithDictionary:task] statusText:statusText];
}

- (void)loadTaskConfigurationFromModel:(AnClickTaskModel *)model statusText:(NSString *)statusText {
    if (![model isKindOfClass:AnClickTaskModel.class]) {
        return;
    }
    _editingTaskModel = [model copy];
    [self stageTaskEditorModelForRuntime:model];
    [self refreshModeButtons];
    [self refreshTaskList];
    [self setTaskEditorVisible:YES];
    [self refreshTaskEditorViewFromCurrentState];
    [self updateStatusForCurrentConfig];
    if (statusText.length > 0) {
        _statusLabel.text = [NSString stringWithFormat:@"%@  %@", statusText, _statusLabel.text ?: @""];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) {
        if (gestureRecognizer.view == _panelView) {
            if (_taskEditorVisible || _globalSettingsView || _functionMenuView) {
                return NO;
            }
            CGPoint location = [gestureRecognizer locationInView:_panelView];
            if (!_taskListView.hidden && CGRectContainsPoint(_taskListView.frame, location)) {
                return NO;
            }
        }
    }
    return YES;
}

- (NSTimeInterval)durationForTaskMode:(AnClickActionMode)mode {
    if (mode == AnClickActionModeTap) {
        return AnClickDefaultTapPressDuration;
    }
    if (mode == AnClickActionModeDoubleTap) {
        return AnClickDefaultTapPressDuration + AnClickDefaultDoubleTapInterval + AnClickDefaultTapPressDuration;
    }
    if (mode == AnClickActionModeTwoFingerTap) {
        return AnClickDefaultTapPressDuration;
    }
    if (mode == AnClickActionModeLongPress) {
        return [self longPressOperationDurationForDuration:_longPressDuration];
    }
    if (mode == AnClickActionModeSwipe) {
        return AnClickDefaultSwipeDuration;
    }
    if (mode == AnClickActionModeImage) {
        return 1.45;
    }
    if (mode == AnClickActionModeOCR) {
        return 1.65;
    }
    if (mode == AnClickActionModeColor) {
        return 1.20;
    }
    if (mode == AnClickActionModeNetwork) {
        return 0.85;
    }
    if (mode == AnClickActionModeJump) {
        return 0.0;
    }
    if (mode == AnClickActionModeDelay) {
        return 0.0;
    }
    if (mode == AnClickActionModeMacro) {
        return [self durationForRecordedEvents:_recordedMacroEvents playbackSpeed:_macroPlaybackSpeed];
    }
    return 0.30;
}

- (NSTimeInterval)estimatedActionDurationForTask:(NSDictionary *)task
                                         success:(BOOL)success
                                      actionMode:(AnClickActionMode)actionMode
                                           depth:(NSUInteger)depth {
    if (actionMode == AnClickActionModeNone || actionMode == AnClickActionModeJump) {
        return 0.0;
    }
    if (actionMode == AnClickActionModeNetwork) {
        return [self networkTimeoutForTask:task] + 0.25;
    }
    if ([self modeIsRecognitionTask:actionMode]) {
        return actionMode == AnClickActionModeOCR ? 0.95 : 0.75;
    }
    return [self durationForTaskMode:actionMode];
}

- (NSTimeInterval)estimatedActionDurationForTaskModel:(AnClickTaskModel *)model
                                              success:(BOOL)success
                                           actionMode:(AnClickActionMode)actionMode
                                                depth:(NSUInteger)depth {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    return task ? [self estimatedActionDurationForTask:task success:success actionMode:actionMode depth:depth] : 0.0;
}

- (NSTimeInterval)estimatedTaskDurationForTask:(NSDictionary *)task depth:(NSUInteger)depth {
    AnClickActionMode mode = [self modeForTask:task];
    NSInteger repeatCount = [self repeatCountForTask:task];
    NSTimeInterval delay = [task[@"delay"] respondsToSelector:@selector(doubleValue)] ? MAX(0.0, [task[@"delay"] doubleValue]) : 0.0;
    NSTimeInterval configuredInterval = [self actionIntervalForTask:task];
    NSTimeInterval duration = [self durationForTaskMode:mode];

    if (mode == AnClickActionModeImage ||
        mode == AnClickActionModeOCR ||
        mode == AnClickActionModeColor) {
        AnClickActionMode successMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        AnClickActionMode failureMode = [self failureActionModeForTask:task];
        NSTimeInterval baseDuration = mode == AnClickActionModeOCR ? 0.95 : 0.75;
        NSTimeInterval successDuration = [self estimatedActionDurationForTask:task success:YES actionMode:successMode depth:depth];
        NSTimeInterval failureDuration = [self estimatedActionDurationForTask:task success:NO actionMode:failureMode depth:depth];
        duration = baseDuration + MAX(successDuration, failureDuration);
    } else if (mode == AnClickActionModeNetwork) {
        duration = 0.85;
    } else if (mode == AnClickActionModeMacro) {
        NSArray *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
        duration = [self durationForRecordedEvents:events playbackSpeed:[self macroPlaybackSpeedForTask:task]];
    } else if (mode == AnClickActionModeDoubleTap) {
        duration = [self doubleTapOperationDurationForTask:task];
    } else if (mode == AnClickActionModeLongPress) {
        duration = [self longPressOperationDurationForDuration:[self longPressDurationForTask:task]];
    } else if (mode == AnClickActionModeSwipe) {
        duration = [self swipeDurationForTask:task];
    }

    BOOL pointTapRepeatMode = mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeTwoFingerTap;
    if (repeatCount > 1 && pointTapRepeatMode) {
        NSTimeInterval minimumStep = (mode == AnClickActionModeDoubleTap)
            ? [self doubleTapOperationDurationForTask:task]
            : AnClickDefaultTapPressDuration;
        NSTimeInterval step = MAX(minimumStep, configuredInterval);
        return delay + step * repeatCount;
    }

    NSTimeInterval interval = duration + configuredInterval;
    return delay + duration + interval * MAX(0, repeatCount - 1);
}

- (NSTimeInterval)estimatedTaskDurationForTaskModel:(AnClickTaskModel *)model depth:(NSUInteger)depth {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    return task ? [self estimatedTaskDurationForTask:task depth:depth] : 0.0;
}

- (NSTimeInterval)delayForTask:(NSDictionary *)task {
    NSTimeInterval delay = MAX(0.0, [task[@"delay"] doubleValue]);
    if (![task[@"randomDelay"] boolValue] || delay <= 0.001) {
        return delay;
    }
    CGFloat unit = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    NSTimeInterval minimumDelay = delay >= 1.0 ? 1.0 : 0.0;
    return minimumDelay + (delay - minimumDelay) * unit;
}

- (NSInteger)repeatCountForTask:(NSDictionary *)task {
    return MAX(1, [task[@"repeat"] integerValue]);
}

- (NSTimeInterval)actionIntervalForTask:(NSDictionary *)task {
    id value = task[@"interval"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return MIN(30.0, MAX(0.0, [value doubleValue]));
    }
    return AnClickDefaultTapPressDuration;
}

- (CGFloat)jitterRadiusForTask:(NSDictionary *)task {
    id value = task[@"jitterRadius"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return MIN(200.0, MAX(0.0, [value doubleValue]));
    }
    return 0.0;
}

- (CGPoint)point:(CGPoint)point byApplyingJitterForTask:(NSDictionary *)task {
    CGFloat radius = [self jitterRadiusForTask:task];
    if (radius <= 0.001) {
        return point;
    }
    CGFloat unitRadius = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    CGFloat unitAngle = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    CGFloat distance = sqrt(unitRadius) * radius;
    CGFloat angle = unitAngle * (CGFloat)(M_PI * 2.0);
    CGPoint jitteredPoint = CGPointMake(point.x + cos(angle) * distance, point.y + sin(angle) * distance);
    CGSize screenSize = [self currentScreenCoordinateSize];
    if ([self screenCoordinateSizeIsValid:screenSize]) {
        jitteredPoint.x = MIN(MAX(0.0, jitteredPoint.x), screenSize.width);
        jitteredPoint.y = MIN(MAX(0.0, jitteredPoint.y), screenSize.height);
    }
    return jitteredPoint;
}

- (NSArray<NSValue *> *)path:(NSArray<NSValue *> *)path byApplyingJitterForTask:(NSDictionary *)task {
    CGFloat radius = [self jitterRadiusForTask:task];
    if (radius <= 0.001 || path.count == 0) {
        return path;
    }
    CGFloat unitRadius = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    CGFloat unitAngle = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    CGFloat distance = sqrt(unitRadius) * radius;
    CGFloat angle = unitAngle * (CGFloat)(M_PI * 2.0);
    CGFloat dx = cos(angle) * distance;
    CGFloat dy = sin(angle) * distance;
    NSMutableArray<NSValue *> *jitteredPath = [NSMutableArray arrayWithCapacity:path.count];
    CGSize screenSize = [self currentScreenCoordinateSize];
    BOOL hasScreenSize = [self screenCoordinateSizeIsValid:screenSize];
    for (NSValue *value in path) {
        CGPoint point = value.CGPointValue;
        point.x += dx;
        point.y += dy;
        if (hasScreenSize) {
            point.x = MIN(MAX(0.0, point.x), screenSize.width);
            point.y = MIN(MAX(0.0, point.y), screenSize.height);
        }
        [jitteredPath addObject:[NSValue valueWithCGPoint:point]];
    }
    return jitteredPath;
}

- (NSArray<NSValue *> *)path:(NSArray<NSValue *> *)path byApplyingSwipeStepForTask:(NSDictionary *)task {
    if (path.count < 2) {
        return path ?: @[];
    }
    id value = task[@"swipeStep"];
    CGFloat step = [value respondsToSelector:@selector(doubleValue)] ? (CGFloat)[value doubleValue] : 0.0;
    if (step < 1.0) {
        return path;
    }

    NSMutableArray<NSValue *> *steppedPath = [NSMutableArray arrayWithCapacity:path.count];
    [steppedPath addObject:path.firstObject];
    for (NSUInteger index = 1; index < path.count; index++) {
        CGPoint start = path[index - 1].CGPointValue;
        CGPoint end = path[index].CGPointValue;
        CGFloat dx = end.x - start.x;
        CGFloat dy = end.y - start.y;
        CGFloat distance = sqrt(dx * dx + dy * dy);
        NSUInteger segments = MAX((NSUInteger)1, (NSUInteger)ceil(distance / step));
        for (NSUInteger segment = 1; segment <= segments; segment++) {
            CGFloat t = (CGFloat)segment / (CGFloat)segments;
            CGPoint point = CGPointMake(start.x + dx * t, start.y + dy * t);
            [steppedPath addObject:[NSValue valueWithCGPoint:point]];
            if (steppedPath.count >= AnClickMacroMaxTrajectoryPoints) {
                return steppedPath;
            }
        }
    }
    return steppedPath;
}

- (NSArray<NSValue *> *)points:(NSArray<NSValue *> *)points byApplyingJitterForTask:(NSDictionary *)task {
    if (points.count == 0) {
        return @[];
    }
    CGFloat radius = [self jitterRadiusForTask:task];
    if (radius <= 0.001) {
        return points;
    }
    NSMutableArray<NSValue *> *jitteredPoints = [NSMutableArray arrayWithCapacity:points.count];
    for (NSValue *value in points) {
        if (![value isKindOfClass:NSValue.class]) {
            continue;
        }
        [jitteredPoints addObject:[NSValue valueWithCGPoint:[self point:value.CGPointValue byApplyingJitterForTask:task]]];
    }
    return jitteredPoints;
}

- (NSArray<NSDictionary *> *)recordedEvents:(NSArray<NSDictionary *> *)events byApplyingJitterForTask:(NSDictionary *)task {
    CGFloat radius = [self jitterRadiusForTask:task];
    if (radius <= 0.001 || events.count == 0) {
        return events;
    }
    CGFloat unitRadius = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    CGFloat unitAngle = (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
    CGFloat distance = sqrt(unitRadius) * radius;
    CGFloat angle = unitAngle * (CGFloat)(M_PI * 2.0);
    CGFloat dx = cos(angle) * distance;
    CGFloat dy = sin(angle) * distance;
    CGSize screenSize = [self currentScreenCoordinateSize];
    BOOL hasScreenSize = [self screenCoordinateSizeIsValid:screenSize];
    NSMutableArray<NSDictionary *> *jitteredEvents = [NSMutableArray arrayWithCapacity:events.count];
    for (NSDictionary *event in events) {
        if (![event isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSMutableDictionary *jitteredEvent = [event mutableCopy];
        if ([event[@"x"] respondsToSelector:@selector(doubleValue)] &&
            [event[@"y"] respondsToSelector:@selector(doubleValue)]) {
            CGFloat x = [event[@"x"] doubleValue] + dx;
            CGFloat y = [event[@"y"] doubleValue] + dy;
            if (hasScreenSize) {
                x = MIN(MAX(0.0, x), screenSize.width);
                y = MIN(MAX(0.0, y), screenSize.height);
            }
            jitteredEvent[@"x"] = @(x);
            jitteredEvent[@"y"] = @(y);
        }
        [jitteredEvents addObject:jitteredEvent];
    }
    return jitteredEvents;
}

- (BOOL)modeIsRecognitionTask:(AnClickActionMode)mode {
    return mode == AnClickActionModeImage ||
        mode == AnClickActionModeOCR ||
        mode == AnClickActionModeColor;
}

- (BOOL)modeIsJudgementTask:(AnClickActionMode)mode {
    return [self modeIsRecognitionTask:mode] || mode == AnClickActionModeNetwork;
}

- (BOOL)modeCanUseRecognitionPoint:(AnClickActionMode)mode {
    return mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeTwoFingerTap;
}

- (NSMutableDictionary *)draftActionTaskForMode:(AnClickActionMode)mode {
    NSMutableDictionary *task = [@{
        @"mode": @(mode),
        @"delay": @0.0,
        @"repeat": @1,
        @"interval": @(AnClickDefaultTapPressDuration),
        @"imageActionMode": @(AnClickActionModeTap),
        @"failureActionMode": @(AnClickActionModeNone),
        @"recognitionRetryUntilFound": @NO,
        @"recognitionRetryInterval": @1.0,
    } mutableCopy];
    if (mode == AnClickActionModeDelay) {
        task[@"delay"] = @0.50;
    } else if (mode == AnClickActionModeNetwork) {
        task[@"networkMethod"] = @"GET";
        task[@"networkTimeout"] = @8.0;
        task[@"networkRetryForever"] = @YES;
        task[@"networkRetryLimit"] = @3;
    } else if (mode == AnClickActionModeSwipe) {
        task[@"swipeDuration"] = @0.30;
        task[@"swipeStep"] = @1.0;
    } else if (mode == AnClickActionModeImage) {
        task[@"useMatchPoint"] = @YES;
        task[@"threshold"] = @0.80;
    } else if (mode == AnClickActionModeOCR) {
        task[@"ocrText"] = @"";
        task[@"ocrMode"] = @(AnClickOCRModeAppleVision);
        task[@"ocrBackendVersion"] = @1;
        task[@"ocrMatchMode"] = @(AnClickOCRMatchModeContains);
        task[@"ocrSimilarity"] = @0.80;
        task[@"useMatchPoint"] = @YES;
    } else if (mode == AnClickActionModeColor) {
        task[@"colorTolerance"] = @18.0;
    }
    return task;
}

- (NSMutableDictionary *)draftRecognitionTaskForMode:(AnClickActionMode)mode {
    return [self draftActionTaskForMode:mode];
}

- (NSString *)recognitionActionConfigKeyForSuccess:(BOOL)success {
    return success ? @"successRecognitionActionConfig" : @"failureRecognitionActionConfig";
}

- (NSString *)branchActionConfigKeyForSuccess:(BOOL)success {
    return success ? @"successActionConfig" : @"failureActionConfig";
}

- (NSDictionary *)branchActionConfigForTask:(NSDictionary *)task success:(BOOL)success expectedMode:(AnClickActionMode)expectedMode {
    if (![self isSelectableActionMode:expectedMode]) {
        return nil;
    }
    id fullConfig = task[[self branchActionConfigKeyForSuccess:success]];
    if ([fullConfig isKindOfClass:NSDictionary.class] &&
        [self modeForTask:(NSDictionary *)fullConfig] == expectedMode) {
        NSDictionary *fullConfigDictionary = (NSDictionary *)fullConfig;
        if ([self modeCanUseRecognitionPoint:expectedMode]) {
            id useMatchPointValue = fullConfigDictionary[@"useMatchPoint"];
            BOOL useMatchPoint = [useMatchPointValue respondsToSelector:@selector(boolValue)]
                ? [useMatchPointValue boolValue]
                : YES;
            if (useMatchPoint) {
                return nil;
            }
        }
        return fullConfigDictionary;
    }
    if (![self modeIsRecognitionTask:expectedMode]) {
        return nil;
    }
    id config = task[[self recognitionActionConfigKeyForSuccess:success]];
    if ([config isKindOfClass:NSDictionary.class] &&
        [self modeForTask:(NSDictionary *)config] == expectedMode) {
        return (NSDictionary *)config;
    }
    return nil;
}

- (NSDictionary *)recognitionActionConfigForTask:(NSDictionary *)task success:(BOOL)success expectedMode:(AnClickActionMode)expectedMode {
    if (![self modeIsRecognitionTask:expectedMode]) {
        return nil;
    }
    return [self branchActionConfigForTask:task success:success expectedMode:expectedMode];
}

- (NSDictionary *)currentStoredBranchActionConfigForSuccess:(BOOL)success mode:(AnClickActionMode)mode {
    if (_selectedTaskIndex < 0 || _selectedTaskIndex >= (NSInteger)_taskItems.count) {
        return nil;
    }
    NSDictionary *ownerTask = [self taskDictionaryAtIndex:(NSUInteger)_selectedTaskIndex];
    return [self branchActionConfigForTask:ownerTask success:success expectedMode:mode];
}

- (NSMutableDictionary *)ensureMutableBranchActionConfigForSuccess:(BOOL)success mode:(AnClickActionMode)mode {
    if (![self isSelectableActionMode:mode] ||
        mode == AnClickActionModeJump ||
        _selectedTaskIndex < 0 ||
        _selectedTaskIndex >= (NSInteger)_taskItems.count) {
        return nil;
    }

    NSMutableDictionary *ownerTask = [self taskDictionaryAtIndex:(NSUInteger)_selectedTaskIndex];
    if (!ownerTask) {
        ownerTask = [NSMutableDictionary dictionary];
    }

    NSDictionary *existingConfig = [self branchActionConfigForTask:ownerTask success:success expectedMode:mode];
    NSMutableDictionary *config = existingConfig ? [existingConfig mutableCopy] : [self draftActionTaskForMode:mode];
    config[@"mode"] = @(mode);
    ownerTask[[self branchActionConfigKeyForSuccess:success]] = config;
    if ([self modeIsRecognitionTask:mode]) {
        ownerTask[[self recognitionActionConfigKeyForSuccess:success]] = config;
    }
    _taskItems[(NSUInteger)_selectedTaskIndex] = [[AnClickTaskModel alloc] initWithDictionary:ownerTask];
    [self persistCurrentTaskList];
    [self refreshCollapsedButtonTitle];
    return config;
}

- (void)storeBranchActionConfig:(NSMutableDictionary *)config success:(BOOL)success mode:(AnClickActionMode)mode {
    if (!config ||
        _selectedTaskIndex < 0 ||
        _selectedTaskIndex >= (NSInteger)_taskItems.count) {
        return;
    }
    config[@"mode"] = @(mode);
    NSMutableDictionary *ownerTask = [self taskDictionaryAtIndex:(NSUInteger)_selectedTaskIndex];
    if (!ownerTask) {
        ownerTask = [NSMutableDictionary dictionary];
    }
    ownerTask[[self branchActionConfigKeyForSuccess:success]] = [config mutableCopy];
    if ([self modeIsRecognitionTask:mode]) {
        ownerTask[[self recognitionActionConfigKeyForSuccess:success]] = [config mutableCopy];
    }
    _taskItems[(NSUInteger)_selectedTaskIndex] = [[AnClickTaskModel alloc] initWithDictionary:ownerTask];
    _editingTaskModel = [[AnClickTaskModel alloc] initWithDictionary:ownerTask];
    [self persistCurrentTaskList];
    [self refreshCollapsedButtonTitle];
}

- (void)beginEditingRecognitionActionConfigForSuccess:(BOOL)success mode:(AnClickActionMode)mode {
    if (![self isSelectableActionMode:mode] ||
        mode == AnClickActionModeJump ||
        _selectedTaskIndex < 0 ||
        _selectedTaskIndex >= (NSInteger)_taskItems.count) {
        _statusLabel.text = @"先保存主任务";
        return;
    }

    AnClickTaskModel *editorModel = _editingTaskModel ?: [self taskEditorModelByMergingRuntimeState];
    NSMutableDictionary *ownerTask = [self taskDictionaryForModel:editorModel];
    if (ownerTask) {
        NSDictionary *existingConfig = [self currentStoredBranchActionConfigForSuccess:success mode:mode];
        if (existingConfig) {
            ownerTask[[self branchActionConfigKeyForSuccess:success]] = [existingConfig mutableCopy];
            if ([self modeIsRecognitionTask:mode]) {
                ownerTask[[self recognitionActionConfigKeyForSuccess:success]] = [existingConfig mutableCopy];
            }
        }
        _taskItems[(NSUInteger)_selectedTaskIndex] = [[AnClickTaskModel alloc] initWithDictionary:ownerTask];
        [self persistCurrentTaskList];
    }

    NSInteger ownerIndex = _selectedTaskIndex;
    NSDictionary *storedConfig = [self branchActionConfigForTask:[self taskDictionaryAtIndex:(NSUInteger)ownerIndex]
                                                        success:success
                                                   expectedMode:mode];
    NSMutableDictionary *branchTask = storedConfig ? [storedConfig mutableCopy] : [self draftActionTaskForMode:mode];
    branchTask[@"mode"] = @(mode);
    NSDictionary *ownerTaskForMode = [self taskDictionaryAtIndex:(NSUInteger)ownerIndex];
    if ([self modeForTask:ownerTaskForMode] == AnClickActionModeNetwork &&
        [self modeCanUseRecognitionPoint:mode]) {
        branchTask[@"useMatchPoint"] = @NO;
    }

    _editingBranchRecognitionConfig = YES;
    _editingBranchRecognitionSuccess = success;
    _editingBranchOwnerTaskIndex = ownerIndex;
    _editingBranchActionMode = mode;
    _selectedTaskIndex = -1;
    _editingTaskIndex = ownerIndex;
    _editingTaskModel = [[AnClickTaskModel alloc] initWithDictionary:branchTask];
    [self loadTaskConfigurationFromTask:branchTask
                             statusText:[NSString stringWithFormat:@"设置%@后%@",
                                         success ? @"成功" : @"失败",
                                         [self actionNameForMode:mode]]];
}

- (AnClickActionMode)successActionModeForTask:(NSDictionary *)task {
    if (![self modeIsJudgementTask:[self modeForTask:task]]) {
        return AnClickActionModeNone;
    }
    id value = task[@"imageActionMode"];
    if (![value respondsToSelector:@selector(integerValue)]) {
        return AnClickActionModeTap;
    }
    return [self normalizedImageActionMode:(AnClickActionMode)[value integerValue]];
}

- (BOOL)recognitionActionModeNeedsPoint:(AnClickActionMode)mode {
    return mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeTwoFingerTap;
}

- (BOOL)recognitionBranchActionModeCanUsePointFallback:(AnClickActionMode)mode {
    return [self recognitionActionModeNeedsPoint:mode];
}

- (BOOL)recognitionBranchActionModeRequiresConfig:(AnClickActionMode)mode {
    if (mode == AnClickActionModeNone || mode == AnClickActionModeJump) {
        return NO;
    }
    return ![self recognitionBranchActionModeCanUsePointFallback:mode];
}

- (NSString *)recognitionActionDisplayNameForMode:(AnClickActionMode)mode networkName:(NSString *)networkName {
    if (mode == AnClickActionModeNetwork) {
        return [NSString stringWithFormat:@"%@网络", networkName.length > 0 ? networkName : @"请求"];
    }
    if (mode == AnClickActionModeJump) {
        return @"跳转任务";
    }
    if ([self modeIsRecognitionTask:mode]) {
        return [NSString stringWithFormat:@"%@任务", [self actionNameForMode:mode]];
    }
    return [self actionNameForMode:mode];
}

- (BOOL)recognitionRetryUntilFoundForTask:(NSDictionary *)task {
    if (![self modeIsRecognitionTask:[self modeForTask:task]]) {
        return NO;
    }
    id value = task[@"recognitionRetryUntilFound"];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

- (NSTimeInterval)recognitionRetryIntervalForTask:(NSDictionary *)task {
    id value = task[@"recognitionRetryInterval"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return MIN(30.0, MAX(0.2, [value doubleValue]));
    }
    return 1.0;
}

- (NSInteger)recognitionBranchIndexForTask:(NSDictionary *)task success:(BOOL)success {
    if (![self modeIsJudgementTask:[self modeForTask:task]]) {
        return -1;
    }
    id value = task[success ? @"successBranchIndex" : @"failureBranchIndex"];
    if (![value respondsToSelector:@selector(integerValue)]) {
        return -1;
    }
    NSInteger branchIndex = [value integerValue];
    return branchIndex >= 0 ? branchIndex : -1;
}

- (NSInteger)validRecognitionBranchIndexForTask:(NSDictionary *)task success:(BOOL)success {
    NSInteger branchIndex = [self recognitionBranchIndexForTask:task success:success];
    if (branchIndex < 0 || branchIndex >= (NSInteger)_taskItems.count) {
        return -1;
    }
    return branchIndex;
}

- (BOOL)recognitionTaskUsesJumpActionForTask:(NSDictionary *)task success:(BOOL)success {
    if (![self modeIsJudgementTask:[self modeForTask:task]]) {
        return NO;
    }
    if (success) {
        AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        return actionMode == AnClickActionModeJump;
    }
    return [self failureActionModeForTask:task] == AnClickActionModeJump;
}

- (NSInteger)validRecognitionJumpIndexForTask:(NSDictionary *)task success:(BOOL)success {
    if (![self recognitionTaskUsesJumpActionForTask:task success:success]) {
        return -1;
    }
    return [self validRecognitionBranchIndexForTask:task success:success];
}

- (AnClickActionMode)failureActionModeForTask:(NSDictionary *)task {
    if (![self modeIsJudgementTask:[self modeForTask:task]]) {
        return AnClickActionModeNone;
    }
    id value = task[@"failureActionMode"];
    if (![value respondsToSelector:@selector(integerValue)]) {
        return AnClickActionModeNone;
    }
    return [self normalizedFailureActionMode:(AnClickActionMode)[value integerValue]];
}

- (BOOL)failureActionModeNeedsPoint:(AnClickActionMode)mode {
    return [self recognitionActionModeNeedsPoint:mode];
}

- (CGPoint)resolvedPoint:(CGPoint)point forTask:(NSDictionary *)task screenSizeKey:(NSString *)screenSizeKey {
    CGSize sourceSize = [self screenCoordinateSizeFromObject:task[screenSizeKey]];
    CGSize targetSize = [self currentScreenCoordinateSize];
    if (![self screenCoordinateSizeIsValid:sourceSize]) {
        sourceSize = [self inferredRotatedSourceSizeForPoint:point targetSize:targetSize];
    }
    return [self point:point mappedFromScreenSize:sourceSize toScreenSize:targetSize];
}

- (BOOL)successActionPointForTask:(NSDictionary *)task
                        matchPoint:(CGPoint)matchPoint
                     hasMatchPoint:(BOOL)hasMatchPoint
                  customPointValue:(NSValue *)customPointValue
                     useMatchPoint:(BOOL)useMatchPoint
                             point:(CGPoint *)point {
    NSValue *successPointValue = task[@"successPoint"];
    if (successPointValue) {
        if (point) {
            *point = [self resolvedPoint:successPointValue.CGPointValue forTask:task screenSizeKey:@"successPointScreenSize"];
        }
        return YES;
    }
    if (useMatchPoint && hasMatchPoint) {
        if (point) {
            *point = matchPoint;
        }
        return YES;
    }
    if (customPointValue) {
        if (point) {
            *point = [self resolvedPointForTask:task fallbackPoint:customPointValue.CGPointValue];
        }
        return YES;
    }
    return NO;
}

- (BOOL)failureActionPointForTask:(NSDictionary *)task point:(CGPoint *)point {
    NSValue *failurePointValue = task[@"failurePoint"];
    if (failurePointValue) {
        if (point) {
            *point = [self resolvedPoint:failurePointValue.CGPointValue forTask:task screenSizeKey:@"failurePointScreenSize"];
        }
        return YES;
    }
    NSValue *pointValue = task[@"point"];
    if (pointValue) {
        if (point) {
            *point = [self resolvedPointForTask:task fallbackPoint:pointValue.CGPointValue];
        }
        return YES;
    }
    if ([self modeForTask:task] == AnClickActionModeColor) {
        NSDictionary *anchor = [self normalizedColorPatternPointsForTask:task].firstObject;
        if ([anchor[@"x"] respondsToSelector:@selector(doubleValue)] &&
            [anchor[@"y"] respondsToSelector:@selector(doubleValue)]) {
            if (point) {
                *point = CGPointMake([anchor[@"x"] doubleValue], [anchor[@"y"] doubleValue]);
            }
            return YES;
        }
    }
    return NO;
}

- (BOOL)validateSuccessRecognitionActionTaskForTask:(NSDictionary *)task {
    AnClickActionMode successMode = [self successActionModeForTask:task];
    NSDictionary *config = [self branchActionConfigForTask:task success:YES expectedMode:successMode];
    if (config) {
        return [self taskModelIsComplete:[[AnClickTaskModel alloc] initWithDictionary:config]];
    }
    if ([self modeForTask:task] == AnClickActionModeNetwork &&
        successMode != AnClickActionModeNone &&
        successMode != AnClickActionModeJump) {
        _statusLabel.text = [NSString stringWithFormat:@"网络成功后%@动作未设置", [self actionNameForMode:successMode]];
        return NO;
    }
    if ([self recognitionBranchActionModeRequiresConfig:successMode]) {
        _statusLabel.text = [NSString stringWithFormat:@"成功后%@动作未设置", [self actionNameForMode:successMode]];
        return NO;
    }
    return YES;
}

- (BOOL)validateFailureRecognitionActionTaskForTask:(NSDictionary *)task {
    AnClickActionMode failureMode = [self failureActionModeForTask:task];
    NSDictionary *config = [self branchActionConfigForTask:task success:NO expectedMode:failureMode];
    if (config) {
        return [self taskModelIsComplete:[[AnClickTaskModel alloc] initWithDictionary:config]];
    }
    if ([self modeForTask:task] == AnClickActionModeNetwork &&
        failureMode != AnClickActionModeNone &&
        failureMode != AnClickActionModeJump) {
        _statusLabel.text = [NSString stringWithFormat:@"网络失败后%@动作未设置", [self actionNameForMode:failureMode]];
        return NO;
    }
    if ([self recognitionBranchActionModeRequiresConfig:failureMode]) {
        _statusLabel.text = [NSString stringWithFormat:@"失败后%@动作未设置", [self actionNameForMode:failureMode]];
        return NO;
    }
    return YES;
}

- (BOOL)validateRecognitionJumpActionForTask:(NSDictionary *)task {
    if (![self modeIsJudgementTask:[self modeForTask:task]]) {
        return YES;
    }

    if ([self recognitionTaskUsesJumpActionForTask:task success:YES]) {
        NSInteger taskIndex = [self recognitionBranchIndexForTask:task success:YES];
        if (taskIndex < 0) {
            _statusLabel.text = @"成功后跳转任务号未设置";
            return NO;
        }
        if (taskIndex >= (NSInteger)_taskItems.count) {
            _statusLabel.text = [NSString stringWithFormat:@"成功后任务%ld不存在", (long)taskIndex + 1];
            return NO;
        }
    }

    if ([self recognitionTaskUsesJumpActionForTask:task success:NO]) {
        NSInteger taskIndex = [self recognitionBranchIndexForTask:task success:NO];
        if (taskIndex < 0) {
            _statusLabel.text = @"失败后跳转任务号未设置";
            return NO;
        }
        if (taskIndex >= (NSInteger)_taskItems.count) {
            _statusLabel.text = [NSString stringWithFormat:@"失败后任务%ld不存在", (long)taskIndex + 1];
            return NO;
        }
    }

    return YES;
}

- (void)storeRecognitionRetryConfigInTask:(NSMutableDictionary *)task {
    task[@"recognitionRetryUntilFound"] = @(_recognitionRetryUntilFound);
    task[@"recognitionRetryInterval"] = @(MIN(30.0, MAX(0.2, _recognitionRetryInterval)));
}

- (BOOL)storeRecognitionSuccessActionConfigInTask:(NSMutableDictionary *)task requireComplete:(BOOL)requireComplete {
    AnClickActionMode successMode = [self normalizedImageActionMode:_imageActionMode];
    if (successMode == AnClickActionModeJump) {
        return YES;
    }

    NSDictionary *config = [self currentStoredBranchActionConfigForSuccess:YES mode:successMode];
    if (config) {
        task[@"successActionConfig"] = config;
        if ([self modeIsRecognitionTask:successMode]) {
            task[@"successRecognitionActionConfig"] = config;
        }
        return YES;
    }
    if (requireComplete && [self recognitionBranchActionModeRequiresConfig:successMode]) {
        _statusLabel.text = [NSString stringWithFormat:@"先设置成功后%@配置", [self actionNameForMode:successMode]];
        return NO;
    }
    return YES;
}

- (BOOL)storeRecognitionJumpActionConfigInTask:(NSMutableDictionary *)task requireComplete:(BOOL)requireComplete {
    if ([self normalizedImageActionMode:_imageActionMode] == AnClickActionModeJump) {
        if (_recognitionSuccessBranchIndex >= 0) {
            task[@"successBranchIndex"] = @(_recognitionSuccessBranchIndex);
        } else if (requireComplete) {
            _statusLabel.text = @"先填成功后跳转任务号";
            return NO;
        }
    }
    if ([self normalizedFailureActionMode:_failureActionMode] == AnClickActionModeJump) {
        if (_recognitionFailureBranchIndex >= 0) {
            task[@"failureBranchIndex"] = @(_recognitionFailureBranchIndex);
        } else if (requireComplete) {
            _statusLabel.text = @"先填失败后跳转任务号";
            return NO;
        }
    }
    return YES;
}

- (BOOL)storeRecognitionFailureActionConfigInTask:(NSMutableDictionary *)task requireComplete:(BOOL)requireComplete {
    AnClickActionMode failureMode = [self normalizedFailureActionMode:_failureActionMode];
    if (failureMode == AnClickActionModeNone || failureMode == AnClickActionModeJump) {
        return YES;
    }

    NSDictionary *config = [self currentStoredBranchActionConfigForSuccess:NO mode:failureMode];
    if (config) {
        task[@"failureActionConfig"] = config;
        if ([self modeIsRecognitionTask:failureMode]) {
            task[@"failureRecognitionActionConfig"] = config;
        }
        return YES;
    }
    if (requireComplete && [self recognitionBranchActionModeRequiresConfig:failureMode]) {
        _statusLabel.text = [NSString stringWithFormat:@"先设置失败后%@配置", [self actionNameForMode:failureMode]];
        return NO;
    }
    return YES;
}

- (void)loadRecognitionRetryConfigFromTask:(NSDictionary *)task {
    _recognitionRetryUntilFound = [self recognitionRetryUntilFoundForTask:task];
    _recognitionRetryDropdownVisible = NO;
    _recognitionRetryInterval = [self recognitionRetryIntervalForTask:task];
    _recognitionSuccessBranchIndex = [self recognitionBranchIndexForTask:task success:YES];
    _recognitionFailureBranchIndex = [self recognitionBranchIndexForTask:task success:NO];
}

- (NSTimeInterval)networkTimeoutForTask:(NSDictionary *)task {
    id value = task[@"networkTimeout"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return MIN(60.0, MAX(1.0, [value doubleValue]));
    }
    return 8.0;
}

- (BOOL)networkRetryForeverForTask:(NSDictionary *)task {
    id value = task[@"networkRetryForever"];
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    return YES;
}

- (NSInteger)networkRetryLimitForTask:(NSDictionary *)task {
    id value = task[@"networkRetryLimit"];
    if ([value respondsToSelector:@selector(integerValue)]) {
        return MIN(99, MAX(1, [value integerValue]));
    }
    return [self repeatCountForTask:task];
}

- (NSString *)normalizedNetworkMethodFromPostFlag:(BOOL)usesPost {
    return usesPost ? @"POST" : @"GET";
}

- (NSString *)networkMethodForTask:(NSDictionary *)task {
    NSString *rawMethod = [task[@"networkMethod"] isKindOfClass:NSString.class] ? task[@"networkMethod"] : nil;
    NSString *method = [rawMethod uppercaseString];
    if ([method isEqualToString:@"POST"]) {
        return @"POST";
    }
    if ([method isEqualToString:@"GET"]) {
        return @"GET";
    }
    return [task[@"networkUsesPost"] boolValue] ? @"POST" : @"GET";
}

- (NSString *)networkPostBodyForTask:(NSDictionary *)task {
    return [self trimmedActionDescription:task[@"networkPostBody"]];
}

- (NSString *)postBody:(NSString *)postBody applyingRecognitionText:(NSString *)recognitionText {
    NSString *body = postBody ?: @"";
    NSString *value = recognitionText ?: @"";
    NSArray<NSString *> *tokens = @[
        @"{{ocr}}",
        @"{{result}}",
        @"{{识别结果}}",
        @"{{识字结果}}",
        @"{{正则结果}}",
        @"{{正则识别结果}}",
        @"${ocr}",
        @"${result}",
        @"{识别结果}",
        @"{识字结果}",
        @"{正则结果}",
        @"{正则识别结果}",
    ];
    for (NSString *token in tokens) {
        body = [body stringByReplacingOccurrencesOfString:token withString:value];
    }
    return body;
}

- (NSString *)networkPostKeyValueTextForTask:(NSDictionary *)task {
    return [self trimmedActionDescription:task[@"networkPostExtraFields"]];
}

- (id)networkPostJSONValueFromText:(NSString *)text recognitionText:(NSString *)recognitionText {
    NSString *value = [self postBody:[self unquotedNetworkPostText:text] applyingRecognitionText:recognitionText];
    NSString *lower = [[self trimmedActionDescription:value] lowercaseString];
    if ([lower isEqualToString:@"true"]) {
        return @(YES);
    }
    if ([lower isEqualToString:@"false"]) {
        return @(NO);
    }
    if ([lower isEqualToString:@"null"]) {
        return NSNull.null;
    }
    return value ?: @"";
}

- (id)networkPostJSONObjectByApplyingRecognitionText:(id)object recognitionText:(NSString *)recognitionText {
    if ([object isKindOfClass:NSString.class]) {
        return [self postBody:object applyingRecognitionText:recognitionText];
    }
    if ([object isKindOfClass:NSArray.class]) {
        NSMutableArray *array = [NSMutableArray array];
        for (id item in (NSArray *)object) {
            [array addObject:[self networkPostJSONObjectByApplyingRecognitionText:item recognitionText:recognitionText] ?: NSNull.null];
        }
        return array;
    }
    if ([object isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id key, id value, __unused BOOL *stop) {
            if (![key isKindOfClass:NSString.class]) {
                return;
            }
            dictionary[key] = [self networkPostJSONObjectByApplyingRecognitionText:value recognitionText:recognitionText] ?: NSNull.null;
        }];
        return dictionary;
    }
    return object ?: NSNull.null;
}

- (NSDictionary *)networkPostDictionaryFromKeyValueText:(NSString *)text recognitionText:(NSString *)recognitionText {
    NSString *rule = [self trimmedActionDescription:text];
    if (rule.length == 0) {
        return nil;
    }

    if ([rule hasPrefix:@"{"]) {
        NSData *data = [rule dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
        if (!error && [object isKindOfClass:NSDictionary.class]) {
            id appliedObject = [self networkPostJSONObjectByApplyingRecognitionText:object recognitionText:recognitionText];
            return [appliedObject isKindOfClass:NSDictionary.class] ? appliedObject : nil;
        }
    }

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSCharacterSet *pairSeparators = [NSCharacterSet characterSetWithCharactersInString:@"&;\n；"];
    NSArray<NSString *> *pairs = [rule componentsSeparatedByCharactersInSet:pairSeparators];
    for (NSString *pair in pairs) {
        NSString *trimmedPair = [self trimmedActionDescription:pair];
        if (trimmedPair.length == 0) {
            continue;
        }
        NSRange separatorRange = [trimmedPair rangeOfString:@"="];
        if (separatorRange.location == NSNotFound) {
            separatorRange = [trimmedPair rangeOfString:@":"];
        }
        if (separatorRange.location == NSNotFound) {
            continue;
        }
        NSString *key = [self unquotedNetworkPostText:[trimmedPair substringToIndex:separatorRange.location]];
        if (key.length == 0) {
            continue;
        }
        NSString *valueText = [trimmedPair substringFromIndex:NSMaxRange(separatorRange)];
        dictionary[key] = [self networkPostJSONValueFromText:valueText recognitionText:recognitionText];
    }
    return dictionary.count > 0 ? dictionary : nil;
}

- (NSDictionary *)networkPostDictionaryFromPairs:(NSArray *)pairs recognitionText:(NSString *)recognitionText {
    if (![pairs isKindOfClass:NSArray.class]) {
        return nil;
    }
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (NSDictionary *pair in pairs) {
        if (![pair isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *key = [self trimmedActionDescription:pair[@"key"]];
        if (key.length == 0) {
            continue;
        }
        BOOL usesResult = [pair[@"useResult"] boolValue];
        NSString *valueText = usesResult ? (recognitionText ?: @"") : [self networkPostSelfFilledValueFromText:pair[@"value"]];
        dictionary[key] = [self networkPostJSONValueFromText:valueText recognitionText:recognitionText];
    }
    return dictionary.count > 0 ? dictionary : nil;
}

- (NSString *)networkPostJSONStringFromDictionary:(NSDictionary *)dictionary {
    if (![NSJSONSerialization isValidJSONObject:dictionary]) {
        return nil;
    }
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    if (error || data.length == 0) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSString *)networkPostBodyForTask:(NSDictionary *)task recognitionText:(NSString *)recognitionText {
    if ([task[@"networkPostPairs"] isKindOfClass:NSArray.class]) {
        NSString *appliedRecognitionText = [task[@"networkPostBodyUsesOCRResult"] boolValue] ? recognitionText : @"";
        NSDictionary *postDictionary = [self networkPostDictionaryFromPairs:task[@"networkPostPairs"]
                                                            recognitionText:appliedRecognitionText];
        if (!postDictionary) {
            postDictionary = [self networkPostDictionaryFromKeyValueText:[self networkPostKeyValueTextForTask:task]
                                                         recognitionText:appliedRecognitionText];
        }
        NSString *jsonBody = postDictionary ? [self networkPostJSONStringFromDictionary:postDictionary] : nil;
        if (jsonBody.length > 0) {
            return jsonBody;
        }
        if ([task[@"networkPostBodyUsesOCRResult"] boolValue]) {
            return [self trimmedActionDescription:recognitionText] ?: @"";
        }
    }

    NSString *postBody = [self networkPostBodyForTask:task];
    if (postBody.length == 0 || recognitionText.length == 0) {
        return postBody;
    }
    return [self postBody:postBody applyingRecognitionText:recognitionText];
}

- (NSString *)normalizedNetworkURLString:(NSString *)urlText {
    return [_networkService normalizedURLString:urlText];
}

- (BOOL)networkBody:(NSString *)body matchesRegexPattern:(NSString *)pattern {
    return [_networkService body:body matchesRegexPattern:pattern];
}

- (BOOL)networkBody:(NSString *)body matchesRuleText:(NSString *)ruleText {
    return [_networkService body:body matchesRuleText:ruleText];
}

- (BOOL)networkBody:(NSString *)body matchesTrueText:(NSString *)trueText falseText:(NSString *)falseText defaultExpectedTrue:(BOOL)defaultExpectedTrue {
    return [_networkService body:body
                 matchesTrueText:trueText
                       falseText:falseText
             defaultExpectedTrue:defaultExpectedTrue];
}

- (BOOL)networkBody:(NSString *)body matchesBlockText:(NSString *)falseText defaultExpectedTrue:(BOOL)defaultExpectedTrue {
    return [_networkService body:body
                matchesBlockText:falseText
             defaultExpectedTrue:defaultExpectedTrue];
}

- (NSString *)globalNetworkGateValidationMessage {
    if (!_globalNetworkGateEnabled) {
        return nil;
    }

    [self syncGlobalSettingsFromFields];
    NSString *url = [self trimmedActionDescription:_globalNetworkURL];
    NSString *contains = [self trimmedActionDescription:_globalNetworkContainsText];
    NSString *falseText = [self trimmedActionDescription:_globalNetworkFalseText];
    if (url.length == 0) {
        return @"网络判断未填链接";
    }
    if (![self normalizedNetworkURLString:url]) {
        return @"网络判断链接无效";
    }
    if (contains.length == 0 && falseText.length == 0) {
        return @"网络判断至少填一个条件";
    }
    return nil;
}

- (void)performNetworkRequestWithURLString:(NSString *)urlString
                                    method:(NSString *)method
                                   headers:(NSDictionary *)headers
                                  postBody:(NSString *)postBody
                                  trueText:(NSString *)trueText
                                 falseText:(NSString *)falseText
                       defaultExpectedTrue:(BOOL)defaultExpectedTrue
                                   timeout:(NSTimeInterval)timeout
                                completion:(void (^)(BOOL matched, BOOL requestSucceeded, NSString *body, NSInteger statusCode, NSError *error))completion {
    [_networkService performRequestWithURLString:urlString
                                          method:method
                                         headers:headers
                                        postBody:postBody
                                        trueText:trueText
                                       falseText:falseText
                             defaultExpectedTrue:defaultExpectedTrue
                                         timeout:timeout
                                      completion:completion];
}

- (BOOL)networkTaskIsOneShot:(NSDictionary *)task {
    return [task[@"networkRequestOnly"] boolValue];
}

- (BOOL)networkTaskHasJudgementCondition:(NSDictionary *)task {
    NSString *contains = [self trimmedActionDescription:task[@"networkContains"]];
    NSString *falseText = [self trimmedActionDescription:task[@"networkFalse"]];
    return [self networkHasJudgementConditionWithTrueText:contains falseText:falseText];
}

- (NSString *)networkStatusTextWithMatched:(BOOL)matched requestSucceeded:(BOOL)requestSucceeded statusCode:(NSInteger)statusCode error:(NSError *)error {
    return [_networkService statusTextWithMatched:matched
                                 requestSucceeded:requestSucceeded
                                       statusCode:statusCode
                                            error:error];
}

- (void)performNetworkRequestTask:(NSDictionary *)task
                     runGeneration:(NSUInteger)runGeneration
                        completion:(void (^)(BOOL matched, BOOL requestSucceeded, BOOL blocked))completion {
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
    NSString *contains = [self trimmedActionDescription:task[@"networkContains"]];
    NSString *falseText = [self trimmedActionDescription:task[@"networkFalse"]];
    if (url.length == 0) {
        _statusLabel.text = @"网络未填链接";
        [self showToast:@"网络未填链接"];
        if (completion) {
            completion(NO, NO, NO);
        }
        return;
    }

    BOOL oneShot = [self networkTaskIsOneShot:task];
    if (!oneShot && ![self networkTaskHasJudgementCondition:task]) {
        _statusLabel.text = @"网络判断未填条件";
        [self showToast:_statusLabel.text];
        if (completion) {
            completion(NO, NO, NO);
        }
        return;
    }
    NSTimeInterval timeout = [self networkTimeoutForTask:task];
    [self showToast:oneShot ? @"网络仅请求" : @"网络请求中"];
    NSString *method = [self networkMethodForTask:task];
    NSString *postBody = [self networkPostBodyForTask:task];
    [self performNetworkRequestWithURLString:url method:method headers:task[@"networkHeaders"] postBody:postBody trueText:contains falseText:falseText defaultExpectedTrue:NO timeout:timeout completion:^(BOOL matched, BOOL requestSucceeded, NSString *body, NSInteger statusCode, NSError *error) {
        if (runGeneration != 0 && (!self->_taskRunActive || runGeneration != self->_taskRunGeneration)) {
            return;
        }
        if (runGeneration != 0 && ![self applicationIsActiveForTaskRun]) {
            [self pauseTaskRunForForegroundLoss];
            [self cleanupScreenInteractionStateRestoringPanel:NO];
            return;
        }
        BOOL blocked = !oneShot && requestSucceeded && [self networkBody:body matchesBlockText:falseText defaultExpectedTrue:NO];
        self->_statusLabel.text = oneShot
            ? (requestSucceeded ? @"网络请求完成" : [self networkStatusTextWithMatched:NO requestSucceeded:requestSucceeded statusCode:statusCode error:error])
            : (blocked ? @"命中不运行" : [self networkStatusTextWithMatched:matched requestSucceeded:requestSucceeded statusCode:statusCode error:error]);
        [self showToast:self->_statusLabel.text];
        if (completion) {
            completion(matched, requestSucceeded, blocked);
        }
    }];
}

- (void)continueTaskRunToIndex:(NSUInteger)nextIndex inWindow:(UIWindow *)hostWindow generation:(NSUInteger)runGeneration {
    [_taskEngine continueTaskRunToIndex:nextIndex host:hostWindow generation:runGeneration];
}

- (void)continueTaskRunAfterIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow generation:(NSUInteger)runGeneration {
    [self continueTaskRunToIndex:index + 1 inWindow:hostWindow generation:runGeneration];
}

- (BOOL)taskUsesRecognitionNetworkAction:(NSDictionary *)task {
    AnClickActionMode mode = [self modeForTask:task];
    if (mode != AnClickActionModeImage && mode != AnClickActionModeOCR && mode != AnClickActionModeColor) {
        return NO;
    }
    AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
    return actionMode == AnClickActionModeNetwork;
}

- (void)performRecognitionNetworkTask:(NSDictionary *)task
                              inWindow:(UIWindow *)hostWindow
                            generation:(NSUInteger)runGeneration
                            completion:(void (^)(BOOL success))completion {
    AnClickActionMode mode = [self modeForTask:task];
    if (mode == AnClickActionModeImage) {
        [self performImageTask:task inWindow:hostWindow runGeneration:runGeneration completion:completion];
    } else if (mode == AnClickActionModeOCR) {
        [self performOCRTask:task inWindow:hostWindow runGeneration:runGeneration completion:completion];
    } else if (mode == AnClickActionModeColor) {
        [self performColorTask:task inWindow:hostWindow runGeneration:runGeneration completion:completion];
    } else if (completion) {
        completion(NO);
    }
}

- (void)runRecognitionNetworkTask:(NSDictionary *)task
                          atIndex:(NSUInteger)index
                         inWindow:(UIWindow *)hostWindow
                       generation:(NSUInteger)runGeneration
                      repeatIndex:(NSInteger)repeatIndex {
    if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
        return;
    }

    NSInteger repeatCount = [self repeatCountForTask:task];
    if (repeatIndex >= repeatCount) {
        [self continueTaskRunAfterIndex:index inWindow:hostWindow generation:runGeneration];
        return;
    }

    [self performRecognitionNetworkTask:task inWindow:hostWindow generation:runGeneration completion:^(__unused BOOL success) {
        if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
            return;
        }
        UIWindow *currentHostWindow = [self currentUsableHostWindowForTaskRunFallback:hostWindow];
        __weak typeof(self) weakSelf = self;
        NSTimeInterval interval = [self actionIntervalForTask:task];
        [_taskEngine scheduleAfter:interval guard:^BOOL{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return NO;
            }
            return [strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:currentHostWindow status:@"窗口变化停止"];
        } block:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            UIWindow *nextHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:currentHostWindow];
            [strongSelf runRecognitionNetworkTask:task atIndex:index inWindow:nextHostWindow generation:runGeneration repeatIndex:repeatIndex + 1];
        }];
    }];
}

- (void)runRecognitionNetworkTask:(NSDictionary *)task atIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow generation:(NSUInteger)runGeneration {
    if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
        return;
    }
    NSTimeInterval delay = [self delayForTask:task];
    [self showToast:[self toastTextForTask:task index:index]];
    __weak typeof(self) weakSelf = self;
    [_taskEngine scheduleAfter:delay guard:^BOOL{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return NO;
        }
        return [strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"];
    } block:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        UIWindow *currentHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:hostWindow];
        [strongSelf runRecognitionNetworkTask:task atIndex:index inWindow:currentHostWindow generation:runGeneration repeatIndex:0];
    }];
}

- (NSTimeInterval)postRecognitionSuccessDelayForTask:(NSDictionary *)task {
    AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
    if ([self branchActionConfigForTask:task success:YES expectedMode:actionMode]) {
        return 0.0;
    }
    NSTimeInterval interval = [self actionIntervalForTask:task];
    if (actionMode == AnClickActionModeNetwork ||
        actionMode == AnClickActionModeJump ||
        [self modeIsRecognitionTask:actionMode]) {
        return interval;
    }
    return [self durationForTaskMode:actionMode] + interval;
}

- (NSUInteger)nextTaskIndexAfterRecognitionTask:(NSDictionary *)task currentIndex:(NSUInteger)index success:(BOOL)success {
    NSInteger branchIndex = [self validRecognitionJumpIndexForTask:task success:success];
    if (branchIndex >= 0) {
        return (NSUInteger)branchIndex;
    }
    return index + 1;
}

- (void)performRecognitionBranchActionForTask:(NSDictionary *)task
                                      success:(BOOL)success
                                     inWindow:(UIWindow *)hostWindow
                                   generation:(NSUInteger)runGeneration
                                   completion:(void (^)(NSTimeInterval actionDelay))completion {
    AnClickActionMode actionMode = success ? [self successActionModeForTask:task] : [self failureActionModeForTask:task];
    if (actionMode == AnClickActionModeNone || actionMode == AnClickActionModeJump) {
        if (completion) {
            completion(0.0);
        }
        return;
    }

    NSDictionary *config = [self branchActionConfigForTask:task success:success expectedMode:actionMode];
    if (!config) {
        if (![self modeIsRecognitionTask:actionMode]) {
            if (completion) {
                completion(0.0);
            }
            return;
        }
        _statusLabel.text = [NSString stringWithFormat:@"%@后%@动作未设置",
                             success ? @"成功" : @"失败",
                             [self actionNameForMode:actionMode]];
        [self showToast:_statusLabel.text];
        if (completion) {
            completion([self actionIntervalForTask:task]);
        }
        return;
    }

    _statusLabel.text = [NSString stringWithFormat:@"识别%@后执行%@%@",
                         success ? @"成功" : @"失败",
                         [self actionNameForMode:actionMode],
                         [self modeIsRecognitionTask:actionMode] ? @"一次判断" : @"完整动作"];
    [self showToast:_statusLabel.text];
    if ([self modeIsRecognitionTask:actionMode]) {
        NSMutableDictionary *singleCheckConfig = [config mutableCopy];
        singleCheckConfig[@"repeat"] = @1;
        singleCheckConfig[@"interval"] = @0.0;
        singleCheckConfig[@"recognitionRetryUntilFound"] = @NO;
        if ([self modeIsRecognitionTask:[self successActionModeForTask:singleCheckConfig]]) {
            singleCheckConfig[@"imageActionMode"] = @(AnClickActionModeTap);
            [singleCheckConfig removeObjectForKey:@"successActionConfig"];
            [singleCheckConfig removeObjectForKey:@"successRecognitionActionConfig"];
        }
        if ([self modeIsRecognitionTask:[self failureActionModeForTask:singleCheckConfig]]) {
            singleCheckConfig[@"failureActionMode"] = @(AnClickActionModeNone);
            [singleCheckConfig removeObjectForKey:@"failureActionConfig"];
            [singleCheckConfig removeObjectForKey:@"failureRecognitionActionConfig"];
        }
        [self performRecognitionNetworkTask:singleCheckConfig
                                   inWindow:hostWindow
                                 generation:runGeneration
                                 completion:^(BOOL matched) {
            [self performRecognitionBranchActionForTask:singleCheckConfig
                                                success:matched
                                               inWindow:hostWindow
                                             generation:runGeneration
                                             completion:^(NSTimeInterval nestedDelay) {
                if (completion) {
                    completion(nestedDelay + [self actionIntervalForTask:task]);
                }
            }];
        }];
        return;
    }
    NSTimeInterval duration = [self performTaskModel:[[AnClickTaskModel alloc] initWithDictionary:config]
                                            inWindow:hostWindow
                                       runGeneration:runGeneration];
    if (completion) {
        completion(duration + [self actionIntervalForTask:task]);
    }
}

- (void)scheduleTaskContinuationAfterRecognitionTask:(NSDictionary *)task
                                             atIndex:(NSUInteger)index
                                            inWindow:(UIWindow *)hostWindow
                                          generation:(NSUInteger)runGeneration
                                            success:(BOOL)success
                                              delay:(NSTimeInterval)delay {
    __weak typeof(self) weakSelf = self;
    [_taskEngine scheduleAfter:delay guard:^BOOL{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return NO;
        }
        return [strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"];
    } block:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        UIWindow *currentHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:hostWindow];
        [strongSelf performRecognitionBranchActionForTask:task
                                                  success:success
                                                 inWindow:currentHostWindow
                                               generation:runGeneration
                                               completion:^(NSTimeInterval actionDelay) {
            if (![strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:currentHostWindow status:@"窗口变化停止"]) {
                return;
            }
            __weak typeof(strongSelf) nestedWeakSelf = strongSelf;
            [strongSelf->_taskEngine scheduleAfter:actionDelay guard:^BOOL{
                __strong typeof(nestedWeakSelf) nestedSelf = nestedWeakSelf;
                if (!nestedSelf) {
                    return NO;
                }
                return [nestedSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:currentHostWindow status:@"窗口变化停止"];
            } block:^{
                __strong typeof(nestedWeakSelf) nestedSelf = nestedWeakSelf;
                if (!nestedSelf) {
                    return;
                }
                UIWindow *nextHostWindow = [nestedSelf currentUsableHostWindowForTaskRunFallback:currentHostWindow];
                NSUInteger nextIndex = [nestedSelf nextTaskIndexAfterRecognitionTask:task currentIndex:index success:success];
                [nestedSelf continueTaskRunToIndex:nextIndex inWindow:nextHostWindow generation:runGeneration];
            }];
        }];
    }];
}

- (void)performPointActionMode:(AnClickActionMode)mode atPoint:(CGPoint)point inWindow:(UIWindow *)hostWindow {
    [self performPointActionMode:mode atPoint:point inWindow:hostWindow showTrace:YES];
}

- (void)performPointActionMode:(AnClickActionMode)mode atPoint:(CGPoint)point inWindow:(UIWindow *)hostWindow showTrace:(BOOL)showTrace {
    [self performPointActionMode:mode
                         atPoint:point
                        inWindow:hostWindow
                       showTrace:showTrace
               longPressDuration:_longPressDuration];
}

- (void)performPointActionMode:(AnClickActionMode)mode
                        atPoint:(CGPoint)point
                       inWindow:(UIWindow *)hostWindow
                      showTrace:(BOOL)showTrace
              longPressDuration:(NSTimeInterval)longPressDuration {
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    NSTimeInterval pressDuration = [self normalizedLongPressDuration:longPressDuration];
    NSTimeInterval duration = (mode == AnClickActionModeLongPress)
        ? [self longPressOperationDurationForDuration:pressDuration]
        : [self durationForTaskMode:mode];
    if (showTrace) {
        [self showOperationTraceForMode:mode atPoint:point inWindow:hostWindow duration:duration];
    }
    if (mode == AnClickActionModeDoubleTap) {
        [self performDoubleTapAtPoint:point interval:AnClickDefaultDoubleTapInterval];
    } else if (mode == AnClickActionModeLongPress) {
        _longPressHolding = YES;
        [AnClickFakeTouch longPressAtPoint:point duration:pressDuration];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf->_longPressHolding = NO;
        });
    } else if (mode == AnClickActionModeTwoFingerTap) {
        [AnClickFakeTouch twoFingerTapAtPoint:point distance:72.0];
    } else if (mode == AnClickActionModeTap) {
        [AnClickFakeTouch fastTapAtPoint:point];
    }
}

- (void)performRecognitionNetworkActionForTask:(NSDictionary *)task
                               recognitionText:(NSString *)recognitionText
                                 runGeneration:(NSUInteger)runGeneration
                                    completion:(void (^)(void))completion {
    NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
    if (url.length == 0) {
        _statusLabel.text = @"网络未填链接";
        [self showToast:@"网络未填链接"];
        if (completion) {
            completion();
        }
        return;
    }

    NSMutableDictionary *networkTask = [@{
        @"networkURL": url,
        @"networkMethod": [self networkMethodForTask:task],
        @"networkRequestOnly": @YES,
        @"networkTimeout": @([self networkTimeoutForTask:task]),
    } mutableCopy];
    NSString *postBody = [self networkPostBodyForTask:task recognitionText:recognitionText];
    if (postBody.length > 0) {
        networkTask[@"networkPostBody"] = postBody;
    }
    [self performNetworkRequestTask:networkTask runGeneration:runGeneration completion:^(__unused BOOL matched, __unused BOOL requestSucceeded, __unused BOOL blocked) {
        if (completion) {
            completion();
        }
    }];
}

- (void)performRecognitionFailureActionForTask:(NSDictionary *)task
                                      inWindow:(UIWindow *)hostWindow
                                    generation:(NSUInteger)runGeneration
                                    completion:(void (^)(NSTimeInterval delay))completion {
    AnClickActionMode failureMode = [self failureActionModeForTask:task];
    if (failureMode == AnClickActionModeNone) {
        if (completion) {
            completion(0.0);
        }
        return;
    }

    NSTimeInterval interval = [self actionIntervalForTask:task];
    if (failureMode == AnClickActionModeJump) {
        if (completion) {
            completion(interval);
        }
        return;
    }
    NSDictionary *failureConfig = [self branchActionConfigForTask:task success:NO expectedMode:failureMode];
    if (failureConfig) {
        _statusLabel.text = [NSString stringWithFormat:@"识别失败后%@完整动作", [self actionNameForMode:failureMode]];
        [self showToast:_statusLabel.text];
        NSTimeInterval duration = [self performTaskModel:[[AnClickTaskModel alloc] initWithDictionary:failureConfig]
                                                inWindow:hostWindow
                                           runGeneration:runGeneration];
        if (completion) {
            completion(duration + interval);
        }
        return;
    }
    if (failureMode == AnClickActionModeNetwork) {
        _statusLabel.text = @"识别失败后网络请求";
        [self showToast:_statusLabel.text];
        [self performRecognitionNetworkActionForTask:task recognitionText:nil runGeneration:runGeneration completion:^{
            if (completion) {
                completion(interval);
            }
        }];
        return;
    }

    if ([self modeIsRecognitionTask:failureMode]) {
        _statusLabel.text = [NSString stringWithFormat:@"识别失败后%@未设置动作", [self actionNameForMode:failureMode]];
        [self showToast:_statusLabel.text];
        if (completion) {
            completion(interval);
        }
        return;
    }

    CGPoint actionPoint = CGPointZero;
    if (![self failureActionPointForTask:task point:&actionPoint]) {
        _statusLabel.text = @"识别失败动作未取点";
        [self showToast:_statusLabel.text];
        if (completion) {
            completion(interval);
        }
        return;
    }

    actionPoint = [self point:actionPoint byApplyingJitterForTask:task];
    [self performPointActionMode:failureMode atPoint:actionPoint inWindow:hostWindow];
    _statusLabel.text = [NSString stringWithFormat:@"识别失败后%@ %.0f,%.0f",
                         [self actionNameForMode:failureMode],
                         actionPoint.x,
                         actionPoint.y];
    [self showToast:_statusLabel.text];
    if (completion) {
        completion([self durationForTaskMode:failureMode] + interval);
    }
}

- (void)performImageTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow {
    [self performImageTask:task inWindow:hostWindow runGeneration:0 completion:nil];
}

- (void)performImageTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow runGeneration:(NSUInteger)runGeneration {
    [self performImageTask:task inWindow:hostWindow runGeneration:runGeneration completion:nil];
}

- (void)performImageTask:(NSDictionary *)task
                inWindow:(UIWindow *)hostWindow
           runGeneration:(NSUInteger)runGeneration
              completion:(void (^)(BOOL success))completion {
    NSString *templatePath = task[@"templatePath"];
    UIImage *templateImage = [self cachedTemplateImageAtPath:templatePath];
    if (!templateImage) {
        _statusLabel.text = @"识图无模板";
        if (completion) {
            completion(NO);
        }
        return;
    }

    BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
    AnClickActionMode imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
    NSNumber *thresholdNumber = task[@"threshold"];
    double threshold = thresholdNumber ? MIN(1.0, MAX(0.0, thresholdNumber.doubleValue)) : 0.80;
    NSValue *customPointValue = task[@"point"];
    BOOL shouldRestorePanel = [self hideOwnUIForRecognitionCaptureWithHostWindow:hostWindow];
    _templateSearchInProgress = YES;
    NSUInteger geometryGeneration = _screenGeometryGeneration;
    __weak typeof(self) weakSelf = self;
    [_taskEngine scheduleRecognitionCaptureWithHost:hostWindow generation:runGeneration delay:AnClickRecognitionCaptureDelay block:^{
        __strong typeof(weakSelf) delayedSelf = weakSelf;
        if (!delayedSelf) {
            return;
        }
        if (![delayedSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                         runGeneration:runGeneration
                                                          restorePanel:(runGeneration == 0 || shouldRestorePanel)] ||
            (runGeneration != 0 &&
             ![delayedSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"])) {
            delayedSelf->_templateSearchInProgress = NO;
            [delayedSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
            return;
        }
        [delayedSelf->_recognitionService findTemplateImageMatch:templateImage threshold:threshold completion:^(NSDictionary *match) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                strongSelf->_templateSearchInProgress = NO;
                if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                                runGeneration:runGeneration
                                                                 restorePanel:(runGeneration == 0 || shouldRestorePanel)]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    return;
                }
                UIWindow *currentHostWindow = [strongSelf hostWindowForCallbackWithFallback:hostWindow
                                                                              runGeneration:runGeneration
                                                                                     status:@"窗口变化停止"];
                if (!currentHostWindow) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    return;
                }
                if (!match) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"识图未找到";
                    [strongSelf showToast:@"识图未找到"];
                    if (completion) {
                        completion(NO);
                    } else {
                        [strongSelf performRecognitionBranchActionForTask:task
                                                                  success:NO
                                                                 inWindow:currentHostWindow
                                                               generation:runGeneration
                                                               completion:nil];
                    }
                    return;
                }
                NSValue *matchPointValue = match[@"point"];
                NSValue *rectValue = match[@"rect"];
                NSNumber *scoreNumber = match[@"score"];
                if (!matchPointValue || !rectValue) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"识图异常";
                    [strongSelf showToast:@"识图异常"];
                    if (completion) {
                        completion(NO);
                    }
                    return;
                }
                CGRect rect = rectValue.CGRectValue;
                [strongSelf showRecognitionBoxForScreenRect:rect score:scoreNumber.doubleValue inWindow:currentHostWindow duration:1.2];
                if (imageActionMode == AnClickActionModeJump) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    NSInteger taskIndex = [strongSelf validRecognitionJumpIndexForTask:task success:YES];
                    strongSelf->_statusLabel.text = taskIndex >= 0
                        ? [NSString stringWithFormat:@"识图 %.2f 成功后跳转任务%ld", scoreNumber.doubleValue, (long)taskIndex + 1]
                        : @"识图成功后跳转未选任务";
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    }
                    return;
                }
                NSDictionary *successConfig = [strongSelf branchActionConfigForTask:task success:YES expectedMode:imageActionMode];
                if (successConfig) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识图 %.2f 成功后%@完整动作",
                                                     scoreNumber.doubleValue,
                                                     [strongSelf actionNameForMode:imageActionMode]];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    } else {
                        [strongSelf performTaskModel:[[AnClickTaskModel alloc] initWithDictionary:successConfig]
                                            inWindow:currentHostWindow
                                       runGeneration:runGeneration];
                    }
                    return;
                }
                if ([strongSelf modeIsRecognitionTask:imageActionMode]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    NSDictionary *config = [strongSelf recognitionActionConfigForTask:task success:YES expectedMode:imageActionMode];
                    strongSelf->_statusLabel.text = config
                        ? [NSString stringWithFormat:@"识图 %.2f 成功后%@动作",
                           scoreNumber.doubleValue,
                           [strongSelf actionNameForMode:imageActionMode]]
                        : [NSString stringWithFormat:@"识图成功后%@未设置动作", [strongSelf actionNameForMode:imageActionMode]];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    }
                    return;
                }
                if (imageActionMode == AnClickActionModeNetwork) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    [strongSelf performRecognitionNetworkActionForTask:task recognitionText:nil runGeneration:runGeneration completion:^{
                        if (completion) {
                            completion(YES);
                        }
                    }];
                    strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识图 %.2f 网络请求",
                                                     scoreNumber.doubleValue];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    return;
                }
                CGPoint actionPoint = CGPointZero;
                if (![strongSelf successActionPointForTask:task
                                                 matchPoint:matchPointValue.CGPointValue
                                              hasMatchPoint:YES
                                           customPointValue:customPointValue
                                              useMatchPoint:useMatchPoint
                                                      point:&actionPoint]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"识图成功动作未取点";
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    }
                    return;
                }
                actionPoint = [strongSelf point:actionPoint byApplyingJitterForTask:task];
                NSTimeInterval actionLongPressDuration = [strongSelf longPressDurationForTask:task];
                NSTimeInterval actionDuration = imageActionMode == AnClickActionModeLongPress
                    ? [strongSelf longPressOperationDurationForDuration:actionLongPressDuration]
                    : [strongSelf durationForTaskMode:imageActionMode];
                [strongSelf performPointActionMode:imageActionMode
                                           atPoint:actionPoint
                                          inWindow:currentHostWindow
                                         showTrace:YES
                                 longPressDuration:actionLongPressDuration];
                strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识图 %.2f %@ %.0f,%.0f",
                                                 scoreNumber.doubleValue,
                                                 [strongSelf actionNameForMode:imageActionMode],
                                                 actionPoint.x,
                                                 actionPoint.y];
                [strongSelf showToast:strongSelf->_statusLabel.text];
                [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel
                                                                   delay:actionDuration + 0.03];
                if (completion) {
                    completion(YES);
                }
        });
    }];
}

- (void)performOCRTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow {
    [self performOCRTask:task inWindow:hostWindow runGeneration:0 completion:nil];
}

- (void)performOCRTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow runGeneration:(NSUInteger)runGeneration {
    [self performOCRTask:task inWindow:hostWindow runGeneration:runGeneration completion:nil];
}

- (void)performOCRTask:(NSDictionary *)task
              inWindow:(UIWindow *)hostWindow
         runGeneration:(NSUInteger)runGeneration
            completion:(void (^)(BOOL success))completion {
    NSString *targetText = [self trimmedActionDescription:task[@"ocrText"]];
    AnClickOCRMatchMode matchMode = [self ocrMatchModeForTask:task];
    BOOL useRegex = matchMode == AnClickOCRMatchModeRegex;
    if (targetText.length == 0) {
        _statusLabel.text = useRegex ? @"正则表达式未填写" : @"识字未填写";
        [self showToast:_statusLabel.text];
        if (completion) {
            completion(NO);
        }
        return;
    }

    AnClickOCRMode ocrMode = [self ocrModeForTask:task];
    if (useRegex && ![self ocrRegexPatternIsValid:targetText]) {
        _statusLabel.text = @"正则表达式无效";
        [self showToast:_statusLabel.text];
        if (completion) {
            completion(NO);
        }
        return;
    }
    AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
    BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
    NSValue *customPointValue = task[@"point"];
    if ([self recognitionActionModeNeedsPoint:actionMode] &&
        !useMatchPoint &&
        !customPointValue &&
        !task[@"successPoint"]) {
        _statusLabel.text = @"识字未取点";
        if (completion) {
            completion(NO);
        }
        return;
    }
    BOOL shouldRestorePanel = [self hideOwnUIForRecognitionCaptureWithHostWindow:hostWindow];
    _templateSearchInProgress = YES;
    NSUInteger geometryGeneration = _screenGeometryGeneration;
    __weak typeof(self) weakSelf = self;
    [_taskEngine scheduleRecognitionCaptureWithHost:hostWindow generation:runGeneration delay:AnClickRecognitionCaptureDelay block:^{
        __strong typeof(weakSelf) delayedSelf = weakSelf;
        if (!delayedSelf) {
            return;
        }
        if (![delayedSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                         runGeneration:runGeneration
                                                          restorePanel:(runGeneration == 0 || shouldRestorePanel)]) {
            delayedSelf->_templateSearchInProgress = NO;
            [delayedSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
            return;
        }
        if (runGeneration != 0 &&
            ![delayedSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
            delayedSelf->_templateSearchInProgress = NO;
            [delayedSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
            return;
        }
        [delayedSelf->_recognitionService findText:targetText mode:ocrMode useRegex:useRegex completion:^(NSDictionary *match) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                strongSelf->_templateSearchInProgress = NO;
                if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                                runGeneration:runGeneration
                                                                 restorePanel:(runGeneration == 0 || shouldRestorePanel)]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    return;
                }
                UIWindow *currentHostWindow = [strongSelf hostWindowForCallbackWithFallback:hostWindow
                                                                              runGeneration:runGeneration
                                                                                     status:@"窗口变化停止"];
                if (!currentHostWindow) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    return;
                }
                NSString *error = [match[@"error"] isKindOfClass:NSString.class] ? match[@"error"] : nil;
                if (error.length > 0) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = error;
                    [strongSelf showToast:error];
                    if (completion) {
                        completion(NO);
                    }
                    return;
                }
                NSValue *pointValue = match[@"point"];
                NSValue *rectValue = match[@"rect"];
                NSNumber *scoreNumber = match[@"score"];
                NSString *text = [match[@"text"] isKindOfClass:NSString.class] ? match[@"text"] : targetText;
                double requiredSimilarity = [task[@"ocrSimilarity"] respondsToSelector:@selector(doubleValue)]
                    ? MIN(1.0, MAX(0.0, [task[@"ocrSimilarity"] doubleValue]))
                    : 0.0;
                if (scoreNumber && scoreNumber.doubleValue + 0.0001 < requiredSimilarity) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"识字相似度不足";
                    [strongSelf showToast:@"识字相似度不足"];
                    if (completion) {
                        completion(NO);
                    } else {
                        [strongSelf performRecognitionBranchActionForTask:task
                                                                  success:NO
                                                                 inWindow:currentHostWindow
                                                               generation:runGeneration
                                                               completion:nil];
                    }
                    return;
                }
                NSInteger matchCount = [match[@"matchCount"] respondsToSelector:@selector(integerValue)] ? MAX(1, [match[@"matchCount"] integerValue]) : 1;
                NSString *matchModeTitle = matchMode == AnClickOCRMatchModeRegex
                    ? @"正则"
                    : @"包含";
                NSString *matchSummary = matchCount > 1
                    ? [NSString stringWithFormat:@"%@ 命中%ld选1", matchModeTitle, (long)matchCount]
                    : matchModeTitle;
                if (!pointValue || !rectValue) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"识字未找到";
                    [strongSelf showToast:@"识字未找到"];
                    if (completion) {
                        completion(NO);
                    } else {
                        [strongSelf performRecognitionBranchActionForTask:task
                                                                  success:NO
                                                                 inWindow:currentHostWindow
                                                               generation:runGeneration
                                                               completion:nil];
                    }
                    return;
                }
                [strongSelf showRecognitionBoxForScreenRect:rectValue.CGRectValue score:scoreNumber ? scoreNumber.doubleValue : 1.0 inWindow:currentHostWindow duration:1.2];
                if (actionMode == AnClickActionModeJump) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    NSInteger taskIndex = [strongSelf validRecognitionJumpIndexForTask:task success:YES];
                    strongSelf->_statusLabel.text = taskIndex >= 0
                        ? [NSString stringWithFormat:@"识字 %@ %@ 成功后跳转任务%ld", matchSummary, text, (long)taskIndex + 1]
                        : @"识字成功后跳转未选任务";
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    }
                    return;
                }
                NSDictionary *successConfig = [strongSelf branchActionConfigForTask:task success:YES expectedMode:actionMode];
                if (successConfig) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识字 %@ %@ 成功后%@完整动作",
                                                     matchSummary,
                                                     text,
                                                     [strongSelf actionNameForMode:actionMode]];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    } else {
                        [strongSelf performTaskModel:[[AnClickTaskModel alloc] initWithDictionary:successConfig]
                                            inWindow:currentHostWindow
                                       runGeneration:runGeneration];
                    }
                    return;
                }
                if ([strongSelf modeIsRecognitionTask:actionMode]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    NSDictionary *config = [strongSelf recognitionActionConfigForTask:task success:YES expectedMode:actionMode];
                    strongSelf->_statusLabel.text = config
                        ? [NSString stringWithFormat:@"识字 %@ %@ 成功后%@动作",
                           matchSummary,
                           text,
                           [strongSelf actionNameForMode:actionMode]]
                        : [NSString stringWithFormat:@"识字成功后%@未设置动作", [strongSelf actionNameForMode:actionMode]];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    }
                    return;
                }
                if (actionMode == AnClickActionModeNetwork) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    [strongSelf performRecognitionNetworkActionForTask:task recognitionText:text runGeneration:runGeneration completion:^{
                        if (completion) {
                            completion(YES);
                        }
                    }];
                    strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识字 %@ %@ 网络请求", matchSummary, text];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    return;
                }
                CGPoint actionPoint = CGPointZero;
                if (![strongSelf successActionPointForTask:task
                                                 matchPoint:pointValue.CGPointValue
                                              hasMatchPoint:YES
                                           customPointValue:customPointValue
                                              useMatchPoint:useMatchPoint
                                                      point:&actionPoint]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"识字成功动作未取点";
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    }
                    return;
                }
                actionPoint = [strongSelf point:actionPoint byApplyingJitterForTask:task];
                NSTimeInterval actionLongPressDuration = [strongSelf longPressDurationForTask:task];
                NSTimeInterval actionDuration = actionMode == AnClickActionModeLongPress
                    ? [strongSelf longPressOperationDurationForDuration:actionLongPressDuration]
                    : [strongSelf durationForTaskMode:actionMode];
                [strongSelf performPointActionMode:actionMode
                                           atPoint:actionPoint
                                          inWindow:currentHostWindow
                                         showTrace:YES
                                 longPressDuration:actionLongPressDuration];
                strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识字 %@ %@ %.0f,%.0f",
                                                 matchSummary,
                                                 text,
                                                 actionPoint.x,
                                                 actionPoint.y];
                [strongSelf showToast:strongSelf->_statusLabel.text];
                [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel
                                                                   delay:actionDuration + 0.03];
                if (completion) {
                    completion(YES);
                }
        });
    }];
}

- (void)performColorTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow {
    [self performColorTask:task inWindow:hostWindow runGeneration:0 completion:nil];
}

- (void)performColorTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow runGeneration:(NSUInteger)runGeneration {
    [self performColorTask:task inWindow:hostWindow runGeneration:runGeneration completion:nil];
}

- (void)performColorTask:(NSDictionary *)task
                inWindow:(UIWindow *)hostWindow
           runGeneration:(NSUInteger)runGeneration
              completion:(void (^)(BOOL success))completion {
    NSArray<NSDictionary *> *colorPoints = [self normalizedColorPatternPointsForTask:task];
    if (colorPoints.count == 0) {
        _statusLabel.text = @"识色未取色";
        if (completion) {
            completion(NO);
        }
        return;
    }

    double tolerance = [task[@"colorTolerance"] respondsToSelector:@selector(doubleValue)]
        ? MIN(255.0, MAX(0.0, [task[@"colorTolerance"] doubleValue]))
        : 18.0;
    BOOL invertColorMatch = [task[@"colorMatchMode"] respondsToSelector:@selector(integerValue)] &&
        [task[@"colorMatchMode"] integerValue] == 1;
    AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
    BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
    NSValue *customPointValue = task[@"point"];
    __block NSString *patternSummary = [self colorPatternSummaryForTask:task];
    BOOL shouldRestorePanel = [self hideOwnUIForRecognitionCaptureWithHostWindow:hostWindow];
    _templateSearchInProgress = YES;
    NSUInteger geometryGeneration = _screenGeometryGeneration;
    __weak typeof(self) weakSelf = self;
    [_taskEngine scheduleRecognitionCaptureWithHost:hostWindow generation:runGeneration delay:AnClickRecognitionCaptureDelay block:^{
        __strong typeof(weakSelf) delayedSelf = weakSelf;
        if (!delayedSelf) {
            return;
        }
        if (![delayedSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                         runGeneration:runGeneration
                                                          restorePanel:(runGeneration == 0 || shouldRestorePanel)] ||
            (runGeneration != 0 &&
             ![delayedSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"])) {
            delayedSelf->_templateSearchInProgress = NO;
            [delayedSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
            return;
        }
        [delayedSelf->_recognitionService findColorPatternMatchWithPoints:colorPoints tolerance:tolerance completion:^(NSDictionary *match) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                strongSelf->_templateSearchInProgress = NO;
                if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                                runGeneration:runGeneration
                                                                 restorePanel:(runGeneration == 0 || shouldRestorePanel)]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    return;
                }
                UIWindow *currentHostWindow = [strongSelf hostWindowForCallbackWithFallback:hostWindow
                                                                              runGeneration:runGeneration
                                                                                     status:@"窗口变化停止"];
                if (!currentHostWindow) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    return;
                }
                if (match && invertColorMatch) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"颜色仍存在";
                    [strongSelf showToast:@"颜色仍存在"];
                    if (completion) {
                        completion(NO);
                    } else {
                        [strongSelf performRecognitionBranchActionForTask:task
                                                                  success:NO
                                                                 inWindow:currentHostWindow
                                                               generation:runGeneration
                                                               completion:nil];
                    }
                    return;
                }
                if (!match && !invertColorMatch) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"颜色未找到";
                    [strongSelf showToast:@"颜色未找到"];
                    if (completion) {
                        completion(NO);
                    } else {
                        [strongSelf performRecognitionBranchActionForTask:task
                                                                  success:NO
                                                                 inWindow:currentHostWindow
                                                               generation:runGeneration
                                                               completion:nil];
                    }
                    return;
                }
                NSValue *pointValue = match[@"point"];
                NSValue *rectValue = match[@"rect"];
                NSNumber *scoreNumber = match[@"score"];
                if (!match && invertColorMatch) {
                    NSDictionary *anchor = colorPoints.firstObject;
                    CGSize screenSize = [strongSelf currentScreenCoordinateSize];
                    CGPoint anchorPoint = CGPointMake(screenSize.width * 0.5, screenSize.height * 0.5);
                    if ([anchor[@"x"] respondsToSelector:@selector(doubleValue)] &&
                        [anchor[@"y"] respondsToSelector:@selector(doubleValue)]) {
                        anchorPoint = CGPointMake([anchor[@"x"] doubleValue], [anchor[@"y"] doubleValue]);
                    }
                    pointValue = [NSValue valueWithCGPoint:anchorPoint];
                    rectValue = [NSValue valueWithCGRect:CGRectMake(anchorPoint.x - 4.0, anchorPoint.y - 4.0, 8.0, 8.0)];
                    scoreNumber = @1.0;
                    patternSummary = [patternSummary stringByAppendingString:@" 未出现"];
                }
                if (!pointValue || !rectValue) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"识色异常";
                    [strongSelf showToast:@"识色异常"];
                    if (completion) {
                        completion(NO);
                    }
                    return;
                }
                [strongSelf showRecognitionBoxForScreenRect:rectValue.CGRectValue score:scoreNumber ? scoreNumber.doubleValue : 1.0 inWindow:currentHostWindow duration:1.2];
                if (actionMode == AnClickActionModeJump) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    NSInteger taskIndex = [strongSelf validRecognitionJumpIndexForTask:task success:YES];
                    strongSelf->_statusLabel.text = taskIndex >= 0
                        ? [NSString stringWithFormat:@"识色 %@ 成功后跳转任务%ld", patternSummary, (long)taskIndex + 1]
                        : @"识色成功后跳转未选任务";
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    }
                    return;
                }
                NSDictionary *successConfig = [strongSelf branchActionConfigForTask:task success:YES expectedMode:actionMode];
                if (successConfig) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识色 %@ 成功后%@完整动作",
                                                     patternSummary,
                                                     [strongSelf actionNameForMode:actionMode]];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    } else {
                        [strongSelf performTaskModel:[[AnClickTaskModel alloc] initWithDictionary:successConfig]
                                            inWindow:currentHostWindow
                                       runGeneration:runGeneration];
                    }
                    return;
                }
                if ([strongSelf modeIsRecognitionTask:actionMode]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    NSDictionary *config = [strongSelf recognitionActionConfigForTask:task success:YES expectedMode:actionMode];
                    strongSelf->_statusLabel.text = config
                        ? [NSString stringWithFormat:@"识色 %@ 成功后%@动作",
                           patternSummary,
                           [strongSelf actionNameForMode:actionMode]]
                        : [NSString stringWithFormat:@"识色成功后%@未设置动作", [strongSelf actionNameForMode:actionMode]];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    }
                    return;
                }
                if (actionMode == AnClickActionModeNetwork) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    [strongSelf performRecognitionNetworkActionForTask:task recognitionText:nil runGeneration:runGeneration completion:^{
                        if (completion) {
                            completion(YES);
                        }
                    }];
                    strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识色 %@ 网络请求", patternSummary];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    return;
                }
                CGPoint actionPoint = CGPointZero;
                if (![strongSelf successActionPointForTask:task
                                                 matchPoint:pointValue.CGPointValue
                                              hasMatchPoint:YES
                                           customPointValue:customPointValue
                                              useMatchPoint:useMatchPoint
                                                      point:&actionPoint]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"识色成功动作未取点";
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    if (completion) {
                        completion(YES);
                    }
                    return;
                }
                actionPoint = [strongSelf point:actionPoint byApplyingJitterForTask:task];
                NSTimeInterval actionLongPressDuration = [strongSelf longPressDurationForTask:task];
                NSTimeInterval actionDuration = actionMode == AnClickActionModeLongPress
                    ? [strongSelf longPressOperationDurationForDuration:actionLongPressDuration]
                    : [strongSelf durationForTaskMode:actionMode];
                [strongSelf performPointActionMode:actionMode
                                           atPoint:actionPoint
                                          inWindow:currentHostWindow
                                         showTrace:YES
                                 longPressDuration:actionLongPressDuration];
                strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识色 %@ %.0f,%.0f",
                                                 patternSummary,
                                                 actionPoint.x,
                                                 actionPoint.y];
                [strongSelf showToast:strongSelf->_statusLabel.text];
                [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel
                                                                   delay:actionDuration + 0.03];
                if (completion) {
                    completion(YES);
                }
        });
    }];
}

- (BOOL)networkTaskHasPostPayload:(NSDictionary *)task {
    if (![[self networkMethodForTask:task] isEqualToString:@"POST"]) {
        return YES;
    }
    if ([self networkPostDictionaryFromPairs:task[@"networkPostPairs"] recognitionText:@""].count > 0) {
        return YES;
    }
    if ([self networkPostKeyValueTextForTask:task].length > 0) {
        return YES;
    }
    return [self networkPostBodyForTask:task].length > 0;
}

- (NSMutableDictionary *)taskDictionaryForModel:(AnClickTaskModel *)model {
    return [model isKindOfClass:AnClickTaskModel.class] ? [model dictionaryRepresentation] : nil;
}

- (BOOL)taskModelIsComplete:(AnClickTaskModel *)model {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    return task ? [self taskIsComplete:task] : NO;
}

- (BOOL)taskIsComplete:(NSDictionary *)task {
    AnClickActionMode mode = [self modeForTask:task];
    if (mode == AnClickActionModeNone) {
        _statusLabel.text = @"任务未选择动作";
        return NO;
    }
    if (mode == AnClickActionModeDelay) {
        NSTimeInterval delay = [task[@"delay"] respondsToSelector:@selector(doubleValue)] ? [task[@"delay"] doubleValue] : 0.0;
        if (delay <= 0.001) {
            _statusLabel.text = @"任务延时未设置";
            return NO;
        }
        return YES;
    }
    if (mode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = task[@"path"];
        if (path.count < 2) {
            _statusLabel.text = @"任务滑动未设置";
            return NO;
        }
        return YES;
    }
    if (mode == AnClickActionModeImage) {
        NSString *templatePath = task[@"templatePath"];
        if (templatePath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:templatePath]) {
            _statusLabel.text = @"任务识图未截图";
            return NO;
        }
        BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
        AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        AnClickActionMode failureMode = [self failureActionModeForTask:task];
        BOOL successUsesFullConfig = [self branchActionConfigForTask:task success:YES expectedMode:actionMode] != nil;
        BOOL failureUsesFullConfig = [self branchActionConfigForTask:task success:NO expectedMode:failureMode] != nil;
        if ((actionMode == AnClickActionModeNetwork && !successUsesFullConfig) ||
            (failureMode == AnClickActionModeNetwork && !failureUsesFullConfig)) {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            if (url.length == 0 || ![self normalizedNetworkURLString:url]) {
                _statusLabel.text = @"任务识图网络未设置";
                return NO;
            }
            if (![self networkTaskHasPostPayload:task]) {
                _statusLabel.text = @"任务识图POST键值未填写";
                return NO;
            }
        }
        if (!successUsesFullConfig &&
            [self recognitionActionModeNeedsPoint:actionMode] &&
            !useMatchPoint &&
            !task[@"point"] &&
            !task[@"successPoint"]) {
            _statusLabel.text = @"任务识图未取点";
            return NO;
        }
        if (!failureUsesFullConfig && [self failureActionModeNeedsPoint:failureMode]) {
            CGPoint failurePoint = CGPointZero;
            if (![self failureActionPointForTask:task point:&failurePoint]) {
                _statusLabel.text = @"任务识图失败动作未取点";
                return NO;
            }
        }
        if (![self validateSuccessRecognitionActionTaskForTask:task]) {
            return NO;
        }
        if (![self validateFailureRecognitionActionTaskForTask:task]) {
            return NO;
        }
        if (![self validateRecognitionJumpActionForTask:task]) {
            return NO;
        }
        return YES;
    }
    if (mode == AnClickActionModeOCR) {
        NSString *targetText = [self trimmedActionDescription:task[@"ocrText"]];
        BOOL usesRegex = [self ocrTaskUsesRegexMatching:task];
        if (targetText.length == 0) {
            _statusLabel.text = usesRegex ? @"任务正则表达式未填写" : @"任务识字未填写";
            return NO;
        }
        if (usesRegex && ![self ocrRegexPatternIsValid:targetText]) {
            _statusLabel.text = @"任务正则表达式无效";
            return NO;
        }
        BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
        AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        AnClickActionMode failureMode = [self failureActionModeForTask:task];
        BOOL successUsesFullConfig = [self branchActionConfigForTask:task success:YES expectedMode:actionMode] != nil;
        BOOL failureUsesFullConfig = [self branchActionConfigForTask:task success:NO expectedMode:failureMode] != nil;
        if ((actionMode == AnClickActionModeNetwork && !successUsesFullConfig) ||
            (failureMode == AnClickActionModeNetwork && !failureUsesFullConfig)) {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            if (url.length == 0 || ![self normalizedNetworkURLString:url]) {
                _statusLabel.text = @"任务识字网络未设置";
                return NO;
            }
            if (![self networkTaskHasPostPayload:task]) {
                _statusLabel.text = @"任务POST键值未填写";
                return NO;
            }
        }
        if (!successUsesFullConfig &&
            [self recognitionActionModeNeedsPoint:actionMode] &&
            !useMatchPoint &&
            !task[@"point"] &&
            !task[@"successPoint"]) {
            _statusLabel.text = @"任务识字未取点";
            return NO;
        }
        if (!failureUsesFullConfig && [self failureActionModeNeedsPoint:failureMode]) {
            CGPoint failurePoint = CGPointZero;
            if (![self failureActionPointForTask:task point:&failurePoint]) {
                _statusLabel.text = @"任务识字失败动作未取点";
                return NO;
            }
        }
        if (![self validateSuccessRecognitionActionTaskForTask:task]) {
            return NO;
        }
        if (![self validateFailureRecognitionActionTaskForTask:task]) {
            return NO;
        }
        if (![self validateRecognitionJumpActionForTask:task]) {
            return NO;
        }
        return YES;
    }
    if (mode == AnClickActionModeColor) {
        if ([self normalizedColorPatternPointsForTask:task].count == 0) {
            _statusLabel.text = @"任务未取色";
            return NO;
        }
        AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        AnClickActionMode failureMode = [self failureActionModeForTask:task];
        BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
        BOOL successUsesFullConfig = [self branchActionConfigForTask:task success:YES expectedMode:actionMode] != nil;
        BOOL failureUsesFullConfig = [self branchActionConfigForTask:task success:NO expectedMode:failureMode] != nil;
        if ((actionMode == AnClickActionModeNetwork && !successUsesFullConfig) ||
            (failureMode == AnClickActionModeNetwork && !failureUsesFullConfig)) {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            if (url.length == 0 || ![self normalizedNetworkURLString:url]) {
                _statusLabel.text = @"任务识色网络未设置";
                return NO;
            }
            if (![self networkTaskHasPostPayload:task]) {
                _statusLabel.text = @"任务识色POST键值未填写";
                return NO;
            }
        }
        if (!failureUsesFullConfig && [self failureActionModeNeedsPoint:failureMode]) {
            CGPoint failurePoint = CGPointZero;
            if (![self failureActionPointForTask:task point:&failurePoint]) {
                _statusLabel.text = @"任务识色失败动作未取点";
                return NO;
            }
        }
        if (!successUsesFullConfig &&
            [self recognitionActionModeNeedsPoint:actionMode] &&
            !useMatchPoint &&
            !task[@"point"] &&
            !task[@"successPoint"]) {
            _statusLabel.text = @"任务识色未取点";
            return NO;
        }
        if (![self validateSuccessRecognitionActionTaskForTask:task]) {
            return NO;
        }
        if (![self validateFailureRecognitionActionTaskForTask:task]) {
            return NO;
        }
        if (![self validateRecognitionJumpActionForTask:task]) {
            return NO;
        }
        return YES;
    }
    if (mode == AnClickActionModeNetwork) {
        NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
        if (url.length == 0) {
            _statusLabel.text = @"任务网络未填链接";
            return NO;
        }
        if (![self normalizedNetworkURLString:url]) {
            _statusLabel.text = @"任务网络链接无效";
            return NO;
        }
        if (![self networkTaskIsOneShot:task] && ![self networkTaskHasJudgementCondition:task]) {
            _statusLabel.text = @"任务网络缺少判断条件";
            return NO;
        }
        if (![self networkTaskHasPostPayload:task]) {
            _statusLabel.text = @"任务POST键值未填写";
            return NO;
        }
        if (![self validateSuccessRecognitionActionTaskForTask:task]) {
            return NO;
        }
        if (![self validateFailureRecognitionActionTaskForTask:task]) {
            return NO;
        }
        if (![self validateRecognitionJumpActionForTask:task]) {
            return NO;
        }
        return YES;
    }
    if (mode == AnClickActionModeJump) {
        id value = task[@"jumpTaskIndex"] ?: task[@"targetTaskIndex"] ?: task[@"jumpTaskId"];
        NSInteger targetIndex = [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : -1;
        if (targetIndex < 0 || targetIndex >= (NSInteger)_taskItems.count) {
            _statusLabel.text = @"任务跳转目标无效";
            return NO;
        }
        return YES;
    }
    if (mode == AnClickActionModeDelay) {
        if ([self delayForTask:task] <= 0.001) {
            _statusLabel.text = @"任务延时未设置";
            return NO;
        }
        return YES;
    }
    if (mode == AnClickActionModeMacro) {
        NSArray *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
        if (events.count == 0) {
            _statusLabel.text = @"任务未录制";
            return NO;
        }
        return YES;
    }
    if (mode == AnClickActionModeTwoFingerTap) {
        NSArray<NSValue *> *points = [self storedMultiTapPointsForTask:task];
        if (points.count >= 2 || [task[@"point"] isKindOfClass:NSValue.class]) {
            return YES;
        }
        _statusLabel.text = @"任务多指未取点";
        return NO;
    }

    NSValue *pointValue = task[@"point"];
    if (!pointValue) {
        _statusLabel.text = @"任务未取点";
        return NO;
    }
    return YES;
}

- (NSTimeInterval)performTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow {
    return [self performTask:task inWindow:hostWindow runGeneration:0];
}

- (NSTimeInterval)performTaskModel:(AnClickTaskModel *)model inWindow:(UIWindow *)hostWindow {
    return [self performTaskModel:model inWindow:hostWindow runGeneration:0];
}

- (NSTimeInterval)performTaskModel:(AnClickTaskModel *)model inWindow:(UIWindow *)hostWindow runGeneration:(NSUInteger)runGeneration {
    NSMutableDictionary *task = [self taskDictionaryForModel:model];
    return task ? [self performTask:task inWindow:hostWindow runGeneration:runGeneration] : 0.0;
}

- (NSTimeInterval)performTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow runGeneration:(NSUInteger)runGeneration {
    if (![self panelCanUseCurrentScene]) {
        return 0;
    }
    if (![self taskIsComplete:task]) {
        return 0;
    }

    AnClickActionMode mode = [self modeForTask:task];
    NSInteger repeatCount = [self repeatCountForTask:task];
    BOOL intervalWasSet = [task[@"interval"] respondsToSelector:@selector(doubleValue)];
    NSTimeInterval configuredInterval = [self actionIntervalForTask:task];
    BOOL hasExtraInterval = intervalWasSet && configuredInterval > 0.001;
    BOOL pointTapRepeatMode = mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeTwoFingerTap;
    BOOL turboPointTapRepeat = repeatCount > 1 && pointTapRepeatMode;
    BOOL suppressFastTrace = repeatCount > 1 &&
        (turboPointTapRepeat ||
         (!hasExtraInterval &&
          (mode == AnClickActionModeSwipe ||
           mode == AnClickActionModeMacro)));
    NSTimeInterval delay = [self delayForTask:task];
    if (mode == AnClickActionModeDelay) {
        return delay;
    }
    NSTimeInterval duration = [self durationForTaskMode:mode];
    if (mode == AnClickActionModeImage) {
        AnClickActionMode imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        NSTimeInterval actionDuration = [self estimatedActionDurationForTask:task success:YES actionMode:imageActionMode depth:0];
        duration = 0.75 + actionDuration;
    } else if (mode == AnClickActionModeOCR) {
        AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        NSTimeInterval actionDuration = [self estimatedActionDurationForTask:task success:YES actionMode:actionMode depth:0];
        duration = 0.95 + actionDuration;
    } else if (mode == AnClickActionModeColor) {
        AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        NSTimeInterval actionDuration = [self estimatedActionDurationForTask:task success:YES actionMode:actionMode depth:0];
        duration = 0.75 + actionDuration;
    } else if (mode == AnClickActionModeNetwork) {
        duration = 0.85;
    } else if (mode == AnClickActionModeMacro) {
        NSArray *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
        duration = [self durationForRecordedEvents:events playbackSpeed:[self macroPlaybackSpeedForTask:task]];
    } else if (mode == AnClickActionModeDoubleTap) {
        duration = [self doubleTapOperationDurationForTask:task];
    } else if (mode == AnClickActionModeLongPress) {
        duration = [self longPressOperationDurationForDuration:[self longPressDurationForTask:task]];
    } else if (mode == AnClickActionModeSwipe) {
        duration = [self swipeDurationForTask:task];
    }
    if (turboPointTapRepeat) {
        __weak typeof(self) weakSelf = self;
        NSTimeInterval minimumStep = (mode == AnClickActionModeDoubleTap)
            ? [self doubleTapOperationDurationForTask:task]
            : AnClickDefaultTapPressDuration;
        NSTimeInterval step = MAX(minimumStep, configuredInterval);
        if (mode == AnClickActionModeTwoFingerTap) {
            NSArray<NSValue *> *basePoints = [[self resolvedMultiTapPointsForTask:task] copy];
            for (NSInteger i = 0; i < repeatCount; i++) {
                NSTimeInterval fireDelay = delay + step * i;
                [_taskEngine scheduleAfter:fireDelay guard:^BOOL{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf || (runGeneration != 0 && (!strongSelf->_taskRunActive || runGeneration != strongSelf->_taskRunGeneration))) {
                        return NO;
                    }
                    return YES;
                } block:^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) {
                        return;
                    }
                    NSArray<NSValue *> *points = [strongSelf points:basePoints byApplyingJitterForTask:task];
                    if (points.count >= 2) {
                        [AnClickFakeTouch fastMultiTapAtPoints:points];
                    }
                }];
            }
        } else {
            NSValue *pointValue = task[@"point"];
            CGPoint basePoint = [self resolvedPointForTask:task fallbackPoint:pointValue.CGPointValue];
            for (NSInteger i = 0; i < repeatCount; i++) {
                NSTimeInterval fireDelay = delay + step * i;
                [_taskEngine scheduleAfter:fireDelay guard:^BOOL{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf || (runGeneration != 0 && (!strongSelf->_taskRunActive || runGeneration != strongSelf->_taskRunGeneration))) {
                        return NO;
                    }
                    return YES;
                } block:^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) {
                        return;
                    }
                    CGPoint point = [strongSelf point:basePoint byApplyingJitterForTask:task];
                    if (mode == AnClickActionModeDoubleTap) {
                        [strongSelf performDoubleTapAtPoint:point interval:[strongSelf doubleTapIntervalForTask:task]];
                    } else {
                        [AnClickFakeTouch fastTapAtPoint:point];
                    }
                }];
            }
        }
        return delay + step * repeatCount;
    }

    NSTimeInterval interval = duration + configuredInterval;

    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < repeatCount; i++) {
        NSTimeInterval fireDelay = delay + interval * i;
        [_taskEngine scheduleAfter:fireDelay guard:^BOOL{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return NO;
            }
            return runGeneration == 0 || (strongSelf->_taskRunActive && runGeneration == strongSelf->_taskRunGeneration);
        } block:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            UIWindow *currentHostWindow = [strongSelf hostWindowForCallbackWithFallback:hostWindow
                                                                          runGeneration:runGeneration
                                                                                 status:@"窗口变化停止"];
            if (!currentHostWindow) {
                return;
            }
            if (![strongSelf panelCanUseCurrentScene]) {
                return;
            }
            if (mode == AnClickActionModeSwipe) {
                NSArray<NSValue *> *steppedPath = [strongSelf path:[strongSelf resolvedPathForTask:task] byApplyingSwipeStepForTask:task];
                NSArray<NSValue *> *path = [strongSelf path:steppedPath byApplyingJitterForTask:task];
                NSTimeInterval swipeDuration = [strongSelf swipeDurationForTask:task];
                if (!suppressFastTrace) {
                    [strongSelf showTrajectoryForScreenPoints:path inWindow:currentHostWindow duration:swipeDuration];
                }
                [AnClickFakeTouch playPath:path duration:swipeDuration];
            } else if (mode == AnClickActionModeImage) {
                [strongSelf performImageTask:task inWindow:currentHostWindow runGeneration:runGeneration];
            } else if (mode == AnClickActionModeOCR) {
                [strongSelf performOCRTask:task inWindow:currentHostWindow runGeneration:runGeneration];
            } else if (mode == AnClickActionModeColor) {
                [strongSelf performColorTask:task inWindow:currentHostWindow runGeneration:runGeneration];
            } else if (mode == AnClickActionModeNetwork) {
                [strongSelf performNetworkRequestTask:task runGeneration:runGeneration completion:nil];
            } else if (mode == AnClickActionModeMacro) {
                NSArray<NSDictionary *> *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
                NSArray<NSDictionary *> *resolvedEvents = [strongSelf recordedEvents:[strongSelf resolvedRecordedEventsForTask:task] byApplyingJitterForTask:task];
                double playbackSpeed = [strongSelf macroPlaybackSpeedForTask:task];
                NSArray<NSValue *> *trajectory = [strongSelf trajectoryPointsForRecordedEvents:resolvedEvents];
                NSTimeInterval playbackDuration = [strongSelf durationForRecordedEvents:events playbackSpeed:playbackSpeed];
                if (!suppressFastTrace && trajectory.count >= 2) {
                    [strongSelf showTrajectoryForScreenPoints:trajectory inWindow:currentHostWindow duration:playbackDuration];
                } else if (!suppressFastTrace && trajectory.count == 1) {
                    [strongSelf showTapMarkerAtScreenPoint:trajectory.firstObject.CGPointValue inWindow:currentHostWindow];
                }
                [AnClickFakeTouch playRecordedEvents:resolvedEvents playbackSpeed:playbackSpeed];
            } else if (mode == AnClickActionModeTwoFingerTap) {
                NSArray<NSValue *> *points = [strongSelf points:[strongSelf resolvedMultiTapPointsForTask:task] byApplyingJitterForTask:task];
                if (points.count >= 2) {
                    if (!suppressFastTrace) {
                        [strongSelf showMultiTapMarkersForScreenPoints:points inWindow:currentHostWindow duration:0.75];
                    }
                    [AnClickFakeTouch fastMultiTapAtPoints:points];
                } else {
                    NSValue *pointValue = task[@"point"];
                    CGPoint point = [strongSelf point:[strongSelf resolvedPointForTask:task fallbackPoint:pointValue.CGPointValue] byApplyingJitterForTask:task];
                    [strongSelf performPointActionMode:mode atPoint:point inWindow:currentHostWindow showTrace:!suppressFastTrace];
                }
            } else {
                NSValue *pointValue = task[@"point"];
                CGPoint point = [strongSelf point:[strongSelf resolvedPointForTask:task fallbackPoint:pointValue.CGPointValue] byApplyingJitterForTask:task];
                if (mode == AnClickActionModeDoubleTap) {
                    NSTimeInterval doubleTapDuration = [strongSelf doubleTapOperationDurationForTask:task];
                    if (!suppressFastTrace) {
                        [strongSelf showOperationTraceForMode:mode atPoint:point inWindow:currentHostWindow duration:doubleTapDuration];
                    }
                    [strongSelf performDoubleTapAtPoint:point interval:[strongSelf doubleTapIntervalForTask:task]];
                } else if (mode == AnClickActionModeLongPress) {
                    [strongSelf performPointActionMode:mode
                                               atPoint:point
                                              inWindow:currentHostWindow
                                             showTrace:!suppressFastTrace
                                     longPressDuration:[strongSelf longPressDurationForTask:task]];
                } else {
                    [strongSelf performPointActionMode:mode atPoint:point inWindow:currentHostWindow showTrace:!suppressFastTrace];
                }
            }
        }];
    }

    return delay + duration + interval * MAX(0, repeatCount - 1);
}

- (void)runTaskList {
    if (_taskRunActive || _taskRunPausedForForeground) {
        _volumeShortcutRunSuppressToasts = NO;
        [self stopTaskRunWithStatus:@"已停止"];
        return;
    }
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    [self clearTaskRunPauseState];
    _volumeShortcutRunSuppressToasts = NO;
    [self startTaskListRunScheduled:NO];
}

- (void)startTaskListRunScheduled:(BOOL)scheduled {
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    if (_taskItems.count == 0) {
        _volumeShortcutRunSuppressToasts = NO;
        _statusLabel.text = scheduled ? @"定时启动无任务" : @"先加任务";
        [self showToast:_statusLabel.text];
        return;
    }

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _volumeShortcutRunSuppressToasts = NO;
        _statusLabel.text = @"无窗口";
        [self showToast:@"无窗口"];
        return;
    }

    if ([AnClickRecorder shared].isRecording) {
        _volumeShortcutRunSuppressToasts = NO;
        _statusLabel.text = @"录制中无法播放";
        [self showToast:@"录制中无法播放"];
        return;
    }

    NSString *networkValidationMessage = [self globalNetworkGateValidationMessage];
    if (networkValidationMessage.length > 0) {
        _volumeShortcutRunSuppressToasts = NO;
        _statusLabel.text = networkValidationMessage;
        [self showToast:_statusLabel.text];
        return;
    }

    [self cancelRunningTaskSideEffects];
    _taskRunActive = YES;
    [self clearTaskRunPauseState];
    _taskRunSingleStepStopIndex = -1;
    _currentGlobalRunCycle = 0;
    [self resetTaskRunJumpGuard];
    [self resetRunProgressToastThrottle];
    [_taskEngine resetListRefreshThrottle];
    NSUInteger runGeneration = ++_taskRunGeneration;
    [self startTaskRunRuntimeTimerReset:YES];
    _statusLabel.text = _globalNetworkGateEnabled ? @"网络监控中" : (scheduled ? @"定时启动" : @"播放中");
    [self showToast:_statusLabel.text];
    [self refreshTaskListDuringRunIfNeeded];
    [self collapsePanel];
    if (_globalNetworkGateEnabled) {
        [self rememberTaskRunResumePointAtIndex:0 inGlobalNetworkGate:YES scheduled:scheduled];
        [_taskEngine monitorGlobalNetworkGateWithHost:hostWindow scheduled:scheduled generation:runGeneration];
        return;
    }
    [self rememberTaskRunResumePointAtIndex:0 inGlobalNetworkGate:NO scheduled:scheduled];
    [self runTaskAtIndex:0 inWindow:hostWindow generation:runGeneration];
}

- (void)stopTaskRunWithStatus:(NSString *)status {
    [self stopTaskRunWithStatus:status showToast:YES];
}

- (void)finishTaskRunWithStatus:(NSString *)status showToast:(BOOL)showToast restorePanel:(BOOL)restorePanel {
    if (!_taskRunActive && !_taskRunPausedForForeground) {
        return;
    }

    _taskRunActive = NO;
    [self clearTaskRunPauseState];
    _taskRunSingleStepStopIndex = -1;
    _currentGlobalRunCycle = 0;
    [self resetTaskRunJumpGuard];
    [self resetRunProgressToastThrottle];
    [_taskEngine resetListRefreshThrottle];
    _taskRunGeneration++;
    [self cancelRunningTaskSideEffects];
    [self stopTaskRunRuntimeTimerReset:YES];
    _statusLabel.text = status.length > 0 ? status : @"已停止";
    if (showToast) {
        [self showToast:_statusLabel.text];
    }
    BOOL panelNeedsRestore = restorePanel || _panelHiddenForSingleStepTest || (_panelWindow && (_panelWindow.hidden || !_panelWindow.userInteractionEnabled));
    _panelHiddenForSingleStepTest = NO;
    if (panelNeedsRestore && [self applicationIsActiveForTaskRun]) {
        [self restorePanelAfterExternalTap];
    }
    _volumeShortcutRunSuppressToasts = NO;
    [self refreshCollapsedButtonTitle];
    [self refreshTaskList];
}

- (void)stopTaskRunWithStatus:(NSString *)status showToast:(BOOL)showToast {
    [self finishTaskRunWithStatus:status showToast:showToast restorePanel:YES];
}

- (void)finishSingleStepTaskRunWithStatus:(NSString *)status {
    [self finishTaskRunWithStatus:(status.length > 0 ? status : @"单步测试完成") showToast:YES restorePanel:YES];
}

- (void)runTaskAtIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow {
    [self runTaskAtIndex:index inWindow:hostWindow generation:_taskRunGeneration];
}

- (void)runTaskAtIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow generation:(NSUInteger)runGeneration {
    [_taskEngine runTaskAtIndex:index host:hostWindow generation:runGeneration];
}

- (void)clearColorPickPixelData {
    _colorPickPixelData = nil;
    _colorPickPixelWidth = 0;
    _colorPickPixelHeight = 0;
    _colorPickPixelBytesPerRow = 0;
}

- (BOOL)prepareColorPickPixelDataForImage:(UIImage *)image {
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        [self clearColorPickPixelData];
        return NO;
    }

    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    if (width == 0 || height == 0) {
        [self clearColorPickPixelData];
        return NO;
    }

    size_t bytesPerRow = width * 4;
    NSMutableData *pixelData = [NSMutableData dataWithLength:height * bytesPerRow];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) {
        [self clearColorPickPixelData];
        return NO;
    }

    CGContextRef context = CGBitmapContextCreate(pixelData.mutableBytes,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (!context) {
        CGColorSpaceRelease(colorSpace);
        [self clearColorPickPixelData];
        return NO;
    }

    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGFloat scale = image.scale > 0 ? image.scale : UIScreen.mainScreen.scale;
    CGContextSaveGState(context);
    CGContextScaleCTM(context, scale, scale);
    UIGraphicsPushContext(context);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIGraphicsPopContext();
    CGContextRestoreGState(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    _colorPickPixelData = pixelData;
    _colorPickPixelWidth = width;
    _colorPickPixelHeight = height;
    _colorPickPixelBytesPerRow = bytesPerRow;
    return YES;
}

- (BOOL)sampleColorFromImageProvider:(CGImageRef)imageRef pixelX:(NSInteger)pixelX pixelY:(NSInteger)pixelY red:(NSInteger *)red green:(NSInteger *)green blue:(NSInteger *)blue {
    if (!imageRef || CGImageGetBitsPerPixel(imageRef) != 32 || CGImageGetBitsPerComponent(imageRef) != 8) {
        return NO;
    }

    CGDataProviderRef provider = CGImageGetDataProvider(imageRef);
    if (!provider) {
        return NO;
    }

    CFDataRef data = CGDataProviderCopyData(provider);
    if (!data) {
        return NO;
    }

    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    CFIndex length = CFDataGetLength(data);
    BOOL success = NO;
    if (pixelX >= 0 && pixelY >= 0 &&
        (size_t)pixelX < width && (size_t)pixelY < height &&
        bytesPerRow >= width * 4 &&
        (CFIndex)((size_t)pixelY * bytesPerRow + (size_t)pixelX * 4 + 3) < length) {
        const UInt8 *bytes = CFDataGetBytePtr(data);
        const UInt8 *pixel = bytes + (size_t)pixelY * bytesPerRow + (size_t)pixelX * 4;
        CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
        CGBitmapInfo byteOrder = bitmapInfo & kCGBitmapByteOrderMask;
        CGImageAlphaInfo alphaInfo = (CGImageAlphaInfo)(bitmapInfo & kCGBitmapAlphaInfoMask);
        NSInteger sampleRed = 0;
        NSInteger sampleGreen = 0;
        NSInteger sampleBlue = 0;

        if (byteOrder == kCGBitmapByteOrder32Little) {
            if (alphaInfo == kCGImageAlphaPremultipliedFirst ||
                alphaInfo == kCGImageAlphaFirst ||
                alphaInfo == kCGImageAlphaNoneSkipFirst) {
                sampleBlue = pixel[0];
                sampleGreen = pixel[1];
                sampleRed = pixel[2];
            } else {
                sampleRed = pixel[3];
                sampleGreen = pixel[2];
                sampleBlue = pixel[1];
            }
        } else {
            if (alphaInfo == kCGImageAlphaPremultipliedFirst ||
                alphaInfo == kCGImageAlphaFirst ||
                alphaInfo == kCGImageAlphaNoneSkipFirst) {
                sampleRed = pixel[1];
                sampleGreen = pixel[2];
                sampleBlue = pixel[3];
            } else {
                sampleRed = pixel[0];
                sampleGreen = pixel[1];
                sampleBlue = pixel[2];
            }
        }

        if (red) {
            *red = sampleRed;
        }
        if (green) {
            *green = sampleGreen;
        }
        if (blue) {
            *blue = sampleBlue;
        }
        success = YES;
    }
    CFRelease(data);
    return success;
}

- (BOOL)sampleColorAtImagePoint:(CGPoint)point image:(UIImage *)image red:(NSInteger *)red green:(NSInteger *)green blue:(NSInteger *)blue {
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        return NO;
    }

    CGFloat scale = image.scale > 0 ? image.scale : UIScreen.mainScreen.scale;
    NSInteger imagePixelWidth = (NSInteger)CGImageGetWidth(imageRef);
    NSInteger imagePixelHeight = (NSInteger)CGImageGetHeight(imageRef);
    if (imagePixelWidth <= 0 || imagePixelHeight <= 0) {
        return NO;
    }
    NSInteger imagePixelX = MIN(MAX((NSInteger)floor(point.x * scale), 0), imagePixelWidth - 1);
    NSInteger imagePixelY = MIN(MAX((NSInteger)floor(point.y * scale), 0), imagePixelHeight - 1);
    NSInteger providerRed = 0;
    NSInteger providerGreen = 0;
    NSInteger providerBlue = 0;
    BOOL providerValid = [self sampleColorFromImageProvider:imageRef
                                                     pixelX:imagePixelX
                                                     pixelY:imagePixelY
                                                        red:&providerRed
                                                      green:&providerGreen
                                                       blue:&providerBlue];

    if (!_colorPickPixelData ||
        image != _colorPickImage ||
        _colorPickPixelWidth != CGImageGetWidth(imageRef) ||
        _colorPickPixelHeight != CGImageGetHeight(imageRef)) {
        if (![self prepareColorPickPixelDataForImage:image]) {
            return NO;
        }
    }

    NSInteger pixelX = MIN(MAX((NSInteger)floor(point.x * scale), 0), (NSInteger)_colorPickPixelWidth - 1);
    NSInteger pixelY = MIN(MAX((NSInteger)floor(point.y * scale), 0), (NSInteger)_colorPickPixelHeight - 1);
    const unsigned char *bytes = (const unsigned char *)_colorPickPixelData.bytes;
    const unsigned char *pixel = bytes + pixelY * _colorPickPixelBytesPerRow + pixelX * 4;

    NSInteger sampleRed = pixel[0];
    NSInteger sampleGreen = pixel[1];
    NSInteger sampleBlue = pixel[2];
    BOOL cacheWhite = sampleRed >= 245 && sampleGreen >= 245 && sampleBlue >= 245;
    BOOL providerWhite = providerRed >= 245 && providerGreen >= 245 && providerBlue >= 245;
    if (cacheWhite && providerValid && !providerWhite) {
        sampleRed = providerRed;
        sampleGreen = providerGreen;
        sampleBlue = providerBlue;
    }

    if (red) {
        *red = sampleRed;
    }
    if (green) {
        *green = sampleGreen;
    }
    if (blue) {
        *blue = sampleBlue;
    }
    return YES;
}

- (BOOL)colorPickSampleHasCoordinate:(NSDictionary *)sample {
    return [sample[@"x"] respondsToSelector:@selector(doubleValue)] &&
           [sample[@"y"] respondsToSelector:@selector(doubleValue)];
}

- (NSDictionary *)colorPickSampleAtPoint:(CGPoint)point red:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue {
    return @{
        @"x": @(point.x),
        @"y": @(point.y),
        @"dx": @(0.0),
        @"dy": @(0.0),
        @"red": @(MIN(255, MAX(0, red))),
        @"green": @(MIN(255, MAX(0, green))),
        @"blue": @(MIN(255, MAX(0, blue))),
    };
}

- (void)recalculatePendingColorPickOffsets {
    if (_pendingColorPickSamples.count == 0) {
        return;
    }

    NSDictionary *anchor = _pendingColorPickSamples.firstObject;
    CGFloat anchorX = [anchor[@"x"] respondsToSelector:@selector(doubleValue)] ? [anchor[@"x"] doubleValue] : 0.0;
    CGFloat anchorY = [anchor[@"y"] respondsToSelector:@selector(doubleValue)] ? [anchor[@"y"] doubleValue] : 0.0;
    NSMutableArray<NSDictionary *> *normalized = [NSMutableArray arrayWithCapacity:_pendingColorPickSamples.count];
    for (NSUInteger index = 0; index < _pendingColorPickSamples.count; index++) {
        NSDictionary *sample = _pendingColorPickSamples[index];
        NSMutableDictionary *mutable = [sample mutableCopy];
        if ([self colorPickSampleHasCoordinate:sample]) {
            CGFloat x = [sample[@"x"] doubleValue];
            CGFloat y = [sample[@"y"] doubleValue];
            mutable[@"dx"] = @(index == 0 ? 0.0 : x - anchorX);
            mutable[@"dy"] = @(index == 0 ? 0.0 : y - anchorY);
        }
        [normalized addObject:[mutable copy]];
    }
    _pendingColorPickSamples = normalized;
}

- (NSString *)colorPickRoleForIndex:(NSUInteger)index {
    return index == 0 ? @"点击点" : [NSString stringWithFormat:@"校验%lu", (unsigned long)index];
}

- (void)refreshColorPickOverlaySamples {
    [_colorPickOverlay updateSamples:_pendingColorPickSamples selectedIndex:_selectedColorPickSampleIndex];
}

- (void)refreshColorPickInfoLabelWithLastSample:(NSDictionary *)lastSample {
    NSDictionary *sample = lastSample ?: (_selectedColorPickSampleIndex >= 0 && _selectedColorPickSampleIndex < (NSInteger)_pendingColorPickSamples.count
        ? _pendingColorPickSamples[(NSUInteger)_selectedColorPickSampleIndex]
        : _pendingColorPickSamples.lastObject);
    if (!_colorPickOverlay) {
        return;
    }
    NSDictionary *previewSample = _pendingColorPickSamples.firstObject ?: sample;
    if (previewSample) {
        _colorPickOverlay.swatchColor = [self uiColorForColorSample:previewSample fallback:[UIColor colorWithWhite:1 alpha:0.10]];
    }
    if (!sample) {
        _colorPickOverlay.infoText = @"第1点为点击坐标";
        _colorPickOverlay.swatchColor = [UIColor colorWithWhite:1 alpha:0.10];
        return;
    }
    if (![sample[@"x"] respondsToSelector:@selector(doubleValue)] ||
        ![sample[@"y"] respondsToSelector:@selector(doubleValue)]) {
        _colorPickOverlay.infoText = @"旧颜色 点截图重设";
        return;
    }

    NSInteger red = [sample[@"red"] integerValue];
    NSInteger green = [sample[@"green"] integerValue];
    NSInteger blue = [sample[@"blue"] integerValue];
    NSUInteger displayIndex = _pendingColorPickSamples.count > 0 ? [_pendingColorPickSamples indexOfObjectIdenticalTo:sample] : NSNotFound;
    if (displayIndex == NSNotFound) {
        displayIndex = _pendingColorPickSamples.count > 0 ? _pendingColorPickSamples.count - 1 : 0;
    }
    NSString *actionText = _selectedColorPickSampleIndex >= 0 ? @"已选中 点击截图修改" : @"点截图继续新增";
    _colorPickOverlay.infoText = [NSString stringWithFormat:@"%lu点 %@ %@ X%.0f Y%.0f #%02lX%02lX%02lX",
                                  (unsigned long)_pendingColorPickSamples.count,
                                  [self colorPickRoleForIndex:displayIndex],
                                  actionText,
                                  [sample[@"x"] doubleValue],
                                  [sample[@"y"] doubleValue],
                                  (long)red,
                                  (long)green,
                                  (long)blue];
}

- (void)selectColorPickSampleAtIndex:(NSUInteger)index {
    if (index >= _pendingColorPickSamples.count) {
        return;
    }
    _selectedColorPickSampleIndex = (NSInteger)index;
    NSDictionary *sample = _pendingColorPickSamples[(NSUInteger)index];
    if ([self colorPickSampleHasCoordinate:sample]) {
        _pendingColorPickPoint = CGPointMake([sample[@"x"] doubleValue], [sample[@"y"] doubleValue]);
        _hasPendingColorPickPoint = YES;
        [self updateColorPickCursorAtImagePoint:_pendingColorPickPoint];
    }
    [self refreshColorPickOverlaySamples];
    [self refreshColorPickInfoLabelWithLastSample:sample];
}

- (void)deleteSelectedColorPickSample {
    if (_pendingColorPickSamples.count == 0) {
        _colorPickOverlay.infoText = @"没有可删点";
        return;
    }

    NSInteger index = _selectedColorPickSampleIndex;
    if (index < 0 || index >= (NSInteger)_pendingColorPickSamples.count) {
        index = (NSInteger)_pendingColorPickSamples.count - 1;
    }
    [_pendingColorPickSamples removeObjectAtIndex:(NSUInteger)index];
    [self recalculatePendingColorPickOffsets];
    _selectedColorPickSampleIndex = -1;

    NSDictionary *sample = _pendingColorPickSamples.lastObject;
    if ([self colorPickSampleHasCoordinate:sample]) {
        _pendingColorPickPoint = CGPointMake([sample[@"x"] doubleValue], [sample[@"y"] doubleValue]);
        _hasPendingColorPickPoint = YES;
        [self updateColorPickCursorAtImagePoint:_pendingColorPickPoint];
    } else {
        _hasPendingColorPickPoint = NO;
        [_colorPickOverlay hideCursor];
    }
    [self refreshColorPickOverlaySamples];
    [self refreshColorPickInfoLabelWithLastSample:sample];
}

- (void)beginColorPicking {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _branchColorPickActive = NO;
        _branchColorPickMode = AnClickActionModeNone;
        _statusLabel.text = @"无窗口";
        return;
    }

    [_pickerService cancelPendingCaptures];
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    __weak typeof(self) weakSelf = self;
    [_pickerService captureAfterDelay:0.12 completion:^(UIImage *image, UIWindow *capturedWindow) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (!image.CGImage) {
            strongSelf->_branchColorPickActive = NO;
            strongSelf->_branchColorPickMode = AnClickActionModeNone;
            strongSelf->_statusLabel.text = @"截图失败";
            [strongSelf restorePanelAfterExternalTap];
            return;
        }
        UIWindow *overlayWindow = capturedWindow ?: hostWindow;
        if (![strongSelf->_pickerService capturedImage:image matchesWindow:overlayWindow]) {
            strongSelf->_branchColorPickActive = NO;
            strongSelf->_branchColorPickMode = AnClickActionModeNone;
            strongSelf->_statusLabel.text = @"截图方向异常 请重试";
            [strongSelf showToast:strongSelf->_statusLabel.text];
            [strongSelf restorePanelAfterExternalTap];
            return;
        }
        [strongSelf showColorPickOverlayWithImage:image hostWindow:overlayWindow];
    }];
}

- (void)beginSuccessBranchColorPicking {
    [self beginBranchColorPickingForSuccess:YES];
}

- (void)beginFailureBranchColorPicking {
    [self beginBranchColorPickingForSuccess:NO];
}

- (void)beginBranchColorPickingForSuccess:(BOOL)success {
    if (![self currentActionIsRecognitionMode]) {
        _statusLabel.text = success ? @"识别动作才有成功后取色" : @"识别动作才有失败后取色";
        return;
    }
    AnClickActionMode mode = success
        ? [self normalizedImageActionMode:_imageActionMode]
        : [self normalizedFailureActionMode:_failureActionMode];
    if (mode != AnClickActionModeColor) {
        _statusLabel.text = success ? @"先选择成功后识色" : @"先选择失败后识色";
        return;
    }
    if (![self ensureMutableBranchActionConfigForSuccess:success mode:mode]) {
        _statusLabel.text = @"先保存主任务";
        return;
    }
    _branchColorPickActive = YES;
    _branchColorPickSuccess = success;
    _branchColorPickMode = mode;
    [self beginColorPicking];
}

- (void)showColorPickOverlayWithImage:(UIImage *)image hostWindow:(UIWindow *)hostWindow {
    _colorPickOverlay.delegate = nil;
    [_colorPickOverlay removeFromSuperview];
    [_pickerService dismissOverlayWindow:_colorPickWindow];
    _colorPickImage = image;
    _pendingColorPickSamples = [NSMutableArray array];
    _hasPendingColorPickPoint = NO;
    if (![self prepareColorPickPixelDataForImage:image]) {
        _statusLabel.text = @"取色初始化失败";
        [self restorePanelAfterExternalTap];
        return;
    }

    _colorPickWindow = [_pickerService overlayWindowForHostWindow:hostWindow levelOffset:2100.0];

    UIView *root = _colorPickWindow.rootViewController.view;
    _colorPickOverlay = [[AnClickColorPickerView alloc] initWithFrame:root.bounds
                                                                 image:image
                                                          surfaceColor:[self themeSurfaceColor]
                                                        separatorColor:[self themeSeparatorColor]
                                                      primaryTextColor:[self themePrimaryTextColor]
                                                      controlFillColor:[self themeControlFillColor]
                                                        highlightColor:[self themeHighlightColor]
                                                           dangerColor:[self themeDangerColor]];
    _colorPickOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _colorPickOverlay.delegate = self;
    [root addSubview:_colorPickOverlay];

    _selectedColorPickSampleIndex = -1;
    [self refreshColorPickOverlaySamples];
    NSDictionary *displaySample = _selectedColorPickSampleIndex >= 0
        ? _pendingColorPickSamples[(NSUInteger)_selectedColorPickSampleIndex]
        : _pendingColorPickSamples.lastObject;
    if ([displaySample[@"x"] respondsToSelector:@selector(doubleValue)] &&
        [displaySample[@"y"] respondsToSelector:@selector(doubleValue)]) {
        _pendingColorPickPoint = CGPointMake([displaySample[@"x"] doubleValue], [displaySample[@"y"] doubleValue]);
        _pendingColorRed = [displaySample[@"red"] integerValue];
        _pendingColorGreen = [displaySample[@"green"] integerValue];
        _pendingColorBlue = [displaySample[@"blue"] integerValue];
        _hasPendingColorPickPoint = YES;
        [self updateColorPickCursorAtImagePoint:_pendingColorPickPoint];
    } else {
        _hasPendingColorPickPoint = NO;
    }
    [self refreshColorPickInfoLabelWithLastSample:displaySample];
    _colorPickWindow.hidden = NO;
    _statusLabel.text = @"截图取色";
}

- (void)updateColorPickCursorAtImagePoint:(CGPoint)point {
    if (!_colorPickOverlay) {
        return;
    }
    [_colorPickOverlay showCursorAtImagePoint:point];
}

- (void)handleColorPickImagePoint:(CGPoint)point {
    if (!_colorPickImage) {
        return;
    }
    point = [_colorPickOverlay clampedImagePoint:point];

    NSInteger red = 0;
    NSInteger green = 0;
    NSInteger blue = 0;
    if (![self sampleColorAtImagePoint:point image:_colorPickImage red:&red green:&green blue:&blue]) {
        _colorPickOverlay.infoText = @"取色失败";
        return;
    }

    NSDictionary *existingAnchor = _pendingColorPickSamples.firstObject;
    if (existingAnchor &&
        (![existingAnchor[@"x"] respondsToSelector:@selector(doubleValue)] ||
         ![existingAnchor[@"y"] respondsToSelector:@selector(doubleValue)])) {
        [_pendingColorPickSamples removeAllObjects];
        _selectedColorPickSampleIndex = -1;
    }

    NSInteger editIndex = _selectedColorPickSampleIndex;
    BOOL editingExistingPoint = editIndex >= 0 && editIndex < (NSInteger)_pendingColorPickSamples.count;
    if (!editingExistingPoint && _pendingColorPickSamples.count >= AnClickColorPickMaxSamples) {
        _colorPickOverlay.infoText = [NSString stringWithFormat:@"最多支持%lu点", (unsigned long)AnClickColorPickMaxSamples];
        return;
    }

    NSDictionary *sample = [self colorPickSampleAtPoint:point red:red green:green blue:blue];
    if (editingExistingPoint) {
        [_pendingColorPickSamples replaceObjectAtIndex:(NSUInteger)editIndex withObject:sample];
    } else {
        [_pendingColorPickSamples addObject:sample];
    }
    [self recalculatePendingColorPickOffsets];
    NSUInteger displayIndex = editingExistingPoint ? (NSUInteger)editIndex : _pendingColorPickSamples.count - 1;
    NSDictionary *displaySample = displayIndex < _pendingColorPickSamples.count ? _pendingColorPickSamples[displayIndex] : _pendingColorPickSamples.lastObject;
    _selectedColorPickSampleIndex = -1;
    _pendingColorPickPoint = point;
    _pendingColorRed = red;
    _pendingColorGreen = green;
    _pendingColorBlue = blue;
    _hasPendingColorPickPoint = YES;
    [self updateColorPickCursorAtImagePoint:point];
    [self refreshColorPickOverlaySamples];
    [self refreshColorPickInfoLabelWithLastSample:displaySample];
    BOOL sampledWhite = red >= 245 && green >= 245 && blue >= 245;
    NSDictionary *primarySample = _pendingColorPickSamples.firstObject ?: sample;
    _colorPickOverlay.swatchColor = [self uiColorForColorSample:primarySample fallback:[UIColor colorWithWhite:1 alpha:0.10]];
    _colorPickOverlay.infoText = [NSString stringWithFormat:@"%@ 主色%@ 当前#%02lX%02lX%02lX  X%.0f Y%.0f",
                                  sampledWhite ? @"采样白色 截图可能白底" : @"采样",
                                  [self colorHexStringForSample:primarySample],
                                  (long)red,
                                  (long)green,
                                  (long)blue,
                                  point.x,
                                  point.y];
    NSLog(@"[AnClick] Color pick sample #%02lX%02lX%02lX point=(%.1f, %.1f) image=(%.1f, %.1f) scale=%.2f",
          (long)red,
          (long)green,
          (long)blue,
          point.x,
          point.y,
          _colorPickImage.size.width,
          _colorPickImage.size.height,
          _colorPickImage.scale);
}

- (void)colorPickerView:(__unused AnClickColorPickerView *)view didTapImagePoint:(CGPoint)point {
    [self handleColorPickImagePoint:point];
}

- (void)colorPickerView:(__unused AnClickColorPickerView *)view didSelectSampleAtIndex:(NSUInteger)index {
    [self selectColorPickSampleAtIndex:index];
}

- (void)colorPickerViewDidDeleteSample:(__unused AnClickColorPickerView *)view {
    [self deleteSelectedColorPickSample];
}

- (void)colorPickerViewDidConfirm:(__unused AnClickColorPickerView *)view {
    [self confirmColorPicking];
}

- (void)colorPickerViewDidCancel:(__unused AnClickColorPickerView *)view {
    [self cancelColorPicking];
}

- (void)finishColorPickingOverlay {
    _colorPickOverlay.delegate = nil;
    [_colorPickOverlay removeFromSuperview];
    _colorPickOverlay = nil;
    [_pickerService dismissOverlayWindow:_colorPickWindow];
    _colorPickWindow = nil;
    _colorPickImage = nil;
    _pendingColorPickSamples = [NSMutableArray array];
    _selectedColorPickSampleIndex = -1;
    _hasPendingColorPickPoint = NO;
    [self clearColorPickPixelData];
    _branchColorPickActive = NO;
    _branchColorPickMode = AnClickActionModeNone;
    [self restorePanelAfterExternalTap];
}

- (void)confirmColorPicking {
    if (_pendingColorPickSamples.count == 0) {
        _colorPickOverlay.infoText = @"先点选颜色";
        return;
    }
    if (_branchColorPickActive) {
        BOOL success = _branchColorPickSuccess;
        AnClickActionMode mode = _branchColorPickMode;
        NSArray<NSDictionary *> *samples = [self colorSamplesForPersistence:_pendingColorPickSamples];
        NSDictionary *anchor = samples.firstObject;
        NSMutableDictionary *config = [self ensureMutableBranchActionConfigForSuccess:success mode:mode];
        if (config && anchor) {
            config[@"colorPoints"] = samples;
            config[@"colorPointScreenSize"] = [self currentScreenCoordinateSizeValue];
            config[@"colorRed"] = @([anchor[@"red"] integerValue]);
            config[@"colorGreen"] = @([anchor[@"green"] integerValue]);
            config[@"colorBlue"] = @([anchor[@"blue"] integerValue]);
            if (![config[@"colorTolerance"] respondsToSelector:@selector(doubleValue)]) {
                config[@"colorTolerance"] = @18.0;
            }
            [self storeBranchActionConfig:config success:success mode:mode];
        }
        [self finishColorPickingOverlay];
        [self stageTaskEditorModelForRuntime:_editingTaskModel];
        [self refreshEditorConfigControls];
        [self refreshTaskList];
        [self updateStatusForCurrentConfig];
        return;
    }
    [self applyTargetColorSamples:_pendingColorPickSamples];
    [self rememberManualCoordinateScreenSize];
    [self finishColorPickingOverlay];
    [self refreshTaskEditorAfterExternalResult];
    [self updateStatusForCurrentConfig];
    [self autosaveSelectedTaskIfPossible];
}

- (void)cancelColorPicking {
    _branchColorPickActive = NO;
    _branchColorPickMode = AnClickActionModeNone;
    [self finishColorPickingOverlay];
    _statusLabel.text = @"取消取色";
}

- (void)beginScreenPointPickingWithHostWindow:(UIWindow *)hostWindow {
    [_pickerService cancelPendingCaptures];
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    __weak typeof(self) weakSelf = self;
    [_pickerService captureAfterDelay:0.12 completion:^(UIImage *image, UIWindow *capturedWindow) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (!image.CGImage) {
            strongSelf->_statusLabel.text = @"截图失败";
            [strongSelf restorePanelAfterExternalTap];
            return;
        }
        UIWindow *overlayWindow = capturedWindow ?: hostWindow;
        if (![strongSelf->_pickerService capturedImage:image matchesWindow:overlayWindow]) {
            strongSelf->_statusLabel.text = @"截图方向异常 请重试";
            [strongSelf showToast:strongSelf->_statusLabel.text];
            [strongSelf restorePanelAfterExternalTap];
            return;
        }
        [strongSelf showPointPickOverlayWithImage:image hostWindow:overlayWindow];
    }];
}

- (void)beginFailureActionPointPicking {
    if (![self currentActionIsRecognitionMode]) {
        return;
    }
    if (![self currentFailureActionNeedsPoint]) {
        return;
    }

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    _pickingSuccessActionPoint = NO;
    _pickingFailureActionPoint = YES;
    _pickingSwipeEndPoint = NO;
    [self beginScreenPointPickingWithHostWindow:hostWindow];
}

- (void)beginSuccessActionPointPicking {
    if (![self currentActionIsRecognitionMode]) {
        return;
    }
    if (![self currentSuccessActionNeedsPoint]) {
        return;
    }

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    _pickingSuccessActionPoint = YES;
    _pickingFailureActionPoint = NO;
    _pickingSwipeEndPoint = NO;
    [self beginScreenPointPickingWithHostWindow:hostWindow];
}

- (void)beginPointPicking {
    if (_actionMode == AnClickActionModeNone) {
        _statusLabel.text = @"先选择动作";
        return;
    }

    _pickingSuccessActionPoint = NO;
    _pickingFailureActionPoint = NO;
    _pickingBranchRecognitionResultPoint = NO;
    _pickingBranchRecognitionResultSuccess = NO;

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    if (_actionMode == AnClickActionModeSwipe) {
        BOOL shouldPickEnd = _hasManualSwipeAnchor && !_hasManualSwipeEndPoint;
        if (!shouldPickEnd) {
            _hasManualSwipeAnchor = NO;
            _hasManualSwipeEndPoint = NO;
        }
        _pickingSwipeEndPoint = shouldPickEnd;
    } else {
        _pickingSwipeEndPoint = NO;
        if (_actionMode == AnClickActionModeImage) {
            _imageUsesMatchPoint = NO;
            [self refreshTaskEditorAfterExternalResult];
        } else if (_actionMode == AnClickActionModeOCR) {
            _ocrUsesMatchPoint = NO;
            [self refreshTaskEditorAfterExternalResult];
        } else if (_actionMode == AnClickActionModeColor) {
            _imageUsesMatchPoint = NO;
            [self refreshTaskEditorAfterExternalResult];
        }
    }

    [self beginScreenPointPickingWithHostWindow:hostWindow];
}

- (void)showPointPickOverlayWithImage:(UIImage *)image hostWindow:(UIWindow *)hostWindow {
    _pointPickOverlay.delegate = nil;
    [_pointPickOverlay removeFromSuperview];
    [_pickerService dismissOverlayWindow:_pointPickWindow];
    _pointPickSnapshot = image;
    _pointPickHostWindow = hostWindow;

    _pointPickWindow = [_pickerService overlayWindowForHostWindow:hostWindow levelOffset:2000.0];
    _pendingPointPickPoint = [self initialPointPickPoint];
    _pointPickOverlay = [[AnClickPointPickerView alloc] initWithFrame:_pointPickWindow.rootViewController.view.bounds
                                                                 image:image
                                                          initialPoint:_pendingPointPickPoint
                                                          surfaceColor:[self themeSurfaceColor]
                                                        separatorColor:[self themeSeparatorColor]
                                                      primaryTextColor:[self themePrimaryTextColor]
                                                      controlFillColor:[self themeControlFillColor]
                                                        highlightColor:[self themeHighlightColor]];
    _pointPickOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _pointPickOverlay.delegate = self;
    [_pointPickWindow.rootViewController.view addSubview:_pointPickOverlay];
    _hasPendingPointPickPoint = YES;
    if (_actionMode == AnClickActionModeSwipe && _pickingSwipeEndPoint && _hasManualSwipeAnchor) {
        [self showPointPickSwipeStartMarker];
    }
    _pointPickWindow.hidden = NO;
    [self updatePointPickCursor];
    _statusLabel.text = _pickingSuccessActionPoint
        ? @"取成功动作位置"
        : (_pickingFailureActionPoint ? @"取失败动作位置" : (_pickingSwipeEndPoint ? @"滑动取终点" : @"拖动取点"));
}

- (CGPoint)initialPointPickPoint {
    UIWindow *hostWindow = _pointPickHostWindow;
    if (_actionMode == AnClickActionModeSwipe && _pickingSwipeEndPoint && _hasManualSwipeAnchor && hostWindow) {
        return [self pointPickImagePointFromScreenPoint:_manualSwipeAnchor];
    }
    if (_pickingSuccessActionPoint && _hasSuccessActionPoint && hostWindow) {
        return [self pointPickImagePointFromScreenPoint:_successActionPoint];
    }
    if (_pickingFailureActionPoint && _hasFailureActionPoint && hostWindow) {
        return [self pointPickImagePointFromScreenPoint:_failureActionPoint];
    }
    if (_actionMode == AnClickActionModeTwoFingerTap && _multiTapPoints.count > 0 && hostWindow) {
        return [self pointPickImagePointFromScreenPoint:_multiTapPoints.lastObject.CGPointValue];
    }
    if ([self hasManualPointForMode:_actionMode] && hostWindow) {
        return [self pointPickImagePointFromScreenPoint:_manualActionPoints[(NSUInteger)_actionMode]];
    }
    CGRect bounds = CGRectMake(0, 0, _pointPickSnapshot.size.width, _pointPickSnapshot.size.height);
    return CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
}

- (CGPoint)pointPickScreenPointFromImagePoint:(CGPoint)point {
    UIWindow *hostWindow = _pointPickHostWindow ?: [self hostWindow];
    if (!hostWindow) {
        return point;
    }
    return [hostWindow convertPoint:point toWindow:nil];
}

- (CGPoint)pointPickImagePointFromScreenPoint:(CGPoint)point {
    UIWindow *hostWindow = _pointPickHostWindow ?: [self hostWindow];
    if (!hostWindow) {
        return point;
    }
    return [hostWindow convertPoint:point fromWindow:nil];
}

- (void)updatePointPickCursor {
    if (!_pointPickOverlay || !_hasPendingPointPickPoint) {
        return;
    }
    _pendingPointPickPoint = [_pointPickOverlay clampedImagePoint:_pendingPointPickPoint];
    _pointPickOverlay.selectedImagePoint = _pendingPointPickPoint;
    CGPoint screenPoint = [self pointPickScreenPointFromImagePoint:_pendingPointPickPoint];
    BOOL pickingCustomClickPoint = _actionMode == AnClickActionModeImage ||
        _actionMode == AnClickActionModeOCR ||
        _actionMode == AnClickActionModeColor;
    NSString *stage = nil;
    if (_pickingSuccessActionPoint) {
        stage = @"成功坐标";
    } else if (_pickingFailureActionPoint) {
        stage = @"失败坐标";
    } else if (_actionMode == AnClickActionModeSwipe) {
        stage = _pickingSwipeEndPoint ? @"终点" : @"起点";
    } else if (_actionMode == AnClickActionModeTwoFingerTap) {
        stage = [NSString stringWithFormat:@"触点%lu", (unsigned long)MIN(_multiTapPoints.count + 1, AnClickMultiTapMaxPoints)];
    } else {
        stage = pickingCustomClickPoint ? @"点击点" : [self currentActionName];
    }
    _pointPickOverlay.coordinateText = [NSString stringWithFormat:@"%@  X %.0f  Y %.0f",
                                        stage,
                                        screenPoint.x,
                                        screenPoint.y];
}

- (void)showPointPickSwipeStartMarker {
    if (!_pointPickOverlay || !_hasManualSwipeAnchor) {
        return;
    }
    [_pointPickOverlay showStartMarkerAtImagePoint:[self pointPickImagePointFromScreenPoint:_manualSwipeAnchor]];
}

- (void)finishPointPickingOverlay {
    _pointPickOverlay.delegate = nil;
    [_pointPickOverlay removeFromSuperview];
    _pointPickOverlay = nil;
    _pointPickSnapshot = nil;
    _hasPendingPointPickPoint = NO;
    [_pickerService dismissOverlayWindow:_pointPickWindow];
    _pointPickWindow = nil;
    _pointPickHostWindow = nil;
    _pickingSwipeEndPoint = NO;
    _pickingSuccessActionPoint = NO;
    _pickingFailureActionPoint = NO;
    _pickingBranchRecognitionResultPoint = NO;
    _pickingBranchRecognitionResultSuccess = NO;
    [self restorePanelAfterExternalTap];
}

- (void)cancelPointPicking {
    [self finishPointPickingOverlay];
    _statusLabel.text = @"取消取点";
}

- (void)pointPickerView:(AnClickPointPickerView *)view didMoveToImagePoint:(CGPoint)point {
    _pendingPointPickPoint = [view clampedImagePoint:point];
    _hasPendingPointPickPoint = YES;
    [self updatePointPickCursor];
}

- (void)pointPickerViewDidConfirm:(__unused AnClickPointPickerView *)view {
    [self confirmPointPicking];
}

- (void)pointPickerViewDidCancel:(__unused AnClickPointPickerView *)view {
    [self cancelPointPicking];
}

- (void)confirmPointPicking {
    UIWindow *hostWindow = _pointPickHostWindow ?: [self hostWindow];
    if (!hostWindow || !_hasPendingPointPickPoint) {
        [self cancelPointPicking];
        return;
    }

    CGPoint screenPoint = [self pointPickScreenPointFromImagePoint:_pendingPointPickPoint];

    if (_actionMode == AnClickActionModeNone) {
        [self cancelPointPicking];
        _statusLabel.text = @"先选择动作";
        return;
    }

    if (_pickingBranchRecognitionResultPoint) {
        BOOL success = _pickingBranchRecognitionResultSuccess;
        [self storeBranchRecognitionResultPoint:screenPoint success:success];
        _pickingBranchRecognitionResultPoint = NO;
        _pickingBranchRecognitionResultSuccess = NO;
        [self finishPointPickingOverlay];
        [self refreshTaskEditorViewFromCurrentState];
        [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
        return;
    }

    if (_pickingSuccessActionPoint) {
        _successActionPoint = screenPoint;
        _hasSuccessActionPoint = YES;
        [self rememberManualCoordinateScreenSize];
        [self finishPointPickingOverlay];
        [self refreshTaskEditorAfterExternalResult];
        [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
        [self updateStatusForCurrentConfig];
        [self autosaveSelectedTaskIfPossible];
        return;
    }

    if (_pickingFailureActionPoint) {
        _failureActionPoint = screenPoint;
        _hasFailureActionPoint = YES;
        [self rememberManualCoordinateScreenSize];
        [self finishPointPickingOverlay];
        [self refreshTaskEditorAfterExternalResult];
        [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
        [self updateStatusForCurrentConfig];
        [self autosaveSelectedTaskIfPossible];
        return;
    }

    if (_actionMode == AnClickActionModeSwipe) {
        if (!_pickingSwipeEndPoint) {
            _manualSwipeAnchor = screenPoint;
            _hasManualSwipeAnchor = YES;
            _hasManualSwipeEndPoint = NO;
            _manualSwipeEndPoint = CGPointZero;
            [self rememberManualCoordinateScreenSize];
            _pickingSwipeEndPoint = YES;
            _pendingPointPickPoint = [self pointPickImagePointFromScreenPoint:screenPoint];
            [self showPointPickSwipeStartMarker];
            [self updatePointPickCursor];
            [self refreshTaskEditorAfterExternalResult];
            return;
        }

        _manualSwipeEndPoint = screenPoint;
        _hasManualSwipeEndPoint = YES;
        [self rememberManualCoordinateScreenSize];
        [self finishPointPickingOverlay];
        [self showTapMarkerAtScreenPoint:_manualSwipeAnchor inWindow:hostWindow];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
        });
        NSArray<NSValue *> *path = [self manualSwipePath];
        if (path.count >= 2) {
            [self showTrajectoryForScreenPoints:path inWindow:hostWindow duration:1.0];
        }
        [self refreshTaskEditorAfterExternalResult];
        [self updateStatusForCurrentConfig];
        [self autosaveSelectedTaskIfPossible];
        return;
    }

    if (_actionMode == AnClickActionModeTwoFingerTap) {
        if (!_multiTapPoints) {
            _multiTapPoints = [NSMutableArray array];
        }
        if (_multiTapPoints.count >= AnClickMultiTapMaxPoints) {
            [self finishPointPickingOverlay];
            _statusLabel.text = [NSString stringWithFormat:@"最多%lu个触点", (unsigned long)AnClickMultiTapMaxPoints];
            return;
        }
        [_multiTapPoints addObject:[NSValue valueWithCGPoint:screenPoint]];
        [self rememberManualCoordinateScreenSize];
        [self finishPointPickingOverlay];
        [self refreshTaskEditorAfterExternalResult];
        [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
        [self updateStatusForCurrentConfig];
        [self autosaveSelectedTaskIfPossible];
        return;
    }

    _manualActionPoints[(NSUInteger)_actionMode] = screenPoint;
    _hasManualActionPoint[(NSUInteger)_actionMode] = YES;
    [self rememberManualCoordinateScreenSize];
    [self finishPointPickingOverlay];
    [self refreshTaskEditorAfterExternalResult];
    [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
    [self updateStatusForCurrentConfig];
    [self autosaveSelectedTaskIfPossible];
}

- (void)runManualAction {
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    AnClickTaskModel *model = _editingTaskModel ?: [self taskEditorModelByMergingRuntimeState];
    if (![self taskModelIsComplete:model]) {
        return;
    }
    [self preparePanelForExternalTapWithHostWindow:hostWindow];
    NSTimeInterval duration = [self performTaskModel:model inWindow:hostWindow];
    if (duration > 0) {
        _statusLabel.text = [NSString stringWithFormat:@"执行%@ %@", [self currentActionName], [self commonConfigSummary]];
    }
}

- (void)previewCurrentAction {
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    if (!_taskRunActive) {
        [_recognitionService cancelPendingRequests];
    }
    if (_actionMode == AnClickActionModeNone) {
        _statusLabel.text = @"先选择动作";
        return;
    }

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    if (_actionMode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = [self manualSwipePath];
        if (path.count < 2) {
            _statusLabel.text = _hasManualSwipeAnchor ? @"先取终点" : @"先取起点";
            return;
        }
        NSTimeInterval previewDuration = 1.2;
        [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
        NSUInteger geometryGeneration = _screenGeometryGeneration;
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                            runGeneration:0
                                                             restorePanel:YES]) {
                return;
            }
            [strongSelf showTrajectoryForScreenPoints:path inWindow:hostWindow duration:previewDuration];
            strongSelf->_statusLabel.text = (strongSelf->_hasManualSwipeAnchor && strongSelf->_hasManualSwipeEndPoint) ? @"预览起终点" : @"预览原轨迹";
            [strongSelf restorePanelAfterScreenDelay:previewDuration + 0.1];
        });
        return;
    }

    if (_actionMode == AnClickActionModeImage) {
        if (_imageActionMode == AnClickActionModeNetwork) {
            _statusLabel.text = _networkURL.length > 0 ? @"识图成功后请求网络" : @"先填网络链接";
            return;
        }
        if (_imageActionMode == AnClickActionModeJump) {
            _statusLabel.text = _recognitionSuccessBranchIndex >= 0
                ? [NSString stringWithFormat:@"识图成功后跳转任务%ld", (long)_recognitionSuccessBranchIndex + 1]
                : @"先填成功后跳转任务号";
            return;
        }
        if ([self modeIsRecognitionTask:_imageActionMode]) {
            _statusLabel.text = [NSString stringWithFormat:@"识图成功后执行%@动作", [self actionNameForMode:_imageActionMode]];
            return;
        }
        if (_imageUsesMatchPoint) {
            _statusLabel.text = [self currentTemplateExists] ? @"识图点随识别结果" : @"先截图模板";
            return;
        }
        if (![self hasManualPointForMode:AnClickActionModeImage]) {
            _statusLabel.text = @"先取点击点";
            return;
        }
        CGPoint point = _manualActionPoints[(NSUInteger)AnClickActionModeImage];
        NSTimeInterval previewDuration = 1.0;
        AnClickActionMode imageActionMode = _imageActionMode;
        [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
        NSUInteger geometryGeneration = _screenGeometryGeneration;
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                            runGeneration:0
                                                             restorePanel:YES]) {
                return;
            }
            [strongSelf showOperationTraceForMode:imageActionMode atPoint:point inWindow:hostWindow duration:previewDuration];
            strongSelf->_statusLabel.text = [NSString stringWithFormat:@"预览识图%@ %.0f,%.0f", [strongSelf actionNameForMode:imageActionMode], point.x, point.y];
            [strongSelf restorePanelAfterScreenDelay:previewDuration + 0.1];
        });
        return;
    }

    if (_actionMode == AnClickActionModeOCR) {
        if (_imageActionMode == AnClickActionModeNetwork) {
            _statusLabel.text = _networkURL.length > 0 ? @"识字成功后请求网络" : @"先填网络链接";
            return;
        }
        if (_imageActionMode == AnClickActionModeJump) {
            _statusLabel.text = _recognitionSuccessBranchIndex >= 0
                ? [NSString stringWithFormat:@"识字成功后跳转任务%ld", (long)_recognitionSuccessBranchIndex + 1]
                : @"先填成功后跳转任务号";
            return;
        }
        if ([self modeIsRecognitionTask:_imageActionMode]) {
            _statusLabel.text = [NSString stringWithFormat:@"识字成功后执行%@动作", [self actionNameForMode:_imageActionMode]];
            return;
        }
        if (_ocrUsesMatchPoint) {
            AnClickOCRMatchMode matchMode = [self effectiveOCRMatchModeForText:_ocrTargetText ?: @""];
            _statusLabel.text = _ocrTargetText.length > 0
                ? @"识字点随识别结果"
                : (matchMode == AnClickOCRMatchModeRegex ? @"先填正则表达式" : @"先填目标文字");
            return;
        }
        if (![self hasManualPointForMode:AnClickActionModeOCR]) {
            _statusLabel.text = @"先取点击点";
            return;
        }
        CGPoint point = _manualActionPoints[(NSUInteger)AnClickActionModeOCR];
        NSTimeInterval previewDuration = (_imageActionMode == AnClickActionModeLongPress)
            ? [self longPressOperationDurationForDuration:_longPressDuration] + 0.30
            : 1.0;
        AnClickActionMode actionMode = _imageActionMode;
        [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
        NSUInteger geometryGeneration = _screenGeometryGeneration;
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                            runGeneration:0
                                                             restorePanel:YES]) {
                return;
            }
            [strongSelf showOperationTraceForMode:actionMode atPoint:point inWindow:hostWindow duration:previewDuration];
            strongSelf->_statusLabel.text = [NSString stringWithFormat:@"预览识字%@ %.0f,%.0f", [strongSelf actionNameForMode:actionMode], point.x, point.y];
            [strongSelf restorePanelAfterScreenDelay:previewDuration + 0.1];
        });
        return;
    }

    if (_actionMode == AnClickActionModeNetwork) {
        AnClickTaskModel *model = _editingTaskModel ?: [self taskEditorModelByMergingRuntimeState];
        NSMutableDictionary *task = [self taskDictionaryForModel:model];
        if (![self taskModelIsComplete:model]) {
            return;
        }
        _statusLabel.text = @"测试网络";
        [self performNetworkRequestTask:task runGeneration:0 completion:nil];
        return;
    }

    if (_actionMode == AnClickActionModeColor) {
        if (_imageActionMode == AnClickActionModeNetwork) {
            _statusLabel.text = _networkURL.length > 0 ? @"识色成功后请求网络" : @"先填网络链接";
            return;
        }
        if (_imageActionMode == AnClickActionModeJump) {
            _statusLabel.text = _recognitionSuccessBranchIndex >= 0
                ? [NSString stringWithFormat:@"识色成功后跳转任务%ld", (long)_recognitionSuccessBranchIndex + 1]
                : @"先填成功后跳转任务号";
            return;
        }
        if ([self modeIsRecognitionTask:_imageActionMode]) {
            _statusLabel.text = [NSString stringWithFormat:@"识色成功后执行%@动作", [self actionNameForMode:_imageActionMode]];
            return;
        }
        NSArray<NSDictionary *> *colorPoints = [self effectiveTargetColorSamples];
        if (colorPoints.count == 0) {
            _statusLabel.text = @"先取目标颜色";
            return;
        }
        double tolerance = _colorTolerance;
        NSTimeInterval previewDuration = 1.2;
        NSString *patternSummary = [self targetColorShortDescription];
        [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
        NSUInteger geometryGeneration = _screenGeometryGeneration;
        __weak typeof(self) weakSelf = self;
        [_taskEngine scheduleRecognitionCaptureWithHost:hostWindow generation:0 delay:AnClickRecognitionCaptureDelay block:^{
            __strong typeof(weakSelf) delayedSelf = weakSelf;
            if (!delayedSelf) {
                return;
            }
            if (![delayedSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                             runGeneration:0
                                                              restorePanel:YES]) {
                return;
            }
            [delayedSelf->_recognitionService findColorPatternMatchWithPoints:colorPoints tolerance:tolerance completion:^(NSDictionary *match) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) {
                        return;
                    }
                    if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                                    runGeneration:0
                                                                     restorePanel:YES]) {
                        return;
                    }
                    if (!match) {
                        strongSelf->_statusLabel.text = @"颜色未找到";
                        [strongSelf restorePanelAfterExternalTap];
                        return;
                    }
                    NSValue *rectValue = match[@"rect"];
                    NSValue *pointValue = match[@"point"];
                    if (rectValue) {
                        [strongSelf showRecognitionBoxForScreenRect:rectValue.CGRectValue score:[match[@"score"] doubleValue] inWindow:hostWindow duration:previewDuration];
                    }
                    CGPoint point = pointValue ? pointValue.CGPointValue : CGPointZero;
                    if (!strongSelf->_imageUsesMatchPoint &&
                        [strongSelf hasManualPointForMode:AnClickActionModeColor]) {
                        point = strongSelf->_manualActionPoints[(NSUInteger)AnClickActionModeColor];
                    }
                    strongSelf->_statusLabel.text = [NSString stringWithFormat:@"预览识色 %@ %.0f,%.0f", patternSummary, point.x, point.y];
                    [strongSelf restorePanelAfterScreenDelay:previewDuration + 0.1];
            });
        }];
        return;
    }

    if (_actionMode == AnClickActionModeTwoFingerTap) {
        if (_multiTapPoints.count < 2) {
            _statusLabel.text = @"先取至少2个触点";
            return;
        }
        NSArray<NSValue *> *points = [_multiTapPoints copy];
        NSTimeInterval previewDuration = 1.0;
        [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
        NSUInteger geometryGeneration = _screenGeometryGeneration;
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                            runGeneration:0
                                                             restorePanel:YES]) {
                return;
            }
            [strongSelf showMultiTapMarkersForScreenPoints:points inWindow:hostWindow duration:previewDuration];
            strongSelf->_statusLabel.text = [NSString stringWithFormat:@"预览多指%lu点", (unsigned long)points.count];
            [strongSelf restorePanelAfterScreenDelay:previewDuration + 0.1];
        });
        return;
    }

    if (![self hasManualPointForMode:_actionMode]) {
        _statusLabel.text = @"先取点";
        return;
    }
    CGPoint point = _manualActionPoints[(NSUInteger)_actionMode];
    NSTimeInterval previewDuration = (_actionMode == AnClickActionModeLongPress)
        ? [self longPressOperationDurationForDuration:_longPressDuration] + 0.30
        : 1.0;
    AnClickActionMode actionMode = _actionMode;
    NSString *actionName = [self currentActionName];
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    NSUInteger geometryGeneration = _screenGeometryGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                        runGeneration:0
                                                         restorePanel:YES]) {
            return;
        }
        [strongSelf showOperationTraceForMode:actionMode atPoint:point inWindow:hostWindow duration:previewDuration];
        strongSelf->_statusLabel.text = [NSString stringWithFormat:@"预览%@ %.0f,%.0f", actionName, point.x, point.y];
        [strongSelf restorePanelAfterScreenDelay:previewDuration + 0.1];
    });
}

- (void)toggleMacroRecording {
    AnClickRecorder *recorder = [AnClickRecorder shared];
    if (recorder.isRecording) {
        [recorder stopRecording];
        _recordedMacroEvents = [recorder serializedEvents];
        _recordedMacroScreenSize = [self currentScreenCoordinateSize];
        _hasRecordedMacroScreenSize = YES;
        _statusLabel.text = [NSString stringWithFormat:@"已录 %lu步", (unsigned long)_recordedMacroEvents.count];
        [self refreshCollapsedButtonTitle];
        [self syncTaskEditorModelFromRuntimeState];
        if (_returnToEditorAfterRecording) {
            _taskEditorVisible = YES;
            [self expandPanel];
        }
        _returnToEditorAfterRecording = NO;
        [self refreshEditorConfigControls];
        [self autosaveSelectedTaskIfPossible];
        return;
    }

    if (![self panelCanUseCurrentScene]) {
        return;
    }

    _actionMode = AnClickActionModeMacro;
    _recordedMacroEvents = nil;
    _recordedMacroScreenSize = CGSizeZero;
    _hasRecordedMacroScreenSize = NO;
    [self syncTaskEditorModelFromRuntimeState];
    _returnToEditorAfterRecording = _taskEditorVisible;
    [recorder startRecording];
    [self invalidatePendingPanelRestore];
    [self refreshModeButtons];
    [self showCollapsedRecordingButton];
    _statusLabel.text = @"录制中";
}

- (void)playRecordedMacro {
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    if (_recordedMacroEvents.count == 0) {
        _statusLabel.text = @"无录制";
        return;
    }

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    double playbackSpeed = [self normalizedMacroPlaybackSpeed:_macroPlaybackSpeed];
    NSTimeInterval duration = [self durationForRecordedEvents:_recordedMacroEvents playbackSpeed:playbackSpeed];
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    NSArray<NSDictionary *> *recordedEvents = _hasRecordedMacroScreenSize
        ? [self resolvedRecordedEvents:_recordedMacroEvents fromScreenSize:_recordedMacroScreenSize]
        : [_recordedMacroEvents copy];
    NSArray<NSValue *> *trajectory = [self trajectoryPointsForRecordedEvents:recordedEvents];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (trajectory.count >= 2) {
            [strongSelf showTrajectoryForScreenPoints:trajectory inWindow:hostWindow duration:duration];
        } else if (trajectory.count == 1) {
            [strongSelf showTapMarkerAtScreenPoint:trajectory.firstObject.CGPointValue inWindow:hostWindow];
        }
        [AnClickFakeTouch playRecordedEvents:recordedEvents playbackSpeed:playbackSpeed];
        [strongSelf restorePanelAfterScreenDelay:duration + 0.15];
    });
    _statusLabel.text = [NSString stringWithFormat:@"回放 %lu步 速%@", (unsigned long)_recordedMacroEvents.count, [self macroPlaybackSpeedSummaryText:playbackSpeed]];
}

- (void)beginSwipeRecording {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    [_trajectoryView removeFromSuperview];
    _liveSwipePoints = [NSMutableArray array];

    UIView *view = [[UIView alloc] initWithFrame:hostWindow.bounds];
    view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.10];
    view.userInteractionEnabled = YES;

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(12, 44, hostWindow.bounds.size.width - 24, 34)];
    hint.text = @"滑动录制中";
    hint.textColor = UIColor.whiteColor;
    hint.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    hint.layer.cornerRadius = 8;
    hint.clipsToBounds = YES;
    [view addSubview:hint];

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.frame = view.bounds;
    layer.strokeColor = UIColor.systemGreenColor.CGColor;
    layer.fillColor = UIColor.clearColor.CGColor;
    layer.lineWidth = 4.0;
    layer.lineCap = kCALineCapRound;
    layer.lineJoin = kCALineJoinRound;
    [view.layer addSublayer:layer];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeRecordingPan:)];
    [view addGestureRecognizer:pan];

    [hostWindow addSubview:view];
    _trajectoryView = view;
    _trajectoryLayer = layer;
    _statusLabel.text = @"录制滑动";
}

- (void)handleSwipeRecordingPan:(UIPanGestureRecognizer *)recognizer {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        return;
    }

    CGPoint windowPoint = [recognizer locationInView:hostWindow];
    CGPoint screenPoint = [hostWindow convertPoint:windowPoint toWindow:nil];

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [_liveSwipePoints removeAllObjects];
        [_liveSwipePoints addObject:[NSValue valueWithCGPoint:screenPoint]];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint last = _liveSwipePoints.lastObject.CGPointValue;
        CGFloat dx = screenPoint.x - last.x;
        CGFloat dy = screenPoint.y - last.y;
        if (sqrt(dx * dx + dy * dy) >= 3.0) {
            [_liveSwipePoints addObject:[NSValue valueWithCGPoint:screenPoint]];
        }
    } else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        [_liveSwipePoints addObject:[NSValue valueWithCGPoint:screenPoint]];
        if (_liveSwipePoints.count >= 2) {
            _recordedSwipePoints = [_liveSwipePoints mutableCopy];
            _hasManualSwipeAnchor = NO;
            _hasManualSwipeEndPoint = NO;
            [self rememberManualCoordinateScreenSize];
            _actionMode = AnClickActionModeSwipe;
            [self refreshModeButtons];
            _statusLabel.text = [NSString stringWithFormat:@"已录 %lu点", (unsigned long)_recordedSwipePoints.count];
            [self showTrajectoryForScreenPoints:_recordedSwipePoints inWindow:hostWindow duration:1.0];
            [self restorePanelAfterScreenDelay:1.1];
        } else {
            _statusLabel.text = @"录制失败";
            [_trajectoryView removeFromSuperview];
            [self restorePanelAfterScreenDelay:0.1];
        }
        _liveSwipePoints = nil;
        return;
    }

    [self updateLiveTrajectoryInWindow:hostWindow];
}

- (void)playTemplateTap {
    if (![self panelCanUseCurrentScene]) {
        return;
    }
    if (_templateSearchInProgress) {
        _statusLabel.text = @"识图中";
        return;
    }

    NSString *path = [self activeTemplatePath];
    if (path.length == 0) {
        path = [self templatePath];
    }
    UIImage *templateImage = [self cachedTemplateImageAtPath:path];
    if (!templateImage) {
        _statusLabel.text = @"先截图";
        return;
    }

    _statusLabel.text = @"寻找";
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }
    _templateSearchInProgress = YES;
    double matchThreshold = _matchThreshold;
    BOOL shouldRestorePanel = [self hideOwnUIForRecognitionCaptureWithHostWindow:hostWindow];
    NSUInteger geometryGeneration = _screenGeometryGeneration;
    __weak typeof(self) weakSelf = self;
    [_taskEngine scheduleRecognitionCaptureWithHost:hostWindow generation:0 delay:AnClickRecognitionCaptureDelay block:^{
        __strong typeof(weakSelf) delayedSelf = weakSelf;
        if (!delayedSelf) {
            return;
        }
        if (![delayedSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                         runGeneration:0
                                                          restorePanel:YES]) {
            delayedSelf->_templateSearchInProgress = NO;
            [delayedSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
            return;
        }
        [delayedSelf->_recognitionService findTemplateImageMatch:templateImage threshold:matchThreshold completion:^(NSDictionary *match) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                strongSelf->_templateSearchInProgress = NO;
                if (![strongSelf recognitionGeometryStillValidFromGeneration:geometryGeneration
                                                                runGeneration:0
                                                                 restorePanel:YES]) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    return;
                }
                if (!match) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"未找到";
                    return;
                }
                NSValue *pointValue = match[@"point"];
                NSValue *rectValue = match[@"rect"];
                NSNumber *scoreNumber = match[@"score"];
                if (!pointValue || !rectValue) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"识别异常";
                    return;
                }
                CGPoint point = pointValue.CGPointValue;
                CGRect rect = rectValue.CGRectValue;
                UIWindow *currentHostWindow = [strongSelf hostWindowForCallbackWithFallback:hostWindow
                                                                              runGeneration:0
                                                                                     status:nil];
                if (!currentHostWindow) {
                    [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:0.05];
                    strongSelf->_statusLabel.text = @"无窗口";
                    return;
                }
                [strongSelf showRecognitionBoxForScreenRect:rect score:scoreNumber.doubleValue inWindow:currentHostWindow duration:1.6];
                [strongSelf performSelectedActionAtPoint:point inWindow:currentHostWindow preparePanel:NO];
                strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识别 %.2f  %.0f,%.0f",
                                                 scoreNumber.doubleValue,
                                                 point.x,
                                                 point.y];
                NSTimeInterval restoreDelay = MAX([strongSelf durationForTaskMode:strongSelf->_actionMode],
                                                  strongSelf->_actionMode == AnClickActionModeSwipe ? 1.15 : 1.0);
                [strongSelf restorePanelAfterRecognitionCaptureIfNeeded:shouldRestorePanel delay:restoreDelay + 0.10];
        });
    }];
}

- (void)testCenterTap {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    CGPoint windowPoint = CGPointMake(CGRectGetMidX(hostWindow.bounds), CGRectGetMidY(hostWindow.bounds));
    CGPoint point = [hostWindow convertPoint:windowPoint toWindow:nil];
    NSLog(@"[AnClick] Test tap window=(%.1f, %.1f) screen=(%.1f, %.1f) host=%@",
          windowPoint.x,
          windowPoint.y,
          point.x,
          point.y,
          hostWindow);
    [self preparePanelForExternalTapWithHostWindow:hostWindow];
    [self performSelectedActionAtPoint:point inWindow:hostWindow];
}

@end

static void AnClickHardwareButtonEventCallback(void *target, void *refcon, IOHIDServiceClientRef service, IOHIDEventRef event) {
    (void)refcon;
    (void)service;
    AnClickUI *ui = (__bridge AnClickUI *)target;
    if (!ui) {
        return;
    }
    [ui handleHardwareButtonHIDEvent:event];
}

static void AnClickVolumeDarwinNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center;
    (void)object;
    (void)userInfo;
    NSInteger direction = 0;
    if (CFStringCompare(name, AnClickVolumeShortcutNotification(-1), 0) == kCFCompareEqualTo) {
        direction = -1;
    } else if (CFStringCompare(name, AnClickVolumeShortcutNotification(1), 0) == kCFCompareEqualTo) {
        direction = 1;
    }
    if (direction == 0) {
        return;
    }

    AnClickUI *ui = (__bridge AnClickUI *)observer;
    dispatch_async(dispatch_get_main_queue(), ^{
        [ui handleExternalVolumeShortcutDirection:direction];
    });
}

static BOOL AnClickProcessIsSpringBoard(void) {
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *bundleIdentifier = bundle.bundleIdentifier ?: @"";
    NSString *processName = NSProcessInfo.processInfo.processName ?: @"";
    return [bundleIdentifier isEqualToString:@"com.apple.springboard"] ||
        [processName isEqualToString:@"SpringBoard"];
}

static NSNumber *AnClickNumberValueForObjectKeys(id object, NSArray<NSString *> *keys) {
    if (!object) {
        return nil;
    }
    if ([object isKindOfClass:NSNumber.class]) {
        return object;
    }

    for (NSString *key in keys) {
        id value = nil;
        @try {
            value = [object valueForKey:key];
        } @catch (__unused NSException *exception) {
            value = nil;
        }
        if ([value isKindOfClass:NSNumber.class]) {
            return value;
        }
        if ([value respondsToSelector:@selector(integerValue)]) {
            return @([value integerValue]);
        }
    }
    return nil;
}

static NSInteger AnClickVolumeShortcutDirectionFromPressesEvent(id event) {
    if (!event || ![event respondsToSelector:@selector(allPresses)]) {
        return 0;
    }
    if ([event respondsToSelector:@selector(type)] && ((UIEvent *)event).type != UIEventTypePresses) {
        return 0;
    }

    NSSet<UIPress *> *presses = [(UIEvent *)event allPresses];
    for (UIPress *press in presses) {
        NSNumber *typeNumber = AnClickNumberValueForObjectKeys(press, @[@"_type", @"type", @"_buttonType", @"buttonType"]);
        NSInteger type = typeNumber.integerValue;
        if (type == AnClickSpringBoardVolumeDownButtonType) {
            return -1;
        }
        if (type == AnClickSpringBoardVolumeUpButtonType) {
            return 1;
        }
    }
    return 0;
}

static NSInteger AnClickVolumeShortcutDirectionFromPhysicalButtonEvent(id event) {
    NSNumber *downNumber = AnClickNumberValueForObjectKeys(event, @[@"_down", @"down", @"_isDown", @"isDown", @"pressed"]);
    if (downNumber && !downNumber.boolValue) {
        return 0;
    }

    NSNumber *typeNumber = AnClickNumberValueForObjectKeys(event, @[@"_type", @"type", @"_buttonType", @"buttonType"]);
    NSInteger type = typeNumber.integerValue;
    if (type == AnClickSpringBoardVolumeDownButtonType) {
        return -1;
    }
    if (type == AnClickSpringBoardVolumeUpButtonType) {
        return 1;
    }

    return AnClickVolumeShortcutDirectionFromPressesEvent(event);
}

static void AnClickPostVolumeShortcutDirection(NSInteger direction) {
    if (direction == 0) {
        return;
    }

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         AnClickVolumeShortcutNotification(direction),
                                         NULL,
                                         NULL,
                                         true);
}

static void AnClickInstallWindowPressEventHook(void) {
    static BOOL installed = NO;
    if (installed) {
        return;
    }

    Class cls = UIWindow.class;
    SEL selector = @selector(sendEvent:);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        return;
    }

    installed = YES;
    AnClickOriginalWindowSendEvent = (void (*)(id, SEL, UIEvent *))method_getImplementation(method);
    IMP replacement = imp_implementationWithBlock(^(__unsafe_unretained UIWindow *window, UIEvent *event) {
        if (!AnClickProcessIsSpringBoard()) {
            NSInteger direction = AnClickVolumeShortcutDirectionFromPressesEvent(event);
            if (direction != 0) {
                [[AnClickUI shared] handleExternalVolumeShortcutDirection:direction];
            }
        }
        if (AnClickOriginalWindowSendEvent) {
            AnClickOriginalWindowSendEvent(window, selector, event);
        }
    });
    method_setImplementation(method, replacement);
}

static void AnClickSpringBoardHandlePhysicalButtonEvent(id self, SEL _cmd, id event) {
    NSInteger direction = AnClickVolumeShortcutDirectionFromPhysicalButtonEvent(event);
    if (direction != 0) {
        AnClickPostVolumeShortcutDirection(direction);
    }
    if (AnClickOriginalSpringBoardHandlePhysicalButtonEvent) {
        AnClickOriginalSpringBoardHandlePhysicalButtonEvent(self, _cmd, event);
    }
}

static void AnClickHookVolumeControlSelector(Class cls, SEL selector, NSInteger direction) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        return;
    }

    IMP original = method_getImplementation(method);
    unsigned int argCount = method_getNumberOfArguments(method);
    IMP replacement = nil;
    if (argCount == 2) {
        replacement = imp_implementationWithBlock(^(__unsafe_unretained id object) {
            AnClickPostVolumeShortcutDirection(direction);
            ((void (*)(id, SEL))original)(object, selector);
        });
    } else if (argCount == 3) {
        replacement = imp_implementationWithBlock(^(__unsafe_unretained id object, uintptr_t arg1) {
            AnClickPostVolumeShortcutDirection(direction);
            ((void (*)(id, SEL, uintptr_t))original)(object, selector, arg1);
        });
    } else if (argCount == 4) {
        replacement = imp_implementationWithBlock(^(__unsafe_unretained id object, uintptr_t arg1, uintptr_t arg2) {
            AnClickPostVolumeShortcutDirection(direction);
            ((void (*)(id, SEL, uintptr_t, uintptr_t))original)(object, selector, arg1, arg2);
        });
    }

    if (!replacement) {
        return;
    }

    method_setImplementation(method, replacement);
    NSLog(@"[AnClick] Installed volume control shortcut hook %@ %@", NSStringFromClass(cls), NSStringFromSelector(selector));
}

static void AnClickInstallSpringBoardVolumeControlHook(void) {
    static BOOL installed = NO;
    if (installed || !AnClickProcessIsSpringBoard()) {
        return;
    }

    NSArray<NSString *> *classNames = @[
        @"VolumeControl",
        @"SBVolumeControl",
        @"SBVolumeHardwareButtonController",
    ];
    NSArray<NSString *> *downSelectors = @[
        @"decreaseVolume",
        @"decreaseVolume:",
        @"_decreaseVolume",
        @"_decreaseVolume:",
        @"handleVolumeDownButtonDown:",
    ];
    NSArray<NSString *> *upSelectors = @[
        @"increaseVolume",
        @"increaseVolume:",
        @"_increaseVolume",
        @"_increaseVolume:",
        @"handleVolumeUpButtonDown:",
    ];

    BOOL hookedAny = NO;
    for (NSString *className in classNames) {
        Class cls = NSClassFromString(className);
        if (!cls) {
            continue;
        }
        for (NSString *selectorName in downSelectors) {
            SEL selector = NSSelectorFromString(selectorName);
            Method method = class_getInstanceMethod(cls, selector);
            if (!method) {
                continue;
            }
            AnClickHookVolumeControlSelector(cls, selector, -1);
            hookedAny = YES;
        }
        for (NSString *selectorName in upSelectors) {
            SEL selector = NSSelectorFromString(selectorName);
            Method method = class_getInstanceMethod(cls, selector);
            if (!method) {
                continue;
            }
            AnClickHookVolumeControlSelector(cls, selector, 1);
            hookedAny = YES;
        }
    }

    installed = hookedAny;
}

static void AnClickInstallSpringBoardPhysicalButtonHook(void) {
    static BOOL installed = NO;
    if (installed || !AnClickProcessIsSpringBoard()) {
        return;
    }

    NSArray<NSString *> *classNames = @[@"SpringBoard", @"SBUIController"];
    NSArray<NSString *> *selectorNames = @[@"_handlePhysicalButtonEvent:", @"handlePhysicalButtonEvent:", @"_handleButtonEvent:"];
    for (NSString *className in classNames) {
        Class cls = NSClassFromString(className);
        if (!cls) {
            continue;
        }
        for (NSString *selectorName in selectorNames) {
            SEL selector = NSSelectorFromString(selectorName);
            Method method = class_getInstanceMethod(cls, selector);
            if (!method) {
                continue;
            }
            installed = YES;
            AnClickOriginalSpringBoardHandlePhysicalButtonEvent = (void (*)(id, SEL, id))method_getImplementation(method);
            method_setImplementation(method, (IMP)AnClickSpringBoardHandlePhysicalButtonEvent);
            NSLog(@"[AnClick] Installed SpringBoard volume shortcut hook %@ %@", className, selectorName);
            return;
        }
    }
}

__attribute__((constructor)) static void AnClickUIInit(void) {
    NSLog(@"[AnClick] UI constructor loaded");
    AnClickInstallWindowPressEventHook();
    if (AnClickProcessIsSpringBoard()) {
        AnClickInstallSpringBoardPhysicalButtonHook();
        AnClickInstallSpringBoardVolumeControlHook();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            AnClickInstallSpringBoardPhysicalButtonHook();
            AnClickInstallSpringBoardVolumeControlHook();
        });
        return;
    }
    AnClickHardenLocalRuntime();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AnClickUI shared] show];
    });
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification) {
        [[AnClickUI shared] handleApplicationDidBecomeActive];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification) {
        [[AnClickUI shared] handleApplicationWillLeaveForeground];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification) {
        [[AnClickUI shared] handleApplicationWillLeaveForeground];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification) {
        [[AnClickUI shared] handleApplicationWillLeaveForeground];
    }];
    [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification) {
        [[AnClickUI shared] handleScreenGeometryChanged];
    }];
}
