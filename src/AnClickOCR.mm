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

+ (NSData *)rgbaPixelDataForImage:(UIImage *)image
                            width:(size_t *)widthOut
                           height:(size_t *)heightOut
                      bytesPerRow:(size_t *)bytesPerRowOut {
    if (!image.CGImage) {
        return nil;
    }

    CGImageRef imageRef = image.CGImage;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    if (width == 0 || height == 0) {
        return nil;
    }

    size_t bytesPerRow = width * 4;
    NSMutableData *data = [NSMutableData dataWithLength:height * bytesPerRow];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) {
        return nil;
    }

    CGContextRef context = CGBitmapContextCreate(data.mutableBytes,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        return nil;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);

    if (widthOut) {
        *widthOut = width;
    }
    if (heightOut) {
        *heightOut = height;
    }
    if (bytesPerRowOut) {
        *bytesPerRowOut = bytesPerRow;
    }
    return data;
}

+ (NSDictionary *)foregroundMatchInImageRect:(CGRect)imageRect
                                      inImage:(UIImage *)image
                                     rgbaData:(NSData *)rgbaData
                                   pixelWidth:(size_t)pixelWidth
                                  pixelHeight:(size_t)pixelHeight
                                 bytesPerRow:(size_t)bytesPerRow {
    if (!rgbaData || CGRectIsEmpty(imageRect) || pixelWidth == 0 || pixelHeight == 0 || bytesPerRow == 0) {
        return nil;
    }

    CGFloat imageScale = image.scale > 0.0 ? image.scale : UIScreen.mainScreen.scale;
    NSInteger minX = MAX(0, (NSInteger)floor(CGRectGetMinX(imageRect) * imageScale));
    NSInteger minY = MAX(0, (NSInteger)floor(CGRectGetMinY(imageRect) * imageScale));
    NSInteger maxX = MIN((NSInteger)pixelWidth - 1, (NSInteger)ceil(CGRectGetMaxX(imageRect) * imageScale) - 1);
    NSInteger maxY = MIN((NSInteger)pixelHeight - 1, (NSInteger)ceil(CGRectGetMaxY(imageRect) * imageScale) - 1);
    if (maxX <= minX || maxY <= minY) {
        return nil;
    }

    const unsigned char *bytes = rgbaData.bytes;
    double bgR = 0.0;
    double bgG = 0.0;
    double bgB = 0.0;
    NSUInteger bgCount = 0;
    for (NSInteger y = minY; y <= maxY; y++) {
        for (NSInteger x = minX; x <= maxX; x++) {
            BOOL isBorder = (x == minX || x == maxX || y == minY || y == maxY);
            if (!isBorder) {
                continue;
            }
            const unsigned char *pixel = bytes + (y * bytesPerRow) + x * 4;
            if (pixel[3] <= 16) {
                continue;
            }
            bgR += pixel[0];
            bgG += pixel[1];
            bgB += pixel[2];
            bgCount++;
        }
    }
    if (bgCount == 0) {
        return nil;
    }
    bgR /= (double)bgCount;
    bgG /= (double)bgCount;
    bgB /= (double)bgCount;

    NSInteger fgMinX = maxX;
    NSInteger fgMinY = maxY;
    NSInteger fgMaxX = minX;
    NSInteger fgMaxY = minY;
    double sumX = 0.0;
    double sumY = 0.0;
    NSUInteger fgCount = 0;
    const double distanceThresholdSquared = 26.0 * 26.0;
    for (NSInteger y = minY; y <= maxY; y++) {
        for (NSInteger x = minX; x <= maxX; x++) {
            const unsigned char *pixel = bytes + (y * bytesPerRow) + x * 4;
            if (pixel[3] <= 24) {
                continue;
            }
            double dr = (double)pixel[0] - bgR;
            double dg = (double)pixel[1] - bgG;
            double db = (double)pixel[2] - bgB;
            double distanceSquared = dr * dr + dg * dg + db * db;
            if (distanceSquared <= distanceThresholdSquared) {
                continue;
            }
            fgMinX = MIN(fgMinX, x);
            fgMinY = MIN(fgMinY, y);
            fgMaxX = MAX(fgMaxX, x);
            fgMaxY = MAX(fgMaxY, y);
            sumX += x + 0.5;
            sumY += y + 0.5;
            fgCount++;
        }
    }

    if (fgCount < 6) {
        return nil;
    }

    CGFloat cropArea = (CGFloat)(maxX - minX + 1) * (CGFloat)(maxY - minY + 1);
    CGFloat foregroundArea = (CGFloat)(fgMaxX - fgMinX + 1) * (CGFloat)(fgMaxY - fgMinY + 1);
    if (foregroundArea >= cropArea * 0.94) {
        return nil;
    }

    CGRect refinedRect = CGRectMake((CGFloat)fgMinX / imageScale,
                                    (CGFloat)fgMinY / imageScale,
                                    (CGFloat)(fgMaxX - fgMinX + 1) / imageScale,
                                    (CGFloat)(fgMaxY - fgMinY + 1) / imageScale);
    CGPoint refinedPoint = CGPointMake((CGFloat)(sumX / (double)fgCount) / imageScale,
                                       (CGFloat)(sumY / (double)fgCount) / imageScale);
    return @{
        @"rect": [NSValue valueWithCGRect:CGRectStandardize(refinedRect)],
        @"point": [NSValue valueWithCGPoint:refinedPoint],
    };
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
    CGFloat bestSpecificity = -1.0;
    CGFloat bestArea = CGFLOAT_MAX;
    NSInteger bestRank = -1;
    size_t pixelWidth = 0;
    size_t pixelHeight = 0;
    size_t bytesPerRow = 0;
    NSData *rgbaData = [self rgbaPixelDataForImage:image
                                             width:&pixelWidth
                                            height:&pixelHeight
                                       bytesPerRow:&bytesPerRow];
    for (VNRecognizedTextObservation *observation in observations) {
        VNRecognizedText *candidate = [observation topCandidates:1].firstObject;
        if (!candidate.string.length) {
            continue;
        }
        NSString *recognized = [self normalizedText:candidate.string];
        if ([recognized rangeOfString:target options:NSCaseInsensitiveSearch].location == NSNotFound) {
            continue;
        }

        NSInteger rank = [self matchRankForRecognizedText:recognized target:target];
        CGFloat specificity = target.length > 0 ? (CGFloat)target.length / (CGFloat)MAX((NSUInteger)1, recognized.length) : 0.0;
        CGFloat score = candidate.confidence;
        CGRect imageRect = [self imageRectForCandidate:candidate target:target observation:observation image:image];
        NSDictionary *foregroundMatch = [self foregroundMatchInImageRect:imageRect
                                                                 inImage:image
                                                                rgbaData:rgbaData
                                                              pixelWidth:pixelWidth
                                                             pixelHeight:pixelHeight
                                                            bytesPerRow:bytesPerRow];
        CGRect clickImageRect = foregroundMatch ? [foregroundMatch[@"rect"] CGRectValue] : imageRect;
        CGPoint clickImagePoint = foregroundMatch ? [foregroundMatch[@"point"] CGPointValue] : CGPointMake(CGRectGetMidX(clickImageRect), CGRectGetMidY(clickImageRect));
        CGFloat area = CGRectGetWidth(clickImageRect) * CGRectGetHeight(clickImageRect);

        BOOL shouldReplace = NO;
        if (rank > bestRank) {
            shouldReplace = YES;
        } else if (rank == bestRank && specificity > bestSpecificity + 0.001) {
            shouldReplace = YES;
        } else if (rank == bestRank && fabs(specificity - bestSpecificity) <= 0.001 && area + 0.5 < bestArea) {
            shouldReplace = YES;
        } else if (rank == bestRank && fabs(specificity - bestSpecificity) <= 0.001 && fabs(area - bestArea) <= 0.5 && score > bestScore) {
            shouldReplace = YES;
        }
        if (!shouldReplace) {
            continue;
        }

        CGRect rect = [self screenRectFromImageRect:clickImageRect image:image sourceWindow:sourceWindow];
        CGPoint point = sourceWindow ? [sourceWindow convertPoint:clickImagePoint toWindow:nil] : clickImagePoint;
        NSLog(@"[AnClick][OCR] target=%@ text=%@ imageRect=(%.1f, %.1f, %.1f, %.1f) screenRect=(%.1f, %.1f, %.1f, %.1f) point=(%.1f, %.1f)",
              target,
              candidate.string,
              clickImageRect.origin.x,
              clickImageRect.origin.y,
              clickImageRect.size.width,
              clickImageRect.size.height,
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
