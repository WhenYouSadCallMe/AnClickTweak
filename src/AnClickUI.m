#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

typedef NS_ENUM(NSInteger, AnClickActionMode) {
    AnClickActionModeTap = 0,
    AnClickActionModeDoubleTap = 1,
    AnClickActionModeLongPress = 2,
    AnClickActionModeSwipe = 3,
};

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
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
    UIButton *_captureButton;
    UIButton *_playButton;
    UIButton *_testButton;
    UIButton *_recordSwipeButton;
    UIButton *_pickPointButton;
    UIButton *_runManualButton;
    UIButton *_previewSwipeButton;
    UIButton *_clearActionButton;
    NSArray<UIButton *> *_modeButtons;
    UILabel *_statusLabel;
    UIView *_captureOverlay;
    UIView *_selectionView;
    UIView *_pointPickOverlay;
    UIWindow *_pointPickWindow;
    UIView *_pointCursorView;
    UILabel *_pointCoordinateLabel;
    UIImage *_captureSnapshot;
    UIImageView *_previewView;
    UIView *_tapMarkerView;
    UIView *_trajectoryView;
    CAShapeLayer *_trajectoryLayer;
    NSMutableArray<NSValue *> *_recordedSwipePoints;
    NSMutableArray<NSValue *> *_liveSwipePoints;
    NSArray<NSDictionary *> *_recordedMacroEvents;
    CGPoint _manualActionPoints[3];
    BOOL _hasManualActionPoint[3];
    CGPoint _manualSwipeAnchor;
    BOOL _hasManualSwipeAnchor;
    CGPoint _pendingPointPickPoint;
    BOOL _hasPendingPointPickPoint;
    BOOL _longPressHolding;
    AnClickActionMode _actionMode;
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
    CGFloat panelWidth = MIN(360.0, UIScreen.mainScreen.bounds.size.width - 24.0);
    _actionMode = AnClickActionModeTap;
    if (!_recordedSwipePoints) {
        _recordedSwipePoints = [NSMutableArray array];
    }

    _panelWindow = [[UIWindow alloc] initWithFrame:CGRectMake(12, 120, panelWidth, 196)];
    [self attachPanelWindowToActiveSceneIfNeeded];
    _panelWindow.windowLevel = UIWindowLevelAlert + 1000;
    _panelWindow.backgroundColor = UIColor.clearColor;
    _panelWindow.hidden = NO;

    UIViewController *controller = [[UIViewController alloc] init];
    _panelWindow.rootViewController = controller;

    _panelView = [[UIView alloc] initWithFrame:_panelWindow.bounds];
    _panelView.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.10 alpha:0.94];
    _panelView.layer.cornerRadius = 6;
    _panelView.layer.borderWidth = 1;
    _panelView.layer.borderColor = [UIColor colorWithRed:0.33 green:0.58 blue:0.86 alpha:0.55].CGColor;
    _panelView.layer.shadowColor = UIColor.blackColor.CGColor;
    _panelView.layer.shadowOpacity = 0.35;
    _panelView.layer.shadowRadius = 14.0;
    _panelView.layer.shadowOffset = CGSizeMake(0, 8);
    [controller.view addSubview:_panelView];

    UIPanGestureRecognizer *panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [_panelView addGestureRecognizer:panelPan];

    CGFloat gap = 8.0;
    CGFloat modeWidth = floor((panelWidth - gap * 5.0) / 4.0);
    NSArray<NSString *> *modeTitles = @[@"点击", @"双击", @"长按", @"滑动"];
    NSMutableArray<UIButton *> *modeButtons = [NSMutableArray array];
    for (NSUInteger i = 0; i < modeTitles.count; i++) {
        UIButton *button = [self panelButtonWithTitle:modeTitles[i] action:@selector(selectActionMode:)];
        button.tag = (NSInteger)i;
        button.frame = CGRectMake(gap + (modeWidth + gap) * i, 8, modeWidth, 32);
        [_panelView addSubview:button];
        [modeButtons addObject:button];
    }
    _modeButtons = [modeButtons copy];
    [self refreshModeButtons];

    CGFloat buttonWidth = floor((panelWidth - gap * 5.0) / 4.0);
    _captureButton = [self panelButtonWithTitle:@"截图" action:@selector(beginTemplateCapture)];
    _captureButton.frame = CGRectMake(gap, 48, buttonWidth, 34);
    [_panelView addSubview:_captureButton];

    _playButton = [self panelButtonWithTitle:@"识图" action:@selector(playTemplateTap)];
    _playButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 48, buttonWidth, 34);
    [_panelView addSubview:_playButton];

    _pickPointButton = [self panelButtonWithTitle:@"取点" action:@selector(beginPointPicking)];
    _pickPointButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 48, buttonWidth, 34);
    [_panelView addSubview:_pickPointButton];

    _runManualButton = [self panelButtonWithTitle:@"执行" action:@selector(runManualAction)];
    _runManualButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 48, buttonWidth, 34);
    [_panelView addSubview:_runManualButton];

    _recordSwipeButton = [self panelButtonWithTitle:@"录制" action:@selector(toggleMacroRecording)];
    _recordSwipeButton.frame = CGRectMake(gap, 88, buttonWidth, 34);
    [_panelView addSubview:_recordSwipeButton];

    _previewSwipeButton = [self panelButtonWithTitle:@"回放" action:@selector(playRecordedMacro)];
    _previewSwipeButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 88, buttonWidth, 34);
    [_panelView addSubview:_previewSwipeButton];

    _clearActionButton = [self panelButtonWithTitle:@"清除" action:@selector(clearCurrentActionConfig)];
    _clearActionButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 88, buttonWidth, 34);
    [_panelView addSubview:_clearActionButton];

    _testButton = [self panelButtonWithTitle:@"测试" action:@selector(testCenterTap)];
    _testButton.frame = CGRectMake(gap * 4.0 + buttonWidth * 3.0, 88, buttonWidth, 34);
    [_panelView addSubview:_testButton];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 130, panelWidth - 16, 22)];
    _statusLabel.text = @"待机";
    _statusLabel.textColor = UIColor.whiteColor;
    _statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _statusLabel.adjustsFontSizeToFitWidth = YES;
    _statusLabel.minimumScaleFactor = 0.6;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [_panelView addSubview:_statusLabel];

    _previewView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 158, panelWidth - 16, 30)];
    _previewView.contentMode = UIViewContentModeScaleAspectFit;
    _previewView.clipsToBounds = YES;
    _previewView.backgroundColor = [UIColor colorWithRed:0.12 green:0.14 blue:0.17 alpha:1.0];
    _previewView.layer.cornerRadius = 4;
    _previewView.layer.borderWidth = 1;
    _previewView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    _previewView.hidden = YES;
    [_panelView addSubview:_previewView];
    [self refreshTemplatePreview];

    _panelWindow.hidden = NO;
    NSLog(@"[AnClick] Panel shown");
}

