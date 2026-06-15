#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class AnClickPointPickerView;

@protocol AnClickPointPickerViewDelegate <NSObject>
- (void)pointPickerView:(AnClickPointPickerView *)view didMoveToImagePoint:(CGPoint)point;
- (void)pointPickerViewDidConfirm:(AnClickPointPickerView *)view;
- (void)pointPickerViewDidCancel:(AnClickPointPickerView *)view;
@end

@interface AnClickPointPickerView : UIView

- (instancetype)initWithFrame:(CGRect)frame
                        image:(UIImage *)image
                 initialPoint:(CGPoint)initialPoint
                 surfaceColor:(UIColor *)surfaceColor
               separatorColor:(UIColor *)separatorColor
             primaryTextColor:(UIColor *)primaryTextColor
             controlFillColor:(UIColor *)controlFillColor
               highlightColor:(UIColor *)highlightColor NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@property (nonatomic, weak, nullable) id<AnClickPointPickerViewDelegate> delegate;
@property (nonatomic, strong, readonly) UIImage *image;
@property (nonatomic, assign) CGPoint selectedImagePoint;
@property (nonatomic, copy) NSString *coordinateText;

- (void)showStartMarkerAtImagePoint:(CGPoint)point;
- (void)clearStartMarker;
- (CGPoint)clampedImagePoint:(CGPoint)point;

@end

NS_ASSUME_NONNULL_END
