#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AnClickRecordEvent : NSObject
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) NSTimeInterval timestamp;
@end

@interface AnClickRecorder : NSObject
+ (instancetype)shared;
- (void)startRecording;
- (NSArray<AnClickRecordEvent *> *)stopRecording;
- (NSArray<AnClickRecordEvent *> *)events;
- (NSArray<NSDictionary *> *)serializedEvents;
@property (nonatomic, assign, getter=isRecording) BOOL recording;
@end

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end;
+ (void)touchDownAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchMoveAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchUpAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
@end

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (BOOL)findAndTapTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
@end

@interface AnClickUI : NSObject
+ (instancetype)shared;
- (void)show;
@end

@implementation AnClickUI {
    UIWindow *_panelWindow;
    UIView *_panelView;
    UIButton *_recordButton;
    UIButton *_playButton;
    UIButton *_visionButton;
    UIButton *_templateButton;
    UILabel *_statusLabel;
    NSArray<AnClickRecordEvent *> *_lastRecording;
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
            [self->_panelWindow makeKeyAndVisible];
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
    CGRect frame = CGRectMake(18, 120, 280, 54);
    _panelWindow = [[UIWindow alloc] initWithFrame:frame];
    [self attachPanelWindowToActiveSceneIfNeeded];
    _panelWindow.windowLevel = UIWindowLevelAlert + 1000;
    _panelWindow.backgroundColor = UIColor.clearColor;
    _panelWindow.hidden = NO;

    UIViewController *controller = [[UIViewController alloc] init];
    _panelWindow.rootViewController = controller;

    _panelView = [[UIView alloc] initWithFrame:_panelWindow.bounds];
    _panelView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.86];
    _panelView.layer.cornerRadius = 8;
    _panelView.layer.borderWidth = 1;
    _panelView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    [controller.view addSubview:_panelView];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [_panelView addGestureRecognizer:pan];

    _recordButton = [self buttonWithTitle:@"Rec" action:@selector(toggleRecord)];
    _recordButton.frame = CGRectMake(8, 8, 48, 38);
    [_panelView addSubview:_recordButton];

    _playButton = [self buttonWithTitle:@"Play" action:@selector(playRecording)];
    _playButton.frame = CGRectMake(62, 8, 54, 38);
    [_panelView addSubview:_playButton];

    _visionButton = [self buttonWithTitle:@"CV" action:@selector(runVisionTap)];
    _visionButton.frame = CGRectMake(122, 8, 42, 38);
    [_panelView addSubview:_visionButton];

    _templateButton = [self buttonWithTitle:@"Tpl" action:@selector(beginTemplateCapture)];
    _templateButton.frame = CGRectMake(170, 8, 42, 38);
    [_panelView addSubview:_templateButton];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(218, 8, 54, 38)];
    _statusLabel.text = @"Idle";
    _statusLabel.textColor = UIColor.whiteColor;
    _statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _statusLabel.adjustsFontSizeToFitWidth = YES;
    _statusLabel.minimumScaleFactor = 0.65;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [_panelView addSubview:_statusLabel];

    [_panelWindow makeKeyAndVisible];
    NSLog(@"[AnClick] Panel shown");
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
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

- (void)toggleRecord {
    AnClickRecorder *recorder = [AnClickRecorder shared];
    if (recorder.isRecording) {
        _lastRecording = [recorder stopRecording];
        _statusLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)_lastRecording.count];
        [_recordButton setTitle:@"Rec" forState:UIControlStateNormal];
        _recordButton.backgroundColor = [UIColor colorWithRed:0.10 green:0.34 blue:0.56 alpha:1.0];
    } else {
        [recorder startRecording];
        _lastRecording = nil;
        _statusLabel.text = @"Live";
        [_recordButton setTitle:@"Stop" forState:UIControlStateNormal];
        _recordButton.backgroundColor = [UIColor colorWithRed:0.62 green:0.12 blue:0.16 alpha:1.0];
    }
}

