#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <math.h>

typedef NS_ENUM(NSInteger, AnClickActionMode) {
    AnClickActionModeNone = -1,
    AnClickActionModeTap = 0,
    AnClickActionModeDoubleTap = 1,
    AnClickActionModeLongPress = 2,
    AnClickActionModeSwipe = 3,
    AnClickActionModeTwoFingerTap = 4,
    AnClickActionModePinchIn = 5,
    AnClickActionModePinchOut = 6,
    AnClickActionModeRotate = 7,
    AnClickActionModeImage = 8,
    AnClickActionModeMacro = 9,
    AnClickActionModeOCR = 10,
    AnClickActionModeColor = 11,
    AnClickActionModeNetwork = 12,
    AnClickActionModeCount = 13,
};

typedef NS_ENUM(NSInteger, AnClickOCRMode) {
    AnClickOCRModeAppleVision = 0,
};

typedef NS_ENUM(NSInteger, AnClickOCRMatchMode) {
    AnClickOCRMatchModeContains = 0,
    AnClickOCRMatchModeRegex = 1,
};

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
static const NSInteger AnClickColorPickMarkerTagBase = 43100;
static const NSInteger AnClickColorPickRowTagBase = 43200;
static const NSUInteger AnClickColorPickMaxSamples = 32;
static CFStringRef const AnClickVolumeShortcutDownNotification = CFSTR("com.anclick.volume.down");
static CFStringRef const AnClickVolumeShortcutUpNotification = CFSTR("com.anclick.volume.up");
static void (*AnClickOriginalWindowSendEvent)(id self, SEL _cmd, UIEvent *event);
static void (*AnClickOriginalSpringBoardHandlePhysicalButtonEvent)(id self, SEL _cmd, id event);

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

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (NSDictionary *)findTemplateImageMatch:(UIImage *)templateImage threshold:(double)threshold;
+ (NSDictionary *)findColorMatchWithRed:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue tolerance:(double)tolerance;
+ (NSDictionary *)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points tolerance:(double)tolerance;
+ (NSValue *)findTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
+ (BOOL)findAndTapTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
@end

@interface AnClickOCR : NSObject
+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode;
+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode useRegex:(BOOL)useRegex;
+ (NSString *)backendNameForMode:(NSInteger)mode;
@end

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
+ (void)doubleTapAtPoint:(CGPoint)point;
+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration;
+ (void)beginHoldAtPoint:(CGPoint)point;
+ (void)endHold;
+ (void)cancelHold;
+ (BOOL)isHolding;
+ (void)playPath:(NSArray<NSValue *> *)points duration:(NSTimeInterval)duration;
+ (void)playRecordedEvents:(NSArray<NSDictionary *> *)events;
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

@interface AnClickUI : NSObject <UITextFieldDelegate, UIGestureRecognizerDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UIScrollViewDelegate>
+ (instancetype)shared;
- (void)show;
- (void)handleScreenGeometryChanged;
- (void)handleHardwareButtonHIDEvent:(IOHIDEventRef)event;
- (void)handleWindowPressesEvent:(UIEvent *)event;
- (void)handleExternalVolumeShortcutDirection:(NSInteger)direction;
- (void)handleApplicationDidBecomeActive;
- (void)handleApplicationWillLeaveForeground;
@end

@implementation AnClickUI {
    UIWindow *_panelWindow;
    UIWindow *_toastWindow;
    UIView *_panelView;
    UIView *_toastView;
    UIView *_hostToastView;
    UIButton *_collapsedButton;
    UIButton *_captureButton;
    UIButton *_playButton;
    UIButton *_testButton;
    UIButton *_recordSwipeButton;
    UIButton *_pickPointButton;
    UIButton *_runManualButton;
    UIButton *_previewSwipeButton;
    UIButton *_clearActionButton;
    UIButton *_addTaskButton;
    UIButton *_deleteTaskButton;
    UIButton *_saveTaskButton;
    UIButton *_runTasksButton;
    UIButton *_collapseButton;
    UIButton *_homeCloseButton;
    UIButton *_editorBackButton;
    UIButton *_imageActionButton;
    UIButton *_ocrContainsMatchModeButton;
    UIButton *_ocrRegexMatchModeButton;
    UIButton *_networkRequestModeButton;
    UIButton *_networkMethodButton;
    UIButton *_networkRetryModeButton;
    UIButton *_networkPostCustomButton;
    UIButton *_networkPostOCRResultButton;
    UIButton *_previewActionButton;
    UIButton *_swipeRecordButton;
    UIButton *_macroRecordButton;
    UIButton *_macroPlayButton;
    UIButton *_cancelEditButton;
    UIButton *_globalSettingsButton;
    NSArray<UIButton *> *_modeButtons;
    UIScrollView *_taskListView;
    UIScrollView *_editorContentScrollView;
    UILabel *_statusLabel;
    UILabel *_toastLabel;
    UILabel *_hostToastLabel;
    UILabel *_toolTitleLabel;
    UILabel *_editorTitleLabel;
    UILabel *_descriptionCaptionLabel;
    UILabel *_primaryConfigLabel;
    UILabel *_secondaryConfigLabel;
    UILabel *_tertiaryConfigLabel;
    UILabel *_thresholdCaptionLabel;
    UILabel *_delayCaptionLabel;
    UILabel *_repeatCaptionLabel;
    UITextField *_descriptionField;
    UITextField *_delayField;
    UITextField *_repeatField;
    UITextField *_thresholdField;
    UITextField *_ocrTargetField;
    UITextField *_networkURLField;
    UITextField *_networkContainsField;
    UITextField *_networkFalseField;
    UITextField *_networkPostBodyField;
    UITextField *_networkPostExtraFieldsField;
    UIView *_captureOverlay;
    UIScrollView *_captureScrollView;
    UIImageView *_captureImageView;
    UIView *_selectionView;
    UIView *_pointPickOverlay;
    UIWindow *_pointPickWindow;
    UIScrollView *_pointPickScrollView;
    UIImageView *_pointPickImageView;
    UIView *_pointCursorView;
    UIView *_pointPickToolbar;
    UILabel *_pointCoordinateLabel;
    UIWindow *_colorPickWindow;
    UIScrollView *_colorPickScrollView;
    UIImageView *_colorPickImageView;
    UIView *_colorPickCursorView;
    UIView *_colorPickToolbar;
    UIScrollView *_colorPickListView;
    UILabel *_colorPickInfoLabel;
    UIView *_colorPickSwatchView;
    UIButton *_colorPickDeleteButton;
    UIImage *_captureSnapshot;
    UIImage *_pointPickSnapshot;
    UIImage *_colorPickImage;
    NSMutableData *_colorPickPixelData;
    UIImageView *_previewView;
    UIView *_colorPreviewView;
    UIView *_tapMarkerView;
    UIView *_recognitionBoxView;
    UIView *_operationTraceView;
    UIView *_trajectoryView;
    CAShapeLayer *_trajectoryLayer;
    UIView *_functionMenuView;
    UIView *_globalSettingsView;
    UIScrollView *_globalSettingsScrollView;
    UITextField *_globalDelayField;
    UITextField *_globalRepeatField;
    UITextField *_globalNetworkURLField;
    UITextField *_globalNetworkContainsField;
    UITextField *_globalNetworkFalseField;
    UIButton *_globalStartTimeButton;
    UIButton *_globalStopTimeButton;
    UIButton *_globalNetworkGateButton;
    UIView *_globalTimePickerView;
    UIPickerView *_globalTimePicker;
    UIScrollView *_configListView;
    NSMutableArray<NSValue *> *_recordedSwipePoints;
    NSMutableArray<NSValue *> *_liveSwipePoints;
    NSArray<NSDictionary *> *_recordedMacroEvents;
    NSMutableArray<NSMutableDictionary *> *_taskItems;
    NSInteger _selectedTaskIndex;
    NSInteger _draggingTaskIndex;
    NSInteger _revealedDeleteTaskIndex;
    CGFloat _taskPanStartOffsetX;
    BOOL _taskPanDirectionLocked;
    BOOL _taskPanHorizontal;
    BOOL _taskReordering;
    CGPoint _manualActionPoints[AnClickActionModeCount];
    BOOL _hasManualActionPoint[AnClickActionModeCount];
    CGPoint _manualSwipeAnchor;
    BOOL _hasManualSwipeAnchor;
    CGPoint _manualSwipeEndPoint;
    BOOL _hasManualSwipeEndPoint;
    BOOL _pickingSwipeEndPoint;
    BOOL _pointPickPanStartedOnToolbar;
    CGPoint _pendingPointPickPoint;
    BOOL _hasPendingPointPickPoint;
    BOOL _longPressHolding;
    BOOL _templateSearchInProgress;
    BOOL _captureDrawingSelection;
    CGPoint _captureDragStartPoint;
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
    BOOL _globalTimePickerEditingStartTime;
    BOOL _taskRunActive;
    BOOL _taskRunPausedForForeground;
    BOOL _taskRunResumeInGlobalNetworkGate;
    BOOL _taskRunResumeScheduled;
    BOOL _volumeShortcutRegistered;
    BOOL _volumeKVORegistered;
    BOOL _volumeDarwinObserverRegistered;
    BOOL _hardwareVolumeButtonObserverRegistered;
    BOOL _hasObservedSystemVolume;
    BOOL _volumeShortcutRunSuppressToasts;
    NSUInteger _panelRestoreGeneration;
    NSUInteger _taskRunGeneration;
    NSUInteger _toastGeneration;
    CGFloat _taskReorderStartCenterY;
    CGFloat _taskReorderStartLocationY;
    CFTimeInterval _toastDeferNonVolumeUntil;
    CFTimeInterval _lastVolumeShortcutTime;
    CFTimeInterval _ignoreVolumeEventsUntil;
    NSInteger _globalDelayMilliseconds;
    NSInteger _globalRunRepeatCount;
    NSInteger _globalStartHour;
    NSInteger _globalStartMinute;
    NSInteger _globalStartSecond;
    NSInteger _globalStopHour;
    NSInteger _globalStopMinute;
    NSInteger _globalStopSecond;
    NSInteger _currentGlobalRunCycle;
    NSInteger _taskRunResumeCycle;
    NSUInteger _taskRunResumeIndex;
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
    NSInteger _selectedColorPickSampleIndex;
    NSTimeInterval _networkTimeout;
    double _colorTolerance;
    NSTimer *_globalStartTimer;
    NSTimer *_globalStopTimer;
    IOHIDEventSystemClientRef _hardwareVolumeButtonClient;
    MPVolumeView *_volumeView;
    UISlider *_volumeSlider;
    double _matchThreshold;
    NSTimeInterval _actionDelay;
    NSInteger _actionRepeatCount;
    NSString *_currentTemplatePath;
    NSString *_actionDescription;
    NSString *_ocrTargetText;
    NSString *_networkURL;
    NSString *_networkContainsText;
    NSString *_networkFalseText;
    NSString *_networkPostBody;
    NSString *_networkPostExtraFields;
    NSString *_globalNetworkURL;
    NSString *_globalNetworkContainsText;
    NSString *_globalNetworkFalseText;
    NSMutableArray<NSDictionary *> *_targetColorSamples;
    NSMutableArray<NSDictionary *> *_pendingColorPickSamples;
    AnClickActionMode _actionMode;
    AnClickActionMode _imageActionMode;
    AnClickOCRMode _ocrMode;
    AnClickOCRMatchMode _ocrMatchMode;
    UIWindow *_pointPickHostWindow;
}

- (UIColor *)themeHighlightColor {
    return [UIColor colorWithRed:0.94 green:0.64 blue:0.23 alpha:1.0];
}

- (UIColor *)themePanelDarkColor {
    return [UIColor colorWithRed:0.06 green:0.06 blue:0.05 alpha:1.0];
}

- (NSString *)toolDisplayName {
    return @"安姐连点器v1.0";
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
            nil];
}

- (dispatch_queue_t)diskIOQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.anclick.disk-io", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

- (void)installDarkBlurInView:(UIView *)view cornerRadius:(CGFloat)cornerRadius {
    if (!view) {
        return;
    }

    [[view viewWithTag:AnClickBackdropBlurViewTag] removeFromSuperview];
    view.backgroundColor = UIColor.clearColor;
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.tag = AnClickBackdropBlurViewTag;
    blurView.frame = view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.userInteractionEnabled = NO;
    blurView.layer.cornerRadius = cornerRadius;
    blurView.clipsToBounds = YES;
    [view insertSubview:blurView atIndex:0];
}

- (void)applyFrostedRoundButtonStyle:(UIButton *)button {
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOffset = CGSizeMake(0, 2);
    button.layer.shadowRadius = 4.0;
    button.layer.shadowOpacity = 0.22;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
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
                                    AnClickVolumeShortcutDownNotification,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center,
                                    (__bridge const void *)self,
                                    AnClickVolumeDarwinNotificationCallback,
                                    AnClickVolumeShortcutUpNotification,
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self attachPanelWindowToActiveSceneIfNeeded];
        [self installVolumeShortcutControl];
        [self reclampPanelWindowForCurrentScreen];
        [self relayoutScreenInteractionOverlays];
        NSString *toastText = self->_toastLabel.text;
        [self layoutToastWithMessage:toastText.length > 0 ? toastText : @""];
        UIWindow *hostWindow = [self hostWindow];
        if (hostWindow) {
            NSString *hostToastText = self->_hostToastLabel.text;
            [self layoutHostToastWithMessage:hostToastText.length > 0 ? hostToastText : @"" inWindow:hostWindow];
        }
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.28 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self attachPanelWindowToActiveSceneIfNeeded];
        [self installVolumeShortcutControl];
        [self reclampPanelWindowForCurrentScreen];
        [self relayoutScreenInteractionOverlays];
    });
}