- (UIButton *)panelButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.backgroundColor = [UIColor colorWithRed:0.16 green:0.20 blue:0.25 alpha:1.0];
    button.layer.cornerRadius = 4;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)selectActionMode:(UIButton *)sender {
    _actionMode = (AnClickActionMode)sender.tag;
    [self refreshModeButtons];

    NSString *name = [self currentActionName];
    if (_actionMode == AnClickActionModeSwipe) {
        if (_recordedSwipePoints.count < 2) {
            _statusLabel.text = @"滑动需录制";
        } else if (_hasManualSwipeAnchor) {
            _statusLabel.text = @"滑动已设锚点";
        } else {
            _statusLabel.text = @"滑动已录轨迹";
        }
    } else if ([self hasManualPointForMode:_actionMode]) {
        CGPoint point = _manualActionPoints[(NSUInteger)_actionMode];
        _statusLabel.text = [NSString stringWithFormat:@"%@ %.0f,%.0f", name, point.x, point.y];
    } else {
        _statusLabel.text = [NSString stringWithFormat:@"模式 %@", name];
    }
}

- (void)refreshModeButtons {
    for (UIButton *button in _modeButtons) {
        BOOL selected = button.tag == _actionMode;
        button.backgroundColor = selected
            ? [UIColor colorWithRed:0.93 green:0.57 blue:0.18 alpha:1.0]
            : [UIColor colorWithRed:0.16 green:0.20 blue:0.25 alpha:1.0];
        button.layer.borderColor = selected
            ? [UIColor colorWithRed:1.0 green:0.78 blue:0.36 alpha:1.0].CGColor
            : [UIColor colorWithWhite:1 alpha:0.10].CGColor;
        [button setTitleColor:selected ? UIColor.blackColor : UIColor.whiteColor forState:UIControlStateNormal];
    }
}

