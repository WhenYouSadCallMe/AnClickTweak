#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>
#import <ImageIO/ImageIO.h>
#include <math.h>

#if ANCLICK_RELEASE_SILENT
#undef NSLog
#define NSLog(...) do {} while (0)
#endif

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (UIImage *)captureCurrentWindowImageWithWindow:(UIWindow **)capturedWindow;
@end

@interface AnClickOCR : NSObject
+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode;
+ (NSDictionary *)findText:(NSString *)targetText mode:(NSInteger)mode useRegex:(BOOL)useRegex;
+ (NSString *)backendNameForMode:(NSInteger)mode;
@end

@implementation AnClickOCR

+ (NSString *)backendNameForMode:(__unused NSInteger)mode {
    return @"文字识别";
}

+ (NSString *)normalizedText:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    trimmed = [[trimmed stringByFoldingWithOptions:(NSWidthInsensitiveSearch | NSDiacriticInsensitiveSearch)
                                           locale:nil] lowercaseString];
    NSArray<NSString *> *parts = [trimmed componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return [parts componentsJoinedByString:@""];
}

+ (NSString *)normalizedRegexPattern:(NSString *)pattern {
    NSString *trimmed = [pattern stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return [trimmed stringByFoldingWithOptions:NSWidthInsensitiveSearch locale:nil];
}

+ (NSString *)targetTextByRemovingRegexPrefix:(NSString *)targetText detectedRegex:(BOOL *)detectedRegex {
    NSString *trimmed = [targetText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray<NSString *> *prefixes = @[@"re:", @"regex:", @"正则:", @"re：", @"regex：", @"正则："];
    for (NSString *prefix in prefixes) {
        if ([trimmed rangeOfString:prefix options:NSCaseInsensitiveSearch].location == 0) {
            if (detectedRegex) {
                *detectedRegex = YES;
            }
            return [[trimmed substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        }
    }
    return trimmed;
}

+ (NSDictionary *)normalizedTextMapForString:(NSString *)string {
    NSMutableString *normalized = [NSMutableString string];
    NSMutableArray<NSValue *> *sourceRanges = [NSMutableArray array];
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
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
    return @{
        @"text": normalized,
        @"ranges": sourceRanges,
    };
}

+ (NSRange)sourceRangeForNormalizedRange:(NSRange)normalizedRange sourceRanges:(NSArray<NSValue *> *)sourceRanges {
    if (normalizedRange.location == NSNotFound ||
        normalizedRange.length == 0 ||
        NSMaxRange(normalizedRange) > sourceRanges.count) {
        return NSMakeRange(NSNotFound, 0);
    }

    NSRange startRange = sourceRanges[normalizedRange.location].rangeValue;
    NSRange endRange = sourceRanges[NSMaxRange(normalizedRange) - 1].rangeValue;
    return NSMakeRange(startRange.location, NSMaxRange(endRange) - startRange.location);
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

+ (UIImage *)imageByAddingRecognitionEdgePadding:(UIImage *)image contentOffset:(CGPoint *)contentOffset {
    if (contentOffset) {
        *contentOffset = CGPointZero;
    }
    if (!image.CGImage || image.size.width <= 0.0 || image.size.height <= 0.0) {
        return image;
    }

    CGFloat shortestSide = MIN(image.size.width, image.size.height);
    CGFloat padding = MIN(24.0, MAX(8.0, floor(shortestSide * 0.03)));
    if (padding <= 0.0) {
        return image;
    }

    CGSize paddedSize = CGSizeMake(image.size.width + padding * 2.0,
                                   image.size.height + padding * 2.0);
    UIGraphicsBeginImageContextWithOptions(paddedSize, NO, image.scale > 0.0 ? image.scale : UIScreen.mainScreen.scale);
    [[UIColor clearColor] setFill];
    UIRectFill(CGRectMake(0, 0, paddedSize.width, paddedSize.height));
    [image drawInRect:CGRectMake(padding, padding, image.size.width, image.size.height)];
    UIImage *paddedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (!paddedImage.CGImage) {
        return image;
    }
    if (contentOffset) {
        *contentOffset = CGPointMake(padding, padding);
    }
    return paddedImage;
}

+ (UIImage *)imageByIncreasingPixelDensity:(UIImage *)image multiplier:(CGFloat)multiplier {
    if (!image.CGImage || image.size.width <= 0.0 || image.size.height <= 0.0 || multiplier <= 1.0) {
        return nil;
    }

    CGFloat baseScale = image.scale > 0.0 ? image.scale : UIScreen.mainScreen.scale;
    CGFloat targetScale = MIN(baseScale * multiplier, 6.0);
    UIGraphicsBeginImageContextWithOptions(image.size, NO, targetScale);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *denseImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return denseImage.CGImage ? denseImage : nil;
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
    if (CGRectIsNull(imageRect) || CGRectIsEmpty(imageRect)) {
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

    NSDictionary *map = [self normalizedTextMapForString:recognizedString];
    NSString *normalized = map[@"text"];
    NSArray<NSValue *> *sourceRanges = map[@"ranges"];

    NSRange normalizedRange = [normalized rangeOfString:target options:options];
    if (normalizedRange.location == NSNotFound || NSMaxRange(normalizedRange) > sourceRanges.count) {
        return NSMakeRange(NSNotFound, 0);
    }

    return [self sourceRangeForNormalizedRange:normalizedRange sourceRanges:sourceRanges];
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

+ (NSInteger)matchRankForRecognizedText:(NSString *)recognized target:(NSString *)target {
    if (recognized.length == 0 || target.length == 0) {
        return 0;
    }
    if ([recognized isEqualToString:target]) {
        return 4;
    }
    if ([recognized hasSuffix:target] || [recognized hasPrefix:target]) {
        return 3;
    }
    if ([recognized rangeOfString:target options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return 2;
    }
    return 1;
}

+ (CGFloat)matchScoreForRank:(NSInteger)rank specificity:(CGFloat)specificity confidence:(CGFloat)confidence {
    CGFloat rankScore = 0.0;
    if (rank >= 4) {
        rankScore = 1.0;
    } else if (rank == 3) {
        rankScore = 0.95;
    } else if (rank == 2) {
        rankScore = 0.90;
    } else if (rank == 1) {
        rankScore = MAX(0.0, MIN(0.75, specificity));
    }
    return MIN(1.0, MAX(confidence, rankScore));
}

+ (CGRect)clippedImageRect:(CGRect)rect image:(UIImage *)image {
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect) || image.size.width <= 0.0 || image.size.height <= 0.0) {
        return CGRectNull;
    }
    CGRect imageBounds = CGRectMake(0, 0, image.size.width, image.size.height);
    CGRect clippedRect = CGRectIntersection(CGRectStandardize(rect), imageBounds);
    if (CGRectIsNull(clippedRect) || CGRectIsEmpty(clippedRect) || clippedRect.size.width <= 0.5 || clippedRect.size.height <= 0.5) {
        return CGRectNull;
    }
    return CGRectStandardize(clippedRect);
}

+ (CGRect)clippedRect:(CGRect)rect toImageSize:(CGSize)imageSize {
    if (CGRectIsNull(rect) || CGRectIsEmpty(rect) || imageSize.width <= 0.0 || imageSize.height <= 0.0) {
        return CGRectNull;
    }
    CGRect imageBounds = CGRectMake(0, 0, imageSize.width, imageSize.height);
    CGRect clippedRect = CGRectIntersection(CGRectStandardize(rect), imageBounds);
    if (CGRectIsNull(clippedRect) || CGRectIsEmpty(clippedRect) || clippedRect.size.width <= 0.5 || clippedRect.size.height <= 0.5) {
        return CGRectNull;
    }
    return CGRectStandardize(clippedRect);
}

+ (CGRect)sourceImageRectForRecognitionRect:(CGRect)recognitionRect
                            sourceImageSize:(CGSize)sourceImageSize
                              contentOffset:(CGPoint)contentOffset {
    if (CGRectIsNull(recognitionRect) || CGRectIsEmpty(recognitionRect)) {
        return CGRectNull;
    }
    CGRect sourceRect = CGRectOffset(recognitionRect, -contentOffset.x, -contentOffset.y);
    return [self clippedRect:sourceRect toImageSize:sourceImageSize];
}

+ (BOOL)targetRect:(CGRect)targetRect isSpecificAgainstObservationRect:(CGRect)observationRect target:(NSString *)target recognized:(NSString *)recognized {
    if (CGRectIsNull(targetRect) || CGRectIsEmpty(targetRect) || CGRectIsNull(observationRect) || CGRectIsEmpty(observationRect)) {
        return NO;
    }

    if ([recognized isEqualToString:target]) {
        return YES;
    }

    CGFloat widthRatio = CGRectGetWidth(observationRect) > 0.0 ? CGRectGetWidth(targetRect) / CGRectGetWidth(observationRect) : 1.0;
    CGFloat heightRatio = CGRectGetHeight(observationRect) > 0.0 ? CGRectGetHeight(targetRect) / CGRectGetHeight(observationRect) : 1.0;
    return widthRatio < 0.92 || heightRatio < 0.92;
}

+ (CGRect)imageRectForCharacterBoxesInRange:(NSRange)targetRange
                                  candidate:(VNRecognizedText *)candidate
                                      image:(UIImage *)image {
    if (targetRange.location == NSNotFound || targetRange.length == 0 || NSMaxRange(targetRange) > candidate.string.length) {
        return CGRectNull;
    }

    __block CGRect unionBox = CGRectNull;
    __block NSUInteger usableBoxCount = 0;
    [candidate.string enumerateSubstringsInRange:targetRange
                                         options:NSStringEnumerationByComposedCharacterSequences
                                      usingBlock:^(NSString *substring, NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop) {
        if ([self normalizedText:substring ?: @""].length == 0) {
            return;
        }
        NSError *boxError = nil;
        VNRectangleObservation *characterBox = [candidate boundingBoxForRange:substringRange error:&boxError];
        if (!characterBox || CGRectIsEmpty(characterBox.boundingBox)) {
            return;
        }
        unionBox = CGRectIsNull(unionBox) ? characterBox.boundingBox : CGRectUnion(unionBox, characterBox.boundingBox);
        usableBoxCount++;
    }];

    if (usableBoxCount == 0 || CGRectIsNull(unionBox) || CGRectIsEmpty(unionBox)) {
        return CGRectNull;
    }

    return [self clippedImageRect:[self imageRectForNormalizedBox:unionBox image:image] image:image];
}

+ (CGRect)imageRectForCandidate:(VNRecognizedText *)candidate
                      textRange:(NSRange)targetRange
                    exactTarget:(NSString *)target
                    observation:(VNRecognizedTextObservation *)observation
                          image:(UIImage *)image {
    CGRect fallbackRect = [self clippedImageRect:[self imageRectForObservation:observation image:image] image:image];
    if (!candidate.string.length ||
        targetRange.location == NSNotFound ||
        targetRange.length == 0 ||
        NSMaxRange(targetRange) > candidate.string.length) {
        return fallbackRect;
    }

    if (@available(iOS 13.0, *)) {
        NSString *recognized = [self normalizedText:candidate.string];
        CGRect characterRect = [self imageRectForCharacterBoxesInRange:targetRange candidate:candidate image:image];
        if ([self targetRect:characterRect isSpecificAgainstObservationRect:fallbackRect target:target recognized:recognized]) {
            return characterRect;
        }

        NSError *rangeError = nil;
        VNRectangleObservation *targetBox = [candidate boundingBoxForRange:targetRange error:&rangeError];
        if (targetBox && !CGRectIsEmpty(targetBox.boundingBox)) {
            CGRect targetRect = [self clippedImageRect:[self imageRectForNormalizedBox:targetBox.boundingBox image:image] image:image];
            if ([self targetRect:targetRect isSpecificAgainstObservationRect:fallbackRect target:target recognized:recognized]) {
                return targetRect;
            }
        }

        CGRect estimatedRect = [self estimatedImageRectForRange:targetRange
                                            inRecognizedString:candidate.string
                                               observationRect:fallbackRect];
        CGRect clippedEstimatedRect = [self clippedImageRect:estimatedRect image:image];
        return CGRectIsNull(clippedEstimatedRect) ? fallbackRect : clippedEstimatedRect;
    }

    return fallbackRect;
}

+ (CGRect)imageRectForCandidate:(VNRecognizedText *)candidate
                         target:(NSString *)target
                    observation:(VNRecognizedTextObservation *)observation
                          image:(UIImage *)image {
    NSRange targetRange = [self rangeOfNormalizedTarget:target inRecognizedString:candidate.string];
    return [self imageRectForCandidate:candidate textRange:targetRange exactTarget:target observation:observation image:image];
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
                        sourceImageSize:(CGSize)sourceImageSize
                          contentOffset:(CGPoint)contentOffset
                                 level:(VNRequestTextRecognitionLevel)level
                    languageCorrection:(BOOL)languageCorrection
                              fallback:(BOOL)fallback
                              useRegex:(BOOL)useRegex {
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
    CGFloat bestSpecificity = -1.0;
    CGFloat bestArea = CGFLOAT_MAX;
    NSInteger bestRank = -1;
    CGFloat bestY = CGFLOAT_MAX;
    CGFloat bestX = CGFLOAT_MAX;
    NSInteger validMatchCount = 0;
    NSRegularExpression *regex = nil;
    if (useRegex) {
        NSError *regexError = nil;
        regex = [NSRegularExpression regularExpressionWithPattern:target
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&regexError];
        if (!regex || regexError) {
            return @{@"error": @"正则表达式无效"};
        }
    }
    for (VNRecognizedTextObservation *observation in observations) {
        NSArray<VNRecognizedText *> *textCandidates = [observation topCandidates:3];
        for (VNRecognizedText *candidate in textCandidates) {
            if (!candidate.string.length) {
                continue;
            }
            NSString *recognized = [self normalizedText:candidate.string];
            NSMutableArray<NSDictionary *> *candidateMatches = [NSMutableArray array];
            if (useRegex) {
                NSDictionary *map = [self normalizedTextMapForString:candidate.string];
                NSString *normalizedCandidate = map[@"text"];
                NSArray<NSValue *> *sourceRanges = map[@"ranges"];
                if (normalizedCandidate.length == 0) {
                    continue;
                }
                NSArray<NSTextCheckingResult *> *regexMatches = [regex matchesInString:normalizedCandidate
                                                                                options:0
                                                                                  range:NSMakeRange(0, normalizedCandidate.length)];
                for (NSTextCheckingResult *regexMatch in regexMatches) {
                    if (!regexMatch || regexMatch.range.location == NSNotFound || regexMatch.range.length == 0) {
                        continue;
                    }
                    NSRange normalizedMatchRange = regexMatch.range;
                    NSRange sourceRange = [self sourceRangeForNormalizedRange:normalizedMatchRange sourceRanges:sourceRanges];
                    if (sourceRange.location == NSNotFound || sourceRange.length == 0 || NSMaxRange(sourceRange) > candidate.string.length) {
                        continue;
                    }
                    NSString *matchedText = [candidate.string substringWithRange:sourceRange];
                    NSString *matchedNormalizedText = [normalizedCandidate substringWithRange:normalizedMatchRange];
                    NSInteger rank = 2;
                    if (normalizedMatchRange.location == 0 && NSMaxRange(normalizedMatchRange) == normalizedCandidate.length) {
                        rank = 4;
                    } else if (normalizedMatchRange.location == 0 || NSMaxRange(normalizedMatchRange) == normalizedCandidate.length) {
                        rank = 3;
                    }
                    CGFloat specificity = (CGFloat)normalizedMatchRange.length / (CGFloat)MAX((NSUInteger)1, normalizedCandidate.length);
                    [candidateMatches addObject:@{
                        @"range": [NSValue valueWithRange:sourceRange],
                        @"text": matchedText,
                        @"normalized": matchedNormalizedText,
                        @"rank": @(rank),
                        @"specificity": @(specificity),
                    }];
                }
            } else {
                NSDictionary *map = [self normalizedTextMapForString:candidate.string];
                NSString *normalizedCandidate = map[@"text"];
                NSArray<NSValue *> *sourceRanges = map[@"ranges"];
                if (normalizedCandidate.length == 0) {
                    continue;
                }
                NSRange searchRange = NSMakeRange(0, normalizedCandidate.length);
                while (searchRange.length > 0) {
                    NSRange normalizedMatchRange = [normalizedCandidate rangeOfString:target
                                                                               options:NSCaseInsensitiveSearch
                                                                                 range:searchRange];
                    if (normalizedMatchRange.location == NSNotFound || normalizedMatchRange.length == 0) {
                        break;
                    }
                    NSRange sourceRange = [self sourceRangeForNormalizedRange:normalizedMatchRange sourceRanges:sourceRanges];
                    if (sourceRange.location != NSNotFound &&
                        sourceRange.length > 0 &&
                        NSMaxRange(sourceRange) <= candidate.string.length) {
                        NSInteger rank = [self matchRankForRecognizedText:recognized target:target];
                        [candidateMatches addObject:@{
                            @"range": [NSValue valueWithRange:sourceRange],
                            @"text": [candidate.string substringWithRange:sourceRange],
                            @"normalized": target,
                            @"rank": @(rank),
                            @"specificity": @(target.length > 0 ? (CGFloat)target.length / (CGFloat)MAX((NSUInteger)1, normalizedCandidate.length) : 0.0),
                        }];
                    }

                    NSUInteger nextLocation = NSMaxRange(normalizedMatchRange);
                    if (nextLocation >= normalizedCandidate.length) {
                        break;
                    }
                    searchRange = NSMakeRange(nextLocation, normalizedCandidate.length - nextLocation);
                }
            }

            if (candidateMatches.count == 0) {
                continue;
            }

            for (NSDictionary *matchInfo in candidateMatches) {
                NSValue *rangeValue = matchInfo[@"range"];
                NSRange targetRange = rangeValue.rangeValue;
                NSString *matchedText = matchInfo[@"text"];
                NSString *matchedNormalizedText = matchInfo[@"normalized"];
                NSInteger rank = [matchInfo[@"rank"] integerValue];
                CGFloat specificity = [matchInfo[@"specificity"] doubleValue];

                CGRect imageRect = [self imageRectForCandidate:candidate
                                                     textRange:targetRange
                                                   exactTarget:matchedNormalizedText
                                                   observation:observation
                                                         image:image];
                if (CGRectIsNull(imageRect) || CGRectIsEmpty(imageRect)) {
                    continue;
                }
                CGRect sourceImageRect = [self sourceImageRectForRecognitionRect:imageRect
                                                                 sourceImageSize:sourceImageSize
                                                                   contentOffset:contentOffset];
                if (CGRectIsNull(sourceImageRect) || CGRectIsEmpty(sourceImageRect)) {
                    continue;
                }
                validMatchCount++;

                CGFloat visionConfidence = candidate.confidence;
                CGFloat score = [self matchScoreForRank:rank specificity:specificity confidence:visionConfidence];
                CGPoint clickImagePoint = CGPointMake(CGRectGetMidX(sourceImageRect), CGRectGetMidY(sourceImageRect));
                CGFloat area = CGRectGetWidth(sourceImageRect) * CGRectGetHeight(sourceImageRect);

                CGFloat minY = CGRectGetMinY(sourceImageRect);
                CGFloat minX = CGRectGetMinX(sourceImageRect);
                BOOL shouldReplace = NO;
                if (rank > bestRank) {
                    shouldReplace = YES;
                } else if (rank == bestRank && specificity > bestSpecificity + 0.001) {
                    shouldReplace = YES;
                } else if (rank == bestRank && fabs(specificity - bestSpecificity) <= 0.001 && area + 0.5 < bestArea) {
                    shouldReplace = YES;
                } else if (rank == bestRank && fabs(specificity - bestSpecificity) <= 0.001 && fabs(area - bestArea) <= 0.5 && minY + 0.5 < bestY) {
                    shouldReplace = YES;
                } else if (rank == bestRank && fabs(specificity - bestSpecificity) <= 0.001 && fabs(area - bestArea) <= 0.5 && fabs(minY - bestY) <= 0.5 && minX + 0.5 < bestX) {
                    shouldReplace = YES;
                } else if (rank == bestRank && fabs(specificity - bestSpecificity) <= 0.001 && fabs(area - bestArea) <= 0.5 && fabs(minY - bestY) <= 0.5 && fabs(minX - bestX) <= 0.5 && score > bestScore) {
                    shouldReplace = YES;
                }
                if (!shouldReplace) {
                    continue;
                }

                CGRect rect = [self screenRectFromImageRect:sourceImageRect image:image sourceWindow:sourceWindow];
                CGPoint point = sourceWindow ? [sourceWindow convertPoint:clickImagePoint toWindow:nil] : clickImagePoint;
                NSLog(@"[AnClick][OCR] target=%@ regex=%d text=%@ match=%@ score=%.2f confidence=%.2f visionRect=(%.1f, %.1f, %.1f, %.1f) screenRect=(%.1f, %.1f, %.1f, %.1f) point=(%.1f, %.1f)",
                      target,
                      useRegex,
                      candidate.string,
                      matchedText,
                      score,
                      visionConfidence,
                      sourceImageRect.origin.x,
                      sourceImageRect.origin.y,
                      sourceImageRect.size.width,
                      sourceImageRect.size.height,
                      rect.origin.x,
                      rect.origin.y,
                      rect.size.width,
                      rect.size.height,
                      point.x,
                      point.y);
                bestRank = rank;
                bestSpecificity = specificity;
                bestArea = area;
                bestScore = score;
                bestY = minY;
                bestX = minX;
                bestMatch = @{
                    @"point": [NSValue valueWithCGPoint:point],
                    @"rect": [NSValue valueWithCGRect:rect],
                    @"score": @(score),
                    @"visionConfidence": @(visionConfidence),
                    @"text": matchedText,
                    @"lineText": candidate.string,
                    @"regex": @(useRegex),
                    @"fallback": @(fallback)
                };
            }
        }
    }

    if (bestMatch) {
        NSMutableDictionary *result = [bestMatch mutableCopy];
        result[@"matchCount"] = @(validMatchCount);
        return result;
    }
    return @{@"error": @"文字识别未找到"};
}

+ (NSDictionary *)findText:(NSString *)targetText mode:(__unused NSInteger)mode {
    BOOL detectedRegex = NO;
    NSString *rawTarget = [self targetTextByRemovingRegexPrefix:targetText detectedRegex:&detectedRegex];
    return [self findText:rawTarget mode:mode useRegex:detectedRegex];
}

+ (NSDictionary *)findText:(NSString *)targetText mode:(__unused NSInteger)mode useRegex:(BOOL)useRegex {
    NSString *rawTarget = useRegex
        ? [self targetTextByRemovingRegexPrefix:targetText detectedRegex:nil]
        : [targetText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *target = useRegex ? [self normalizedRegexPattern:rawTarget] : [self normalizedText:rawTarget];
    if (target.length == 0) {
        return @{@"error": @"文字识别未填写"};
    }

    NSArray<NSDictionary *> *primaryAttempts = @[
        @{@"level": @(VNRequestTextRecognitionLevelAccurate), @"correction": @YES, @"fallback": @NO},
    ];
    NSArray<NSDictionary *> *fallbackAttempts = @[
        @{@"level": @(VNRequestTextRecognitionLevelAccurate), @"correction": @NO, @"fallback": @YES},
        @{@"level": @(VNRequestTextRecognitionLevelFast), @"correction": @YES, @"fallback": @YES},
    ];
    NSDictionary *lastResult = nil;

    for (NSUInteger frameAttempt = 0; frameAttempt < 2; frameAttempt++) {
        UIWindow *sourceWindow = nil;
        UIImage *image = [AnClickCore captureCurrentWindowImageWithWindow:&sourceWindow];
        if (!image.CGImage) {
            lastResult = @{@"error": @"截图失败"};
        } else {
            CGPoint contentOffset = CGPointZero;
            CGSize sourceImageSize = image.size;
            UIImage *recognitionImage = [self imageByAddingRecognitionEdgePadding:image contentOffset:&contentOffset] ?: image;
            for (NSDictionary *attempt in primaryAttempts) {
                NSDictionary *result = [self matchNormalizedText:target
                                                         inImage:recognitionImage
                                                    sourceWindow:sourceWindow
                                                 sourceImageSize:sourceImageSize
                                                   contentOffset:contentOffset
                                                           level:(VNRequestTextRecognitionLevel)[attempt[@"level"] integerValue]
                                              languageCorrection:[attempt[@"correction"] boolValue]
                                                        fallback:[attempt[@"fallback"] boolValue]
                                                        useRegex:useRegex];
                NSString *error = [result[@"error"] isKindOfClass:NSString.class] ? result[@"error"] : nil;
                if (error.length == 0) {
                    return result;
                }
                lastResult = result;
                if (![error isEqualToString:@"文字识别未找到"]) {
                    break;
                }
            }
            if (lastResult && [[lastResult[@"error"] description] isEqualToString:@"文字识别未找到"]) {
                for (NSDictionary *attempt in fallbackAttempts) {
                    NSDictionary *result = [self matchNormalizedText:target
                                                             inImage:recognitionImage
                                                        sourceWindow:sourceWindow
                                                     sourceImageSize:sourceImageSize
                                                       contentOffset:contentOffset
                                                               level:(VNRequestTextRecognitionLevel)[attempt[@"level"] integerValue]
                                                  languageCorrection:[attempt[@"correction"] boolValue]
                                                            fallback:[attempt[@"fallback"] boolValue]
                                                            useRegex:useRegex];
                    NSString *error = [result[@"error"] isKindOfClass:NSString.class] ? result[@"error"] : nil;
                    if (error.length == 0) {
                        return result;
                    }
                    lastResult = result;
                    if (![error isEqualToString:@"文字识别未找到"]) {
                        break;
                    }
                }
            }
            if (lastResult && [[lastResult[@"error"] description] isEqualToString:@"文字识别未找到"]) {
                UIImage *denseImage = [self imageByIncreasingPixelDensity:recognitionImage multiplier:2.0] ?: recognitionImage;
                if (denseImage != recognitionImage) {
                    for (NSDictionary *attempt in fallbackAttempts) {
                        NSDictionary *result = [self matchNormalizedText:target
                                                                 inImage:denseImage
                                                            sourceWindow:sourceWindow
                                                         sourceImageSize:sourceImageSize
                                                           contentOffset:contentOffset
                                                                   level:(VNRequestTextRecognitionLevel)[attempt[@"level"] integerValue]
                                                      languageCorrection:[attempt[@"correction"] boolValue]
                                                                fallback:[attempt[@"fallback"] boolValue]
                                                                useRegex:useRegex];
                        NSString *error = [result[@"error"] isKindOfClass:NSString.class] ? result[@"error"] : nil;
                        if (error.length == 0) {
                            return result;
                        }
                        lastResult = result;
                        if (![error isEqualToString:@"文字识别未找到"]) {
                            break;
                        }
                    }
                }
            }
        }

        NSString *lastError = [lastResult[@"error"] isKindOfClass:NSString.class] ? lastResult[@"error"] : nil;
        BOOL retryable = [lastError isEqualToString:@"文字识别未找到"] || [lastError isEqualToString:@"截图失败"];
        if (!retryable || frameAttempt >= 1) {
            break;
        }
        [NSThread sleepForTimeInterval:0.05];
    }
    return lastResult ?: @{@"error": @"文字识别未找到"};
}

@end
