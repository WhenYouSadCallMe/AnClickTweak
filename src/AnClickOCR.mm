#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>
#import <ImageIO/ImageIO.h>

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (UIImage *)captureCurrentWindowImageWithWindow:(UIWindow **)capturedWindow;
@end

@interface AnClickOCR : NSObject
+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode;
+ (NSString *)backendNameForMode:(NSInteger)mode;
@end

@implementation AnClickOCR

+ (NSString *)backendNameForMode:(__unused NSInteger)mode {
    return @"文字识别";
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

+ (CGRect)imageRectForNormalizedBox:(CGRect)box image:(UIImage *)image {
    CGSize imageSize = image.size;
    CGRect rect = CGRectMake(box.origin.x * imageSize.width,
                             (1.0 - box.origin.y - box.size.height) * imageSize.height,
                             box.size.width * imageSize.width,
                             box.size.height * imageSize.height);
    return CGRectStandardize(rect);
}

+ (CGRect)imageRectForObservation:(VNRecognizedTextObservation *)observation image:(UIImage *)image {
    return [self imageRectForNormalizedBox:observation.boundingBox image:image];
}

+ (CGRect)screenRectFromImageRect:(CGRect)imageRect image:(UIImage *)image sourceWindow:(UIWindow *)sourceWindow {
    if (CGRectIsEmpty(imageRect)) {
        return CGRectZero;
    }

    CGPoint topLeftWindowPoint = imageRect.origin;
    CGPoint bottomRightWindowPoint = CGPointMake(CGRectGetMaxX(imageRect),
                                                 CGRectGetMaxY(imageRect));
    CGPoint topLeftScreenPoint = sourceWindow ? [sourceWindow convertPoint:topLeftWindowPoint toWindow:nil] : topLeftWindowPoint;
    CGPoint bottomRightScreenPoint = sourceWindow ? [sourceWindow convertPoint:bottomRightWindowPoint toWindow:nil] : bottomRightWindowPoint;
    return CGRectStandardize(CGRectMake(topLeftScreenPoint.x,
                                        topLeftScreenPoint.y,
                                        bottomRightScreenPoint.x - topLeftScreenPoint.x,
                                        bottomRightScreenPoint.y - topLeftScreenPoint.y));
}

+ (NSRange)rangeOfNormalizedTarget:(NSString *)target inRecognizedString:(NSString *)recognizedString {
    if (target.length == 0 || recognizedString.length == 0) {
        return NSMakeRange(NSNotFound, 0);
    }

    NSStringCompareOptions options = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    NSRange directRange = [recognizedString rangeOfString:target options:options];
    if (directRange.location != NSNotFound) {
        return directRange;
    }

    NSMutableString *normalized = [NSMutableString string];
    NSMutableArray<NSValue *> *sourceRanges = [NSMutableArray array];
    [recognizedString enumerateSubstringsInRange:NSMakeRange(0, recognizedString.length)
                                         options:NSStringEnumerationByComposedCharacterSequences
                                      usingBlock:^(NSString *substring, NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop) {
        NSString *piece = [self normalizedText:substring ?: @""];
        if (piece.length == 0) {
            return;
        }
        [normalized appendString:piece];
        for (NSUInteger i = 0; i < piece.length; i++) {
            [sourceRanges addObject:[NSValue valueWithRange:substringRange]];
        }
    }];

    NSRange normalizedRange = [normalized rangeOfString:target options:options];
    if (normalizedRange.location == NSNotFound || NSMaxRange(normalizedRange) > sourceRanges.count) {
        return NSMakeRange(NSNotFound, 0);
    }

    NSRange startRange = sourceRanges[normalizedRange.location].rangeValue;
    NSRange endRange = sourceRanges[NSMaxRange(normalizedRange) - 1].rangeValue;
    return NSMakeRange(startRange.location, NSMaxRange(endRange) - startRange.location);
}

+ (CGFloat)layoutWeightForSubstring:(NSString *)substring {
    if (substring.length == 0) {
        return 0.0;
    }
    if ([substring rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) {
        return 0.35;
    }
    unichar ch = [substring characterAtIndex:0];
    if ([[NSCharacterSet punctuationCharacterSet] characterIsMember:ch]) {
        return 0.45;
    }
    if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:ch]) {
        return 0.65;
    }
    return 1.0;
}

