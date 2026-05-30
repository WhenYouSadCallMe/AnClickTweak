#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#include <vector>

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
@end

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
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
    size_t bytesPerRow = width * 4;
    std::vector<unsigned char> data(height * bytesPerRow);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data.data(),
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    if (context) {
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGContextRelease(context);
    }
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

+ (NSValue *)findTemplateImage:(UIImage *)templateImage threshold:(double)threshold {
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
    CGPoint windowPoint = CGPointMake(((CGFloat)bestLocation.x + (CGFloat)templ.cols * 0.5) / scale,
                                      ((CGFloat)bestLocation.y + (CGFloat)templ.rows * 0.5) / scale);
    CGPoint screenPoint = sourceWindow ? [sourceWindow convertPoint:windowPoint toWindow:nil] : windowPoint;
    NSLog(@"[AnClick] OpenCV match score %.3f window=(%.1f, %.1f) screen=(%.1f, %.1f)",
          bestScore,
          windowPoint.x,
          windowPoint.y,
          screenPoint.x,
          screenPoint.y);
    return [NSValue valueWithCGPoint:screenPoint];
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
