#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ANSystemTouch : NSObject

+ (BOOL)systemTouchAvailable;
+ (void)tapAtPoint:(CGPoint)point;
+ (void)doubleTapAtPoint:(CGPoint)point;
+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration;
+ (void)playPath:(NSArray<NSValue *> *)points duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END
