#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <stdlib.h>

@interface AnClickFakeTouch : NSObject
+ (void)tapAtPoint:(CGPoint)point;
@end

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImage;
+ (NSValue *)findTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
+ (BOOL)findAndTapTemplateImage:(UIImage *)templateImage threshold:(double)threshold;
@end

typedef struct {
    size_t width;
    size_t height;
    size_t bytesPerRow;
    unsigned char *data;
} AnClickBitmap;

static void AnClickBitmapRelease(AnClickBitmap *bitmap) {
    if (bitmap && bitmap->data) {
        free(bitmap->data);
        bitmap->data = NULL;
    }
}

static UIWindow *AnClickActiveWindow(void) {
    UIWindow *fallback = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow && !window.hidden && window.alpha > 0.01) {
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
    if (UIApplication.sharedApplication.keyWindow && !UIApplication.sharedApplication.keyWindow.hidden && UIApplication.sharedApplication.keyWindow.alpha > 0.01) {
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

static AnClickBitmap AnClickBitmapFromUIImage(UIImage *image) {
    AnClickBitmap bitmap = {0, 0, 0, NULL};
    if (!image.CGImage) {
        return bitmap;
    }

    CGImageRef imageRef = image.CGImage;
    bitmap.width = CGImageGetWidth(imageRef);
    bitmap.height = CGImageGetHeight(imageRef);
    bitmap.bytesPerRow = bitmap.width * 4;
    bitmap.data = (unsigned char *)calloc(bitmap.height, bitmap.bytesPerRow);
    if (!bitmap.data) {
        bitmap.width = 0;
        bitmap.height = 0;
        bitmap.bytesPerRow = 0;
        return bitmap;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(bitmap.data,
                                                 bitmap.width,
                                                 bitmap.height,
                                                 8,
                                                 bitmap.bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    if (context) {
        CGContextDrawImage(context, CGRectMake(0, 0, bitmap.width, bitmap.height), imageRef);
        CGContextRelease(context);
    }
    CGColorSpaceRelease(colorSpace);

    return bitmap;
}

static double AnClickTemplateScore(const AnClickBitmap *source,
                                   const AnClickBitmap *templ,
                                   size_t originX,
                                   size_t originY,
                                   double minimumScore) {
    uint64_t diff = 0;
    uint64_t pixelCount = (uint64_t)templ->width * (uint64_t)templ->height;
    uint64_t maxDiff = pixelCount * 255ULL * 3ULL;
    uint64_t allowedDiff = (uint64_t)((1.0 - minimumScore) * (double)maxDiff);

    for (size_t y = 0; y < templ->height; y++) {
        const unsigned char *sourceRow = source->data + (originY + y) * source->bytesPerRow + originX * 4;
        const unsigned char *templateRow = templ->data + y * templ->bytesPerRow;
        for (size_t x = 0; x < templ->width; x++) {
            const unsigned char *sourcePixel = sourceRow + x * 4;
            const unsigned char *templatePixel = templateRow + x * 4;
            diff += (uint64_t)labs((long)sourcePixel[0] - (long)templatePixel[0]);
            diff += (uint64_t)labs((long)sourcePixel[1] - (long)templatePixel[1]);
            diff += (uint64_t)labs((long)sourcePixel[2] - (long)templatePixel[2]);
            if (diff > allowedDiff) {
                return 0.0;
            }
        }
    }

    return 1.0 - ((double)diff / (double)maxDiff);
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

    AnClickBitmap source = AnClickBitmapFromUIImage(sourceImage);
    AnClickBitmap templ = AnClickBitmapFromUIImage(templateImage);
    if (!source.data || !templ.data || source.width < templ.width || source.height < templ.height) {
        AnClickBitmapRelease(&source);
        AnClickBitmapRelease(&templ);
        return nil;
    }

    double bestScore = 0.0;
    size_t bestX = 0;
    size_t bestY = 0;
    size_t maxX = source.width - templ.width;
    size_t maxY = source.height - templ.height;

    for (size_t y = 0; y <= maxY; y++) {
        for (size_t x = 0; x <= maxX; x++) {
            double minimumScore = MAX(threshold, bestScore);
            double score = AnClickTemplateScore(&source, &templ, x, y, minimumScore);
            if (score > bestScore) {
                bestScore = score;
                bestX = x;
                bestY = y;
            }
        }
    }

    if (bestScore < threshold) {
        AnClickBitmapRelease(&source);
        AnClickBitmapRelease(&templ);
        return nil;
    }

    CGFloat scale = UIScreen.mainScreen.scale;
    CGFloat centerX = ((CGFloat)bestX + (CGFloat)templ.width * 0.5) / scale;
    CGFloat centerY = ((CGFloat)bestY + (CGFloat)templ.height * 0.5) / scale;
    AnClickBitmapRelease(&source);
    AnClickBitmapRelease(&templ);
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