- (void)buildPanel {
    CGSize initialPanelSize = [self expandedPanelSizeForEditorVisible:NO];
    CGFloat panelWidth = initialPanelSize.width;
    CGFloat panelHeight = initialPanelSize.height;
    _actionMode = AnClickActionModeNone;
    _selectedTaskIndex = -1;
    _draggingTaskIndex = -1;
    _revealedDeleteTaskIndex = -1;
    _taskReordering = NO;
    _imageUsesMatchPoint = YES;
    _ocrUsesMatchPoint = YES;
    _imageActionMode = AnClickActionModeTap;
    _ocrMode = AnClickOCRModeAppleVision;
    _ocrMatchMode = AnClickOCRMatchModeContains;
    _colorTolerance = 18.0;
    _matchThreshold = 0.80;
    _actionDelay = 0;
    _actionRepeatCount = 1;
    _globalDelayMilliseconds = 0;
    _globalRunRepeatCount = 1;
    _globalStartEnabled = NO;
    _globalStopEnabled = NO;
    _globalNetworkGateEnabled = NO;
    _networkRequestOnly = NO;
    _networkUsesPost = NO;
    _networkPostBodyUsesOCRResult = NO;
    _networkPostExtraFields = nil;
    _networkRetryForever = YES;
    _networkTimeout = 8.0;
    _globalStartHour = 8;
    _globalStartMinute = 0;
    _globalStartSecond = 0;
    _globalStopHour = 23;
    _globalStopMinute = 0;
    _globalStopSecond = 0;
    _currentGlobalRunCycle = 0;
    _taskRunActive = NO;
    _taskRunPausedForForeground = NO;
    _taskRunResumeInGlobalNetworkGate = NO;
    _taskRunResumeScheduled = NO;
    _taskRunResumeCycle = 0;
    _taskRunResumeIndex = 0;
    _volumeShortcutRegistered = NO;
    _hasObservedSystemVolume = NO;
    _volumeShortcutRunSuppressToasts = NO;
    _ignoreVolumeEventsUntil = 0;
    [self loadGlobalSettings];
    [self registerVolumeShortcutObserver];
    if (!_recordedSwipePoints) {
        _recordedSwipePoints = [NSMutableArray array];
    }
    if (!_taskItems) {
        _taskItems = [self savedCurrentTaskList];
    }

    _panelWindow = [[UIWindow alloc] initWithFrame:CGRectMake(8, 118, panelWidth, panelHeight)];
    [self attachPanelWindowToActiveSceneIfNeeded];
    _panelWindow.windowLevel = UIWindowLevelAlert + 1000;
    _panelWindow.backgroundColor = UIColor.clearColor;
    _panelWindow.hidden = NO;

    UIViewController *controller = [[UIViewController alloc] init];
    _panelWindow.rootViewController = controller;
    [self installVolumeShortcutControl];

    _collapsedButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _collapsedButton.frame = CGRectMake(0, 0, 48, 48);
    _collapsedButton.backgroundColor = [[self themePanelDarkColor] colorWithAlphaComponent:0.92];
    _collapsedButton.layer.cornerRadius = 6;
    _collapsedButton.layer.borderWidth = 1;
    _collapsedButton.layer.borderColor = [[self themeHighlightColor] colorWithAlphaComponent:0.82].CGColor;
    _collapsedButton.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    [_collapsedButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [_collapsedButton addTarget:self action:@selector(handleCollapsedTap) forControlEvents:UIControlEventTouchUpInside];
    [controller.view addSubview:_collapsedButton];

    UILongPressGestureRecognizer *collapsedLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleCollapsedLongPress:)];
    collapsedLongPress.minimumPressDuration = 0.45;
    [_collapsedButton addGestureRecognizer:collapsedLongPress];
    UIPanGestureRecognizer *collapsedPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    collapsedPan.delegate = self;
    [_collapsedButton addGestureRecognizer:collapsedPan];

    _panelView = [[UIView alloc] initWithFrame:_panelWindow.bounds];
    [self installDarkBlurInView:_panelView cornerRadius:12.0];
    _panelView.layer.cornerRadius = 12.0;
    _panelView.layer.borderWidth = 1.0;
    _panelView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;
    _panelView.layer.shadowColor = UIColor.blackColor.CGColor;
    _panelView.layer.shadowOpacity = 0.60;
    _panelView.layer.shadowRadius = 24.0;
    _panelView.layer.shadowOffset = CGSizeMake(0, 12);
    [controller.view addSubview:_panelView];

    UIPanGestureRecognizer *panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    panelPan.delegate = self;
    [_panelView addGestureRecognizer:panelPan];
    UITapGestureRecognizer *keyboardDismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelTapToDismissKeyboard:)];
    keyboardDismissTap.cancelsTouchesInView = NO;
    [_panelView addGestureRecognizer:keyboardDismissTap];

    CGFloat gap = 12.0;
    CGFloat modeWidth = floor((panelWidth - gap * 4.0) / 3.0);
    NSArray<NSString *> *modeTitles = @[@"点击", @"双击", @"长按", @"滑动", @"识图", @"识字", @"识色", @"网络", @"录制"];
    NSArray<NSNumber *> *modeTags = @[
        @(AnClickActionModeTap),
        @(AnClickActionModeDoubleTap),
        @(AnClickActionModeLongPress),
        @(AnClickActionModeSwipe),
        @(AnClickActionModeImage),
        @(AnClickActionModeOCR),
        @(AnClickActionModeColor),
        @(AnClickActionModeNetwork),
        @(AnClickActionModeMacro),
    ];
    NSMutableArray<UIButton *> *modeButtons = [NSMutableArray array];
    for (NSUInteger i = 0; i < modeTitles.count; i++) {
        UIButton *button = [self panelButtonWithTitle:modeTitles[i] action:@selector(selectActionMode:)];
        button.tag = [modeTags[i] integerValue];
        NSUInteger row = i / 3;
        NSUInteger column = i % 3;
        button.frame = CGRectMake(gap + (modeWidth + gap) * column, 8 + row * 36, modeWidth, 30);
        [_panelView addSubview:button];
        [modeButtons addObject:button];
    }
    _modeButtons = [modeButtons copy];
    [self refreshModeButtons];

    CGFloat buttonWidth = floor((panelWidth - gap * 5.0) / 4.0);
    _captureButton = [self panelButtonWithTitle:@"截图" action:@selector(beginTemplateCapture)];
    _captureButton.frame = CGRectMake(gap, 120, buttonWidth, 32);
    [_panelView addSubview:_captureButton];

    _playButton = [self panelButtonWithTitle:@"识别" action:@selector(handleSecondaryConfigButton)];
    _playButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 120, buttonWidth, 32);
    [_panelView addSubview:_playButton];

    _pickPointButton = [self panelButtonWithTitle:@"取点" action:@selector(beginPointPicking)];
    _pickPointButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 120, buttonWidth, 32);
    [_panelView addSubview:_pickPointButton];

    _runManualButton = [self panelButtonWithTitle:@"执行" action:@selector(runManualAction)];
    _runManualButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 120, buttonWidth, 32);
    [_panelView addSubview:_runManualButton];

    _recordSwipeButton = [self panelButtonWithTitle:@"点击" action:@selector(selectImageActionMode:)];
    _recordSwipeButton.tag = AnClickActionModeTap;
    _recordSwipeButton.frame = CGRectMake(gap, 158, buttonWidth, 32);
    [_panelView addSubview:_recordSwipeButton];

    _previewSwipeButton = [self panelButtonWithTitle:@"双击" action:@selector(selectImageActionMode:)];
    _previewSwipeButton.tag = AnClickActionModeDoubleTap;
    _previewSwipeButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 158, buttonWidth, 32);
    [_panelView addSubview:_previewSwipeButton];

    _clearActionButton = [self panelButtonWithTitle:@"长按" action:@selector(selectImageActionMode:)];
    _clearActionButton.tag = AnClickActionModeLongPress;
    _clearActionButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 158, buttonWidth, 32);
    [_panelView addSubview:_clearActionButton];

    _testButton = [self panelButtonWithTitle:@"次+" action:@selector(increaseActionRepeatCount)];
    _testButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 158, buttonWidth, 32);
    [_panelView addSubview:_testButton];

    _addTaskButton = [self panelButtonWithTitle:@"＋0" action:@selector(addTaskFromCurrentConfig)];
    _addTaskButton.frame = CGRectMake(gap, 8, buttonWidth, 38);
    [_panelView addSubview:_addTaskButton];

    _deleteTaskButton = [self panelButtonWithTitle:@"删除" action:@selector(deleteLastTask)];
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

    _globalSettingsButton = [self panelButtonWithTitle:@"⚙" action:@selector(showGlobalSettings)];
    _globalSettingsButton.frame = CGRectMake(10, 8, 34, 34);
    [_panelView addSubview:_globalSettingsButton];

    _saveTaskButton = [self panelButtonWithTitle:@"保存" action:@selector(saveSelectedTaskFromCurrentConfig)];
    _saveTaskButton.frame = CGRectMake(gap, 120, buttonWidth, 34);
    [_panelView addSubview:_saveTaskButton];

    _imageActionButton = [self panelButtonWithTitle:@"网络" action:@selector(selectImageActionMode:)];
    _imageActionButton.tag = AnClickActionModeNetwork;
    _imageActionButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 196, buttonWidth, 32);
    [_panelView addSubview:_imageActionButton];

    _ocrContainsMatchModeButton = [self panelButtonWithTitle:@"包含匹配" action:@selector(selectOCRMatchMode:)];
    _ocrContainsMatchModeButton.tag = AnClickOCRMatchModeContains;
    _ocrContainsMatchModeButton.frame = CGRectMake(gap, 196, buttonWidth, 32);
    [_panelView addSubview:_ocrContainsMatchModeButton];

    _ocrRegexMatchModeButton = [self panelButtonWithTitle:@"正则匹配" action:@selector(selectOCRMatchMode:)];
    _ocrRegexMatchModeButton.tag = AnClickOCRMatchModeRegex;
    _ocrRegexMatchModeButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 196, buttonWidth, 32);
    [_panelView addSubview:_ocrRegexMatchModeButton];

    _networkRequestModeButton = [self panelButtonWithTitle:@"返回判断" action:@selector(toggleNetworkRequestMode)];
    _networkRequestModeButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 196, buttonWidth, 32);
    [_panelView addSubview:_networkRequestModeButton];

    _networkMethodButton = [self panelButtonWithTitle:@"GET" action:@selector(toggleNetworkMethod)];
    _networkMethodButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 196, buttonWidth, 32);
    [_panelView addSubview:_networkMethodButton];

    _networkPostCustomButton = [self panelButtonWithTitle:@"自定义内容" action:@selector(selectNetworkPostBodySource:)];
    _networkPostCustomButton.tag = 0;
    _networkPostCustomButton.frame = CGRectMake(gap, 234, buttonWidth, 32);
    [_panelView addSubview:_networkPostCustomButton];

    _networkPostOCRResultButton = [self panelButtonWithTitle:@"键值JSON" action:@selector(selectNetworkPostBodySource:)];
    _networkPostOCRResultButton.tag = 1;
    _networkPostOCRResultButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 234, buttonWidth, 32);
    [_panelView addSubview:_networkPostOCRResultButton];

    _networkRetryModeButton = [self panelButtonWithTitle:@"一直判断" action:@selector(toggleNetworkRetryMode)];
    _networkRetryModeButton.frame = CGRectMake(gap, 234, buttonWidth, 32);
    [_panelView addSubview:_networkRetryModeButton];

    _previewActionButton = [self panelButtonWithTitle:@"预览" action:@selector(previewCurrentAction)];
    _previewActionButton.frame = CGRectMake(gap, 234, buttonWidth, 32);
    [_panelView addSubview:_previewActionButton];

    _swipeRecordButton = [self panelButtonWithTitle:@"录制" action:@selector(beginSwipeRecording)];
    _swipeRecordButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 234, buttonWidth, 32);
    [_panelView addSubview:_swipeRecordButton];

    _macroRecordButton = [self panelButtonWithTitle:@"开始录制" action:@selector(toggleMacroRecording)];
    _macroRecordButton.frame = CGRectMake(gap, 272, buttonWidth, 32);
    [_panelView addSubview:_macroRecordButton];

    _macroPlayButton = [self panelButtonWithTitle:@"回放录制" action:@selector(playRecordedMacro)];
    _macroPlayButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 272, buttonWidth, 32);
    [_panelView addSubview:_macroPlayButton];

    _editorBackButton = [self panelButtonWithTitle:@"返回" action:@selector(showTaskHome)];
    _editorBackButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 120, buttonWidth, 34);
    [_panelView addSubview:_editorBackButton];

    _cancelEditButton = [self panelButtonWithTitle:@"取消" action:@selector(showTaskHome)];
    _cancelEditButton.frame = CGRectMake(gap, 158, buttonWidth, 34);
    [_panelView addSubview:_cancelEditButton];

    _toolTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 8, panelWidth - 100, 22)];
    _toolTitleLabel.text = [self toolDisplayName];
    _toolTitleLabel.textColor = UIColor.whiteColor;
    _toolTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    _toolTitleLabel.adjustsFontSizeToFitWidth = YES;
    _toolTitleLabel.minimumScaleFactor = 0.68;
    _toolTitleLabel.textAlignment = NSTextAlignmentCenter;
    [_panelView addSubview:_toolTitleLabel];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 52, panelWidth - 16, 24)];
    _statusLabel.text = @"待机";
    _statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.78];
    _statusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _statusLabel.adjustsFontSizeToFitWidth = YES;
    _statusLabel.minimumScaleFactor = 0.6;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [_panelView addSubview:_statusLabel];

    _editorContentScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _editorContentScrollView.backgroundColor = UIColor.clearColor;
    _editorContentScrollView.alwaysBounceVertical = YES;
    _editorContentScrollView.showsVerticalScrollIndicator = YES;
    _editorContentScrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _editorContentScrollView.hidden = YES;
    [_panelView addSubview:_editorContentScrollView];

    _editorTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _editorTitleLabel.textColor = UIColor.whiteColor;
    _editorTitleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    _editorTitleLabel.textAlignment = NSTextAlignmentLeft;
    _editorTitleLabel.adjustsFontSizeToFitWidth = YES;
    _editorTitleLabel.minimumScaleFactor = 0.72;
    [_panelView addSubview:_editorTitleLabel];

    _descriptionCaptionLabel = [self configCaptionLabelWithText:@"动作描述"];
    [_panelView addSubview:_descriptionCaptionLabel];
    _primaryConfigLabel = [self configCaptionLabelWithText:@""];
    [_panelView addSubview:_primaryConfigLabel];
    _secondaryConfigLabel = [self configCaptionLabelWithText:@""];
    [_panelView addSubview:_secondaryConfigLabel];
    _tertiaryConfigLabel = [self configCaptionLabelWithText:@""];
    [_panelView addSubview:_tertiaryConfigLabel];
    _thresholdCaptionLabel = [self configCaptionLabelWithText:@"匹配阈值（0.0~1.0）"];
    [_panelView addSubview:_thresholdCaptionLabel];
    _delayCaptionLabel = [self configCaptionLabelWithText:@"延时执行（秒）"];
    [_panelView addSubview:_delayCaptionLabel];
    _repeatCaptionLabel = [self configCaptionLabelWithText:@"执行次数（次数）"];
    [_panelView addSubview:_repeatCaptionLabel];

    _descriptionField = [[UITextField alloc] initWithFrame:CGRectMake(8, 142, panelWidth - 16, 34)];
    _descriptionField.placeholder = @"备注/动作说明";
    [self applyObsidianInputStyleToField:_descriptionField placeholder:@"备注/动作说明" monospaced:NO];
    [self configureConfigTextField:_descriptionField];
    [_descriptionField addTarget:self action:@selector(actionDescriptionChanged:) forControlEvents:UIControlEventEditingChanged];
    [_panelView addSubview:_descriptionField];

    _delayField = [self configTextFieldWithPlaceholder:@"延时(秒)"];
    _delayField.keyboardType = UIKeyboardTypeDecimalPad;
    [_delayField addTarget:self action:@selector(actionTimingChanged:) forControlEvents:UIControlEventEditingChanged];
    [_delayField addTarget:self action:@selector(actionTimingEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [_panelView addSubview:_delayField];

    _repeatField = [self configTextFieldWithPlaceholder:@"次数"];
    _repeatField.keyboardType = UIKeyboardTypeNumberPad;
    [_repeatField addTarget:self action:@selector(actionTimingChanged:) forControlEvents:UIControlEventEditingChanged];
    [_repeatField addTarget:self action:@selector(actionTimingEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [_panelView addSubview:_repeatField];

    _thresholdField = [self configTextFieldWithPlaceholder:@"0.80"];
    _thresholdField.keyboardType = UIKeyboardTypeDecimalPad;
    [_thresholdField addTarget:self action:@selector(actionThresholdChanged:) forControlEvents:UIControlEventEditingChanged];
    [_thresholdField addTarget:self action:@selector(actionThresholdEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [_panelView addSubview:_thresholdField];

    _ocrTargetField = [[UITextField alloc] initWithFrame:CGRectZero];
    _ocrTargetField.placeholder = @"目标文字";
    _ocrTargetField.keyboardType = UIKeyboardTypeDefault;
    _ocrTargetField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _ocrTargetField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self applyObsidianInputStyleToField:_ocrTargetField placeholder:@"目标文字" monospaced:NO];
    [self configureConfigTextField:_ocrTargetField];
    [_ocrTargetField addTarget:self action:@selector(ocrTargetChanged:) forControlEvents:UIControlEventEditingChanged];
    [_ocrTargetField addTarget:self action:@selector(ocrTargetEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [_panelView addSubview:_ocrTargetField];

    _networkURLField = [[UITextField alloc] initWithFrame:CGRectZero];
    _networkURLField.placeholder = @"https://example.com";
    _networkURLField.keyboardType = UIKeyboardTypeURL;
    _networkURLField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _networkURLField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self applyObsidianInputStyleToField:_networkURLField placeholder:@"https://example.com" monospaced:NO];
    [self configureConfigTextField:_networkURLField];
    [_networkURLField addTarget:self action:@selector(networkFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [_networkURLField addTarget:self action:@selector(networkFieldEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [_panelView addSubview:_networkURLField];

    _networkContainsField = [[UITextField alloc] initWithFrame:CGRectZero];
    _networkContainsField.placeholder = @"例：成功 / true";
    _networkContainsField.keyboardType = UIKeyboardTypeDefault;
    _networkContainsField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _networkContainsField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self applyObsidianInputStyleToField:_networkContainsField placeholder:@"例：成功 / true" monospaced:NO];
    [self configureConfigTextField:_networkContainsField];
    [_networkContainsField addTarget:self action:@selector(networkFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [_networkContainsField addTarget:self action:@selector(networkFieldEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [_panelView addSubview:_networkContainsField];

    _networkFalseField = [[UITextField alloc] initWithFrame:CGRectZero];
    _networkFalseField.placeholder = @"例：失败 / false";
    _networkFalseField.keyboardType = UIKeyboardTypeDefault;
    _networkFalseField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _networkFalseField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self applyObsidianInputStyleToField:_networkFalseField placeholder:@"例：失败 / false" monospaced:NO];
    [self configureConfigTextField:_networkFalseField];
    [_networkFalseField addTarget:self action:@selector(networkFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [_networkFalseField addTarget:self action:@selector(networkFieldEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [_panelView addSubview:_networkFalseField];

    _networkPostBodyField = [[UITextField alloc] initWithFrame:CGRectZero];
    _networkPostBodyField.placeholder = @"POST参数 JSON/表单";
    _networkPostBodyField.keyboardType = UIKeyboardTypeDefault;
    _networkPostBodyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _networkPostBodyField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self applyObsidianInputStyleToField:_networkPostBodyField placeholder:@"POST参数 JSON/表单" monospaced:NO];
    [self configureConfigTextField:_networkPostBodyField];
    [_networkPostBodyField addTarget:self action:@selector(networkFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [_networkPostBodyField addTarget:self action:@selector(networkFieldEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [_panelView addSubview:_networkPostBodyField];

    _networkPostExtraFieldsField = [[UITextField alloc] initWithFrame:CGRectZero];
    _networkPostExtraFieldsField.keyboardType = UIKeyboardTypeDefault;
    _networkPostExtraFieldsField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _networkPostExtraFieldsField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self applyObsidianInputStyleToField:_networkPostExtraFieldsField placeholder:@"键=值 例content={{result}}&to_user=@all" monospaced:NO];
    [self configureConfigTextField:_networkPostExtraFieldsField];
    [_networkPostExtraFieldsField addTarget:self action:@selector(networkFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [_networkPostExtraFieldsField addTarget:self action:@selector(networkFieldEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [_panelView addSubview:_networkPostExtraFieldsField];

    _taskListView = [[UIScrollView alloc] initWithFrame:CGRectMake(8, 84, panelWidth - 16, panelHeight - 92)];
    _taskListView.backgroundColor = [[self themePanelDarkColor] colorWithAlphaComponent:0.92];
    _taskListView.layer.cornerRadius = 4;
    _taskListView.layer.borderWidth = 1;
    _taskListView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    [_panelView addSubview:_taskListView];

    _previewView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 296, panelWidth - 16, MAX(70.0, panelHeight - 304))];
    _previewView.contentMode = UIViewContentModeScaleAspectFit;
    _previewView.clipsToBounds = YES;
    _previewView.backgroundColor = [self themePanelDarkColor];
    _previewView.layer.cornerRadius = 4;
    _previewView.layer.borderWidth = 1;
    _previewView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    _previewView.hidden = YES;
    [_panelView addSubview:_previewView];

    _colorPreviewView = [[UIView alloc] initWithFrame:CGRectZero];
    _colorPreviewView.hidden = YES;
    _colorPreviewView.layer.cornerRadius = 6;
    _colorPreviewView.layer.borderWidth = 1;
    _colorPreviewView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.24].CGColor;
    [_panelView addSubview:_colorPreviewView];
    [self installEditorContentSubviewsInScrollView];
    [self refreshTemplatePreview];
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
    button.layer.cornerRadius = 8;
    button.layer.masksToBounds = NO;

    if (selected) {
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.25];
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [[self themeHighlightColor] colorWithAlphaComponent:0.8].CGColor;
        button.layer.shadowColor = [self themeHighlightColor].CGColor;
        button.layer.shadowOffset = CGSizeMake(0, 0);
        button.layer.shadowRadius = 8.0;
        button.layer.shadowOpacity = 0.4;
        [button setTitleColor:[UIColor colorWithRed:1.0 green:0.82 blue:0.43 alpha:1.0] forState:UIControlStateNormal];
    } else {
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
        button.layer.shadowColor = UIColor.blackColor.CGColor;
        button.layer.shadowOffset = CGSizeMake(2.0, 4.0);
        button.layer.shadowRadius = 5.0;
        button.layer.shadowOpacity = 0.5;
        [button setTitleColor:[UIColor colorWithWhite:1 alpha:0.85] forState:UIControlStateNormal];
    }

    [self updateButtonShadowPath:button];
}

- (void)setStyledPlaceholder:(NSString *)placeholder forField:(UITextField *)field alpha:(CGFloat)alpha {
    if (!field) {
        return;
    }
    field.placeholder = placeholder;
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @""
                                                                  attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:alpha]}];
}

- (void)applyObsidianInputStyleToField:(UITextField *)field placeholder:(NSString *)placeholder monospaced:(BOOL)monospaced {
    field.textColor = monospaced ? [self themeHighlightColor] : UIColor.whiteColor;
    field.tintColor = [self themeHighlightColor];
    field.font = monospaced
        ? [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightBold]
        : [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    field.backgroundColor = [self themePanelDarkColor];
    field.layer.cornerRadius = 6;
    field.layer.borderWidth = 1.0;
    field.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.8].CGColor;
    field.layer.shadowColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    field.layer.shadowOffset = CGSizeMake(0, 1);
    field.layer.shadowRadius = 1.0;
    field.layer.shadowOpacity = 0.18;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    [self setStyledPlaceholder:placeholder forField:field alpha:0.25];
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
            button.tintColor = UIColor.whiteColor;
            button.imageView.contentMode = UIViewContentModeScaleAspectFit;
            return;
        }
    }

    [button setTitle:fallbackTitle forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
}

- (UIButton *)panelButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
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

- (UILabel *)configCaptionLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.textColor = [UIColor colorWithWhite:1 alpha:0.62];
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
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

- (void)ensureToastWindow {
    CGRect bounds = UIScreen.mainScreen.bounds;
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

- (void)showVolumeShortcutToast:(NSString *)message {
    CFTimeInterval holdUntil = CACurrentMediaTime() + 0.55;
    _toastDeferNonVolumeUntil = MAX(_toastDeferNonVolumeUntil, holdUntil);
    [self showToast:message];
}

- (CGSize)expandedPanelSize {
    return [self expandedPanelSizeForEditorVisible:_taskEditorVisible];
}

- (CGSize)expandedPanelSizeForEditorVisible:(BOOL)editorVisible {
    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    BOOL landscape = screenSize.width > screenSize.height;
    CGFloat widthLimit = landscape ? (editorVisible ? 430.0 : 380.0) : 340.0;
    CGFloat width = MIN(widthLimit, screenSize.width - 10.0);
    CGFloat verticalPadding = landscape ? 52.0 : 60.0;
    CGFloat availableHeight = screenSize.height - verticalPadding;
    CGFloat editorPreferredHeight = landscape ? availableHeight : 700.0;
    CGFloat editorMinHeight = landscape ? 300.0 : 620.0;
    CGFloat preferredHeight = MIN(editorVisible ? editorPreferredHeight : 420.0, availableHeight);
    CGFloat minHeight = MIN(editorVisible ? editorMinHeight : 340.0, availableHeight);
    return CGSizeMake(width, MAX(minHeight, preferredHeight));
}

- (CGRect)clampedPanelFrame:(CGRect)frame {
    CGRect bounds = UIScreen.mainScreen.bounds;
    UIEdgeInsets safeInsets = [self panelSafeAreaInsets];
    CGFloat minX = MAX(4.0, safeInsets.left + 4.0);
    CGFloat minY = MAX(24.0, safeInsets.top + 4.0);
    CGFloat maxX = bounds.size.width - frame.size.width - MAX(4.0, safeInsets.right + 4.0);
    CGFloat maxY = bounds.size.height - frame.size.height - MAX(4.0, safeInsets.bottom + 4.0);
    frame.origin.x = MIN(MAX(frame.origin.x, minX), MAX(minX, maxX));
    frame.origin.y = MIN(MAX(frame.origin.y, minY), MAX(minY, maxY));
    return frame;
}

- (CGRect)clampedFloatingFrame:(CGRect)frame {
    CGRect bounds = UIScreen.mainScreen.bounds;
    UIEdgeInsets safeInsets = [self panelSafeAreaInsets];
    CGFloat minX = MAX(6.0, safeInsets.left + 6.0);
    CGFloat minY = MAX(6.0, safeInsets.top + 8.0);
    CGFloat maxX = bounds.size.width - frame.size.width - MAX(6.0, safeInsets.right + 6.0);
    CGFloat maxY = bounds.size.height - frame.size.height - MAX(6.0, safeInsets.bottom + 8.0);
    frame.origin.x = MIN(MAX(frame.origin.x, minX), MAX(minX, maxX));
    frame.origin.y = MIN(MAX(frame.origin.y, minY), MAX(minY, maxY));
    return frame;
}

- (UIEdgeInsets)panelSafeAreaInsets {
    UIEdgeInsets insets = UIEdgeInsetsZero;
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
    insets.top = MAX(insets.top, statusHeight);
    if (insets.top > 0.0) {
        insets.top += 6.0;
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

    CGSize screenSize = view ? view.bounds.size : UIScreen.mainScreen.bounds.size;
    if (screenSize.width <= 0.0 || screenSize.height <= 0.0) {
        screenSize = UIScreen.mainScreen.bounds.size;
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

- (CGFloat)minimumZoomScaleForImageSize:(CGSize)imageSize inBoundsSize:(CGSize)boundsSize {
    CGFloat width = MAX(1.0, imageSize.width);
    CGFloat height = MAX(1.0, imageSize.height);
    CGFloat boundWidth = MAX(1.0, boundsSize.width);
    CGFloat boundHeight = MAX(1.0, boundsSize.height);
    CGFloat minZoom = MIN(boundWidth / width, boundHeight / height);
    return MIN(MAX(minZoom, 0.25), 1.0);
}

- (void)centerCaptureImageContent {
    if (!_captureScrollView || !_captureImageView) {
        return;
    }
    CGSize boundsSize = _captureScrollView.bounds.size;
    CGRect frame = _captureImageView.frame;
    frame.origin.x = frame.size.width < boundsSize.width ? (boundsSize.width - frame.size.width) * 0.5 : 0.0;
    frame.origin.y = frame.size.height < boundsSize.height ? (boundsSize.height - frame.size.height) * 0.5 : 0.0;
    _captureImageView.frame = frame;
}

- (void)updateCaptureZoomForCurrentBounds {
    if (!_captureScrollView || !_captureSnapshot) {
        return;
    }
    CGFloat minZoom = [self minimumZoomScaleForImageSize:_captureSnapshot.size inBoundsSize:_captureScrollView.bounds.size];
    _captureScrollView.minimumZoomScale = minZoom;
    if (_captureScrollView.zoomScale < minZoom) {
        _captureScrollView.zoomScale = minZoom;
    }
    [self centerCaptureImageContent];
}

- (void)centerPointPickImageContent {
    if (!_pointPickScrollView || !_pointPickImageView) {
        return;
    }
    CGSize boundsSize = _pointPickScrollView.bounds.size;
    CGRect frame = _pointPickImageView.frame;
    frame.origin.x = frame.size.width < boundsSize.width ? (boundsSize.width - frame.size.width) * 0.5 : 0.0;
    frame.origin.y = frame.size.height < boundsSize.height ? (boundsSize.height - frame.size.height) * 0.5 : 0.0;
    _pointPickImageView.frame = frame;
}

- (void)updatePointPickZoomForCurrentBounds {
    if (!_pointPickScrollView || !_pointPickSnapshot) {
        return;
    }
    CGFloat minZoom = [self minimumZoomScaleForImageSize:_pointPickSnapshot.size inBoundsSize:_pointPickScrollView.bounds.size];
    _pointPickScrollView.minimumZoomScale = minZoom;
    if (_pointPickScrollView.zoomScale < minZoom) {
        _pointPickScrollView.zoomScale = minZoom;
    }
    [self centerPointPickImageContent];
}

- (void)updateColorPickZoomForCurrentBounds {
    if (!_colorPickScrollView || !_colorPickImage) {
        return;
    }

    CGFloat minZoom = [self minimumZoomScaleForImageSize:_colorPickImage.size inBoundsSize:_colorPickScrollView.bounds.size];
    _colorPickScrollView.minimumZoomScale = minZoom;
    if (_colorPickScrollView.zoomScale < minZoom) {
        _colorPickScrollView.zoomScale = minZoom;
    }
    [self centerColorPickImageContent];
}

- (void)relayoutScreenInteractionOverlays {
    CGRect screenBounds = UIScreen.mainScreen.bounds;
    if (_captureOverlay) {
        _captureOverlay.frame = screenBounds;
        _captureScrollView.frame = _captureOverlay.bounds;
        [self updateCaptureZoomForCurrentBounds];
        [self layoutCaptureActionButtonsAvoidingSelection];
    }
    if (_pointPickWindow) {
        _pointPickWindow.frame = screenBounds;
        _pointPickWindow.rootViewController.view.frame = _pointPickWindow.bounds;
        _pointPickOverlay.frame = _pointPickWindow.rootViewController.view.bounds;
        _pointPickScrollView.frame = _pointPickOverlay.bounds;
        [self updatePointPickZoomForCurrentBounds];
        [self updatePointPickCursor];
        if (_actionMode == AnClickActionModeSwipe && _hasManualSwipeAnchor) {
            [self showPointPickSwipeStartMarker];
        }
    }
    if (_colorPickWindow) {
        _colorPickWindow.frame = screenBounds;
        UIView *root = _colorPickWindow.rootViewController.view;
        root.frame = _colorPickWindow.bounds;
        _colorPickScrollView.frame = root.bounds;
        [self updateColorPickZoomForCurrentBounds];
        [self layoutColorPickToolbar];
    }
}

- (void)reclampPanelWindowForCurrentScreen {
    if (!_panelWindow) {
        return;
    }
    CGRect frame = _panelWindow.frame;
    if (_panelExpanded) {
        frame.size = [self expandedPanelSize];
        _panelWindow.frame = [self clampedPanelFrame:frame];
        _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
        _panelView.frame = _panelWindow.bounds;
        if (_taskEditorVisible) {
            [self refreshEditorConfigControls];
        } else {
            [self layoutTaskHomeControls];
            [self refreshTaskList];
        }
        return;
    }

    frame.size = CGSizeMake(48.0, 48.0);
    _panelWindow.frame = [self clampedFloatingFrame:frame];
    _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
    _collapsedButton.frame = _panelWindow.bounds;
}

- (void)refreshCollapsedButtonTitle {
    if ([AnClickRecorder shared].isRecording) {
        _collapsedButton.backgroundColor = [UIColor colorWithRed:0.84 green:0.12 blue:0.10 alpha:0.94];
        _collapsedButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.34 blue:0.30 alpha:0.90].CGColor;
        [self setCenteredIconForButton:_collapsedButton systemName:@"stop.fill" fallbackTitle:@"■" fontSize:20];
        return;
    }
    if (_taskRunActive) {
        _collapsedButton.backgroundColor = [UIColor colorWithRed:0.84 green:0.12 blue:0.10 alpha:0.94];
        _collapsedButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.34 blue:0.30 alpha:0.90].CGColor;
        [self setCenteredIconForButton:_collapsedButton systemName:@"stop.fill" fallbackTitle:@"■" fontSize:20];
        return;
    }
    _collapsedButton.backgroundColor = [[self themePanelDarkColor] colorWithAlphaComponent:0.92];
    _collapsedButton.layer.borderColor = [[self themeHighlightColor] colorWithAlphaComponent:0.82].CGColor;
    [self setCenteredIconForButton:_collapsedButton systemName:@"hand.tap.fill" fallbackTitle:@"点" fontSize:22];
}

- (void)setTaskEditorVisible:(BOOL)visible {
    _taskEditorVisible = visible;
    if (_panelExpanded && _panelWindow && _panelView) {
        CGRect frame = _panelWindow.frame;
        frame.size = [self expandedPanelSizeForEditorVisible:visible];
        _panelWindow.frame = [self clampedPanelFrame:frame];
        _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
        _panelView.frame = _panelWindow.bounds;
    }

    for (UIButton *button in _modeButtons) {
        button.hidden = !visible;
    }
    _toolTitleLabel.hidden = NO;
    _editorTitleLabel.hidden = !visible;
    _descriptionCaptionLabel.hidden = !visible;
    _primaryConfigLabel.hidden = YES;
    _secondaryConfigLabel.hidden = YES;
    _tertiaryConfigLabel.hidden = YES;
    _thresholdCaptionLabel.hidden = YES;
    _delayCaptionLabel.hidden = YES;
    _repeatCaptionLabel.hidden = YES;
    _captureButton.hidden = YES;
    _playButton.hidden = YES;
    _pickPointButton.hidden = YES;
    _runManualButton.hidden = YES;
    _recordSwipeButton.hidden = YES;
    _previewSwipeButton.hidden = YES;
    _clearActionButton.hidden = YES;
    _testButton.hidden = YES;
    _saveTaskButton.hidden = !visible;
    _editorBackButton.hidden = !visible;
    _cancelEditButton.hidden = !visible;
    _imageActionButton.hidden = YES;
    _ocrContainsMatchModeButton.hidden = YES;
    _ocrRegexMatchModeButton.hidden = YES;
    _networkRequestModeButton.hidden = YES;
    _networkMethodButton.hidden = YES;
    _networkRetryModeButton.hidden = YES;
    _networkPostCustomButton.hidden = YES;
    _networkPostOCRResultButton.hidden = YES;
    _previewActionButton.hidden = YES;
    _swipeRecordButton.hidden = YES;
    _macroRecordButton.hidden = YES;
    _macroPlayButton.hidden = YES;
    _descriptionField.hidden = !visible;
    _thresholdField.hidden = YES;
    _delayField.hidden = YES;
    _repeatField.hidden = YES;
    _ocrTargetField.hidden = YES;
    _networkURLField.hidden = YES;
    _networkContainsField.hidden = YES;
    _networkFalseField.hidden = YES;
    _networkPostBodyField.hidden = YES;
    _networkPostExtraFieldsField.hidden = YES;
    _previewView.hidden = YES;
    _colorPreviewView.hidden = YES;
    _editorContentScrollView.hidden = !visible;
    if (!visible) {
        _editorContentScrollView.contentOffset = CGPointZero;
    }

    _addTaskButton.hidden = visible;
    _deleteTaskButton.hidden = visible;
    _runTasksButton.hidden = visible;
    _homeCloseButton.hidden = visible;
    _globalSettingsButton.hidden = visible;
    _collapseButton.hidden = NO;
    _taskListView.hidden = visible;
    if (visible) {
        [self hideGlobalSettings];
    }
    if (visible) {
        [self layoutEditorScaffold];
        [self refreshEditorConfigControls];
    } else {
        [self layoutTaskHomeControls];
    }
}

- (NSArray<UIView *> *)editorContentViews {
    UIView *views[] = {
        _descriptionCaptionLabel,
        _descriptionField,
        _primaryConfigLabel,
        _secondaryConfigLabel,
        _tertiaryConfigLabel,
        _thresholdCaptionLabel,
        _delayCaptionLabel,
        _repeatCaptionLabel,
        _captureButton,
        _playButton,
        _pickPointButton,
        _runManualButton,
        _recordSwipeButton,
        _previewSwipeButton,
        _clearActionButton,
        _testButton,
        _imageActionButton,
        _ocrContainsMatchModeButton,
        _ocrRegexMatchModeButton,
        _networkRequestModeButton,
        _networkMethodButton,
        _networkRetryModeButton,
        _networkPostCustomButton,
        _networkPostOCRResultButton,
        _previewActionButton,
        _swipeRecordButton,
        _macroRecordButton,
        _macroPlayButton,
        _delayField,
        _repeatField,
        _thresholdField,
        _ocrTargetField,
        _networkURLField,
        _networkContainsField,
        _networkFalseField,
        _networkPostBodyField,
        _networkPostExtraFieldsField,
        _previewView,
        _colorPreviewView,
    };
    NSMutableArray<UIView *> *result = [NSMutableArray array];
    NSUInteger count = sizeof(views) / sizeof(UIView *);
    for (NSUInteger i = 0; i < count; i++) {
        if (views[i]) {
            [result addObject:views[i]];
        }
    }
    return result;
}

- (void)installEditorContentSubviewsInScrollView {
    if (!_editorContentScrollView) {
        return;
    }

    for (UIView *view in [self editorContentViews]) {
        if (view.superview != _editorContentScrollView) {
            [_editorContentScrollView addSubview:view];
        }
    }
}

- (void)refreshEditorContentScrollSize {
    if (!_editorContentScrollView) {
        return;
    }

    CGFloat maxY = 0.0;
    for (UIView *view in [self editorContentViews]) {
        if (!view.hidden) {
            maxY = MAX(maxY, CGRectGetMaxY(view.frame));
        }
    }

    CGFloat contentHeight = MAX(_editorContentScrollView.bounds.size.height + 1.0, maxY + 18.0);
    _editorContentScrollView.contentSize = CGSizeMake(_editorContentScrollView.bounds.size.width, contentHeight);
    CGFloat maxOffsetY = MAX(0.0, contentHeight - _editorContentScrollView.bounds.size.height);
    if (_editorContentScrollView.contentOffset.y > maxOffsetY) {
        _editorContentScrollView.contentOffset = CGPointMake(_editorContentScrollView.contentOffset.x, maxOffsetY);
    }
}

- (void)layoutTaskHomeControls {
    if (!_panelView) {
        return;
    }

    CGFloat width = _panelView.bounds.size.width;
    CGFloat height = _panelView.bounds.size.height;
    CGFloat buttonSize = 46.0;
    CGFloat totalWidth = buttonSize * 4.0 + 26.0 * 3.0;
    CGFloat startX = MAX(12.0, (width - totalWidth) * 0.5);
    CGFloat buttonY = height - buttonSize - 14.0;
    [_panelView viewWithTag:8811].hidden = YES;

    [self setCenteredIconForButton:_addTaskButton systemName:@"plus" fallbackTitle:@"+" fontSize:27];
    [self setCenteredIconForButton:_deleteTaskButton systemName:@"minus" fallbackTitle:@"-" fontSize:27];
    [self setCenteredIconForButton:_collapseButton systemName:@"square.and.arrow.down.fill" fallbackTitle:@"存" fontSize:22];
    [self setCenteredIconForButton:_runTasksButton systemName:_taskRunActive ? @"stop.fill" : @"play.fill" fallbackTitle:_taskRunActive ? @"■" : @"▶" fontSize:24];
    NSArray<UIButton *> *toolbarButtons = @[_addTaskButton, _deleteTaskButton, _collapseButton, _runTasksButton];
    NSArray<UIColor *> *colors = @[
        [UIColor colorWithRed:0.02 green:0.50 blue:0.95 alpha:0.95],
        [UIColor colorWithRed:0.88 green:0.12 blue:0.10 alpha:0.95],
        [UIColor colorWithRed:0.68 green:0.24 blue:0.86 alpha:0.95],
        _taskRunActive ? [UIColor colorWithRed:0.84 green:0.12 blue:0.10 alpha:0.95] : [UIColor colorWithRed:0.12 green:0.74 blue:0.30 alpha:0.95],
    ];
    for (NSUInteger i = 0; i < toolbarButtons.count; i++) {
        UIButton *button = toolbarButtons[i];
        button.frame = CGRectMake(startX + (buttonSize + 26.0) * i, buttonY, buttonSize, buttonSize);
        button.layer.cornerRadius = buttonSize * 0.5;
        button.layer.borderWidth = 0;
        button.layer.shadowColor = UIColor.blackColor.CGColor;
        button.layer.shadowOffset = CGSizeMake(0, 4);
        button.layer.shadowRadius = 7.0;
        button.layer.shadowOpacity = 0.32;
        button.backgroundColor = colors[i];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.tintColor = UIColor.whiteColor;
        [self updateButtonShadowPath:button];
    }

    CGFloat closeSize = 32.0;
    [self setCenteredIconForButton:_homeCloseButton systemName:@"xmark" fallbackTitle:@"×" fontSize:17];
    _homeCloseButton.frame = CGRectMake(width - closeSize - 10.0, 6.0, closeSize, closeSize);
    _homeCloseButton.layer.cornerRadius = closeSize * 0.5;
    _homeCloseButton.layer.borderWidth = 0;
    _homeCloseButton.layer.shadowOpacity = 0;
    _homeCloseButton.backgroundColor = UIColor.clearColor;
    [_homeCloseButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _homeCloseButton.tintColor = UIColor.whiteColor;
    [self updateButtonShadowPath:_homeCloseButton];

    [self setCenteredIconForButton:_globalSettingsButton systemName:@"gearshape.fill" fallbackTitle:@"⚙" fontSize:17];
    _globalSettingsButton.frame = CGRectMake(10.0, 6.0, closeSize, closeSize);
    _globalSettingsButton.layer.cornerRadius = closeSize * 0.5;
    _globalSettingsButton.layer.borderWidth = 0;
    _globalSettingsButton.layer.shadowOpacity = 0;
    _globalSettingsButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    _globalSettingsButton.tintColor = UIColor.whiteColor;
    [_globalSettingsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self updateButtonShadowPath:_globalSettingsButton];

    _toolTitleLabel.hidden = NO;
    _toolTitleLabel.text = [self toolDisplayName];
    _toolTitleLabel.frame = CGRectMake(50, 7, width - closeSize - 84.0, 20);
    _toolTitleLabel.textColor = UIColor.whiteColor;
    _toolTitleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];

    _statusLabel.frame = CGRectMake(50, 28, width - closeSize - 84.0, 18);
    _statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.72];
    _statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _taskListView.frame = CGRectMake(10, 56, width - 20, MAX(80.0, buttonY - 64.0));
    if (_globalSettingsView) {
        _globalSettingsView.frame = _panelView.bounds;
        [_panelView bringSubviewToFront:_globalSettingsView];
    } else if (_functionMenuView) {
        _functionMenuView.frame = _panelView.bounds;
        [_panelView bringSubviewToFront:_functionMenuView];
    } else {
        [_panelView bringSubviewToFront:_globalSettingsButton];
        [_panelView bringSubviewToFront:_homeCloseButton];
    }
}

- (CGFloat)editorConfigTopY {
    BOOL compactHeight = _panelView && _panelView.bounds.size.height < 430.0;
    CGFloat captionHeight = compactHeight ? 18.0 : 20.0;
    CGFloat fieldHeight = compactHeight ? 36.0 : 40.0;
    return captionHeight + 2.0 + fieldHeight + (compactHeight ? 10.0 : 12.0);
}

- (void)layoutEditorScaffold {
    if (!_panelView) {
        return;
    }

    CGFloat width = _panelView.bounds.size.width;
    CGFloat height = _panelView.bounds.size.height;
    CGFloat side = 18.0;
    BOOL compactHeight = height < 430.0;
    CGFloat modeGap = compactHeight ? 5.0 : 6.0;
    CGFloat modeRowGap = compactHeight ? 4.0 : 5.0;
    CGFloat modeTopY = compactHeight ? 58.0 : 64.0;
    CGFloat modeButtonHeight = _modeButtons.count > 6 ? (compactHeight ? 28.0 : 30.0) : (compactHeight ? 30.0 : 34.0);
    NSUInteger modeColumns = 1;
    if (_modeButtons.count > 6) {
        modeColumns = (compactHeight && width >= 400.0) ? 5 : 4;
    } else {
        modeColumns = MAX((NSUInteger)1, _modeButtons.count);
    }
    NSUInteger modeRows = (_modeButtons.count + modeColumns - 1) / modeColumns;
    [self installEditorContentSubviewsInScrollView];

    [_editorBackButton setTitle:@"‹" forState:UIControlStateNormal];
    _editorBackButton.titleLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    CGFloat chromeButtonWidth = compactHeight ? 38.0 : 42.0;
    CGFloat chromeButtonHeight = compactHeight ? 36.0 : 40.0;
    CGFloat chromeButtonY = compactHeight ? 7.0 : 8.0;
    _editorBackButton.frame = CGRectMake(12, chromeButtonY, chromeButtonWidth, chromeButtonHeight);
    _editorBackButton.layer.cornerRadius = chromeButtonHeight * 0.5;
    _editorBackButton.layer.borderWidth = 0;
    _editorBackButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    _editorBackButton.layer.borderWidth = 1.0;
    _editorBackButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    [_editorBackButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self updateButtonShadowPath:_editorBackButton];

    [self setCenteredIconForButton:_collapseButton systemName:@"xmark" fallbackTitle:@"×" fontSize:22];
    _collapseButton.frame = CGRectMake(width - chromeButtonWidth - 12.0, chromeButtonY, chromeButtonWidth, chromeButtonHeight);
    _collapseButton.layer.cornerRadius = chromeButtonHeight * 0.5;
    _collapseButton.layer.borderWidth = 0;
    _collapseButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    _collapseButton.layer.borderWidth = 1.0;
    _collapseButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    [_collapseButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _collapseButton.tintColor = UIColor.whiteColor;
    [self updateButtonShadowPath:_collapseButton];

    _toolTitleLabel.hidden = NO;
    _toolTitleLabel.text = [self toolDisplayName];
    _toolTitleLabel.frame = CGRectMake(66, compactHeight ? 6.0 : 7.0, width - 132, 17);
    _toolTitleLabel.textColor = [UIColor colorWithWhite:1 alpha:0.70];
    _toolTitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];

    _editorTitleLabel.text = (_actionMode == AnClickActionModeNone) ? @"选择动作" : [self currentActionName];
    _editorTitleLabel.frame = CGRectMake(66, compactHeight ? 21.0 : 22.0, width - 132, 30);

    UIView *divider = [_panelView viewWithTag:8811];
    if (!divider) {
        divider = [[UIView alloc] initWithFrame:CGRectZero];
        divider.tag = 8811;
        divider.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        [_panelView addSubview:divider];
    }
    divider.hidden = NO;
    divider.frame = CGRectMake(0, 56, width, 1);

    for (NSUInteger i = 0; i < _modeButtons.count; i++) {
        UIButton *button = _modeButtons[i];
        NSUInteger row = i / modeColumns;
        NSUInteger column = i % modeColumns;
        NSUInteger rowStart = row * modeColumns;
        NSUInteger itemsInRow = MIN(modeColumns, _modeButtons.count - rowStart);
        CGFloat rowWidth = width - side * 2.0;
        CGFloat buttonWidth = floor((rowWidth - modeGap * (itemsInRow - 1)) / itemsInRow);
        CGFloat usedWidth = buttonWidth * itemsInRow + modeGap * (itemsInRow - 1);
        CGFloat rowX = side + floor((rowWidth - usedWidth) * 0.5);
        button.frame = CGRectMake(rowX + (buttonWidth + modeGap) * column,
                                  modeTopY + (modeButtonHeight + modeRowGap) * row,
                                  buttonWidth,
                                  modeButtonHeight);
        button.titleLabel.font = [UIFont systemFontOfSize:(compactHeight ? 14 : 15) weight:UIFontWeightBold];
    }

    CGFloat modeRowGapCount = modeRows > 0 ? (CGFloat)(modeRows - 1) : 0.0;
    CGFloat modeBottomY = modeTopY + modeRows * modeButtonHeight + modeRowGapCount * modeRowGap;
    _statusLabel.frame = CGRectMake(16, modeBottomY + (compactHeight ? 4.0 : 6.0), width - 32, compactHeight ? 20.0 : 22.0);
    _statusLabel.textColor = UIColor.whiteColor;
    _statusLabel.font = [UIFont systemFontOfSize:(compactHeight ? 14 : 15) weight:UIFontWeightMedium];

    CGFloat bottomButtonHeight = compactHeight ? 38.0 : 40.0;
    CGFloat bottomButtonY = height - bottomButtonHeight - (compactHeight ? 8.0 : 12.0);
    CGFloat scrollTop = CGRectGetMaxY(_statusLabel.frame) + (compactHeight ? 4.0 : 6.0);
    CGFloat scrollBottom = bottomButtonY - 8.0;
    CGFloat minimumScrollHeight = compactHeight ? 72.0 : 120.0;
    if (scrollBottom - scrollTop < minimumScrollHeight) {
        scrollTop = MAX(58.0, scrollBottom - minimumScrollHeight);
    }
    CGFloat scrollHeight = MAX(52.0, scrollBottom - scrollTop);
    _editorContentScrollView.frame = CGRectMake(0, scrollTop, width, scrollHeight);
    _editorContentScrollView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 0, 3.0);

    CGFloat descriptionCaptionHeight = compactHeight ? 18.0 : 20.0;
    CGFloat descriptionFieldHeight = compactHeight ? 36.0 : 40.0;
    _descriptionCaptionLabel.frame = CGRectMake(side, 0, width - side * 2.0, descriptionCaptionHeight);
    _descriptionField.frame = CGRectMake(side, CGRectGetMaxY(_descriptionCaptionLabel.frame) + 2.0, width - side * 2.0, descriptionFieldHeight);

    CGFloat bottomButtonWidth = floor((width - side * 2.0 - 12.0) / 2.0);
    _cancelEditButton.frame = CGRectMake(side, bottomButtonY, bottomButtonWidth, bottomButtonHeight);
    _saveTaskButton.frame = CGRectMake(side + bottomButtonWidth + 12.0, bottomButtonY, bottomButtonWidth, bottomButtonHeight);
    [_saveTaskButton setTitle:@"确定" forState:UIControlStateNormal];
    [self updateButtonShadowPath:_cancelEditButton];
    [self updateButtonShadowPath:_saveTaskButton];
    for (UIButton *button in _modeButtons) {
        [self updateButtonShadowPath:button];
        [_panelView bringSubviewToFront:button];
    }
    [_panelView bringSubviewToFront:divider];
    [_panelView bringSubviewToFront:_editorBackButton];
    [_panelView bringSubviewToFront:_collapseButton];
    [_panelView bringSubviewToFront:_toolTitleLabel];
    [_panelView bringSubviewToFront:_editorTitleLabel];
    [_panelView bringSubviewToFront:_statusLabel];
    [_panelView bringSubviewToFront:_cancelEditButton];
    [_panelView bringSubviewToFront:_saveTaskButton];
    [self refreshEditorContentScrollSize];
}

- (void)showTaskHome {
    [self hideFunctionMenu];
    [self hideGlobalSettings];
    [self setTaskEditorVisible:NO];
    [self refreshTaskList];
    _statusLabel.text = _taskItems.count == 0
        ? @"暂无任务"
        : [NSString stringWithFormat:@"任务列表 · %lu项", (unsigned long)_taskItems.count];
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

- (NSMutableArray<NSMutableDictionary *> *)savedCurrentTaskList {
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

- (NSMutableArray<NSMutableDictionary *> *)copyTaskItemsForSaving {
    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:_taskItems.count];
    for (NSDictionary *task in _taskItems) {
        [tasks addObject:[task mutableCopy]];
    }
    return tasks;
}

- (NSMutableArray<NSMutableDictionary *> *)mutableTasksFromSavedTasks:(NSArray *)tasks {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *task in tasks) {
        if ([task isKindOfClass:NSDictionary.class]) {
            [result addObject:[task mutableCopy]];
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
        @"delayMilliseconds": @(_globalDelayMilliseconds),
        @"runRepeatCount": @(_globalRunRepeatCount),
        @"startEnabled": @(_globalStartEnabled),
        @"stopEnabled": @(_globalStopEnabled),
        @"startHour": @(_globalStartHour),
        @"startMinute": @(_globalStartMinute),
        @"startSecond": @(_globalStartSecond),
        @"stopHour": @(_globalStopHour),
        @"stopMinute": @(_globalStopMinute),
        @"stopSecond": @(_globalStopSecond),
        @"networkGateEnabled": @(_globalNetworkGateEnabled),
        @"networkURL": _globalNetworkURL ?: @"",
        @"networkContains": _globalNetworkContainsText ?: @"",
        @"networkFalse": _globalNetworkFalseText ?: @"",
    };
}

- (void)applyGlobalSettingsDictionary:(NSDictionary *)settings {
    if (![settings isKindOfClass:NSDictionary.class]) {
        return;
    }

    _globalDelayMilliseconds = MIN(3600000, MAX(0, [settings[@"delayMilliseconds"] integerValue]));
    _globalRunRepeatCount = MIN(9999, MAX(0, [settings[@"runRepeatCount"] integerValue]));
    _globalStartEnabled = [settings[@"startEnabled"] boolValue];
    _globalStopEnabled = [settings[@"stopEnabled"] boolValue];
    _globalStartHour = MIN(23, MAX(0, [settings[@"startHour"] integerValue]));
    _globalStartMinute = MIN(59, MAX(0, [settings[@"startMinute"] integerValue]));
    _globalStartSecond = MIN(59, MAX(0, [settings[@"startSecond"] integerValue]));
    _globalStopHour = MIN(23, MAX(0, [settings[@"stopHour"] integerValue]));
    _globalStopMinute = MIN(59, MAX(0, [settings[@"stopMinute"] integerValue]));
    _globalStopSecond = MIN(59, MAX(0, [settings[@"stopSecond"] integerValue]));
    _globalNetworkGateEnabled = [settings[@"networkGateEnabled"] boolValue];
    id networkURL = settings[@"networkURL"];
    id networkContains = settings[@"networkContains"];
    id networkFalse = settings[@"networkFalse"];
    _globalNetworkURL = [networkURL isKindOfClass:NSString.class] ? [self trimmedActionDescription:networkURL] : nil;
    _globalNetworkContainsText = [networkContains isKindOfClass:NSString.class] ? [self trimmedActionDescription:networkContains] : nil;
    _globalNetworkFalseText = [networkFalse isKindOfClass:NSString.class] ? [self trimmedActionDescription:networkFalse] : nil;
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

- (NSDate *)dateTodayWithHour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[NSDate date]];
    components.hour = hour;
    components.minute = minute;
    components.second = second;
    NSDate *date = [calendar dateFromComponents:components];
    return date ? date : [NSDate date];
}

- (NSDate *)nextFireDateForHour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second {
    NSDate *date = [self dateTodayWithHour:hour minute:minute second:second];
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
        NSDate *startDate = [self nextFireDateForHour:_globalStartHour minute:_globalStartMinute second:_globalStartSecond];
        _globalStartTimer = [[NSTimer alloc] initWithFireDate:startDate interval:0 target:self selector:@selector(handleGlobalStartTimer:) userInfo:nil repeats:NO];
        [NSRunLoop.mainRunLoop addTimer:_globalStartTimer forMode:NSRunLoopCommonModes];
    }
    if (_globalStopEnabled) {
        NSDate *stopDate = [self nextFireDateForHour:_globalStopHour minute:_globalStopMinute second:_globalStopSecond];
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
    return _globalDelayMilliseconds > 0 ? [NSString stringWithFormat:@"%ld", (long)_globalDelayMilliseconds] : @"";
}

- (NSString *)globalRepeatFieldText {
    return _globalRunRepeatCount > 0 ? [NSString stringWithFormat:@"%ld", (long)_globalRunRepeatCount] : @"";
}

- (NSString *)globalTimeTitleEnabled:(BOOL)enabled hour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second {
    return enabled ? [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hour, (long)minute, (long)second] : @"关闭";
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
    button.titleLabel.minimumScaleFactor = 0.72;
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 22, 0, 22);
    button.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.24 alpha:0.92];
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)refreshGlobalSettingsControls {
    if (_globalDelayField && !_globalDelayField.isFirstResponder) {
        _globalDelayField.text = [self globalDelayFieldText];
    }
    if (_globalRepeatField && !_globalRepeatField.isFirstResponder) {
        _globalRepeatField.text = [self globalRepeatFieldText];
    }
    [_globalStartTimeButton setTitle:[self globalTimeTitleEnabled:_globalStartEnabled hour:_globalStartHour minute:_globalStartMinute second:_globalStartSecond] forState:UIControlStateNormal];
    [_globalStopTimeButton setTitle:[self globalTimeTitleEnabled:_globalStopEnabled hour:_globalStopHour minute:_globalStopMinute second:_globalStopSecond] forState:UIControlStateNormal];
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
        _globalDelayMilliseconds = delayText.length > 0 ? MIN(3600000, MAX(0, delayText.integerValue)) : 0;
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
    if (_globalDelayField || _globalRepeatField) {
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

- (void)showGlobalSettings {
    [self dismissKeyboard];
    [self hideFunctionMenu];
    [self hideGlobalSettings];

    _globalSettingsView = [[UIView alloc] initWithFrame:_panelView.bounds];
    [self installDarkBlurInView:_globalSettingsView cornerRadius:_panelView.layer.cornerRadius];
    _globalSettingsView.layer.cornerRadius = _panelView.layer.cornerRadius;
    _globalSettingsView.clipsToBounds = YES;
    [_panelView addSubview:_globalSettingsView];

    CGFloat width = _globalSettingsView.bounds.size.width;
    CGFloat height = _globalSettingsView.bounds.size.height;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 14, width - 76, 34)];
    titleLabel.text = [NSString stringWithFormat:@"%@ 设置", [self toolDisplayName]];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.68;
    [_globalSettingsView addSubview:titleLabel];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(width - 54, 10, 40, 40);
    closeButton.layer.cornerRadius = 20;
    closeButton.titleLabel.font = [UIFont systemFontOfSize:27 weight:UIFontWeightBold];
    [closeButton setTitle:@"×" forState:UIControlStateNormal];
    [self applyFrostedRoundButtonStyle:closeButton];
    [closeButton addTarget:self action:@selector(hideGlobalSettings) forControlEvents:UIControlEventTouchUpInside];
    [_globalSettingsView addSubview:closeButton];

    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(0, 60, width, 1)];
    divider.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    [_globalSettingsView addSubview:divider];

    _globalSettingsScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 61, width, height - 61)];
    _globalSettingsScrollView.backgroundColor = UIColor.clearColor;
    _globalSettingsScrollView.alwaysBounceVertical = YES;
    [_globalSettingsView addSubview:_globalSettingsScrollView];

    CGFloat side = 18.0;
    CGFloat y = 18.0;
    CGFloat contentWidth = width - side * 2.0;
    NSArray<NSString *> *captions = @[
        @"整体延时（毫秒，0=无延时）",
        @"整体执行次数（0=无限循环）",
        @"定时启动（到时间自动开始）",
        @"定时停止（到时间自动停止）",
        @"播放前网络判断（不满足会持续监控）",
        @"网络判断链接（GET）",
        @"返回包含这些就运行（至少填一项）",
        @"返回包含这些就不运行（至少填一项）",
    ];
    NSMutableArray<UIView *> *controls = [NSMutableArray array];
    _globalDelayField = [self globalSettingsTextFieldWithPlaceholder:@"无延时"];
    _globalRepeatField = [self globalSettingsTextFieldWithPlaceholder:@"无限循环"];
    _globalStartTimeButton = [self globalSettingsValueButtonWithAction:@selector(showGlobalStartTimePicker)];
    _globalStopTimeButton = [self globalSettingsValueButtonWithAction:@selector(showGlobalStopTimePicker)];
    _globalNetworkGateButton = [self globalSettingsValueButtonWithAction:@selector(toggleGlobalNetworkGate)];
    _globalNetworkURLField = [self globalSettingsTextFieldWithPlaceholder:@"https://example.com"];
    _globalNetworkURLField.keyboardType = UIKeyboardTypeURL;
    _globalNetworkURLField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _globalNetworkURLField.autocorrectionType = UITextAutocorrectionTypeNo;
    _globalNetworkURLField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _globalNetworkContainsField = [self globalSettingsTextFieldWithPlaceholder:@"例：成功 / true"];
    _globalNetworkContainsField.keyboardType = UIKeyboardTypeDefault;
    _globalNetworkContainsField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _globalNetworkContainsField.autocorrectionType = UITextAutocorrectionTypeNo;
    _globalNetworkContainsField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _globalNetworkFalseField = [self globalSettingsTextFieldWithPlaceholder:@"例：失败 / false"];
    _globalNetworkFalseField.keyboardType = UIKeyboardTypeDefault;
    _globalNetworkFalseField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _globalNetworkFalseField.autocorrectionType = UITextAutocorrectionTypeNo;
    _globalNetworkFalseField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [controls addObjectsFromArray:@[
        _globalDelayField,
        _globalRepeatField,
        _globalStartTimeButton,
        _globalStopTimeButton,
        _globalNetworkGateButton,
        _globalNetworkURLField,
        _globalNetworkContainsField,
        _globalNetworkFalseField,
    ]];

    for (NSUInteger i = 0; i < captions.count; i++) {
        UILabel *caption = [self configCaptionLabelWithText:captions[i]];
        caption.frame = CGRectMake(side, y, contentWidth, 24);
        [_globalSettingsScrollView addSubview:caption];

        UIView *control = controls[i];
        control.frame = CGRectMake(side, y + 34.0, contentWidth, 58.0);
        [_globalSettingsScrollView addSubview:control];
        y += 112.0;
    }
    _globalSettingsScrollView.contentSize = CGSizeMake(width, y + 12.0);
    [self refreshGlobalSettingsControls];
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
    return pickerView == _globalTimePicker ? 3 : 0;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return pickerView == _globalTimePicker ? [self globalTimePickerRowCountForComponent:component] : 0;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (pickerView != _globalTimePicker) {
        return @"";
    }
    return [NSString stringWithFormat:@"%02ld %@", (long)row, [self globalTimePickerUnitForComponent:component]];
}

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSString *title = [self pickerView:pickerView titleForRow:row forComponent:component];
    return [[NSAttributedString alloc] initWithString:title
                                          attributes:@{
                                              NSForegroundColorAttributeName: UIColor.whiteColor,
                                              NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:20 weight:UIFontWeightSemibold]
                                          }];
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return pickerView == _globalTimePicker ? 34.0 : 0.0;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    if (pickerView != _globalTimePicker || component < 0 || component > 2) {
        return 0.0;
    }
    return floor((pickerView.bounds.size.width - 18.0) / 3.0);
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
    CGFloat cardHeight = MIN(380.0, height - 48.0);
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, MAX(40.0, (height - cardHeight) * 0.5), width, cardHeight)];
    card.backgroundColor = [[self themePanelDarkColor] colorWithAlphaComponent:0.98];
    card.layer.cornerRadius = 22;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
    card.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        card.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    [overlay addSubview:card];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 20, width - 32, 34)];
    titleLabel.text = [NSString stringWithFormat:@"%@ %@", [self toolDisplayName], startTime ? @"启动时间" : @"停止时间"];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.68;
    [card addSubview:titleLabel];

    CGFloat buttonY = cardHeight - 60.0;
    CGFloat pickerY = 68.0;
    CGFloat pickerHeight = MAX(150.0, buttonY - pickerY - 10.0);
    _globalTimePicker = [[UIPickerView alloc] initWithFrame:CGRectMake(10.0, pickerY, width - 20.0, pickerHeight)];
    _globalTimePicker.dataSource = self;
    _globalTimePicker.delegate = self;
    if (@available(iOS 13.0, *)) {
        _globalTimePicker.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    NSDate *defaultDate = [self defaultGlobalTimePickerDateForStart:startTime];
    NSDateComponents *defaultComponents = [NSCalendar.currentCalendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:defaultDate];
    [card addSubview:_globalTimePicker];
    [_globalTimePicker selectRow:MIN(23, MAX(0, defaultComponents.hour)) inComponent:0 animated:NO];
    [_globalTimePicker selectRow:MIN(59, MAX(0, defaultComponents.minute)) inComponent:1 animated:NO];
    [_globalTimePicker selectRow:MIN(59, MAX(0, defaultComponents.second)) inComponent:2 animated:NO];

    CGFloat buttonWidth = width / 3.0;
    NSArray<NSString *> *titles = @[@"关闭", @"取消", @"确定"];
    NSArray<NSString *> *selectors = @[@"disableGlobalPickedTime", @"cancelGlobalTimePicker", @"confirmGlobalTimePicker"];
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(buttonWidth * i, buttonY, buttonWidth, 60.0);
        button.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:(i == 2 ? UIColor.systemBlueColor : [UIColor colorWithWhite:1 alpha:0.78]) forState:UIControlStateNormal];
        [button addTarget:self action:NSSelectorFromString(selectors[i]) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:button];
        if (i > 0) {
            UIView *line = [[UIView alloc] initWithFrame:CGRectMake(buttonWidth * i, buttonY, 1, 60.0)];
            line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
            [card addSubview:line];
        }
    }
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, buttonY, width, 1)];
    topLine.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
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
    if (_globalTimePickerEditingStartTime) {
        _globalStartEnabled = YES;
        _globalStartHour = hour;
        _globalStartMinute = minute;
        _globalStartSecond = second;
    } else {
        _globalStopEnabled = YES;
        _globalStopHour = hour;
        _globalStopMinute = minute;
        _globalStopSecond = second;
    }
    [self hideGlobalTimePicker];
    [self refreshGlobalSettingsControls];
    [self persistGlobalSettings];
}

