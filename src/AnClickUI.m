#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
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
    AnClickActionModeCount = 9,
};

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (NSDictionary *)findTemplateImageMatch:(UIImage *)templateImage threshold:(double)threshold;
+ (NSValue *)findTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
+ (BOOL)findAndTapTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
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

@interface AnClickUI : NSObject
+ (instancetype)shared;
- (void)show;
@end

@implementation AnClickUI {
    UIWindow *_panelWindow;
    UIView *_panelView;
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
    UIButton *_editorBackButton;
    UIButton *_imageActionButton;
    UIButton *_previewActionButton;
    UIButton *_clearConfigButton;
    UIButton *_swipeRecordButton;
    NSArray<UIButton *> *_modeButtons;
    UIScrollView *_taskListView;
    UILabel *_statusLabel;
    UITextField *_descriptionField;
    UITextField *_delayField;
    UITextField *_repeatField;
    UIView *_captureOverlay;
    UIView *_selectionView;
    UIView *_pointPickOverlay;
    UIWindow *_pointPickWindow;
    UIView *_pointCursorView;
    UIView *_pointPickToolbar;
    UILabel *_pointCoordinateLabel;
    UIImage *_captureSnapshot;
    UIImageView *_previewView;
    UIView *_tapMarkerView;
    UIView *_recognitionBoxView;
    UIView *_operationTraceView;
    UIView *_trajectoryView;
    CAShapeLayer *_trajectoryLayer;
    NSMutableArray<NSValue *> *_recordedSwipePoints;
    NSMutableArray<NSValue *> *_liveSwipePoints;
    NSArray<NSDictionary *> *_recordedMacroEvents;
    NSMutableArray<NSMutableDictionary *> *_taskItems;
    NSInteger _selectedTaskIndex;
    NSInteger _draggingTaskIndex;
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
    NSTimeInterval _actionDelay;
    NSInteger _actionRepeatCount;
    NSString *_currentTemplatePath;
    NSString *_actionDescription;
    AnClickActionMode _actionMode;
    AnClickActionMode _imageActionMode;
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
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_panelWindow) {
            [self attachPanelWindowToActiveSceneIfNeeded];
            self->_panelWindow.hidden = NO;
            [self refreshCollapsedButtonTitle];
            return;
        }
        [self buildPanel];
    });
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

- (void)buildPanel {
    CGFloat panelWidth = MIN(348.0, UIScreen.mainScreen.bounds.size.width - 16.0);
    CGFloat panelHeight = MIN(420.0, UIScreen.mainScreen.bounds.size.height - 72.0);
    _actionMode = AnClickActionModeNone;
    _selectedTaskIndex = -1;
    _draggingTaskIndex = -1;
    _imageUsesMatchPoint = YES;
    _imageActionMode = AnClickActionModeTap;
    _actionDelay = 0;
    _actionRepeatCount = 1;
    if (!_recordedSwipePoints) {
        _recordedSwipePoints = [NSMutableArray array];
    }
    if (!_taskItems) {
        _taskItems = [NSMutableArray array];
    }

    _panelWindow = [[UIWindow alloc] initWithFrame:CGRectMake(8, 118, panelWidth, panelHeight)];
    [self attachPanelWindowToActiveSceneIfNeeded];
    _panelWindow.windowLevel = UIWindowLevelAlert + 1000;
    _panelWindow.backgroundColor = UIColor.clearColor;
    _panelWindow.hidden = NO;

    UIViewController *controller = [[UIViewController alloc] init];
    _panelWindow.rootViewController = controller;

    _collapsedButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _collapsedButton.frame = CGRectMake(0, 0, 48, 48);
    _collapsedButton.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.075 alpha:0.92];
    _collapsedButton.layer.cornerRadius = 6;
    _collapsedButton.layer.borderWidth = 1;
    _collapsedButton.layer.borderColor = [UIColor colorWithRed:0.94 green:0.64 blue:0.23 alpha:0.82].CGColor;
    _collapsedButton.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    [_collapsedButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [_collapsedButton addTarget:self action:@selector(handleCollapsedTap) forControlEvents:UIControlEventTouchUpInside];
    [controller.view addSubview:_collapsedButton];

    UILongPressGestureRecognizer *collapsedLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleCollapsedLongPress:)];
    collapsedLongPress.minimumPressDuration = 0.45;
    [_collapsedButton addGestureRecognizer:collapsedLongPress];
    UIPanGestureRecognizer *collapsedPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [_collapsedButton addGestureRecognizer:collapsedPan];

    _panelView = [[UIView alloc] initWithFrame:_panelWindow.bounds];
    _panelView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.075 alpha:0.94];
    _panelView.layer.cornerRadius = 6;
    _panelView.layer.borderWidth = 1;
    _panelView.layer.borderColor = [UIColor colorWithRed:0.72 green:0.57 blue:0.32 alpha:0.55].CGColor;
    _panelView.layer.shadowColor = UIColor.blackColor.CGColor;
    _panelView.layer.shadowOpacity = 0.35;
    _panelView.layer.shadowRadius = 14.0;
    _panelView.layer.shadowOffset = CGSizeMake(0, 8);
    [controller.view addSubview:_panelView];

    UIPanGestureRecognizer *panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [_panelView addGestureRecognizer:panelPan];

    CGFloat gap = 7.0;
    CGFloat modeWidth = floor((panelWidth - gap * 4.0) / 3.0);
    NSArray<NSString *> *modeTitles = @[@"点击", @"双击", @"长按", @"滑动", @"识图"];
    NSArray<NSNumber *> *modeTags = @[
        @(AnClickActionModeTap),
        @(AnClickActionModeDoubleTap),
        @(AnClickActionModeLongPress),
        @(AnClickActionModeSwipe),
        @(AnClickActionModeImage),
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

    _playButton = [self panelButtonWithTitle:@"清除" action:@selector(handleSecondaryConfigButton)];
    _playButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 120, buttonWidth, 32);
    [_panelView addSubview:_playButton];

    _pickPointButton = [self panelButtonWithTitle:@"取点" action:@selector(beginPointPicking)];
    _pickPointButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 120, buttonWidth, 32);
    [_panelView addSubview:_pickPointButton];

    _runManualButton = [self panelButtonWithTitle:@"执行" action:@selector(runManualAction)];
    _runManualButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 120, buttonWidth, 32);
    [_panelView addSubview:_runManualButton];

    _recordSwipeButton = [self panelButtonWithTitle:@"延-" action:@selector(decreaseActionDelay)];
    _recordSwipeButton.frame = CGRectMake(gap, 158, buttonWidth, 32);
    [_panelView addSubview:_recordSwipeButton];

    _previewSwipeButton = [self panelButtonWithTitle:@"延+" action:@selector(increaseActionDelay)];
    _previewSwipeButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 158, buttonWidth, 32);
    [_panelView addSubview:_previewSwipeButton];

    _clearActionButton = [self panelButtonWithTitle:@"次-" action:@selector(decreaseActionRepeatCount)];
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

    _collapseButton = [self panelButtonWithTitle:@"收起" action:@selector(collapsePanel)];
    _collapseButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 8, buttonWidth, 38);
    [_panelView addSubview:_collapseButton];

    _saveTaskButton = [self panelButtonWithTitle:@"保存" action:@selector(saveSelectedTaskFromCurrentConfig)];
    _saveTaskButton.frame = CGRectMake(gap, 120, buttonWidth, 34);
    [_panelView addSubview:_saveTaskButton];

    _imageActionButton = [self panelButtonWithTitle:@"动作点击" action:@selector(cycleImageActionMode)];
    _imageActionButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 196, buttonWidth, 32);
    [_panelView addSubview:_imageActionButton];

    _previewActionButton = [self panelButtonWithTitle:@"预览" action:@selector(previewCurrentAction)];
    _previewActionButton.frame = CGRectMake(gap, 234, buttonWidth, 32);
    [_panelView addSubview:_previewActionButton];

    _clearConfigButton = [self panelButtonWithTitle:@"清除" action:@selector(clearCurrentActionConfig)];
    _clearConfigButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 234, buttonWidth, 32);
    [_panelView addSubview:_clearConfigButton];

    _swipeRecordButton = [self panelButtonWithTitle:@"录制" action:@selector(beginSwipeRecording)];
    _swipeRecordButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 234, buttonWidth, 32);
    [_panelView addSubview:_swipeRecordButton];

    _editorBackButton = [self panelButtonWithTitle:@"返回" action:@selector(showTaskHome)];
    _editorBackButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 120, buttonWidth, 34);
    [_panelView addSubview:_editorBackButton];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 52, panelWidth - 16, 24)];
    _statusLabel.text = @"待机";
    _statusLabel.textColor = UIColor.whiteColor;
    _statusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _statusLabel.adjustsFontSizeToFitWidth = YES;
    _statusLabel.minimumScaleFactor = 0.6;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [_panelView addSubview:_statusLabel];

    _descriptionField = [[UITextField alloc] initWithFrame:CGRectMake(8, 142, panelWidth - 16, 34)];
    _descriptionField.placeholder = @"备注/动作说明";
    _descriptionField.textColor = UIColor.whiteColor;
    _descriptionField.tintColor = [UIColor colorWithRed:0.94 green:0.64 blue:0.23 alpha:1.0];
    _descriptionField.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _descriptionField.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.12 alpha:1.0];
    _descriptionField.layer.cornerRadius = 4;
    _descriptionField.layer.borderWidth = 1;
    _descriptionField.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    _descriptionField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _descriptionField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    _descriptionField.leftViewMode = UITextFieldViewModeAlways;
    _descriptionField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"备注/动作说明"
                                                                              attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.45]}];
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

    _taskListView = [[UIScrollView alloc] initWithFrame:CGRectMake(8, 84, panelWidth - 16, panelHeight - 92)];
    _taskListView.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.10 alpha:1.0];
    _taskListView.layer.cornerRadius = 4;
    _taskListView.layer.borderWidth = 1;
    _taskListView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    [_panelView addSubview:_taskListView];

    _previewView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 296, panelWidth - 16, MAX(70.0, panelHeight - 304))];
    _previewView.contentMode = UIViewContentModeScaleAspectFit;
    _previewView.clipsToBounds = YES;
    _previewView.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.12 alpha:1.0];
    _previewView.layer.cornerRadius = 4;
    _previewView.layer.borderWidth = 1;
    _previewView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    _previewView.hidden = YES;
    [_panelView addSubview:_previewView];
    [self refreshTemplatePreview];
    [self refreshTaskList];
    [self setTaskEditorVisible:NO];

    _panelWindow.hidden = NO;
    [self collapsePanel];
    NSLog(@"[AnClick] Panel shown");
}

