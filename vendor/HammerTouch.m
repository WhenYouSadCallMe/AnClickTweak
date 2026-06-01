#import "../include/HammerTouch.h"
#import <dlfcn.h>
#import <mach/mach_time.h>

typedef struct __IOHIDEvent *IOHIDEventRef;

#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

typedef uint32_t IOHIDDigitizerTransducerType;
typedef uint32_t IOHIDEventField;
typedef uint32_t IOHIDEventType;
typedef uint32_t IOOptionBits;

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
extern IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef allocator,
                                                          uint64_t timeStamp,
                                                          uint32_t identity,
                                                          uint32_t index,
                                                          uint32_t eventMask,
                                                          IOHIDFloat x,
                                                          IOHIDFloat y,
                                                          IOHIDFloat z,
                                                          IOHIDFloat tipPressure,
                                                          IOHIDFloat twist,
                                                          Boolean range,
                                                          Boolean touch,
                                                          IOOptionBits options);
extern void IOHIDEventAppendEvent(IOHIDEventRef event, IOHIDEventRef childEvent, IOOptionBits options);
extern void IOHIDEventSetFloatValue(IOHIDEventRef event, IOHIDEventField field, IOHIDFloat value);
extern void IOHIDEventSetIntegerValue(IOHIDEventRef event, IOHIDEventField field, int value);
extern void IOHIDEventSetSenderID(IOHIDEventRef event, uint64_t sender);

enum {
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
    kIOHIDDigitizerEventCancel = 0x00000080,
};

enum {
    kIOHIDEventFieldDigitizerMajorRadius = IOHIDEventFieldBase(kIOHIDEventTypeDigitizer) + 20,
    kIOHIDEventFieldDigitizerMinorRadius = IOHIDEventFieldBase(kIOHIDEventTypeDigitizer) + 21,
    kIOHIDEventFieldDigitizerIsDisplayIntegrated = IOHIDEventFieldBase(kIOHIDEventTypeDigitizer) + 25,
};

@interface UIApplication (AnClickHammerTouchPrivate)
- (void)_enqueueHIDEvent:(IOHIDEventRef)event;
@end

@interface UIWindow (AnClickHammerTouchPrivate)
- (unsigned)_contextId;
@end

typedef void (*AnClickBKSHIDEventSetDigitizerInfoFunction)(IOHIDEventRef event,
                                                           uint32_t contextID,
                                                           uint8_t systemGesturePossible,
                                                           uint8_t isSystemGestureStateChangeEvent,
                                                           CFStringRef displayUUID,
                                                           CFTimeInterval initialTouchTimestamp,
                                                           float maxForce);

typedef struct {
    BOOL active;
    uint32_t identity;
    CGPoint point;
    __unsafe_unretained UIWindow *window;
} AnClickHammerTouchSlot;

static AnClickHammerTouchSlot AnClickHammerTouchSlots[64];
static uint32_t AnClickHammerNextIdentity = 1000;
static const uint64_t AnClickHammerSenderID = 0x0000000123456789ULL;

static AnClickBKSHIDEventSetDigitizerInfoFunction AnClickBKSHIDEventSetDigitizerInfo(void) {
    static AnClickBKSHIDEventSetDigitizerInfoFunction function = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_NOW);
        if (handle) {
            function = (AnClickBKSHIDEventSetDigitizerInfoFunction)dlsym(handle, "BKSHIDEventSetDigitizerInfo");
        }
        if (!function) {
            NSLog(@"[AnClick] HammerTouch BKSHIDEventSetDigitizerInfo unavailable");
        }
    });
    return function;
}

static UIWindow *AnClickHammerWindowForPoint(CGPoint point) {
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

    return fallback;
}

static uint32_t AnClickHammerContextIDForWindow(UIWindow *window) {
    if (!window || ![window respondsToSelector:@selector(_contextId)]) {
        return 0;
    }
    return (uint32_t)[window _contextId];
}

static uint32_t AnClickHammerNewIdentity(void) {
    AnClickHammerNextIdentity++;
    if (AnClickHammerNextIdentity > 65000) {
        AnClickHammerNextIdentity = 1001;
    }
    return AnClickHammerNextIdentity;
}

static BOOL AnClickHammerPhaseIsTouching(AnClickHammerTouchPhase phase) {
    return phase == AnClickHammerTouchPhaseBegan ||
           phase == AnClickHammerTouchPhaseMoved ||
           phase == AnClickHammerTouchPhaseStationary;
}

static uint32_t AnClickHammerFingerMaskForPhase(AnClickHammerTouchPhase phase) {
    uint32_t mask = 0;
    if (phase == AnClickHammerTouchPhaseBegan ||
        phase == AnClickHammerTouchPhaseEnded ||
        phase == AnClickHammerTouchPhaseCancelled) {
        mask |= kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch;
    }
    if (phase == AnClickHammerTouchPhaseMoved) {
        mask |= kIOHIDDigitizerEventPosition;
    }
    if (phase == AnClickHammerTouchPhaseCancelled) {
        mask |= kIOHIDDigitizerEventCancel;
    }
    return mask;
}

static uint32_t AnClickHammerHandMaskForPhase(AnClickHammerTouchPhase phase) {
    return AnClickHammerFingerMaskForPhase(phase) & kIOHIDDigitizerEventTouch;
}

