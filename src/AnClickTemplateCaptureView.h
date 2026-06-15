#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class AnClickTemplateCaptureView;

@protocol AnClickTemplateCaptureViewDelegate <NSObject>
- (void)templateCaptureView:(AnClickTemplateCaptureView *)view didSelectFrame:(CGRect)selectionFrame;
- (void)templateCaptureViewDidCancel:(AnClickTemplateCaptureView *)view;
@end

@interface AnClickTemplateCaptureView : UIView

- (instancetype)initWithFrame:(CGRect)frame image:(UIImage *)image NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@property (nonatomic, weak, nullable) id<AnClickTemplateCaptureViewDelegate> delegate;
@property (nonatomic, strong, readonly) UIImage *image;
@property (nonatomic, assign, readonly) CGRect selectionFrame;

@end

NS_ASSUME_NONNULL_END
