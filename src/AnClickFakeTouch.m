#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "../include/HammerTouch.h"

#if ANCLICK_RELEASE_SILENT
#undef NSLog
#define NSLog(...) do {} while (0)
#endif

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
+ (void)doubleTapAtPoint:(CGPoint)point;
+ (void)multiTapAtPoints:(NSArray<NSValue *> *)points;
+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration;
+ (void)beginHoldAtPoint:(CGPoint)point;
+ (void)endHold;
+ (void)cancelHold;
+ (BOOL)isHolding;
+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end;
+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end duration:(NSTimeInterval)duration steps:(NSUInteger)steps;
+ (void)playPath:(NSArray<NSValue *> *)points duration:(NSTimeInterval)duration;
+ (void)playRecordedEvents:(NSArray<NSDictionary *> *)events;
+ (void)twoFingerTapAtPoint:(CGPoint)point distance:(CGFloat)distance;
+ (void)pinchAtPoint:(CGPoint)center fromDistance:(CGFloat)fromDistance toDistance:(CGFloat)toDistance duration:(NSTimeInterval)duration;
+ (void)rotateAtPoint:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle duration:(NSTimeInterval)duration;
+ (void)touchDownAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchMoveAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchStationaryAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchCancelAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchUpAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
@end

@implementation AnClickFakeTouch

static NSInteger AnClickHoldTouchId = 0;
static BOOL AnClickHolding = NO;
static CGPoint AnClickHoldPoint = {0, 0};
static dispatch_source_t AnClickHoldTimer = nil;
static NSUInteger AnClickHoldGeneration = 0;
static const NSTimeInterval AnClickHoldTickInterval = 1.0 / 60.0;
static const NSTimeInterval AnClickTouchUpDelay = 1.0 / 120.0;
static const NSTimeInterval AnClickFastTapMoveDelay = 0.005;
static const NSTimeInterval AnClickFastTapUpDelay = 0.025;
static const NSTimeInterval AnClickFastDoubleTapDelay = 0.055;
static const NSTimeInterval AnClickRecordedKeepAliveInterval = 1.0 / 30.0;
static const NSTimeInterval AnClickRecordedMoveMinInterval = 1.0 / 90.0;
static const NSTimeInterval AnClickRecordedPlaybackMaxDuration = 600.0;
static const NSUInteger AnClickRecordedPlaybackMaxEvents = 24000;
static const NSUInteger AnClickRecordedPlaybackMaxScheduledBlocks = 30000;
static const NSUInteger AnClickMultiTapMaxPoints = 32;

+ (void)tapAtPoint:(CGPoint)point {
    NSInteger touchId = 1;
    [self touchDownAtPoint:point touchId:touchId];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(AnClickFastTapMoveDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self touchMoveAtPoint:point touchId:touchId];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(AnClickFastTapUpDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self touchUpAtPoint:point touchId:touchId];
        [self triggerUIKitControlAtPoint:point];
    });
}

+ (void)doubleTapAtPoint:(CGPoint)point {
    [self tapAtPoint:point];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(AnClickFastDoubleTapDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self tapAtPoint:point];
    });
}

+ (void)multiTapAtPoints:(NSArray<NSValue *> *)points {
    if (points.count == 0) {
        return;
    }

    NSUInteger maxCount = MIN(points.count, AnClickMultiTapMaxPoints);
    NSMutableArray<NSNumber *> *touchIds = [NSMutableArray arrayWithCapacity:maxCount];
    NSMutableArray<NSValue *> *touchPoints = [NSMutableArray arrayWithCapacity:maxCount];
    NSMutableArray<NSNumber *> *beganPhases = [NSMutableArray arrayWithCapacity:maxCount];
    NSMutableArray<NSNumber *> *movePhases = [NSMutableArray arrayWithCapacity:maxCount];
    NSMutableArray<NSNumber *> *endedPhases = [NSMutableArray arrayWithCapacity:maxCount];
    for (NSUInteger i = 0; i < maxCount; i++) {
        NSValue *value = points[i];
        if (![value isKindOfClass:NSValue.class]) {
            continue;
        }
        [touchIds addObject:@(30 + (NSInteger)i)];
        [touchPoints addObject:value];
        [beganPhases addObject:@(AnClickHammerTouchPhaseBegan)];
        [movePhases addObject:@(AnClickHammerTouchPhaseMoved)];
        [endedPhases addObject:@(AnClickHammerTouchPhaseEnded)];
    }
    if (touchPoints.count == 0) {
        return;
    }

    [AnClickHammerTouch sendTouchIds:touchIds points:touchPoints phases:beganPhases];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(AnClickFastTapMoveDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [AnClickHammerTouch sendTouchIds:touchIds points:touchPoints phases:movePhases];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(AnClickFastTapUpDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [AnClickHammerTouch sendTouchIds:touchIds points:touchPoints phases:endedPhases];
        for (NSValue *value in touchPoints) {
            [self triggerUIKitControlAtPoint:value.CGPointValue];
        }
    });
}

