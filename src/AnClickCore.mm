#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#include <dlfcn.h>
#include <float.h>
#include <math.h>
#include <string.h>
#include <mutex>
#include <unordered_map>
#include <vector>

#if ANCLICK_RELEASE_SILENT
#undef NSLog
#define NSLog(...) do {} while (0)
#endif

@interface AnClickHammerTouchDriver : NSObject
+ (void)fastTapAtPoint:(CGPoint)point;
@end

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (UIImage *)captureCurrentWindowImageWithWindow:(UIWindow **)capturedWindow;
+ (NSDictionary *)findTemplateImageMatch:(UIImage *)templateImage threshold:(double)threshold;
+ (NSDictionary *)findColorMatchWithRed:(NSInteger)red green:(NSInteger)green blue:(NSInteger)blue tolerance:(double)tolerance;
+ (NSDictionary *)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points tolerance:(double)tolerance;
+ (NSValue *)findTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
+ (BOOL)findAndTapTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
+ (void)warmUpRecognition;
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
    if (windows.count == 0 && AnClickWindowCanBeCaptured(primary)) {
        [windows addObject:primary];
    } else if (primary && ![windows containsObject:primary] && AnClickWindowCanBeCaptured(primary)) {
        [windows insertObject:primary atIndex:0];
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

static BOOL AnClickImageAppearsBlankOrLowDetail(UIImage *image) {
    if (!image.CGImage) {
        return YES;
    }

    const size_t sampleWidth = 32;
    const size_t sampleHeight = 32;
    const size_t bytesPerPixel = 4;
    const size_t bytesPerRow = sampleWidth * bytesPerPixel;
    unsigned char pixels[sampleHeight * bytesPerRow];
    memset(pixels, 0, sizeof(pixels));

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) {
        return NO;
    }
    CGContextRef context = CGBitmapContextCreate(pixels,
                                                 sampleWidth,
                                                 sampleHeight,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        return NO;
    }

    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    CGContextDrawImage(context, CGRectMake(0, 0, sampleWidth, sampleHeight), image.CGImage);
    CGContextRelease(context);

    int minR = 255;
    int minG = 255;
    int minB = 255;
    int maxR = 0;
    int maxG = 0;
    int maxB = 0;
    double luminanceSum = 0.0;
    double luminanceSquaredSum = 0.0;
    NSUInteger darkPixels = 0;
    for (size_t y = 0; y < sampleHeight; y++) {
        for (size_t x = 0; x < sampleWidth; x++) {
            const unsigned char *pixel = pixels + y * bytesPerRow + x * bytesPerPixel;
            int r = pixel[0];
            int g = pixel[1];
            int b = pixel[2];
            double luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            minR = MIN(minR, r);
            minG = MIN(minG, g);
            minB = MIN(minB, b);
            maxR = MAX(maxR, r);
            maxG = MAX(maxG, g);
            maxB = MAX(maxB, b);
            luminanceSum += luminance;
            luminanceSquaredSum += luminance * luminance;
            if (luminance < 12.0) {
                darkPixels++;
            }
        }
    }
    NSUInteger pixelCount = sampleWidth * sampleHeight;
    double mean = luminanceSum / MAX((double)pixelCount, 1.0);
    double variance = luminanceSquaredSum / MAX((double)pixelCount, 1.0) - mean * mean;
    double stdDev = sqrt(MAX(0.0, variance));
    double darkRatio = (double)darkPixels / MAX((double)pixelCount, 1.0);
    BOOL almostUniform = (maxR - minR) <= 3 && (maxG - minG) <= 3 && (maxB - minB) <= 3;
    BOOL mostlyBlack = mean < 18.0 && darkRatio > 0.92;
    BOOL tooLittleDetail = stdDev < 2.5 && (maxR - minR) <= 10 && (maxG - minG) <= 10 && (maxB - minB) <= 10;
    return almostUniform || mostlyBlack || tooLittleDetail;
}

static BOOL AnClickImageMatchesWindowPointSize(UIImage *image, UIWindow *window) {
    if (!image.CGImage || !window || CGRectIsEmpty(window.bounds)) {
        return YES;
    }

    CGSize windowSize = window.bounds.size;
    CGSize imageSize = image.size;
    CGFloat scale = image.scale > 0.0 ? image.scale : (window.screen.scale > 0.0 ? window.screen.scale : UIScreen.mainScreen.scale);
    CGSize pixelPointSize = CGSizeMake((CGFloat)CGImageGetWidth(image.CGImage) / MAX(scale, 0.01),
                                       (CGFloat)CGImageGetHeight(image.CGImage) / MAX(scale, 0.01));
    BOOL imageMatches = fabs(imageSize.width - windowSize.width) < 0.5 &&
        fabs(imageSize.height - windowSize.height) < 0.5;
    BOOL pixelMatches = fabs(pixelPointSize.width - windowSize.width) < 0.5 &&
        fabs(pixelPointSize.height - windowSize.height) < 0.5;
    return imageMatches || pixelMatches;
}