- (UIButton *)panelButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.72;
    button.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.18 alpha:1.0];
    button.layer.cornerRadius = 4;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UITextField *)configTextFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
    field.placeholder = placeholder;
    field.textColor = UIColor.whiteColor;
    field.tintColor = [UIColor colorWithRed:0.94 green:0.64 blue:0.23 alpha:1.0];
    field.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    field.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.12 alpha:1.0];
    field.layer.cornerRadius = 4;
    field.layer.borderWidth = 1;
    field.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder
                                                                   attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.45]}];
    return field;
}

- (CGSize)expandedPanelSize {
    CGFloat width = MIN(348.0, UIScreen.mainScreen.bounds.size.width - 16.0);
    CGFloat height = MIN(420.0, UIScreen.mainScreen.bounds.size.height - 72.0);
    return CGSizeMake(width, MAX(340.0, height));
}

- (CGRect)clampedPanelFrame:(CGRect)frame {
    CGRect bounds = UIScreen.mainScreen.bounds;
    frame.origin.x = MIN(MAX(frame.origin.x, 4.0), bounds.size.width - frame.size.width - 4.0);
    frame.origin.y = MIN(MAX(frame.origin.y, 24.0), bounds.size.height - frame.size.height - 4.0);
    return frame;
}

- (void)refreshCollapsedButtonTitle {
    [_collapsedButton setTitle:[NSString stringWithFormat:@"＋%lu", (unsigned long)_taskItems.count] forState:UIControlStateNormal];
}

- (void)setTaskEditorVisible:(BOOL)visible {
    _taskEditorVisible = visible;

    for (UIButton *button in _modeButtons) {
        button.hidden = !visible;
    }
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
    _imageActionButton.hidden = YES;
    _previewActionButton.hidden = YES;
    _clearConfigButton.hidden = YES;
    _swipeRecordButton.hidden = YES;
    _descriptionField.hidden = !visible;
    _delayField.hidden = YES;
    _repeatField.hidden = YES;
    _previewView.hidden = YES;

    _addTaskButton.hidden = visible;
    _deleteTaskButton.hidden = visible;
    _runTasksButton.hidden = visible;
    _collapseButton.hidden = visible;
    _taskListView.hidden = visible;

    CGRect statusFrame = _statusLabel.frame;
    statusFrame.origin.y = visible ? 116.0 : 52.0;
    statusFrame.size.height = visible ? 22.0 : 24.0;
    _statusLabel.frame = statusFrame;
    _statusLabel.font = [UIFont systemFontOfSize:(visible ? 14.0 : 15.0) weight:UIFontWeightMedium];
    [self refreshEditorConfigControls];
}

- (void)showTaskHome {
    [self setTaskEditorVisible:NO];
    [self refreshTaskList];
    _statusLabel.text = _taskItems.count == 0 ? @"暂无任务" : @"任务列表";
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
    _imageActionMode = AnClickActionModeTap;
    _actionDescription = nil;
    _actionDelay = 0;
    _actionRepeatCount = 1;
}

- (void)collapsePanel {
    if (!_panelWindow || !_collapsedButton || !_panelView) {
        return;
    }

    _panelExpanded = NO;
    _taskEditorVisible = NO;
    CGRect frame = _panelWindow.frame;
    frame.size = CGSizeMake(48.0, 48.0);
    _panelWindow.frame = [self clampedPanelFrame:frame];
    _panelWindow.rootViewController.view.frame = _panelWindow.bounds;
    _collapsedButton.frame = _panelWindow.bounds;
    _collapsedButton.hidden = NO;
    _panelView.hidden = YES;
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
    [self refreshCollapsedButtonTitle];
}

- (void)handleCollapsedLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _taskEditorVisible = NO;
        [self expandPanel];
        [self showTaskHome];
    }
}

- (void)selectActionMode:(UIButton *)sender {
    [self syncActionDescriptionFromField];
    [self syncActionTimingFromFields];
    _actionMode = (AnClickActionMode)sender.tag;
    [self refreshModeButtons];
    [self refreshEditorConfigControls];
    [self updateStatusForCurrentConfig];
}

- (void)refreshModeButtons {
    for (UIButton *button in _modeButtons) {
        BOOL selected = button.tag == _actionMode;
        button.backgroundColor = selected
            ? [UIColor colorWithRed:0.94 green:0.64 blue:0.23 alpha:1.0]
            : [UIColor colorWithRed:0.20 green:0.20 blue:0.18 alpha:1.0];
        button.layer.borderColor = selected
            ? [UIColor colorWithRed:1.0 green:0.82 blue:0.43 alpha:1.0].CGColor
            : [UIColor colorWithWhite:1 alpha:0.10].CGColor;
        [button setTitleColor:selected ? UIColor.blackColor : UIColor.whiteColor forState:UIControlStateNormal];
    }
}

- (NSString *)currentActionName {
    return [self actionNameForMode:_actionMode];
}

- (NSString *)actionNameForMode:(AnClickActionMode)mode {
    NSArray<NSString *> *names = @[@"点击", @"双击", @"长按", @"滑动", @"二指", @"缩小", @"放大", @"旋转", @"识图"];
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
        mode == AnClickActionModeImage;
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

- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:_panelWindow];
    CGPoint center = _panelWindow.center;
    center.x += translation.x;
    center.y += translation.y;
    _panelWindow.center = center;
    [recognizer setTranslation:CGPointZero inView:_panelWindow];
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

