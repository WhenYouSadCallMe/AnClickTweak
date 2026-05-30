#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (NSValue *)findTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
+ (BOOL)findAndTapTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
@end

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
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
    UILabel *_statusLabel;
    UIView *_captureOverlay;
    UIView *_selectionView;
    UIImage *_captureSnapshot;
    UIImageView *_previewView;
    UIView *_tapMarkerView;
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
    _panelWindow = [[UIWindow alloc] initWithFrame:CGRectMake(12, 120, panelWidth, 104)];
    [self attachPanelWindowToActiveSceneIfNeeded];
    _panelWindow.windowLevel = UIWindowLevelAlert + 1000;
    _panelWindow.backgroundColor = UIColor.clearColor;
    _panelWindow.hidden = NO;

    UIViewController *controller = [[UIViewController alloc] init];
    _panelWindow.rootViewController = controller;

    _panelView = [[UIView alloc] initWithFrame:_panelWindow.bounds];
    _panelView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.88];
    _panelView.layer.cornerRadius = 8;
    _panelView.layer.borderWidth = 1;
    _panelView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    [controller.view addSubview:_panelView];

    UIPanGestureRecognizer *panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [_panelView addGestureRecognizer:panelPan];

    CGFloat gap = 8.0;
    CGFloat buttonWidth = floor((panelWidth - gap * 4.0) / 3.0);
    _captureButton = [self panelButtonWithTitle:@"截图" action:@selector(beginTemplateCapture)];
    _captureButton.frame = CGRectMake(gap, 8, buttonWidth, 38);
    [_panelView addSubview:_captureButton];

    _playButton = [self panelButtonWithTitle:@"播放" action:@selector(playTemplateTap)];
    _playButton.frame = CGRectMake(gap * 2.0 + buttonWidth, 8, buttonWidth, 38);
    [_panelView addSubview:_playButton];

    _testButton = [self panelButtonWithTitle:@"测试" action:@selector(testCenterTap)];
    _testButton.frame = CGRectMake(gap * 3.0 + buttonWidth * 2.0, 8, buttonWidth, 38);
    [_panelView addSubview:_testButton];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 52, panelWidth - 16, 22)];
    _statusLabel.text = @"待机";
    _statusLabel.textColor = UIColor.whiteColor;
    _statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _statusLabel.adjustsFontSizeToFitWidth = YES;
    _statusLabel.minimumScaleFactor = 0.6;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [_panelView addSubview:_statusLabel];

    _previewView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 80, panelWidth - 16, 14)];
    _previewView.contentMode = UIViewContentModeScaleAspectFit;
    _previewView.clipsToBounds = YES;
    _previewView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
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
    button.backgroundColor = [UIColor colorWithRed:0.10 green:0.34 blue:0.56 alpha:1.0];
    button.layer.cornerRadius = 6;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
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
    _panelWindow.hidden = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_captureSnapshot = [AnClickCore captureCurrentWindowImage];
        if (!self->_captureSnapshot.CGImage) {
            self->_panelWindow.hidden = NO;
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
    button.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.9];
    button.layer.cornerRadius = 8;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
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
    if (_panelWindow) {
        _panelWindow.userInteractionEnabled = NO;
        _panelWindow.alpha = 0.0;
        _panelWindow.hidden = YES;
    }

    if (hostWindow && !hostWindow.isKeyWindow) {
        [hostWindow makeKeyWindow];
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
            [self showTapMarkerAtScreenPoint:point inWindow:currentHostWindow];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [AnClickFakeTouch tapAtPoint:point];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self restorePanelAfterExternalTap];
                    self->_statusLabel.text = [NSString stringWithFormat:@"点 %.0f,%.0f", point.x, point.y];
                });
            });
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
    [self showTapMarkerAtScreenPoint:point inWindow:hostWindow];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [AnClickFakeTouch tapAtPoint:point];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self restorePanelAfterExternalTap];
            self->_statusLabel.text = [NSString stringWithFormat:@"测 %.0f,%.0f", point.x, point.y];
        });
    });
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
