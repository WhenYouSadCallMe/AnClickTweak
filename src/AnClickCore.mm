#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <opencv2/opencv.hpp>

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
                if (window.isKeyWindow) {
                    return window;
                }
                if (!fallback && !window.hidden && window.alpha > 0.01) {
                    fallback = window;
                }
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (UIApplication.sharedApplication.keyWindow) {
        return UIApplication.sharedApplication.keyWindow;
    }
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (!window.hidden && window.alpha > 0.01) {
            return window;
        }
    }
#pragma clang diagnostic pop
    return fallback;
}

static cv::Mat AnClickMatFromUIImage(UIImage *image) {
    if (!image.CGImage) {
        return cv::Mat();
    }

    CGImageRef imageRef = image.CGImage;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    cv::Mat rgba((int)height, (int)width, CV_8UC4);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgba.data,
                                                 width,
                                                 height,
                                                 8,
                                                 rgba.step[0],
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    if (context) {
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGContextRelease(context);
    }
    CGColorSpaceRelease(colorSpace);

    cv::Mat bgr;
    cv::cvtColor(rgba, bgr, cv::COLOR_RGBA2BGR);
    return bgr;
}

@implementation AnClickCore

+ (UIImage *)captureCurrentWindowImage {
    __block UIImage *image = nil;
    void (^captureBlock)(void) = ^{
        UIWindow *window = AnClickActiveWindow();
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
    return image;
}

+ (NSValue *)findTemplateImage:(UIImage *)templateImage threshold:(double)threshold {
    UIImage *sourceImage = [self captureCurrentWindowImage];
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

    double minValue = 0;
    double maxValue = 0;
    cv::Point minLocation;
    cv::Point maxLocation;
    cv::minMaxLoc(result, &minValue, &maxValue, &minLocation, &maxLocation);
    if (maxValue < threshold) {
        return nil;
    }

    CGFloat scale = UIScreen.mainScreen.scale;
    CGFloat centerX = ((CGFloat)maxLocation.x + (CGFloat)templ.cols * 0.5) / scale;
    CGFloat centerY = ((CGFloat)maxLocation.y + (CGFloat)templ.rows * 0.5) / scale;
    return [NSValue valueWithCGPoint:CGPointMake(centerX, centerY)];
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
