#import "AnClickRecognitionService.h"
#import <dispatch/dispatch.h>

@interface AnClickCore : NSObject
+ (NSDictionary *)findTemplateImageMatch:(UIImage *)templateImage threshold:(double)threshold;
+ (NSDictionary *)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points tolerance:(double)tolerance;
@end

@interface AnClickOCR : NSObject
+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode useRegex:(BOOL)useRegex;
@end

@interface AnClickRecognitionService ()
@property (nonatomic) dispatch_queue_t queue;
@property (atomic, assign) NSUInteger cancellationGeneration;
@end

@implementation AnClickRecognitionService

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.anclick.recognition", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)completeOnMain:(AnClickRecognitionMatchCompletion)completion
                 match:(NSDictionary *)match
            generation:(NSUInteger)generation {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self isGenerationCurrent:generation]) {
            return;
        }
        if (completion) {
            completion(match);
        }
    });
}

- (BOOL)isGenerationCurrent:(NSUInteger)generation {
    return generation == self.cancellationGeneration;
}

- (void)findTemplateImageMatch:(UIImage *)templateImage
                     threshold:(double)threshold
                    completion:(AnClickRecognitionMatchCompletion)completion {
    if (!templateImage) {
        [self completeOnMain:completion match:nil generation:self.cancellationGeneration];
        return;
    }
    NSUInteger generation = self.cancellationGeneration;
    dispatch_async(_queue, ^{
        @autoreleasepool {
            if (![self isGenerationCurrent:generation]) {
                return;
            }
            NSDictionary *match = [AnClickCore findTemplateImageMatch:templateImage threshold:threshold];
            if (![self isGenerationCurrent:generation]) {
                return;
            }
            [self completeOnMain:completion match:match generation:generation];
        }
    });
}

- (void)findText:(NSString *)targetText
            mode:(AnClickOCRMode)mode
        useRegex:(BOOL)useRegex
      completion:(AnClickRecognitionMatchCompletion)completion {
    if (targetText.length == 0) {
        [self completeOnMain:completion match:nil generation:self.cancellationGeneration];
        return;
    }
    NSUInteger generation = self.cancellationGeneration;
    dispatch_async(_queue, ^{
        @autoreleasepool {
            if (![self isGenerationCurrent:generation]) {
                return;
            }
            NSDictionary *match = [AnClickOCR findText:targetText mode:mode useRegex:useRegex];
            if (![self isGenerationCurrent:generation]) {
                return;
            }
            [self completeOnMain:completion match:match generation:generation];
        }
    });
}

- (void)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points
                              tolerance:(double)tolerance
                             completion:(AnClickRecognitionMatchCompletion)completion {
    if (points.count == 0) {
        [self completeOnMain:completion match:nil generation:self.cancellationGeneration];
        return;
    }
    NSUInteger generation = self.cancellationGeneration;
    dispatch_async(_queue, ^{
        @autoreleasepool {
            if (![self isGenerationCurrent:generation]) {
                return;
            }
            NSDictionary *match = [AnClickCore findColorPatternMatchWithPoints:points tolerance:tolerance];
            if (![self isGenerationCurrent:generation]) {
                return;
            }
            [self completeOnMain:completion match:match generation:generation];
        }
    });
}

- (void)cancelPendingRequests {
    self.cancellationGeneration = self.cancellationGeneration + 1;
}

@end