- (void)refreshTimingFieldsIfNeeded {
    if (!_delayField.isFirstResponder) {
        _delayField.text = [self delayFieldText];
    }
    if (!_repeatField.isFirstResponder) {
        _repeatField.text = [self repeatFieldText];
    }
}

- (void)actionTimingChanged:(__unused UITextField *)textField {
    [self syncActionTimingFromFields];
    [self updateStatusForCurrentConfig];
}

- (void)actionTimingEditingDidEnd:(__unused UITextField *)textField {
    [self syncActionTimingFromFields];
    [self refreshTimingFieldsIfNeeded];
    [self updateStatusForCurrentConfig];
}

- (void)hideAllConfigButtons {
    _captureButton.hidden = YES;
    _playButton.hidden = YES;
    _pickPointButton.hidden = YES;
    _runManualButton.hidden = YES;
    _recordSwipeButton.hidden = YES;
    _previewSwipeButton.hidden = YES;
    _clearActionButton.hidden = YES;
    _testButton.hidden = YES;
    _imageActionButton.hidden = YES;
    _previewActionButton.hidden = YES;
    _clearConfigButton.hidden = YES;
    _swipeRecordButton.hidden = YES;
    _delayField.hidden = YES;
    _repeatField.hidden = YES;
    _saveTaskButton.hidden = YES;
    _editorBackButton.hidden = YES;
}

- (void)layoutConfigButtons:(NSArray<UIButton *> *)buttons y:(CGFloat)y {
    if (buttons.count == 0 || !_panelView) {
        return;
    }

    CGFloat gap = 7.0;
    CGFloat width = _panelView.bounds.size.width;
    CGFloat buttonWidth = floor((width - gap * (buttons.count + 1)) / buttons.count);
    CGFloat buttonHeight = 34.0;
    for (NSUInteger i = 0; i < buttons.count; i++) {
        UIButton *button = buttons[i];
        button.hidden = NO;
        button.frame = CGRectMake(gap + (buttonWidth + gap) * i, y, buttonWidth, buttonHeight);
    }
}

- (void)layoutTimingFieldsAtY:(CGFloat)y {
    CGFloat gap = 7.0;
    CGFloat width = _panelView.bounds.size.width;
    CGFloat fieldWidth = floor((width - gap * 3.0) / 2.0);
    _delayField.hidden = NO;
    _repeatField.hidden = NO;
    _delayField.frame = CGRectMake(gap, y, fieldWidth, 34.0);
    _repeatField.frame = CGRectMake(gap * 2.0 + fieldWidth, y, fieldWidth, 34.0);
}

- (void)refreshEditorConfigControls {
    if (!_taskEditorVisible) {
        return;
    }

    [self hideAllConfigButtons];
    _descriptionField.hidden = NO;
    if (!_descriptionField.isFirstResponder) {
        _descriptionField.text = _actionDescription ?: @"";
    }
    [self refreshTimingFieldsIfNeeded];
    [_captureButton setTitle:@"截图" forState:UIControlStateNormal];
    [_playButton setTitle:(_actionMode == AnClickActionModeImage ? (_imageUsesMatchPoint ? @"点识别" : @"点指定") : @"清除") forState:UIControlStateNormal];
    [_imageActionButton setTitle:[NSString stringWithFormat:@"后%@", [self actionNameForMode:_imageActionMode]] forState:UIControlStateNormal];
    NSString *pickTitle = @"取点";
    if (_actionMode == AnClickActionModeSwipe) {
        pickTitle = (_hasManualSwipeAnchor && !_hasManualSwipeEndPoint) ? @"取终点" : @"取起点";
    } else if (_actionMode == AnClickActionModeImage) {
        pickTitle = @"取点击点";
    }
    [_pickPointButton setTitle:pickTitle forState:UIControlStateNormal];
    [_runManualButton setTitle:@"测试" forState:UIControlStateNormal];
    [_previewActionButton setTitle:@"预览" forState:UIControlStateNormal];
    [_clearConfigButton setTitle:@"清除" forState:UIControlStateNormal];
    [_swipeRecordButton setTitle:@"录制" forState:UIControlStateNormal];

    if (_actionMode == AnClickActionModeNone) {
        [self layoutConfigButtons:@[_editorBackButton] y:180.0];
    } else if (_actionMode == AnClickActionModeImage) {
        [self layoutConfigButtons:@[_captureButton, _playButton, _pickPointButton, _imageActionButton] y:180.0];
        [self layoutTimingFieldsAtY:218.0];
        [self layoutConfigButtons:@[_previewActionButton, _runManualButton, _saveTaskButton, _editorBackButton] y:256.0];
    } else if (_actionMode == AnClickActionModeSwipe) {
        [self layoutConfigButtons:@[_pickPointButton, _swipeRecordButton, _previewActionButton, _runManualButton] y:180.0];
        [self layoutTimingFieldsAtY:218.0];
        [self layoutConfigButtons:@[_clearConfigButton, _saveTaskButton, _editorBackButton] y:256.0];
    } else {
        [self layoutConfigButtons:@[_pickPointButton, _previewActionButton, _runManualButton, _playButton] y:180.0];
        [self layoutTimingFieldsAtY:218.0];
        [self layoutConfigButtons:@[_saveTaskButton, _editorBackButton] y:256.0];
    }
    [self refreshTemplatePreview];
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
                             [self actionNameForMode:_imageActionMode]];
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

    NSString *name = [self currentActionName];
    if ([self hasManualPointForMode:_actionMode]) {
        _statusLabel.text = [NSString stringWithFormat:@"%@ 已取点", name];
    } else {
        _statusLabel.text = [NSString stringWithFormat:@"%@ 先取点", name];
    }
}

- (void)handleSecondaryConfigButton {
    if (_actionMode == AnClickActionModeImage) {
        _imageUsesMatchPoint = !_imageUsesMatchPoint;
        [self refreshEditorConfigControls];
        [self updateStatusForCurrentConfig];
        return;
    }
    [self clearCurrentActionConfig];
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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (UIApplication.sharedApplication.keyWindow &&
        UIApplication.sharedApplication.keyWindow.windowLevel < UIWindowLevelAlert &&
        UIApplication.sharedApplication.keyWindow != _panelWindow) {
        return UIApplication.sharedApplication.keyWindow;
    }
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window != _panelWindow && window.windowLevel < UIWindowLevelAlert && !window.hidden && window.alpha > 0.01) {
            return window;
        }
    }
    return nil;
#pragma clang diagnostic pop
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
    if (hostWindow && !hostWindow.isKeyWindow) {
        [hostWindow makeKeyWindow];
    }
    if (_panelWindow) {
        _panelWindow.userInteractionEnabled = NO;
        _panelWindow.hidden = YES;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.16 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_captureSnapshot = [AnClickCore captureCurrentWindowImage];
        if (!self->_captureSnapshot.CGImage) {
            [self restorePanelAfterExternalTap];
            self->_statusLabel.text = @"截图失败";
            return;
        }
        [self showCaptureOverlayInWindow:hostWindow];
    });
}

- (void)showCaptureOverlayInWindow:(UIWindow *)hostWindow {
    [_captureOverlay removeFromSuperview];

    _captureOverlay = [[UIView alloc] initWithFrame:hostWindow.bounds];
    _captureOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.36];
    _captureOverlay.userInteractionEnabled = YES;

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(12, 54, hostWindow.bounds.size.width - 24, 42)];
    hint.text = @"按住拖动框选模板区域";
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
    [_captureOverlay addSubview:_selectionView];

    UIPanGestureRecognizer *movePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSelectionPan:)];
    [_selectionView addGestureRecognizer:movePan];

    UIPanGestureRecognizer *drawPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCaptureDrawPan:)];
    drawPan.cancelsTouchesInView = NO;
    [_captureOverlay addGestureRecognizer:drawPan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleCaptureOverlayTap:)];
    tap.cancelsTouchesInView = NO;
    [_captureOverlay addGestureRecognizer:tap];

    UIButton *saveButton = [self overlayButtonWithTitle:@"保存" action:@selector(saveSelectedTemplate)];
    saveButton.tag = 3001;
    saveButton.frame = CGRectMake(16, hostWindow.bounds.size.height - 70, 86, 44);
    saveButton.hidden = YES;
    saveButton.userInteractionEnabled = NO;
    [_captureOverlay addSubview:saveButton];

    UIButton *cancelButton = [self overlayButtonWithTitle:@"取消" action:@selector(cancelTemplateCapture)];
    cancelButton.tag = 3002;
    cancelButton.frame = CGRectMake(hostWindow.bounds.size.width - 102, hostWindow.bounds.size.height - 70, 86, 44);
    cancelButton.hidden = YES;
    cancelButton.userInteractionEnabled = NO;
    [_captureOverlay addSubview:cancelButton];

    [hostWindow addSubview:_captureOverlay];
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