- (NSString *)currentActionName {
    NSArray<NSString *> *names = @[@"点击", @"双击", @"长按", @"滑动"];
    return names[(NSUInteger)_actionMode];
}

- (BOOL)hasManualPointForMode:(AnClickActionMode)mode {
    if (mode < AnClickActionModeTap || mode > AnClickActionModeLongPress) {
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
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    _statusLabel.text = @"截图中";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_captureSnapshot = [AnClickCore captureCurrentWindowImage];
        if (!self->_captureSnapshot.CGImage) {
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
    hint.text = @"拖动方框选择区域，双指缩放大小";
    hint.textColor = UIColor.whiteColor;
    hint.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    hint.adjustsFontSizeToFitWidth = YES;
    hint.textAlignment = NSTextAlignmentCenter;
    [_captureOverlay addSubview:hint];

    CGFloat side = MIN(150.0, MIN(hostWindow.bounds.size.width, hostWindow.bounds.size.height) - 40.0);
    CGRect selectionFrame = CGRectMake((hostWindow.bounds.size.width - side) * 0.5,
                                       (hostWindow.bounds.size.height - side) * 0.5,
                                       side,
                                       side);
    _selectionView = [[UIView alloc] initWithFrame:selectionFrame];
    _selectionView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    _selectionView.layer.borderColor = UIColor.systemYellowColor.CGColor;
    _selectionView.layer.borderWidth = 2.0;
    _selectionView.userInteractionEnabled = YES;
    [_captureOverlay addSubview:_selectionView];

    UILabel *selectionLabel = [[UILabel alloc] initWithFrame:_selectionView.bounds];
    selectionLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    selectionLabel.text = @"模板区域";
    selectionLabel.textColor = UIColor.whiteColor;
    selectionLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    selectionLabel.textAlignment = NSTextAlignmentCenter;
    [_selectionView addSubview:selectionLabel];
    [self addCornerHandles];

    UIPanGestureRecognizer *movePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSelectionPan:)];
    [_selectionView addGestureRecognizer:movePan];

    UIButton *saveButton = [self overlayButtonWithTitle:@"保存" action:@selector(saveSelectedTemplate)];
    saveButton.frame = CGRectMake(16, hostWindow.bounds.size.height - 70, 86, 44);
    [_captureOverlay addSubview:saveButton];

    UIButton *cancelButton = [self overlayButtonWithTitle:@"取消" action:@selector(cancelTemplateCapture)];
    cancelButton.frame = CGRectMake(hostWindow.bounds.size.width - 102, hostWindow.bounds.size.height - 70, 86, 44);
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
    CGFloat minSide = 40.0;
    CGFloat maxWidth = MAX(minSide, bounds.size.width - 20.0);
    CGFloat maxHeight = MAX(minSide, bounds.size.height - 20.0);
    frame.size.width = MIN(MAX(frame.size.width, minSide), maxWidth);
    frame.size.height = MIN(MAX(frame.size.height, minSide), maxHeight);
    frame.origin.x = MIN(MAX(frame.origin.x, 10.0), bounds.size.width - frame.size.width - 10.0);
    frame.origin.y = MIN(MAX(frame.origin.y, 10.0), bounds.size.height - frame.size.height - 10.0);
    return frame;
}

