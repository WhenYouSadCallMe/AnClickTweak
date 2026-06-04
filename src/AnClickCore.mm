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

@implementation AnClickCore

+ (UIImage *)captureCurrentWindowImage {
    return AnClickCaptureActiveWindowImage(NULL);
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
    CGPoint topLeftWindowPoint = CGPointMake((CGFloat)bestLocation.x / scale,
                                             (CGFloat)bestLocation.y / scale);
    CGPoint bottomRightWindowPoint = CGPointMake(((CGFloat)bestLocation.x + (CGFloat)templ.cols) / scale,
                                                 ((CGFloat)bestLocation.y + (CGFloat)templ.rows) / scale);
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
    CGPoint windowPoint = CGPointMake((CGFloat)bestPoint.x / scale, (CGFloat)bestPoint.y / scale);
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
