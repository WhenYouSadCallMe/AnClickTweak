#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PTFakeTouch.h"

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end;
+ (void)swipeFrom:(CGPoint)start to:(CGPoint)end duration:(NSTimeInterval)duration steps:(NSUInteger)steps;
+ (void)touchDownAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchMoveAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
+ (void)touchUpAtPoint:(CGPoint)point touchId:(NSInteger)touchId;
@end

@implementation AnClickFakeTouch

+ (void)tapAtPoint:(CGPoint)point {
    NSInteger touchId = 1;
    [self touchDownAtPoint:point touchId:touchId];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self touchUpAtPoint:point touchId:touchId];
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
