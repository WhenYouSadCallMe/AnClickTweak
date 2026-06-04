#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#include <dlfcn.h>
#include <float.h>
#include <math.h>
#include <vector>

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
@end

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (UIImage *)captureCurrentWindowImageWithWindow:(UIWindow **)capturedWindow;
+ (NSDictionary *)findTemplateImageMatch:(UIImage *)templateImage threshold:(double)threshold;
+ (NSDictionary *)findColorMatchWithRed:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue tolerance:(double)tolerance;
+ (NSDictionary *)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points tolerance:(double)tolerance;
+ (NSValue *)findTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
+ (BOOL)findAndTapTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
@end

static UIWindow *AnClickActiveWindow(void) {
    UIWindow *fallback = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.windowLevel >= UIWindowLevelAlert || window.hidden || window.alpha <= 0.01) {
                    continue;
                }
                if (window.isKeyWindow) {
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
    if (UIApplication.sharedApplication.keyWindow &&
        UIApplication.sharedApplication.keyWindow.windowLevel < UIWindowLevelAlert &&
        !UIApplication.sharedApplication.keyWindow.hidden &&
        UIApplication.sharedApplication.keyWindow.alpha > 0.01) {
        return UIApplication.sharedApplication.keyWindow;
    }
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.windowLevel < UIWindowLevelAlert && !window.hidden && window.alpha > 0.01) {
            return window;
        }
    }
#pragma clang diagnostic pop
    return fallback;
}

static BOOL AnClickWindowCanBeCaptured(UIWindow *window) {
    return window &&
        window.windowLevel < UIWindowLevelAlert &&
        !window.hidden &&
        window.alpha > 0.01 &&
        !CGRectIsEmpty(window.bounds);
}

static NSArray<UIWindow *> *AnClickCaptureCandidateWindows(UIWindow **primaryWindow) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    UIWindow *primary = nil;

    if (@available(iOS 13.0, *)) {
        UIWindowScene *fallbackScene = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                fallbackScene = (UIWindowScene *)scene;
                break;
            }
            if (!fallbackScene && scene.activationState == UISceneActivationStateForegroundInactive) {
                fallbackScene = (UIWindowScene *)scene;
            }
        }

        for (UIWindow *window in fallbackScene.windows) {
            if (!AnClickWindowCanBeCaptured(window)) {
                continue;
            }
            [windows addObject:window];
            if (window.isKeyWindow) {
                primary = window;
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (windows.count == 0) {
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (!AnClickWindowCanBeCaptured(window)) {
                continue;
            }
            [windows addObject:window];
            if (window.isKeyWindow) {
                primary = window;
            }
        }
    }
#pragma clang diagnostic pop

    if (!primary) {
        primary = windows.firstObject ?: AnClickActiveWindow();
    }
    if (primaryWindow) {
        *primaryWindow = primary;
    }
    return windows;
}

static UIImage *AnClickCaptureHardwareScreenImage(void) {
    typedef CGImageRef (*AnClickUIGetScreenImageFunction)(void);
    static AnClickUIGetScreenImageFunction getScreenImage = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        getScreenImage = (AnClickUIGetScreenImageFunction)dlsym(RTLD_DEFAULT, "UIGetScreenImage");
    });

    if (!getScreenImage) {
        return nil;
    }

    CGImageRef imageRef = getScreenImage();
    if (!imageRef) {
        return nil;
    }

    CGFloat scale = UIScreen.mainScreen.scale > 0 ? UIScreen.mainScreen.scale : 1.0;
    UIImage *image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(imageRef);
    return image;
}

static UIImage *AnClickCaptureActiveWindowImage(UIWindow **capturedWindow) {
    __block UIImage *image = nil;
    __block UIWindow *window = nil;
    void (^captureBlock)(void) = ^{
        UIImage *screenImage = AnClickCaptureHardwareScreenImage();
        if (screenImage.CGImage) {
            image = screenImage;
            window = nil;
            return;
        }

        NSArray<UIWindow *> *windows = AnClickCaptureCandidateWindows(&window);
        if (!window) {
            return;
        }

        CGSize size = window.bounds.size;
        CGFloat scale = UIScreen.mainScreen.scale;
        UIGraphicsBeginImageContextWithOptions(size, NO, scale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        for (UIWindow *captureWindow in windows) {
            if (!AnClickWindowCanBeCaptured(captureWindow)) {
                continue;
            }
            CGPoint origin = [captureWindow convertPoint:CGPointZero toWindow:window];
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, origin.x, origin.y);
            BOOL drawn = [captureWindow drawViewHierarchyInRect:captureWindow.bounds afterScreenUpdates:YES];
            if (!drawn) {
                [captureWindow.layer renderInContext:context];
            }
            CGContextRestoreGState(context);
        }
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    };

    if (NSThread.isMainThread) {
        captureBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), captureBlock);
    }

    if (capturedWindow) {
        *capturedWindow = window;
    }
    return image;
}

