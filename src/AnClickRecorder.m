#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, AnClickRecordEventType) {
    AnClickRecordEventTypeBegan = 0,
    AnClickRecordEventTypeMoved = 1,
    AnClickRecordEventTypeEnded = 2,
    AnClickRecordEventTypeCancelled = 3,
};

@interface AnClickRecordEvent : NSObject
@property (nonatomic, assign) AnClickRecordEventType type;
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) NSTimeInterval timestamp;
- (NSDictionary *)dictionaryValue;
@end

@implementation AnClickRecordEvent

- (NSDictionary *)dictionaryValue {
    return @{
        @"type": @(self.type),
        @"x": @(self.point.x),
        @"y": @(self.point.y),
        @"timestamp": @(self.timestamp),
    };
}

@end

@interface AnClickRecorder : NSObject
+ (instancetype)shared;
- (void)installHook;
- (void)startRecording;
- (NSArray<AnClickRecordEvent *> *)stopRecording;
- (NSArray<AnClickRecordEvent *> *)events;
- (NSArray<NSDictionary *> *)serializedEvents;
@property (nonatomic, assign, getter=isRecording) BOOL recording;
@end

static void (*original_sendEvent)(id self, SEL _cmd, UIEvent *event);

@implementation AnClickRecorder {
    NSMutableArray<AnClickRecordEvent *> *_events;
    NSTimeInterval _recordStartTime;
}

+ (instancetype)shared {
    static AnClickRecorder *recorder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recorder = [[AnClickRecorder alloc] init];
    });
    return recorder;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _events = [NSMutableArray array];
    }
    return self;
}

- (void)installHook {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = UIWindow.class;
        SEL selector = @selector(sendEvent:);
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) {
            return;
        }
        original_sendEvent = (void (*)(id, SEL, UIEvent *))method_getImplementation(method);
        IMP replacement = imp_implementationWithBlock(^(__unsafe_unretained UIWindow *window, UIEvent *event) {
            [[AnClickRecorder shared] handleEvent:event inWindow:window];
            if (original_sendEvent) {
                original_sendEvent(window, selector, event);
            }
        });
        method_setImplementation(method, replacement);
    });
}

- (void)startRecording {
    @synchronized (self) {
        [_events removeAllObjects];
        _recordStartTime = CACurrentMediaTime();
        self.recording = YES;
    }
}

- (NSArray<AnClickRecordEvent *> *)stopRecording {
    @synchronized (self) {
        self.recording = NO;
        return [_events copy];
    }
}

- (NSArray<AnClickRecordEvent *> *)events {
    @synchronized (self) {
        return [_events copy];
    }
}

- (NSArray<NSDictionary *> *)serializedEvents {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    for (AnClickRecordEvent *event in [self events]) {
        [result addObject:[event dictionaryValue]];
    }
    return result;
}

- (void)handleEvent:(UIEvent *)event inWindow:(UIWindow *)window {
    if (!self.isRecording || event.type != UIEventTypeTouches) {
        return;
    }

    NSSet<UITouch *> *touches = [event allTouches];
    if (touches.count == 0) {
        return;
    }

    @synchronized (self) {
        if (!self.isRecording) {
            return;
        }

        for (UITouch *touch in touches) {
            AnClickRecordEventType type;
            switch (touch.phase) {
                case UITouchPhaseBegan:
                    type = AnClickRecordEventTypeBegan;
                    break;
                case UITouchPhaseMoved:
                    type = AnClickRecordEventTypeMoved;
                    break;
                case UITouchPhaseEnded:
                    type = AnClickRecordEventTypeEnded;
                    break;
                case UITouchPhaseCancelled:
                    type = AnClickRecordEventTypeCancelled;
                    break;
                default:
                    continue;
            }

            AnClickRecordEvent *record = [[AnClickRecordEvent alloc] init];
            record.type = type;
            record.point = [touch locationInView:window];
            record.timestamp = MAX(0, CACurrentMediaTime() - _recordStartTime);
            [_events addObject:record];
        }
    }
}

@end

__attribute__((constructor)) static void AnClickRecorderInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[AnClickRecorder shared] installHook];
    });
}