- (void)playRecording {
    NSArray<AnClickRecordEvent *> *events = _lastRecording ?: [[AnClickRecorder shared] events];
    if (events.count == 0) {
        _statusLabel.text = @"Empty";
        return;
    }

    _statusLabel.text = @"Run";
    for (AnClickRecordEvent *event in events) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(event.timestamp * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSInteger touchId = 7;
            if (event.type == 0) {
                [AnClickFakeTouch touchDownAtPoint:event.point touchId:touchId];
            } else if (event.type == 1) {
                [AnClickFakeTouch touchMoveAtPoint:event.point touchId:touchId];
            } else {
                [AnClickFakeTouch touchUpAtPoint:event.point touchId:touchId];
            }
        });
    }

    AnClickRecordEvent *lastEvent = events.lastObject;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((lastEvent.timestamp + 0.2) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self->_statusLabel.text = @"Idle";
    });
}

- (void)runVisionTap {
    NSString *path = [self templatePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        path = [NSBundle.mainBundle pathForResource:@"anclick_template" ofType:@"png"];
    }
    UIImage *templateImage = path ? [UIImage imageWithContentsOfFile:path] : nil;
    if (!templateImage) {
        _statusLabel.text = @"NoTpl";
        return;
    }

    _statusLabel.text = @"Scan";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL tapped = [AnClickCore findAndTapTemplateImage:templateImage threshold:0.86];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_statusLabel.text = tapped ? @"Tap" : @"Miss";
        });
    });
}

- (NSString *)templatePath {
    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[documentsURL path] stringByAppendingPathComponent:@"anclick_template.png"];
}

- (UIWindow *)hostWindow {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self activeWindowScene];
        for (UIWindow *window in scene.windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
        return scene.windows.firstObject;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
#pragma clang diagnostic pop
}

- (void)beginTemplateCapture {
    UIWindow *hostWindow = [self hostWindow];
    if (!hostWindow) {
        _statusLabel.text = @"NoWin";
        return;
    }

    _statusLabel.text = @"Pick";
    UIView *overlay = [[UIView alloc] initWithFrame:hostWindow.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    overlay.userInteractionEnabled = YES;
    overlay.accessibilityIdentifier = @"AnClickTemplateOverlay";

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 80, hostWindow.bounds.size.width - 32, 44)];
    label.text = @"Tap target";
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    [overlay addSubview:label];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTemplateTap:)];
    [overlay addGestureRecognizer:tap];
    [hostWindow addSubview:overlay];
}

- (void)handleTemplateTap:(UITapGestureRecognizer *)recognizer {
    UIView *overlay = recognizer.view;
    UIWindow *hostWindow = (UIWindow *)overlay.window;
    CGPoint point = [recognizer locationInView:hostWindow];

    overlay.hidden = YES;
    _panelWindow.hidden = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *screen = [AnClickCore captureCurrentWindowImage];
        self->_panelWindow.hidden = NO;
        [overlay removeFromSuperview];

        if (!screen.CGImage) {
            self->_statusLabel.text = @"NoImg";
            return;
        }

        CGFloat scale = screen.scale;
        CGFloat templateSide = 100.0;
        CGRect pointRect = CGRectMake((point.x - templateSide * 0.5) * scale,
                                      (point.y - templateSide * 0.5) * scale,
                                      templateSide * scale,
                                      templateSide * scale);
        CGRect imageBounds = CGRectMake(0, 0, CGImageGetWidth(screen.CGImage), CGImageGetHeight(screen.CGImage));
        CGRect cropRect = CGRectIntersection(pointRect, imageBounds);
        if (CGRectIsEmpty(cropRect)) {
            self->_statusLabel.text = @"BadTpl";
            return;
        }

        CGImageRef croppedRef = CGImageCreateWithImageInRect(screen.CGImage, cropRect);
        if (!croppedRef) {
            self->_statusLabel.text = @"BadTpl";
            return;
        }

        UIImage *templateImage = [UIImage imageWithCGImage:croppedRef scale:scale orientation:screen.imageOrientation];
        CGImageRelease(croppedRef);
        NSData *pngData = UIImagePNGRepresentation(templateImage);
        BOOL saved = [pngData writeToFile:[self templatePath] atomically:YES];
        self->_statusLabel.text = saved ? @"TplOK" : @"TplErr";
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