static cv::Mat AnClickMatFromUIImage(UIImage *image) {
    if (!image.CGImage) {
        return cv::Mat();
    }

    CGImageRef imageRef = image.CGImage;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    if (width == 0 || height == 0) {
        return cv::Mat();
    }

    size_t bytesPerRow = width * 4;
    std::vector<unsigned char> data(height * bytesPerRow);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) {
        return cv::Mat();
    }

    CGContextRef context = CGBitmapContextCreate(data.data(),
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (!context) {
        CGColorSpaceRelease(colorSpace);
        return cv::Mat();
    }

    CGContextTranslateCTM(context, 0, (CGFloat)height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    cv::Mat rgba((int)height, (int)width, CV_8UC4, data.data(), bytesPerRow);
    cv::Mat bgr;
    cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);
    return bgr.clone();
}

static double AnClickColorDistanceSquaredToRGB(const unsigned char *pixel, double red, double green, double blue) {
    double dr = (double)pixel[0] - red;
    double dg = (double)pixel[1] - green;
    double db = (double)pixel[2] - blue;
    return dr * dr + dg * dg + db * db;
}

static CGRect AnClickRectFromPixelBounds(size_t minX, size_t minY, size_t maxX, size_t maxY, size_t width, size_t height, int templateCols, int templateRows) {
    CGRect contentRect = CGRectMake((CGFloat)minX,
                                    (CGFloat)minY,
                                    (CGFloat)(maxX - minX + 1),
                                    (CGFloat)(maxY - minY + 1));
    if (CGRectIsEmpty(contentRect) || CGRectEqualToRect(CGRectIntegral(contentRect), CGRectMake(0, 0, width, height))) {
        return CGRectMake(0, 0, MAX(0, templateCols), MAX(0, templateRows));
    }

    CGFloat xScale = (CGFloat)templateCols / (CGFloat)width;
    CGFloat yScale = (CGFloat)templateRows / (CGFloat)height;
    return CGRectMake(contentRect.origin.x * xScale,
                      contentRect.origin.y * yScale,
                      contentRect.size.width * xScale,
                      contentRect.size.height * yScale);
}