- (void)handleSelectionPan:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.view != _selectionView) {
        return;
    }
    CGPoint translation = [recognizer translationInView:_captureOverlay];
    CGRect frame = _selectionView.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    _selectionView.frame = [self clampedSelectionFrame:frame];
    [recognizer setTranslation:CGPointZero inView:_captureOverlay];
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
    if (!_captureSnapshot.CGImage || !_selectionView) {
        [self cancelTemplateCapture];
        _statusLabel.text = @"截图失败";
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
    BOOL saved = [pngData writeToFile:[self templatePath] atomically:YES];
    [self finishTemplateCapture];
    [self refreshTemplatePreview];
    _statusLabel.text = saved ? @"已保存" : @"保存失败";
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
    [self restorePanelAfterExternalTap];
}

- (void)refreshTemplatePreview {
    NSString *path = [self templatePath];
    UIImage *image = [[NSFileManager defaultManager] fileExistsAtPath:path] ? [UIImage imageWithContentsOfFile:path] : nil;
    _previewView.image = image;
    _previewView.hidden = (image == nil);
}

- (void)preparePanelForExternalTapWithHostWindow:(UIWindow *)hostWindow {
    if (hostWindow && !hostWindow.isKeyWindow) {
        [hostWindow makeKeyWindow];
    }
    if (_panelWindow) {
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
}

- (void)showTapMarkerAtScreenPoint:(CGPoint)screenPoint inWindow:(UIWindow *)hostWindow {
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
    marker.layer.borderColor = UIColor.systemRedColor.CGColor;

    UIView *horizontal = [[UIView alloc] initWithFrame:CGRectMake(4, size * 0.5 - 1, size - 8, 2)];
    horizontal.backgroundColor = UIColor.systemRedColor;
    horizontal.userInteractionEnabled = NO;
    [marker addSubview:horizontal];

    UIView *vertical = [[UIView alloc] initWithFrame:CGRectMake(size * 0.5 - 1, 4, 2, size - 8)];
    vertical.backgroundColor = UIColor.systemRedColor;
    vertical.userInteractionEnabled = NO;
    [marker addSubview:vertical];

    [hostWindow addSubview:marker];
    _tapMarkerView = marker;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [marker removeFromSuperview];
        if (self->_tapMarkerView == marker) {
            self->_tapMarkerView = nil;
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
    [self preparePanelForExternalTapWithHostWindow:hostWindow];

    if (_actionMode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = [self recordedSwipePointsAnchoredAtPoint:point];
        if (path.count < 2) {
            _statusLabel.text = @"先录滑动";
            return;
        }
        [self showTrajectoryForScreenPoints:path inWindow:hostWindow duration:1.1];
        [AnClickFakeTouch playPath:path duration:0.55];
        _statusLabel.text = [NSString stringWithFormat:@"滑 %.0f,%.0f", point.x, point.y];
        return;
    }

    [self showTapMarkerAtScreenPoint:point inWindow:hostWindow];
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
                self->_statusLabel.text = @"长按完成无点击";
                [self refreshModeButtons];
            }
        });
    } else {
        [AnClickFakeTouch tapAtPoint:point];
        _statusLabel.text = [NSString stringWithFormat:@"点 %.0f,%.0f", point.x, point.y];
    }
}

- (NSArray<NSValue *> *)manualSwipePath {
    if (_recordedSwipePoints.count < 2) {
        return @[];
    }
    if (_hasManualSwipeAnchor) {
        return [self recordedSwipePointsAnchoredAtPoint:_manualSwipeAnchor];
    }
    return [_recordedSwipePoints copy];
}