- (void)hideFunctionMenu {
    [_functionMenuView removeFromSuperview];
    _functionMenuView = nil;
    _configListView = nil;
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
    [attributed addAttribute:NSForegroundColorAttributeName value:UIColor.whiteColor range:NSMakeRange(0, title.length)];
    [attributed addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:19 weight:UIFontWeightBold] range:NSMakeRange(0, title.length)];
    if (subtitle.length > 0) {
        NSRange subtitleRange = NSMakeRange(title.length + 1, subtitle.length);
        [attributed addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:1 alpha:0.58] range:subtitleRange];
        [attributed addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:13 weight:UIFontWeightMedium] range:subtitleRange];
    }
    [button setAttributedTitle:attributed forState:UIControlStateNormal];
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 18, 0, 34);
    button.backgroundColor = color;
    button.layer.cornerRadius = 8;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UILabel *chevron = [[UILabel alloc] initWithFrame:CGRectZero];
    chevron.tag = 9001;
    chevron.text = @">";
    chevron.textColor = [UIColor colorWithWhite:1 alpha:0.55];
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
    }
}

- (void)showFunctionMenu {
    [self dismissKeyboard];
    [self hideGlobalSettings];
    [self hideFunctionMenu];

    _functionMenuView = [[UIView alloc] initWithFrame:_panelView.bounds];
    [self installDarkBlurInView:_functionMenuView cornerRadius:_panelView.layer.cornerRadius];
    _functionMenuView.layer.cornerRadius = _panelView.layer.cornerRadius;
    _functionMenuView.clipsToBounds = YES;
    [_panelView addSubview:_functionMenuView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 14, _functionMenuView.bounds.size.width - 76, 34)];
    titleLabel.text = [NSString stringWithFormat:@"%@ 功能", [self toolDisplayName]];
    titleLabel.textColor = UIColor.whiteColor;
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
    caption.text = @"配置管理";
    caption.textColor = [UIColor colorWithWhite:1 alpha:0.58];
    caption.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [_functionMenuView addSubview:caption];

    UIButton *saveRow = [self functionMenuRowWithTitle:@"保存当前任务列表"
                                             subtitle:@"保存当前所有任务和设置"
                                                color:[UIColor colorWithRed:0.03 green:0.30 blue:0.52 alpha:0.82]
                                               action:@selector(saveCurrentTaskConfig)
                                                  tag:0];
    UIButton *chooseRow = [self functionMenuRowWithTitle:@"选择任务配置"
                                               subtitle:@"加载已保存的任务列表"
                                                  color:[UIColor colorWithRed:0.08 green:0.32 blue:0.16 alpha:0.82]
                                                 action:@selector(showSavedConfigChooser)
                                                    tag:0];
    UIButton *deleteRow = [self functionMenuRowWithTitle:@"删除任务配置"
                                               subtitle:@"删除已保存的配置文件"
                                                  color:[UIColor colorWithRed:0.44 green:0.16 blue:0.07 alpha:0.82]
                                                 action:@selector(showSavedConfigDeleter)
                                                    tag:0];
    [_functionMenuView addSubview:saveRow];
    [_functionMenuView addSubview:chooseRow];
    [_functionMenuView addSubview:deleteRow];
    [self layoutFunctionMenuRows:@[saveRow, chooseRow, deleteRow] startY:108.0];
}

- (void)saveCurrentTaskConfig {
    if (_taskItems.count == 0) {
        _statusLabel.text = @"没有任务可保存";
        [self hideFunctionMenu];
        return;
    }

    NSMutableArray *configs = [self savedTaskConfigs];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MM-dd HH:mm";
    NSString *name = [NSString stringWithFormat:@"配置 %@  %lu项", [formatter stringFromDate:[NSDate date]], (unsigned long)_taskItems.count];
    NSMutableDictionary *config = [@{
        @"name": name,
        @"createdAt": @([NSDate date].timeIntervalSince1970),
        @"tasks": [self copyTaskItemsForSaving],
        @"globalSettings": [self currentGlobalSettingsDictionary],
    } mutableCopy];
    [configs insertObject:config atIndex:0];
    [self writeSavedTaskConfigs:configs];
    _statusLabel.text = @"任务配置已保存";
    [self hideFunctionMenu];
}

- (void)showSavedConfigChooser {
    [self showSavedConfigListForDeleting:NO];
}

- (void)showSavedConfigDeleter {
    [self showSavedConfigListForDeleting:YES];
}

- (void)showSavedConfigListForDeleting:(BOOL)deleting {
    if (!_functionMenuView) {
        [self showFunctionMenu];
    }
    for (UIView *view in [_functionMenuView.subviews copy]) {
        if (view.tag != AnClickBackdropBlurViewTag) {
            [view removeFromSuperview];
        }
    }

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 14, _functionMenuView.bounds.size.width - 76, 34)];
    titleLabel.text = [NSString stringWithFormat:@"%@ %@", [self toolDisplayName], deleting ? @"删除配置" : @"选择配置"];
    titleLabel.textColor = UIColor.whiteColor;
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

    NSArray *configs = [self savedTaskConfigs];
    if (configs.count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, _configListView.bounds.size.width - 20, 60)];
        empty.text = @"暂无已保存配置";
        empty.textColor = [UIColor colorWithWhite:1 alpha:0.58];
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
                                                 color:deleting ? [UIColor colorWithRed:0.46 green:0.11 blue:0.08 alpha:0.86] : [UIColor colorWithWhite:1 alpha:0.10]
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
    _revealedDeleteTaskIndex = -1;
    [self resetCurrentActionConfiguration];
    [self hideFunctionMenu];
    [self showTaskHome];
    [self persistCurrentTaskList];
    _statusLabel.text = [NSString stringWithFormat:@"已加载 %lu 个任务", (unsigned long)_taskItems.count];
}

- (void)deleteSavedConfigButton:(UIButton *)sender {
    NSMutableArray *configs = [self savedTaskConfigs];
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)configs.count) {
        _statusLabel.text = @"配置不存在";
        return;
    }

    [configs removeObjectAtIndex:(NSUInteger)index];
    [self writeSavedTaskConfigs:configs];
    _statusLabel.text = @"配置已删除";
    [self showSavedConfigListForDeleting:YES];
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
    if (_recordedSwipePoints) {
        [_recordedSwipePoints removeAllObjects];
    } else {
        _recordedSwipePoints = [NSMutableArray array];
    }
    _currentTemplatePath = nil;
    _imageUsesMatchPoint = YES;
    _ocrUsesMatchPoint = YES;
    _imageActionMode = AnClickActionModeTap;
    _ocrMode = AnClickOCRModeAppleVision;
    _ocrMatchMode = AnClickOCRMatchModeContains;
    _ocrTargetText = nil;
    _networkURL = nil;
    _networkContainsText = nil;
    _networkFalseText = nil;
    _networkPostBody = nil;
    _networkPostExtraFields = nil;
    _networkRequestOnly = NO;
    _networkUsesPost = NO;
    _networkPostBodyUsesOCRResult = NO;
    _networkRetryForever = YES;
    _networkTimeout = 8.0;
    _hasTargetColor = NO;
    _targetColorSamples = [NSMutableArray array];
    _pendingColorPickSamples = [NSMutableArray array];
    _selectedColorPickSampleIndex = -1;
    _targetColorRed = 0;
    _targetColorGreen = 0;
    _targetColorBlue = 0;
    _colorTolerance = 18.0;
    _recordedMacroEvents = nil;
    _matchThreshold = 0.80;
    _actionDescription = nil;
    _actionDelay = 0;
    _actionRepeatCount = 1;
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
    CGRect frame = _panelWindow.frame;
    frame.size = CGSizeMake(48.0, 48.0);
    _panelWindow.frame = [self clampedFloatingFrame:frame];
    _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
    _collapsedButton.frame = _panelWindow.bounds;
    _collapsedButton.hidden = NO;
    _homeCloseButton.hidden = YES;
    _panelView.hidden = YES;
    [self refreshCollapsedButtonTitle];
}

- (void)showCollapsedRecordingButton {
    if (!_panelWindow || !_collapsedButton || !_panelView) {
        return;
    }

    _panelExpanded = NO;
    CGRect frame = _panelWindow.frame;
    frame.size = CGSizeMake(48.0, 48.0);
    _panelWindow.frame = [self clampedFloatingFrame:frame];
    _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
    _collapsedButton.frame = _panelWindow.bounds;
    _collapsedButton.hidden = NO;
    _homeCloseButton.hidden = YES;
    _panelView.hidden = YES;
    _panelWindow.hidden = NO;
    _panelWindow.userInteractionEnabled = YES;
    [self refreshCollapsedButtonTitle];
}

