#import "AnClickPickerService.h"
#import <dispatch/dispatch.h>
#import <math.h>

@interface AnClickCore : NSObject
+ (UIImage *)captureCurrentWindowImageWithWindow:(UIWindow **)capturedWindow;
@end

@interface AnClickPickerService ()
@property (atomic, assign) NSUInteger captureGeneration;
@end

@implementation AnClickPickerService

- (UIWindowScene *)activeWindowScene {
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes;
        for (UIScene *scene in scenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                return (UIWindowScene *)scene;
            }
        }
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                return (UIWindowScene *)scene;
            }
        }
    }
    return nil;
}

- (void)captureAfterDelay:(NSTimeInterval)delay completion:(AnClickPickerCaptureCompletion)completion {
    NSTimeInterval safeDelay = isfinite(delay) ? MAX(0.0, delay) : 0.0;
    self.captureGeneration = self.captureGeneration + 1;
    NSUInteger generation = self.captureGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(safeDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation != self.captureGeneration) {
            return;
        }
        UIWindow *capturedWindow = nil;
        UIImage *image = [AnClickCore captureCurrentWindowImageWithWindow:&capturedWindow];
        if (generation != self.captureGeneration) {
            return;
        }
        if (completion) {
            completion(image, capturedWindow);
        }
    });
}

- (void)cancelPendingCaptures {
    self.captureGeneration = self.captureGeneration + 1;
}

- (CGRect)screenBoundsForWindow:(UIWindow *_Nullable)window {
    CGRect bounds = CGRectZero;
    if (window && !CGRectIsEmpty(window.bounds)) {
        bounds = window.bounds;
    }
    if (CGRectIsEmpty(bounds)) {
        bounds = UIScreen.mainScreen.bounds;
    }
    bounds.origin = CGPointZero;
    return CGRectStandardize(bounds);
}

- (BOOL)size:(CGSize)lhs isCloseToSize:(CGSize)rhs {
    return fabs(lhs.width - rhs.width) < 0.5 && fabs(lhs.height - rhs.height) < 0.5;
}

- (BOOL)capturedImage:(UIImage *_Nullable)image matchesWindow:(UIWindow *_Nullable)window {
    if (!image.CGImage) {
        return NO;
    }
    if (!window || CGRectIsEmpty(window.bounds)) {
        return YES;
    }

    CGSize windowSize = [self screenBoundsForWindow:window].size;
    CGSize imageSize = image.size;
    CGFloat screenScale = window.screen.scale > 0.0 ? window.screen.scale : UIScreen.mainScreen.scale;
    CGFloat scale = image.scale > 0.0 ? image.scale : screenScale;
    CGSize pixelPointSize = CGSizeMake((CGFloat)CGImageGetWidth(image.CGImage) / MAX(scale, 0.01),
                                       (CGFloat)CGImageGetHeight(image.CGImage) / MAX(scale, 0.01));
    BOOL directMatch = [self size:imageSize isCloseToSize:windowSize] ||
        [self size:pixelPointSize isCloseToSize:windowSize];
    if (!directMatch) {
        NSLog(@"[AnClick] Capture size mismatch image=(%.1f, %.1f) pixelPoint=(%.1f, %.1f) window=(%.1f, %.1f)",
              imageSize.width,
              imageSize.height,
              pixelPointSize.width,
              pixelPointSize.height,
              windowSize.width,
              windowSize.height);
    }
    return directMatch;
}

- (UIImage *_Nullable)croppedImageFromImage:(UIImage *_Nullable)image selectionFrame:(CGRect)selectionFrame {
    if (!image.CGImage || CGRectIsEmpty(selectionFrame)) {
        return nil;
    }

    CGFloat scale = image.scale > 0.0 ? image.scale : UIScreen.mainScreen.scale;
    CGRect cropRect = CGRectMake(selectionFrame.origin.x * scale,
                                 selectionFrame.origin.y * scale,
                                 selectionFrame.size.width * scale,
                                 selectionFrame.size.height * scale);
    CGRect imageBounds = CGRectMake(0.0,
                                    0.0,
                                    (CGFloat)CGImageGetWidth(image.CGImage),
                                    (CGFloat)CGImageGetHeight(image.CGImage));
    cropRect = CGRectIntegral(CGRectIntersection(cropRect, imageBounds));
    if (CGRectIsEmpty(cropRect) || cropRect.size.width < 1.0 || cropRect.size.height < 1.0) {
        return nil;
    }

    CGImageRef croppedRef = CGImageCreateWithImageInRect(image.CGImage, cropRect);
    if (!croppedRef) {
        return nil;
    }
    UIImage *croppedImage = [UIImage imageWithCGImage:croppedRef scale:scale orientation:image.imageOrientation];
    CGImageRelease(croppedRef);
    return croppedImage;
}

- (BOOL)saveImage:(UIImage *_Nullable)image toPath:(NSString *)path {
    if (!image.CGImage || path.length == 0) {
        return NO;
    }
    NSData *pngData = UIImagePNGRepresentation(image);
    if (pngData.length == 0) {
        return NO;
    }
    return [pngData writeToFile:path atomically:YES];
}

- (UIWindow *)overlayWindowForHostWindow:(UIWindow *_Nullable)hostWindow levelOffset:(CGFloat)levelOffset {
    UIWindow *window = [[UIWindow alloc] initWithFrame:[self screenBoundsForWindow:hostWindow]];
    if (@available(iOS 13.0, *)) {
        window.windowScene = hostWindow.windowScene ?: [self activeWindowScene];
    }
    window.windowLevel = UIWindowLevelAlert + levelOffset;
    window.backgroundColor = UIColor.blackColor;
    window.rootViewController = [[UIViewController alloc] init];
    window.rootViewController.view.frame = window.bounds;
    window.rootViewController.view.backgroundColor = UIColor.blackColor;
    return window;
}

- (void)dismissOverlayWindow:(UIWindow *_Nullable)window {
    window.hidden = YES;
    window.rootViewController = nil;
}

@end
