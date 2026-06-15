#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AnClickPickerCaptureCompletion)(UIImage *_Nullable image, UIWindow *_Nullable capturedWindow);

@interface AnClickPickerService : NSObject

- (void)captureAfterDelay:(NSTimeInterval)delay completion:(AnClickPickerCaptureCompletion)completion;
- (void)cancelPendingCaptures;
- (BOOL)capturedImage:(UIImage *_Nullable)image matchesWindow:(UIWindow *_Nullable)window;
- (UIImage *_Nullable)croppedImageFromImage:(UIImage *_Nullable)image selectionFrame:(CGRect)selectionFrame;
- (BOOL)saveImage:(UIImage *_Nullable)image toPath:(NSString *)path;
- (UIWindow *)overlayWindowForHostWindow:(UIWindow *_Nullable)hostWindow levelOffset:(CGFloat)levelOffset;
- (void)dismissOverlayWindow:(UIWindow *_Nullable)window;

@end

NS_ASSUME_NONNULL_END