- (void)expandPanel {
    if (!_panelWindow || !_collapsedButton || !_panelView) {
        return;
    }

    _panelExpanded = YES;
    CGRect frame = _panelWindow.frame;
    frame.size = [self expandedPanelSize];
    _panelWindow.frame = [self clampedPanelFrame:frame];
    _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
    _panelView.frame = _panelWindow.bounds;
    _collapsedButton.hidden = YES;
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
    if (_taskRunActive) {
        [self stopTaskRunWithStatus:@"已停止"];
        return;
    }
    [self refreshCollapsedButtonTitle];
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

- (void)selectActionMode:(UIButton *)sender {
    [self syncActionDescriptionFromField];
    [self syncActionTimingFromFields];
    [self syncOCRTargetFromField];
    [self syncNetworkFieldsFromEditor];
    AnClickActionMode previousMode = _actionMode;
    AnClickActionMode nextMode = (AnClickActionMode)sender.tag;
    CGPoint reusablePoint = CGPointZero;
    BOOL hasReusablePoint = [self isReusablePointActionMode:previousMode] && [self hasManualPointForMode:previousMode];
    if (hasReusablePoint) {
        reusablePoint = _manualActionPoints[(NSUInteger)previousMode];
    }

    _actionMode = nextMode;
    if ([self isReusablePointActionMode:nextMode] && ![self hasManualPointForMode:nextMode] && hasReusablePoint) {
        _manualActionPoints[(NSUInteger)nextMode] = reusablePoint;
        _hasManualActionPoint[(NSUInteger)nextMode] = YES;
    }
    [self refreshModeButtons];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
}

- (void)refreshModeButtons {
    for (UIButton *button in _modeButtons) {
        BOOL selected = button.tag == _actionMode;
        [self applyObsidian3DStyleToButton:button selected:selected];
    }
}

- (NSString *)currentActionName {
    return [self actionNameForMode:_actionMode];
}

- (NSString *)actionNameForMode:(AnClickActionMode)mode {
    NSArray<NSString *> *names = @[@"点击", @"双击", @"长按", @"滑动", @"二指", @"缩小", @"放大", @"旋转", @"识图", @"录制", @"识字", @"识色", @"网络"];
    if (mode < AnClickActionModeTap || mode >= AnClickActionModeCount) {
        return @"动作";
    }
    return names[(NSUInteger)mode];
}

- (BOOL)isSelectableActionMode:(AnClickActionMode)mode {
    return mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeSwipe ||
        mode == AnClickActionModeImage ||
        mode == AnClickActionModeMacro ||
        mode == AnClickActionModeOCR ||
        mode == AnClickActionModeColor ||
        mode == AnClickActionModeNetwork;
}

- (BOOL)isReusablePointActionMode:(AnClickActionMode)mode {
    return mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress;
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
    return targetText.length > 0 ? targetText : (matchMode == AnClickOCRMatchModeRegex ? @"先填正则表达式" : @"先填文字");
}

- (AnClickOCRMatchMode)ocrMatchModeForTask:(NSDictionary *)task {
    NSNumber *modeNumber = task[@"ocrMatchMode"];
    if (modeNumber) {
        return modeNumber.integerValue == AnClickOCRMatchModeRegex
            ? AnClickOCRMatchModeRegex
            : AnClickOCRMatchModeContains;
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
    return _ocrMatchMode == AnClickOCRMatchModeRegex ? AnClickOCRMatchModeRegex : AnClickOCRMatchModeContains;
}

- (NSString *)ocrMatchModeTitleForMode:(AnClickOCRMatchMode)mode {
    return mode == AnClickOCRMatchModeRegex ? @"正则匹配" : @"包含匹配";
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
    return @[
        @(AnClickActionModeTap),
        @(AnClickActionModeDoubleTap),
        @(AnClickActionModeLongPress),
        @(AnClickActionModeNetwork),
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
    [self syncActionDescriptionFromField];
    [self syncActionTimingFromFields];
    [self syncImageThresholdFromField];
    [self syncOCRTargetFromField];
    [self syncNetworkFieldsFromEditor];
    [self syncGlobalSettingsFromFields];
    [_panelView endEditing:YES];
}

- (void)dismissKeyboard {
    [self dismissConfigKeyboardAndSync];
    [self refreshTimingFieldsIfNeeded];
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

- (void)handlePanelTapToDismissKeyboard:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }

    NSMutableArray<UITextField *> *fields = [NSMutableArray arrayWithObjects:_descriptionField, _delayField, _repeatField, _thresholdField, _ocrTargetField, _networkURLField, _networkContainsField, _networkFalseField, _networkPostBodyField, _networkPostExtraFieldsField, nil];
    if (_globalDelayField) {
        [fields addObject:_globalDelayField];
    }
    if (_globalRepeatField) {
        [fields addObject:_globalRepeatField];
    }
    if (_globalNetworkURLField) {
        [fields addObject:_globalNetworkURLField];
    }
    if (_globalNetworkContainsField) {
        [fields addObject:_globalNetworkContainsField];
    }
    if (_globalNetworkFalseField) {
        [fields addObject:_globalNetworkFalseField];
    }
    for (UITextField *field in fields) {
        UIView *fieldContainer = field.superview ? field.superview : _panelView;
        CGPoint fieldPoint = [recognizer locationInView:fieldContainer];
        if (!field.hidden && CGRectContainsPoint(field.frame, fieldPoint)) {
            return;
        }
    }
    [self dismissKeyboard];
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
    return [NSString stringWithFormat:@"延%.1fs 次%ld", _actionDelay, (long)_actionRepeatCount];
}

- (void)syncActionDescriptionFromField {
    if (!_descriptionField) {
        return;
    }
    _actionDescription = [self trimmedActionDescription:_descriptionField.text];
}

- (void)actionDescriptionChanged:(UITextField *)textField {
    _actionDescription = [self trimmedActionDescription:textField.text];
    [self autosaveSelectedTaskIfPossible];
}

- (NSString *)delayFieldText {
    if (_actionDelay <= 0.001) {
        return @"";
    }
    return [NSString stringWithFormat:@"%.1f", _actionDelay];
}

- (NSString *)repeatFieldText {
    return [NSString stringWithFormat:@"%ld", (long)MAX(1, _actionRepeatCount)];
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

- (void)syncActionTimingFromFields {
    NSString *delayText = [_delayField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *repeatText = [_repeatField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (delayText.length > 0) {
        _actionDelay = MIN(30.0, MAX(0.0, delayText.doubleValue));
        _actionDelay = round(_actionDelay * 10.0) / 10.0;
    } else {
        _actionDelay = 0.0;
    }
    if (repeatText.length > 0) {
        _actionRepeatCount = MIN(99, MAX(1, repeatText.integerValue));
    } else {
        _actionRepeatCount = 1;
    }
}

- (void)syncImageThresholdFromField {
    NSString *thresholdText = [_thresholdField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (_actionMode == AnClickActionModeNetwork) {
        if (thresholdText.length > 0) {
            _networkTimeout = MIN(60.0, MAX(1.0, thresholdText.doubleValue));
        } else {
            _networkTimeout = 8.0;
        }
        return;
    }
    if (_actionMode == AnClickActionModeColor) {
        if (thresholdText.length > 0) {
            _colorTolerance = MIN(255.0, MAX(0.0, thresholdText.doubleValue));
        } else {
            _colorTolerance = 18.0;
        }
        return;
    }
    if (thresholdText.length > 0) {
        _matchThreshold = MIN(1.0, MAX(0.0, thresholdText.doubleValue));
    } else {
        _matchThreshold = 0.80;
    }
}

- (void)syncOCRTargetFromField {
    if (!_ocrTargetField) {
        return;
    }
    _ocrTargetText = [self trimmedActionDescription:_ocrTargetField.text];
}

- (void)syncNetworkFieldsFromEditor {
    if (_networkURLField) {
        _networkURL = [self trimmedActionDescription:_networkURLField.text];
    }
    if (_networkContainsField) {
        _networkContainsText = [self trimmedActionDescription:_networkContainsField.text];
    }
    if (_networkFalseField) {
        _networkFalseText = [self trimmedActionDescription:_networkFalseField.text];
    }
    if (_networkPostBodyField) {
        _networkPostBody = [self trimmedActionDescription:_networkPostBodyField.text];
    }
    if (_networkPostExtraFieldsField) {
        _networkPostExtraFields = [self trimmedActionDescription:_networkPostExtraFieldsField.text];
    }
}

- (void)refreshTimingFieldsIfNeeded {
    if (!_delayField.isFirstResponder) {
        _delayField.text = [self delayFieldText];
    }
    if (!_repeatField.isFirstResponder) {
        _repeatField.text = [self repeatFieldText];
    }
    if (!_thresholdField.isFirstResponder) {
        _thresholdField.text = [self thresholdFieldText];
    }
}

- (void)ocrTargetChanged:(UITextField *)textField {
    _ocrTargetText = [self trimmedActionDescription:textField.text];
    [self autosaveSelectedTaskIfPossible];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
}

- (void)ocrTargetEditingDidEnd:(__unused UITextField *)textField {
    [self syncOCRTargetFromField];
    [self autosaveSelectedTaskIfPossible];
    [self updateStatusForCurrentConfig];
}

- (void)selectOCRMatchMode:(UIButton *)sender {
    if (_actionMode != AnClickActionModeOCR) {
        return;
    }
    [self syncOCRTargetFromField];
    _ocrMatchMode = sender.tag == AnClickOCRMatchModeRegex
        ? AnClickOCRMatchModeRegex
        : AnClickOCRMatchModeContains;
    [self autosaveSelectedTaskIfPossible];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
}

- (void)networkFieldChanged:(__unused UITextField *)textField {
    [self syncNetworkFieldsFromEditor];
    [self autosaveSelectedTaskIfPossible];
    [self updateStatusForCurrentConfig];
}

- (void)networkFieldEditingDidEnd:(__unused UITextField *)textField {
    [self syncNetworkFieldsFromEditor];
    [self autosaveSelectedTaskIfPossible];
    [self updateStatusForCurrentConfig];
}

- (void)toggleNetworkRequestMode {
    if (_actionMode != AnClickActionModeNetwork) {
        return;
    }
    [self syncNetworkFieldsFromEditor];
    _networkRequestOnly = !_networkRequestOnly;
    [self autosaveSelectedTaskIfPossible];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
}

- (void)toggleNetworkRetryMode {
    if (_actionMode != AnClickActionModeNetwork || _networkRequestOnly) {
        return;
    }
    [self syncNetworkFieldsFromEditor];
    _networkRetryForever = !_networkRetryForever;
    [self autosaveSelectedTaskIfPossible];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
}

- (void)toggleNetworkMethod {
    if (_actionMode != AnClickActionModeNetwork &&
        !((_actionMode == AnClickActionModeImage ||
           _actionMode == AnClickActionModeOCR ||
           _actionMode == AnClickActionModeColor) &&
          _imageActionMode == AnClickActionModeNetwork)) {
        return;
    }
    [self syncNetworkFieldsFromEditor];
    _networkUsesPost = !_networkUsesPost;
    [self autosaveSelectedTaskIfPossible];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
}

- (void)selectNetworkPostBodySource:(UIButton *)sender {
    if (_actionMode != AnClickActionModeOCR ||
        _imageActionMode != AnClickActionModeNetwork ||
        !_networkUsesPost) {
        return;
    }
    [self syncNetworkFieldsFromEditor];
    _networkPostBodyUsesOCRResult = sender.tag == 1;
    [self autosaveSelectedTaskIfPossible];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
}

- (void)actionTimingChanged:(__unused UITextField *)textField {
    [self syncActionTimingFromFields];
    [self autosaveSelectedTaskIfPossible];
    [self updateStatusForCurrentConfig];
}

- (void)actionTimingEditingDidEnd:(__unused UITextField *)textField {
    [self syncActionTimingFromFields];
    [self autosaveSelectedTaskIfPossible];
    [self refreshTimingFieldsIfNeeded];
    [self updateStatusForCurrentConfig];
}

- (void)actionThresholdChanged:(__unused UITextField *)textField {
    [self syncImageThresholdFromField];
    [self autosaveSelectedTaskIfPossible];
    [self updateStatusForCurrentConfig];
}

- (void)actionThresholdEditingDidEnd:(__unused UITextField *)textField {
    [self syncImageThresholdFromField];
    [self autosaveSelectedTaskIfPossible];
    [self refreshTimingFieldsIfNeeded];
    [self updateStatusForCurrentConfig];
}

- (void)hideAllConfigButtons {
    _primaryConfigLabel.hidden = YES;
    _secondaryConfigLabel.hidden = YES;
    _tertiaryConfigLabel.hidden = YES;
    _thresholdCaptionLabel.hidden = YES;
    _delayCaptionLabel.hidden = YES;
    _repeatCaptionLabel.hidden = YES;
    _captureButton.hidden = YES;
    _playButton.hidden = YES;
    _pickPointButton.hidden = YES;
    _runManualButton.hidden = YES;
    _recordSwipeButton.hidden = YES;
    _previewSwipeButton.hidden = YES;
    _clearActionButton.hidden = YES;
    _testButton.hidden = YES;
    _imageActionButton.hidden = YES;
    _ocrContainsMatchModeButton.hidden = YES;
    _ocrRegexMatchModeButton.hidden = YES;
    _networkRequestModeButton.hidden = YES;
    _networkMethodButton.hidden = YES;
    _networkRetryModeButton.hidden = YES;
    _networkPostCustomButton.hidden = YES;
    _networkPostOCRResultButton.hidden = YES;
    _previewActionButton.hidden = YES;
    _swipeRecordButton.hidden = YES;
    _macroRecordButton.hidden = YES;
    _macroPlayButton.hidden = YES;
    _delayField.hidden = YES;
    _repeatField.hidden = YES;
    _thresholdField.hidden = YES;
    _ocrTargetField.hidden = YES;
    _networkURLField.hidden = YES;
    _networkContainsField.hidden = YES;
    _networkFalseField.hidden = YES;
    _networkPostBodyField.hidden = YES;
    _networkPostExtraFieldsField.hidden = YES;
    _colorPreviewView.hidden = YES;
    _saveTaskButton.hidden = YES;
    _editorBackButton.hidden = YES;
    _cancelEditButton.hidden = YES;
}

- (void)layoutConfigButtons:(NSArray<UIButton *> *)buttons y:(CGFloat)y {
    if (buttons.count == 0 || !_panelView) {
        return;
    }

    CGFloat gap = 12.0;
    CGFloat width = _panelView.bounds.size.width;
    CGFloat buttonWidth = floor((width - gap * (buttons.count + 1)) / buttons.count);
    CGFloat buttonHeight = 34.0;
    for (NSUInteger i = 0; i < buttons.count; i++) {
        UIButton *button = buttons[i];
        button.hidden = NO;
        button.frame = CGRectMake(gap + (buttonWidth + gap) * i, y, buttonWidth, buttonHeight);
        [self updateButtonShadowPath:button];
    }
}

- (void)layoutTimingFieldsAtY:(CGFloat)y {
    CGFloat gap = 12.0;
    CGFloat width = _panelView.bounds.size.width;
    CGFloat fieldWidth = floor((width - gap * 3.0) / 2.0);
    _delayField.hidden = NO;
    _repeatField.hidden = NO;
    _delayField.frame = CGRectMake(gap, y, fieldWidth, 34.0);
    _repeatField.frame = CGRectMake(gap * 2.0 + fieldWidth, y, fieldWidth, 34.0);
}

- (void)styleSegmentButton:(UIButton *)button selected:(BOOL)selected {
    [self applyObsidian3DStyleToButton:button selected:selected];
}

- (void)styleNormalButton:(UIButton *)button {
    [self applyObsidian3DStyleToButton:button selected:NO];
}

- (void)styleRecordButton:(UIButton *)button active:(BOOL)active {
    button.layer.cornerRadius = 7;
    button.layer.borderWidth = 1;
    button.layer.masksToBounds = NO;
    button.backgroundColor = active
        ? [UIColor colorWithRed:0.84 green:0.12 blue:0.10 alpha:0.96]
        : [UIColor colorWithRed:0.58 green:0.08 blue:0.07 alpha:0.94];
    button.layer.borderColor = [UIColor colorWithRed:1.0 green:0.30 blue:0.24 alpha:0.92].CGColor;
    button.layer.shadowColor = [UIColor colorWithRed:0.90 green:0.10 blue:0.08 alpha:1.0].CGColor;
    button.layer.shadowOffset = CGSizeMake(0, active ? 0 : 2.5);
    button.layer.shadowRadius = active ? 8.0 : 5.0;
    button.layer.shadowOpacity = active ? 0.40 : 0.28;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self updateButtonShadowPath:button];
}

- (void)layoutButtons:(NSArray<UIButton *> *)buttons x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height gap:(CGFloat)gap {
    if (buttons.count == 0) {
        return;
    }

    CGFloat buttonWidth = floor((width - gap * (buttons.count - 1)) / buttons.count);
    for (NSUInteger i = 0; i < buttons.count; i++) {
        UIButton *button = buttons[i];
        button.hidden = NO;
        button.frame = CGRectMake(x + (buttonWidth + gap) * i, y, buttonWidth, height);
        [self updateButtonShadowPath:button];
    }
}

- (void)configureSuccessActionButtons {
    [_recordSwipeButton setTitle:@"点击" forState:UIControlStateNormal];
    [_previewSwipeButton setTitle:@"双击" forState:UIControlStateNormal];
    [_clearActionButton setTitle:@"长按" forState:UIControlStateNormal];
    [_imageActionButton setTitle:@"网络" forState:UIControlStateNormal];
}

- (void)layoutSuccessActionButtonsAtY:(CGFloat)y side:(CGFloat)side width:(CGFloat)width {
    [self configureSuccessActionButtons];
    [self layoutButtons:@[_recordSwipeButton, _previewSwipeButton, _clearActionButton, _imageActionButton]
                      x:side
                      y:y
                  width:width
                 height:34.0
                    gap:7.0];
    [self styleSegmentButton:_recordSwipeButton selected:_imageActionMode == AnClickActionModeTap];
    [self styleSegmentButton:_previewSwipeButton selected:_imageActionMode == AnClickActionModeDoubleTap];
    [self styleSegmentButton:_clearActionButton selected:_imageActionMode == AnClickActionModeLongPress];
    [self styleSegmentButton:_imageActionButton selected:_imageActionMode == AnClickActionModeNetwork];
}

- (CGFloat)layoutRecognitionNetworkFieldsAtY:(CGFloat)y side:(CGFloat)side width:(CGFloat)width {
    _networkURLField.hidden = NO;
    _networkURLField.frame = CGRectMake(side, y, width, 40.0);

    [_networkMethodButton setTitle:(_networkUsesPost ? @"POST" : @"GET") forState:UIControlStateNormal];
    [self styleSegmentButton:_networkMethodButton selected:_networkUsesPost];
    _networkMethodButton.hidden = NO;
    _networkMethodButton.frame = CGRectMake(side, y + 46.0, width, 34.0);
    [self updateButtonShadowPath:_networkMethodButton];

    CGFloat nextY = y + 88.0;
    if (_networkUsesPost) {
        BOOL canUseOCRResult = _actionMode == AnClickActionModeOCR;
        AnClickOCRMatchMode ocrMatchMode = canUseOCRResult
            ? [self effectiveOCRMatchModeForText:_ocrTargetText ?: @""]
            : AnClickOCRMatchModeContains;
        if (canUseOCRResult) {
            _networkPostCustomButton.hidden = NO;
            _networkPostOCRResultButton.hidden = NO;
            [_networkPostCustomButton setTitle:@"原始内容" forState:UIControlStateNormal];
            [_networkPostOCRResultButton setTitle:@"键值JSON" forState:UIControlStateNormal];
            [self layoutButtons:@[_networkPostCustomButton, _networkPostOCRResultButton]
                              x:side
                              y:nextY
                          width:width
                         height:34.0
                            gap:10.0];
            [self styleSegmentButton:_networkPostCustomButton selected:!_networkPostBodyUsesOCRResult];
            [self styleSegmentButton:_networkPostOCRResultButton selected:_networkPostBodyUsesOCRResult];
            nextY += 42.0;
        }
        if (!(canUseOCRResult && _networkPostBodyUsesOCRResult)) {
            _networkPostBodyField.hidden = NO;
            NSString *postPlaceholder = @"POST参数 JSON/表单";
            if (canUseOCRResult) {
                postPlaceholder = @"原始POST 可用{{result}}";
            }
            [self setStyledPlaceholder:postPlaceholder forField:_networkPostBodyField alpha:0.25];
            _networkPostBodyField.frame = CGRectMake(side, nextY, width, 40.0);
            nextY += 50.0;
        } else {
            _networkPostExtraFieldsField.hidden = NO;
            [self setStyledPlaceholder:@"键=值 例content={{result}}&to_user=@all" forField:_networkPostExtraFieldsField alpha:0.25];
            _networkPostExtraFieldsField.frame = CGRectMake(side, nextY, width, 40.0);
            nextY += 50.0;
        }
    }
    return nextY;
}

- (NSString *)pointSummaryForMode:(AnClickActionMode)mode emptyTitle:(NSString *)emptyTitle {
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

- (void)layoutSingleField:(UITextField *)field caption:(UILabel *)caption title:(NSString *)title y:(CGFloat)y {
    CGFloat side = 18.0;
    CGFloat width = _panelView.bounds.size.width;
    caption.text = title;
    caption.hidden = NO;
    caption.frame = CGRectMake(side, y, width - side * 2.0, 22);
    field.hidden = NO;
    field.frame = CGRectMake(side, y + 26.0, width - side * 2.0, 46);
}

- (void)layoutDoubleTimingFieldsAtY:(CGFloat)y {
    CGFloat side = 18.0;
    CGFloat width = _panelView.bounds.size.width;
    CGFloat gap = 12.0;
    CGFloat fieldWidth = floor((width - side * 2.0 - gap) / 2.0);
    _delayCaptionLabel.text = @"延时执行（秒）";
    _repeatCaptionLabel.text = @"执行次数（次数）";
    _delayCaptionLabel.hidden = NO;
    _repeatCaptionLabel.hidden = NO;
    _delayCaptionLabel.frame = CGRectMake(side, y, fieldWidth, 20);
    _repeatCaptionLabel.frame = CGRectMake(side + fieldWidth + gap, y, fieldWidth, 20);
    _delayField.hidden = NO;
    _repeatField.hidden = NO;
    _delayField.frame = CGRectMake(side, y + 22.0, fieldWidth, 40);
    _repeatField.frame = CGRectMake(side + fieldWidth + gap, y + 22.0, fieldWidth, 40);
}

- (void)layoutImageFieldsAtY:(CGFloat)y {
    CGFloat side = 18.0;
    CGFloat width = _panelView.bounds.size.width;
    CGFloat gap = 8.0;
    CGFloat fieldWidth = floor((width - side * 2.0 - gap * 2.0) / 3.0);
    NSArray<UILabel *> *captions = @[_thresholdCaptionLabel, _delayCaptionLabel, _repeatCaptionLabel];
    NSArray<UITextField *> *fields = @[_thresholdField, _delayField, _repeatField];
    NSArray<NSString *> *titles = @[@"匹配阈值", @"延时秒", @"执行次数"];
    for (NSUInteger i = 0; i < captions.count; i++) {
        UILabel *caption = captions[i];
        UITextField *field = fields[i];
        CGFloat x = side + (fieldWidth + gap) * i;
        caption.text = titles[i];
        caption.hidden = NO;
        caption.frame = CGRectMake(x, y, fieldWidth, 20);
        field.hidden = NO;
        field.frame = CGRectMake(x, y + 22.0, fieldWidth, 38);
    }
}

- (void)layoutColorFieldsAtY:(CGFloat)y {
    CGFloat side = 18.0;
    CGFloat width = _panelView.bounds.size.width;
    CGFloat gap = 8.0;
    CGFloat fieldWidth = floor((width - side * 2.0 - gap * 2.0) / 3.0);
    NSArray<UILabel *> *captions = @[_thresholdCaptionLabel, _delayCaptionLabel, _repeatCaptionLabel];
    NSArray<UITextField *> *fields = @[_thresholdField, _delayField, _repeatField];
    NSArray<NSString *> *titles = @[@"颜色容差", @"延时秒", @"执行次数"];
    for (NSUInteger i = 0; i < captions.count; i++) {
        UILabel *caption = captions[i];
        UITextField *field = fields[i];
        CGFloat x = side + (fieldWidth + gap) * i;
        caption.text = titles[i];
        caption.hidden = NO;
        caption.frame = CGRectMake(x, y, fieldWidth, 20);
        field.hidden = NO;
        field.frame = CGRectMake(x, y + 22.0, fieldWidth, 38);
    }
}

- (void)layoutNetworkFieldsAtY:(CGFloat)y {
    CGFloat side = 18.0;
    CGFloat width = _panelView.bounds.size.width;
    CGFloat gap = 8.0;
    CGFloat fieldWidth = floor((width - side * 2.0 - gap * 2.0) / 3.0);
    NSArray<UILabel *> *captions = @[_thresholdCaptionLabel, _delayCaptionLabel, _repeatCaptionLabel];
    NSArray<UITextField *> *fields = @[_thresholdField, _delayField, _repeatField];
    NSString *repeatTitle = (_actionMode == AnClickActionModeNetwork && !_networkRequestOnly) ? @"判断次数" : @"执行次数";
    NSArray<NSString *> *titles = @[@"超时秒", @"延时秒", repeatTitle];
    for (NSUInteger i = 0; i < captions.count; i++) {
        UILabel *caption = captions[i];
        UITextField *field = fields[i];
        CGFloat x = side + (fieldWidth + gap) * i;
        caption.text = titles[i];
        caption.hidden = NO;
        caption.frame = CGRectMake(x, y, fieldWidth, 20);
        field.hidden = NO;
        field.frame = CGRectMake(x, y + 22.0, fieldWidth, 38);
    }
}

- (NSString *)targetColorSummary {
    if ([self effectiveTargetColorSamples].count == 0) {
        return @"截图放大取色";
    }
    return [self targetColorDetailedDescription];
}

- (UIColor *)targetUIColor {
    NSDictionary *anchor = [self effectiveTargetColorSamples].firstObject;
    if (!anchor) {
        return [UIColor colorWithWhite:1 alpha:0.10];
    }
    return [UIColor colorWithRed:MIN(255, MAX(0, [anchor[@"red"] integerValue])) / 255.0
                           green:MIN(255, MAX(0, [anchor[@"green"] integerValue])) / 255.0
                            blue:MIN(255, MAX(0, [anchor[@"blue"] integerValue])) / 255.0
                           alpha:1.0];
}

- (void)refreshEditorConfigControls {
    if (!_taskEditorVisible) {
        return;
    }

    [self hideAllConfigButtons];
    [self layoutEditorScaffold];
    _saveTaskButton.hidden = NO;
    _editorBackButton.hidden = NO;
    _cancelEditButton.hidden = NO;
    _collapseButton.hidden = NO;
    _editorTitleLabel.text = (_actionMode == AnClickActionModeNone) ? @"选择动作" : [self currentActionName];
    _descriptionField.hidden = NO;
    _descriptionCaptionLabel.hidden = NO;
    if (!_descriptionField.isFirstResponder) {
        _descriptionField.text = _actionDescription ?: @"";
    }
    if (!_ocrTargetField.isFirstResponder) {
        _ocrTargetField.text = _ocrTargetText ?: @"";
    }
    if (!_networkURLField.isFirstResponder) {
        _networkURLField.text = _networkURL ?: @"";
    }
    if (!_networkContainsField.isFirstResponder) {
        _networkContainsField.text = _networkContainsText ?: @"";
    }
    if (!_networkFalseField.isFirstResponder) {
        _networkFalseField.text = _networkFalseText ?: @"";
    }
    if (!_networkPostBodyField.isFirstResponder) {
        _networkPostBodyField.text = _networkPostBody ?: @"";
    }
    if (!_networkPostExtraFieldsField.isFirstResponder) {
        _networkPostExtraFieldsField.text = _networkPostExtraFields ?: @"";
    }
    [self refreshTimingFieldsIfNeeded];
    CGFloat configTopY = [self editorConfigTopY];

    if (_actionMode == AnClickActionModeNone) {
        _descriptionCaptionLabel.hidden = YES;
        _descriptionField.hidden = YES;
        _saveTaskButton.enabled = NO;
        _saveTaskButton.alpha = 0.45;
        _statusLabel.text = @"请选择动作类型";
    } else if (_actionMode == AnClickActionModeImage) {
        _saveTaskButton.enabled = YES;
        _saveTaskButton.alpha = 1.0;

        CGFloat side = 18.0;
        CGFloat width = _panelView.bounds.size.width;
        CGFloat contentWidth = width - side * 2.0;
        _primaryConfigLabel.text = @"识别图像";
        _primaryConfigLabel.hidden = NO;
        _primaryConfigLabel.frame = CGRectMake(side, configTopY, contentWidth, 20);
        [_captureButton setTitle:@"截图选择识别图像" forState:UIControlStateNormal];
        _captureButton.hidden = NO;
        _captureButton.frame = CGRectMake(side, configTopY + 22.0, contentWidth, 40);
        _captureButton.backgroundColor = [UIColor colorWithRed:0.31 green:0.22 blue:0.12 alpha:0.82];
        _captureButton.layer.borderColor = [UIColor colorWithRed:0.94 green:0.55 blue:0.12 alpha:0.94].CGColor;
        [_captureButton setTitleColor:[UIColor colorWithRed:1.0 green:0.63 blue:0.16 alpha:1.0] forState:UIControlStateNormal];
        [self updateButtonShadowPath:_captureButton];

        BOOL roomy = _panelView.bounds.size.height >= 580.0;
        CGFloat previewHeight = roomy ? 58.0 : 44.0;
        CGFloat previewY = configTopY + 68.0;
        _previewView.hidden = NO;
        _previewView.frame = CGRectMake(side, previewY, contentWidth, previewHeight);

        _secondaryConfigLabel.text = @"点击模式";
        _secondaryConfigLabel.hidden = NO;
        CGFloat modeLabelY = previewY + previewHeight + 6.0;
        _secondaryConfigLabel.frame = CGRectMake(side, modeLabelY, contentWidth, 20);
        [_playButton setTitle:@"识别图像位置" forState:UIControlStateNormal];
        [_pickPointButton setTitle:_imageUsesMatchPoint ? @"自定义位置" : [self pointSummaryForMode:AnClickActionModeImage emptyTitle:@"自定义位置"] forState:UIControlStateNormal];
        CGFloat modeButtonY = modeLabelY + 22.0;
        [self layoutButtons:@[_playButton, _pickPointButton] x:side y:modeButtonY width:contentWidth height:34 gap:10.0];
        [self styleSegmentButton:_playButton selected:_imageUsesMatchPoint];
        [self styleSegmentButton:_pickPointButton selected:!_imageUsesMatchPoint];

        _tertiaryConfigLabel.text = @"成功后动作类型";
        _tertiaryConfigLabel.hidden = NO;
        CGFloat actionLabelY = modeButtonY + 40.0;
        _tertiaryConfigLabel.frame = CGRectMake(side, actionLabelY, contentWidth, 20);
        CGFloat actionButtonY = actionLabelY + 22.0;
        [self layoutSuccessActionButtonsAtY:actionButtonY side:side width:contentWidth];

        CGFloat fieldsY = actionButtonY + 42.0;
        if (_imageActionMode == AnClickActionModeNetwork) {
            fieldsY = [self layoutRecognitionNetworkFieldsAtY:fieldsY side:side width:contentWidth];
        }
        [self layoutImageFieldsAtY:fieldsY];
    } else if (_actionMode == AnClickActionModeOCR) {
        _saveTaskButton.enabled = YES;
        _saveTaskButton.alpha = 1.0;
        CGFloat side = 18.0;
        CGFloat width = _panelView.bounds.size.width;
        CGFloat contentWidth = width - side * 2.0;
        AnClickOCRMatchMode effectiveMatchMode = [self effectiveOCRMatchModeForText:_ocrTargetText ?: @""];
        _primaryConfigLabel.text = effectiveMatchMode == AnClickOCRMatchModeRegex ? @"正则表达式" : @"目标文字";
        _primaryConfigLabel.hidden = NO;
        _primaryConfigLabel.frame = CGRectMake(side, configTopY, contentWidth, 20);
        [self setStyledPlaceholder:(effectiveMatchMode == AnClickOCRMatchModeRegex ? @"输入正则表达式" : @"目标文字")
                           forField:_ocrTargetField
                              alpha:0.25];
        _ocrTargetField.hidden = NO;
        _ocrTargetField.frame = CGRectMake(side, configTopY + 22.0, contentWidth, 40);

        _ocrContainsMatchModeButton.hidden = NO;
        _ocrRegexMatchModeButton.hidden = NO;
        [_ocrContainsMatchModeButton setTitle:@"包含匹配" forState:UIControlStateNormal];
        [_ocrRegexMatchModeButton setTitle:@"正则匹配" forState:UIControlStateNormal];
        [self layoutButtons:@[_ocrContainsMatchModeButton, _ocrRegexMatchModeButton] x:side y:configTopY + 72.0 width:contentWidth height:36 gap:10.0];
        [self styleSegmentButton:_ocrContainsMatchModeButton selected:effectiveMatchMode == AnClickOCRMatchModeContains];
        [self styleSegmentButton:_ocrRegexMatchModeButton selected:effectiveMatchMode == AnClickOCRMatchModeRegex];
        [self updateButtonShadowPath:_ocrContainsMatchModeButton];
        [self updateButtonShadowPath:_ocrRegexMatchModeButton];

        _secondaryConfigLabel.text = @"点击模式";
        _secondaryConfigLabel.hidden = NO;
        CGFloat modeLabelY = configTopY + 118.0;
        _secondaryConfigLabel.frame = CGRectMake(side, modeLabelY, contentWidth, 20);
        [_playButton setTitle:@"识字位置" forState:UIControlStateNormal];
        [_pickPointButton setTitle:_ocrUsesMatchPoint ? @"自定义位置" : [self pointSummaryForMode:AnClickActionModeOCR emptyTitle:@"自定义位置"] forState:UIControlStateNormal];
        CGFloat modeButtonY = modeLabelY + 22.0;
        [self layoutButtons:@[_playButton, _pickPointButton] x:side y:modeButtonY width:contentWidth height:34 gap:10.0];
        [self styleSegmentButton:_playButton selected:_ocrUsesMatchPoint];
        [self styleSegmentButton:_pickPointButton selected:!_ocrUsesMatchPoint];

        _tertiaryConfigLabel.text = @"成功后动作类型";
        _tertiaryConfigLabel.hidden = NO;
        CGFloat actionLabelY = modeButtonY + 42.0;
        _tertiaryConfigLabel.frame = CGRectMake(side, actionLabelY, contentWidth, 20);
        CGFloat actionButtonY = actionLabelY + 22.0;
        [self layoutSuccessActionButtonsAtY:actionButtonY side:side width:contentWidth];
        CGFloat fieldsY = actionButtonY + 44.0;
        if (_imageActionMode == AnClickActionModeNetwork) {
            fieldsY = [self layoutRecognitionNetworkFieldsAtY:fieldsY side:side width:contentWidth];
        }
        [self layoutDoubleTimingFieldsAtY:fieldsY];
    } else if (_actionMode == AnClickActionModeColor) {
        _saveTaskButton.enabled = YES;
        _saveTaskButton.alpha = 1.0;
        CGFloat side = 18.0;
        CGFloat width = _panelView.bounds.size.width;
        CGFloat contentWidth = width - side * 2.0;
        _primaryConfigLabel.text = @"目标颜色";
        _primaryConfigLabel.hidden = NO;
        _primaryConfigLabel.frame = CGRectMake(side, configTopY, contentWidth, 20);

        CGFloat swatchSize = 40.0;
        _colorPreviewView.hidden = NO;
        _colorPreviewView.frame = CGRectMake(side, configTopY + 22.0, swatchSize, swatchSize);
        _colorPreviewView.backgroundColor = [self targetUIColor];

        [_pickPointButton setTitle:[self targetColorSummary] forState:UIControlStateNormal];
        [self styleNormalButton:_pickPointButton];
        _pickPointButton.hidden = NO;
        _pickPointButton.frame = CGRectMake(side + swatchSize + 10.0, configTopY + 22.0, contentWidth - swatchSize - 10.0, 40);
        [self updateButtonShadowPath:_pickPointButton];

        _secondaryConfigLabel.text = @"成功后动作类型";
        _secondaryConfigLabel.hidden = NO;
        _secondaryConfigLabel.frame = CGRectMake(side, configTopY + 72.0, contentWidth, 20);
        CGFloat actionButtonY = configTopY + 94.0;
        [self layoutSuccessActionButtonsAtY:actionButtonY side:side width:contentWidth];
        CGFloat fieldsY = actionButtonY + 44.0;
        if (_imageActionMode == AnClickActionModeNetwork) {
            fieldsY = [self layoutRecognitionNetworkFieldsAtY:fieldsY side:side width:contentWidth];
        }
        [self layoutColorFieldsAtY:fieldsY];
    } else if (_actionMode == AnClickActionModeNetwork) {
        _saveTaskButton.enabled = YES;
        _saveTaskButton.alpha = 1.0;
        CGFloat side = 18.0;
        CGFloat width = _panelView.bounds.size.width;
        CGFloat contentWidth = width - side * 2.0;

        _primaryConfigLabel.text = @"请求链接";
        _primaryConfigLabel.hidden = NO;
        _primaryConfigLabel.frame = CGRectMake(side, configTopY, contentWidth, 20);
        _networkURLField.hidden = NO;
        _networkURLField.frame = CGRectMake(side, configTopY + 22.0, contentWidth, 40);

        BOOL roomyNetworkLayout = _panelView.bounds.size.height >= 640.0;
        [_networkMethodButton setTitle:(_networkUsesPost ? @"POST" : @"GET") forState:UIControlStateNormal];
        [self styleSegmentButton:_networkMethodButton selected:_networkUsesPost];
        _networkMethodButton.hidden = NO;
        _networkMethodButton.frame = CGRectMake(side, configTopY + 72.0, contentWidth, 36);
        [self updateButtonShadowPath:_networkMethodButton];

        CGFloat networkModeY = configTopY + 118.0;
        if (_networkUsesPost) {
            _networkPostBodyField.hidden = NO;
            [self setStyledPlaceholder:@"POST参数 JSON/表单" forField:_networkPostBodyField alpha:0.25];
            _networkPostBodyField.frame = CGRectMake(side, networkModeY, contentWidth, 40);
            networkModeY += 50.0;
        }
        [_networkRequestModeButton setTitle:_networkRequestOnly ? @"当前：仅请求" : @"当前：返回判断" forState:UIControlStateNormal];
        [self styleSegmentButton:_networkRequestModeButton selected:_networkRequestOnly];
        _networkRequestModeButton.hidden = NO;
        _networkRequestModeButton.frame = CGRectMake(side, networkModeY, contentWidth, 36);
        [self updateButtonShadowPath:_networkRequestModeButton];
        CGFloat conditionTopY = networkModeY + 46.0;
        if (!_networkRequestOnly) {
            [_networkRetryModeButton setTitle:_networkRetryForever ? @"当前：一直判断" : @"当前：判断次数" forState:UIControlStateNormal];
            [self styleSegmentButton:_networkRetryModeButton selected:_networkRetryForever];
            _networkRetryModeButton.hidden = NO;
            _networkRetryModeButton.frame = CGRectMake(side, conditionTopY, contentWidth, 36);
            [self updateButtonShadowPath:_networkRetryModeButton];
            conditionTopY += 46.0;
        }

        _secondaryConfigLabel.text = roomyNetworkLayout ? @"返回包含这些就运行（关键字/正则）" : @"包含就运行";
        _secondaryConfigLabel.hidden = _networkRequestOnly;
        _tertiaryConfigLabel.text = roomyNetworkLayout ? @"返回包含这些就不运行（关键字/正则）" : @"包含就不运行";
        _tertiaryConfigLabel.hidden = _networkRequestOnly;
        _networkContainsField.hidden = _networkRequestOnly;
        _networkFalseField.hidden = _networkRequestOnly;
        [_previewActionButton setTitle:@"测试请求" forState:UIControlStateNormal];
        [_runManualButton setTitle:_networkRequestOnly ? @"执行请求" : @"执行判断" forState:UIControlStateNormal];
        [self styleNormalButton:_previewActionButton];
        [self styleNormalButton:_runManualButton];

        if (_networkRequestOnly) {
            [self layoutButtons:@[_previewActionButton, _runManualButton] x:side y:conditionTopY width:contentWidth height:36 gap:10.0];
            [self layoutNetworkFieldsAtY:conditionTopY + 52.0];
        } else if (roomyNetworkLayout) {
            _secondaryConfigLabel.frame = CGRectMake(side, conditionTopY, contentWidth, 20);
            _networkContainsField.frame = CGRectMake(side, conditionTopY + 22.0, contentWidth, 40);
            _tertiaryConfigLabel.frame = CGRectMake(side, conditionTopY + 72.0, contentWidth, 20);
            _networkFalseField.frame = CGRectMake(side, conditionTopY + 94.0, contentWidth, 40);
            [self layoutButtons:@[_previewActionButton, _runManualButton] x:side y:conditionTopY + 146.0 width:contentWidth height:36 gap:10.0];
            [self layoutNetworkFieldsAtY:conditionTopY + 198.0];
        } else {
            CGFloat gap = 10.0;
            CGFloat halfWidth = floor((contentWidth - gap) / 2.0);
            _secondaryConfigLabel.frame = CGRectMake(side, conditionTopY, halfWidth, 20);
            _tertiaryConfigLabel.frame = CGRectMake(side + halfWidth + gap, conditionTopY, halfWidth, 20);
            _networkContainsField.frame = CGRectMake(side, conditionTopY + 22.0, halfWidth, 40);
            _networkFalseField.frame = CGRectMake(side + halfWidth + gap, conditionTopY + 22.0, halfWidth, 40);
            [self layoutButtons:@[_previewActionButton, _runManualButton] x:side y:conditionTopY + 74.0 width:contentWidth height:36 gap:10.0];
            [self layoutNetworkFieldsAtY:conditionTopY + 124.0];
        }
    } else if (_actionMode == AnClickActionModeMacro) {
        _saveTaskButton.enabled = YES;
        _saveTaskButton.alpha = 1.0;
        CGFloat side = 18.0;
        CGFloat width = _panelView.bounds.size.width;
        CGFloat contentWidth = width - side * 2.0;
        BOOL recording = [AnClickRecorder shared].isRecording;
        _primaryConfigLabel.text = @"录制回放";
        _primaryConfigLabel.hidden = NO;
        _primaryConfigLabel.frame = CGRectMake(side, configTopY, contentWidth, 20);
        [_macroRecordButton setTitle:recording ? @"停止录制" : (_recordedMacroEvents.count > 0 ? @"重新录制" : @"开始录制") forState:UIControlStateNormal];
        [_macroPlayButton setTitle:_recordedMacroEvents.count > 0 ? @"回放录制" : @"暂无录制" forState:UIControlStateNormal];
        _macroPlayButton.enabled = _recordedMacroEvents.count > 0 && !recording;
        _macroPlayButton.alpha = _macroPlayButton.enabled ? 1.0 : 0.45;
        [self styleRecordButton:_macroRecordButton active:recording];
        [self styleNormalButton:_macroPlayButton];
        [self layoutButtons:@[_macroRecordButton, _macroPlayButton] x:side y:configTopY + 22.0 width:contentWidth height:40 gap:10.0];
        [self layoutDoubleTimingFieldsAtY:configTopY + 80.0];
    } else if (_actionMode == AnClickActionModeSwipe) {
        _saveTaskButton.enabled = YES;
        _saveTaskButton.alpha = 1.0;
        CGFloat side = 18.0;
        CGFloat width = _panelView.bounds.size.width;
        CGFloat contentWidth = width - side * 2.0;
        _primaryConfigLabel.text = @"自定义位置";
        _primaryConfigLabel.hidden = NO;
        _primaryConfigLabel.frame = CGRectMake(side, configTopY, contentWidth, 20);
        NSString *pickTitle = (_hasManualSwipeAnchor && !_hasManualSwipeEndPoint) ? @"继续选择终点" : [self pointSummaryForMode:AnClickActionModeSwipe emptyTitle:@"选择滑动起点"];
        [_pickPointButton setTitle:pickTitle forState:UIControlStateNormal];
        [self styleNormalButton:_pickPointButton];
        _pickPointButton.hidden = NO;
        _pickPointButton.frame = CGRectMake(side, configTopY + 22.0, contentWidth, 40);
        [self updateButtonShadowPath:_pickPointButton];
        [_swipeRecordButton setTitle:@"录制滑动轨迹" forState:UIControlStateNormal];
        [_previewActionButton setTitle:@"预览轨迹" forState:UIControlStateNormal];
        [self styleNormalButton:_swipeRecordButton];
        [self styleNormalButton:_previewActionButton];
        [self layoutButtons:@[_swipeRecordButton, _previewActionButton] x:side y:configTopY + 72.0 width:contentWidth height:36 gap:10.0];
        [self layoutDoubleTimingFieldsAtY:configTopY + 124.0];
    } else {
        _saveTaskButton.enabled = YES;
        _saveTaskButton.alpha = 1.0;
        CGFloat side = 18.0;
        CGFloat width = _panelView.bounds.size.width;
        CGFloat contentWidth = width - side * 2.0;
        _primaryConfigLabel.text = @"自定义位置";
        _primaryConfigLabel.hidden = NO;
        _primaryConfigLabel.frame = CGRectMake(side, configTopY, contentWidth, 20);
        [_pickPointButton setTitle:[self pointSummaryForMode:_actionMode emptyTitle:@"选择点击位置"] forState:UIControlStateNormal];
        [self styleNormalButton:_pickPointButton];
        _pickPointButton.hidden = NO;
        _pickPointButton.frame = CGRectMake(side, configTopY + 22.0, contentWidth, 40);
        [self updateButtonShadowPath:_pickPointButton];
        [_previewActionButton setTitle:@"预览位置" forState:UIControlStateNormal];
        [_runManualButton setTitle:@"测试执行" forState:UIControlStateNormal];
        [self styleNormalButton:_previewActionButton];
        [self styleNormalButton:_runManualButton];
        [self layoutButtons:@[_previewActionButton, _runManualButton] x:side y:configTopY + 72.0 width:contentWidth height:36 gap:10.0];
        [self layoutDoubleTimingFieldsAtY:configTopY + 124.0];
    }
    [self refreshTemplatePreview];
    [self refreshEditorContentScrollSize];
}

- (void)updateStatusForCurrentConfig {
    if (_actionMode == AnClickActionModeNone) {
        _statusLabel.text = @"请选择动作";
        return;
    }

    if (_actionMode == AnClickActionModeImage) {
        NSString *templateState = [self currentTemplateExists] ? @"有模板" : @"先截图";
        NSString *targetState = _imageUsesMatchPoint ? @"识别点" : @"先取点击点";
        if (!_imageUsesMatchPoint && [self hasManualPointForMode:AnClickActionModeImage]) {
            targetState = @"已取点击点";
        }
        _statusLabel.text = [NSString stringWithFormat:@"识图 %@ %@ 后%@",
                             templateState,
                             targetState,
                             _imageActionMode == AnClickActionModeNetwork
                                ? [NSString stringWithFormat:@"%@网络", [self normalizedNetworkMethodFromPostFlag:_networkUsesPost]]
                                : [self actionNameForMode:_imageActionMode]];
        return;
    }

    if (_actionMode == AnClickActionModeOCR) {
        AnClickOCRMatchMode matchMode = [self effectiveOCRMatchModeForText:_ocrTargetText ?: @""];
        if (matchMode == AnClickOCRMatchModeRegex &&
            _ocrTargetText.length > 0 &&
            ![self ocrRegexPatternIsValid:_ocrTargetText]) {
            _statusLabel.text = @"正则表达式格式错误";
            return;
        }
        NSString *targetState = [self ocrDisplayTextForText:_ocrTargetText matchMode:matchMode];
        NSString *pointState = _ocrUsesMatchPoint ? @"识别点" : ([self hasManualPointForMode:AnClickActionModeOCR] ? @"自定义点" : @"先取点击点");
        NSString *networkActionName = [self normalizedNetworkMethodFromPostFlag:_networkUsesPost];
        if (_networkUsesPost && _networkPostBodyUsesOCRResult) {
            networkActionName = @"POST键值";
        }
        _statusLabel.text = [NSString stringWithFormat:@"识字 %@ %@ %@ 后%@",
                             [self ocrMatchModeTitleForMode:matchMode],
                             targetState,
                             pointState,
                             _imageActionMode == AnClickActionModeNetwork
                                ? [NSString stringWithFormat:@"%@网络", networkActionName]
                                : [self actionNameForMode:_imageActionMode]];
        return;
    }

    if (_actionMode == AnClickActionModeColor) {
        NSString *targetState = [self targetColorShortDescription];
        _statusLabel.text = [NSString stringWithFormat:@"识色 %@ 容差%.0f 后%@",
                             targetState,
                             _colorTolerance,
                             _imageActionMode == AnClickActionModeNetwork
                                ? [NSString stringWithFormat:@"%@网络", [self normalizedNetworkMethodFromPostFlag:_networkUsesPost]]
                                : [self actionNameForMode:_imageActionMode]];
        return;
    }

    if (_actionMode == AnClickActionModeNetwork) {
        NSString *urlState = _networkURL.length > 0 ? @"有链接" : @"先填链接";
        BOOL oneShot = _networkRequestOnly;
        NSString *conditionState = nil;
        if (oneShot) {
            conditionState = @"请求一次";
        } else if (_networkContainsText.length > 0) {
            conditionState = [NSString stringWithFormat:@"包含%@就运行", _networkContainsText];
        } else if (_networkFalseText.length > 0) {
            conditionState = @"未命中不运行就继续";
        } else {
            conditionState = @"先填判断条件";
        }
        if (_networkFalseText.length > 0) {
            conditionState = [conditionState stringByAppendingFormat:@" 包含%@就不运行", _networkFalseText];
        }
        if (!oneShot && [self currentNetworkJudgementHasCondition]) {
            conditionState = [conditionState stringByAppendingFormat:@" %@", _networkRetryForever ? @"一直判断" : [NSString stringWithFormat:@"判断%ld次", (long)MAX(1, _actionRepeatCount)]];
        }
        _statusLabel.text = [NSString stringWithFormat:@"网络 %@ %@ %@", [self normalizedNetworkMethodFromPostFlag:_networkUsesPost], urlState, conditionState];
        return;
    }

    if (_actionMode == AnClickActionModeSwipe) {
        NSString *state = @"先取起点";
        if (_hasManualSwipeAnchor && _hasManualSwipeEndPoint) {
            state = @"已设起终点";
        } else if (_hasManualSwipeAnchor) {
            state = @"再取终点";
        } else if (_recordedSwipePoints.count >= 2) {
            state = @"已录轨迹";
        }
        _statusLabel.text = [NSString stringWithFormat:@"滑动 %@", state];
        return;
    }

    if (_actionMode == AnClickActionModeMacro) {
        if ([AnClickRecorder shared].isRecording) {
            _statusLabel.text = @"录制中  点悬浮停止";
        } else if (_recordedMacroEvents.count > 0) {
            _statusLabel.text = [NSString stringWithFormat:@"已录制 %lu步", (unsigned long)_recordedMacroEvents.count];
        } else {
            _statusLabel.text = @"先开始录制";
        }
        return;
    }

    NSString *name = [self currentActionName];
    if ([self hasManualPointForMode:_actionMode]) {
        _statusLabel.text = [NSString stringWithFormat:@"%@ 已取点", name];
    } else {
        _statusLabel.text = [NSString stringWithFormat:@"%@ 先取点", name];
    }
}

- (void)handleSecondaryConfigButton {
    if (_actionMode == AnClickActionModeImage) {
        _imageUsesMatchPoint = YES;
        [self refreshEditorConfigControls];
        [self updateStatusForCurrentConfig];
        [self autosaveSelectedTaskIfPossible];
    } else if (_actionMode == AnClickActionModeOCR) {
        _ocrUsesMatchPoint = YES;
        [self refreshEditorConfigControls];
        [self updateStatusForCurrentConfig];
        [self autosaveSelectedTaskIfPossible];
    }
}

- (void)cycleImageActionMode {
    NSArray<NSNumber *> *modes = [self imageActionModes];
    NSUInteger currentIndex = 0;
    for (NSUInteger i = 0; i < modes.count; i++) {
        if ([(NSNumber *)modes[i] integerValue] == _imageActionMode) {
            currentIndex = i;
            break;
        }
    }
    NSUInteger nextIndex = (currentIndex + 1) % modes.count;
    _imageActionMode = (AnClickActionMode)[(NSNumber *)modes[nextIndex] integerValue];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
    [self autosaveSelectedTaskIfPossible];
}

- (void)selectImageActionMode:(UIButton *)sender {
    _imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)sender.tag];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
    [self autosaveSelectedTaskIfPossible];
}

- (void)decreaseActionDelay {
    _actionDelay = MAX(0.0, _actionDelay - 0.1);
    _actionDelay = round(_actionDelay * 10.0) / 10.0;
    [self updateStatusForCurrentConfig];
}

- (void)increaseActionDelay {
    _actionDelay = MIN(30.0, _actionDelay + 0.1);
    _actionDelay = round(_actionDelay * 10.0) / 10.0;
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
}

- (void)rememberTaskRunResumePointAtIndex:(NSUInteger)index inGlobalNetworkGate:(BOOL)inGlobalNetworkGate scheduled:(BOOL)scheduled {
    _taskRunResumeIndex = index;
    _taskRunResumeCycle = _currentGlobalRunCycle;
    _taskRunResumeInGlobalNetworkGate = inGlobalNetworkGate;
    _taskRunResumeScheduled = scheduled;
}

- (void)pauseTaskRunForForegroundLoss {
    if (!_taskRunActive) {
        return;
    }

    _taskRunActive = NO;
    _taskRunPausedForForeground = YES;
    _taskRunResumeCycle = _currentGlobalRunCycle;
    _taskRunGeneration++;
    _statusLabel.text = @"应用切出暂停";
    _volumeShortcutRunSuppressToasts = NO;
    [self refreshCollapsedButtonTitle];
    [self refreshTaskList];
}

- (void)cleanupScreenInteractionStateRestoringPanel:(BOOL)restorePanel {
    [self invalidatePendingPanelRestore];

    [_captureOverlay removeFromSuperview];
    _captureOverlay = nil;
    _captureScrollView = nil;
    _captureImageView = nil;
    _selectionView = nil;
    _captureSnapshot = nil;
    _captureDrawingSelection = NO;

    [_pointPickOverlay removeFromSuperview];
    _pointPickOverlay = nil;
    _pointPickWindow.hidden = YES;
    _pointPickWindow = nil;
    _pointPickScrollView = nil;
    _pointPickImageView = nil;
    _pointCursorView = nil;
    _pointPickToolbar = nil;
    _pointCoordinateLabel = nil;
    _pointPickSnapshot = nil;
    _pointPickHostWindow = nil;
    _hasPendingPointPickPoint = NO;
    _pickingSwipeEndPoint = NO;
    _pointPickPanStartedOnToolbar = NO;

    _colorPickWindow.hidden = YES;
    _colorPickWindow = nil;
    _colorPickScrollView = nil;
    _colorPickImageView = nil;
    _colorPickCursorView = nil;
    _colorPickToolbar = nil;
    _colorPickListView = nil;
    _colorPickInfoLabel = nil;
    _colorPickSwatchView = nil;
    _colorPickDeleteButton = nil;
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

    if ([AnClickFakeTouch isHolding]) {
        [AnClickFakeTouch cancelHold];
    }
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
    _statusLabel.text = resumeInGlobalNetworkGate ? @"恢复网络监控" : @"恢复播放";
    [self showToast:_statusLabel.text];
    [self refreshTaskList];
    [self collapsePanel];

    if (resumeInGlobalNetworkGate) {
        [self rememberTaskRunResumePointAtIndex:0 inGlobalNetworkGate:YES scheduled:scheduled];
        [self monitorGlobalNetworkGateWithHostWindow:hostWindow scheduled:scheduled generation:runGeneration];
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

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    _statusLabel.text = @"截图中";
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.16 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf->_captureSnapshot = [AnClickCore captureCurrentWindowImage];
        if (!strongSelf->_captureSnapshot.CGImage) {
            [strongSelf restorePanelAfterExternalTap];
            strongSelf->_statusLabel.text = @"截图失败";
            return;
        }
        [strongSelf showCaptureOverlayInWindow:hostWindow];
    });
}

- (void)showCaptureOverlayInWindow:(UIWindow *)hostWindow {
    [_captureOverlay removeFromSuperview];

    _captureOverlay = [[UIView alloc] initWithFrame:hostWindow.bounds];
    _captureOverlay.backgroundColor = UIColor.blackColor;
    _captureOverlay.userInteractionEnabled = YES;

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:_captureOverlay.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.delegate = self;
    scrollView.backgroundColor = UIColor.blackColor;
    scrollView.minimumZoomScale = 1.0;
    scrollView.maximumZoomScale = 8.0;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.panGestureRecognizer.minimumNumberOfTouches = 2;
    [_captureOverlay addSubview:scrollView];
    _captureScrollView = scrollView;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:_captureSnapshot];
    imageView.frame = CGRectMake(0, 0, _captureSnapshot.size.width, _captureSnapshot.size.height);
    imageView.userInteractionEnabled = YES;
    [scrollView addSubview:imageView];
    _captureImageView = imageView;
    scrollView.contentSize = imageView.bounds.size;
    [self updateCaptureZoomForCurrentBounds];
    scrollView.zoomScale = scrollView.minimumZoomScale;
    [self centerCaptureImageContent];

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(12, 54, hostWindow.bounds.size.width - 24, 42)];
    hint.text = @"双指缩放移动，单指框选模板区域";
    hint.textColor = UIColor.whiteColor;
    hint.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    hint.adjustsFontSizeToFitWidth = YES;
    hint.textAlignment = NSTextAlignmentCenter;
    [_captureOverlay addSubview:hint];

    _selectionView = [[UIView alloc] initWithFrame:CGRectZero];
    _selectionView.backgroundColor = UIColor.clearColor;
    _selectionView.layer.borderColor = UIColor.systemYellowColor.CGColor;
    _selectionView.layer.borderWidth = 2.0;
    _selectionView.userInteractionEnabled = YES;
    _selectionView.hidden = YES;
    [imageView addSubview:_selectionView];

    UIPanGestureRecognizer *movePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSelectionPan:)];
    movePan.maximumNumberOfTouches = 1;
    [_selectionView addGestureRecognizer:movePan];

    UIPanGestureRecognizer *drawPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCaptureDrawPan:)];
    drawPan.maximumNumberOfTouches = 1;
    drawPan.cancelsTouchesInView = NO;
    [imageView addGestureRecognizer:drawPan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCaptureOverlayTap:)];
    tap.cancelsTouchesInView = NO;
    [_captureOverlay addGestureRecognizer:tap];

    UIButton *saveButton = [self overlayButtonWithTitle:@"保存" action:@selector(saveSelectedTemplate)];
    saveButton.tag = 3001;
    saveButton.frame = CGRectMake(16, hostWindow.bounds.size.height - 70, 86, 44);
    saveButton.hidden = YES;
    [_captureOverlay addSubview:saveButton];

    UIButton *cancelButton = [self overlayButtonWithTitle:@"取消" action:@selector(cancelTemplateCapture)];
    cancelButton.tag = 3002;
    cancelButton.frame = CGRectMake(hostWindow.bounds.size.width - 102, hostWindow.bounds.size.height - 70, 86, 44);
    cancelButton.hidden = NO;
    [_captureOverlay addSubview:cancelButton];

    [hostWindow addSubview:_captureOverlay];
    [self layoutCaptureActionButtonsAvoidingSelection];
}

