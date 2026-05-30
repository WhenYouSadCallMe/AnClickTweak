#import "../include/PTFakeTouch.h"
#import <mach/mach_time.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __GSEvent *GSEventRef;

#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

typedef uint32_t IOHIDDigitizerTransducerType;
typedef uint32_t IOHIDEventField;
typedef uint32_t IOHIDEventType;
typedef uint32_t IOOptionBits;

static IOHIDEventRef AnClickIOHIDEventWithTouches(NSArray<UITouch *> *touches) CF_RETURNS_RETAINED;

extern IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef allocator,
                                                    uint64_t timeStamp,
                                                    IOHIDDigitizerTransducerType type,
                                                    uint32_t index,
                                                    uint32_t identity,
                                                    uint32_t eventMask,
                                                    uint32_t buttonMask,
                                                    IOHIDFloat x,
                                                    IOHIDFloat y,
                                                    IOHIDFloat z,
                                                    IOHIDFloat tipPressure,
                                                    IOHIDFloat barrelPressure,
                                                    Boolean range,
                                                    Boolean touch,
                                                    IOOptionBits options);
extern IOHIDEventRef IOHIDEventCreateDigitizerFingerEventWithQuality(CFAllocatorRef allocator,
                                                                     uint64_t timeStamp,
                                                                     uint32_t index,
                                                                     uint32_t identity,
                                                                     uint32_t eventMask,
                                                                     IOHIDFloat x,
                                                                     IOHIDFloat y,
                                                                     IOHIDFloat z,
                                                                     IOHIDFloat tipPressure,
                                                                     IOHIDFloat twist,
                                                                     IOHIDFloat minorRadius,
                                                                     IOHIDFloat majorRadius,
                                                                     IOHIDFloat quality,
                                                                     IOHIDFloat density,
                                                                     IOHIDFloat irregularity,
                                                                     Boolean range,
                                                                     Boolean touch,
                                                                     IOOptionBits options);
extern void IOHIDEventAppendEvent(IOHIDEventRef event, IOHIDEventRef childEvent, IOOptionBits options);
extern void IOHIDEventSetIntegerValue(IOHIDEventRef event, IOHIDEventField field, int value);
extern void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t sender);

enum {
    kIOHIDDigitizerTransducerTypeFinger = 2,
    kIOHIDDigitizerTransducerTypeHand = 3,
};

enum {
    kIOHIDEventTypeDigitizer = 11,
};

#define IOHIDEventFieldBase(type) ((type) << 16)

enum {
    kIOHIDDigitizerEventRange = 0x00000001,
    kIOHIDDigitizerEventTouch = 0x00000002,
    kIOHIDDigitizerEventPosition = 0x00000004,
};

enum {
    kIOHIDEventFieldDigitizerIsDisplayIntegrated = IOHIDEventFieldBase(kIOHIDEventTypeDigitizer) + 24,
};

@interface UITouch ()
- (void)setWindow:(UIWindow *)window;
- (void)setView:(UIView *)view;
- (void)setIsTap:(BOOL)isTap;
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)setPhase:(UITouchPhase)touchPhase;
- (void)setGestureView:(UIView *)view;
- (void)_setLocationInWindow:(CGPoint)location resetPrevious:(BOOL)resetPrevious;
- (void)_setIsFirstTouchForView:(BOOL)firstTouchForView;
- (void)_setIsTapToClick:(BOOL)isTapToClick;
- (void)_setHidEvent:(IOHIDEventRef)event;
@end

@interface UIEvent ()
- (void)_addTouch:(UITouch *)touch forDelayedDelivery:(BOOL)delayed;
- (void)_clearTouches;
- (void)_setGSEvent:(GSEventRef)event;
- (void)_setHIDEvent:(IOHIDEventRef)event;
- (void)_setTimestamp:(NSTimeInterval)timestamp;
@end

@interface UIApplication ()
- (UIEvent *)_touchesEvent;
@end

@interface KIFGSEventProxy : NSObject {
@public
    unsigned int flags;
    unsigned int type;
    unsigned int ignored1;
    float x1;
    float y1;
    float x2;
    float y2;
    unsigned int ignored2[10];
    unsigned int ignored3[7];
    float sizeX;
    float sizeY;
    float x3;
    float y3;
    unsigned int ignored4[3];
}
@end

@implementation KIFGSEventProxy
@end

@interface UITouch (AnClickPTFakeTouch)
- (instancetype)initAnClickAtPoint:(CGPoint)point inWindow:(UIWindow *)window;
- (void)anclick_setLocationInWindow:(CGPoint)location;
- (void)anclick_setPhaseAndUpdateTimestamp:(UITouchPhase)phase;
- (void)anclick_setHIDEvent;
@end

@implementation UITouch (AnClickPTFakeTouch)