- (UIView *)cornerHandleWithTag:(NSInteger)tag {
    UIView *handle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    handle.tag = tag;
    handle.backgroundColor = UIColor.systemYellowColor;
    handle.layer.cornerRadius = 15;
    handle.layer.borderColor = UIColor.blackColor.CGColor;
    handle.layer.borderWidth = 1;
    handle.userInteractionEnabled = YES;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCornerPan:)];
    [handle addGestureRecognizer:pan];
    return handle;
}

- (void)addCornerHandles {
    for (NSInteger tag = 1; tag <= 4; tag++) {
        [_selectionView addSubview:[self cornerHandleWithTag:tag]];
    }
    [self layoutCornerHandles];
}

- (void)layoutCornerHandles {
    for (UIView *handle in _selectionView.subviews) {
        if (handle.tag < 1 || handle.tag > 4) {
            continue;
        }
        if (handle.tag == 1) {
            handle.center = CGPointMake(0, 0);
        } else if (handle.tag == 2) {
            handle.center = CGPointMake(_selectionView.bounds.size.width, 0);
        } else if (handle.tag == 3) {
            handle.center = CGPointMake(0, _selectionView.bounds.size.height);
        } else if (handle.tag == 4) {
            handle.center = CGPointMake(_selectionView.bounds.size.width, _selectionView.bounds.size.height);
        }
    }
}

- (CGRect)clampedSelectionFrame:(CGRect)frame {
    CGRect bounds = _captureOverlay.bounds;
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
    if (!_captureOverlay || !_selectionView || _selectionView.hidden) {
        [self setCaptureActionButtonsHidden:YES];
        return;
    }

    UIView *saveButton = [_captureOverlay viewWithTag:3001];
    UIView *cancelButton = [_captureOverlay viewWithTag:3002];
    if (!saveButton || !cancelButton) {
        return;
    }

    CGFloat margin = 14.0;
    CGFloat gap = 12.0;
    CGFloat buttonWidth = 86.0;
    CGFloat buttonHeight = 44.0;
    CGRect selectionFrame = _selectionView.frame;
    CGFloat totalWidth = buttonWidth * 2.0 + gap;
    CGFloat x = MIN(MAX(CGRectGetMidX(selectionFrame) - totalWidth * 0.5,
                        margin),
                    _captureOverlay.bounds.size.width - totalWidth - margin);

    CGFloat belowY = CGRectGetMaxY(selectionFrame) + margin;
    CGFloat aboveY = CGRectGetMinY(selectionFrame) - buttonHeight - margin;
    CGFloat y = 0.0;
    if (belowY + buttonHeight <= _captureOverlay.bounds.size.height - margin) {
        y = belowY;
    } else if (aboveY >= margin) {
        y = aboveY;
    } else {
        y = _captureOverlay.bounds.size.height - buttonHeight - margin;
    }

    saveButton.frame = CGRectMake(x, y, buttonWidth, buttonHeight);
    cancelButton.frame = CGRectMake(x + buttonWidth + gap, y, buttonWidth, buttonHeight);
    [self setCaptureActionButtonsHidden:NO];
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

    CGPoint point = [recognizer locationInView:_captureOverlay];
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
        [self layoutCornerHandles];
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
        [self layoutCornerHandles];
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
    CGPoint translation = [recognizer translationInView:_captureOverlay];
    CGRect frame = _selectionView.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    _selectionView.frame = [self clampedSelectionFrame:frame];
    [recognizer setTranslation:CGPointZero inView:_captureOverlay];
    if (recognizer.state == UIGestureRecognizerStateEnded ||
        recognizer.state == UIGestureRecognizerStateCancelled ||
        recognizer.state == UIGestureRecognizerStateFailed) {
        [self layoutCaptureActionButtonsAvoidingSelection];
    }
}

- (void)handleCornerPan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:_captureOverlay];
    CGRect frame = _selectionView.frame;

    if (recognizer.view.tag == 1) {
        frame.origin.x += translation.x;
        frame.origin.y += translation.y;
        frame.size.width -= translation.x;
        frame.size.height -= translation.y;
    } else if (recognizer.view.tag == 2) {
        frame.origin.y += translation.y;
        frame.size.width += translation.x;
        frame.size.height -= translation.y;
    } else if (recognizer.view.tag == 3) {
        frame.origin.x += translation.x;
        frame.size.width -= translation.x;
        frame.size.height += translation.y;
    } else {
        frame.size.width += translation.x;
        frame.size.height += translation.y;
    }

    _selectionView.frame = [self clampedSelectionFrame:frame];
    [self layoutCornerHandles];
    [recognizer setTranslation:CGPointZero inView:_captureOverlay];
}

- (void)handleSelectionPinch:(UIPinchGestureRecognizer *)recognizer {
    CGRect frame = _selectionView.frame;
    CGPoint center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    frame.size.width *= recognizer.scale;
    frame.size.height *= recognizer.scale;
    frame.origin.x = center.x - frame.size.width * 0.5;
    frame.origin.y = center.y - frame.size.height * 0.5;
    _selectionView.frame = [self clampedSelectionFrame:frame];
    [self layoutCornerHandles];
    recognizer.scale = 1.0;
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
    _statusLabel.text = saved ? [NSString stringWithFormat:@"模板已保存 %@", [self commonConfigSummary]] : @"保存失败";
}

- (void)cancelTemplateCapture {
    [self finishTemplateCapture];
    _statusLabel.text = @"取消";
}

- (void)finishTemplateCapture {
    [_captureOverlay removeFromSuperview];
    _captureOverlay = nil;
    _selectionView = nil;
    _captureSnapshot = nil;
    _captureDrawingSelection = NO;
    [self restorePanelAfterExternalTap];
}

- (void)refreshTemplatePreview {
    NSString *path = [self activeTemplatePath];
    UIImage *image = (path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) ? [UIImage imageWithContentsOfFile:path] : nil;
    _previewView.image = image;
    _previewView.hidden = !_taskEditorVisible || _actionMode != AnClickActionModeImage || image == nil;
}

