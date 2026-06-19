#import "../include/HammerTouch.h"
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <sys/proc.h>
#import <sys/sysctl.h>
#import <unistd.h>

#if ANCLICK_RELEASE_SILENT
#undef NSLog
#define NSLog(...) do {} while (0)
#endif

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

#ifndef P_TRACED
#define P_TRACED 0x00000800
#endif

static NSTimeInterval AnClickHammerExpiryUnixTime(void) {
    const uint8_t encoded[] = {0x26, 0xA7, 0x1F, 0xF8, 0x0F, 0xC4, 0x78, 0xB3};
    const uint8_t masks[] = {0xA6, 0x31, 0x5D, 0x92, 0x0F, 0xC4, 0x78, 0xB3};
    uint64_t value = 0;
    for (size_t i = 0; i < sizeof(encoded); i++) {
        value |= ((uint64_t)(encoded[i] ^ masks[i])) << (8 * i);
    }
    if (((uint32_t)value ^ 0xA70C91EFu) != 0xCD4E076Fu ||
        value < 1600000000ULL ||
        value > 2200000000ULL) {
        return 1.0;
    }
    return (NSTimeInterval)value;
}

static NSString *AnClickHammerClockKey(void) {
    static NSString *clockKey = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const uint8_t encoded[] = {
            0x39, 0x35, 0x37, 0x74, 0x3B, 0x34, 0x39, 0x36, 0x33,
            0x39, 0x31, 0x74, 0x36, 0x35, 0x39, 0x3B, 0x36, 0x74,
            0x3D, 0x2F, 0x3B, 0x28, 0x3E, 0x74, 0x37, 0x3B, 0x22,
        };
        char decoded[sizeof(encoded) + 1];
        for (size_t i = 0; i < sizeof(encoded); i++) {
            decoded[i] = (char)(encoded[i] ^ 0x5A);
        }
        decoded[sizeof(encoded)] = '\0';
        clockKey = [[NSString alloc] initWithBytes:decoded length:sizeof(encoded) encoding:NSUTF8StringEncoding];
    });
    return clockKey;
}

static BOOL AnClickHammerDebuggerAttached(void) {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    size_t size = sizeof(info);
    memset(&info, 0, sizeof(info));
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) {
        return NO;
    }
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