- (instancetype)initAnClickAtPoint:(CGPoint)point inWindow:(UIWindow *)window {
    self = [super init];
    if (!self || !window) {
        return self;
    }

    [self setWindow:window];
    [self _setLocationInWindow:point resetPrevious:YES];

    UIView *hitTestView = [window hitTest:point withEvent:nil];
    [self setView:hitTestView ?: window];
    [self setPhase:UITouchPhaseBegan];
    [self setTimestamp:NSProcessInfo.processInfo.systemUptime];

    if ([self respondsToSelector:@selector(_setIsTapToClick:)]) {
        [self _setIsTapToClick:NO];
    } else {
        if ([self respondsToSelector:@selector(_setIsFirstTouchForView:)]) {
            [self _setIsFirstTouchForView:YES];
        }
        if ([self respondsToSelector:@selector(setIsTap:)]) {
            [self setIsTap:NO];
        }
    }
    if ([self respondsToSelector:@selector(setGestureView:)]) {
        [self setGestureView:hitTestView ?: window];
    }
    if ([self respondsToSelector:@selector(_setHidEvent:)]) {
        [self anclick_setHIDEvent];
    }

    return self;
}

- (void)anclick_setLocationInWindow:(CGPoint)location {
    [self setTimestamp:NSProcessInfo.processInfo.systemUptime];
    [self _setLocationInWindow:location resetPrevious:NO];
}

- (void)anclick_setPhaseAndUpdateTimestamp:(UITouchPhase)phase {
    [self setTimestamp:NSProcessInfo.processInfo.systemUptime];
    [self setPhase:phase];
    if ([self respondsToSelector:@selector(_setHidEvent:)]) {
        [self anclick_setHIDEvent];
    }
}

- (void)anclick_setHIDEvent {
    IOHIDEventRef event = AnClickIOHIDEventWithTouches(@[self]);
    [self _setHidEvent:event];
    CFRelease(event);
}

@end

static NSMutableArray<UITouch *> *AnClickTouches;

static UIEdgeInsets AnClickSafeInsets(void) {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (@available(iOS 11.0, *)) {
        return window.safeAreaInsets;
    }
    return UIEdgeInsetsZero;
}

static UIWindow *AnClickWindowForPoint(CGPoint point) {
    UIWindow *fallback = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            for (UIWindow *window in ((UIWindowScene *)scene).windows.reverseObjectEnumerator) {
                if (window.hidden || window.alpha <= 0.01 || window.windowLevel >= UIWindowLevelAlert) {
                    continue;
                }
                if (CGRectContainsPoint(window.bounds, [window convertPoint:point fromWindow:nil])) {
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
    for (UIWindow *window in UIApplication.sharedApplication.windows.reverseObjectEnumerator) {
        if (window.hidden || window.alpha <= 0.01 || window.windowLevel >= UIWindowLevelAlert) {
            continue;
        }
        if (CGRectContainsPoint(window.bounds, [window convertPoint:point fromWindow:nil])) {
            return window;
        }
        if (!fallback) {
            fallback = window;
        }
    }
#pragma clang diagnostic pop

    return fallback ?: UIApplication.sharedApplication.keyWindow;
}

static IOHIDEventRef AnClickIOHIDEventWithTouches(NSArray<UITouch *> *touches) {
    uint64_t timeStamp = mach_absolute_time();

    IOHIDEventRef handEvent = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault,
                                                             timeStamp,
                                                             kIOHIDDigitizerTransducerTypeHand,
                                                             0,
                                                             0,
                                                             kIOHIDDigitizerEventTouch,
                                                             0,
                                                             0,
                                                             0,
                                                             0,
                                                             0,
                                                             0,
                                                             false,
                                                             true,
                                                             0);
    IOHIDEventSetIntegerValue(handEvent, kIOHIDEventFieldDigitizerIsDisplayIntegrated, 1);
    IOHIDEventSetSenderID(handEvent, 0x8000000817319373ULL);

    for (UITouch *touch in touches) {
        if (touch.phase == UITouchPhaseStationary || touch.phase == UITouchPhaseCancelled || (touch.phase == UITouchPhaseEnded && !touch.window)) {
            continue;
        }

        BOOL touching = touch.phase != UITouchPhaseEnded;
        uint32_t eventMask = touch.phase == UITouchPhaseMoved
            ? kIOHIDDigitizerEventPosition
            : (kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch);
        CGPoint location = [touch locationInView:touch.window];

        IOHIDEventRef fingerEvent = IOHIDEventCreateDigitizerFingerEventWithQuality(kCFAllocatorDefault,
                                                                                    timeStamp,
                                                                                    (uint32_t)[touches indexOfObject:touch] + 1,
                                                                                    2,
                                                                                    eventMask,
                                                                                    (IOHIDFloat)location.x,
                                                                                    (IOHIDFloat)location.y,
                                                                                    0,
                                                                                    touching ? 0.5 : 0,
                                                                                    0,
                                                                                    5,
                                                                                    5,
                                                                                    1,
                                                                                    1,
                                                                                    1,
                                                                                    touching,
                                                                                    touching,
                                                                                    0);
        IOHIDEventSetIntegerValue(fingerEvent, kIOHIDEventFieldDigitizerIsDisplayIntegrated, 1);
        IOHIDEventSetSenderID(fingerEvent, 0x8000000817319373ULL);
        IOHIDEventAppendEvent(handEvent, fingerEvent, 0);
        CFRelease(fingerEvent);
    }

    return handEvent;
}

static void AnClickSetEventWithTouches(UIEvent *event, NSArray<UITouch *> *touches) {
    if (!event) {
        return;
    }

    if ([event respondsToSelector:@selector(_clearTouches)]) {
        [event _clearTouches];
    }

    IOHIDEventRef hidEvent = AnClickIOHIDEventWithTouches(touches);
    if ([event respondsToSelector:@selector(_setHIDEvent:)]) {
        [event _setHIDEvent:hidEvent];
    }
    CFRelease(hidEvent);

    for (UITouch *touch in touches) {
        if (touch.phase == UITouchPhaseStationary) {
            continue;
        }
        if ([event respondsToSelector:@selector(_addTouch:forDelayedDelivery:)]) {
            [event _addTouch:touch forDelayedDelivery:NO];
        }
    }
}

@implementation PTFakeTouch

+ (void)load {
    AnClickTouches = [NSMutableArray arrayWithCapacity:100];
    for (NSInteger i = 0; i < 100; i++) {
        UITouch *touch = [[UITouch alloc] init];
        [touch setPhase:UITouchPhaseEnded];
        [AnClickTouches addObject:touch];
    }
}

+ (NSInteger)getAvailablePointId {
    for (NSInteger i = 0; i < MIN((NSInteger)AnClickTouches.count, 50); i++) {
        UITouch *touch = AnClickTouches[(NSUInteger)i];
        if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseStationary || touch.phase == UITouchPhaseCancelled) {
            return i + 1;
        }
    }
    return 0;
}