- (UIButton *)overlayButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    button.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.15 alpha:0.94];
    button.layer.cornerRadius = 5;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    button.layer.borderWidth = 1;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (CGRect)clampedSelectionFrame:(CGRect)frame {
    CGRect bounds = _captureImageView ? _captureImageView.bounds : _captureOverlay.bounds;
    CGFloat minSide = 8.0;
    CGFloat maxWidth = MAX(minSide, bounds.size.width);
    CGFloat maxHeight = MAX(minSide, bounds.size.height);
    frame.size.width = MIN(MAX(frame.size.width, minSide), maxWidth);
    frame.size.height = MIN(MAX(frame.size.height, minSide), maxHeight);
    frame.origin.x = MIN(MAX(frame.origin.x, 0.0), bounds.size.width - frame.size.width);
    frame.origin.y = MIN(MAX(frame.origin.y, 0.0), bounds.size.height - frame.size.height);
    return frame;
}

- (CGRect)selectionFrameFromPoint:(CGPoint)startPoint toPoint:(CGPoint)endPoint {
    CGRect rawFrame = CGRectStandardize(CGRectMake(startPoint.x,
                                                   startPoint.y,
                                                   endPoint.x - startPoint.x,
                                                   endPoint.y - startPoint.y));
    return [self clampedSelectionFrame:rawFrame];
}

- (void)setCaptureActionButtonsHidden:(BOOL)hidden {
    UIView *saveButton = [_captureOverlay viewWithTag:3001];
    UIView *cancelButton = [_captureOverlay viewWithTag:3002];
    saveButton.hidden = hidden;
    cancelButton.hidden = hidden;
}

- (void)layoutCaptureActionButtonsAvoidingSelection {
    if (!_captureOverlay) {
        return;
    }

    UIView *saveButton = [_captureOverlay viewWithTag:3001];
    UIView *cancelButton = [_captureOverlay viewWithTag:3002];
    if (!saveButton || !cancelButton) {
        return;
    }

    UIEdgeInsets safeInsets = [self overlaySafeAreaInsetsForView:_captureOverlay window:_captureOverlay.window];
    CGFloat margin = 14.0;
    CGFloat gap = 12.0;
    CGFloat buttonWidth = 86.0;
    CGFloat buttonHeight = 44.0;
    CGFloat bottomY = _captureOverlay.bounds.size.height - buttonHeight - MAX(margin, safeInsets.bottom + margin);
    CGFloat cancelX = _captureOverlay.bounds.size.width - safeInsets.right - margin - buttonWidth;
    cancelButton.frame = CGRectMake(cancelX, bottomY, buttonWidth, buttonHeight);

    if (!_selectionView || _selectionView.hidden) {
        saveButton.hidden = YES;
        cancelButton.hidden = NO;
        return;
    }

    CGRect selectionFrame = [_selectionView.superview convertRect:_selectionView.frame toView:_captureOverlay];
    CGFloat totalWidth = buttonWidth * 2.0 + gap;
    CGFloat minX = safeInsets.left + margin;
    CGFloat maxX = _captureOverlay.bounds.size.width - safeInsets.right - totalWidth - margin;
    CGFloat x = MIN(MAX(CGRectGetMidX(selectionFrame) - totalWidth * 0.5, minX), maxX);

    CGFloat belowY = CGRectGetMaxY(selectionFrame) + margin;
    CGFloat aboveY = CGRectGetMinY(selectionFrame) - buttonHeight - margin;
    CGFloat y = 0.0;
    CGFloat minY = MAX(margin, safeInsets.top + margin);
    CGFloat maxY = _captureOverlay.bounds.size.height - buttonHeight - MAX(margin, safeInsets.bottom + margin);
    if (belowY <= maxY) {
        y = belowY;
    } else if (aboveY >= minY) {
        y = aboveY;
    } else {
        y = maxY;
    }

    saveButton.frame = CGRectMake(x, y, buttonWidth, buttonHeight);
    cancelButton.frame = CGRectMake(x + buttonWidth + gap, y, buttonWidth, buttonHeight);
    saveButton.hidden = NO;
    cancelButton.hidden = NO;
}

- (void)handleCaptureOverlayTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded || !_captureOverlay) {
        return;
    }

    CGPoint point = [recognizer locationInView:_captureOverlay];
    UIView *saveButton = [_captureOverlay viewWithTag:3001];
    UIView *cancelButton = [_captureOverlay viewWithTag:3002];
    if (saveButton && !saveButton.hidden && CGRectContainsPoint(CGRectInset(saveButton.frame, -8.0, -8.0), point)) {
        [self saveSelectedTemplate];
    } else if (cancelButton && !cancelButton.hidden && CGRectContainsPoint(CGRectInset(cancelButton.frame, -8.0, -8.0), point)) {
        [self cancelTemplateCapture];
    }
}

- (void)handleCaptureDrawPan:(UIPanGestureRecognizer *)recognizer {
    if (!_captureOverlay || !_selectionView) {
        return;
    }

    CGPoint point = [recognizer locationInView:_captureImageView];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (!_selectionView.hidden && CGRectContainsPoint(_selectionView.frame, point)) {
            _captureDrawingSelection = NO;
            return;
        }
        _captureDrawingSelection = YES;
        _captureDragStartPoint = point;
        [self setCaptureActionButtonsHidden:YES];
        _selectionView.hidden = NO;
        _selectionView.frame = CGRectMake(point.x, point.y, 1.0, 1.0);
        return;
    }

    if (!_captureDrawingSelection) {
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateChanged ||
        recognizer.state == UIGestureRecognizerStateEnded) {
        CGRect frame = [self selectionFrameFromPoint:_captureDragStartPoint toPoint:point];
        _selectionView.frame = frame;
        _selectionView.hidden = CGRectGetWidth(frame) < 2.0 || CGRectGetHeight(frame) < 2.0;
    }

    if (recognizer.state == UIGestureRecognizerStateEnded ||
        recognizer.state == UIGestureRecognizerStateCancelled ||
        recognizer.state == UIGestureRecognizerStateFailed) {
        _captureDrawingSelection = NO;
        if (_selectionView.frame.size.width < 8.0 || _selectionView.frame.size.height < 8.0) {
            _selectionView.hidden = YES;
            _selectionView.frame = CGRectZero;
            [self setCaptureActionButtonsHidden:YES];
        } else {
            [self layoutCaptureActionButtonsAvoidingSelection];
        }
    }
}

- (void)handleSelectionPan:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.view != _selectionView) {
        return;
    }
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self setCaptureActionButtonsHidden:YES];
    }
    CGPoint translation = [recognizer translationInView:_captureImageView];
    CGRect frame = _selectionView.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    _selectionView.frame = [self clampedSelectionFrame:frame];
    [recognizer setTranslation:CGPointZero inView:_captureImageView];
    if (recognizer.state == UIGestureRecognizerStateEnded ||
        recognizer.state == UIGestureRecognizerStateCancelled ||
        recognizer.state == UIGestureRecognizerStateFailed) {
        [self layoutCaptureActionButtonsAvoidingSelection];
    }
}

- (void)saveSelectedTemplate {
    if (!_captureSnapshot.CGImage || !_selectionView || _selectionView.hidden || CGRectIsEmpty(_selectionView.frame)) {
        [self cancelTemplateCapture];
        _statusLabel.text = @"先框选区域";
        return;
    }

    CGRect selectionFrame = _selectionView.frame;
    CGFloat scale = _captureSnapshot.scale;
    CGRect cropRect = CGRectMake(selectionFrame.origin.x * scale,
                                 selectionFrame.origin.y * scale,
                                 selectionFrame.size.width * scale,
                                 selectionFrame.size.height * scale);
    CGRect imageBounds = CGRectMake(0, 0, CGImageGetWidth(_captureSnapshot.CGImage), CGImageGetHeight(_captureSnapshot.CGImage));
    cropRect = CGRectIntersection(cropRect, imageBounds);
    if (CGRectIsEmpty(cropRect)) {
        [self cancelTemplateCapture];
        _statusLabel.text = @"区域错误";
        return;
    }

    CGImageRef croppedRef = CGImageCreateWithImageInRect(_captureSnapshot.CGImage, cropRect);
    if (!croppedRef) {
        [self cancelTemplateCapture];
        _statusLabel.text = @"保存失败";
        return;
    }

    UIImage *templateImage = [UIImage imageWithCGImage:croppedRef scale:scale orientation:_captureSnapshot.imageOrientation];
    CGImageRelease(croppedRef);
    NSData *pngData = UIImagePNGRepresentation(templateImage);
    BOOL saved = [pngData writeToFile:[self writableTemplatePath] atomically:YES];
    [self finishTemplateCapture];
    [self refreshTemplatePreview];
    [self refreshEditorConfigControls];
    [self autosaveSelectedTaskIfPossible];
    _statusLabel.text = saved ? [NSString stringWithFormat:@"模板已保存 %@", [self commonConfigSummary]] : @"保存失败";
}

- (void)cancelTemplateCapture {
    [self finishTemplateCapture];
    _statusLabel.text = @"取消";
}

- (void)finishTemplateCapture {
    [_captureOverlay removeFromSuperview];
    _captureOverlay = nil;
    _captureScrollView = nil;
    _captureImageView = nil;
    _selectionView = nil;
    _captureSnapshot = nil;
    _captureDrawingSelection = NO;
    [self restorePanelAfterExternalTap];
}

- (void)refreshTemplatePreview {
    NSString *path = [self activeTemplatePath];
    UIImage *image = (path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) ? [UIImage imageWithContentsOfFile:path] : nil;
    _previewView.image = image;
    _previewView.hidden = !_taskEditorVisible || _actionMode != AnClickActionModeImage;
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

- (void)showOperationTraceForMode:(AnClickActionMode)mode atPoint:(CGPoint)screenPoint inWindow:(UIWindow *)hostWindow duration:(NSTimeInterval)duration {
    [_operationTraceView removeFromSuperview];
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
    } else if (mode == AnClickActionModePinchIn || mode == AnClickActionModePinchOut) {
        CGFloat fromDistance = (mode == AnClickActionModePinchIn) ? 168.0 : 58.0;
        CGFloat toDistance = (mode == AnClickActionModePinchIn) ? 58.0 : 168.0;
        CGPoint startA = CGPointMake(center.x - fromDistance * 0.5, center.y);
        CGPoint endA = CGPointMake(center.x - toDistance * 0.5, center.y);
        CGPoint startB = CGPointMake(center.x + fromDistance * 0.5, center.y);
        CGPoint endB = CGPointMake(center.x + toDistance * 0.5, center.y);
        [path moveToPoint:startA];
        [path addLineToPoint:endA];
        [path moveToPoint:startB];
        [path addLineToPoint:endB];
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(endA.x - 5, endA.y - 5, 10, 10)]];
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(endB.x - 5, endB.y - 5, 10, 10)]];
    } else if (mode == AnClickActionModeRotate) {
        [path addArcWithCenter:center radius:64.0 startAngle:(CGFloat)(-M_PI / 4.0) endAngle:(CGFloat)(M_PI * 0.75) clockwise:YES];
        CGPoint start = CGPointMake(center.x + cos(-M_PI / 4.0) * 64.0,
                                    center.y + sin(-M_PI / 4.0) * 64.0);
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(start.x - 5, start.y - 5, 10, 10)]];
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
    if (_actionMode == AnClickActionModeNone) {
        _statusLabel.text = @"先选择动作";
        return;
    }

    [self preparePanelForExternalTapWithHostWindow:hostWindow];

    if (_actionMode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = (_hasManualSwipeAnchor && _hasManualSwipeEndPoint)
            ? [self manualSwipePath]
            : [self recordedSwipePointsAnchoredAtPoint:point];
        if (path.count < 2) {
            _statusLabel.text = _hasManualSwipeAnchor ? @"先取终点" : @"先取起点";
            return;
        }
        [self showTrajectoryForScreenPoints:path inWindow:hostWindow duration:1.1];
        [AnClickFakeTouch playPath:path duration:0.55];
        _statusLabel.text = [NSString stringWithFormat:@"滑 %.0f,%.0f", point.x, point.y];
        return;
    }

    NSTimeInterval operationTraceDuration = (_actionMode == AnClickActionModeLongPress) ? 5.2 : 1.0;
    [self showOperationTraceForMode:_actionMode atPoint:point inWindow:hostWindow duration:operationTraceDuration];
    if (_actionMode == AnClickActionModeDoubleTap) {
        [AnClickFakeTouch doubleTapAtPoint:point];
        _statusLabel.text = [NSString stringWithFormat:@"双 %.0f,%.0f", point.x, point.y];
    } else if (_actionMode == AnClickActionModeLongPress) {
        _longPressHolding = YES;
        [AnClickFakeTouch longPressAtPoint:point duration:5.0];
        _statusLabel.text = [NSString stringWithFormat:@"长按5秒 %.0f,%.0f", point.x, point.y];
        [self refreshModeButtons];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
    } else if (_actionMode == AnClickActionModePinchIn) {
        [AnClickFakeTouch pinchAtPoint:point fromDistance:168.0 toDistance:58.0 duration:0.46];
        _statusLabel.text = [NSString stringWithFormat:@"缩小 %.0f,%.0f", point.x, point.y];
    } else if (_actionMode == AnClickActionModePinchOut) {
        [AnClickFakeTouch pinchAtPoint:point fromDistance:58.0 toDistance:168.0 duration:0.46];
        _statusLabel.text = [NSString stringWithFormat:@"放大 %.0f,%.0f", point.x, point.y];
    } else if (_actionMode == AnClickActionModeRotate) {
        [AnClickFakeTouch rotateAtPoint:point radius:64.0 startAngle:(CGFloat)(-M_PI / 4.0) endAngle:(CGFloat)(M_PI * 0.75) duration:0.58];
        _statusLabel.text = [NSString stringWithFormat:@"旋转 %.0f,%.0f", point.x, point.y];
    } else {
        [AnClickFakeTouch tapAtPoint:point];
        _statusLabel.text = [NSString stringWithFormat:@"点 %.0f,%.0f", point.x, point.y];
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
    return [self trajectoryPointsForRecordedEvents:_recordedMacroEvents];
}

- (NSTimeInterval)durationForRecordedEvents:(NSArray<NSDictionary *> *)events {
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
    return MAX(0.35, duration + 0.20);
}

- (void)autosaveSelectedTaskIfPossible {
    if (!_taskEditorVisible ||
        _selectedTaskIndex < 0 ||
        _selectedTaskIndex >= (NSInteger)_taskItems.count ||
        [_taskItems[(NSUInteger)_selectedTaskIndex] count] == 0) {
        return;
    }
    if (_actionMode == AnClickActionModeMacro && _recordedMacroEvents.count == 0) {
        return;
    }

    NSMutableDictionary *task = [self taskDictionaryFromCurrentConfigRequireComplete:NO];
    if (!task) {
        return;
    }
    _taskItems[(NSUInteger)_selectedTaskIndex] = task;
    [self persistCurrentTaskList];
    [self refreshCollapsedButtonTitle];
}

- (BOOL)storeNetworkRequestConfigInTask:(NSMutableDictionary *)task requireComplete:(BOOL)requireComplete {
    [self syncNetworkFieldsFromEditor];
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
    BOOL canUseOCRResult = _actionMode == AnClickActionModeOCR && _networkUsesPost;
    task[@"networkPostBodyUsesOCRResult"] = @(canUseOCRResult && _networkPostBodyUsesOCRResult);
    if (canUseOCRResult && _networkPostBodyUsesOCRResult && _networkPostExtraFields.length == 0) {
        if (requireComplete) {
            _statusLabel.text = @"先填POST键值";
        }
        return !requireComplete;
    }
    if (_networkPostBody.length > 0) {
        task[@"networkPostBody"] = _networkPostBody;
    }
    if (_networkPostExtraFields.length > 0) {
        task[@"networkPostExtraFields"] = _networkPostExtraFields;
    }
    return YES;
}

- (BOOL)networkHasJudgementConditionWithTrueText:(NSString *)trueText falseText:(NSString *)falseText {
    return [self trimmedActionDescription:trueText].length > 0 ||
        [self trimmedActionDescription:falseText].length > 0;
}

- (BOOL)currentNetworkJudgementHasCondition {
    return [self networkHasJudgementConditionWithTrueText:_networkContainsText falseText:_networkFalseText];
}

- (void)loadNetworkRequestConfigFromTask:(NSDictionary *)task {
    _networkURL = [self trimmedActionDescription:task[@"networkURL"]];
    _networkPostBody = [self trimmedActionDescription:task[@"networkPostBody"]];
    _networkPostExtraFields = [self trimmedActionDescription:task[@"networkPostExtraFields"]];
    _networkUsesPost = [[self networkMethodForTask:task] isEqualToString:@"POST"];
    _networkPostBodyUsesOCRResult = _networkUsesPost &&
        [self modeForTask:task] == AnClickActionModeOCR &&
        [task[@"networkPostBodyUsesOCRResult"] boolValue];
}

- (NSMutableDictionary *)taskDictionaryFromCurrentConfigRequireComplete:(BOOL)requireComplete {
    [self syncActionDescriptionFromField];
    [self syncActionTimingFromFields];
    [self syncImageThresholdFromField];
    if (_actionMode == AnClickActionModeNone) {
        if (requireComplete) {
            _statusLabel.text = @"先选择动作";
        }
        return nil;
    }

    NSMutableDictionary *task = [@{
        @"mode": @(_actionMode),
        @"delay": @(_actionDelay),
        @"repeat": @(MAX(1, _actionRepeatCount)),
    } mutableCopy];
    if (_actionDescription.length > 0) {
        task[@"desc"] = _actionDescription;
    }
    if (_actionMode == AnClickActionModeImage) {
        NSString *templatePath = [self activeTemplatePath];
        if (templatePath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:templatePath]) {
            task[@"templatePath"] = templatePath;
        } else if (requireComplete) {
            _statusLabel.text = @"先截图模板";
            return nil;
        }
        task[@"useMatchPoint"] = @(_imageUsesMatchPoint);
        task[@"imageActionMode"] = @([self normalizedImageActionMode:_imageActionMode]);
        task[@"threshold"] = @(_matchThreshold);
        if (_imageActionMode == AnClickActionModeNetwork && ![self storeNetworkRequestConfigInTask:task requireComplete:requireComplete]) {
            return nil;
        }
        if (!_imageUsesMatchPoint && _imageActionMode != AnClickActionModeNetwork) {
            if ([self hasManualPointForMode:AnClickActionModeImage]) {
                task[@"point"] = [NSValue valueWithCGPoint:_manualActionPoints[(NSUInteger)AnClickActionModeImage]];
            } else if (requireComplete) {
                _statusLabel.text = @"先取点击点";
                return nil;
            }
        }
        return task;
    }

    if (_actionMode == AnClickActionModeOCR) {
        [self syncOCRTargetFromField];
        AnClickOCRMatchMode matchMode = [self effectiveOCRMatchModeForText:_ocrTargetText ?: @""];
        if (_ocrTargetText.length > 0) {
            task[@"ocrText"] = _ocrTargetText;
        } else if (requireComplete) {
            _statusLabel.text = matchMode == AnClickOCRMatchModeRegex ? @"先填正则表达式" : @"先填目标文字";
            return nil;
        }
        if (matchMode == AnClickOCRMatchModeRegex &&
            requireComplete &&
            ![self ocrRegexPatternIsValid:_ocrTargetText]) {
            _statusLabel.text = @"正则表达式格式错误";
            return nil;
        }
        task[@"ocrMode"] = @(_ocrMode);
        task[@"ocrBackendVersion"] = @1;
        task[@"ocrMatchMode"] = @(matchMode);
        task[@"useMatchPoint"] = @(_ocrUsesMatchPoint);
        task[@"imageActionMode"] = @([self normalizedImageActionMode:_imageActionMode]);
        if (_imageActionMode == AnClickActionModeNetwork && ![self storeNetworkRequestConfigInTask:task requireComplete:requireComplete]) {
            return nil;
        }
        if (!_ocrUsesMatchPoint && _imageActionMode != AnClickActionModeNetwork) {
            if ([self hasManualPointForMode:AnClickActionModeOCR]) {
                task[@"point"] = [NSValue valueWithCGPoint:_manualActionPoints[(NSUInteger)AnClickActionModeOCR]];
            } else if (requireComplete) {
                _statusLabel.text = @"先取点击点";
                return nil;
            }
        }
        return task;
    }

    if (_actionMode == AnClickActionModeColor) {
        NSArray<NSDictionary *> *colorSamples = [self effectiveTargetColorSamples];
        if (colorSamples.count == 0) {
            if (requireComplete) {
                _statusLabel.text = @"先取目标颜色";
            }
            return nil;
        }
        NSDictionary *anchorColor = colorSamples.firstObject;
        task[@"colorRed"] = @([anchorColor[@"red"] integerValue]);
        task[@"colorGreen"] = @([anchorColor[@"green"] integerValue]);
        task[@"colorBlue"] = @([anchorColor[@"blue"] integerValue]);
        task[@"colorPoints"] = colorSamples;
        task[@"colorTolerance"] = @(_colorTolerance);
        task[@"imageActionMode"] = @([self normalizedImageActionMode:_imageActionMode]);
        if (_imageActionMode == AnClickActionModeNetwork && ![self storeNetworkRequestConfigInTask:task requireComplete:requireComplete]) {
            return nil;
        }
        return task;
    }

    if (_actionMode == AnClickActionModeNetwork) {
        if (![self storeNetworkRequestConfigInTask:task requireComplete:requireComplete]) {
            return nil;
        }
        if (!_networkRequestOnly && ![self currentNetworkJudgementHasCondition]) {
            _statusLabel.text = @"先填运行或不运行条件";
            return nil;
        }
        task[@"networkRequestOnly"] = @(_networkRequestOnly);
        task[@"networkRetryForever"] = @(_networkRetryForever);
        task[@"networkRetryLimit"] = @(MAX(1, _actionRepeatCount));
        task[@"networkTimeout"] = @(MAX(1.0, MIN(60.0, _networkTimeout)));
        if (_networkContainsText.length > 0) {
            task[@"networkContains"] = _networkContainsText;
        }
        if (_networkFalseText.length > 0) {
            task[@"networkFalse"] = _networkFalseText;
        }
        return task;
    }

    if (_actionMode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = [self manualSwipePath];
        if (path.count >= 2) {
            task[@"path"] = [path copy];
        } else if (requireComplete) {
            _statusLabel.text = _hasManualSwipeAnchor ? @"先取终点" : @"先取起点";
            return nil;
        }
        return task;
    }

    if (_actionMode == AnClickActionModeMacro) {
        if (_recordedMacroEvents.count > 0) {
            task[@"events"] = [_recordedMacroEvents copy];
        } else if (requireComplete) {
            _statusLabel.text = @"先录制";
            return nil;
        }
        return task;
    }

    if ([self hasManualPointForMode:_actionMode]) {
        task[@"point"] = [NSValue valueWithCGPoint:_manualActionPoints[(NSUInteger)_actionMode]];
    } else if (requireComplete) {
        _statusLabel.text = @"先取点";
        return nil;
    }
    return task;
}

- (NSString *)commonSuffixForTask:(NSDictionary *)task {
    NSTimeInterval delay = [task[@"delay"] doubleValue];
    NSInteger repeat = MAX(1, [task[@"repeat"] integerValue]);
    if (delay <= 0.001 && repeat <= 1) {
        return @"";
    }
    return [NSString stringWithFormat:@" 延%.1f 次%ld", delay, (long)repeat];
}

- (NSString *)titleForTask:(NSDictionary *)task index:(NSUInteger)index {
    AnClickActionMode mode = [self modeForTask:task];
    NSString *name = (mode == AnClickActionModeNone) ? @"未设置" : [self actionNameForMode:mode];
    NSString *desc = [self trimmedActionDescription:task[@"desc"]];
    NSString *subtitle = desc.length > 0 ? desc : (mode == AnClickActionModeNone ? @"未设置" : @"已设置");
    if (desc.length == 0 && mode == AnClickActionModeMacro) {
        NSArray *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
        subtitle = events.count > 0 ? [NSString stringWithFormat:@"已录 %lu 步", (unsigned long)events.count] : @"未录制";
    } else if (desc.length == 0 && mode == AnClickActionModeOCR) {
        NSString *text = [self trimmedActionDescription:task[@"ocrText"]];
        AnClickOCRMatchMode matchMode = [self ocrMatchModeForTask:task];
        subtitle = text.length > 0
            ? [NSString stringWithFormat:@"识字 · %@ · %@", [self ocrMatchModeTitleForMode:matchMode], [self ocrDisplayTextForText:text matchMode:matchMode]]
            : @"未设置文字";
        if ([self taskUsesRecognitionNetworkAction:task]) {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            NSString *method = [self networkMethodForTask:task];
            if ([method isEqualToString:@"POST"] &&
                [self modeForTask:task] == AnClickActionModeOCR &&
                [task[@"networkPostBodyUsesOCRResult"] boolValue]) {
                method = @"POST键值";
            }
            subtitle = [subtitle stringByAppendingFormat:@" · 成功后%@请求%@", method, url.length > 0 ? @"" : @"未设置"];
        }
    } else if (desc.length == 0 && mode == AnClickActionModeColor) {
        subtitle = [self colorPatternSummaryForTask:task];
        if ([self taskUsesRecognitionNetworkAction:task]) {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            subtitle = [subtitle stringByAppendingFormat:@" · 成功后%@请求%@", [self networkMethodForTask:task], url.length > 0 ? @"" : @"未设置"];
        }
    } else if (desc.length == 0 && mode == AnClickActionModeImage && [self taskUsesRecognitionNetworkAction:task]) {
        NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
        subtitle = [NSString stringWithFormat:@"识图 · 成功后%@请求%@", [self networkMethodForTask:task], url.length > 0 ? @"" : @"未设置"];
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
        subtitle = [subtitle stringByAppendingFormat:@" · 超时%.0fs", [self networkTimeoutForTask:task]];
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
    } else if (detail.length == 0 && mode == AnClickActionModeColor) {
        detail = [self colorPatternSummaryForTask:task];
    } else if (detail.length == 0 && mode == AnClickActionModeNetwork) {
        BOOL requestOnly = [self networkTaskIsOneShot:task];
        detail = [NSString stringWithFormat:@"%@ %@", [self networkMethodForTask:task], requestOnly ? @"仅请求" : @"判断返回"];
    }

    NSString *prefix = [NSString stringWithFormat:@"任务%lu/%lu %@",
                        (unsigned long)index + 1,
                        (unsigned long)MAX((NSUInteger)1, _taskItems.count),
                        name];
    NSString *shortDetail = [self shortToastDetail:detail maxLength:14];
    return shortDetail.length > 0 ? [prefix stringByAppendingFormat:@" %@", shortDetail] : prefix;
}