static IOHIDEventRef AnClickHammerCreateTouchEvent(CGPoint point,
                                                   uint32_t identity,
                                                   uint32_t fingerIndex,
                                                   AnClickHammerTouchPhase phase) CF_RETURNS_RETAINED {
    BOOL touching = AnClickHammerPhaseIsTouching(phase);
    uint64_t timestamp = mach_absolute_time();
    uint32_t handMask = AnClickHammerHandMaskForPhase(phase);
    uint32_t fingerMask = AnClickHammerFingerMaskForPhase(phase);

    IOHIDEventRef handEvent = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault,
                                                             timestamp,
                                                             kIOHIDDigitizerTransducerTypeHand,
                                                             0,
                                                             0,
                                                             handMask,
                                                             0,
                                                             0,
                                                             0,
                                                             0,
                                                             0,
                                                             0,
                                                             false,
                                                             touching,
                                                             0);
    if (!handEvent) {
        return NULL;
    }

    IOHIDEventSetIntegerValue(handEvent, kIOHIDEventFieldDigitizerIsDisplayIntegrated, 1);
    IOHIDEventSetSenderID(handEvent, AnClickHammerSenderID);

    IOHIDEventRef fingerEvent = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault,
                                                                     timestamp,
                                                                     identity,
                                                                     fingerIndex,
                                                                     fingerMask,
                                                                     (IOHIDFloat)point.x,
                                                                     (IOHIDFloat)point.y,
                                                                     0,
                                                                     touching ? 0.5 : 0,
                                                                     0,
                                                                     touching,
                                                                     touching,
                                                                     0);
    if (fingerEvent) {
        IOHIDEventSetIntegerValue(fingerEvent, kIOHIDEventFieldDigitizerIsDisplayIntegrated, 1);
        IOHIDEventSetFloatValue(fingerEvent, kIOHIDEventFieldDigitizerMajorRadius, 5);
        IOHIDEventSetFloatValue(fingerEvent, kIOHIDEventFieldDigitizerMinorRadius, 5);
        IOHIDEventSetSenderID(fingerEvent, AnClickHammerSenderID);
        IOHIDEventAppendEvent(handEvent, fingerEvent, 0);
        CFRelease(fingerEvent);
    }

    return handEvent;
}

static void AnClickHammerPrepareEventForWindow(IOHIDEventRef event, UIWindow *window) {
    if (!event) {
        return;
    }

    uint32_t contextID = AnClickHammerContextIDForWindow(window);
    AnClickBKSHIDEventSetDigitizerInfoFunction setDigitizerInfo = AnClickBKSHIDEventSetDigitizerInfo();
    if (contextID && setDigitizerInfo) {
        setDigitizerInfo(event, contextID, false, false, NULL, 0, 0);
    }
}

@implementation AnClickHammerTouch

+ (NSInteger)availableTouchId {
    for (NSInteger i = 0; i < 50; i++) {
        if (!AnClickHammerTouchSlots[i].active) {
            return i + 1;
        }
    }
    return 0;
}

+ (void)cancelAllActiveTouches {
    for (NSInteger i = 0; i < 64; i++) {
        if (!AnClickHammerTouchSlots[i].active) {
            continue;
        }
        [self sendTouchId:i + 1 atPoint:AnClickHammerTouchSlots[i].point phase:AnClickHammerTouchPhaseCancelled];
    }
}

+ (NSInteger)sendTouchId:(NSInteger)touchId atPoint:(CGPoint)point phase:(AnClickHammerTouchPhase)phase {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendTouchId:touchId atPoint:point phase:phase];
        });
        return touchId;
    }

    if (![UIApplication.sharedApplication respondsToSelector:@selector(_enqueueHIDEvent:)]) {
        NSLog(@"[AnClick] HammerTouch _enqueueHIDEvent unavailable");
        return 0;
    }

    if (touchId <= 0) {
        touchId = [self availableTouchId];
    }
    if (touchId <= 0 || touchId > 64) {
        NSLog(@"[AnClick] HammerTouch no available touch id");
        return 0;
    }

    NSUInteger index = (NSUInteger)(touchId - 1);
    AnClickHammerTouchSlot *slot = &AnClickHammerTouchSlots[index];

    if (phase == AnClickHammerTouchPhaseBegan) {
        if (slot->active) {
            [self sendTouchId:touchId atPoint:slot->point phase:AnClickHammerTouchPhaseCancelled];
        }
        slot->active = YES;
        slot->identity = AnClickHammerNewIdentity();
        slot->point = point;
        slot->window = AnClickHammerWindowForPoint(point);
    } else if (!slot->active) {
        NSLog(@"[AnClick] HammerTouch dropped inactive phase=%ld id=%ld screen=(%.1f, %.1f)",
              (long)phase,
              (long)touchId,
              point.x,
              point.y);
        return touchId;
    } else {
        slot->point = point;
        if (!slot->window || slot->window.hidden || slot->window.alpha <= 0.01) {
            slot->window = AnClickHammerWindowForPoint(point);
        }
    }

    UIWindow *window = slot->window ?: AnClickHammerWindowForPoint(point);
    if (!window) {
        NSLog(@"[AnClick] HammerTouch no target window at %.1f, %.1f", point.x, point.y);
        if (phase == AnClickHammerTouchPhaseBegan) {
            slot->active = NO;
            slot->identity = 0;
            slot->window = nil;
        }
        return touchId;
    }

    IOHIDEventRef event = AnClickHammerCreateTouchEvent(point,
                                                        slot->identity ?: (uint32_t)touchId,
                                                        (uint32_t)touchId,
                                                        phase);
    if (event) {
        AnClickHammerPrepareEventForWindow(event, window);
        [UIApplication.sharedApplication _enqueueHIDEvent:event];
        CFRelease(event);
    }

    if (phase == AnClickHammerTouchPhaseEnded || phase == AnClickHammerTouchPhaseCancelled) {
        slot->active = NO;
        slot->identity = 0;
        slot->point = CGPointZero;
        slot->window = nil;
    }

    return touchId;
}

@end
