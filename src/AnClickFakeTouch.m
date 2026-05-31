#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "../include/PTFakeTouch.h"

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
+ (void)doubleTapAtPoint:(CGPoint)point;
+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration;
+ (void)beginHoldAtPoint:(CGPoint)point;
+ (void)endHold;
+ (void)cancelHold;
+ (BOOL)isHolding;
+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end;
+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end duration:(NSTimeInterval)duration steps:(NSUInteger)steps;
+ (void)playPath:(NSArray<NSValue *> *)points duration:(NSTimeInterval)duration;
+ (void)playRecordedEvents:(NSArray<NSDictionary *> *)events;
+ (void)touchDownAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchMoveAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchStationaryAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchCancelAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchUpAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
@end

@implementation AnClickFakeTouch

static NSInteger AnClickHoldTouchId = 8;
static BOOL AnClickHolding = NO;
static CGPoint AnClickHoldPoint = {0, 0};
static dispatch_source_t AnClickHoldTimer = nil;
static NSUInteger AnClickHoldGeneration = 0;

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
    NSTimeInterval holdDuration = MAX(duration, 5.0);
    [self beginHoldAtPoint:point];
    NSUInteger generation = AnClickHoldGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(holdDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (AnClickHolding && generation == AnClickHoldGeneration) {
            [self cancelHold];
        }
    });
}

+ (void)beginHoldAtPoint:(CGPoint)point {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self beginHoldAtPoint:point];
        });
        return;
    }

    if (AnClickHolding) {
        [self cancelHold];
    }

    AnClickHolding = YES;
    AnClickHoldPoint = point;
    AnClickHoldGeneration++;
    [self touchDownAtPoint:point touchId:AnClickHoldTouchId];

    __block NSUInteger tick = 0;
    AnClickHoldTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(AnClickHoldTimer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                              (uint64_t)(0.06 * NSEC_PER_SEC),
                              (uint64_t)(0.01 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(AnClickHoldTimer, ^{
        if (!AnClickHolding) {
            return;
        }
        tick++;
        if (tick % 8 == 0) {
            [self touchMoveAtPoint:AnClickHoldPoint touchId:AnClickHoldTouchId];
        } else {
            [self touchStationaryAtPoint:AnClickHoldPoint touchId:AnClickHoldTouchId];
        }
    });
    dispatch_resume(AnClickHoldTimer);
}

+ (void)endHold {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self endHold];
        });
        return;
    }

    if (!AnClickHolding) {
        return;
    }

    if (AnClickHoldTimer) {
        dispatch_source_cancel(AnClickHoldTimer);
        AnClickHoldTimer = nil;
    }
    [self touchUpAtPoint:AnClickHoldPoint touchId:AnClickHoldTouchId];
    AnClickHolding = NO;
}

+ (void)cancelHold {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self cancelHold];
        });
        return;
    }

    if (!AnClickHolding) {
        return;
    }

    if (AnClickHoldTimer) {
        dispatch_source_cancel(AnClickHoldTimer);
        AnClickHoldTimer = nil;
    }
    [self touchCancelAtPoint:AnClickHoldPoint touchId:AnClickHoldTouchId];
    AnClickHolding = NO;
}

+ (BOOL)isHolding {
    return AnClickHolding;
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

+ (void)playRecordedEvents:(NSArray<NSDictionary *> *)events {
    if (events.count == 0) {
        return;
    }

    NSInteger touchId = 6;
    __block BOOL sawEnded = NO;
    __block CGPoint lastPoint = CGPointZero;
    __block NSTimeInterval lastTimestamp = 0;

    for (NSDictionary *event in events) {
        NSNumber *typeNumber = event[@"type"];
        NSNumber *xNumber = event[@"x"];
        NSNumber *yNumber = event[@"y"];
        NSNumber *timestampNumber = event[@"timestamp"];
        if (!typeNumber || !xNumber || !yNumber || !timestampNumber) {
            continue;
        }

        NSInteger type = typeNumber.integerValue;
        CGPoint point = CGPointMake(xNumber.doubleValue, yNumber.doubleValue);
        NSTimeInterval timestamp = MAX(0, timestampNumber.doubleValue);
        lastPoint = point;
        lastTimestamp = MAX(lastTimestamp, timestamp);
        if (type == 2 || type == 3) {
            sawEnded = YES;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timestamp * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (type == 0) {
                [self touchDownAtPoint:point touchId:touchId];
            } else if (type == 1) {
                [self touchMoveAtPoint:point touchId:touchId];
            } else {
                [self touchUpAtPoint:point touchId:touchId];
            }
        });
    }

    if (!sawEnded) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((lastTimestamp + 0.08) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self touchUpAtPoint:lastPoint touchId:touchId];
        });
    }
}

+ (void)touchDownAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [PTFakeTouch fakeTouchId:touchId AtPoint:point WithType:PTFakeTouchEventTouchDown];
}

+ (void)touchMoveAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [PTFakeTouch fakeTouchId:touchId AtPoint:point WithType:PTFakeTouchEventTouchMove];
}

+ (void)touchStationaryAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [PTFakeTouch fakeTouchId:touchId AtPoint:point WithType:PTFakeTouchEventTouchStationary];
}

+ (void)touchCancelAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [PTFakeTouch fakeTouchId:touchId AtPoint:point WithType:PTFakeTouchEventTouchCancel];
}

+ (void)touchUpAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [PTFakeTouch fakeTouchId:touchId AtPoint:point WithType:PTFakeTouchEventTouchUp];
}

@end