+ (NSInteger)fakeTouchId:(NSInteger)pointId AtPoint:(CGPoint)point WithType:(PTFakeTouchEvent)type {
    UITouchPhase phase = UITouchPhaseBegan;
    switch (type) {
        case PTFakeTouchEventTouchDown:
            phase = UITouchPhaseBegan;
            break;
        case PTFakeTouchEventTouchMove:
            phase = UITouchPhaseMoved;
            break;
        case PTFakeTouchEventTouchCancel:
            phase = UITouchPhaseCancelled;
            break;
        case PTFakeTouchEventTouchUp:
        default:
            phase = UITouchPhaseEnded;
            break;
    }
    return [self fakeTouchId:pointId AtPoint:point withTouchPhase:phase];
}

+ (NSInteger)fakeTouchId:(NSInteger)pointId AtPoint:(CGPoint)point withTouchPhase:(UITouchPhase)phase {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fakeTouchId:pointId AtPoint:point withTouchPhase:phase];
        });
        return pointId;
    }

    if (pointId <= 0) {
        pointId = [self getAvailablePointId];
        if (pointId <= 0) {
            NSLog(@"[AnClick] PTFakeTouch no available touch id");
            return 0;
        }
    }

    NSUInteger index = (NSUInteger)(pointId - 1);
    if (index >= AnClickTouches.count) {
        return 0;
    }

    UITouch *touch = AnClickTouches[index];
    if (phase == UITouchPhaseBegan || touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
        UIWindow *window = AnClickWindowForPoint(point);
        CGPoint windowPoint = [window convertPoint:point fromWindow:nil];
        touch = [[UITouch alloc] initAnClickAtPoint:windowPoint inWindow:window];
        AnClickTouches[index] = touch;
    } else {
        CGPoint windowPoint = [touch.window convertPoint:point fromWindow:nil];
        [touch anclick_setLocationInWindow:windowPoint];
        [touch anclick_setPhaseAndUpdateTimestamp:phase];
    }

    UIEvent *event = [UIApplication.sharedApplication respondsToSelector:@selector(_touchesEvent)]
        ? [UIApplication.sharedApplication _touchesEvent]
        : [[UIEvent alloc] init];
    AnClickSetEventWithTouches(event, AnClickTouches);
    [UIApplication.sharedApplication sendEvent:event];

    NSLog(@"[AnClick] PTFakeTouch %@ id=%ld screen=(%.1f, %.1f) window=%@ safe=(%.0f,%.0f,%.0f,%.0f)",
          phase == UITouchPhaseBegan ? @"began" : (phase == UITouchPhaseMoved ? @"moved" : @"ended"),
          (long)pointId,
          point.x,
          point.y,
          touch.window,
          AnClickSafeInsets().top,
          AnClickSafeInsets().left,
          AnClickSafeInsets().bottom,
          AnClickSafeInsets().right);

    if (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseMoved) {
        [touch anclick_setPhaseAndUpdateTimestamp:UITouchPhaseStationary];
    }

    return pointId;
}

@end
