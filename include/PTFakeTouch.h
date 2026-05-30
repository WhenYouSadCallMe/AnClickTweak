#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PTFakeTouchEvent) {
    PTFakeTouchEventTouchDown = 0,
    PTFakeTouchEventTouchUp = 1,
    PTFakeTouchEventTouchMove = 2,
    PTFakeTouchEventTouchCancel = 3,
};

@interface PTFakeTouch : NSObject

+ (void)fakeTouchId:(NSInteger)touchId AtPoint:(CGPoint)point WithType:(PTFakeTouchEvent)type;
+ (void)setUseScreenScale:(BOOL)useScreenScale;
+ (void)setUseEventSystemClientScheduling:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