+ (CGRect)estimatedImageRectForRange:(NSRange)targetRange
                  inRecognizedString:(NSString *)recognizedString
                     observationRect:(CGRect)observationRect {
    if (targetRange.location == NSNotFound || targetRange.length == 0 || CGRectIsEmpty(observationRect) || recognizedString.length == 0) {
        return observationRect;
    }

    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSMutableArray<NSNumber *> *weights = [NSMutableArray array];
    __block CGFloat totalWeight = 0.0;
    [recognizedString enumerateSubstringsInRange:NSMakeRange(0, recognizedString.length)
                                         options:NSStringEnumerationByComposedCharacterSequences
                                      usingBlock:^(NSString *substring, NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop) {
        CGFloat weight = [self layoutWeightForSubstring:substring ?: @""];
        [ranges addObject:[NSValue valueWithRange:substringRange]];
        [weights addObject:@(weight)];
        totalWeight += weight;
    }];

    if (ranges.count == 0 || totalWeight <= 0.0) {
        return observationRect;
    }

    CGFloat startWeight = 0.0;
    CGFloat targetWeight = 0.0;
    for (NSUInteger i = 0; i < ranges.count; i++) {
        NSRange currentRange = ranges[i].rangeValue;
        CGFloat currentWeight = weights[i].doubleValue;
        if (NSMaxRange(currentRange) <= targetRange.location) {
            startWeight += currentWeight;
            continue;
        }
        if (currentRange.location >= NSMaxRange(targetRange)) {
            break;
        }
        targetWeight += currentWeight;
    }

    if (targetWeight <= 0.0) {
        return observationRect;
    }

    CGFloat startFraction = MIN(MAX(startWeight / totalWeight, 0.0), 1.0);
    CGFloat endFraction = MIN(MAX((startWeight + targetWeight) / totalWeight, startFraction), 1.0);
    BOOL horizontal = observationRect.size.width >= observationRect.size.height;
    if (horizontal) {
        CGFloat paddingX = MAX(1.0, observationRect.size.width * 0.02);
        CGFloat paddingY = MAX(1.0, observationRect.size.height * 0.12);
        CGFloat minX = CGRectGetMinX(observationRect) + observationRect.size.width * startFraction + paddingX;
        CGFloat maxX = CGRectGetMinX(observationRect) + observationRect.size.width * endFraction - paddingX;
        if (maxX <= minX) {
            maxX = minX + MAX(4.0, observationRect.size.width * 0.08);
        }
        return CGRectStandardize(CGRectMake(minX,
                                            CGRectGetMinY(observationRect) + paddingY,
                                            maxX - minX,
                                            MAX(4.0, observationRect.size.height - paddingY * 2.0)));
    }

    CGFloat paddingX = MAX(1.0, observationRect.size.width * 0.12);
    CGFloat paddingY = MAX(1.0, observationRect.size.height * 0.02);
    CGFloat minY = CGRectGetMinY(observationRect) + observationRect.size.height * startFraction + paddingY;
    CGFloat maxY = CGRectGetMinY(observationRect) + observationRect.size.height * endFraction - paddingY;
    if (maxY <= minY) {
        maxY = minY + MAX(4.0, observationRect.size.height * 0.08);
    }
    return CGRectStandardize(CGRectMake(CGRectGetMinX(observationRect) + paddingX,
                                        minY,
                                        MAX(4.0, observationRect.size.width - paddingX * 2.0),
                                        maxY - minY));
}

