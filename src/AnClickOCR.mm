#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>
#import <ImageIO/ImageIO.h>

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
@end

@interface AnClickOCR : NSObject
+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode;
+ (NSString *)backendNameForMode:(NSInteger)mode;
@end

@implementation AnClickOCR

+ (NSString *)backendNameForMode:(NSInteger)mode {
    return mode == 1 ? @"精准" : @"快速";
}

+ (NSString *)normalizedText:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray<NSString *> *parts = [trimmed componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return [[parts componentsJoinedByString:@""] lowercaseString];
}

+ (CGImagePropertyOrientation)cgImageOrientationForUIImage:(UIImage *)image {
    switch (image.imageOrientation) {
        case UIImageOrientationUp:
            return kCGImagePropertyOrientationUp;
        case UIImageOrientationDown:
            return kCGImagePropertyOrientationDown;
        case UIImageOrientationLeft:
            return kCGImagePropertyOrientationLeft;
        case UIImageOrientationRight:
            return kCGImagePropertyOrientationRight;
        case UIImageOrientationUpMirrored:
            return kCGImagePropertyOrientationUpMirrored;
        case UIImageOrientationDownMirrored:
            return kCGImagePropertyOrientationDownMirrored;
        case UIImageOrientationLeftMirrored:
            return kCGImagePropertyOrientationLeftMirrored;
        case UIImageOrientationRightMirrored:
            return kCGImagePropertyOrientationRightMirrored;
    }
    return kCGImagePropertyOrientationUp;
}

+ (CGRect)screenRectForObservation:(VNRecognizedTextObservation *)observation image:(UIImage *)image {
    CGRect box = observation.boundingBox;
    CGSize imageSize = image.size;
    return CGRectMake(box.origin.x * imageSize.width,
                      (1.0 - box.origin.y - box.size.height) * imageSize.height,
                      box.size.width * imageSize.width,
                      box.size.height * imageSize.height);
}

+ (void)configureRecognitionLanguagesForRequest:(VNRecognizeTextRequest *)request level:(VNRequestTextRecognitionLevel)level {
    NSError *error = nil;
    NSArray<NSString *> *supported = [VNRecognizeTextRequest supportedRecognitionLanguagesForTextRecognitionLevel:level
                                                                                                         revision:request.revision
                                                                                                            error:&error];
    if (supported.count == 0) {
        return;
    }

    NSArray<NSString *> *preferred = @[@"zh-Hans", @"zh-Hant", @"en-US"];
    NSMutableArray<NSString *> *languages = [NSMutableArray array];
    for (NSString *language in preferred) {
        if ([supported containsObject:language]) {
            [languages addObject:language];
        }
    }
    if (languages.count > 0) {
        request.recognitionLanguages = languages;
    }
}

+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode {
    NSString *target = [self normalizedText:targetText];
    if (target.length == 0) {
        return @{@"error": @"文字未填写"};
    }

    UIImage *image = [AnClickCore captureCurrentWindowImage];
    if (!image.CGImage) {
        return @{@"error": @"截图失败"};
    }

    VNRequestTextRecognitionLevel level = mode == 1 ? VNRequestTextRecognitionLevelAccurate : VNRequestTextRecognitionLevelFast;
    __block NSArray<VNRecognizedTextObservation *> *observations = @[];
    VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *finishedRequest, NSError *requestError) {
        if (requestError) {
            observations = @[];
            return;
        }
        NSArray *results = finishedRequest.results;
        observations = [results isKindOfClass:NSArray.class] ? results : @[];
    }];
    request.recognitionLevel = level;
    request.usesLanguageCorrection = (mode == 1);
    [self configureRecognitionLanguagesForRequest:request level:level];

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image.CGImage
                                                                        orientation:[self cgImageOrientationForUIImage:image]
                                                                            options:@{}];
    NSError *performError = nil;
    if (![handler performRequests:@[request] error:&performError]) {
        return @{@"error": @"文字识别失败"};
    }

    NSDictionary *bestMatch = nil;
    CGFloat bestScore = -1.0;
    for (VNRecognizedTextObservation *observation in observations) {
        VNRecognizedText *candidate = [observation topCandidates:1].firstObject;
        if (!candidate.string.length) {
            continue;
        }
        NSString *recognized = [self normalizedText:candidate.string];
        if ([recognized rangeOfString:target options:NSCaseInsensitiveSearch].location == NSNotFound) {
            continue;
        }
        CGFloat score = candidate.confidence;
        if (score <= bestScore) {
            continue;
        }

        CGRect rect = [self screenRectForObservation:observation image:image];
        CGPoint point = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
        bestScore = score;
        bestMatch = @{
            @"point": [NSValue valueWithCGPoint:point],
            @"rect": [NSValue valueWithCGRect:rect],
            @"score": @(score),
            @"text": candidate.string
        };
    }

    return bestMatch ?: @{@"error": @"文字未找到"};
}

@end