+ (void)finishTouchId:(NSInteger)touchId atPoint:(CGPoint)point cancelled:(BOOL)cancelled {
    [self touchMoveAtPoint:point touchId:touchId];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(AnClickTouchUpDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (cancelled) {
            [self touchCancelAtPoint:point touchId:touchId];
        } else {
            [self touchUpAtPoint:point touchId:touchId];
        }
    });
}

+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration {
    NSTimeInterval holdDuration = MAX(duration, 2.5);
    [self beginHoldAtPoint:point];
    NSUInteger generation = AnClickHoldGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(holdDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (AnClickHolding && generation == AnClickHoldGeneration) {
            [self endHold];
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
    [AnClickHammerTouch cancelAllActiveTouches];

    AnClickHolding = YES;
    AnClickHoldPoint = point;
    AnClickHoldTouchId = [AnClickHammerTouch availableTouchId];
    if (AnClickHoldTouchId <= 0) {
        AnClickHoldTouchId = 8;
    }
    AnClickHoldGeneration++;
    NSUInteger generation = AnClickHoldGeneration;
    NSInteger touchId = AnClickHoldTouchId;
    CGPoint holdPoint = AnClickHoldPoint;
    [self touchDownAtPoint:point touchId:touchId];

    AnClickHoldTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(AnClickHoldTimer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(AnClickHoldTickInterval * NSEC_PER_SEC)),
                              (uint64_t)(AnClickHoldTickInterval * NSEC_PER_SEC),
                              (uint64_t)(0.002 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(AnClickHoldTimer, ^{
        if (!AnClickHolding || generation != AnClickHoldGeneration) {
            return;
        }
        [self touchMoveAtPoint:holdPoint touchId:touchId];
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
    CGPoint point = AnClickHoldPoint;
    NSInteger touchId = AnClickHoldTouchId;
    AnClickHolding = NO;
    AnClickHoldGeneration++;
    [self finishTouchId:touchId atPoint:point cancelled:NO];
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
    CGPoint point = AnClickHoldPoint;
    NSInteger touchId = AnClickHoldTouchId;
    AnClickHolding = NO;
    AnClickHoldGeneration++;
    [self finishTouchId:touchId atPoint:point cancelled:YES];
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(AnClickTouchUpDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
        [self finishTouchId:touchId atPoint:end cancelled:NO];
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
        [self finishTouchId:touchId atPoint:points.lastObject.CGPointValue cancelled:NO];
    });
}

+ (NSArray<NSValue *> *)twoFingerPointsAtCenter:(CGPoint)center distance:(CGFloat)distance angle:(CGFloat)angle {
    CGFloat halfDistance = distance * 0.5;
    CGFloat dx = cos(angle) * halfDistance;
    CGFloat dy = sin(angle) * halfDistance;
    return @[
        [NSValue valueWithCGPoint:CGPointMake(center.x - dx, center.y - dy)],
        [NSValue valueWithCGPoint:CGPointMake(center.x + dx, center.y + dy)],
    ];
}

+ (void)sendTwoFingerPoints:(NSArray<NSValue *> *)points phase:(AnClickHammerTouchPhase)phase {
    [AnClickHammerTouch sendTouchIds:@[@20, @21]
                              points:points
                              phases:@[@(phase), @(phase)]];
}

+ (void)twoFingerTapAtPoint:(CGPoint)point distance:(CGFloat)distance {
    NSArray<NSValue *> *points = [self twoFingerPointsAtCenter:point distance:MAX(distance, 24.0) angle:0];
    [self sendTwoFingerPoints:points phase:AnClickHammerTouchPhaseBegan];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(AnClickFastTapUpDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self sendTwoFingerPoints:points phase:AnClickHammerTouchPhaseEnded];
    });
}

+ (void)pinchAtPoint:(CGPoint)center fromDistance:(CGFloat)fromDistance toDistance:(CGFloat)toDistance duration:(NSTimeInterval)duration {
    NSInteger touchIdA = 22;
    NSInteger touchIdB = 23;
    NSUInteger steps = 18;
    NSTimeInterval safeDuration = MAX(duration, 0.18);
    NSTimeInterval stepDuration = safeDuration / (NSTimeInterval)steps;
    NSArray<NSValue *> *startPoints = [self twoFingerPointsAtCenter:center distance:MAX(fromDistance, 10.0) angle:0];
    [AnClickHammerTouch sendTouchIds:@[@(touchIdA), @(touchIdB)]
                              points:startPoints
                              phases:@[@(AnClickHammerTouchPhaseBegan), @(AnClickHammerTouchPhaseBegan)]];

    for (NSUInteger i = 1; i <= steps; i++) {
        CGFloat progress = (CGFloat)i / (CGFloat)steps;
        CGFloat distance = fromDistance + (toDistance - fromDistance) * progress;
        NSArray<NSValue *> *points = [self twoFingerPointsAtCenter:center distance:MAX(distance, 8.0) angle:0];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(stepDuration * i * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [AnClickHammerTouch sendTouchIds:@[@(touchIdA), @(touchIdB)]
                                      points:points
                                      phases:@[@(AnClickHammerTouchPhaseMoved), @(AnClickHammerTouchPhaseMoved)]];
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((safeDuration + AnClickTouchUpDelay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSArray<NSValue *> *endPoints = [self twoFingerPointsAtCenter:center distance:MAX(toDistance, 8.0) angle:0];
        [AnClickHammerTouch sendTouchIds:@[@(touchIdA), @(touchIdB)]
                                  points:endPoints
                                  phases:@[@(AnClickHammerTouchPhaseEnded), @(AnClickHammerTouchPhaseEnded)]];
    });
}

+ (void)rotateAtPoint:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle duration:(NSTimeInterval)duration {
    NSInteger touchIdA = 24;
    NSInteger touchIdB = 25;
    NSUInteger steps = 24;
    NSTimeInterval safeDuration = MAX(duration, 0.24);
    NSTimeInterval stepDuration = safeDuration / (NSTimeInterval)steps;
    CGFloat distance = MAX(radius * 2.0, 24.0);
    NSArray<NSValue *> *startPoints = [self twoFingerPointsAtCenter:center distance:distance angle:startAngle];
    [AnClickHammerTouch sendTouchIds:@[@(touchIdA), @(touchIdB)]
                              points:startPoints
                              phases:@[@(AnClickHammerTouchPhaseBegan), @(AnClickHammerTouchPhaseBegan)]];

    for (NSUInteger i = 1; i <= steps; i++) {
        CGFloat progress = (CGFloat)i / (CGFloat)steps;
        CGFloat angle = startAngle + (endAngle - startAngle) * progress;
        NSArray<NSValue *> *points = [self twoFingerPointsAtCenter:center distance:distance angle:angle];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(stepDuration * i * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [AnClickHammerTouch sendTouchIds:@[@(touchIdA), @(touchIdB)]
                                      points:points
                                      phases:@[@(AnClickHammerTouchPhaseMoved), @(AnClickHammerTouchPhaseMoved)]];
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((safeDuration + AnClickTouchUpDelay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSArray<NSValue *> *endPoints = [self twoFingerPointsAtCenter:center distance:distance angle:endAngle];
        [AnClickHammerTouch sendTouchIds:@[@(touchIdA), @(touchIdB)]
                                  points:endPoints
                                  phases:@[@(AnClickHammerTouchPhaseEnded), @(AnClickHammerTouchPhaseEnded)]];
    });
}

+ (void)playRecordedEvents:(NSArray<NSDictionary *> *)events {
    if (events.count == 0) {
        return;
    }

    NSInteger touchId = 6;
    BOOL touchIsDown = NO;
    NSTimeInterval previousTimestamp = 0;
    CGPoint previousPoint = CGPointZero;
    NSInteger previousType = -1;
    NSUInteger processedEvents = 0;
    NSUInteger scheduledBlocks = 0;
    BOOL hasScheduledMove = NO;
    NSTimeInterval lastScheduledMoveTimestamp = 0;
    CGPoint lastScheduledMovePoint = CGPointZero;

    for (NSDictionary *event in events) {
        if (processedEvents >= AnClickRecordedPlaybackMaxEvents) {
            break;
        }
        processedEvents++;

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
        if (timestamp > AnClickRecordedPlaybackMaxDuration) {
            break;
        }

        if (touchIsDown && timestamp > previousTimestamp + AnClickRecordedKeepAliveInterval) {
            for (NSTimeInterval tick = previousTimestamp + AnClickRecordedKeepAliveInterval;
                 tick < timestamp - 0.001 && scheduledBlocks < AnClickRecordedPlaybackMaxScheduledBlocks;
                 tick += AnClickRecordedKeepAliveInterval) {
                CGPoint keepAlivePoint = previousPoint;
                NSInteger keepAliveTouchId = touchId;
                scheduledBlocks++;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(tick * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self touchMoveAtPoint:keepAlivePoint touchId:keepAliveTouchId];
                });
            }
        }

        BOOL shouldScheduleEvent = YES;
        if (type == 1 && hasScheduledMove) {
            CGFloat dx = point.x - lastScheduledMovePoint.x;
            CGFloat dy = point.y - lastScheduledMovePoint.y;
            shouldScheduleEvent = timestamp - lastScheduledMoveTimestamp >= AnClickRecordedMoveMinInterval ||
                hypot(dx, dy) >= 0.75;
        }
        if (type == 1 && scheduledBlocks >= AnClickRecordedPlaybackMaxScheduledBlocks) {
            shouldScheduleEvent = NO;
        }

        if (shouldScheduleEvent) {
            NSInteger eventType = type;
            CGPoint eventPoint = point;
            NSInteger eventTouchId = touchId;
            scheduledBlocks++;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timestamp * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (eventType == 0) {
                    [self touchDownAtPoint:eventPoint touchId:eventTouchId];
                } else if (eventType == 1) {
                    [self touchMoveAtPoint:eventPoint touchId:eventTouchId];
                } else if (eventType == 3) {
                    [self finishTouchId:eventTouchId atPoint:eventPoint cancelled:YES];
                } else {
                    [self finishTouchId:eventTouchId atPoint:eventPoint cancelled:NO];
                }
            });
            if (type == 1) {
                hasScheduledMove = YES;
                lastScheduledMoveTimestamp = timestamp;
                lastScheduledMovePoint = point;
            }
        }

        touchIsDown = (type == 0 || type == 1);
        previousTimestamp = timestamp;
        previousPoint = point;
        previousType = type;
    }

    if (previousType == 0 || previousType == 1) {
        NSTimeInterval cancelTimestamp = MIN(previousTimestamp + 0.08, AnClickRecordedPlaybackMaxDuration);
        NSInteger cancelTouchId = touchId;
        CGPoint cancelPoint = previousPoint;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cancelTimestamp * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self finishTouchId:cancelTouchId atPoint:cancelPoint cancelled:YES];
        });
    }
}

+ (void)touchDownAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [AnClickHammerTouch sendTouchId:touchId atPoint:point phase:AnClickHammerTouchPhaseBegan];
}

+ (void)touchMoveAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [AnClickHammerTouch sendTouchId:touchId atPoint:point phase:AnClickHammerTouchPhaseMoved];
}

+ (void)touchStationaryAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [AnClickHammerTouch sendTouchId:touchId atPoint:point phase:AnClickHammerTouchPhaseStationary];
}

+ (void)touchCancelAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [AnClickHammerTouch sendTouchId:touchId atPoint:point phase:AnClickHammerTouchPhaseCancelled];
}

+ (void)touchUpAtPoint:(CGPoint)point touchId:(NSInteger)touchId {
    [AnClickHammerTouch sendTouchId:touchId atPoint:point phase:AnClickHammerTouchPhaseEnded];
}

@end