+ (CGRect)imageRectForCandidate:(VNRecognizedText *)candidate
                         target:(NSString *)target
                    observation:(VNRecognizedTextObservation *)observation
                          image:(UIImage *)image {
    CGRect fallbackRect = [self imageRectForObservation:observation image:image];
    if (!candidate.string.length) {
        return fallbackRect;
    }

    if (@available(iOS 13.0, *)) {
        NSRange targetRange = [self rangeOfNormalizedTarget:target inRecognizedString:candidate.string];
        if (targetRange.location != NSNotFound && targetRange.length > 0 && NSMaxRange(targetRange) <= candidate.string.length) {
            NSError *rangeError = nil;
            VNRectangleObservation *targetBox = [candidate boundingBoxForRange:targetRange error:&rangeError];
            CGRect normalizedBox = targetBox.boundingBox;
            if (targetBox && !CGRectIsEmpty(normalizedBox)) {
                CGRect targetRect = [self imageRectForNormalizedBox:normalizedBox image:image];
                CGFloat widthRatio = CGRectGetWidth(fallbackRect) > 0.0 ? CGRectGetWidth(targetRect) / CGRectGetWidth(fallbackRect) : 1.0;
                CGFloat heightRatio = CGRectGetHeight(fallbackRect) > 0.0 ? CGRectGetHeight(targetRect) / CGRectGetHeight(fallbackRect) : 1.0;
                BOOL looksSpecificEnough = widthRatio < 0.92 || heightRatio < 0.92;
                if (targetRect.size.width > 0.5 && targetRect.size.height > 0.5 && looksSpecificEnough) {
                    return targetRect;
                }
            }

            return [self estimatedImageRectForRange:targetRange
                                 inRecognizedString:candidate.string
                                    observationRect:fallbackRect];
        }
    }

    return fallbackRect;
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

+ (NSDictionary *)matchNormalizedText:(NSString *)target
                               inImage:(UIImage *)image
                           sourceWindow:(UIWindow *)sourceWindow
                                 level:(VNRequestTextRecognitionLevel)level
                    languageCorrection:(BOOL)languageCorrection
                              fallback:(BOOL)fallback {
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
    request.usesLanguageCorrection = languageCorrection;
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

        CGRect imageRect = [self imageRectForCandidate:candidate target:target observation:observation image:image];
        CGRect rect = [self screenRectFromImageRect:imageRect image:image sourceWindow:sourceWindow];
        CGPoint point = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
        NSLog(@"[AnClick][OCR] target=%@ text=%@ imageRect=(%.1f, %.1f, %.1f, %.1f) screenRect=(%.1f, %.1f, %.1f, %.1f) point=(%.1f, %.1f)",
              target,
              candidate.string,
              imageRect.origin.x,
              imageRect.origin.y,
              imageRect.size.width,
              imageRect.size.height,
              rect.origin.x,
              rect.origin.y,
              rect.size.width,
              rect.size.height,
              point.x,
              point.y);
        bestScore = score;
        bestMatch = @{
            @"point": [NSValue valueWithCGPoint:point],
            @"rect": [NSValue valueWithCGRect:rect],
            @"score": @(score),
            @"text": candidate.string,
            @"fallback": @(fallback)
        };
    }

    return bestMatch ?: @{@"error": @"文字识别未找到"};
}

+ (NSDictionary *)findText:(NSString *)targetText mode:(__unused NSInteger)mode {
    NSString *target = [self normalizedText:targetText];
    if (target.length == 0) {
        return @{@"error": @"文字识别未填写"};
    }

    UIWindow *sourceWindow = nil;
    UIImage *image = [AnClickCore captureCurrentWindowImageWithWindow:&sourceWindow];
    if (!image.CGImage) {
        return @{@"error": @"截图失败"};
    }

    return [self matchNormalizedText:target
                             inImage:image
                        sourceWindow:sourceWindow
                               level:VNRequestTextRecognitionLevelAccurate
                  languageCorrection:YES
                            fallback:NO];
}

@end