static UIImage *AnClickCaptureWindowHierarchyImage(NSArray<UIWindow *> *windows, UIWindow *window) {
    if (!window || CGRectIsEmpty(window.bounds)) {
        return nil;
    }

    CGSize size = window.bounds.size;
    CGFloat scale = window.screen.scale > 0 ? window.screen.scale : UIScreen.mainScreen.scale;
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIImage *image = nil;
    if (context) {
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
    }
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *AnClickCaptureSingleAttempt(UIWindow **capturedWindow, BOOL *capturedImageIsUsable) {
    __block UIImage *image = nil;
    __block UIWindow *window = nil;
    void (^captureBlock)(void) = ^{
        NSArray<UIWindow *> *windows = AnClickCaptureCandidateWindows(&window);
        if (window) {
            UIImage *screenImage = AnClickCaptureHardwareScreenImage();
            BOOL screenImageMatches = screenImage.CGImage && AnClickImageMatchesWindowPointSize(screenImage, window);
            if (screenImageMatches && !AnClickImageAppearsBlankOrLowDetail(screenImage)) {
                image = screenImage;
                window = nil;
                return;
            }
            if (screenImage.CGImage && !screenImageMatches) {
                NSLog(@"[AnClick] Ignored hardware screenshot with mismatched orientation size");
            }

            image = AnClickCaptureWindowHierarchyImage(windows, window);
            if (image.CGImage && !AnClickImageAppearsBlankOrLowDetail(image)) {
                return;
            }

            if (screenImageMatches && screenImage.CGImage) {
                image = screenImage;
                window = nil;
                return;
            }
        }

        UIImage *screenImage = AnClickCaptureHardwareScreenImage();
        BOOL screenImageMatches = screenImage.CGImage && (!window || AnClickImageMatchesWindowPointSize(screenImage, window));
        if (screenImageMatches) {
            image = screenImage;
            window = nil;
        } else if (screenImage.CGImage) {
            NSLog(@"[AnClick] Ignored hardware screenshot with mismatched orientation size");
        }
    };

    if (NSThread.isMainThread) {
        captureBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), captureBlock);
    }

    if (capturedWindow) {
        *capturedWindow = window;
    }
    if (capturedImageIsUsable) {
        *capturedImageIsUsable = image.CGImage && !AnClickImageAppearsBlankOrLowDetail(image);
    }
    return image;
}

