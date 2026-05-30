#import "../include/PTFakeTouch.h"
#import <mach/mach_time.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t transducerType, uint32_t index, uint32_t identity, uint32_t eventMask, uint32_t buttonMask, CGFloat x, CGFloat y, CGFloat z, CGFloat tipPressure, CGFloat barrelPressure, Boolean range, Boolean touch, OptionBits options);
extern IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef allocator, uint64_t timeStamp, uint32_t index, uint32_t identity, uint32_t eventMask, CGFloat x, CGFloat y, CGFloat z, CGFloat tipPressure, CGFloat twist, Boolean range, Boolean touch, OptionBits options);
extern void IOHIDEventAppendEvent(IOHIDEventRef event, IOHIDEventRef childEvent, OptionBits options);
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);

static const uint32_t kPTDigitizerTransducerHand = 3;
static const uint32_t kPTDigitizerEventRange = 1 << 0;
static const uint32_t kPTDigitizerEventTouch = 1 << 1;
static const uint32_t kPTDigitizerEventPosition = 1 << 2;
static const uint32_t kPTDigitizerEventIdentity = 1 << 5;
static const uint32_t kPTDigitizerEventAttribute = 1 << 6;
static BOOL gPTFakeTouchUseScreenScale = NO;

@implementation PTFakeTouch

+ (void)setUseScreenScale:(BOOL)useScreenScale {
    gPTFakeTouchUseScreenScale = useScreenScale;
}

+ (void)fakeTouchId:(NSInteger)touchId AtPoint:(CGPoint)point WithType:(PTFakeTouchEvent)type {
    static IOHIDEventSystemClientRef client = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    });

    if (!client) {
        return;
    }

    BOOL touching = (type == PTFakeTouchEventTouchDown || type == PTFakeTouchEventTouchMove);
    uint32_t eventMask = kPTDigitizerEventPosition | kPTDigitizerEventIdentity | kPTDigitizerEventAttribute;
    if (type == PTFakeTouchEventTouchDown) {
        eventMask |= kPTDigitizerEventRange | kPTDigitizerEventTouch;
    } else if (type == PTFakeTouchEventTouchMove) {
        eventMask |= kPTDigitizerEventRange | kPTDigitizerEventTouch;
    }

    uint64_t timestamp = mach_absolute_time();
    CGFloat scale = gPTFakeTouchUseScreenScale ? UIScreen.mainScreen.scale : 1.0;
    CGFloat x = point.x * scale;
    CGFloat y = point.y * scale;
    uint32_t identity = (uint32_t)MAX(1, touchId);

    IOHIDEventRef handEvent = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault,
                                                             timestamp,
                                                             kPTDigitizerTransducerHand,
                                                             0,
                                                             identity,
                                                             eventMask,
                                                             0,
                                                             x,
                                                             y,
                                                             0,
                                                             0,
                                                             0,
                                                             true,
                                                             touching,
                                                             0);
    if (!handEvent) {
        return;
    }

    IOHIDEventRef fingerEvent = IOHIDEventCreateDigitizerFingerEvent(kCFAllocatorDefault,
                                                                     timestamp,
                                                                     1,
                                                                     identity,
                                                                     eventMask,
                                                                     x,
                                                                     y,
                                                                     0,
                                                                     touching ? 0.5 : 0,
                                                                     0,
                                                                     true,
                                                                     touching,
                                                                     0);
    if (fingerEvent) {
        IOHIDEventAppendEvent(handEvent, fingerEvent, 0);
        CFRelease(fingerEvent);
    }

    IOHIDEventSystemClientDispatchEvent(client, handEvent);
    CFRelease(handEvent);
}

@end