static BOOL AnClickHammerRuntimeAllowed(void) {
    if (AnClickHammerDebuggerAttached()) {
        return NO;
    }
    NSTimeInterval expiry = AnClickHammerExpiryUnixTime();
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (expiry <= 1.0 || now < 978307200.0) {
        return NO;
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *clockKey = AnClickHammerClockKey();
    NSTimeInterval maxSeen = [defaults doubleForKey:clockKey];
    if (now > maxSeen + 30.0) {
        [defaults setDouble:now forKey:clockKey];
        [defaults synchronize];
        maxSeen = now;
    }
    if (maxSeen >= expiry) {
        return NO;
    }
    if (maxSeen > 0.0 && now + 600.0 < maxSeen) {
        return NO;
    }
    return now < expiry;
}

static BOOL AnClickHammerPayloadIsCleanup(NSArray<NSNumber *> *phases) {
    if (phases.count == 0) {
        return NO;
    }
    for (NSNumber *phaseNumber in phases) {
        AnClickHammerTouchPhase phase = (AnClickHammerTouchPhase)phaseNumber.integerValue;
        if (phase == AnClickHammerTouchPhaseBegan ||
            phase == AnClickHammerTouchPhaseMoved ||
            phase == AnClickHammerTouchPhaseStationary) {
            return NO;
        }
    }
    return YES;
}

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

static BOOL AnClickHammerWindowCanReceivePoint(UIWindow *window, CGPoint point) {
    if (!window || window.hidden || window.alpha <= 0.01 || window.windowLevel >= UIWindowLevelAlert) {
        return NO;
    }
    CGPoint windowPoint = [window convertPoint:point fromWindow:nil];
    return CGRectContainsPoint(window.bounds, windowPoint);
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

static IOHIDEventRef AnClickHammerCreateTouchEvent(NSArray<NSNumber *> *touchIds,
                                                   NSArray<NSValue *> *points,
                                                   NSArray<NSNumber *> *phases,
                                                   NSArray<NSNumber *> *identities) CF_RETURNS_RETAINED {
    uint64_t timestamp = mach_absolute_time();
    BOOL touching = NO;
    uint32_t handMask = 0;
    for (NSNumber *phaseNumber in phases) {
        AnClickHammerTouchPhase phase = (AnClickHammerTouchPhase)phaseNumber.integerValue;
        touching = touching || AnClickHammerPhaseIsTouching(phase);
        handMask |= AnClickHammerHandMaskForPhase(phase);
    }

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

    for (NSUInteger i = 0; i < points.count; i++) {
        CGPoint point = [(NSValue *)points[i] CGPointValue];
        AnClickHammerTouchPhase phase = (AnClickHammerTouchPhase)[(NSNumber *)phases[i] integerValue];
        BOOL fingerTouching = AnClickHammerPhaseIsTouching(phase);
        uint32_t identity = [(NSNumber *)identities[i] unsignedIntValue];
        uint32_t fingerIndex = [(NSNumber *)touchIds[i] unsignedIntValue];
        uint32_t fingerMask = AnClickHammerFingerMaskForPhase(phase);
        IOHIDEventRef fingerEvent = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault,
                                                                         timestamp,
                                                                         identity,
                                                                         fingerIndex,
                                                                         fingerMask,
                                                                         (IOHIDFloat)point.x,
                                                                         (IOHIDFloat)point.y,
                                                                         0,
                                                                         fingerTouching ? 0.5 : 0,
                                                                         0,
                                                                         fingerTouching,
                                                                         fingerTouching,
                                                                         0);
        if (fingerEvent) {
            IOHIDEventSetIntegerValue(fingerEvent, kIOHIDEventFieldDigitizerIsDisplayIntegrated, 1);
            IOHIDEventSetFloatValue(fingerEvent, kIOHIDEventFieldDigitizerMajorRadius, 5);
            IOHIDEventSetFloatValue(fingerEvent, kIOHIDEventFieldDigitizerMinorRadius, 5);
            IOHIDEventSetSenderID(fingerEvent, AnClickHammerSenderID);
            IOHIDEventAppendEvent(handEvent, fingerEvent, 0);
            CFRelease(fingerEvent);
        }
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
    return [self sendTouchId:touchId atPoint:point phase:phase targetWindow:nil];
}

+ (NSInteger)sendTouchId:(NSInteger)touchId
                 atPoint:(CGPoint)point
                   phase:(AnClickHammerTouchPhase)phase
            targetWindow:(UIWindow *)targetWindow {
    if (touchId <= 0) {
        touchId = [self availableTouchId];
    }
    if (touchId <= 0) {
        NSLog(@"[AnClick] HammerTouch no available touch id");
        return 0;
    }
    [self sendTouchIds:@[@(touchId)]
                points:@[[NSValue valueWithCGPoint:point]]
                phases:@[@(phase)]
          targetWindow:targetWindow];
    return touchId;
}

+ (void)sendTouchIds:(NSArray<NSNumber *> *)touchIds
              points:(NSArray<NSValue *> *)points
              phases:(NSArray<NSNumber *> *)phases {
    [self sendTouchIds:touchIds points:points phases:phases targetWindow:nil];
}

+ (void)sendTouchIds:(NSArray<NSNumber *> *)touchIds
              points:(NSArray<NSValue *> *)points
              phases:(NSArray<NSNumber *> *)phases
        targetWindow:(UIWindow *)targetWindow {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendTouchIds:touchIds points:points phases:phases targetWindow:targetWindow];
        });
        return;
    }

    if (!AnClickHammerRuntimeAllowed() && !AnClickHammerPayloadIsCleanup(phases)) {
        return;
    }

    if (![UIApplication.sharedApplication respondsToSelector:@selector(_enqueueHIDEvent:)]) {
        NSLog(@"[AnClick] HammerTouch _enqueueHIDEvent unavailable");
        return;
    }

    if (touchIds.count == 0 || touchIds.count != points.count || touchIds.count != phases.count) {
        NSLog(@"[AnClick] HammerTouch invalid multi-touch payload");
        return;
    }

    NSMutableArray<NSNumber *> *eventTouchIds = [NSMutableArray array];
    NSMutableArray<NSValue *> *eventPoints = [NSMutableArray array];
    NSMutableArray<NSNumber *> *eventPhases = [NSMutableArray array];
    NSMutableArray<NSNumber *> *eventIdentities = [NSMutableArray array];
    NSMutableArray<NSNumber *> *endedTouchIds = [NSMutableArray array];
    UIWindow *eventWindow = nil;

    for (NSUInteger i = 0; i < touchIds.count; i++) {
        NSInteger touchId = [(NSNumber *)touchIds[i] integerValue];
        CGPoint point = [(NSValue *)points[i] CGPointValue];
        AnClickHammerTouchPhase phase = (AnClickHammerTouchPhase)[(NSNumber *)phases[i] integerValue];
        if (touchId <= 0 || touchId > 64) {
            NSLog(@"[AnClick] HammerTouch invalid id=%ld", (long)touchId);
            continue;
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
            slot->window = AnClickHammerWindowCanReceivePoint(targetWindow, point) ? targetWindow : AnClickHammerWindowForPoint(point);
        } else if (!slot->active) {
            NSLog(@"[AnClick] HammerTouch dropped inactive phase=%ld id=%ld screen=(%.1f, %.1f)",
                  (long)phase,
                  (long)touchId,
                  point.x,
                  point.y);
            continue;
        } else {
            slot->point = point;
            if (!slot->window || slot->window.hidden || slot->window.alpha <= 0.01) {
                slot->window = AnClickHammerWindowCanReceivePoint(targetWindow, point) ? targetWindow : AnClickHammerWindowForPoint(point);
            }
        }

        if (!eventWindow) {
            eventWindow = slot->window ?: (AnClickHammerWindowCanReceivePoint(targetWindow, point) ? targetWindow : AnClickHammerWindowForPoint(point));
        }

        if (!eventWindow) {
            NSLog(@"[AnClick] HammerTouch no target window at %.1f, %.1f", point.x, point.y);
            if (phase == AnClickHammerTouchPhaseBegan) {
                slot->active = NO;
                slot->identity = 0;
                slot->window = nil;
            }
            continue;
        }

        [eventTouchIds addObject:@(touchId)];
        [eventPoints addObject:[NSValue valueWithCGPoint:point]];
        [eventPhases addObject:@(phase)];
        [eventIdentities addObject:@(slot->identity ?: (uint32_t)touchId)];
        if (phase == AnClickHammerTouchPhaseEnded || phase == AnClickHammerTouchPhaseCancelled) {
            [endedTouchIds addObject:@(touchId)];
        }
    }

    if (eventTouchIds.count == 0 || !eventWindow) {
        return;
    }

    IOHIDEventRef event = AnClickHammerCreateTouchEvent(eventTouchIds,
                                                        eventPoints,
                                                        eventPhases,
                                                        eventIdentities);
    if (event) {
        AnClickHammerPrepareEventForWindow(event, eventWindow);
        [UIApplication.sharedApplication _enqueueHIDEvent:event];
        CFRelease(event);
    }

    for (NSNumber *touchIdNumber in endedTouchIds) {
        NSUInteger index = (NSUInteger)(touchIdNumber.integerValue - 1);
        AnClickHammerTouchSlot *slot = &AnClickHammerTouchSlots[index];
        slot->active = NO;
        slot->identity = 0;
        slot->point = CGPointZero;
        slot->window = nil;
    }
}

@end