- (void)refreshTaskList {
    [self refreshCollapsedButtonTitle];
    BOOL hasTasks = _taskItems.count > 0;
    _deleteTaskButton.enabled = hasTasks;
    _deleteTaskButton.alpha = hasTasks ? 1.0 : 0.45;
    _runTasksButton.enabled = hasTasks || _taskRunActive;
    _runTasksButton.alpha = (hasTasks || _taskRunActive) ? 1.0 : 0.45;
    if (!_taskListView) {
        return;
    }

    for (UIView *view in _taskListView.subviews) {
        [view removeFromSuperview];
    }

    CGFloat rowHeight = 78.0;
    CGFloat width = _taskListView.bounds.size.width;
    if (_taskItems.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(12.0, 18.0, width - 24.0, 46.0)];
        emptyLabel.text = @"暂无任务  点击添加";
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.textColor = [UIColor colorWithWhite:1 alpha:0.58];
        emptyLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        emptyLabel.adjustsFontSizeToFitWidth = YES;
        emptyLabel.minimumScaleFactor = 0.7;
        [_taskListView addSubview:emptyLabel];
    }
    for (NSUInteger i = 0; i < _taskItems.count; i++) {
        CGFloat rowY = 8.0 + rowHeight * i;
        UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        deleteButton.tag = 50000 + (NSInteger)i;
        deleteButton.accessibilityIdentifier = @"AnClickTaskDelete";
        deleteButton.frame = CGRectMake(width - 88.0, rowY, 82.0, 68.0);
        [deleteButton setTitle:@"删除" forState:UIControlStateNormal];
        [deleteButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        deleteButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        deleteButton.backgroundColor = [UIColor colorWithRed:0.84 green:0.13 blue:0.10 alpha:0.94];
        deleteButton.layer.cornerRadius = 4;
        deleteButton.layer.borderWidth = 1;
        deleteButton.layer.borderColor = [UIColor colorWithRed:1.0 green:0.34 blue:0.30 alpha:0.85].CGColor;
        deleteButton.layer.shadowColor = UIColor.blackColor.CGColor;
        deleteButton.layer.shadowOffset = CGSizeMake(0, 2);
        deleteButton.layer.shadowRadius = 4.0;
        deleteButton.layer.shadowOpacity = 0.28;
        deleteButton.hidden = (NSInteger)i != _revealedDeleteTaskIndex;
        deleteButton.alpha = deleteButton.hidden ? 0.0 : 1.0;
        [deleteButton addTarget:self action:@selector(deleteTaskButtonAtIndex:) forControlEvents:UIControlEventTouchUpInside];
        [_taskListView addSubview:deleteButton];
        [self updateButtonShadowPath:deleteButton];

        UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem];
        row.tag = (NSInteger)i;
        row.accessibilityIdentifier = @"AnClickTaskRow";
        row.frame = CGRectMake(6.0, rowY, width - 12.0, 68.0);
        [row setTitle:[self titleForTask:_taskItems[i] index:i] forState:UIControlStateNormal];
        [row setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        row.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
        row.titleLabel.numberOfLines = 2;
        row.titleLabel.adjustsFontSizeToFitWidth = YES;
        row.titleLabel.minimumScaleFactor = 0.62;
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.titleEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 34);
        BOOL selected = (NSInteger)i == _selectedTaskIndex;
        row.backgroundColor = selected
            ? [UIColor colorWithRed:0.28 green:0.22 blue:0.11 alpha:0.98]
            : [UIColor colorWithRed:0.15 green:0.15 blue:0.135 alpha:0.96];
        row.layer.cornerRadius = 8;
        row.layer.borderWidth = 1;
        row.layer.borderColor = selected
            ? [UIColor colorWithRed:0.98 green:0.70 blue:0.28 alpha:0.78].CGColor
            : [UIColor colorWithWhite:1 alpha:0.15].CGColor;
        row.layer.shadowColor = UIColor.blackColor.CGColor;
        row.layer.shadowOffset = CGSizeMake(0, 2);
        row.layer.shadowRadius = 4.0;
        row.layer.shadowOpacity = selected ? 0.30 : 0.18;
        if ((NSInteger)i == _revealedDeleteTaskIndex) {
            row.transform = CGAffineTransformMakeTranslation(-88.0, 0);
        }
        [self updateButtonShadowPath:row];
        [row addTarget:self action:@selector(selectTaskButton:) forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTaskPan:)];
        pan.cancelsTouchesInView = YES;
        pan.delegate = self;
        [row addGestureRecognizer:pan];

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTaskLongPress:)];
        longPress.minimumPressDuration = 0.55;
        [row addGestureRecognizer:longPress];
        [_taskListView addSubview:row];
    }
    _taskListView.contentSize = CGSizeMake(width, MAX(_taskListView.bounds.size.height + 1.0, 16.0 + rowHeight * _taskItems.count));
}

- (void)addTaskFromCurrentConfig {
    NSMutableDictionary *task = [NSMutableDictionary dictionary];
    [_taskItems addObject:task];
    _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    _revealedDeleteTaskIndex = -1;
    [self resetCurrentActionConfiguration];
    [self showTaskHome];
    [self persistCurrentTaskList];
    _statusLabel.text = [NSString stringWithFormat:@"已加任务%lu  点击任务设置", (unsigned long)_taskItems.count];
}

- (void)deleteLastTask {
    if (_taskItems.count == 0) {
        _statusLabel.text = @"没有任务";
        return;
    }

    NSInteger removedIndex = (NSInteger)_taskItems.count - 1;
    BOOL removedSelectedTask = _selectedTaskIndex == removedIndex;
    [_taskItems removeLastObject];
    if (removedSelectedTask || _taskItems.count == 0) {
        _selectedTaskIndex = -1;
        [self resetCurrentActionConfiguration];
    } else if (_selectedTaskIndex >= (NSInteger)_taskItems.count) {
        _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    }
    _revealedDeleteTaskIndex = -1;
    [self showTaskHome];
    [self persistCurrentTaskList];
    _statusLabel.text = _taskItems.count == 0 ? @"暂无任务" : [NSString stringWithFormat:@"已删剩%lu", (unsigned long)_taskItems.count];
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
    _revealedDeleteTaskIndex = -1;
    [self showTaskHome];
    [self persistCurrentTaskList];
    _statusLabel.text = _taskItems.count == 0 ? @"暂无任务" : [NSString stringWithFormat:@"已删任务%ld  剩%lu", (long)index + 1, (unsigned long)_taskItems.count];
}

- (void)deleteTaskButtonAtIndex:(UIButton *)sender {
    [self deleteTaskAtIndex:sender.tag - 50000];
}

- (void)saveSelectedTaskFromCurrentConfig {
    NSMutableDictionary *task = [self taskDictionaryFromCurrentConfigRequireComplete:YES];
    if (!task) {
        return;
    }
    BOOL updatingExistingTask = _selectedTaskIndex >= 0 &&
        _selectedTaskIndex < (NSInteger)_taskItems.count &&
        [_taskItems[(NSUInteger)_selectedTaskIndex] count] > 0;
    if (_selectedTaskIndex < 0 || _selectedTaskIndex >= (NSInteger)_taskItems.count) {
        [_taskItems addObject:task];
        _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    } else {
        _taskItems[(NSUInteger)_selectedTaskIndex] = task;
    }
    [self refreshTaskList];
    _revealedDeleteTaskIndex = -1;
    [self showTaskHome];
    [self persistCurrentTaskList];
    _statusLabel.text = [NSString stringWithFormat:@"%@任务%ld", updatingExistingTask ? @"已修改" : @"已保存", (long)_selectedTaskIndex + 1];
}

- (void)selectTaskButton:(UIButton *)sender {
    _revealedDeleteTaskIndex = -1;
    [self selectTaskAtIndex:sender.tag];
}

- (void)selectTaskAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        return;
    }

    _selectedTaskIndex = index;
    [self dismissConfigKeyboardAndSync];
    NSDictionary *task = _taskItems[(NSUInteger)index];
    AnClickActionMode mode = [self modeForTask:task];
    [self resetEditorActionState];
    _actionMode = mode;
    _actionDelay = MAX(0.0, [task[@"delay"] doubleValue]);
    _actionRepeatCount = MAX(1, [task[@"repeat"] integerValue]);
    _actionDescription = [self trimmedActionDescription:task[@"desc"]];

    if (mode == AnClickActionModeNone) {
        _statusLabel.text = @"请选择动作";
    } else if (mode == AnClickActionModeImage) {
        _currentTemplatePath = task[@"templatePath"];
        NSNumber *useMatchPointNumber = task[@"useMatchPoint"];
        _imageUsesMatchPoint = useMatchPointNumber ? useMatchPointNumber.boolValue : YES;
        _imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        if (_imageActionMode == AnClickActionModeNetwork) {
            [self loadNetworkRequestConfigFromTask:task];
        }
        NSNumber *thresholdNumber = task[@"threshold"];
        _matchThreshold = thresholdNumber ? MIN(1.0, MAX(0.0, thresholdNumber.doubleValue)) : 0.80;
        NSValue *pointValue = task[@"point"];
        if (pointValue) {
            _manualActionPoints[(NSUInteger)AnClickActionModeImage] = pointValue.CGPointValue;
            _hasManualActionPoint[(NSUInteger)AnClickActionModeImage] = YES;
        }
    } else if (mode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = task[@"path"];
        if (path.count >= 2) {
            _recordedSwipePoints = [path mutableCopy];
            _manualSwipeAnchor = path.firstObject.CGPointValue;
            _manualSwipeEndPoint = path.lastObject.CGPointValue;
            _hasManualSwipeAnchor = YES;
            _hasManualSwipeEndPoint = YES;
        }
    } else if (mode == AnClickActionModeMacro) {
        NSArray<NSDictionary *> *events = task[@"events"];
        _recordedMacroEvents = [events isKindOfClass:NSArray.class] ? [events copy] : nil;
    } else if (mode == AnClickActionModeOCR) {
        _ocrTargetText = [self trimmedActionDescription:task[@"ocrText"]];
        _ocrMode = [self ocrModeForTask:task];
        _ocrMatchMode = [self ocrMatchModeForTask:task];
        NSNumber *useMatchPointNumber = task[@"useMatchPoint"];
        _ocrUsesMatchPoint = useMatchPointNumber ? useMatchPointNumber.boolValue : YES;
        _imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        if (_imageActionMode == AnClickActionModeNetwork) {
            [self loadNetworkRequestConfigFromTask:task];
        }
        NSValue *pointValue = task[@"point"];
        if (pointValue) {
            _manualActionPoints[(NSUInteger)AnClickActionModeOCR] = pointValue.CGPointValue;
            _hasManualActionPoint[(NSUInteger)AnClickActionModeOCR] = YES;
        }
    } else if (mode == AnClickActionModeColor) {
        NSArray<NSDictionary *> *savedColorPoints = [self mutableColorSamplesArrayFromObject:task[@"colorPoints"]];
        if (savedColorPoints.count > 0) {
            [self applyTargetColorSamples:savedColorPoints];
        } else if ([task[@"colorRed"] respondsToSelector:@selector(integerValue)] &&
                   [task[@"colorGreen"] respondsToSelector:@selector(integerValue)] &&
                   [task[@"colorBlue"] respondsToSelector:@selector(integerValue)]) {
            [self applyTargetColorSamples:@[@{
                @"dx": @(0.0),
                @"dy": @(0.0),
                @"red": @([task[@"colorRed"] integerValue]),
                @"green": @([task[@"colorGreen"] integerValue]),
                @"blue": @([task[@"colorBlue"] integerValue]),
            }]];
        }
        NSNumber *toleranceNumber = task[@"colorTolerance"];
        _colorTolerance = toleranceNumber ? MIN(255.0, MAX(0.0, toleranceNumber.doubleValue)) : 18.0;
        _imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        if (_imageActionMode == AnClickActionModeNetwork) {
            [self loadNetworkRequestConfigFromTask:task];
        }
    } else if (mode == AnClickActionModeNetwork) {
        [self loadNetworkRequestConfigFromTask:task];
        _networkContainsText = [self trimmedActionDescription:task[@"networkContains"]];
        _networkFalseText = [self trimmedActionDescription:task[@"networkFalse"]];
        _networkRequestOnly = [task[@"networkRequestOnly"] boolValue];
        _networkRetryForever = [self networkRetryForeverForTask:task];
        _actionRepeatCount = [self networkRetryLimitForTask:task];
        _networkTimeout = [task[@"networkTimeout"] respondsToSelector:@selector(doubleValue)]
            ? MIN(60.0, MAX(1.0, [task[@"networkTimeout"] doubleValue]))
            : 8.0;
    } else if ([self isSelectableActionMode:mode] && mode != AnClickActionModeSwipe && mode != AnClickActionModeImage) {
        NSValue *pointValue = task[@"point"];
        if (pointValue) {
            _manualActionPoints[(NSUInteger)mode] = pointValue.CGPointValue;
            _hasManualActionPoint[(NSUInteger)mode] = YES;
        }
    }

    [self refreshModeButtons];
    [self refreshTaskList];
    [self setTaskEditorVisible:YES];
    [self updateStatusForCurrentConfig];
    _statusLabel.text = [NSString stringWithFormat:@"修改任务%ld  %@", (long)index + 1, _statusLabel.text ?: @""];
}

- (void)resetRevealedTaskRowsExceptIndex:(NSInteger)index animated:(BOOL)animated {
    if (!_taskListView) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    void (^changes)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        for (UIView *view in strongSelf->_taskListView.subviews) {
            if ([view.accessibilityIdentifier isEqualToString:@"AnClickTaskRow"]) {
                if (view.tag != index) {
                    view.transform = CGAffineTransformIdentity;
                }
            } else if ([view.accessibilityIdentifier isEqualToString:@"AnClickTaskDelete"]) {
                NSInteger taskIndex = view.tag - 50000;
                if (taskIndex != index) {
                    view.alpha = 0.0;
                    view.hidden = YES;
                }
            }
        }
    };

    if (animated) {
        [UIView animateWithDuration:0.16 animations:changes];
    } else {
        changes();
    }
}

- (UIButton *)deleteButtonForTaskIndex:(NSInteger)index {
    UIView *view = [_taskListView viewWithTag:50000 + index];
    return [view isKindOfClass:UIButton.class] ? (UIButton *)view : nil;
}

- (void)setDeleteButtonVisible:(BOOL)visible forTaskIndex:(NSInteger)index animated:(BOOL)animated {
    UIButton *deleteButton = [self deleteButtonForTaskIndex:index];
    if (!deleteButton) {
        return;
    }
    if (visible) {
        deleteButton.hidden = NO;
    }
    void (^changes)(void) = ^{
        deleteButton.alpha = visible ? 1.0 : 0.0;
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        if (!visible) {
            deleteButton.hidden = YES;
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.14 animations:changes completion:completion];
    } else {
        changes();
        completion(YES);
    }
}

- (void)moveTaskAtIndex:(NSInteger)index toIndex:(NSInteger)targetIndex {
    if (index < 0 ||
        targetIndex < 0 ||
        index >= (NSInteger)_taskItems.count ||
        targetIndex >= (NSInteger)_taskItems.count ||
        index == targetIndex) {
        return;
    }

    NSMutableDictionary *task = _taskItems[(NSUInteger)index];
    [_taskItems removeObjectAtIndex:(NSUInteger)index];
    [_taskItems insertObject:task atIndex:(NSUInteger)targetIndex];
    if (_selectedTaskIndex == index) {
        _selectedTaskIndex = targetIndex;
    } else if (_selectedTaskIndex > index && _selectedTaskIndex <= targetIndex) {
        _selectedTaskIndex--;
    } else if (_selectedTaskIndex < index && _selectedTaskIndex >= targetIndex) {
        _selectedTaskIndex++;
    }
    _revealedDeleteTaskIndex = -1;
    [self persistCurrentTaskList];
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
        if ([gestureRecognizer.view.accessibilityIdentifier isEqualToString:@"AnClickTaskRow"]) {
            CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:_taskListView];
            return fabs(velocity.x) > fabs(velocity.y) * 1.25;
        }
    }
    return YES;
}

- (void)handleTaskLongPress:(UILongPressGestureRecognizer *)recognizer {
    UIView *row = recognizer.view;
    if (!row) {
        return;
    }

    NSInteger index = row.tag;
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        return;
    }

    CGFloat rowHeight = 78.0;
    CGPoint location = [recognizer locationInView:_taskListView];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _taskReordering = YES;
        _draggingTaskIndex = index;
        _taskReorderStartCenterY = row.center.y;
        _taskReorderStartLocationY = location.y;
        _revealedDeleteTaskIndex = -1;
        [self resetRevealedTaskRowsExceptIndex:index animated:YES];
        [_taskListView bringSubviewToFront:row];
        [UIView animateWithDuration:0.12 animations:^{
            row.transform = CGAffineTransformMakeScale(1.025, 1.025);
            row.alpha = 0.94;
        }];
        _statusLabel.text = [NSString stringWithFormat:@"拖动排序任务%ld", (long)index + 1];
        return;
    }

    if (!_taskReordering || _draggingTaskIndex != index) {
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGFloat deltaY = location.y - _taskReorderStartLocationY;
        CGFloat minCenterY = 8.0 + rowHeight * 0.5;
        CGFloat maxCenterY = 8.0 + rowHeight * ((CGFloat)_taskItems.count - 0.5);
        CGFloat centerY = MIN(MAX(_taskReorderStartCenterY + deltaY, minCenterY), maxCenterY);
        row.center = CGPointMake(row.center.x, centerY);
        return;
    }

    if (recognizer.state == UIGestureRecognizerStateEnded ||
        recognizer.state == UIGestureRecognizerStateCancelled ||
        recognizer.state == UIGestureRecognizerStateFailed) {
        NSInteger targetIndex = (NSInteger)floor((row.center.y - 8.0) / rowHeight);
        targetIndex = MIN(MAX(targetIndex, 0), (NSInteger)_taskItems.count - 1);
        row.transform = CGAffineTransformIdentity;
        row.alpha = 1.0;
        [self moveTaskAtIndex:index toIndex:targetIndex];
        _taskReordering = NO;
        _draggingTaskIndex = -1;
        _taskReorderStartCenterY = 0;
        _taskReorderStartLocationY = 0;
        [self refreshTaskList];
        _statusLabel.text = targetIndex == index
            ? @"排序未变化"
            : [NSString stringWithFormat:@"已移到第%ld", (long)targetIndex + 1];
    }
}

- (void)handleTaskPan:(UIPanGestureRecognizer *)recognizer {
    if (_taskReordering) {
        return;
    }

    UIView *row = recognizer.view;
    if (!row) {
        return;
    }

    NSInteger index = row.tag;
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        return;
    }

    CGPoint translation = [recognizer translationInView:_taskListView];
    CGFloat revealWidth = 88.0;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _draggingTaskIndex = index;
        CGAffineTransform currentTransform = row.transform;
        _taskPanStartOffsetX = currentTransform.tx;
        _taskPanDirectionLocked = fabs(_taskPanStartOffsetX) > 1.0;
        _taskPanHorizontal = _taskPanDirectionLocked;
        [self resetRevealedTaskRowsExceptIndex:index animated:YES];
        if (_taskPanHorizontal) {
            [self setDeleteButtonVisible:YES forTaskIndex:index animated:NO];
        }
        [_taskListView bringSubviewToFront:row];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        if (!_taskPanDirectionLocked && hypot(translation.x, translation.y) > 7.0) {
            _taskPanHorizontal = fabs(translation.x) > fabs(translation.y);
            _taskPanDirectionLocked = YES;
            if (_taskPanHorizontal) {
                [self setDeleteButtonVisible:YES forTaskIndex:index animated:NO];
            }
        }

        if (_taskPanHorizontal) {
            CGFloat offsetX = MIN(MAX(_taskPanStartOffsetX + translation.x, -revealWidth), 0.0);
            row.transform = CGAffineTransformMakeTranslation(offsetX, 0);
        }
    } else if (recognizer.state == UIGestureRecognizerStateEnded ||
               recognizer.state == UIGestureRecognizerStateCancelled ||
               recognizer.state == UIGestureRecognizerStateFailed) {
        if (_taskPanHorizontal) {
            CGAffineTransform currentTransform = row.transform;
            CGFloat targetX = currentTransform.tx < -revealWidth * 0.45 ? -revealWidth : 0.0;
            [UIView animateWithDuration:0.16 animations:^{
                row.transform = CGAffineTransformMakeTranslation(targetX, 0);
            }];
            _revealedDeleteTaskIndex = targetX < 0.0 ? index : -1;
            [self setDeleteButtonVisible:targetX < 0.0 forTaskIndex:index animated:YES];
            if (targetX < 0.0) {
                _statusLabel.text = [NSString stringWithFormat:@"可删除任务%ld", (long)index + 1];
            }
            _draggingTaskIndex = -1;
            _taskPanDirectionLocked = NO;
            _taskPanHorizontal = NO;
            _taskPanStartOffsetX = 0;
            return;
        }

        row.transform = CGAffineTransformIdentity;
        _draggingTaskIndex = -1;
        _taskPanDirectionLocked = NO;
        _taskPanHorizontal = NO;
        _taskPanStartOffsetX = 0;
        [self refreshTaskList];
    }
}

- (NSTimeInterval)durationForTaskMode:(AnClickActionMode)mode {
    if (mode == AnClickActionModeLongPress) {
        return 5.35;
    }
    if (mode == AnClickActionModeSwipe) {
        return 0.78;
    }
    if (mode == AnClickActionModeDoubleTap) {
        return 0.55;
    }
    if (mode == AnClickActionModePinchIn || mode == AnClickActionModePinchOut) {
        return 0.72;
    }
    if (mode == AnClickActionModeRotate) {
        return 0.86;
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
    if (mode == AnClickActionModeMacro) {
        return [self durationForRecordedEvents:_recordedMacroEvents];
    }
    return 0.30;
}

- (NSTimeInterval)delayForTask:(NSDictionary *)task {
    return MAX(0.0, [task[@"delay"] doubleValue]);
}

- (NSInteger)repeatCountForTask:(NSDictionary *)task {
    return MAX(1, [task[@"repeat"] integerValue]);
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
    if ([self modeForTask:task] == AnClickActionModeOCR &&
        [task[@"networkPostBodyUsesOCRResult"] boolValue]) {
        NSDictionary *postDictionary = [self networkPostDictionaryFromKeyValueText:[self networkPostKeyValueTextForTask:task]
                                                                   recognitionText:recognitionText];
        NSString *jsonBody = postDictionary ? [self networkPostJSONStringFromDictionary:postDictionary] : nil;
        if (jsonBody.length > 0) {
            return jsonBody;
        }
        return [self trimmedActionDescription:recognitionText] ?: @"";
    }

    NSString *postBody = [self networkPostBodyForTask:task];
    if (postBody.length == 0 || recognitionText.length == 0) {
        return postBody;
    }
    return [self postBody:postBody applyingRecognitionText:recognitionText];
}

- (NSString *)normalizedNetworkURLString:(NSString *)urlText {
    NSString *trimmed = [self trimmedActionDescription:urlText];
    if (trimmed.length == 0) {
        return nil;
    }
    if ([trimmed rangeOfString:@"://"].location == NSNotFound) {
        trimmed = [@"https://" stringByAppendingString:trimmed];
    }
    return [NSURL URLWithString:trimmed] ? trimmed : nil;
}

- (NSString *)stringFromNetworkData:(NSData *)data {
    if (data.length == 0) {
        return @"";
    }

    NSString *body = nil;
    [NSString stringEncodingForData:data encodingOptions:nil convertedString:&body usedLossyConversion:nil];
    if (body.length > 0) {
        return body;
    }
    body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return body ?: @"";
}

- (BOOL)networkBody:(NSString *)body matchesRegexPattern:(NSString *)pattern {
    NSString *regexPattern = [self trimmedActionDescription:pattern];
    if (regexPattern.length == 0) {
        return NO;
    }

    NSString *response = body ?: @"";
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexPattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    if (!regex || error) {
        return NO;
    }
    NSRange range = NSMakeRange(0, response.length);
    return [regex firstMatchInString:response options:0 range:range] != nil;
}

- (NSString *)networkRegexPatternFromRuleText:(NSString *)ruleText {
    NSString *rule = [self trimmedActionDescription:ruleText];
    NSString *lowercaseRule = [rule lowercaseString];
    NSArray<NSString *> *prefixes = @[@"re:", @"regex:", @"正则:"];
    for (NSString *prefix in prefixes) {
        if ([lowercaseRule hasPrefix:prefix]) {
            return [self trimmedActionDescription:[rule substringFromIndex:prefix.length]];
        }
    }
    return nil;
}

- (BOOL)networkBody:(NSString *)body matchesRuleText:(NSString *)ruleText {
    NSString *rule = [self trimmedActionDescription:ruleText];
    if (rule.length == 0) {
        return NO;
    }

    NSString *regexPattern = [self networkRegexPatternFromRuleText:rule];
    if (regexPattern.length > 0) {
        return [self networkBody:body matchesRegexPattern:regexPattern];
    }

    NSString *response = body ?: @"";
    return [response rangeOfString:rule options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (NSNumber *)networkStatusBooleanFromBody:(NSString *)body {
    NSData *data = [(body ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length == 0) {
        return nil;
    }

    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![object isKindOfClass:NSDictionary.class]) {
        return nil;
    }

    id statusValue = ((NSDictionary *)object)[@"status"];
    if ([statusValue isKindOfClass:NSNumber.class]) {
        return @([statusValue boolValue]);
    }
    if ([statusValue isKindOfClass:NSString.class]) {
        NSString *statusText = [[self trimmedActionDescription:statusValue] lowercaseString];
        if ([statusText isEqualToString:@"true"]) {
            return @(YES);
        }
        if ([statusText isEqualToString:@"false"]) {
            return @(NO);
        }
    }
    return nil;
}

- (BOOL)networkBodyMatchesDefaultTrue:(NSString *)body {
    NSNumber *jsonStatus = [self networkStatusBooleanFromBody:body];
    if (jsonStatus) {
        return jsonStatus.boolValue;
    }

    NSString *response = body ?: @"";
    if ([self networkBody:response matchesRegexPattern:@"\"status\"\\s*:\\s*true"]) {
        return YES;
    }
    NSString *trimmed = [[response stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    return [trimmed isEqualToString:@"true"];
}

- (BOOL)networkBodyMatchesDefaultFalse:(NSString *)body {
    NSNumber *jsonStatus = [self networkStatusBooleanFromBody:body];
    if (jsonStatus) {
        return !jsonStatus.boolValue;
    }

    NSString *response = body ?: @"";
    if ([self networkBody:response matchesRegexPattern:@"\"status\"\\s*:\\s*false"]) {
        return YES;
    }
    NSString *trimmed = [[response stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    return [trimmed isEqualToString:@"false"];
}

- (BOOL)networkBody:(NSString *)body matchesTrueText:(NSString *)trueText falseText:(NSString *)falseText defaultExpectedTrue:(BOOL)defaultExpectedTrue {
    NSString *trueRule = [self trimmedActionDescription:trueText];
    NSString *falseRule = [self trimmedActionDescription:falseText];
    if (falseRule.length > 0 && [self networkBody:body matchesRuleText:falseRule]) {
        return NO;
    }
    if (trueRule.length > 0) {
        return [self networkBody:body matchesRuleText:trueRule];
    }
    if (defaultExpectedTrue) {
        if ([self networkBodyMatchesDefaultFalse:body]) {
            return NO;
        }
        return [self networkBodyMatchesDefaultTrue:body];
    }
    return YES;
}

- (BOOL)networkBody:(NSString *)body matchesBlockText:(NSString *)falseText defaultExpectedTrue:(BOOL)defaultExpectedTrue {
    NSString *falseRule = [self trimmedActionDescription:falseText];
    if (falseRule.length > 0) {
        return [self networkBody:body matchesRuleText:falseRule];
    }
    return defaultExpectedTrue && [self networkBodyMatchesDefaultFalse:body];
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
                                  postBody:(NSString *)postBody
                                  trueText:(NSString *)trueText
                                 falseText:(NSString *)falseText
                       defaultExpectedTrue:(BOOL)defaultExpectedTrue
                                   timeout:(NSTimeInterval)timeout
                                completion:(void (^)(BOOL matched, BOOL requestSucceeded, NSString *body, NSInteger statusCode, NSError *error))completion {
    NSString *normalizedURLString = [self normalizedNetworkURLString:urlString];
    NSURL *url = normalizedURLString.length > 0 ? [NSURL URLWithString:normalizedURLString] : nil;
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"AnClickNetwork"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"链接无效"}];
            completion(NO, NO, @"", 0, error);
        }
        return;
    }

    NSTimeInterval requestTimeout = MIN(60.0, MAX(1.0, timeout));
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:requestTimeout];
    NSString *normalizedMethod = [[self trimmedActionDescription:method] uppercaseString];
    BOOL usesPost = [normalizedMethod isEqualToString:@"POST"];
    request.HTTPMethod = usesPost ? @"POST" : @"GET";
    if (usesPost) {
        NSString *bodyText = postBody ?: @"";
        request.HTTPBody = [bodyText dataUsingEncoding:NSUTF8StringEncoding];
        NSString *trimmedBody = [self trimmedActionDescription:bodyText];
        NSString *contentType = [trimmedBody hasPrefix:@"{"] || [trimmedBody hasPrefix:@"["]
            ? @"application/json;charset=utf-8"
            : @"application/x-www-form-urlencoded;charset=utf-8";
        [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    }
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = 0;
        if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            statusCode = ((NSHTTPURLResponse *)response).statusCode;
        }
        NSString *body = [self stringFromNetworkData:data];
        BOOL requestSucceeded = !error && (statusCode == 0 || (statusCode >= 200 && statusCode < 400));
        BOOL matched = requestSucceeded && [self networkBody:body matchesTrueText:trueText falseText:falseText defaultExpectedTrue:defaultExpectedTrue];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(matched, requestSucceeded, body, statusCode, error);
            }
        });
    }];
    [task resume];
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
    if (matched) {
        return @"命中运行";
    }
    if (error) {
        return @"网络请求失败";
    }
    if (!requestSucceeded && statusCode > 0) {
        return [NSString stringWithFormat:@"网络状态%ld", (long)statusCode];
    }
    return @"未命中运行";
}

- (void)performNetworkRequestTask:(NSDictionary *)task
                     runGeneration:(NSUInteger)runGeneration
                        completion:(void (^)(BOOL matched, BOOL requestSucceeded, BOOL blocked))completion {
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
    [self performNetworkRequestWithURLString:url method:method postBody:postBody trueText:contains falseText:falseText defaultExpectedTrue:NO timeout:timeout completion:^(BOOL matched, BOOL requestSucceeded, NSString *body, NSInteger statusCode, NSError *error) {
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

- (void)continueTaskRunAfterIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow generation:(NSUInteger)runGeneration {
    NSTimeInterval globalDelay = MAX(0.0, _globalDelayMilliseconds / 1000.0);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(globalDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (![strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
            return;
        }
        UIWindow *currentHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:hostWindow];
        [strongSelf runTaskAtIndex:index + 1 inWindow:currentHostWindow generation:runGeneration];
    });
}

- (void)pollNetworkTask:(NSDictionary *)task atIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow generation:(NSUInteger)runGeneration attempt:(NSInteger)attempt {
    if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
        return;
    }

    BOOL waitsForCondition = ![self networkTaskIsOneShot:task];
    BOOL retryForever = [self networkRetryForeverForTask:task];
    NSInteger retryLimit = [self networkRetryLimitForTask:task];
    [self performNetworkRequestTask:task runGeneration:runGeneration completion:^(BOOL matched, BOOL requestSucceeded, BOOL blocked) {
        if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
            return;
        }
        UIWindow *currentHostWindow = [self currentUsableHostWindowForTaskRunFallback:hostWindow];
        if (!waitsForCondition) {
            [self continueTaskRunAfterIndex:index inWindow:currentHostWindow generation:runGeneration];
            return;
        }

        NSString *runRule = [self trimmedActionDescription:task[@"networkContains"]];
        BOOL shouldContinue = runRule.length > 0 ? (matched && !blocked) : (requestSucceeded && !blocked);
        if (shouldContinue) {
            [self continueTaskRunAfterIndex:index inWindow:currentHostWindow generation:runGeneration];
            return;
        }

        NSString *stateText = blocked ? @"命中不运行" : (requestSucceeded ? @"网络不运行" : @"网络重试中");
        if (!retryForever && attempt >= retryLimit) {
            [self stopTaskRunWithStatus:[NSString stringWithFormat:@"%@ 达到%ld次", stateText, (long)retryLimit]];
            return;
        }

        self->_statusLabel.text = retryForever
            ? [NSString stringWithFormat:@"%@ 继续判断", stateText]
            : [NSString stringWithFormat:@"%@ %ld/%ld", stateText, (long)attempt, (long)retryLimit];
        [self showToast:self->_statusLabel.text];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf ||
                ![strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:currentHostWindow status:@"窗口变化停止"]) {
                return;
            }
            UIWindow *retryHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:currentHostWindow];
            [strongSelf pollNetworkTask:task atIndex:index inWindow:retryHostWindow generation:runGeneration attempt:attempt + 1];
        });
    }];
}

- (void)runNetworkTask:(NSDictionary *)task atIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow generation:(NSUInteger)runGeneration {
    if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
        return;
    }
    NSTimeInterval delay = [self delayForTask:task];
    _statusLabel.text = @"网络请求";
    [self showToast:[self toastTextForTask:task index:index]];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf ||
            ![strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
            return;
        }
        UIWindow *currentHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:hostWindow];
        [strongSelf pollNetworkTask:task atIndex:index inWindow:currentHostWindow generation:runGeneration attempt:1];
    });
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
                            completion:(void (^)(void))completion {
    AnClickActionMode mode = [self modeForTask:task];
    if (mode == AnClickActionModeImage) {
        [self performImageTask:task inWindow:hostWindow runGeneration:runGeneration completion:completion];
    } else if (mode == AnClickActionModeOCR) {
        [self performOCRTask:task inWindow:hostWindow runGeneration:runGeneration completion:completion];
    } else if (mode == AnClickActionModeColor) {
        [self performColorTask:task inWindow:hostWindow runGeneration:runGeneration completion:completion];
    } else if (completion) {
        completion();
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

    [self performRecognitionNetworkTask:task inWindow:hostWindow generation:runGeneration completion:^{
        if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
            return;
        }
        UIWindow *currentHostWindow = [self currentUsableHostWindowForTaskRunFallback:hostWindow];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf ||
                ![strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:currentHostWindow status:@"窗口变化停止"]) {
                return;
            }
            UIWindow *nextHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:currentHostWindow];
            [strongSelf runRecognitionNetworkTask:task atIndex:index inWindow:nextHostWindow generation:runGeneration repeatIndex:repeatIndex + 1];
        });
    }];
}

- (void)runRecognitionNetworkTask:(NSDictionary *)task atIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow generation:(NSUInteger)runGeneration {
    if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
        return;
    }
    NSTimeInterval delay = [self delayForTask:task];
    [self showToast:[self toastTextForTask:task index:index]];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf ||
            ![strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
            return;
        }
        UIWindow *currentHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:hostWindow];
        [strongSelf runRecognitionNetworkTask:task atIndex:index inWindow:currentHostWindow generation:runGeneration repeatIndex:0];
    });
}

