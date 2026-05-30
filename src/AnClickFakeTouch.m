#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../include/PTFakeTouch.h"

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
+ (void)doubleTapAtPoint:(CGPoint)point;
+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration;
+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end;
+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end duration:(NSTimeInterval)duration steps:(NSUInteger)steps;
+ (void)playPath:(NSArray<NSValue *> *)points duration:(NSTimeInterval)duration;
+ (void)touchDownAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchMoveAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchUpAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
@end

@implementation AnClickFakeTouch

+ (void)tapAtPoint:(CGPoint)point {
    NSInteger touchId = 1;
    [self touchDownAtPoint:point touchId:touchId];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self touchMoveAtPoint:point touchId:touchId];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.14 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self touchUpAtPoint:point touchId:touchId];
        [self triggerUIKitControlAtPoint:point];
    });
}

+ (void)doubleTapAtPoint:(CGPoint)point {
    [self tapAtPoint:point];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.22 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self tapAtPoint:point];
    });
}

+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration {
    NSInteger touchId = 3;
    NSTimeInterval holdDuration = MAX(duration, 0.35);
    [self touchDownAtPoint:point touchId:touchId];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self touchMoveAtPoint:point touchId:touchId];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(holdDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self touchUpAtPoint:point touchId:touchId];
    });
}

+ (UIWindow *)activeApplicationWindow {
    UIWindow *fallback = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.windowLevel >= UIWindowLevelAlert || window.hidden || window.alpha <= 0.01) {
                    continue;
                }
                if (window.isKeyWindow) {
                    return window;
                }
                if (!fallback) {
                    fallback = window;
                }
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (UIApplication.sharedApplication.keyWindow && UIApplication.sharedApplication.keyWindow.windowLevel < UIWindowLevelAlert) {
        return UIApplication.sharedApplication.keyWindow;
    }
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.windowLevel < UIWindowLevelAlert && !window.hidden && window.alpha > 0.01) {
            return window;
        }
    }
#pragma clang diagnostic pop
    return fallback;
}

+ (void)triggerUIKitControlAtPoint:(CGPoint)point {
    UIWindow *window = [self activeApplicationWindow];
    CGPoint windowPoint = [window convertPoint:point fromWindow:nil];
    UIView *view = [window hitTest:windowPoint withEvent:nil];
    UIControl *control = nil;
    for (UIView *current = view; current; current = current.superview) {
        if ([current isKindOfClass:UIControl.class]) {
            control = (UIControl *)current;
            break;
        }
    }

    if (!control || !control.enabled || control.hidden || control.alpha <= 0.01) {
        NSLog(@"[AnClick] UIKit fallback missed screen=(%.1f, %.1f) window=(%.1f, %.1f) view=%@",
              point.x,
              point.y,
              windowPoint.x,
              windowPoint.y,
              view);
        return;
    }

    [control sendActionsForControlEvents:UIControlEventTouchDown];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        NSLog(@"[AnClick] UIKit fallback tapped %@ screen=(%.1f, %.1f) window=(%.1f, %.1f)",
              control,
              point.x,
              point.y,
              windowPoint.x,
              windowPoint.y);
    });
}

+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end {
    [self swipeFrom:start to:end duration:0.45 steps:18];
}

+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end duration:(NSTimeInterval)duration steps:(NSUInteger)steps {
    NSUInteger safeSteps = MAX(steps, 2);
    NSInteger touchId = 2;
    NSTimeInterval stepDuration = duration / (NSTimeInterval)safeSteps;

    [self touchDownAtPoint:start touchId:touchId];
    for (NSUInteger i = 1; i < safeSteps; i++) {
        CGFloat progress = (CGFloat)i / (CGFloat)safeSteps;
        CGPoint point = CGPointMake(start.x + (end.x - start.x) * progress,
                                    start.y + (end.y - start.y) * progress);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(stepDuration * i * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self touchMoveAtPoint:point touchId:touchId];
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self touchUpAtPoint:end touchId:touchId];
    });
}

+ (void)playPath:(NSArray<NSValue *> *)points duration:(NSTimeInterval)duration {
    if (points.count < 2) {
        return;
    }

    NSInteger touchId = 4;
    NSTimeInterval safeDuration = MAX(duration, 0.16);
    NSUInteger lastIndex = points.count - 1;
    [self touchDownAtPoint:points.firstObject.CGPointValue touchId:touchId];

    for (NSUInteger i = 1; i < lastIndex; i++) {
        NSTimeInterval delay = safeDuration * ((NSTimeInterval)i / (NSTimeInterval)lastIndex);
        CGPoint point = points[i].CGPointValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self touchMoveAtPoint:point touchId:touchId];
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(safeDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self touchUpAtPoint:points.lastObject.CGPointValue touchId:touchId];
    });
}

+ (void)touchDownAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [PTFakeTouch fakeTouchId:touchId AtPoint:point WithType:PTFakeTouchEventTouchDown];
}

+ (void)touchMoveAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [PTFakeTouch fakeTouchId:touchId AtPoint:point WithType:PTFakeTouchEventTouchMove];
}

+ (void)touchUpAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [PTFakeTouch fakeTouchId:touchId AtPoint:point WithType:PTFakeTouchEventTouchUp];
}

@end
