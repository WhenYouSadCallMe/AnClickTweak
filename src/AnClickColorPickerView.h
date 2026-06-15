#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class AnClickColorPickerView;

@protocol AnClickColorPickerViewDelegate <NSObject>
- (void)colorPickerView:(AnClickColorPickerView *)view didTapImagePoint:(CGPoint)point;
- (void)colorPickerView:(AnClickColorPickerView *)view didSelectSampleAtIndex:(NSUInteger)index;
- (void)colorPickerViewDidDeleteSample:(AnClickColorPickerView *)view;
- (void)colorPickerViewDidConfirm:(AnClickColorPickerView *)view;
- (void)colorPickerViewDidCancel:(AnClickColorPickerView *)view;
@end

@interface AnClickColorPickerView : UIView

- (instancetype)initWithFrame:(CGRect)frame
                        image:(UIImage *)image
                 surfaceColor:(UIColor *)surfaceColor
               separatorColor:(UIColor *)separatorColor
             primaryTextColor:(UIColor *)primaryTextColor
             controlFillColor:(UIColor *)controlFillColor
               highlightColor:(UIColor *)highlightColor
                  dangerColor:(UIColor *)dangerColor NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@property (nonatomic, weak, nullable) id<AnClickColorPickerViewDelegate> delegate;
@property (nonatomic, strong, readonly) UIImage *image;
@property (nonatomic, copy) NSString *infoText;
@property (nonatomic, strong) UIColor *swatchColor;
@property (nonatomic, assign) BOOL deleteEnabled;

- (void)updateSamples:(NSArray<NSDictionary *> *)samples selectedIndex:(NSInteger)selectedIndex;
- (void)showCursorAtImagePoint:(CGPoint)point;
- (void)hideCursor;
- (CGPoint)clampedImagePoint:(CGPoint)point;

@end

NS_ASSUME_NONNULL_END