- (void)preparePanelForExternalTapWithHostWindow:(UIWindow *)hostWindow {
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

- (void)restorePanelAfterExternalTap {
    if (!_panelWindow) {
        return;
    }

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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(duration, 0.4) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [marker removeFromSuperview];
        if (self->_tapMarkerView == marker) {
            self->_tapMarkerView = nil;
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(duration, 0.6) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [overlay removeFromSuperview];
        if (self->_recognitionBoxView == overlay) {
            self->_recognitionBoxView = nil;
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(duration, 0.6) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [overlay removeFromSuperview];
        if (self->_operationTraceView == overlay) {
            self->_operationTraceView = nil;
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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(duration, 0.4) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [view removeFromSuperview];
        if (self->_trajectoryView == view) {
            self->_trajectoryView = nil;
            self->_trajectoryLayer = nil;
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self->_longPressHolding = NO;
            if (self->_actionMode == AnClickActionModeLongPress) {
                self->_statusLabel.text = @"长按完成";
                [self refreshModeButtons];
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

- (NSArray<NSValue *> *)recordedMacroTrajectoryPoints {
    if (_recordedMacroEvents.count == 0) {
        return @[];
    }

    NSMutableArray<NSValue *> *points = [NSMutableArray array];
    for (NSDictionary *event in _recordedMacroEvents) {
        NSNumber *typeNumber = event[@"type"];
        NSNumber *xNumber = event[@"x"];
        NSNumber *yNumber = event[@"y"];
        if (!typeNumber || !xNumber || !yNumber) {
            continue;
        }
        NSInteger type = typeNumber.integerValue;
        if (type == 0 || type == 1 || type == 2) {
            [points addObject:[NSValue valueWithCGPoint:CGPointMake(xNumber.doubleValue, yNumber.doubleValue)]];
        }
    }
    return points;
}

- (NSMutableDictionary *)taskDictionaryFromCurrentConfigRequireComplete:(BOOL)requireComplete {
    [self syncActionDescriptionFromField];
    [self syncActionTimingFromFields];
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
        if (!_imageUsesMatchPoint) {
            if ([self hasManualPointForMode:AnClickActionModeImage]) {
                task[@"point"] = [NSValue valueWithCGPoint:_manualActionPoints[(NSUInteger)AnClickActionModeImage]];
            } else if (requireComplete) {
                _statusLabel.text = @"先取点击点";
                return nil;
            }
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
    NSString *name = [self actionNameForMode:mode];
    NSString *desc = [self trimmedActionDescription:task[@"desc"]];
    NSString *suffix = [self commonSuffixForTask:task];
    if (mode == AnClickActionModeNone) {
        return [NSString stringWithFormat:@"%lu  %@未选择动作%@",
                (unsigned long)index + 1,
                desc.length > 0 ? [NSString stringWithFormat:@"%@ ", desc] : @"",
                suffix];
    }
    if (mode == AnClickActionModeImage) {
        NSString *templatePath = task[@"templatePath"];
        BOOL hasTemplate = templatePath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:templatePath];
        BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
        AnClickActionMode imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        NSString *imageActionName = [self actionNameForMode:imageActionMode];
        NSString *prefix = desc.length > 0 ? [NSString stringWithFormat:@"%@ ", desc] : @"";
        if (useMatchPoint) {
            return [NSString stringWithFormat:@"%lu  %@%@ %@ 识别点 后%@%@",
                    (unsigned long)index + 1,
                    prefix,
                    name,
                    hasTemplate ? @"有模板" : @"未截图",
                    imageActionName,
                    suffix];
        }
        NSValue *pointValue = task[@"point"];
        if (pointValue) {
            CGPoint point = pointValue.CGPointValue;
            return [NSString stringWithFormat:@"%lu  %@%@ %@ %.0f,%.0f 后%@%@",
                    (unsigned long)index + 1,
                    prefix,
                    name,
                    hasTemplate ? @"有模板" : @"未截图",
                    point.x,
                    point.y,
                    imageActionName,
                    suffix];
        }
        return [NSString stringWithFormat:@"%lu  %@%@ %@ 未取点 后%@%@", (unsigned long)index + 1, prefix, name, hasTemplate ? @"有模板" : @"未截图", imageActionName, suffix];
    }
    if (mode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = task[@"path"];
        if (path.count >= 2) {
            CGPoint start = path.firstObject.CGPointValue;
            CGPoint end = path.lastObject.CGPointValue;
            return [NSString stringWithFormat:@"%lu  %@%@ %.0f,%.0f→%.0f,%.0f%@",
                    (unsigned long)index + 1,
                    desc.length > 0 ? [NSString stringWithFormat:@"%@ ", desc] : @"",
                    name,
                    start.x,
                    start.y,
                    end.x,
                    end.y,
                    suffix];
        }
        return [NSString stringWithFormat:@"%lu  %@%@ 未设置%@", (unsigned long)index + 1, desc.length > 0 ? [NSString stringWithFormat:@"%@ ", desc] : @"", name, suffix];
    }

    NSValue *pointValue = task[@"point"];
    if (pointValue) {
        CGPoint point = pointValue.CGPointValue;
        return [NSString stringWithFormat:@"%lu  %@%@ %.0f,%.0f%@",
                (unsigned long)index + 1,
                desc.length > 0 ? [NSString stringWithFormat:@"%@ ", desc] : @"",
                name,
                point.x,
                point.y,
                suffix];
    }
    return [NSString stringWithFormat:@"%lu  %@%@ 未取点%@", (unsigned long)index + 1, desc.length > 0 ? [NSString stringWithFormat:@"%@ ", desc] : @"", name, suffix];
}

- (void)refreshTaskList {
    [self refreshCollapsedButtonTitle];
    [_addTaskButton setTitle:[NSString stringWithFormat:@"添加%lu", (unsigned long)_taskItems.count] forState:UIControlStateNormal];
    BOOL hasTasks = _taskItems.count > 0;
    _deleteTaskButton.enabled = hasTasks;
    _deleteTaskButton.alpha = hasTasks ? 1.0 : 0.45;
    _runTasksButton.enabled = hasTasks;
    _runTasksButton.alpha = hasTasks ? 1.0 : 0.45;
    if (!_taskListView) {
        return;
    }

    for (UIView *view in _taskListView.subviews) {
        [view removeFromSuperview];
    }

    CGFloat rowHeight = 42.0;
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
        UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem];
        row.tag = (NSInteger)i;
        row.frame = CGRectMake(6.0, 6.0 + rowHeight * i, width - 12.0, 36.0);
        [row setTitle:[self titleForTask:_taskItems[i] index:i] forState:UIControlStateNormal];
        [row setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        row.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        row.titleLabel.adjustsFontSizeToFitWidth = YES;
        row.titleLabel.minimumScaleFactor = 0.62;
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
        row.backgroundColor = ((NSInteger)i == _selectedTaskIndex)
            ? [UIColor colorWithRed:0.94 green:0.64 blue:0.23 alpha:0.88]
            : [UIColor colorWithWhite:1 alpha:0.08];
        row.layer.cornerRadius = 4;
        row.layer.borderWidth = 1;
        row.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
        [row addTarget:self action:@selector(selectTaskButton:) forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTaskPan:)];
        pan.cancelsTouchesInView = YES;
        [row addGestureRecognizer:pan];
        [_taskListView addSubview:row];
    }
    _taskListView.contentSize = CGSizeMake(width, MAX(_taskListView.bounds.size.height + 1.0, 12.0 + rowHeight * _taskItems.count));
}

- (void)addTaskFromCurrentConfig {
    NSMutableDictionary *task = [NSMutableDictionary dictionary];
    [_taskItems addObject:task];
    _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    [self showTaskHome];
    _statusLabel.text = [NSString stringWithFormat:@"已加任务%lu  点击任务设置", (unsigned long)_taskItems.count];
}

- (void)deleteLastTask {
    if (_taskItems.count == 0) {
        _statusLabel.text = @"没有任务";
        return;
    }

    [_taskItems removeLastObject];
    _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    [self showTaskHome];
    _statusLabel.text = [NSString stringWithFormat:@"已删剩%lu", (unsigned long)_taskItems.count];
}

- (void)saveSelectedTaskFromCurrentConfig {
    NSMutableDictionary *task = [self taskDictionaryFromCurrentConfigRequireComplete:YES];
    if (!task) {
        return;
    }
    if (_selectedTaskIndex < 0 || _selectedTaskIndex >= (NSInteger)_taskItems.count) {
        [_taskItems addObject:task];
        _selectedTaskIndex = (NSInteger)_taskItems.count - 1;
    } else {
        _taskItems[(NSUInteger)_selectedTaskIndex] = task;
    }
    [self refreshTaskList];
    [self showTaskHome];
    _statusLabel.text = [NSString stringWithFormat:@"已保存任务%ld", (long)_selectedTaskIndex + 1];
}

- (void)selectTaskButton:(UIButton *)sender {
    [self selectTaskAtIndex:sender.tag];
}

- (void)selectTaskAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        return;
    }

    _selectedTaskIndex = index;
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
}

- (void)handleTaskPan:(UIPanGestureRecognizer *)recognizer {
    UIView *row = recognizer.view;
    if (!row) {
        return;
    }

    NSInteger index = row.tag;
    if (index < 0 || index >= (NSInteger)_taskItems.count) {
        return;
    }

    CGPoint translation = [recognizer translationInView:_taskListView];
    CGFloat rowHeight = 42.0;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _draggingTaskIndex = index;
        [_taskListView bringSubviewToFront:row];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        row.transform = CGAffineTransformMakeTranslation(0, translation.y);
    } else if (recognizer.state == UIGestureRecognizerStateEnded ||
               recognizer.state == UIGestureRecognizerStateCancelled ||
               recognizer.state == UIGestureRecognizerStateFailed) {
        NSInteger targetIndex = index + (NSInteger)llround(translation.y / rowHeight);
        targetIndex = MIN(MAX(targetIndex, 0), (NSInteger)_taskItems.count - 1);
        row.transform = CGAffineTransformIdentity;
        if (targetIndex != index) {
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
        }
        _draggingTaskIndex = -1;
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
    return 0.30;
}

- (NSTimeInterval)delayForTask:(NSDictionary *)task {
    return MAX(0.0, [task[@"delay"] doubleValue]);
}

- (NSInteger)repeatCountForTask:(NSDictionary *)task {
    return MAX(1, [task[@"repeat"] integerValue]);
}

- (void)performPointActionMode:(AnClickActionMode)mode atPoint:(CGPoint)point inWindow:(UIWindow *)hostWindow {
    NSTimeInterval duration = [self durationForTaskMode:mode];
    [self showOperationTraceForMode:mode atPoint:point inWindow:hostWindow duration:duration];
    if (mode == AnClickActionModeDoubleTap) {
        [AnClickFakeTouch doubleTapAtPoint:point];
    } else if (mode == AnClickActionModeLongPress) {
        _longPressHolding = YES;
        [AnClickFakeTouch longPressAtPoint:point duration:5.0];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self->_longPressHolding = NO;
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

- (void)performImageTask:(NSDictionary *)task inWindow:(UIWindow *)hostWindow {
    NSString *templatePath = task[@"templatePath"];
    UIImage *templateImage = (templatePath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:templatePath]) ? [UIImage imageWithContentsOfFile:templatePath] : nil;
    if (!templateImage) {
        _statusLabel.text = @"识图无模板";
        return;
    }

    BOOL useMatchPoint = task[@"useMatchPoint"] ? [task[@"useMatchPoint"] boolValue] : YES;
    AnClickActionMode imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
    NSValue *customPointValue = task[@"point"];
    _templateSearchInProgress = YES;
    dispatch_async([self templateSearchQueue], ^{
        NSDictionary *match = [AnClickCore findTemplateImageMatch:templateImage threshold:0.86];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_templateSearchInProgress = NO;
            if (!match) {
                self->_statusLabel.text = @"识图未找到";
                return;
            }
            NSValue *matchPointValue = match[@"point"];
            NSValue *rectValue = match[@"rect"];
            NSNumber *scoreNumber = match[@"score"];
            if (!matchPointValue || !rectValue) {
                self->_statusLabel.text = @"识图异常";
                return;
            }
            UIWindow *currentHostWindow = [self hostWindow] ?: hostWindow;
            CGRect rect = rectValue.CGRectValue;
            [self showRecognitionBoxForScreenRect:rect score:scoreNumber.doubleValue inWindow:currentHostWindow duration:1.2];
            CGPoint actionPoint = useMatchPoint ? matchPointValue.CGPointValue : customPointValue.CGPointValue;
            [self performPointActionMode:imageActionMode atPoint:actionPoint inWindow:currentHostWindow];
            self->_statusLabel.text = [NSString stringWithFormat:@"识图 %.2f %@ %.0f,%.0f",
                                      scoreNumber.doubleValue,
                                      [self actionNameForMode:imageActionMode],
                                      actionPoint.x,
                                      actionPoint.y];
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
        if (!useMatchPoint && !task[@"point"]) {
            _statusLabel.text = @"任务识图未取点";
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
    if (![self taskIsComplete:task]) {
        return 0;
    }

    AnClickActionMode mode = [self modeForTask:task];
    NSInteger repeatCount = [self repeatCountForTask:task];
    NSTimeInterval delay = [self delayForTask:task];
    NSTimeInterval duration = [self durationForTaskMode:mode];
    if (mode == AnClickActionModeImage) {
        AnClickActionMode imageActionMode = [self normalizedImageActionMode:(AnClickActionMode)[task[@"imageActionMode"] integerValue]];
        duration = 0.75 + [self durationForTaskMode:imageActionMode];
    }
    NSTimeInterval interval = duration + 0.12;

    for (NSInteger i = 0; i < repeatCount; i++) {
        NSTimeInterval fireDelay = delay + interval * i;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(fireDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *currentHostWindow = [self hostWindow] ?: hostWindow;
            if (mode == AnClickActionModeSwipe) {
                NSArray<NSValue *> *path = task[@"path"];
                [self showTrajectoryForScreenPoints:path inWindow:currentHostWindow duration:0.75];
                [AnClickFakeTouch playPath:path duration:0.55];
            } else if (mode == AnClickActionModeImage) {
                [self performImageTask:task inWindow:currentHostWindow];
            } else {
                NSValue *pointValue = task[@"point"];
                [self performPointActionMode:mode atPoint:pointValue.CGPointValue inWindow:currentHostWindow];
            }
        });
    }

    return delay + interval * repeatCount;
}

- (void)runTaskList {
    if (_taskItems.count == 0) {
        _statusLabel.text = @"先加任务";
        return;
    }

    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    [self collapsePanel];
    [self runTaskAtIndex:0 inWindow:hostWindow];
}

- (void)runTaskAtIndex:(NSUInteger)index inWindow:(UIWindow *)hostWindow {
    if (index >= _taskItems.count) {
        _statusLabel.text = @"任务完成";
        return;
    }

    UIWindow *currentHostWindow = [self hostWindow] ?: hostWindow;
    NSTimeInterval duration = [self performTask:_taskItems[index] inWindow:currentHostWindow];
    if (duration <= 0) {
        [self expandPanel];
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((duration + 0.12) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self runTaskAtIndex:index + 1 inWindow:currentHostWindow];
    });
}

- (void)beginPointPicking {
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
        }
    }

    _panelWindow.hidden = YES;
    [_pointPickOverlay removeFromSuperview];
    _pointPickWindow.hidden = YES;
    _pointPickWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    if (@available(iOS 13.0, *)) {
        _pointPickWindow.windowScene = hostWindow.windowScene ?: [self activeWindowScene];
    }
    _pointPickWindow.windowLevel = UIWindowLevelAlert + 2000;
    _pointPickWindow.backgroundColor = UIColor.clearColor;
    _pointPickWindow.rootViewController = [[UIViewController alloc] init];

    UIView *overlay = [[UIView alloc] initWithFrame:_pointPickWindow.bounds];
    overlay.backgroundColor = UIColor.clearColor;
    overlay.userInteractionEnabled = YES;

    CGFloat cursorSize = 32.0;
    UIView *cursor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cursorSize, cursorSize)];
    cursor.backgroundColor = UIColor.clearColor;
    cursor.layer.cornerRadius = cursorSize * 0.5;
    cursor.layer.borderWidth = 1.25;
    cursor.layer.borderColor = UIColor.systemYellowColor.CGColor;
    cursor.userInteractionEnabled = NO;
    UIView *horizontal = [[UIView alloc] initWithFrame:CGRectMake(6, cursorSize * 0.5 - 0.5, cursorSize - 12, 1)];
    horizontal.backgroundColor = UIColor.systemYellowColor;
    horizontal.userInteractionEnabled = NO;
    [cursor addSubview:horizontal];
    UIView *vertical = [[UIView alloc] initWithFrame:CGRectMake(cursorSize * 0.5 - 0.5, 6, 1, cursorSize - 12)];
    vertical.backgroundColor = UIColor.systemYellowColor;
    vertical.userInteractionEnabled = NO;
    [cursor addSubview:vertical];
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(cursorSize * 0.5 - 2, cursorSize * 0.5 - 2, 4, 4)];
    dot.backgroundColor = UIColor.systemRedColor;
    dot.layer.cornerRadius = 2;
    dot.userInteractionEnabled = NO;
    [cursor addSubview:dot];
    [overlay addSubview:cursor];
    _pointCursorView = cursor;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointPickingTap:)];
    tap.cancelsTouchesInView = NO;
    [overlay addGestureRecognizer:tap];
    UIPanGestureRecognizer *overlayPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointPickingOverlayPan:)];
    overlayPan.cancelsTouchesInView = NO;
    [overlay addGestureRecognizer:overlayPan];

    UIView *toolbar = [[UIView alloc] initWithFrame:CGRectZero];
    toolbar.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.055 alpha:0.72];
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

    [_pointPickWindow.rootViewController.view addSubview:overlay];
    _pointPickOverlay = overlay;
    _pendingPointPickPoint = [self initialPointPickPointInOverlay:overlay];
    _hasPendingPointPickPoint = YES;
    if (_actionMode == AnClickActionModeSwipe && _pickingSwipeEndPoint && _hasManualSwipeAnchor) {
        [self showPointPickSwipeStartMarker];
    }
    [self updatePointPickCursor];
    _pointPickWindow.hidden = NO;
    _statusLabel.text = _pickingSwipeEndPoint ? @"滑动取终点" : @"拖动取点";
}

