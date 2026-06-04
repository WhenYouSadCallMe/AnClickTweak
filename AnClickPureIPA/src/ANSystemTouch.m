#import "ANSystemTouch.h"
#import <dlfcn.h>
#import <mach/mach_time.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

typedef uint32_t IOHIDDigitizerTransducerType;
typedef uint32_t IOHIDEventField;
typedef uint32_t IOHIDEventType;
typedef uint32_t IOOptionBits;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
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
    ANHIDDigitizerTransducerTypeHand = 3,
    ANHIDEventTypeDigitizer = 11,
    ANHIDDigitizerEventRange = 0x00000001,
    ANHIDDigitizerEventTouch = 0x00000002,
    ANHIDDigitizerEventPosition = 0x00000004,
    ANHIDDigitizerEventCancel = 0x00000080,
};

#define ANHIDEventFieldBase(type) ((type) << 16)

enum {
    ANHIDEventFieldDigitizerMajorRadius = ANHIDEventFieldBase(ANHIDEventTypeDigitizer) + 20,
    ANHIDEventFieldDigitizerMinorRadius = ANHIDEventFieldBase(ANHIDEventTypeDigitizer) + 21,
    ANHIDEventFieldDigitizerIsDisplayIntegrated = ANHIDEventFieldBase(ANHIDEventTypeDigitizer) + 25,
};

typedef NS_ENUM(NSInteger, ANSystemTouchPhase) {
    ANSystemTouchPhaseBegan = 0,
    ANSystemTouchPhaseMoved = 1,
    ANSystemTouchPhaseEnded = 2,
    ANSystemTouchPhaseCancelled = 3,
};

static const uint64_t ANSystemTouchSenderID = 0x00000000AC1C1001ULL;

static IOHIDEventSystemClientRef ANSystemTouchClient(void) {
    static IOHIDEventSystemClientRef client = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        if (!client) {
            NSLog(@"[AnClickPureIPA] IOHIDEventSystemClient unavailable");
        }
    });
    return client;
}

static uint32_t ANSystemTouchMaskForPhase(ANSystemTouchPhase phase) {
    switch (phase) {
        case ANSystemTouchPhaseBegan:
        case ANSystemTouchPhaseEnded:
            return ANHIDDigitizerEventRange | ANHIDDigitizerEventTouch;
        case ANSystemTouchPhaseMoved:
            return ANHIDDigitizerEventPosition;
        case ANSystemTouchPhaseCancelled:
            return ANHIDDigitizerEventRange | ANHIDDigitizerEventTouch | ANHIDDigitizerEventCancel;
    }
}

static BOOL ANSystemTouchPhaseIsTouching(ANSystemTouchPhase phase) {
    return phase == ANSystemTouchPhaseBegan || phase == ANSystemTouchPhaseMoved;
}

static IOHIDEventRef ANSystemTouchCreateEvent(CGPoint point, ANSystemTouchPhase phase, uint32_t identity) CF_RETURNS_RETAINED {
    uint64_t timestamp = mach_absolute_time();
    BOOL touching = ANSystemTouchPhaseIsTouching(phase);
    uint32_t mask = ANSystemTouchMaskForPhase(phase);
    IOHIDEventRef handEvent = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault,
                                                             timestamp,
                                                             ANHIDDigitizerTransducerTypeHand,
                                                             0,
                                                             0,
                                                             mask & ANHIDDigitizerEventTouch,
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

    IOHIDEventSetIntegerValue(handEvent, ANHIDEventFieldDigitizerIsDisplayIntegrated, 1);
    IOHIDEventSetSenderID(handEvent, ANSystemTouchSenderID);

    IOHIDEventRef fingerEvent = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault,
                                                                     timestamp,
                                                                     identity,
                                                                     1,
                                                                     mask,
                                                                     (IOHIDFloat)point.x,
                                                                     (IOHIDFloat)point.y,
                                                                     0,
                                                                     touching ? 0.5 : 0,
                                                                     0,
                                                                     touching,
                                                                     touching,
                                                                     0);
    if (fingerEvent) {
        IOHIDEventSetIntegerValue(fingerEvent, ANHIDEventFieldDigitizerIsDisplayIntegrated, 1);
        IOHIDEventSetFloatValue(fingerEvent, ANHIDEventFieldDigitizerMajorRadius, 5);
        IOHIDEventSetFloatValue(fingerEvent, ANHIDEventFieldDigitizerMinorRadius, 5);
        IOHIDEventSetSenderID(fingerEvent, ANSystemTouchSenderID);
        IOHIDEventAppendEvent(handEvent, fingerEvent, 0);
        CFRelease(fingerEvent);
    }

    return handEvent;
}

static void ANSystemTouchSend(CGPoint point, ANSystemTouchPhase phase, uint32_t identity) {
    IOHIDEventSystemClientRef client = ANSystemTouchClient();
    if (!client) {
        return;
    }
    IOHIDEventRef event = ANSystemTouchCreateEvent(point, phase, identity);
    if (!event) {
        return;
    }
    IOHIDEventSystemClientDispatchEvent(client, event);
    CFRelease(event);
}

@implementation ANSystemTouch

+ (BOOL)systemTouchAvailable {
    return ANSystemTouchClient() != NULL;
}

+ (void)tapAtPoint:(CGPoint)point {
    uint32_t identity = (uint32_t)(arc4random_uniform(50000) + 1000);
    dispatch_async(dispatch_get_main_queue(), ^{
        ANSystemTouchSend(point, ANSystemTouchPhaseBegan, identity);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.055 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ANSystemTouchSend(point, ANSystemTouchPhaseEnded, identity);
        });
    });
}

+ (void)doubleTapAtPoint:(CGPoint)point {
    [self tapAtPoint:point];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self tapAtPoint:point];
    });
}

+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration {
    uint32_t identity = (uint32_t)(arc4random_uniform(50000) + 1000);
    NSTimeInterval holdDuration = MAX(0.35, duration);
    dispatch_async(dispatch_get_main_queue(), ^{
        ANSystemTouchSend(point, ANSystemTouchPhaseBegan, identity);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(holdDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ANSystemTouchSend(point, ANSystemTouchPhaseEnded, identity);
        });
    });
}

+ (void)playPath:(NSArray<NSValue *> *)points duration:(NSTimeInterval)duration {
    if (points.count < 2) {
        return;
    }
    uint32_t identity = (uint32_t)(arc4random_uniform(50000) + 1000);
    NSTimeInterval totalDuration = MAX(0.12, duration);
    NSUInteger count = points.count;
    dispatch_async(dispatch_get_main_queue(), ^{
        ANSystemTouchSend(points.firstObject.CGPointValue, ANSystemTouchPhaseBegan, identity);
        for (NSUInteger index = 1; index < count; index++) {
            NSTimeInterval delay = totalDuration * ((double)index / (double)MAX((NSUInteger)1, count - 1));
            CGPoint point = points[index].CGPointValue;
            BOOL last = index == count - 1;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                ANSystemTouchSend(point, last ? ANSystemTouchPhaseEnded : ANSystemTouchPhaseMoved, identity);
            });
        }
    });
}

@end
