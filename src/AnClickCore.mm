#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#include <float.h>
#include <vector>

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
@end

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (UIImage *)captureCurrentWindowImageWithWindow:(UIWindow **)capturedWindow;
+ (NSDictionary *)findTemplateImageMatch:(UIImage *)templateImage threshold:(double)threshold;
+ (NSDictionary *)findColorMatchWithRed:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue tolerance:(double)tolerance;
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

static UIImage *AnClickCaptureActiveWindowImage(UIWindow **capturedWindow) {
    __block UIImage *image = nil;
    __block UIWindow *window = nil;
    void (^captureBlock)(void) = ^{
        window = AnClickActiveWindow();
        if (!window) {
            return;
        }

        CGSize size = window.bounds.size;
        CGFloat scale = UIScreen.mainScreen.scale;
        UIGraphicsBeginImageContextWithOptions(size, NO, scale);
        BOOL drawn = [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
        if (!drawn) {
            [window.layer renderInContext:UIGraphicsGetCurrentContext()];
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
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    if (!context) {
        CGColorSpaceRelease(colorSpace);
        return cv::Mat();
    }

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
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    if (!context) {
        CGColorSpaceRelease(colorSpace);
        return fullRect;
    }

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

    CGFloat scale = UIScreen.mainScreen.scale;
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

+ (NSDictionary *)findColorMatchWithRed:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue tolerance:(double)tolerance {
    UIWindow *sourceWindow = nil;
    UIImage *sourceImage = AnClickCaptureActiveWindowImage(&sourceWindow);
    if (!sourceImage) {
        return nil;
    }

    cv::Mat source = AnClickMatFromUIImage(sourceImage);
    if (source.empty()) {
        return nil;
    }

    NSInteger targetRed = MIN(255, MAX(0, red));
    NSInteger targetGreen = MIN(255, MAX(0, green));
    NSInteger targetBlue = MIN(255, MAX(0, blue));
    double maxDistance = MIN(255.0, MAX(0.0, tolerance));
    double maxDistanceSquared = maxDistance * maxDistance;
    double bestDistanceSquared = DBL_MAX;
    cv::Point bestPoint(0, 0);

    for (int y = 0; y < source.rows; y++) {
        const cv::Vec3b *row = source.ptr<cv::Vec3b>(y);
        for (int x = 0; x < source.cols; x++) {
            const cv::Vec3b pixel = row[x];
            double db = (double)pixel[0] - (double)targetBlue;
            double dg = (double)pixel[1] - (double)targetGreen;
            double dr = (double)pixel[2] - (double)targetRed;
            double distanceSquared = db * db + dg * dg + dr * dr;
            if (distanceSquared < bestDistanceSquared) {
                bestDistanceSquared = distanceSquared;
                bestPoint = cv::Point(x, y);
                if (bestDistanceSquared <= 0.0) {
                    break;
                }
            }
        }
        if (bestDistanceSquared <= 0.0) {
            break;
        }
    }

    if (bestDistanceSquared > maxDistanceSquared) {
        return nil;
    }

    double bestDistance = sqrt(bestDistanceSquared);
    CGFloat scale = UIScreen.mainScreen.scale;
    CGPoint windowPoint = CGPointMake(((CGFloat)bestPoint.x + 0.5) / scale,
                                      ((CGFloat)bestPoint.y + 0.5) / scale);
    CGPoint screenPoint = sourceWindow ? [sourceWindow convertPoint:windowPoint toWindow:nil] : windowPoint;
    CGFloat markerSize = 12.0;
    CGRect screenRect = CGRectMake(screenPoint.x - markerSize * 0.5,
                                   screenPoint.y - markerSize * 0.5,
                                   markerSize,
                                   markerSize);
    return @{
        @"point": [NSValue valueWithCGPoint:screenPoint],
        @"rect": [NSValue valueWithCGRect:screenRect],
        @"distance": @(bestDistance),
        @"score": @(MAX(0.0, 1.0 - bestDistance / MAX(1.0, maxDistance))),
    };
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