- (void)beginPointPicking {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

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
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.08];
    overlay.userInteractionEnabled = YES;

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(12, 44, overlay.bounds.size.width - 24, 38)];
    hint.text = _actionMode == AnClickActionModeSwipe ? @"拖动准星选择滑动起点" : [NSString stringWithFormat:@"拖动准星选择%@", [self currentActionName]];
    hint.textColor = UIColor.whiteColor;
    hint.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.10 alpha:0.86];
    hint.layer.cornerRadius = 6;
    hint.layer.borderWidth = 1;
    hint.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    hint.clipsToBounds = YES;
    [overlay addSubview:hint];

    CGFloat controlWidth = MIN(330.0, overlay.bounds.size.width - 24.0);
    UIView *controlPanel = [[UIView alloc] initWithFrame:CGRectMake((overlay.bounds.size.width - controlWidth) * 0.5,
                                                                    overlay.bounds.size.height - 164.0,
                                                                    controlWidth,
                                                                    142.0)];
    controlPanel.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.10 alpha:0.92];
    controlPanel.layer.cornerRadius = 6;
    controlPanel.layer.borderWidth = 1;
    controlPanel.layer.borderColor = [UIColor colorWithRed:0.33 green:0.58 blue:0.86 alpha:0.45].CGColor;
    [overlay addSubview:controlPanel];

    _pointCoordinateLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, controlWidth - 20, 24)];
    _pointCoordinateLabel.textColor = UIColor.whiteColor;
    _pointCoordinateLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightSemibold];
    _pointCoordinateLabel.textAlignment = NSTextAlignmentCenter;
    [controlPanel addSubview:_pointCoordinateLabel];

    UIButton *upButton = [self pointNudgeButtonWithTitle:@"上" tag:1];
    upButton.frame = CGRectMake(62, 36, 44, 32);
    [controlPanel addSubview:upButton];

    UIButton *leftButton = [self pointNudgeButtonWithTitle:@"左" tag:2];
    leftButton.frame = CGRectMake(14, 72, 44, 32);
    [controlPanel addSubview:leftButton];

    UIButton *rightButton = [self pointNudgeButtonWithTitle:@"右" tag:3];
    rightButton.frame = CGRectMake(110, 72, 44, 32);
    [controlPanel addSubview:rightButton];

    UIButton *downButton = [self pointNudgeButtonWithTitle:@"下" tag:4];
    downButton.frame = CGRectMake(62, 108, 44, 28);
    [controlPanel addSubview:downButton];

    UIButton *confirmButton = [self overlayButtonWithTitle:@"确认" action:@selector(confirmPointPicking)];
    confirmButton.frame = CGRectMake(controlWidth - 148, 44, 64, 40);
    confirmButton.backgroundColor = [UIColor colorWithRed:0.93 green:0.57 blue:0.18 alpha:1.0];
    [confirmButton setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [controlPanel addSubview:confirmButton];

    UIButton *cancelButton = [self overlayButtonWithTitle:@"取消" action:@selector(cancelPointPicking)];
    cancelButton.frame = CGRectMake(controlWidth - 76, 44, 64, 40);
    [controlPanel addSubview:cancelButton];

    UILabel *stepLabel = [[UILabel alloc] initWithFrame:CGRectMake(controlWidth - 150, 92, 138, 34)];
    stepLabel.text = @"微调 1px\n拖动可粗调";
    stepLabel.textColor = [UIColor colorWithWhite:1 alpha:0.72];
    stepLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    stepLabel.textAlignment = NSTextAlignmentCenter;
    stepLabel.numberOfLines = 2;
    [controlPanel addSubview:stepLabel];

    CGFloat cursorSize = 58.0;
    UIView *cursor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cursorSize, cursorSize)];
    cursor.backgroundColor = UIColor.clearColor;
    cursor.layer.cornerRadius = cursorSize * 0.5;
    cursor.layer.borderWidth = 2.0;
    cursor.layer.borderColor = UIColor.systemYellowColor.CGColor;
    cursor.userInteractionEnabled = YES;
    UIView *horizontal = [[UIView alloc] initWithFrame:CGRectMake(4, cursorSize * 0.5 - 1, cursorSize - 8, 2)];
    horizontal.backgroundColor = UIColor.systemYellowColor;
    horizontal.userInteractionEnabled = NO;
    [cursor addSubview:horizontal];
    UIView *vertical = [[UIView alloc] initWithFrame:CGRectMake(cursorSize * 0.5 - 1, 4, 2, cursorSize - 8)];
    vertical.backgroundColor = UIColor.systemYellowColor;
    vertical.userInteractionEnabled = NO;
    [cursor addSubview:vertical];
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(cursorSize * 0.5 - 3, cursorSize * 0.5 - 3, 6, 6)];
    dot.backgroundColor = UIColor.systemRedColor;
    dot.layer.cornerRadius = 3;
    dot.userInteractionEnabled = NO;
    [cursor addSubview:dot];
    UIPanGestureRecognizer *cursorPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointCursorPan:)];
    [cursor addGestureRecognizer:cursorPan];
    [overlay addSubview:cursor];
    _pointCursorView = cursor;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointPickingTap:)];
    [overlay addGestureRecognizer:tap];

    [_pointPickWindow.rootViewController.view addSubview:overlay];
    _pointPickOverlay = overlay;
    _pendingPointPickPoint = [self initialPointPickPointInOverlay:overlay];
    _hasPendingPointPickPoint = YES;
    [self updatePointPickCursor];
    _pointPickWindow.hidden = NO;
    _statusLabel.text = @"移动准星后确认";
}