static UIImage *AnClickCaptureActiveWindowImage(UIWindow **capturedWindow) {
    UIImage *bestImage = nil;
    UIWindow *bestWindow = nil;
    static const NSTimeInterval retryDelays[] = {0.0, 0.045, 0.090};
    for (NSUInteger attempt = 0; attempt < sizeof(retryDelays) / sizeof(retryDelays[0]); attempt++) {
        NSTimeInterval delay = retryDelays[attempt];
        if (delay > 0.0) {
            if (NSThread.isMainThread) {
                [[NSRunLoop currentRunLoop] runMode:NSRunLoopCommonModes
                                        beforeDate:[NSDate dateWithTimeIntervalSinceNow:delay]];
            } else {
                [NSThread sleepForTimeInterval:delay];
            }
        }

        UIWindow *attemptWindow = nil;
        BOOL usable = NO;
        UIImage *attemptImage = AnClickCaptureSingleAttempt(&attemptWindow, &usable);
        if (attemptImage.CGImage) {
            bestImage = attemptImage;
            bestWindow = attemptWindow;
        }
        if (usable) {
            if (capturedWindow) {
                *capturedWindow = attemptWindow;
            }
            if (attempt > 0) {
                NSLog(@"[AnClick] Screenshot recovered after %lu retry", (unsigned long)attempt);
            }
            return attemptImage;
        }
    }

    if (capturedWindow) {
        *capturedWindow = bestWindow;
    }
    if (bestImage.CGImage && AnClickImageAppearsBlankOrLowDetail(bestImage)) {
        NSLog(@"[AnClick] Screenshot still appears blank after retries");
    }
    return bestImage;
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

static BOOL AnClickSampleImageDataRGB(CGImageRef imageRef, const UInt8 *bytes, CFIndex length, NSInteger pixelX, NSInteger pixelY, NSInteger *red, NSInteger *green, NSInteger *blue) {
    if (!imageRef || !bytes || CGImageGetBitsPerPixel(imageRef) != 32 || CGImageGetBitsPerComponent(imageRef) != 8) {
        return NO;
    }

    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    if (pixelX < 0 || pixelY < 0 ||
        (size_t)pixelX >= width || (size_t)pixelY >= height ||
        bytesPerRow < width * 4 ||
        (CFIndex)((size_t)pixelY * bytesPerRow + (size_t)pixelX * 4 + 3) >= length) {
        return NO;
    }

    const UInt8 *pixel = bytes + (size_t)pixelY * bytesPerRow + (size_t)pixelX * 4;
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    CGBitmapInfo byteOrder = bitmapInfo & kCGBitmapByteOrderMask;
    CGImageAlphaInfo alphaInfo = (CGImageAlphaInfo)(bitmapInfo & kCGBitmapAlphaInfoMask);
    NSInteger sampleRed = 0;
    NSInteger sampleGreen = 0;
    NSInteger sampleBlue = 0;

    if (byteOrder == kCGBitmapByteOrder32Little) {
        if (alphaInfo == kCGImageAlphaPremultipliedFirst ||
            alphaInfo == kCGImageAlphaFirst ||
            alphaInfo == kCGImageAlphaNoneSkipFirst) {
            sampleBlue = pixel[0];
            sampleGreen = pixel[1];
            sampleRed = pixel[2];
        } else {
            sampleRed = pixel[3];
            sampleGreen = pixel[2];
            sampleBlue = pixel[1];
        }
    } else {
        if (alphaInfo == kCGImageAlphaPremultipliedFirst ||
            alphaInfo == kCGImageAlphaFirst ||
            alphaInfo == kCGImageAlphaNoneSkipFirst) {
            sampleRed = pixel[1];
            sampleGreen = pixel[2];
            sampleBlue = pixel[3];
        } else {
            sampleRed = pixel[0];
            sampleGreen = pixel[1];
            sampleBlue = pixel[2];
        }
    }

    if (red) {
        *red = sampleRed;
    }
    if (green) {
        *green = sampleGreen;
    }
    if (blue) {
        *blue = sampleBlue;
    }
    return YES;
}

static double AnClickColorDistanceSquaredBGRToRGB(const cv::Vec3b &pixel, NSInteger red, NSInteger green, NSInteger blue) {
    double db = (double)pixel[0] - (double)blue;
    double dg = (double)pixel[1] - (double)green;
    double dr = (double)pixel[2] - (double)red;
    return db * db + dg * dg + dr * dr;
}

static BOOL AnClickMatAppearsVerticallyFlippedFromImage(UIImage *image, const cv::Mat &mat) {
    CGImageRef imageRef = image.CGImage;
    if (!imageRef || mat.empty() || mat.cols <= 1 || mat.rows <= 1 ||
        CGImageGetWidth(imageRef) != (size_t)mat.cols ||
        CGImageGetHeight(imageRef) != (size_t)mat.rows) {
        return NO;
    }

    CGDataProviderRef provider = CGImageGetDataProvider(imageRef);
    if (!provider) {
        return NO;
    }
    CFDataRef imageData = CGDataProviderCopyData(provider);
    if (!imageData) {
        return NO;
    }
    const UInt8 *imageBytes = CFDataGetBytePtr(imageData);
    CFIndex imageLength = CFDataGetLength(imageData);

    static const CGPoint samplePoints[] = {
        {0.20, 0.18},
        {0.50, 0.33},
        {0.78, 0.62},
        {0.35, 0.84},
    };
    double normalDistance = 0.0;
    double flippedDistance = 0.0;
    NSUInteger validSamples = 0;
    for (size_t i = 0; i < sizeof(samplePoints) / sizeof(samplePoints[0]); i++) {
        CGPoint normalizedPoint = samplePoints[i];
        int x = MIN(MAX((int)floor(normalizedPoint.x * (double)(mat.cols - 1)), 0), mat.cols - 1);
        int y = MIN(MAX((int)floor(normalizedPoint.y * (double)(mat.rows - 1)), 0), mat.rows - 1);
        int flippedY = mat.rows - 1 - y;
        NSInteger red = 0;
        NSInteger green = 0;
        NSInteger blue = 0;
        NSInteger flippedRed = 0;
        NSInteger flippedGreen = 0;
        NSInteger flippedBlue = 0;
        if (!AnClickSampleImageDataRGB(imageRef, imageBytes, imageLength, x, y, &red, &green, &blue) ||
            !AnClickSampleImageDataRGB(imageRef, imageBytes, imageLength, x, flippedY, &flippedRed, &flippedGreen, &flippedBlue)) {
            continue;
        }
        const cv::Vec3b matPixel = mat.at<cv::Vec3b>(y, x);
        normalDistance += AnClickColorDistanceSquaredBGRToRGB(matPixel, red, green, blue);
        flippedDistance += AnClickColorDistanceSquaredBGRToRGB(matPixel, flippedRed, flippedGreen, flippedBlue);
        validSamples++;
    }

    CFRelease(imageData);
    if (validSamples == 0) {
        return NO;
    }
    return flippedDistance + 1.0 < normalDistance;
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

struct AnClickTemplateCacheEntry {
    cv::Mat mat;
    CGRect contentRect;
    double averageStdDev;
};

static BOOL AnClickBuildTemplateCacheEntry(UIImage *templateImage, AnClickTemplateCacheEntry *entry) {
    if (!templateImage.CGImage || !entry) {
        return NO;
    }

    cv::Mat templ = AnClickMatFromUIImage(templateImage);
    if (templ.empty()) {
        return NO;
    }

    cv::Scalar templateMean;
    cv::Scalar templateStdDev;
    cv::meanStdDev(templ, templateMean, templateStdDev);
    entry->averageStdDev = (templateStdDev[0] + templateStdDev[1] + templateStdDev[2]) / 3.0;
    entry->contentRect = AnClickTemplateContentRectInPixels(templateImage, templ.cols, templ.rows);
    entry->mat = templ;
    return YES;
}

static BOOL AnClickGetTemplateCacheEntry(UIImage *templateImage, AnClickTemplateCacheEntry *entry) {
    if (!templateImage.CGImage || !entry) {
        return NO;
    }

    static std::mutex cacheMutex;
    static std::unordered_map<uintptr_t, AnClickTemplateCacheEntry> cache;
    static std::vector<uintptr_t> cacheOrder;
    static const size_t cacheLimit = 24;

    uintptr_t key = (uintptr_t)templateImage.CGImage;
    {
        std::lock_guard<std::mutex> lock(cacheMutex);
        auto found = cache.find(key);
        if (found != cache.end()) {
            *entry = found->second;
            return YES;
        }
    }

    AnClickTemplateCacheEntry builtEntry;
    if (!AnClickBuildTemplateCacheEntry(templateImage, &builtEntry)) {
        return NO;
    }

    {
        std::lock_guard<std::mutex> lock(cacheMutex);
        cache[key] = builtEntry;
        cacheOrder.push_back(key);
        while (cacheOrder.size() > cacheLimit) {
            uintptr_t oldestKey = cacheOrder.front();
            cacheOrder.erase(cacheOrder.begin());
            cache.erase(oldestKey);
        }
        *entry = builtEntry;
    }
    return YES;
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

+ (void)warmUpRecognition {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cv::Mat source(24, 24, CV_8UC3, cv::Scalar(255, 255, 255));
        cv::Mat templ(8, 8, CV_8UC3, cv::Scalar(255, 255, 255));
        cv::rectangle(source, cv::Rect(8, 8, 8, 8), cv::Scalar(0, 0, 0), cv::FILLED);
        cv::rectangle(templ, cv::Rect(0, 0, 8, 8), cv::Scalar(0, 0, 0), cv::FILLED);

        cv::Mat result;
        cv::matchTemplate(source, templ, result, cv::TM_CCOEFF_NORMED);
        double maxScore = 0.0;
        cv::Point maxLocation;
        cv::minMaxLoc(result, NULL, &maxScore, NULL, &maxLocation);

        std::vector<cv::Point> points;
        points.reserve(1);
        points.push_back(maxLocation);
        (void)points;
        (void)maxScore;
    });
}

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
    AnClickTemplateCacheEntry templateEntry;
    if (!AnClickGetTemplateCacheEntry(templateImage, &templateEntry)) {
        return nil;
    }
    cv::Mat templ = templateEntry.mat;
    if (source.empty() || templ.empty() || source.cols < templ.cols || source.rows < templ.rows) {
        return nil;
    }

    if (templateEntry.averageStdDev < 3.0) {
        NSLog(@"[AnClick] Rejected low-detail template stddev %.3f", templateEntry.averageStdDev);
        return nil;
    }

    cv::Mat result;
    cv::matchTemplate(source, templ, result, cv::TM_CCOEFF_NORMED);

    double maxScore = 0.0;
    cv::Point maxLocation;
    cv::minMaxLoc(result, NULL, &maxScore, NULL, &maxLocation);
    cv::Point bestLocation = maxLocation;
    double bestScore = maxScore;
    if (!isfinite(bestScore) || bestScore < threshold) {
        return nil;
    }

    cv::Rect matchedPixelRect(bestLocation.x, bestLocation.y, templ.cols, templ.rows);
    if (matchedPixelRect.x < 0 ||
        matchedPixelRect.y < 0 ||
        matchedPixelRect.x + matchedPixelRect.width > source.cols ||
        matchedPixelRect.y + matchedPixelRect.height > source.rows) {
        return nil;
    }
    cv::Mat absoluteDifference;
    cv::absdiff(source(matchedPixelRect), templ, absoluteDifference);
    cv::Scalar meanDifference = cv::mean(absoluteDifference);
    double averageDifference = (meanDifference[0] + meanDifference[1] + meanDifference[2]) / 3.0;
    double pixelSimilarity = 1.0 - MIN(1.0, MAX(0.0, averageDifference / 255.0));
    double minimumPixelSimilarity = MAX(0.58, MIN(0.90, threshold - 0.16));
    if (!isfinite(pixelSimilarity) || pixelSimilarity < minimumPixelSimilarity) {
        NSLog(@"[AnClick] Rejected template match score %.3f pixelSimilarity %.3f threshold %.3f",
              bestScore,
              pixelSimilarity,
              threshold);
        return nil;
    }

    CGFloat scale = sourceImage.scale > 0 ? sourceImage.scale : UIScreen.mainScreen.scale;
    BOOL sourceMatFlipped = AnClickMatAppearsVerticallyFlippedFromImage(sourceImage, source);
    CGRect contentRect = templateEntry.contentRect;
    CGPoint contentTopLeftPixel = CGPointZero;
    CGPoint contentBottomRightPixel = CGPointZero;
    if (sourceMatFlipped) {
        CGFloat topY = (CGFloat)source.rows - ((CGFloat)bestLocation.y + CGRectGetMaxY(contentRect));
        CGFloat bottomY = (CGFloat)source.rows - ((CGFloat)bestLocation.y + CGRectGetMinY(contentRect));
        contentTopLeftPixel = CGPointMake((CGFloat)bestLocation.x + contentRect.origin.x, topY);
        contentBottomRightPixel = CGPointMake((CGFloat)bestLocation.x + CGRectGetMaxX(contentRect), bottomY);
    } else {
        contentTopLeftPixel = CGPointMake((CGFloat)bestLocation.x + contentRect.origin.x,
                                          (CGFloat)bestLocation.y + contentRect.origin.y);
        contentBottomRightPixel = CGPointMake((CGFloat)bestLocation.x + CGRectGetMaxX(contentRect),
                                              (CGFloat)bestLocation.y + CGRectGetMaxY(contentRect));
    }
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
    NSLog(@"[AnClick] OpenCV match score %.3f pixelSimilarity %.3f rect=(%.1f, %.1f, %.1f, %.1f) screen=(%.1f, %.1f)",
          bestScore,
          pixelSimilarity,
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
        @"pixelSimilarity": @(pixelSimilarity),
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
    cv::Point bestAnchor(0, 0);

    int startX = MAX(0, -minDx);
    int endX = MIN(source.cols - 1, source.cols - 1 - maxDx);
    int startY = MAX(0, -minDy);
    int endY = MIN(source.rows - 1, source.rows - 1 - maxDy);
    if (startX > endX || startY > endY) {
        return nil;
    }

    auto scanRange = [&](int scanStartX, int scanEndX, int scanStartY, int scanEndY) {
        for (int y = scanStartY; y <= scanEndY; y++) {
            const cv::Vec3b *row = source.ptr<cv::Vec3b>(y);
            for (int x = scanStartX; x <= scanEndX; x++) {
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

                BOOL betterMatch = NO;
                if (totalDistanceSquared < bestTotalDistanceSquared - 0.25) {
                    betterMatch = YES;
                }

                if (betterMatch) {
                    bestTotalDistanceSquared = totalDistanceSquared;
                    bestAnchor = cv::Point(x, y);
                    if (bestTotalDistanceSquared <= 0.0) {
                        return;
                    }
                }
            }
        }
    };

    scanRange(startX, endX, startY, endY);

    if (bestTotalDistanceSquared == DBL_MAX) {
        return nil;
    }

    std::vector<cv::Point> matchedPixels;
    matchedPixels.reserve(normalizedPoints.size());
    for (const AnClickColorPoint &point : normalizedPoints) {
        cv::Point matchedPixel(bestAnchor.x + point.dx, bestAnchor.y + point.dy);
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
        [AnClickHammerTouchDriver fastTapAtPoint:point];
    });
    return YES;
}

@end