- (void)performPointActionMode:(AnClickActionMode)mode atPoint:(CGPoint)point inWindow:(UIWindow *)hostWindow {
    NSTimeInterval duration = [self durationForTaskMode:mode];
    [self showOperationTraceForMode:mode atPoint:point inWindow:hostWindow duration:duration];
    if (mode == AnClickActionModeDoubleTap) {
        [AnClickFakeTouch doubleTapAtPoint:point];
    } else if (mode == AnClickActionModeLongPress) {
        _longPressHolding = YES;
        [AnClickFakeTouch longPressAtPoint:point duration:5.0];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf->_longPressHolding = NO;
        });
    } else if (mode == AnClickActionModeTwoFingerTap) {
        [AnClickFakeTouch twoFingerTapAtPoint:point distance:72.0];
    } else if (mode == AnClickActionModePinchIn) {
        [AnClickFakeTouch pinchAtPoint:point fromDistance:168.0 toDistance:58.0 duration:0.46];
    } else if (mode == AnClickActionModePinchOut) {
        [AnClickFakeTouch pinchAtPoint:point fromDistance:58.0 toDistance:168.0 duration:0.46];
    } else if (mode == AnClickActionModeRotate) {
        [AnClickFakeTouch rotateAtPoint:point radius:64.0 startAngle:(CGFloat)(-M_PI / 4.0) endAngle:(CGFloat)(M_PI * 0.75) duration:0.58];
    } else {
        [AnClickFakeTouch tapAtPoint:point];
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

- (void)performImageTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow {
    [self performImageTask:task inWindow:hostWindow runGeneration:0 completion:nil];
}

- (void)performImageTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow runGeneration:(NSUInteger)runGeneration {
    [self performImageTask:task inWindow:hostWindow runGeneration:runGeneration completion:nil];
}

- (void)performImageTask:(NSDictionary *)task
                inWindow:(UIWindow *)hostWindow
           runGeneration:(NSUInteger)runGeneration
              completion:(void (^)(void))completion {
    NSString *templatePath = task[@"templatePath"];
    UIImage *templateImage = (templatePath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:templatePath]) ? [UIImage imageWithContentsOfFile:templatePath] : nil;
    if (!templateImage) {
        _statusLabel.text = @"识图无模板";
        if (completion) {
            completion();
        }
        return;
    }

    BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
    AnClickActionMode imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
    NSNumber *thresholdNumber = task[@"threshold"];
    double threshold = thresholdNumber ? MIN(1.0, MAX(0.0, thresholdNumber.doubleValue)) : 0.80;
    NSValue *customPointValue = task[@"point"];
    _templateSearchInProgress = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async([self templateSearchQueue], ^{
        __strong typeof(weakSelf) searchSelf = weakSelf;
        if (!searchSelf) {
            return;
        }
        NSDictionary *match = [AnClickCore findTemplateImageMatch:templateImage threshold:threshold];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf->_templateSearchInProgress = NO;
            UIWindow *currentHostWindow = [strongSelf hostWindowForCallbackWithFallback:hostWindow
                                                                          runGeneration:runGeneration
                                                                                 status:@"窗口变化停止"];
            if (!currentHostWindow) {
                return;
            }
            if (!match) {
                strongSelf->_statusLabel.text = @"识图未找到";
                [strongSelf showToast:@"识图未找到"];
                if (completion) {
                    completion();
                }
                return;
            }
            NSValue *matchPointValue = match[@"point"];
            NSValue *rectValue = match[@"rect"];
            NSNumber *scoreNumber = match[@"score"];
            if (!matchPointValue || !rectValue) {
                strongSelf->_statusLabel.text = @"识图异常";
                [strongSelf showToast:@"识图异常"];
                if (completion) {
                    completion();
                }
                return;
            }
            CGRect rect = rectValue.CGRectValue;
            [strongSelf showRecognitionBoxForScreenRect:rect score:scoreNumber.doubleValue inWindow:currentHostWindow duration:1.2];
            if (imageActionMode == AnClickActionModeNetwork) {
                [strongSelf performRecognitionNetworkActionForTask:task recognitionText:nil runGeneration:runGeneration completion:completion];
                strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识图 %.2f 网络请求",
                                                 scoreNumber.doubleValue];
                [strongSelf showToast:strongSelf->_statusLabel.text];
                return;
            }
            CGPoint actionPoint = useMatchPoint ? matchPointValue.CGPointValue : customPointValue.CGPointValue;
            [strongSelf performPointActionMode:imageActionMode atPoint:actionPoint inWindow:currentHostWindow];
            strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识图 %.2f %@ %.0f,%.0f",
                                             scoreNumber.doubleValue,
                                             [strongSelf actionNameForMode:imageActionMode],
                                             actionPoint.x,
                                             actionPoint.y];
            [strongSelf showToast:strongSelf->_statusLabel.text];
            if (completion) {
                completion();
            }
        });
    });
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
            completion:(void (^)(void))completion {
    NSString *targetText = [self trimmedActionDescription:task[@"ocrText"]];
    BOOL useRegex = [self ocrTaskUsesRegexMatching:task];
    if (targetText.length == 0) {
        _statusLabel.text = useRegex ? @"正则表达式未填写" : @"识字未填写";
        [self showToast:_statusLabel.text];
        if (completion) {
            completion();
        }
        return;
    }

    AnClickOCRMode ocrMode = [self ocrModeForTask:task];
    if (useRegex && ![self ocrRegexPatternIsValid:targetText]) {
        _statusLabel.text = @"正则表达式无效";
        [self showToast:_statusLabel.text];
        if (completion) {
            completion();
        }
        return;
    }
    AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
    BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
    NSValue *customPointValue = task[@"point"];
    if (actionMode != AnClickActionModeNetwork && !useMatchPoint && !customPointValue) {
        _statusLabel.text = @"识字未取点";
        if (completion) {
            completion();
        }
        return;
    }
    _templateSearchInProgress = YES;
    __weak typeof(self) weakSelf = self;
    [self hideToastForRecognitionCapture];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) delayedSelf = weakSelf;
        if (!delayedSelf) {
            return;
        }
        if (runGeneration != 0 &&
            ![delayedSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
            delayedSelf->_templateSearchInProgress = NO;
            return;
        }
        dispatch_async([delayedSelf templateSearchQueue], ^{
            NSDictionary *match = [AnClickOCR findText:targetText mode:ocrMode useRegex:useRegex];
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                strongSelf->_templateSearchInProgress = NO;
                UIWindow *currentHostWindow = [strongSelf hostWindowForCallbackWithFallback:hostWindow
                                                                              runGeneration:runGeneration
                                                                                     status:@"窗口变化停止"];
                if (!currentHostWindow) {
                    return;
                }
                NSString *error = [match[@"error"] isKindOfClass:NSString.class] ? match[@"error"] : nil;
                if (error.length > 0) {
                    strongSelf->_statusLabel.text = error;
                    [strongSelf showToast:error];
                    if (completion) {
                        completion();
                    }
                    return;
                }
                NSValue *pointValue = match[@"point"];
                NSValue *rectValue = match[@"rect"];
                NSNumber *scoreNumber = match[@"score"];
                NSString *text = [match[@"text"] isKindOfClass:NSString.class] ? match[@"text"] : targetText;
                NSInteger matchCount = [match[@"matchCount"] respondsToSelector:@selector(integerValue)] ? MAX(1, [match[@"matchCount"] integerValue]) : 1;
                NSString *matchSummary = matchCount > 1
                    ? [NSString stringWithFormat:@"%@ 命中%ld选1", useRegex ? @"正则" : @"包含", (long)matchCount]
                    : (useRegex ? @"正则" : @"包含");
                if (!pointValue || !rectValue) {
                    strongSelf->_statusLabel.text = @"识字未找到";
                    [strongSelf showToast:@"识字未找到"];
                    if (completion) {
                        completion();
                    }
                    return;
                }
                [strongSelf showRecognitionBoxForScreenRect:rectValue.CGRectValue score:scoreNumber ? scoreNumber.doubleValue : 1.0 inWindow:currentHostWindow duration:1.2];
                if (actionMode == AnClickActionModeNetwork) {
                    [strongSelf performRecognitionNetworkActionForTask:task recognitionText:text runGeneration:runGeneration completion:completion];
                    strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识字 %@ %@ 网络请求", matchSummary, text];
                    [strongSelf showToast:strongSelf->_statusLabel.text];
                    return;
                }
                CGPoint actionPoint = useMatchPoint ? pointValue.CGPointValue : customPointValue.CGPointValue;
                [strongSelf performPointActionMode:actionMode atPoint:actionPoint inWindow:currentHostWindow];
                strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识字 %@ %@ %.0f,%.0f",
                                                 matchSummary,
                                                 text,
                                                 actionPoint.x,
                                                 actionPoint.y];
                [strongSelf showToast:strongSelf->_statusLabel.text];
                if (completion) {
                    completion();
                }
            });
        });
    });
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
              completion:(void (^)(void))completion {
    NSArray<NSDictionary *> *colorPoints = [self normalizedColorPatternPointsForTask:task];
    if (colorPoints.count == 0) {
        _statusLabel.text = @"识色未取色";
        if (completion) {
            completion();
        }
        return;
    }

    double tolerance = [task[@"colorTolerance"] respondsToSelector:@selector(doubleValue)]
        ? MIN(255.0, MAX(0.0, [task[@"colorTolerance"] doubleValue]))
        : 18.0;
    AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
    NSString *patternSummary = [self colorPatternSummaryForTask:task];
    _templateSearchInProgress = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async([self templateSearchQueue], ^{
        NSDictionary *match = [AnClickCore findColorPatternMatchWithPoints:colorPoints tolerance:tolerance];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf->_templateSearchInProgress = NO;
            UIWindow *currentHostWindow = [strongSelf hostWindowForCallbackWithFallback:hostWindow
                                                                          runGeneration:runGeneration
                                                                                 status:@"窗口变化停止"];
            if (!currentHostWindow) {
                return;
            }
            if (!match) {
                strongSelf->_statusLabel.text = @"颜色未找到";
                [strongSelf showToast:@"颜色未找到"];
                if (completion) {
                    completion();
                }
                return;
            }
            NSValue *pointValue = match[@"point"];
            NSValue *rectValue = match[@"rect"];
            NSNumber *scoreNumber = match[@"score"];
            if (!pointValue || !rectValue) {
                strongSelf->_statusLabel.text = @"识色异常";
                [strongSelf showToast:@"识色异常"];
                if (completion) {
                    completion();
                }
                return;
            }
            [strongSelf showRecognitionBoxForScreenRect:rectValue.CGRectValue score:scoreNumber ? scoreNumber.doubleValue : 1.0 inWindow:currentHostWindow duration:1.2];
            if (actionMode == AnClickActionModeNetwork) {
                [strongSelf performRecognitionNetworkActionForTask:task recognitionText:nil runGeneration:runGeneration completion:completion];
                strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识色 %@ 网络请求", patternSummary];
                [strongSelf showToast:strongSelf->_statusLabel.text];
                return;
            }
            CGPoint actionPoint = pointValue.CGPointValue;
            [strongSelf performPointActionMode:actionMode atPoint:actionPoint inWindow:currentHostWindow];
            strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识色 %@ %.0f,%.0f",
                                             patternSummary,
                                             actionPoint.x,
                                             actionPoint.y];
            [strongSelf showToast:strongSelf->_statusLabel.text];
            if (completion) {
                completion();
            }
        });
    });
}

- (BOOL)taskIsComplete:(NSDictionary *)task {
    AnClickActionMode mode = [self modeForTask:task];
    if (mode == AnClickActionModeNone) {
        _statusLabel.text = @"任务未选择动作";
        return NO;
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
        if (actionMode == AnClickActionModeNetwork) {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            if (url.length == 0 || ![self normalizedNetworkURLString:url]) {
                _statusLabel.text = @"任务识图网络未设置";
                return NO;
            }
        } else if (!useMatchPoint && !task[@"point"]) {
            _statusLabel.text = @"任务识图未取点";
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
        if (actionMode == AnClickActionModeNetwork) {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            if (url.length == 0 || ![self normalizedNetworkURLString:url]) {
                _statusLabel.text = @"任务识字网络未设置";
                return NO;
            }
            if ([[self networkMethodForTask:task] isEqualToString:@"POST"] &&
                [task[@"networkPostBodyUsesOCRResult"] boolValue] &&
                [self networkPostKeyValueTextForTask:task].length == 0) {
                _statusLabel.text = @"任务POST键值未填写";
                return NO;
            }
        } else if (!useMatchPoint && !task[@"point"]) {
            _statusLabel.text = @"任务识字未取点";
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
        if (actionMode == AnClickActionModeNetwork) {
            NSString *url = [self trimmedActionDescription:task[@"networkURL"]];
            if (url.length == 0 || ![self normalizedNetworkURLString:url]) {
                _statusLabel.text = @"任务识色网络未设置";
                return NO;
            }
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

- (NSTimeInterval)performTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow runGeneration:(NSUInteger)runGeneration {
    if (![self taskIsComplete:task]) {
        return 0;
    }

    AnClickActionMode mode = [self modeForTask:task];
    NSInteger repeatCount = [self repeatCountForTask:task];
    NSTimeInterval delay = [self delayForTask:task];
    NSTimeInterval duration = [self durationForTaskMode:mode];
    if (mode == AnClickActionModeImage) {
        AnClickActionMode imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        duration = 0.75 + (imageActionMode == AnClickActionModeNetwork ? [self networkTimeoutForTask:task] + 0.25 : [self durationForTaskMode:imageActionMode]);
    } else if (mode == AnClickActionModeOCR) {
        AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        duration = 0.95 + (actionMode == AnClickActionModeNetwork ? [self networkTimeoutForTask:task] + 0.25 : [self durationForTaskMode:actionMode]);
    } else if (mode == AnClickActionModeColor) {
        AnClickActionMode actionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        duration = 0.75 + (actionMode == AnClickActionModeNetwork ? [self networkTimeoutForTask:task] + 0.25 : [self durationForTaskMode:actionMode]);
    } else if (mode == AnClickActionModeNetwork) {
        duration = 0.85;
    } else if (mode == AnClickActionModeMacro) {
        NSArray *events = [task[@"events"] isKindOfClass:NSArray.class] ? task[@"events"] : @[];
        duration = [self durationForRecordedEvents:events];
    }
    NSTimeInterval interval = duration + 0.12;

    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < repeatCount; i++) {
        NSTimeInterval fireDelay = delay + interval * i;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(fireDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
            if (mode == AnClickActionModeSwipe) {
                NSArray<NSValue *> *path = task[@"path"];
                [strongSelf showTrajectoryForScreenPoints:path inWindow:currentHostWindow duration:0.75];
                [AnClickFakeTouch playPath:path duration:0.55];
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
                NSArray<NSValue *> *trajectory = [strongSelf trajectoryPointsForRecordedEvents:events];
                if (trajectory.count >= 2) {
                    [strongSelf showTrajectoryForScreenPoints:trajectory inWindow:currentHostWindow duration:[strongSelf durationForRecordedEvents:events]];
                } else if (trajectory.count == 1) {
                    [strongSelf showTapMarkerAtScreenPoint:trajectory.firstObject.CGPointValue inWindow:currentHostWindow];
                }
                [AnClickFakeTouch playRecordedEvents:events];
            } else {
                NSValue *pointValue = task[@"point"];
                [strongSelf performPointActionMode:mode atPoint:pointValue.CGPointValue inWindow:currentHostWindow];
            }
        });
    }

    return delay + interval * repeatCount;
}

- (void)runTaskList {
    if (_taskRunActive || _taskRunPausedForForeground) {
        _volumeShortcutRunSuppressToasts = NO;
        [self stopTaskRunWithStatus:@"已停止"];
        return;
    }
    [self clearTaskRunPauseState];
    _volumeShortcutRunSuppressToasts = NO;
    [self startTaskListRunScheduled:NO];
}

- (void)monitorGlobalNetworkGateWithHostWindow:(UIWindow *)hostWindow scheduled:(BOOL)scheduled generation:(NSUInteger)runGeneration {
    if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
        return;
    }
    [self rememberTaskRunResumePointAtIndex:0 inGlobalNetworkGate:YES scheduled:scheduled];

    NSString *url = _globalNetworkURL;
    NSString *contains = _globalNetworkContainsText;
    NSString *falseText = _globalNetworkFalseText;
    __weak typeof(self) weakSelf = self;
    [self performNetworkRequestWithURLString:url method:@"GET" postBody:nil trueText:contains falseText:falseText defaultExpectedTrue:NO timeout:8.0 completion:^(BOOL matched, BOOL requestSucceeded, NSString *body, NSInteger statusCode, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf ||
            ![strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
            return;
        }
        UIWindow *currentHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:hostWindow];
        NSString *runRule = [strongSelf trimmedActionDescription:contains];
        BOOL blocked = requestSucceeded && [strongSelf networkBody:body matchesBlockText:falseText defaultExpectedTrue:NO];
        BOOL shouldRun = runRule.length > 0 ? matched : (requestSucceeded && !blocked);
        if (shouldRun) {
            strongSelf->_statusLabel.text = scheduled ? @"定时命中运行" : @"命中运行";
            [strongSelf showToast:strongSelf->_statusLabel.text];
            [strongSelf refreshCollapsedButtonTitle];
            [strongSelf runTaskAtIndex:0 inWindow:currentHostWindow generation:runGeneration];
            return;
        }

        strongSelf->_statusLabel.text = blocked
            ? @"命中不运行 继续监控"
            : (requestSucceeded
                ? @"未命中运行 继续监控"
                : [strongSelf networkStatusTextWithMatched:NO requestSucceeded:requestSucceeded statusCode:statusCode error:error]);
        [strongSelf showToast:strongSelf->_statusLabel.text];
        [strongSelf refreshCollapsedButtonTitle];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) retrySelf = weakSelf;
            if (!retrySelf ||
                ![retrySelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:currentHostWindow status:@"窗口变化停止"]) {
                return;
            }
            UIWindow *retryHostWindow = [retrySelf currentUsableHostWindowForTaskRunFallback:currentHostWindow];
            [retrySelf monitorGlobalNetworkGateWithHostWindow:retryHostWindow scheduled:scheduled generation:runGeneration];
        });
    }];
}

- (void)startTaskListRunScheduled:(BOOL)scheduled {
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

    _taskRunActive = YES;
    [self clearTaskRunPauseState];
    _currentGlobalRunCycle = 0;
    NSUInteger runGeneration = ++_taskRunGeneration;
    _statusLabel.text = _globalNetworkGateEnabled ? @"网络监控中" : (scheduled ? @"定时启动" : @"播放中");
    [self showToast:_statusLabel.text];
    [self refreshTaskList];
    [self collapsePanel];
    if (_globalNetworkGateEnabled) {
        [self rememberTaskRunResumePointAtIndex:0 inGlobalNetworkGate:YES scheduled:scheduled];
        [self monitorGlobalNetworkGateWithHostWindow:hostWindow scheduled:scheduled generation:runGeneration];
        return;
    }
    [self rememberTaskRunResumePointAtIndex:0 inGlobalNetworkGate:NO scheduled:scheduled];
    [self runTaskAtIndex:0 inWindow:hostWindow generation:runGeneration];
}

- (void)stopTaskRunWithStatus:(NSString *)status {
    [self stopTaskRunWithStatus:status showToast:YES];
}

- (void)stopTaskRunWithStatus:(NSString *)status showToast:(BOOL)showToast {
    if (!_taskRunActive && !_taskRunPausedForForeground) {
        return;
    }

    _taskRunActive = NO;
    [self clearTaskRunPauseState];
    _currentGlobalRunCycle = 0;
    _taskRunGeneration++;
    _statusLabel.text = status.length > 0 ? status : @"已停止";
    if (showToast) {
        [self showToast:_statusLabel.text];
    }
    _volumeShortcutRunSuppressToasts = NO;
    [self refreshCollapsedButtonTitle];
    [self refreshTaskList];
}

- (void)runTaskAtIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow {
    [self runTaskAtIndex:index inWindow:hostWindow generation:_taskRunGeneration];
}

- (void)runTaskAtIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow generation:(NSUInteger)runGeneration {
    if (![self taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:hostWindow status:@"窗口变化停止"]) {
        return;
    }
    UIWindow *currentHostWindow = [self currentUsableHostWindowForTaskRunFallback:hostWindow];
    [self rememberTaskRunResumePointAtIndex:index inGlobalNetworkGate:NO scheduled:_taskRunResumeScheduled];

    if (index >= _taskItems.count) {
        _currentGlobalRunCycle++;
        NSInteger repeatLimit = MAX(0, _globalRunRepeatCount);
        if (repeatLimit == 0 || _currentGlobalRunCycle < repeatLimit) {
            [self rememberTaskRunResumePointAtIndex:0 inGlobalNetworkGate:NO scheduled:_taskRunResumeScheduled];
            [self runTaskAtIndex:0 inWindow:currentHostWindow generation:runGeneration];
            return;
        }

        _taskRunActive = NO;
        [self clearTaskRunPauseState];
        _statusLabel.text = @"任务完成";
        [self showToast:@"任务完成"];
        _volumeShortcutRunSuppressToasts = NO;
        [self refreshCollapsedButtonTitle];
        [self refreshTaskList];
        return;
    }

    [self showToast:[self toastTextForTask:_taskItems[index] index:index]];
    if ([self modeForTask:_taskItems[index]] == AnClickActionModeNetwork) {
        if (![self taskIsComplete:_taskItems[index]]) {
            _taskRunActive = NO;
            [self clearTaskRunPauseState];
            [self expandPanel];
            [self showToast:_statusLabel.text];
            _volumeShortcutRunSuppressToasts = NO;
            [self refreshCollapsedButtonTitle];
            return;
        }
        [self runNetworkTask:_taskItems[index] atIndex:index inWindow:currentHostWindow generation:runGeneration];
        return;
    }

    if ([self taskUsesRecognitionNetworkAction:_taskItems[index]]) {
        if (![self taskIsComplete:_taskItems[index]]) {
            _taskRunActive = NO;
            [self clearTaskRunPauseState];
            [self expandPanel];
            [self showToast:_statusLabel.text];
            _volumeShortcutRunSuppressToasts = NO;
            [self refreshCollapsedButtonTitle];
            return;
        }
        [self runRecognitionNetworkTask:_taskItems[index] atIndex:index inWindow:currentHostWindow generation:runGeneration];
        return;
    }

    NSTimeInterval duration = [self performTask:_taskItems[index] inWindow:currentHostWindow runGeneration:runGeneration];
    if (duration <= 0) {
        _taskRunActive = NO;
        [self clearTaskRunPauseState];
        [self expandPanel];
        [self showToast:_statusLabel.text];
        _volumeShortcutRunSuppressToasts = NO;
        [self refreshCollapsedButtonTitle];
        return;
    }

    NSTimeInterval globalDelay = MAX(0.0, _globalDelayMilliseconds / 1000.0);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((duration + 0.12) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) delaySelf = weakSelf;
        if (!delaySelf ||
            ![delaySelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:currentHostWindow status:@"窗口变化停止"]) {
            return;
        }
        UIWindow *delayedHostWindow = [delaySelf currentUsableHostWindowForTaskRunFallback:currentHostWindow];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(globalDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf ||
                ![strongSelf taskRunIsStillValidWithGeneration:runGeneration fallbackWindow:delayedHostWindow status:@"窗口变化停止"]) {
                return;
            }
            UIWindow *nextHostWindow = [strongSelf currentUsableHostWindowForTaskRunFallback:delayedHostWindow];
            [strongSelf runTaskAtIndex:index + 1 inWindow:nextHostWindow generation:runGeneration];
        });
    });
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

- (void)removeColorPickMarkers {
    if (!_colorPickImageView) {
        return;
    }
    for (NSUInteger index = 0; index < AnClickColorPickMaxSamples; index++) {
        [[_colorPickImageView viewWithTag:AnClickColorPickMarkerTagBase + (NSInteger)index] removeFromSuperview];
    }
}

- (void)rebuildColorPickMarkers {
    if (!_colorPickImageView) {
        return;
    }

    [self removeColorPickMarkers];
    CGFloat zoomScale = MAX(0.01, _colorPickScrollView.zoomScale);
    for (NSUInteger index = 0; index < _pendingColorPickSamples.count && index < AnClickColorPickMaxSamples; index++) {
        NSDictionary *sample = _pendingColorPickSamples[index];
        if (![sample[@"x"] respondsToSelector:@selector(doubleValue)] ||
            ![sample[@"y"] respondsToSelector:@selector(doubleValue)]) {
            continue;
        }

        BOOL selected = _selectedColorPickSampleIndex == (NSInteger)index;
        CGFloat markerSize = (selected ? 20.0 : (index == 0 ? 18.0 : 15.0)) / zoomScale;
        UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, markerSize, markerSize)];
        marker.tag = AnClickColorPickMarkerTagBase + (NSInteger)index;
        marker.userInteractionEnabled = NO;
        marker.backgroundColor = UIColor.clearColor;
        marker.layer.cornerRadius = markerSize * 0.5;
        marker.layer.borderWidth = MAX(0.8, (selected ? 2.0 : 1.2) / zoomScale);
        marker.layer.borderColor = (selected ? UIColor.systemRedColor : (index == 0 ? [self themeHighlightColor] : UIColor.systemGreenColor)).CGColor;
        marker.layer.shadowColor = UIColor.blackColor.CGColor;
        marker.layer.shadowOpacity = 0.28;
        marker.layer.shadowRadius = 1.0 / zoomScale;
        marker.layer.shadowOffset = CGSizeZero;
        marker.center = CGPointMake([sample[@"x"] doubleValue], [sample[@"y"] doubleValue]);

        UILabel *numberLabel = [[UILabel alloc] initWithFrame:marker.bounds];
        numberLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)index + 1];
        numberLabel.textColor = UIColor.blackColor;
        numberLabel.textAlignment = NSTextAlignmentCenter;
        numberLabel.font = [UIFont monospacedDigitSystemFontOfSize:MAX(5.0, 9.0 / zoomScale) weight:UIFontWeightHeavy];
        numberLabel.backgroundColor = selected ? UIColor.systemRedColor : (index == 0 ? [self themeHighlightColor] : UIColor.systemGreenColor);
        numberLabel.layer.cornerRadius = markerSize * 0.5;
        numberLabel.clipsToBounds = YES;
        numberLabel.userInteractionEnabled = NO;
        [marker addSubview:numberLabel];
        [_colorPickImageView addSubview:marker];
    }
}

- (void)rebuildColorPickList {
    if (!_colorPickListView) {
        return;
    }

    for (UIView *view in _colorPickListView.subviews) {
        [view removeFromSuperview];
    }

    CGFloat rowHeight = 34.0;
    CGFloat gap = 5.0;
    CGFloat width = MAX(1.0, _colorPickListView.bounds.size.width);
    for (NSUInteger index = 0; index < _pendingColorPickSamples.count; index++) {
        NSDictionary *sample = _pendingColorPickSamples[index];
        BOOL selected = _selectedColorPickSampleIndex == (NSInteger)index;
        UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem];
        row.tag = AnClickColorPickRowTagBase + (NSInteger)index;
        row.frame = CGRectMake(0.0, (rowHeight + gap) * index, width, rowHeight);
        row.backgroundColor = selected
            ? [[self themeHighlightColor] colorWithAlphaComponent:0.30]
            : [UIColor colorWithWhite:1 alpha:0.08];
        row.layer.cornerRadius = 6;
        row.layer.borderWidth = 1;
        row.layer.borderColor = (selected ? [self themeHighlightColor] : [UIColor colorWithWhite:1 alpha:0.12]).CGColor;
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.contentEdgeInsets = UIEdgeInsetsMake(0, 38, 0, 8);
        row.titleLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
        row.titleLabel.adjustsFontSizeToFitWidth = YES;
        row.titleLabel.minimumScaleFactor = 0.62;
        [row setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [row addTarget:self action:@selector(handleColorPickRowTap:) forControlEvents:UIControlEventTouchUpInside];

        NSInteger red = [sample[@"red"] integerValue];
        NSInteger green = [sample[@"green"] integerValue];
        NSInteger blue = [sample[@"blue"] integerValue];
        NSString *hex = [self colorHexStringForSample:sample];
        NSString *role = [self colorPickRoleForIndex:index];
        NSString *coord = [self colorPickSampleHasCoordinate:sample]
            ? [NSString stringWithFormat:@"X%.0f Y%.0f", [sample[@"x"] doubleValue], [sample[@"y"] doubleValue]]
            : @"旧颜色";
        [row setTitle:[NSString stringWithFormat:@"%lu %@ %@ %@", (unsigned long)index + 1, role, hex, coord]
             forState:UIControlStateNormal];

        UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(10, 8, 18, 18)];
        swatch.userInteractionEnabled = NO;
        swatch.backgroundColor = [UIColor colorWithRed:MIN(255, MAX(0, red)) / 255.0
                                                 green:MIN(255, MAX(0, green)) / 255.0
                                                  blue:MIN(255, MAX(0, blue)) / 255.0
                                                 alpha:1.0];
        swatch.layer.cornerRadius = 4;
        swatch.layer.borderWidth = 1;
        swatch.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.32].CGColor;
        [row addSubview:swatch];
        [_colorPickListView addSubview:row];
    }

    CGFloat contentHeight = _pendingColorPickSamples.count == 0 ? 0.0 : (rowHeight + gap) * _pendingColorPickSamples.count - gap;
    _colorPickListView.contentSize = CGSizeMake(width, contentHeight);
    _colorPickListView.hidden = _pendingColorPickSamples.count == 0;
    _colorPickDeleteButton.enabled = _pendingColorPickSamples.count > 0;
    _colorPickDeleteButton.alpha = _pendingColorPickSamples.count > 0 ? 1.0 : 0.45;
}

- (void)refreshColorPickInfoLabelWithLastSample:(NSDictionary *)lastSample {
    NSDictionary *sample = lastSample ?: (_selectedColorPickSampleIndex >= 0 && _selectedColorPickSampleIndex < (NSInteger)_pendingColorPickSamples.count
        ? _pendingColorPickSamples[(NSUInteger)_selectedColorPickSampleIndex]
        : _pendingColorPickSamples.lastObject);
    if (!_colorPickInfoLabel) {
        return;
    }
    NSDictionary *previewSample = _pendingColorPickSamples.firstObject ?: sample;
    if (previewSample) {
        NSInteger previewRed = [previewSample[@"red"] integerValue];
        NSInteger previewGreen = [previewSample[@"green"] integerValue];
        NSInteger previewBlue = [previewSample[@"blue"] integerValue];
        _colorPickSwatchView.backgroundColor = [UIColor colorWithRed:MIN(255, MAX(0, previewRed)) / 255.0
                                                               green:MIN(255, MAX(0, previewGreen)) / 255.0
                                                                blue:MIN(255, MAX(0, previewBlue)) / 255.0
                                                               alpha:1.0];
    }
    if (!sample) {
        _colorPickInfoLabel.text = @"第1点为点击坐标";
        _colorPickSwatchView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        return;
    }
    if (![sample[@"x"] respondsToSelector:@selector(doubleValue)] ||
        ![sample[@"y"] respondsToSelector:@selector(doubleValue)]) {
        _colorPickInfoLabel.text = @"旧颜色 点截图重设";
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
    _colorPickInfoLabel.text = [NSString stringWithFormat:@"%lu点 %@ %@ X%.0f Y%.0f #%02lX%02lX%02lX",
                                (unsigned long)_pendingColorPickSamples.count,
                                [self colorPickRoleForIndex:displayIndex],
                                actionText,
                                [sample[@"x"] doubleValue],
                                [sample[@"y"] doubleValue],
                                (long)red,
                                (long)green,
                                (long)blue];
}

- (void)handleColorPickRowTap:(UIButton *)button {
    NSInteger index = button.tag - AnClickColorPickRowTagBase;
    if (index < 0 || index >= (NSInteger)_pendingColorPickSamples.count) {
        return;
    }
    _selectedColorPickSampleIndex = index;
    NSDictionary *sample = _pendingColorPickSamples[(NSUInteger)index];
    if ([self colorPickSampleHasCoordinate:sample]) {
        _pendingColorPickPoint = CGPointMake([sample[@"x"] doubleValue], [sample[@"y"] doubleValue]);
        _hasPendingColorPickPoint = YES;
        [self updateColorPickCursorAtImagePoint:_pendingColorPickPoint];
    }
    [self rebuildColorPickMarkers];
    [self rebuildColorPickList];
    [self refreshColorPickInfoLabelWithLastSample:sample];
}

- (void)deleteSelectedColorPickSample {
    if (_pendingColorPickSamples.count == 0) {
        _colorPickInfoLabel.text = @"没有可删点";
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
        _colorPickCursorView.hidden = YES;
    }
    [self rebuildColorPickMarkers];
    [self rebuildColorPickList];
    [self refreshColorPickInfoLabelWithLastSample:sample];
}

- (void)beginColorPicking {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        UIImage *image = [AnClickCore captureCurrentWindowImage];
        if (!image.CGImage) {
            strongSelf->_statusLabel.text = @"截图失败";
            [strongSelf restorePanelAfterExternalTap];
            return;
        }
        [strongSelf showColorPickOverlayWithImage:image hostWindow:hostWindow];
    });
}

- (void)showColorPickOverlayWithImage:(UIImage *)image hostWindow:(UIWindow *)hostWindow {
    [_colorPickWindow removeFromSuperview];
    _colorPickWindow.hidden = YES;
    _colorPickImage = image;
    _pendingColorPickSamples = [[self mutableColorSamplesArrayFromObject:_targetColorSamples] mutableCopy];
    _hasPendingColorPickPoint = NO;
    if (![self prepareColorPickPixelDataForImage:image]) {
        _statusLabel.text = @"取色初始化失败";
        [self restorePanelAfterExternalTap];
        return;
    }

    _colorPickWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    if (@available(iOS 13.0, *)) {
        _colorPickWindow.windowScene = hostWindow.windowScene ?: [self activeWindowScene];
    }
    _colorPickWindow.windowLevel = UIWindowLevelAlert + 2100;
    _colorPickWindow.backgroundColor = UIColor.blackColor;
    _colorPickWindow.rootViewController = [[UIViewController alloc] init];

    UIView *root = _colorPickWindow.rootViewController.view;
    root.backgroundColor = UIColor.blackColor;

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:root.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.delegate = self;
    scrollView.backgroundColor = UIColor.blackColor;
    scrollView.minimumZoomScale = 1.0;
    scrollView.maximumZoomScale = 8.0;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    [root addSubview:scrollView];
    _colorPickScrollView = scrollView;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    imageView.userInteractionEnabled = YES;
    [scrollView addSubview:imageView];
    _colorPickImageView = imageView;
    scrollView.contentSize = imageView.bounds.size;

    CGFloat minZoom = MIN(root.bounds.size.width / MAX(1.0, image.size.width),
                          root.bounds.size.height / MAX(1.0, image.size.height));
    minZoom = MIN(MAX(minZoom, 0.25), 1.0);
    scrollView.minimumZoomScale = minZoom;
    scrollView.zoomScale = minZoom;
    [self centerColorPickImageContent];

    UIView *cursor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 9, 9)];
    cursor.backgroundColor = UIColor.systemYellowColor;
    cursor.layer.cornerRadius = 4.5;
    cursor.layer.borderWidth = 1.0;
    cursor.layer.borderColor = UIColor.blackColor.CGColor;
    cursor.layer.shadowColor = UIColor.blackColor.CGColor;
    cursor.layer.shadowOpacity = 0.55;
    cursor.layer.shadowRadius = 1.0;
    cursor.layer.shadowOffset = CGSizeZero;
    cursor.hidden = YES;
    cursor.userInteractionEnabled = NO;
    [imageView addSubview:cursor];
    _colorPickCursorView = cursor;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleColorPickTap:)];
    [imageView addGestureRecognizer:tap];

    UIScrollView *listView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    listView.backgroundColor = [[self themePanelDarkColor] colorWithAlphaComponent:0.72];
    listView.layer.cornerRadius = 8;
    listView.layer.borderWidth = 1;
    listView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
    listView.clipsToBounds = YES;
    listView.showsVerticalScrollIndicator = YES;
    listView.hidden = YES;
    [root addSubview:listView];
    _colorPickListView = listView;

    UIView *toolbar = [[UIView alloc] initWithFrame:CGRectZero];
    toolbar.backgroundColor = [[self themePanelDarkColor] colorWithAlphaComponent:0.88];
    toolbar.layer.cornerRadius = 8;
    toolbar.layer.borderWidth = 1;
    toolbar.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
    toolbar.clipsToBounds = YES;
    [root addSubview:toolbar];
    _colorPickToolbar = toolbar;

    _colorPickSwatchView = [[UIView alloc] initWithFrame:CGRectZero];
    _colorPickSwatchView.layer.cornerRadius = 5;
    _colorPickSwatchView.layer.borderWidth = 1;
    _colorPickSwatchView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
    [toolbar addSubview:_colorPickSwatchView];

    _colorPickInfoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _colorPickInfoLabel.textColor = UIColor.whiteColor;
    _colorPickInfoLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    _colorPickInfoLabel.adjustsFontSizeToFitWidth = YES;
    _colorPickInfoLabel.minimumScaleFactor = 0.6;
    _colorPickInfoLabel.text = @"放大截图后点选颜色";
    [toolbar addSubview:_colorPickInfoLabel];

    UIButton *deleteButton = [self pointPickButtonWithTitle:@"删点" action:@selector(deleteSelectedColorPickSample)];
    deleteButton.tag = 4103;
    deleteButton.enabled = NO;
    deleteButton.alpha = 0.45;
    [toolbar addSubview:deleteButton];
    _colorPickDeleteButton = deleteButton;

    UIButton *confirmButton = [self pointPickButtonWithTitle:@"确定" action:@selector(confirmColorPicking)];
    confirmButton.tag = 4101;
    [toolbar addSubview:confirmButton];
    UIButton *cancelButton = [self pointPickButtonWithTitle:@"取消" action:@selector(cancelColorPicking)];
    cancelButton.tag = 4102;
    [toolbar addSubview:cancelButton];

    _selectedColorPickSampleIndex = -1;
    [self layoutColorPickToolbar];
    [self rebuildColorPickMarkers];
    [self rebuildColorPickList];
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

