#import "ANSystemTouch.h"

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
@end

@implementation AnClickFakeTouch

+ (void)tapAtPoint:(CGPoint)point {
    [ANSystemTouch tapAtPoint:point];
}

@end
