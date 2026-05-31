#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PTFakeTouchEvent) {
    PTFakeTouchEventTouchDown = 0,
    PTFakeTouchEventTouchUp = 1,
    PTFakeTouchEventTouchMove = 2,
    PTFakeTouchEventTouchCancel = 3,
    PTFakeTouchEventTouchStationary = 4,
};

@interface PTFakeTouch : NSObject

+ (NSInteger)getAvailablePointId;
+ (NSInteger)fakeTouchId:(NSInteger)pointId AtPoint:(CGPoint)point withTouchPhase:(UITouchPhase)phase;

// Compatibility wrapper used by the tweak code.
+ (NSInteger)fakeTouchId:(NSInteger)touchId AtPoint:(CGPoint)point WithType:(PTFakeTouchEvent)type;

@end