- (UIButton *)pointNudgeButtonWithTitle:(NSString *)title tag:(NSInteger)tag {
    UIButton *button = [self overlayButtonWithTitle:title action:@selector(nudgePointPicking:)];
    button.tag = tag;
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    return button;
}

- (CGPoint)initialPointPickPointInOverlay:(UIView *)overlay {
    if (_actionMode == AnClickActionModeSwipe && _hasManualSwipeAnchor) {
        return [self clampedPointPickPoint:_manualSwipeAnchor inOverlay:overlay];
    }
    if (_actionMode <= AnClickActionModeLongPress && [self hasManualPointForMode:_actionMode]) {
        return [self clampedPointPickPoint:_manualActionPoints[(NSUInteger)_actionMode] inOverlay:overlay];
    }
    return CGPointMake(CGRectGetMidX(overlay.bounds), CGRectGetMidY(overlay.bounds));
}

- (CGPoint)clampedPointPickPoint:(CGPoint)point inOverlay:(UIView *)overlay {
    CGFloat margin = 6.0;
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
    _pointCoordinateLabel.text = [NSString stringWithFormat:@"X %.0f   Y %.0f", _pendingPointPickPoint.x, _pendingPointPickPoint.y];
}

- (void)cancelPointPicking {
    [_pointPickOverlay removeFromSuperview];
    _pointPickOverlay = nil;
    _pointCursorView = nil;
    _pointCoordinateLabel = nil;
    _hasPendingPointPickPoint = NO;
    _pointPickWindow.hidden = YES;
    _pointPickWindow = nil;
    _statusLabel.text = @"取消取点";
}

- (void)handlePointPickingTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    UIView *hitView = [_pointPickOverlay hitTest:[recognizer locationInView:_pointPickOverlay] withEvent:nil];
    if ([hitView isKindOfClass:UIControl.class] || [hitView.superview isKindOfClass:UIControl.class]) {
        return;
    }
    _pendingPointPickPoint = [self clampedPointPickPoint:[recognizer locationInView:_pointPickOverlay] inOverlay:_pointPickOverlay];
    _hasPendingPointPickPoint = YES;
    [self updatePointPickCursor];
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

- (void)nudgePointPicking:(UIButton *)sender {
    if (!_pointPickOverlay) {
        return;
    }
    CGFloat dx = 0;
    CGFloat dy = 0;
    if (sender.tag == 1) {
        dy = -1;
    } else if (sender.tag == 2) {
        dx = -1;
    } else if (sender.tag == 3) {
        dx = 1;
    } else if (sender.tag == 4) {
        dy = 1;
    }
    _pendingPointPickPoint = [self clampedPointPickPoint:CGPointMake(_pendingPointPickPoint.x + dx,
                                                                     _pendingPointPickPoint.y + dy)
                                              inOverlay:_pointPickOverlay];
    _hasPendingPointPickPoint = YES;
    [self updatePointPickCursor];
}

