#import "AnClickRecognitionService.h"
#import <dispatch/dispatch.h>

@interface AnClickCore : NSObject
+ (NSDictionary *)findTemplateImageMatch:(UIImage *)templateImage threshold:(double)threshold;
+ (NSDictionary *)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points tolerance:(double)tolerance;
+ (void)warmUpRecognition;
@end

@interface AnClickOCR : NSObject
+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode useRegex:(BOOL)useRegex;
+ (void)warmUpRecognition;
@end

@interface AnClickRecognitionService ()
@property (nonatomic) dispatch_queue_t queue;
@property (atomic, assign) NSUInteger cancellationGeneration;
@property (atomic, assign) NSUInteger latestRequestToken;
@end

@implementation AnClickRecognitionService

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.anclick.recognition", DISPATCH_QUEUE_SERIAL);
        dispatch_async(_queue, ^{
            @autoreleasepool {
                [AnClickCore warmUpRecognition];
                [AnClickOCR warmUpRecognition];
            }
        });
    }
    return self;
}

- (void)prewarmWithCompletion:(void (^)(void))completion {
    dispatch_async(_queue, ^{
        @autoreleasepool {
            [AnClickCore warmUpRecognition];
            [AnClickOCR warmUpRecognition];
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
    });
}

- (NSUInteger)beginRequestToken {
    @synchronized (self) {
        self.latestRequestToken += 1;
        if (self.latestRequestToken == 0) {
            self.latestRequestToken = 1;
        }
        return self.latestRequestToken;
    }
}

- (BOOL)isRequestTokenCurrent:(NSUInteger)token {
    return token == self.latestRequestToken;
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
    NSUInteger requestToken = [self beginRequestToken];
    if (!templateImage) {
        [self completeOnMain:completion match:nil generation:self.cancellationGeneration];
        return;
    }
    NSUInteger generation = self.cancellationGeneration;
    dispatch_async(_queue, ^{
        @autoreleasepool {
            if (![self isGenerationCurrent:generation] || ![self isRequestTokenCurrent:requestToken]) {
                return;
            }
            NSDictionary *match = [AnClickCore findTemplateImageMatch:templateImage threshold:threshold];
            if (![self isGenerationCurrent:generation] || ![self isRequestTokenCurrent:requestToken]) {
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
    NSUInteger requestToken = [self beginRequestToken];
    if (targetText.length == 0) {
        [self completeOnMain:completion match:nil generation:self.cancellationGeneration];
        return;
    }
    NSUInteger generation = self.cancellationGeneration;
    dispatch_async(_queue, ^{
        @autoreleasepool {
            if (![self isGenerationCurrent:generation] || ![self isRequestTokenCurrent:requestToken]) {
                return;
            }
            NSDictionary *match = [AnClickOCR findText:targetText mode:mode useRegex:useRegex];
            if (![self isGenerationCurrent:generation] || ![self isRequestTokenCurrent:requestToken]) {
                return;
            }
            [self completeOnMain:completion match:match generation:generation];
        }
    });
}

- (void)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points
                              tolerance:(double)tolerance
                             completion:(AnClickRecognitionMatchCompletion)completion {
    NSUInteger requestToken = [self beginRequestToken];
    if (points.count == 0) {
        [self completeOnMain:completion match:nil generation:self.cancellationGeneration];
        return;
    }
    NSUInteger generation = self.cancellationGeneration;
    dispatch_async(_queue, ^{
        @autoreleasepool {
            if (![self isGenerationCurrent:generation] || ![self isRequestTokenCurrent:requestToken]) {
                return;
            }
            NSDictionary *match = [AnClickCore findColorPatternMatchWithPoints:points tolerance:tolerance];
            if (![self isGenerationCurrent:generation] || ![self isRequestTokenCurrent:requestToken]) {
                return;
            }
            [self completeOnMain:completion match:match generation:generation];
        }
    });
}

- (void)cancelPendingRequests {
    self.cancellationGeneration = self.cancellationGeneration + 1;
    @synchronized (self) {
        self.latestRequestToken += 1;
        if (self.latestRequestToken == 0) {
            self.latestRequestToken = 1;
        }
    }
}

@end