- (CGPoint)initialPointPickPointInOverlay:(UIView *)overlay {
    if (_actionMode == AnClickActionModeSwipe && _pickingSwipeEndPoint && _hasManualSwipeAnchor) {
        return [self clampedPointPickPoint:_manualSwipeAnchor inOverlay:overlay];
    }
    if ([self hasManualPointForMode:_actionMode]) {
        return [self clampedPointPickPoint:_manualActionPoints[(NSUInteger)_actionMode] inOverlay:overlay];
    }
    return CGPointMake(CGRectGetMidX(overlay.bounds), CGRectGetMidY(overlay.bounds));
}

- (CGPoint)clampedPointPickPoint:(CGPoint)point inOverlay:(UIView *)overlay {
    CGFloat margin = 0;
    point.x = MIN(MAX(point.x, margin), overlay.bounds.size.width - margin);
    point.y = MIN(MAX(point.y, margin), overlay.bounds.size.height - margin);
    return point;
}

- (void)updatePointPickCursor {
    if (!_pointPickOverlay || !_pointCursorView || !_hasPendingPointPickPoint) {
        return;
    }
    _pendingPointPickPoint = [self clampedPointPickPoint:_pendingPointPickPoint inOverlay:_pointPickOverlay];
    _pointCursorView.center = _pendingPointPickPoint;
    NSString *stage = (_actionMode == AnClickActionModeSwipe)
        ? (_pickingSwipeEndPoint ? @"终点" : @"起点")
        : (_actionMode == AnClickActionModeImage ? @"点击点" : [self currentActionName]);
    _pointCoordinateLabel.text = [NSString stringWithFormat:@"%@  X %.0f  Y %.0f",
                                  stage,
                                  _pendingPointPickPoint.x,
                                  _pendingPointPickPoint.y];
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
    CGFloat toolbarWidth = MIN(_pointPickOverlay.bounds.size.width - margin * 2.0, 360.0);
    CGFloat x = (_pointPickOverlay.bounds.size.width - toolbarWidth) * 0.5;
    BOOL cursorNearBottom = _hasPendingPointPickPoint &&
        _pendingPointPickPoint.y > _pointPickOverlay.bounds.size.height - toolbarHeight - 28.0;
    CGFloat y = cursorNearBottom ? margin : _pointPickOverlay.bounds.size.height - toolbarHeight - margin;
    _pointPickToolbar.frame = CGRectMake(x, y, toolbarWidth, toolbarHeight);

    CGFloat buttonWidth = 64.0;
    CGFloat buttonHeight = 34.0;
    CGFloat buttonY = (toolbarHeight - buttonHeight) * 0.5;
    UIButton *confirmButton = (UIButton *)[_pointPickToolbar viewWithTag:1001];
    UIButton *cancelButton = (UIButton *)[_pointPickToolbar viewWithTag:1002];
    cancelButton.frame = CGRectMake(toolbarWidth - margin - buttonWidth, buttonY, buttonWidth, buttonHeight);
    confirmButton.frame = CGRectMake(CGRectGetMinX(cancelButton.frame) - margin - buttonWidth, buttonY, buttonWidth, buttonHeight);
    _pointCoordinateLabel.frame = CGRectMake(10, 0, CGRectGetMinX(confirmButton.frame) - 18, toolbarHeight);
}