static CGRect AnClickTemplateContentRectInPixels(UIImage *image, int templateCols, int templateRows) {
    CGRect fullRect = CGRectMake(0, 0, MAX(0, templateCols), MAX(0, templateRows));
    if (!image.CGImage || templateCols <= 0 || templateRows <= 0) {
        return fullRect;
    }

    CGImageRef imageRef = image.CGImage;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    if (width == 0 || height == 0) {
        return fullRect;
    }

    size_t bytesPerRow = width * 4;
    std::vector<unsigned char> data(height * bytesPerRow);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) {
        return fullRect;
    }

    CGContextRef context = CGBitmapContextCreate(data.data(),
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (!context) {
        CGColorSpaceRelease(colorSpace);
        return fullRect;
    }

    CGContextTranslateCTM(context, 0, (CGFloat)height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    bool hasTransparentPixel = false;
    bool hasContentPixel = false;
    size_t minX = width;
    size_t minY = height;
    size_t maxX = 0;
    size_t maxY = 0;
    for (size_t y = 0; y < height; y++) {
        const unsigned char *row = data.data() + y * bytesPerRow;
        for (size_t x = 0; x < width; x++) {
            unsigned char alpha = row[x * 4 + 3];
            if (alpha < 250) {
                hasTransparentPixel = true;
            }
            if (alpha <= 16) {
                continue;
            }
            hasContentPixel = true;
            minX = MIN(minX, x);
            minY = MIN(minY, y);
            maxX = MAX(maxX, x);
            maxY = MAX(maxY, y);
        }
    }

    if (hasTransparentPixel && hasContentPixel) {
        return AnClickRectFromPixelBounds(minX, minY, maxX, maxY, width, height, templateCols, templateRows);
    }

    if (width < 8 || height < 8) {
        return fullRect;
    }

    const unsigned char *topLeft = data.data();
    const unsigned char *topRight = data.data() + (width - 1) * 4;
    const unsigned char *bottomLeft = data.data() + (height - 1) * bytesPerRow;
    const unsigned char *bottomRight = data.data() + (height - 1) * bytesPerRow + (width - 1) * 4;
    double backgroundRed = ((double)topLeft[0] + (double)topRight[0] + (double)bottomLeft[0] + (double)bottomRight[0]) * 0.25;
    double backgroundGreen = ((double)topLeft[1] + (double)topRight[1] + (double)bottomLeft[1] + (double)bottomRight[1]) * 0.25;
    double backgroundBlue = ((double)topLeft[2] + (double)topRight[2] + (double)bottomLeft[2] + (double)bottomRight[2]) * 0.25;
    double cornerLimitSquared = 24.0 * 24.0;
    if (AnClickColorDistanceSquaredToRGB(topLeft, backgroundRed, backgroundGreen, backgroundBlue) > cornerLimitSquared ||
        AnClickColorDistanceSquaredToRGB(topRight, backgroundRed, backgroundGreen, backgroundBlue) > cornerLimitSquared ||
        AnClickColorDistanceSquaredToRGB(bottomLeft, backgroundRed, backgroundGreen, backgroundBlue) > cornerLimitSquared ||
        AnClickColorDistanceSquaredToRGB(bottomRight, backgroundRed, backgroundGreen, backgroundBlue) > cornerLimitSquared) {
        return fullRect;
    }

    bool hasForeground = false;
    size_t foregroundMinX = width;
    size_t foregroundMinY = height;
    size_t foregroundMaxX = 0;
    size_t foregroundMaxY = 0;
    double foregroundLimitSquared = 32.0 * 32.0;
    for (size_t y = 0; y < height; y++) {
        const unsigned char *row = data.data() + y * bytesPerRow;
        for (size_t x = 0; x < width; x++) {
            const unsigned char *pixel = row + x * 4;
            if (AnClickColorDistanceSquaredToRGB(pixel, backgroundRed, backgroundGreen, backgroundBlue) <= foregroundLimitSquared) {
                continue;
            }
            hasForeground = true;
            foregroundMinX = MIN(foregroundMinX, x);
            foregroundMinY = MIN(foregroundMinY, y);
            foregroundMaxX = MAX(foregroundMaxX, x);
            foregroundMaxY = MAX(foregroundMaxY, y);
        }
    }

    if (!hasForeground) {
        return fullRect;
    }

    CGFloat foregroundWidth = (CGFloat)(foregroundMaxX - foregroundMinX + 1);
    CGFloat foregroundHeight = (CGFloat)(foregroundMaxY - foregroundMinY + 1);
    CGFloat foregroundArea = foregroundWidth * foregroundHeight;
    CGFloat fullArea = (CGFloat)width * (CGFloat)height;
    BOOL trimsEnough = foregroundMinX > width * 0.04 ||
        foregroundMinY > height * 0.04 ||
        foregroundMaxX + 1 < width * 0.96 ||
        foregroundMaxY + 1 < height * 0.96;
    if (foregroundWidth < 2.0 || foregroundHeight < 2.0 || foregroundArea >= fullArea * 0.92 || !trimsEnough) {
        return fullRect;
    }

    return AnClickRectFromPixelBounds(foregroundMinX, foregroundMinY, foregroundMaxX, foregroundMaxY, width, height, templateCols, templateRows);
}

static NSDictionary *AnClickColorMatchResult(UIWindow *sourceWindow,
                                             CGFloat scale,
                                             const std::vector<cv::Point> &matchedPixels,
                                             double totalDistance,
                                             double tolerance) {
    if (matchedPixels.empty()) {
        return nil;
    }

    int minX = matchedPixels[0].x;
    int minY = matchedPixels[0].y;
    int maxX = matchedPixels[0].x;
    int maxY = matchedPixels[0].y;
    for (const cv::Point &point : matchedPixels) {
        minX = MIN(minX, point.x);
        minY = MIN(minY, point.y);
        maxX = MAX(maxX, point.x);
        maxY = MAX(maxY, point.y);
    }

    CGPoint anchorWindowPoint = CGPointMake(((CGFloat)matchedPixels[0].x + 0.5) / scale,
                                            ((CGFloat)matchedPixels[0].y + 0.5) / scale);
    CGPoint topLeftWindowPoint = CGPointMake((CGFloat)minX / scale,
                                             (CGFloat)minY / scale);
    CGPoint bottomRightWindowPoint = CGPointMake((CGFloat)(maxX + 1) / scale,
                                                 (CGFloat)(maxY + 1) / scale);
    CGPoint screenPoint = sourceWindow ? [sourceWindow convertPoint:anchorWindowPoint toWindow:nil] : anchorWindowPoint;
    CGPoint topLeftScreenPoint = sourceWindow ? [sourceWindow convertPoint:topLeftWindowPoint toWindow:nil] : topLeftWindowPoint;
    CGPoint bottomRightScreenPoint = sourceWindow ? [sourceWindow convertPoint:bottomRightWindowPoint toWindow:nil] : bottomRightWindowPoint;
    CGRect screenRect = CGRectStandardize(CGRectMake(topLeftScreenPoint.x,
                                                     topLeftScreenPoint.y,
                                                     bottomRightScreenPoint.x - topLeftScreenPoint.x,
                                                     bottomRightScreenPoint.y - topLeftScreenPoint.y));
    if (screenRect.size.width < 12.0) {
        screenRect.origin.x -= (12.0 - screenRect.size.width) * 0.5;
        screenRect.size.width = 12.0;
    }
    if (screenRect.size.height < 12.0) {
        screenRect.origin.y -= (12.0 - screenRect.size.height) * 0.5;
        screenRect.size.height = 12.0;
    }

    double averageDistance = totalDistance / MAX((double)matchedPixels.size(), 1.0);
    double score = MAX(0.0, 1.0 - averageDistance / MAX(1.0, tolerance));
    return @{
        @"point": [NSValue valueWithCGPoint:screenPoint],
        @"rect": [NSValue valueWithCGRect:screenRect],
        @"distance": @(averageDistance),
        @"score": @(score),
    };
}

@implementation AnClickCore

+ (UIImage *)captureCurrentWindowImage {
    return AnClickCaptureActiveWindowImage(NULL);
}

+ (UIImage *)captureCurrentWindowImageWithWindow:(UIWindow **)capturedWindow {
    return AnClickCaptureActiveWindowImage(capturedWindow);
}

+ (NSDictionary *)findTemplateImageMatch:(UIImage *)templateImage threshold:(double)threshold {
    UIWindow *sourceWindow = nil;
    UIImage *sourceImage = AnClickCaptureActiveWindowImage(&sourceWindow);
    if (!sourceImage || !templateImage) {
        return nil;
    }

    cv::Mat source = AnClickMatFromUIImage(sourceImage);
    cv::Mat templ = AnClickMatFromUIImage(templateImage);
    if (source.empty() || templ.empty() || source.cols < templ.cols || source.rows < templ.rows) {
        return nil;
    }

    cv::Mat result;
    cv::matchTemplate(source, templ, result, cv::TM_CCOEFF_NORMED);

    double bestScore = 0.0;
    cv::Point bestLocation;
    cv::minMaxLoc(result, NULL, &bestScore, NULL, &bestLocation);
    if (bestScore < threshold) {
        return nil;
    }

    CGFloat scale = sourceImage.scale > 0 ? sourceImage.scale : UIScreen.mainScreen.scale;
    CGRect contentRect = AnClickTemplateContentRectInPixels(templateImage, templ.cols, templ.rows);
    CGPoint contentTopLeftPixel = CGPointMake((CGFloat)bestLocation.x + contentRect.origin.x,
                                              (CGFloat)bestLocation.y + contentRect.origin.y);
    CGPoint contentBottomRightPixel = CGPointMake((CGFloat)bestLocation.x + CGRectGetMaxX(contentRect),
                                                  (CGFloat)bestLocation.y + CGRectGetMaxY(contentRect));
    CGPoint topLeftWindowPoint = CGPointMake(contentTopLeftPixel.x / scale,
                                             contentTopLeftPixel.y / scale);
    CGPoint bottomRightWindowPoint = CGPointMake(contentBottomRightPixel.x / scale,
                                                 contentBottomRightPixel.y / scale);
    CGPoint centerWindowPoint = CGPointMake((topLeftWindowPoint.x + bottomRightWindowPoint.x) * 0.5,
                                            (topLeftWindowPoint.y + bottomRightWindowPoint.y) * 0.5);
    CGPoint topLeftScreenPoint = sourceWindow ? [sourceWindow convertPoint:topLeftWindowPoint toWindow:nil] : topLeftWindowPoint;
    CGPoint bottomRightScreenPoint = sourceWindow ? [sourceWindow convertPoint:bottomRightWindowPoint toWindow:nil] : bottomRightWindowPoint;
    CGPoint screenPoint = sourceWindow ? [sourceWindow convertPoint:centerWindowPoint toWindow:nil] : centerWindowPoint;
    CGRect screenRect = CGRectStandardize(CGRectMake(topLeftScreenPoint.x,
                                                     topLeftScreenPoint.y,
                                                     bottomRightScreenPoint.x - topLeftScreenPoint.x,
                                                     bottomRightScreenPoint.y - topLeftScreenPoint.y));
    NSLog(@"[AnClick] OpenCV match score %.3f rect=(%.1f, %.1f, %.1f, %.1f) screen=(%.1f, %.1f)",
          bestScore,
          screenRect.origin.x,
          screenRect.origin.y,
          screenRect.size.width,
          screenRect.size.height,
          screenPoint.x,
          screenPoint.y);
    return @{
        @"point": [NSValue valueWithCGPoint:screenPoint],
        @"rect": [NSValue valueWithCGRect:screenRect],
        @"score": @(bestScore),
    };
}

+ (NSDictionary *)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points tolerance:(double)tolerance {
    if (![points isKindOfClass:NSArray.class] || points.count == 0) {
        return nil;
    }

    UIWindow *sourceWindow = nil;
    UIImage *sourceImage = AnClickCaptureActiveWindowImage(&sourceWindow);
    if (!sourceImage) {
        return nil;
    }

    cv::Mat source = AnClickMatFromUIImage(sourceImage);
    if (source.empty()) {
        return nil;
    }

    double maxDistance = MIN(255.0, MAX(0.0, tolerance));
    double maxDistanceSquared = maxDistance * maxDistance;
    CGFloat scale = sourceImage.scale > 0 ? sourceImage.scale : UIScreen.mainScreen.scale;

    struct AnClickColorPoint {
        int dx;
        int dy;
        double red;
        double green;
        double blue;
    };

    std::vector<AnClickColorPoint> normalizedPoints;
    normalizedPoints.reserve(points.count);
    BOOL hasPreferredAnchorPixel = NO;
    double preferredAnchorPixelX = 0.0;
    double preferredAnchorPixelY = 0.0;
    int minDx = 0;
    int minDy = 0;
    int maxDx = 0;
    int maxDy = 0;
    for (NSDictionary *point in points) {
        if (![point isKindOfClass:NSDictionary.class]) {
            continue;
        }
        id redValue = point[@"red"];
        id greenValue = point[@"green"];
        id blueValue = point[@"blue"];
        if (![redValue respondsToSelector:@selector(doubleValue)] ||
            ![greenValue respondsToSelector:@selector(doubleValue)] ||
            ![blueValue respondsToSelector:@selector(doubleValue)]) {
            continue;
        }
        double dxValue = [point[@"dx"] respondsToSelector:@selector(doubleValue)] ? [point[@"dx"] doubleValue] : 0.0;
        double dyValue = [point[@"dy"] respondsToSelector:@selector(doubleValue)] ? [point[@"dy"] doubleValue] : 0.0;
        if (normalizedPoints.empty()) {
            id preferredXValue = [point[@"preferredX"] respondsToSelector:@selector(doubleValue)] ? point[@"preferredX"] : point[@"x"];
            id preferredYValue = [point[@"preferredY"] respondsToSelector:@selector(doubleValue)] ? point[@"preferredY"] : point[@"y"];
            if ([preferredXValue respondsToSelector:@selector(doubleValue)] &&
                [preferredYValue respondsToSelector:@selector(doubleValue)]) {
                preferredAnchorPixelX = [preferredXValue doubleValue] * scale;
                preferredAnchorPixelY = [preferredYValue doubleValue] * scale;
                hasPreferredAnchorPixel = YES;
            }
        }
        AnClickColorPoint colorPoint = {
            (int)llround(dxValue * scale),
            (int)llround(dyValue * scale),
            (double)MIN(255.0, MAX(0.0, [redValue doubleValue])),
            (double)MIN(255.0, MAX(0.0, [greenValue doubleValue])),
            (double)MIN(255.0, MAX(0.0, [blueValue doubleValue])),
        };
        minDx = MIN(minDx, colorPoint.dx);
        minDy = MIN(minDy, colorPoint.dy);
        maxDx = MAX(maxDx, colorPoint.dx);
        maxDy = MAX(maxDy, colorPoint.dy);
        normalizedPoints.push_back(colorPoint);
    }

    if (normalizedPoints.empty()) {
        return nil;
    }

    const AnClickColorPoint &anchorPoint = normalizedPoints[0];
    BOOL usesVerticallyFlippedImageCoordinates = NO;
    if (hasPreferredAnchorPixel) {
        int preferredPixelX = MIN(MAX((int)floor(preferredAnchorPixelX), 0), source.cols - 1);
        int preferredPixelY = MIN(MAX((int)floor(preferredAnchorPixelY), 0), source.rows - 1);
        int flippedPreferredPixelY = source.rows - 1 - preferredPixelY;
        const cv::Vec3b normalPixel = source.at<cv::Vec3b>(preferredPixelY, preferredPixelX);
        const cv::Vec3b flippedPixel = source.at<cv::Vec3b>(flippedPreferredPixelY, preferredPixelX);
        double normalDb = (double)normalPixel[0] - anchorPoint.blue;
        double normalDg = (double)normalPixel[1] - anchorPoint.green;
        double normalDr = (double)normalPixel[2] - anchorPoint.red;
        double flippedDb = (double)flippedPixel[0] - anchorPoint.blue;
        double flippedDg = (double)flippedPixel[1] - anchorPoint.green;
        double flippedDr = (double)flippedPixel[2] - anchorPoint.red;
        double normalDistanceSquared = normalDb * normalDb + normalDg * normalDg + normalDr * normalDr;
        double flippedDistanceSquared = flippedDb * flippedDb + flippedDg * flippedDg + flippedDr * flippedDr;
        usesVerticallyFlippedImageCoordinates = flippedDistanceSquared + 0.5 < normalDistanceSquared &&
            flippedDistanceSquared <= maxDistanceSquared;
        if (usesVerticallyFlippedImageCoordinates) {
            for (AnClickColorPoint &colorPoint : normalizedPoints) {
                colorPoint.dy = -colorPoint.dy;
            }
            preferredAnchorPixelY = (double)(source.rows - 1) - preferredAnchorPixelY;
        }
    }

    minDx = 0;
    minDy = 0;
    maxDx = 0;
    maxDy = 0;
    for (const AnClickColorPoint &colorPoint : normalizedPoints) {
        minDx = MIN(minDx, colorPoint.dx);
        minDy = MIN(minDy, colorPoint.dy);
        maxDx = MAX(maxDx, colorPoint.dx);
        maxDy = MAX(maxDy, colorPoint.dy);
    }

    double bestTotalDistanceSquared = DBL_MAX;
    double bestProximitySquared = DBL_MAX;
    cv::Point bestAnchor(0, 0);

    int startX = MAX(0, -minDx);
    int endX = MIN(source.cols - 1, source.cols - 1 - maxDx);
    int startY = MAX(0, -minDy);
    int endY = MIN(source.rows - 1, source.rows - 1 - maxDy);
    if (startX > endX || startY > endY) {
        return nil;
    }

    for (int y = startY; y <= endY; y++) {
        const cv::Vec3b *row = source.ptr<cv::Vec3b>(y);
        for (int x = startX; x <= endX; x++) {
            const cv::Vec3b pixel = row[x];
            double db = (double)pixel[0] - anchorPoint.blue;
            double dg = (double)pixel[1] - anchorPoint.green;
            double dr = (double)pixel[2] - anchorPoint.red;
            double totalDistanceSquared = db * db + dg * dg + dr * dr;
            if (totalDistanceSquared > maxDistanceSquared) {
                continue;
            }

            BOOL matched = YES;
            for (size_t index = 1; index < normalizedPoints.size(); index++) {
                const AnClickColorPoint &colorPoint = normalizedPoints[index];
                const cv::Vec3b samplePixel = source.at<cv::Vec3b>(y + colorPoint.dy, x + colorPoint.dx);
                double sampleDb = (double)samplePixel[0] - colorPoint.blue;
                double sampleDg = (double)samplePixel[1] - colorPoint.green;
                double sampleDr = (double)samplePixel[2] - colorPoint.red;
                double sampleDistanceSquared = sampleDb * sampleDb + sampleDg * sampleDg + sampleDr * sampleDr;
                if (sampleDistanceSquared > maxDistanceSquared) {
                    matched = NO;
                    break;
                }
                totalDistanceSquared += sampleDistanceSquared;
            }

            if (!matched) {
                continue;
            }

            double proximitySquared = 0.0;
            if (hasPreferredAnchorPixel) {
                double proximityDx = (double)x - preferredAnchorPixelX;
                double proximityDy = (double)y - preferredAnchorPixelY;
                proximitySquared = proximityDx * proximityDx + proximityDy * proximityDy;
            }

            BOOL betterMatch = NO;
            if (hasPreferredAnchorPixel) {
                if (proximitySquared < bestProximitySquared - 0.5) {
                    betterMatch = YES;
                } else if (fabs(proximitySquared - bestProximitySquared) <= 0.5 &&
                           totalDistanceSquared < bestTotalDistanceSquared) {
                    betterMatch = YES;
                }
            } else if (totalDistanceSquared < bestTotalDistanceSquared) {
                betterMatch = YES;
            }

            if (betterMatch) {
                bestTotalDistanceSquared = totalDistanceSquared;
                bestProximitySquared = proximitySquared;
                bestAnchor = cv::Point(x, y);
                if ((!hasPreferredAnchorPixel && bestTotalDistanceSquared <= 0.0) ||
                    (hasPreferredAnchorPixel && bestTotalDistanceSquared <= 0.0 && bestProximitySquared <= 0.0)) {
                    break;
                }
            }
        }
        if ((!hasPreferredAnchorPixel && bestTotalDistanceSquared <= 0.0) ||
            (hasPreferredAnchorPixel && bestTotalDistanceSquared <= 0.0 && bestProximitySquared <= 0.0)) {
            break;
        }
    }

    if (bestTotalDistanceSquared == DBL_MAX) {
        return nil;
    }

    std::vector<cv::Point> matchedPixels;
    matchedPixels.reserve(normalizedPoints.size());
    for (const AnClickColorPoint &point : normalizedPoints) {
        cv::Point matchedPixel(bestAnchor.x + point.dx, bestAnchor.y + point.dy);
        if (usesVerticallyFlippedImageCoordinates) {
            matchedPixel.y = source.rows - 1 - matchedPixel.y;
        }
        matchedPixels.push_back(matchedPixel);
    }
    return AnClickColorMatchResult(sourceWindow,
                                   scale,
                                   matchedPixels,
                                   sqrt(MAX(0.0, bestTotalDistanceSquared)),
                                   maxDistance);
}

+ (NSDictionary *)findColorMatchWithRed:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue tolerance:(double)tolerance {
    return [self findColorPatternMatchWithPoints:@[@{
        @"dx": @(0.0),
        @"dy": @(0.0),
        @"red": @(MIN(255, MAX(0, red))),
        @"green": @(MIN(255, MAX(0, green))),
        @"blue": @(MIN(255, MAX(0, blue))),
    }] tolerance:tolerance];
}

+ (NSValue *)findTemplateImage:(UIImage *)templateImage threshold:(double)threshold {
    NSDictionary *match = [self findTemplateImageMatch:templateImage threshold:threshold];
    return match[@"point"];
}

+ (BOOL)findAndTapTemplateImage:(UIImage *)templateImage threshold:(double)threshold {
    NSValue *pointValue = [self findTemplateImage:templateImage threshold:threshold];
    if (!pointValue) {
        return NO;
    }

    CGPoint point = pointValue.CGPointValue;
    dispatch_async(dispatch_get_main_queue(), ^{
        [AnClickFakeTouch tapAtPoint:point];
    });
    return YES;
}

@end
