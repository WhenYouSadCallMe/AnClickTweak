#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, AnClickHammerTouchPhase) {
    AnClickHammerTouchPhaseBegan = 0,
    AnClickHammerTouchPhaseMoved = 1,
    AnClickHammerTouchPhaseEnded = 2,
    AnClickHammerTouchPhaseCancelled = 3,
    AnClickHammerTouchPhaseStationary = 4,
};

@interface AnClickHammerTouch : NSObject

+ (NSInteger)availableTouchId;
+ (void)cancelAllActiveTouches;
+ (NSInteger)sendTouchId:(NSInteger)touchId atPoint:(CGPoint)point phase:(AnClickHammerTouchPhase)phase;
+ (NSInteger)sendTouchId:(NSInteger)touchId
                 atPoint:(CGPoint)point
                   phase:(AnClickHammerTouchPhase)phase
            targetWindow:(UIWindow *)targetWindow;
+ (void)sendTouchIds:(NSArray<NSNumber *> *)touchIds
              points:(NSArray<NSValue *> *)points
              phases:(NSArray<NSNumber *> *)phases;
+ (void)sendTouchIds:(NSArray<NSNumber *> *)touchIds
              points:(NSArray<NSValue *> *)points
              phases:(NSArray<NSNumber *> *)phases
        targetWindow:(UIWindow *)targetWindow;

@end