- (BOOL)pointPickLocationHitsToolbar:(CGPoint)location {
    return _pointPickToolbar && CGRectContainsPoint(_pointPickToolbar.frame, location);
}

- (void)showPointPickSwipeStartMarker {
    if (!_pointPickOverlay || !_hasManualSwipeAnchor) {
        return;
    }

    [[_pointPickOverlay viewWithTag:2201] removeFromSuperview];
    CGFloat size = 24.0;
    UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    marker.tag = 2201;
    marker.center = [self clampedPointPickPoint:_manualSwipeAnchor inOverlay:_pointPickOverlay];
    marker.userInteractionEnabled = NO;
    marker.backgroundColor = UIColor.clearColor;
    marker.layer.cornerRadius = size * 0.5;
    marker.layer.borderWidth = 2.0;
    marker.layer.borderColor = UIColor.systemGreenColor.CGColor;

    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(size * 0.5 - 2, size * 0.5 - 2, 4, 4)];
    dot.backgroundColor = UIColor.systemGreenColor;
    dot.layer.cornerRadius = 2;
    dot.userInteractionEnabled = NO;
    [marker addSubview:dot];
    [_pointPickOverlay insertSubview:marker belowSubview:_pointCursorView];
}

- (void)finishPointPickingOverlay {
    [_pointPickOverlay removeFromSuperview];
    _pointPickOverlay = nil;
    _pointCursorView = nil;
    _pointPickToolbar = nil;
    _pointCoordinateLabel = nil;
    _hasPendingPointPickPoint = NO;
    _pointPickWindow.hidden = YES;
    _pointPickWindow = nil;
    _pickingSwipeEndPoint = NO;
    [self restorePanelAfterExternalTap];
}

- (void)cancelPointPicking {
    [self finishPointPickingOverlay];
    _statusLabel.text = @"取消取点";
}

- (void)handlePointPickingTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    CGPoint location = [recognizer locationInView:_pointPickOverlay];
    if ([self pointPickLocationHitsToolbar:location]) {
        return;
    }
    _pendingPointPickPoint = [self clampedPointPickPoint:location inOverlay:_pointPickOverlay];
    _hasPendingPointPickPoint = YES;
    [self updatePointPickCursor];
}

- (void)handlePointPickingOverlayPan:(UIPanGestureRecognizer *)recognizer {
    if (!_pointPickOverlay) {
        return;
    }
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _pointPickPanStartedOnToolbar = [self pointPickLocationHitsToolbar:[recognizer locationInView:_pointPickOverlay]];
        [recognizer setTranslation:CGPointZero inView:_pointPickOverlay];
        return;
    }
    if (_pointPickPanStartedOnToolbar) {
        if (recognizer.state == UIGestureRecognizerStateEnded ||
            recognizer.state == UIGestureRecognizerStateCancelled ||
            recognizer.state == UIGestureRecognizerStateFailed) {
            _pointPickPanStartedOnToolbar = NO;
        }
        return;
    }
    if (recognizer.state == UIGestureRecognizerStateChanged ||
        recognizer.state == UIGestureRecognizerStateEnded) {
        CGPoint translation = [recognizer translationInView:_pointPickOverlay];
        _pendingPointPickPoint = [self clampedPointPickPoint:CGPointMake(_pendingPointPickPoint.x + translation.x,
                                                                         _pendingPointPickPoint.y + translation.y)
                                                  inOverlay:_pointPickOverlay];
        _hasPendingPointPickPoint = YES;
        [self updatePointPickCursor];
        [recognizer setTranslation:CGPointZero inView:_pointPickOverlay];
    }
}