- (void)confirmPointPicking {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow || !_hasPendingPointPickPoint) {
        [self cancelPointPicking];
        return;
    }

    CGPoint screenPoint = _pendingPointPickPoint;
    [_pointPickOverlay removeFromSuperview];
    _pointPickOverlay = nil;
    _pointCursorView = nil;
    _pointCoordinateLabel = nil;
    _hasPendingPointPickPoint = NO;
    _pointPickWindow.hidden = YES;
    _pointPickWindow = nil;

    if (_actionMode == AnClickActionModeSwipe) {
        _manualSwipeAnchor = screenPoint;
        _hasManualSwipeAnchor = YES;
        [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
        NSArray<NSValue *> *path = [self manualSwipePath];
        if (path.count >= 2) {
            [self showTrajectoryForScreenPoints:path inWindow:hostWindow duration:1.0];
        }
        _statusLabel.text = [NSString stringWithFormat:@"滑动起点 %.0f,%.0f", screenPoint.x, screenPoint.y];
        return;
    }

    _manualActionPoints[(NSUInteger)_actionMode] = screenPoint;
    _hasManualActionPoint[(NSUInteger)_actionMode] = YES;
    [self showTapMarkerAtScreenPoint:screenPoint inWindow:hostWindow];
    _statusLabel.text = [NSString stringWithFormat:@"%@点 %.0f,%.0f", [self currentActionName], screenPoint.x, screenPoint.y];
}

- (void)runManualAction {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    if (_actionMode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = [self manualSwipePath];
        if (path.count < 2) {
            _statusLabel.text = @"先录滑动";
            return;
        }
        [self preparePanelForExternalTapWithHostWindow:hostWindow];
        [self showTrajectoryForScreenPoints:path inWindow:hostWindow duration:1.1];
        [AnClickFakeTouch playPath:path duration:0.55];
        _statusLabel.text = _hasManualSwipeAnchor ? @"执行滑动锚点" : @"执行原轨迹";
        return;
    }

    if (![self hasManualPointForMode:_actionMode]) {
        _statusLabel.text = @"先取点";
        return;
    }
    [self performSelectedActionAtPoint:_manualActionPoints[(NSUInteger)_actionMode] inWindow:hostWindow];
}

- (void)previewCurrentAction {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"无窗口";
        return;
    }

    if (_actionMode == AnClickActionModeSwipe) {
        NSArray<NSValue *> *path = [self manualSwipePath];
        if (path.count < 2) {
            _statusLabel.text = @"先录滑动";
            return;
        }
        [self showTrajectoryForScreenPoints:path inWindow:hostWindow duration:1.2];
        _statusLabel.text = _hasManualSwipeAnchor ? @"预览锚点轨迹" : @"预览原轨迹";
        return;
    }

    if (![self hasManualPointForMode:_actionMode]) {
        _statusLabel.text = @"先取点";
        return;
    }
    CGPoint point = _manualActionPoints[(NSUInteger)_actionMode];
    [self showTapMarkerAtScreenPoint:point inWindow:hostWindow];
    _statusLabel.text = [NSString stringWithFormat:@"预览%@ %.0f,%.0f", [self currentActionName], point.x, point.y];
}

- (void)clearCurrentActionConfig {
    if (_actionMode == AnClickActionModeSwipe) {
        [_recordedSwipePoints removeAllObjects];
        _hasManualSwipeAnchor = NO;
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
        _recordSwipeButton.backgroundColor = [UIColor colorWithRed:0.16 green:0.20 blue:0.25 alpha:1.0];
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

- (void)playTemplateTap {
    NSString *path = [self templatePath];
    UIImage *templateImage = [[NSFileManager defaultManager] fileExistsAtPath:path] ? [UIImage imageWithContentsOfFile:path] : nil;
    if (!templateImage) {
        _statusLabel.text = @"先截图";
        return;
    }

    _statusLabel.text = @"寻找";
    UIWindow *hostWindow = [self hostWindow];
    [self preparePanelForExternalTapWithHostWindow:hostWindow];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSValue *pointValue = [AnClickCore findTemplateImage:templateImage threshold:0.86];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!pointValue) {
                [self restorePanelAfterExternalTap];
                self->_statusLabel.text = @"未找到";
                return;
            }
            CGPoint point = pointValue.CGPointValue;
            UIWindow *currentHostWindow = [self hostWindow] ?: hostWindow;
            [self preparePanelForExternalTapWithHostWindow:currentHostWindow];
            [self performSelectedActionAtPoint:point inWindow:currentHostWindow];
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