- (void)layoutColorPickToolbar {
    if (!_colorPickToolbar || !_colorPickWindow) {
        return;
    }

    UIView *root = _colorPickWindow.rootViewController.view;
    UIEdgeInsets safeInsets = [self overlaySafeAreaInsetsForView:root window:_colorPickWindow];
    CGFloat margin = 8.0;
    CGFloat toolbarHeight = 52.0;
    CGFloat availableWidth = MAX(1.0, root.bounds.size.width - safeInsets.left - safeInsets.right - margin * 2.0);
    CGFloat toolbarWidth = MIN(availableWidth, 390.0);
    CGFloat toolbarX = safeInsets.left + (availableWidth - toolbarWidth) * 0.5 + margin;
    CGFloat toolbarY = root.bounds.size.height - safeInsets.bottom - toolbarHeight - margin;
    toolbarY = MAX(safeInsets.top + margin, toolbarY);
    _colorPickToolbar.frame = CGRectMake(toolbarX,
                                         toolbarY,
                                         toolbarWidth,
                                         toolbarHeight);

    CGFloat listMaxHeight = MIN(168.0, MAX(0.0, toolbarY - safeInsets.top - margin * 2.0));
    CGFloat rowHeight = 34.0;
    CGFloat rowGap = 5.0;
    CGFloat wantedListHeight = _pendingColorPickSamples.count == 0
        ? 0.0
        : MIN(listMaxHeight, (rowHeight + rowGap) * _pendingColorPickSamples.count - rowGap + 12.0);
    _colorPickListView.frame = CGRectMake(toolbarX,
                                          toolbarY - wantedListHeight - 6.0,
                                          toolbarWidth,
                                          wantedListHeight);

    CGFloat swatchSize = MIN(34.0, MAX(24.0, toolbarWidth * 0.18));
    _colorPickSwatchView.frame = CGRectMake(10.0, (toolbarHeight - swatchSize) * 0.5, swatchSize, swatchSize);
    CGFloat buttonWidth = MIN(56.0, MAX(0.0, floor((toolbarWidth - margin * 4.0) / 3.0)));
    CGFloat buttonHeight = 34.0;
    CGFloat buttonY = (toolbarHeight - buttonHeight) * 0.5;
    UIButton *cancelButton = (UIButton *)[_colorPickToolbar viewWithTag:4102];
    UIButton *confirmButton = (UIButton *)[_colorPickToolbar viewWithTag:4101];
    UIButton *deleteButton = (UIButton *)[_colorPickToolbar viewWithTag:4103];
    cancelButton.frame = CGRectMake(toolbarWidth - margin - buttonWidth, buttonY, buttonWidth, buttonHeight);
    confirmButton.frame = CGRectMake(CGRectGetMinX(cancelButton.frame) - margin - buttonWidth, buttonY, buttonWidth, buttonHeight);
    deleteButton.frame = CGRectMake(CGRectGetMinX(confirmButton.frame) - margin - buttonWidth, buttonY, buttonWidth, buttonHeight);
    CGFloat infoX = CGRectGetMaxX(_colorPickSwatchView.frame) + 8.0;
    CGFloat infoWidth = MAX(0.0, CGRectGetMinX(deleteButton.frame) - infoX - 8.0);
    _colorPickInfoLabel.frame = CGRectMake(infoX,
                                           0,
                                           infoWidth,
                                           toolbarHeight);
    [self rebuildColorPickList];
}

- (void)centerColorPickImageContent {
    if (!_colorPickScrollView || !_colorPickImageView) {
        return;
    }
    CGSize boundsSize = _colorPickScrollView.bounds.size;
    CGRect frame = _colorPickImageView.frame;
    frame.origin.x = frame.size.width < boundsSize.width ? (boundsSize.width - frame.size.width) * 0.5 : 0;
    frame.origin.y = frame.size.height < boundsSize.height ? (boundsSize.height - frame.size.height) * 0.5 : 0;
    _colorPickImageView.frame = frame;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if (scrollView == _captureScrollView) {
        return _captureImageView;
    }
    if (scrollView == _pointPickScrollView) {
        return _pointPickImageView;
    }
    if (scrollView == _colorPickScrollView) {
        return _colorPickImageView;
    }
    return nil;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (scrollView == _captureScrollView) {
        [self centerCaptureImageContent];
        [self layoutCaptureActionButtonsAvoidingSelection];
        return;
    }
    if (scrollView == _pointPickScrollView) {
        [self centerPointPickImageContent];
        if (_hasPendingPointPickPoint) {
            [self updatePointPickCursor];
        }
        if (_actionMode == AnClickActionModeSwipe && _hasManualSwipeAnchor) {
            [self showPointPickSwipeStartMarker];
        }
        return;
    }
    if (scrollView == _colorPickScrollView) {
        [self centerColorPickImageContent];
        if (_hasPendingColorPickPoint) {
            [self updateColorPickCursorAtImagePoint:_pendingColorPickPoint];
        }
        [self rebuildColorPickMarkers];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == _captureScrollView) {
        [self layoutCaptureActionButtonsAvoidingSelection];
        return;
    }
    if (scrollView == _pointPickScrollView) {
        [self layoutPointPickToolbar];
        return;
    }
}

- (void)updateColorPickCursorAtImagePoint:(CGPoint)point {
    if (!_colorPickCursorView) {
        return;
    }

    CGFloat zoomScale = MAX(0.01, _colorPickScrollView.zoomScale);
    CGFloat cursorSize = 9.0 / zoomScale;
    _colorPickCursorView.bounds = CGRectMake(0, 0, cursorSize, cursorSize);
    _colorPickCursorView.center = point;
    _colorPickCursorView.layer.cornerRadius = cursorSize * 0.5;
    _colorPickCursorView.layer.borderWidth = 1.0 / zoomScale;
    _colorPickCursorView.layer.shadowRadius = 1.0 / zoomScale;
    _colorPickCursorView.hidden = NO;
}

- (void)handleColorPickTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded || !_colorPickImage) {
        return;
    }
    CGPoint point = [recognizer locationInView:_colorPickImageView];
    point.x = MIN(MAX(point.x, 0.0), _colorPickImage.size.width);
    point.y = MIN(MAX(point.y, 0.0), _colorPickImage.size.height);

    NSInteger red = 0;
    NSInteger green = 0;
    NSInteger blue = 0;
    if (![self sampleColorAtImagePoint:point image:_colorPickImage red:&red green:&green blue:&blue]) {
        _colorPickInfoLabel.text = @"取色失败";
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
        _colorPickInfoLabel.text = [NSString stringWithFormat:@"最多支持%lu点", (unsigned long)AnClickColorPickMaxSamples];
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
    [self rebuildColorPickMarkers];
    [self rebuildColorPickList];
    [self refreshColorPickInfoLabelWithLastSample:displaySample];
    BOOL sampledWhite = red >= 245 && green >= 245 && blue >= 245;
    _colorPickInfoLabel.text = [NSString stringWithFormat:@"%@ #%02lX%02lX%02lX  X%.0f Y%.0f",
                                sampledWhite ? @"采样白色 截图可能白底" : @"采样",
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

- (void)finishColorPickingOverlay {
    _colorPickWindow.hidden = YES;
    _colorPickWindow = nil;
    _colorPickScrollView = nil;
    _colorPickImageView = nil;
    _colorPickCursorView = nil;
    _colorPickToolbar = nil;
    _colorPickListView = nil;
    _colorPickInfoLabel = nil;
    _colorPickSwatchView = nil;
    _colorPickDeleteButton = nil;
    _colorPickImage = nil;
    _pendingColorPickSamples = [NSMutableArray array];
    _selectedColorPickSampleIndex = -1;
    _hasPendingColorPickPoint = NO;
    [self clearColorPickPixelData];
    [self restorePanelAfterExternalTap];
}

- (void)confirmColorPicking {
    if (_pendingColorPickSamples.count == 0) {
        _colorPickInfoLabel.text = @"先点选颜色";
        return;
    }
    [self applyTargetColorSamples:_pendingColorPickSamples];
    [self finishColorPickingOverlay];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
    [self autosaveSelectedTaskIfPossible];
}

- (void)cancelColorPicking {
    [self finishColorPickingOverlay];
    _statusLabel.text = @"取消取色";
}

- (void)beginPointPicking {
    if (_actionMode == AnClickActionModeNone) {
        _statusLabel.text = @"先选择动作";
        return;
    }

    if (_actionMode == AnClickActionModeColor) {
        [self beginColorPicking];
        return;
    }

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
            [self refreshEditorConfigControls];
        } else if (_actionMode == AnClickActionModeOCR) {
            _ocrUsesMatchPoint = NO;
            [self refreshEditorConfigControls];
        }
    }

    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        UIImage *image = [AnClickCore captureCurrentWindowImage];
        if (!image.CGImage) {
            strongSelf->_statusLabel.text = @"截图失败";
            [strongSelf restorePanelAfterExternalTap];
            return;
        }
        [strongSelf showPointPickOverlayWithImage:image hostWindow:hostWindow];
    });
}

- (void)showPointPickOverlayWithImage:(UIImage *)image hostWindow:(UIWindow *)hostWindow {
    [_pointPickOverlay removeFromSuperview];
    _pointPickWindow.hidden = YES;
    _pointPickSnapshot = image;
    _pointPickHostWindow = hostWindow;

    _pointPickWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    if (@available(iOS 13.0, *)) {
        _pointPickWindow.windowScene = hostWindow.windowScene ?: [self activeWindowScene];
    }
    _pointPickWindow.windowLevel = UIWindowLevelAlert + 2000;
    _pointPickWindow.backgroundColor = UIColor.blackColor;
    _pointPickWindow.rootViewController = [[UIViewController alloc] init];
    _pointPickWindow.rootViewController.view.frame = _pointPickWindow.bounds;
    _pointPickWindow.rootViewController.view.backgroundColor = UIColor.blackColor;

    UIView *overlay = [[UIView alloc] initWithFrame:_pointPickWindow.rootViewController.view.bounds];
    overlay.backgroundColor = UIColor.blackColor;
    overlay.userInteractionEnabled = YES;
    [_pointPickWindow.rootViewController.view addSubview:overlay];
    _pointPickOverlay = overlay;

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:overlay.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.delegate = self;
    scrollView.backgroundColor = UIColor.blackColor;
    scrollView.minimumZoomScale = 1.0;
    scrollView.maximumZoomScale = 8.0;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.panGestureRecognizer.minimumNumberOfTouches = 2;
    [overlay addSubview:scrollView];
    _pointPickScrollView = scrollView;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    imageView.userInteractionEnabled = YES;
    [scrollView addSubview:imageView];
    _pointPickImageView = imageView;
    scrollView.contentSize = imageView.bounds.size;
    [self updatePointPickZoomForCurrentBounds];
    scrollView.zoomScale = scrollView.minimumZoomScale;
    [self centerPointPickImageContent];

    UIEdgeInsets safeInsets = [self overlaySafeAreaInsetsForView:overlay window:_pointPickWindow];
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(12,
                                                              safeInsets.top + 12.0,
                                                              overlay.bounds.size.width - 24.0,
                                                              38.0)];
    hint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    hint.text = @"双指缩放移动，单指点选或微调";
    hint.textColor = UIColor.whiteColor;
    hint.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    hint.adjustsFontSizeToFitWidth = YES;
    hint.textAlignment = NSTextAlignmentCenter;
    [overlay addSubview:hint];

    CGFloat cursorSize = 32.0;
    UIView *cursor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cursorSize, cursorSize)];
    cursor.backgroundColor = UIColor.clearColor;
    cursor.layer.cornerRadius = cursorSize * 0.5;
    cursor.layer.borderWidth = 1.25;
    cursor.layer.borderColor = UIColor.systemYellowColor.CGColor;
    cursor.userInteractionEnabled = NO;
    UIView *horizontal = [[UIView alloc] initWithFrame:CGRectMake(6, cursorSize * 0.5 - 0.5, cursorSize - 12, 1)];
    horizontal.tag = 1;
    horizontal.backgroundColor = UIColor.systemYellowColor;
    horizontal.userInteractionEnabled = NO;
    [cursor addSubview:horizontal];
    UIView *vertical = [[UIView alloc] initWithFrame:CGRectMake(cursorSize * 0.5 - 0.5, 6, 1, cursorSize - 12)];
    vertical.tag = 2;
    vertical.backgroundColor = UIColor.systemYellowColor;
    vertical.userInteractionEnabled = NO;
    [cursor addSubview:vertical];
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(cursorSize * 0.5 - 2, cursorSize * 0.5 - 2, 4, 4)];
    dot.tag = 3;
    dot.backgroundColor = UIColor.systemRedColor;
    dot.layer.cornerRadius = 2;
    dot.userInteractionEnabled = NO;
    [cursor addSubview:dot];
    [imageView addSubview:cursor];
    _pointCursorView = cursor;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointPickingTap:)];
    tap.cancelsTouchesInView = NO;
    [imageView addGestureRecognizer:tap];
    UIPanGestureRecognizer *overlayPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointPickingOverlayPan:)];
    overlayPan.maximumNumberOfTouches = 1;
    overlayPan.cancelsTouchesInView = NO;
    [imageView addGestureRecognizer:overlayPan];

    UIView *toolbar = [[UIView alloc] initWithFrame:CGRectZero];
    toolbar.backgroundColor = [[self themePanelDarkColor] colorWithAlphaComponent:0.72];
    toolbar.layer.cornerRadius = 6;
    toolbar.layer.borderWidth = 1;
    toolbar.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
    toolbar.clipsToBounds = YES;
    [overlay addSubview:toolbar];
    _pointPickToolbar = toolbar;

    _pointCoordinateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _pointCoordinateLabel.textColor = UIColor.whiteColor;
    _pointCoordinateLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    _pointCoordinateLabel.adjustsFontSizeToFitWidth = YES;
    _pointCoordinateLabel.minimumScaleFactor = 0.65;
    [toolbar addSubview:_pointCoordinateLabel];

    UIButton *confirmButton = [self pointPickButtonWithTitle:@"确定" action:@selector(confirmPointPicking)];
    confirmButton.tag = 1001;
    [toolbar addSubview:confirmButton];

    UIButton *cancelButton = [self pointPickButtonWithTitle:@"取消" action:@selector(cancelPointPicking)];
    cancelButton.tag = 1002;
    [toolbar addSubview:cancelButton];

    _pendingPointPickPoint = [self initialPointPickPointInOverlay:overlay];
    _hasPendingPointPickPoint = YES;
    if (_actionMode == AnClickActionModeSwipe && _pickingSwipeEndPoint && _hasManualSwipeAnchor) {
        [self showPointPickSwipeStartMarker];
    }
    _pointPickWindow.hidden = NO;
    [self updatePointPickCursor];
    _statusLabel.text = _pickingSwipeEndPoint ? @"滑动取终点" : @"拖动取点";
}

- (CGPoint)initialPointPickPointInOverlay:(UIView *)overlay {
    UIWindow *hostWindow = _pointPickHostWindow;
    if (_actionMode == AnClickActionModeSwipe && _pickingSwipeEndPoint && _hasManualSwipeAnchor && hostWindow) {
        return [self clampedPointPickPoint:[hostWindow convertPoint:_manualSwipeAnchor fromWindow:nil] inOverlay:overlay];
    }
    if ([self hasManualPointForMode:_actionMode] && hostWindow) {
        return [self clampedPointPickPoint:[hostWindow convertPoint:_manualActionPoints[(NSUInteger)_actionMode] fromWindow:nil]
                                  inOverlay:overlay];
    }
    CGRect bounds = _pointPickImageView ? _pointPickImageView.bounds : (overlay ? overlay.bounds : CGRectMake(0, 0, _pointPickSnapshot.size.width, _pointPickSnapshot.size.height));
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

- (CGPoint)clampedPointPickPoint:(CGPoint)point inOverlay:(UIView *)overlay {
    CGRect bounds = _pointPickImageView ? _pointPickImageView.bounds : (overlay ? overlay.bounds : CGRectMake(0, 0, _pointPickSnapshot.size.width, _pointPickSnapshot.size.height));
    point.x = MIN(MAX(point.x, 0.0), bounds.size.width);
    point.y = MIN(MAX(point.y, 0.0), bounds.size.height);
    return point;
}

- (void)updatePointPickCursor {
    if (!_pointPickImageView || !_pointCursorView || !_hasPendingPointPickPoint) {
        return;
    }
    _pendingPointPickPoint = [self clampedPointPickPoint:_pendingPointPickPoint inOverlay:_pointPickOverlay];

    CGFloat zoomScale = MAX(0.01, _pointPickScrollView.zoomScale);
    CGFloat cursorSize = 28.0 / zoomScale;
    _pointCursorView.bounds = CGRectMake(0, 0, cursorSize, cursorSize);
    _pointCursorView.center = _pendingPointPickPoint;
    _pointCursorView.layer.cornerRadius = cursorSize * 0.5;
    _pointCursorView.layer.borderWidth = MAX(0.8, 1.2 / zoomScale);

    UIView *horizontal = [_pointCursorView viewWithTag:1];
    UIView *vertical = [_pointCursorView viewWithTag:2];
    UIView *dot = [_pointCursorView viewWithTag:3];
    CGFloat lineInset = 5.0 / zoomScale;
    CGFloat lineThickness = MAX(0.8, 1.0 / zoomScale);
    horizontal.frame = CGRectMake(lineInset,
                                  cursorSize * 0.5 - lineThickness * 0.5,
                                  MAX(0.0, cursorSize - lineInset * 2.0),
                                  lineThickness);
    vertical.frame = CGRectMake(cursorSize * 0.5 - lineThickness * 0.5,
                                lineInset,
                                lineThickness,
                                MAX(0.0, cursorSize - lineInset * 2.0));
    CGFloat dotSize = MAX(2.0, 4.0 / zoomScale);
    dot.frame = CGRectMake((cursorSize - dotSize) * 0.5,
                           (cursorSize - dotSize) * 0.5,
                           dotSize,
                           dotSize);
    dot.layer.cornerRadius = dotSize * 0.5;

    CGPoint screenPoint = [self pointPickScreenPointFromImagePoint:_pendingPointPickPoint];
    BOOL pickingCustomClickPoint = _actionMode == AnClickActionModeImage || _actionMode == AnClickActionModeOCR;
    NSString *stage = (_actionMode == AnClickActionModeSwipe)
        ? (_pickingSwipeEndPoint ? @"终点" : @"起点")
        : (pickingCustomClickPoint ? @"点击点" : [self currentActionName]);
    _pointCoordinateLabel.text = [NSString stringWithFormat:@"%@  X %.0f  Y %.0f",
                                  stage,
                                  screenPoint.x,
                                  screenPoint.y];
    [self layoutPointPickToolbar];
}

- (UIButton *)pointPickButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    button.backgroundColor = [title isEqualToString:@"确定"]
        ? [UIColor colorWithRed:0.86 green:0.55 blue:0.18 alpha:0.92]
        : [UIColor colorWithWhite:1 alpha:0.10];
    button.layer.cornerRadius = 5;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)layoutPointPickToolbar {
    if (!_pointPickOverlay || !_pointPickToolbar) {
        return;
    }

    CGFloat margin = 8.0;
    CGFloat toolbarHeight = 48.0;
    UIEdgeInsets safeInsets = [self overlaySafeAreaInsetsForView:_pointPickOverlay window:_pointPickWindow];
    CGFloat topY = MAX(margin, safeInsets.top + margin);
    CGFloat bottomY = _pointPickOverlay.bounds.size.height - toolbarHeight - MAX(margin, safeInsets.bottom + margin);
    bottomY = MAX(topY, bottomY);
    CGFloat availableWidth = MAX(1.0, _pointPickOverlay.bounds.size.width - safeInsets.left - safeInsets.right - margin * 2.0);
    CGFloat toolbarWidth = MIN(availableWidth, 360.0);
    CGFloat x = safeInsets.left + margin + (availableWidth - toolbarWidth) * 0.5;
    CGPoint overlayPoint = _hasPendingPointPickPoint && _pointPickImageView
        ? [_pointPickImageView convertPoint:_pendingPointPickPoint toView:_pointPickOverlay]
        : CGPointMake(CGRectGetMidX(_pointPickOverlay.bounds), CGRectGetMidY(_pointPickOverlay.bounds));
    BOOL cursorNearBottom = overlayPoint.y > bottomY - 20.0;
    CGFloat y = cursorNearBottom ? topY : bottomY;
    _pointPickToolbar.frame = CGRectMake(x, y, toolbarWidth, toolbarHeight);

    CGFloat buttonWidth = MIN(64.0, MAX(0.0, floor((toolbarWidth - margin * 3.0) / 2.0)));
    CGFloat buttonHeight = 34.0;
    CGFloat buttonY = (toolbarHeight - buttonHeight) * 0.5;
    UIButton *confirmButton = (UIButton *)[_pointPickToolbar viewWithTag:1001];
    UIButton *cancelButton = (UIButton *)[_pointPickToolbar viewWithTag:1002];
    cancelButton.frame = CGRectMake(toolbarWidth - margin - buttonWidth, buttonY, buttonWidth, buttonHeight);
    confirmButton.frame = CGRectMake(CGRectGetMinX(cancelButton.frame) - margin - buttonWidth, buttonY, buttonWidth, buttonHeight);
    _pointCoordinateLabel.frame = CGRectMake(10, 0, MAX(0.0, CGRectGetMinX(confirmButton.frame) - 18), toolbarHeight);
}

- (BOOL)pointPickLocationHitsToolbar:(CGPoint)location {
    return _pointPickToolbar && CGRectContainsPoint(_pointPickToolbar.frame, location);
}

- (void)showPointPickSwipeStartMarker {
    if (!_pointPickImageView || !_hasManualSwipeAnchor) {
        return;
    }

    [[_pointPickImageView viewWithTag:2201] removeFromSuperview];
    CGFloat zoomScale = MAX(0.01, _pointPickScrollView.zoomScale);
    CGFloat size = 22.0 / zoomScale;
    UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    marker.tag = 2201;
    marker.center = [self clampedPointPickPoint:[self pointPickImagePointFromScreenPoint:_manualSwipeAnchor] inOverlay:_pointPickOverlay];
    marker.userInteractionEnabled = NO;
    marker.backgroundColor = UIColor.clearColor;
    marker.layer.cornerRadius = size * 0.5;
    marker.layer.borderWidth = MAX(1.0, 1.8 / zoomScale);
    marker.layer.borderColor = UIColor.systemGreenColor.CGColor;

    CGFloat dotSize = MAX(2.0, 4.0 / zoomScale);
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake((size - dotSize) * 0.5,
                                                           (size - dotSize) * 0.5,
                                                           dotSize,
                                                           dotSize)];
    dot.backgroundColor = UIColor.systemGreenColor;
    dot.layer.cornerRadius = dotSize * 0.5;
    dot.userInteractionEnabled = NO;
    [marker addSubview:dot];
    if (_pointCursorView) {
        [_pointPickImageView insertSubview:marker belowSubview:_pointCursorView];
    } else {
        [_pointPickImageView addSubview:marker];
    }
}

- (void)finishPointPickingOverlay {
    [_pointPickOverlay removeFromSuperview];
    _pointPickOverlay = nil;
    _pointPickScrollView = nil;
    _pointPickImageView = nil;
    _pointCursorView = nil;
    _pointPickToolbar = nil;
    _pointCoordinateLabel = nil;
    _pointPickSnapshot = nil;
    _hasPendingPointPickPoint = NO;
    _pointPickWindow.hidden = YES;
    _pointPickWindow = nil;
    _pointPickHostWindow = nil;
    _pickingSwipeEndPoint = NO;
    [self restorePanelAfterExternalTap];
}

- (void)cancelPointPicking {
    [self finishPointPickingOverlay];
    _statusLabel.text = @"取消取点";
}

- (void)handlePointPickingTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded || !_pointPickImageView) {
        return;
    }
    CGPoint location = [recognizer locationInView:_pointPickImageView];
    _pendingPointPickPoint = [self clampedPointPickPoint:location inOverlay:_pointPickOverlay];
    _hasPendingPointPickPoint = YES;
    [self updatePointPickCursor];
}

- (void)handlePointPickingOverlayPan:(UIPanGestureRecognizer *)recognizer {
    if (!_pointPickImageView) {
        return;
    }
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [recognizer setTranslation:CGPointZero inView:_pointPickImageView];
        return;
    }
    if (recognizer.state == UIGestureRecognizerStateChanged ||
        recognizer.state == UIGestureRecognizerStateEnded) {
        CGPoint translation = [recognizer translationInView:_pointPickImageView];
        _pendingPointPickPoint = [self clampedPointPickPoint:CGPointMake(_pendingPointPickPoint.x + translation.x,
                                                                         _pendingPointPickPoint.y + translation.y)
                                                  inOverlay:_pointPickOverlay];
        _hasPendingPointPickPoint = YES;
        [self updatePointPickCursor];
        [recognizer setTranslation:CGPointZero inView:_pointPickImageView];
    }
}

- (void)handlePointCursorPan:(UIPanGestureRecognizer *)recognizer {
    if (!_pointPickImageView) {
        return;
    }
    CGPoint translation = [recognizer translationInView:_pointPickImageView];
    _pendingPointPickPoint = [self clampedPointPickPoint:CGPointMake(_pendingPointPickPoint.x + translation.x,
                                                                     _pendingPointPickPoint.y + translation.y)
                                              inOverlay:_pointPickOverlay];
    _hasPendingPointPickPoint = YES;
    [self updatePointPickCursor];
    [recognizer setTranslation:CGPointZero inView:_pointPickImageView];
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

    if (_actionMode == AnClickActionModeSwipe) {
        if (!_pickingSwipeEndPoint) {
            _manualSwipeAnchor = screenPoint;
            _hasManualSwipeAnchor = YES;
            _hasManualSwipeEndPoint = NO;
            _manualSwipeEndPoint = CGPointZero;
            _pickingSwipeEndPoint = YES;
            _pendingPointPickPoint = [self pointPickImagePointFromScreenPoint:screenPoint];
            [self showPointPickSwipeStartMarker];
            [self updatePointPickCursor];
            [self refreshEditorConfigControls];
            _statusLabel.text = @"起点已定 继续终点";
            return;
        }

        _manualSwipeEndPoint = screenPoint;
        _hasManualSwipeEndPoint = YES;
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
        [self refreshEditorConfigControls];
        [self updateStatusForCurrentConfig];
        [self autosaveSelectedTaskIfPossible];
        return;
    }

    _manualActionPoints[(NSUInteger)_actionMode] = screenPoint;
    _hasManualActionPoint[(NSUInteger)_actionMode] = YES;
    [self finishPointPickingOverlay];
    [self refreshEditorConfigControls];
    [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
    [self updateStatusForCurrentConfig];
    [self autosaveSelectedTaskIfPossible];
}

- (void)runManualAction {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    NSMutableDictionary *task = [self taskDictionaryFromCurrentConfigRequireComplete:YES];
    if (!task) {
        return;
    }
    [self preparePanelForExternalTapWithHostWindow:hostWindow];
    NSTimeInterval duration = [self performTask:task inWindow:hostWindow];
    if (duration > 0) {
        _statusLabel.text = [NSString stringWithFormat:@"执行%@ %@", [self currentActionName], [self commonConfigSummary]];
    }
}

- (void)previewCurrentAction {
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
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
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
            [self syncNetworkFieldsFromEditor];
            _statusLabel.text = _networkURL.length > 0 ? @"识图成功后请求网络" : @"先填网络链接";
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
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
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
            [self syncNetworkFieldsFromEditor];
            _statusLabel.text = _networkURL.length > 0 ? @"识字成功后请求网络" : @"先填网络链接";
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
        NSTimeInterval previewDuration = (_imageActionMode == AnClickActionModeLongPress) ? 2.0 : 1.0;
        AnClickActionMode actionMode = _imageActionMode;
        [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf showOperationTraceForMode:actionMode atPoint:point inWindow:hostWindow duration:previewDuration];
            strongSelf->_statusLabel.text = [NSString stringWithFormat:@"预览识字%@ %.0f,%.0f", [strongSelf actionNameForMode:actionMode], point.x, point.y];
            [strongSelf restorePanelAfterScreenDelay:previewDuration + 0.1];
        });
        return;
    }

    if (_actionMode == AnClickActionModeNetwork) {
        NSMutableDictionary *task = [self taskDictionaryFromCurrentConfigRequireComplete:YES];
        if (!task) {
            return;
        }
        _statusLabel.text = @"测试网络";
        [self performNetworkRequestTask:task runGeneration:0 completion:nil];
        return;
    }

    if (_actionMode == AnClickActionModeColor) {
        if (_imageActionMode == AnClickActionModeNetwork) {
            [self syncNetworkFieldsFromEditor];
            _statusLabel.text = _networkURL.length > 0 ? @"识色成功后请求网络" : @"先填网络链接";
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
        __weak typeof(self) weakSelf = self;
        dispatch_async([self templateSearchQueue], ^{
            NSDictionary *match = [AnClickCore findColorPatternMatchWithPoints:colorPoints tolerance:tolerance];
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
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
                strongSelf->_statusLabel.text = [NSString stringWithFormat:@"预览识色 %@ %.0f,%.0f", patternSummary, point.x, point.y];
                [strongSelf restorePanelAfterScreenDelay:previewDuration + 0.1];
            });
        });
        return;
    }

    if (![self hasManualPointForMode:_actionMode]) {
        _statusLabel.text = @"先取点";
        return;
    }
    CGPoint point = _manualActionPoints[(NSUInteger)_actionMode];
    NSTimeInterval previewDuration = (_actionMode == AnClickActionModeLongPress) ? 2.0 : 1.0;
    AnClickActionMode actionMode = _actionMode;
    NSString *actionName = [self currentActionName];
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
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
        [_macroRecordButton setTitle:@"重新录制" forState:UIControlStateNormal];
        [self styleRecordButton:_macroRecordButton active:NO];
        _statusLabel.text = [NSString stringWithFormat:@"已录 %lu步", (unsigned long)_recordedMacroEvents.count];
        [self refreshCollapsedButtonTitle];
        if (_returnToEditorAfterRecording) {
            _taskEditorVisible = YES;
            [self expandPanel];
        }
        _returnToEditorAfterRecording = NO;
        [self refreshEditorConfigControls];
        [self autosaveSelectedTaskIfPossible];
        return;
    }

    _actionMode = AnClickActionModeMacro;
    _recordedMacroEvents = nil;
    _returnToEditorAfterRecording = _taskEditorVisible;
    [recorder startRecording];
    [_macroRecordButton setTitle:@"停止录制" forState:UIControlStateNormal];
    [self styleRecordButton:_macroRecordButton active:YES];
    [self invalidatePendingPanelRestore];
    [self refreshModeButtons];
    [self showCollapsedRecordingButton];
    _statusLabel.text = @"录制中";
}

- (void)playRecordedMacro {
    if (_recordedMacroEvents.count == 0) {
        _statusLabel.text = @"无录制";
        return;
    }

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    NSTimeInterval duration = [self durationForRecordedEvents:_recordedMacroEvents];
    [self hidePanelForScreenInteractionWithHostWindow:hostWindow];
    NSArray<NSValue *> *trajectory = [self recordedMacroTrajectoryPoints];
    NSArray<NSDictionary *> *recordedEvents = [_recordedMacroEvents copy];
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
        [AnClickFakeTouch playRecordedEvents:recordedEvents];
        [strongSelf restorePanelAfterScreenDelay:duration + 0.15];
    });
    _statusLabel.text = [NSString stringWithFormat:@"回放 %lu步", (unsigned long)_recordedMacroEvents.count];
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

- (dispatch_queue_t)templateSearchQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.anclick.template-search", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

- (void)playTemplateTap {
    if (_templateSearchInProgress) {
        _statusLabel.text = @"识图中";
        return;
    }

    [self syncImageThresholdFromField];
    NSString *path = [self activeTemplatePath];
    if (path.length == 0) {
        path = [self templatePath];
    }
    UIImage *templateImage = [[NSFileManager defaultManager] fileExistsAtPath:path] ? [UIImage imageWithContentsOfFile:path] : nil;
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
    _playButton.enabled = NO;
    _playButton.alpha = 0.55;
    double matchThreshold = _matchThreshold;
    [self preparePanelForExternalTapWithHostWindow:hostWindow];
    __weak typeof(self) weakSelf = self;
    dispatch_async([self templateSearchQueue], ^{
        __strong typeof(weakSelf) searchSelf = weakSelf;
        if (!searchSelf) {
            return;
        }
        NSDictionary *match = [AnClickCore findTemplateImageMatch:templateImage threshold:matchThreshold];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf->_templateSearchInProgress = NO;
            strongSelf->_playButton.enabled = YES;
            strongSelf->_playButton.alpha = 1.0;
            if (!match) {
                [strongSelf restorePanelAfterExternalTap];
                strongSelf->_statusLabel.text = @"未找到";
                return;
            }
            NSValue *pointValue = match[@"point"];
            NSValue *rectValue = match[@"rect"];
            NSNumber *scoreNumber = match[@"score"];
            if (!pointValue || !rectValue) {
                [strongSelf restorePanelAfterExternalTap];
                strongSelf->_statusLabel.text = @"识别异常";
                return;
            }
            CGPoint point = pointValue.CGPointValue;
            CGRect rect = rectValue.CGRectValue;
            UIWindow *currentHostWindow = [strongSelf hostWindowForCallbackWithFallback:hostWindow
                                                                          runGeneration:0
                                                                                 status:nil];
            if (!currentHostWindow) {
                [strongSelf restorePanelAfterExternalTap];
                strongSelf->_statusLabel.text = @"无窗口";
                return;
            }
            [strongSelf preparePanelForExternalTapWithHostWindow:currentHostWindow];
            [strongSelf showRecognitionBoxForScreenRect:rect score:scoreNumber.doubleValue inWindow:currentHostWindow duration:1.6];
            [strongSelf performSelectedActionAtPoint:point inWindow:currentHostWindow];
            strongSelf->_statusLabel.text = [NSString stringWithFormat:@"识别 %.2f  %.0f,%.0f",
                                             scoreNumber.doubleValue,
                                             point.x,
                                             point.y];
        });
    });
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
    if (CFStringCompare(name, AnClickVolumeShortcutDownNotification, 0) == kCFCompareEqualTo) {
        direction = -1;
    } else if (CFStringCompare(name, AnClickVolumeShortcutUpNotification, 0) == kCFCompareEqualTo) {
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
                                         direction < 0 ? AnClickVolumeShortcutDownNotification : AnClickVolumeShortcutUpNotification,
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