- (void)handlePointCursorPan:(UIPanGestureRecognizer *)recognizer {
    if (!_pointPickOverlay) {
        return;
    }
    CGPoint translation = [recognizer translationInView:_pointPickOverlay];
    _pendingPointPickPoint = [self clampedPointPickPoint:CGPointMake(_pendingPointPickPoint.x + translation.x,
                                                                     _pendingPointPickPoint.y + translation.y)
                                              inOverlay:_pointPickOverlay];
    _hasPendingPointPickPoint = YES;
    [self updatePointPickCursor];
    [recognizer setTranslation:CGPointZero inView:_pointPickOverlay];
}

- (void)confirmPointPicking {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow || !_hasPendingPointPickPoint) {
        [self cancelPointPicking];
        return;
    }

    CGPoint screenPoint = _pendingPointPickPoint;

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
            _pendingPointPickPoint = screenPoint;
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
        });
        NSArray<NSValue *> *path = [self manualSwipePath];
        if (path.count >= 2) {
            [self showTrajectoryForScreenPoints:path inWindow:hostWindow duration:1.0];
        }
        [self refreshEditorConfigControls];
        [self updateStatusForCurrentConfig];
        return;
    }

    [self finishPointPickingOverlay];
    _manualActionPoints[(NSUInteger)_actionMode] = screenPoint;
    _hasManualActionPoint[(NSUInteger)_actionMode] = YES;
    [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
    [self updateStatusForCurrentConfig];
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
        [self showTrajectoryForScreenPoints:path inWindow:hostWindow duration:1.2];
        _statusLabel.text = (_hasManualSwipeAnchor && _hasManualSwipeEndPoint) ? @"预览起终点" : @"预览原轨迹";
        return;
    }

    if (_actionMode == AnClickActionModeImage) {
        if (_imageUsesMatchPoint) {
            _statusLabel.text = [self currentTemplateExists] ? @"识图点随识别结果" : @"先截图模板";
            return;
        }
        if (![self hasManualPointForMode:AnClickActionModeImage]) {
            _statusLabel.text = @"先取点击点";
            return;
        }
        CGPoint point = _manualActionPoints[(NSUInteger)AnClickActionModeImage];
        [self showOperationTraceForMode:_imageActionMode atPoint:point inWindow:hostWindow duration:1.0];
        _statusLabel.text = [NSString stringWithFormat:@"预览识图%@ %.0f,%.0f", [self actionNameForMode:_imageActionMode], point.x, point.y];
        return;
    }

    if (![self hasManualPointForMode:_actionMode]) {
        _statusLabel.text = @"先取点";
        return;
    }
    CGPoint point = _manualActionPoints[(NSUInteger)_actionMode];
    NSTimeInterval previewDuration = (_actionMode == AnClickActionModeLongPress) ? 2.0 : 1.0;
    [self showOperationTraceForMode:_actionMode atPoint:point inWindow:hostWindow duration:previewDuration];
    _statusLabel.text = [NSString stringWithFormat:@"预览%@ %.0f,%.0f", [self currentActionName], point.x, point.y];
}

- (void)clearCurrentActionConfig {
    if (_actionMode == AnClickActionModeNone) {
        _statusLabel.text = @"请选择动作";
        return;
    }

    if (_actionMode == AnClickActionModeImage) {
        _currentTemplatePath = nil;
        _imageUsesMatchPoint = YES;
        _hasManualActionPoint[(NSUInteger)AnClickActionModeImage] = NO;
        _manualActionPoints[(NSUInteger)AnClickActionModeImage] = CGPointZero;
        [self refreshEditorConfigControls];
        [self updateStatusForCurrentConfig];
        return;
    }

    if (_actionMode == AnClickActionModeSwipe) {
        [_recordedSwipePoints removeAllObjects];
        _hasManualSwipeAnchor = NO;
        _hasManualSwipeEndPoint = NO;
        _manualSwipeAnchor = CGPointZero;
        _manualSwipeEndPoint = CGPointZero;
        [_trajectoryView removeFromSuperview];
        _statusLabel.text = @"已清滑动";
        return;
    }

    if (_actionMode == AnClickActionModeLongPress && (_longPressHolding || [AnClickFakeTouch isHolding])) {
        [AnClickFakeTouch cancelHold];
        _longPressHolding = NO;
    }

    _hasManualActionPoint[(NSUInteger)_actionMode] = NO;
    _manualActionPoints[(NSUInteger)_actionMode] = CGPointZero;
    _statusLabel.text = [NSString stringWithFormat:@"已清%@", [self currentActionName]];
}

- (void)toggleMacroRecording {
    AnClickRecorder *recorder = [AnClickRecorder shared];
    if (recorder.isRecording) {
        [recorder stopRecording];
        _recordedMacroEvents = [recorder serializedEvents];
        [_recordSwipeButton setTitle:@"录制" forState:UIControlStateNormal];
        _recordSwipeButton.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.18 alpha:1.0];
        _statusLabel.text = [NSString stringWithFormat:@"已录 %lu步", (unsigned long)_recordedMacroEvents.count];
        return;
    }

    _recordedMacroEvents = nil;
    [recorder startRecording];
    [_recordSwipeButton setTitle:@"停止" forState:UIControlStateNormal];
    _recordSwipeButton.backgroundColor = [UIColor colorWithRed:0.84 green:0.18 blue:0.18 alpha:1.0];
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

    [self preparePanelForExternalTapWithHostWindow:hostWindow];
    NSArray<NSValue *> *trajectory = [self recordedMacroTrajectoryPoints];
    if (trajectory.count >= 2) {
        [self showTrajectoryForScreenPoints:trajectory inWindow:hostWindow duration:1.2];
    } else if (trajectory.count == 1) {
        [self showTapMarkerAtScreenPoint:trajectory.firstObject.CGPointValue inWindow:hostWindow];
    }
    [AnClickFakeTouch playRecordedEvents:_recordedMacroEvents];
    _statusLabel.text = [NSString stringWithFormat:@"回放 %lu步", (unsigned long)_recordedMacroEvents.count];
}

- (void)beginSwipeRecording {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

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
        } else {
            _statusLabel.text = @"录制失败";
            [_trajectoryView removeFromSuperview];
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

    NSString *path = [self templatePath];
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
    [self preparePanelForExternalTapWithHostWindow:hostWindow];
    dispatch_async([self templateSearchQueue], ^{
        NSDictionary *match = [AnClickCore findTemplateImageMatch:templateImage threshold:0.86];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_templateSearchInProgress = NO;
            self->_playButton.enabled = YES;
            self->_playButton.alpha = 1.0;
            if (!match) {
                [self restorePanelAfterExternalTap];
                self->_statusLabel.text = @"未找到";
                return;
            }
            NSValue *pointValue = match[@"point"];
            NSValue *rectValue = match[@"rect"];
            NSNumber *scoreNumber = match[@"score"];
            if (!pointValue || !rectValue) {
                [self restorePanelAfterExternalTap];
                self->_statusLabel.text = @"识别异常";
                return;
            }
            CGPoint point = pointValue.CGPointValue;
            CGRect rect = rectValue.CGRectValue;
            UIWindow *currentHostWindow = [self hostWindow] ?: hostWindow;
            [self preparePanelForExternalTapWithHostWindow:currentHostWindow];
            [self showRecognitionBoxForScreenRect:rect score:scoreNumber.doubleValue inWindow:currentHostWindow duration:1.6];
            [self performSelectedActionAtPoint:point inWindow:currentHostWindow];
            self->_statusLabel.text = [NSString stringWithFormat:@"识别 %.2f  %.0f,%.0f",
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

__attribute__((constructor)) static void AnClickUIInit(void) {
    NSLog(@"[AnClick] UI constructor loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AnClickUI shared] show];
    });
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification) {
        [[AnClickUI shared] show];
    }];
}
