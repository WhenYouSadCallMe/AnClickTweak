#import "AnClickPointPickerView.h"
#import <math.h>

static const NSInteger AnClickPointPickerStartMarkerTag = 2201;

@interface AnClickPointPickerView () <UIScrollViewDelegate>
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *cursorView;
@property (nonatomic, strong) UIView *toolbar;
@property (nonatomic, strong) UILabel *coordinateLabel;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIColor *surfaceColor;
@property (nonatomic, strong) UIColor *separatorColor;
@property (nonatomic, strong) UIColor *primaryTextColor;
@property (nonatomic, strong) UIColor *controlFillColor;
@property (nonatomic, strong) UIColor *highlightColor;
@end

@implementation AnClickPointPickerView

- (instancetype)initWithFrame:(CGRect)frame
                        image:(UIImage *)image
                 initialPoint:(CGPoint)initialPoint
                 surfaceColor:(UIColor *)surfaceColor
               separatorColor:(UIColor *)separatorColor
             primaryTextColor:(UIColor *)primaryTextColor
             controlFillColor:(UIColor *)controlFillColor
               highlightColor:(UIColor *)highlightColor {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    _image = image;
    _surfaceColor = surfaceColor ?: [UIColor colorWithWhite:0.12 alpha:1.0];
    _separatorColor = separatorColor ?: [UIColor colorWithWhite:1.0 alpha:0.18];
    _primaryTextColor = primaryTextColor ?: UIColor.whiteColor;
    _controlFillColor = controlFillColor ?: [UIColor colorWithWhite:1.0 alpha:0.12];
    _highlightColor = highlightColor ?: UIColor.systemBlueColor;
    _coordinateText = @"";

    self.backgroundColor = UIColor.blackColor;
    self.userInteractionEnabled = YES;

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.delegate = self;
    scrollView.backgroundColor = UIColor.blackColor;
    scrollView.minimumZoomScale = 1.0;
    scrollView.maximumZoomScale = 8.0;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.panGestureRecognizer.minimumNumberOfTouches = 2;
    [self addSubview:scrollView];
    self.scrollView = scrollView;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    imageView.userInteractionEnabled = YES;
    [scrollView addSubview:imageView];
    self.imageView = imageView;
    scrollView.contentSize = imageView.bounds.size;

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectZero];
    hint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    hint.text = @"双指缩放移动，单指点选或微调";
    hint.textColor = UIColor.whiteColor;
    hint.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    hint.adjustsFontSizeToFitWidth = YES;
    hint.textAlignment = NSTextAlignmentCenter;
    [self addSubview:hint];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [hint.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:12.0],
        [hint.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12.0],
        [hint.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12.0],
        [hint.heightAnchor constraintEqualToConstant:38.0]
    ]];

    self.cursorView = [self newCursorView];
    [imageView addSubview:self.cursorView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.cancelsTouchesInView = NO;
    [imageView addGestureRecognizer:tap];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.maximumNumberOfTouches = 1;
    pan.cancelsTouchesInView = NO;
    [imageView addGestureRecognizer:pan];

    UIView *toolbar = [[UIView alloc] initWithFrame:CGRectZero];
    toolbar.backgroundColor = [_surfaceColor colorWithAlphaComponent:0.90];
    toolbar.layer.cornerRadius = 12.0;
    toolbar.layer.borderWidth = 1.0;
    toolbar.layer.borderColor = [_separatorColor colorWithAlphaComponent:0.72].CGColor;
    toolbar.layer.shadowColor = UIColor.blackColor.CGColor;
    toolbar.layer.shadowOffset = CGSizeMake(0, 4);
    toolbar.layer.shadowRadius = 14.0;
    toolbar.layer.shadowOpacity = 0.16;
    toolbar.clipsToBounds = NO;
    [self addSubview:toolbar];
    self.toolbar = toolbar;

    UILabel *coordinateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    coordinateLabel.textColor = _primaryTextColor;
    coordinateLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    coordinateLabel.adjustsFontSizeToFitWidth = YES;
    coordinateLabel.minimumScaleFactor = 0.65;
    [toolbar addSubview:coordinateLabel];
    self.coordinateLabel = coordinateLabel;

    UIButton *confirmButton = [self buttonWithTitle:@"确定" primary:YES action:@selector(confirmTapped)];
    [toolbar addSubview:confirmButton];
    self.confirmButton = confirmButton;

    UIButton *cancelButton = [self buttonWithTitle:@"取消" primary:NO action:@selector(cancelTapped)];
    [toolbar addSubview:cancelButton];
    self.cancelButton = cancelButton;

    CGFloat minZoom = [self minimumZoomScaleForImageSize:image.size inBoundsSize:scrollView.bounds.size];
    scrollView.minimumZoomScale = minZoom;
    scrollView.zoomScale = minZoom;
    [self centerImageContent];
    self.selectedImagePoint = [self clampedImagePoint:initialPoint];
    [self updateCursor];
    [self relayoutToolbar];
    return self;
}

- (UIView *)newCursorView {
    CGFloat cursorSize = 32.0;
    UIView *cursor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cursorSize, cursorSize)];
    cursor.backgroundColor = UIColor.clearColor;
    cursor.layer.cornerRadius = cursorSize * 0.5;
    cursor.layer.borderWidth = 1.25;
    cursor.layer.borderColor = UIColor.systemYellowColor.CGColor;
    cursor.userInteractionEnabled = NO;

    UIView *horizontal = [[UIView alloc] initWithFrame:CGRectMake(6, cursorSize * 0.5 - 0.5, cursorSize - 12, 1)];
    horizontal.tag = 1;
    horizontal.backgroundColor = UIColor.systemYellowColor;
    horizontal.userInteractionEnabled = NO;
    [cursor addSubview:horizontal];

    UIView *vertical = [[UIView alloc] initWithFrame:CGRectMake(cursorSize * 0.5 - 0.5, 6, 1, cursorSize - 12)];
    vertical.tag = 2;
    vertical.backgroundColor = UIColor.systemYellowColor;
    vertical.userInteractionEnabled = NO;
    [cursor addSubview:vertical];

    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(cursorSize * 0.5 - 2, cursorSize * 0.5 - 2, 4, 4)];
    dot.tag = 3;
    dot.backgroundColor = UIColor.systemRedColor;
    dot.layer.cornerRadius = 2.0;
    dot.userInteractionEnabled = NO;
    [cursor addSubview:dot];
    return cursor;
}

- (UIButton *)buttonWithTitle:(NSString *)title primary:(BOOL)primary action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    button.backgroundColor = primary ? self.highlightColor : self.controlFillColor;
    [button setTitleColor:(primary ? UIColor.whiteColor : self.primaryTextColor) forState:UIControlStateNormal];
    button.layer.cornerRadius = 8.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = (primary
        ? [self.highlightColor colorWithAlphaComponent:0.86]
        : [self.separatorColor colorWithAlphaComponent:0.82]).CGColor;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOffset = CGSizeMake(0, primary ? 2 : 1);
    button.layer.shadowRadius = primary ? 4.0 : 2.0;
    button.layer.shadowOpacity = primary ? 0.12 : 0.04;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)setCoordinateText:(NSString *)coordinateText {
    _coordinateText = [coordinateText copy] ?: @"";
    self.coordinateLabel.text = _coordinateText;
}

- (void)setSelectedImagePoint:(CGPoint)selectedImagePoint {
    _selectedImagePoint = [self clampedImagePoint:selectedImagePoint];
    [self updateCursor];
    [self relayoutToolbar];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.scrollView.frame = self.bounds;
    [self updateZoomForCurrentBounds];
    [self relayoutToolbar];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return scrollView == self.scrollView ? self.imageView : nil;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) {
        return;
    }
    [self centerImageContent];
    [self updateCursor];
    [self relayoutToolbar];
    [self refreshStartMarkerScale];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.scrollView) {
        [self relayoutToolbar];
    }
}

- (CGFloat)minimumZoomScaleForImageSize:(CGSize)imageSize inBoundsSize:(CGSize)boundsSize {
    CGFloat width = MAX(1.0, imageSize.width);
    CGFloat height = MAX(1.0, imageSize.height);
    CGFloat boundWidth = MAX(1.0, boundsSize.width);
    CGFloat boundHeight = MAX(1.0, boundsSize.height);
    CGFloat minZoom = MIN(boundWidth / width, boundHeight / height);
    return MIN(MAX(minZoom, 0.25), 1.0);
}

- (void)updateZoomForCurrentBounds {
    CGFloat minZoom = [self minimumZoomScaleForImageSize:self.image.size inBoundsSize:self.scrollView.bounds.size];
    self.scrollView.minimumZoomScale = minZoom;
    if (self.scrollView.zoomScale < minZoom) {
        self.scrollView.zoomScale = minZoom;
    }
    [self centerImageContent];
}

- (void)centerImageContent {
    CGSize boundsSize = self.scrollView.bounds.size;
    CGRect frame = self.imageView.frame;
    frame.origin.x = frame.size.width < boundsSize.width ? (boundsSize.width - frame.size.width) * 0.5 : 0.0;
    frame.origin.y = frame.size.height < boundsSize.height ? (boundsSize.height - frame.size.height) * 0.5 : 0.0;
    self.imageView.frame = frame;
}

- (CGPoint)clampedImagePoint:(CGPoint)point {
    CGRect bounds = self.imageView ? self.imageView.bounds : CGRectMake(0, 0, self.image.size.width, self.image.size.height);
    point.x = MIN(MAX(point.x, 0.0), bounds.size.width);
    point.y = MIN(MAX(point.y, 0.0), bounds.size.height);
    return point;
}

- (void)updateCursor {
    CGFloat zoomScale = MAX(0.01, self.scrollView.zoomScale);
    CGFloat cursorSize = 28.0 / zoomScale;
    self.cursorView.bounds = CGRectMake(0, 0, cursorSize, cursorSize);
    self.cursorView.center = self.selectedImagePoint;
    self.cursorView.layer.cornerRadius = cursorSize * 0.5;
    self.cursorView.layer.borderWidth = MAX(0.8, 1.2 / zoomScale);

    UIView *horizontal = [self.cursorView viewWithTag:1];
    UIView *vertical = [self.cursorView viewWithTag:2];
    UIView *dot = [self.cursorView viewWithTag:3];
    CGFloat lineInset = 5.0 / zoomScale;
    CGFloat lineThickness = MAX(0.8, 1.0 / zoomScale);
    horizontal.frame = CGRectMake(lineInset,
                                  cursorSize * 0.5 - lineThickness * 0.5,
                                  MAX(0.0, cursorSize - lineInset * 2.0),
                                  lineThickness);
    vertical.frame = CGRectMake(cursorSize * 0.5 - lineThickness * 0.5,
                                lineInset,
                                lineThickness,
                                MAX(0.0, cursorSize - lineInset * 2.0));
    CGFloat dotSize = MAX(2.0, 4.0 / zoomScale);
    dot.frame = CGRectMake((cursorSize - dotSize) * 0.5,
                           (cursorSize - dotSize) * 0.5,
                           dotSize,
                           dotSize);
    dot.layer.cornerRadius = dotSize * 0.5;
}

- (void)relayoutToolbar {
    CGFloat margin = 8.0;
    CGFloat toolbarHeight = 48.0;
    UIEdgeInsets safeInsets = self.safeAreaInsets;
    CGFloat topY = MAX(margin, safeInsets.top + margin);
    CGFloat bottomY = self.bounds.size.height - toolbarHeight - MAX(margin, safeInsets.bottom + margin);
    bottomY = MAX(topY, bottomY);
    CGFloat availableWidth = MAX(1.0, self.bounds.size.width - safeInsets.left - safeInsets.right - margin * 2.0);
    CGFloat toolbarWidth = MIN(availableWidth, 360.0);
    CGFloat x = safeInsets.left + margin + (availableWidth - toolbarWidth) * 0.5;
    CGPoint overlayPoint = [self.imageView convertPoint:self.selectedImagePoint toView:self];
    BOOL cursorNearBottom = overlayPoint.y > bottomY - 20.0;
    CGFloat y = cursorNearBottom ? topY : bottomY;
    self.toolbar.frame = CGRectMake(x, y, toolbarWidth, toolbarHeight);

    CGFloat buttonWidth = MIN(64.0, MAX(0.0, floor((toolbarWidth - margin * 3.0) / 2.0)));
    CGFloat buttonHeight = 34.0;
    CGFloat buttonY = (toolbarHeight - buttonHeight) * 0.5;
    self.cancelButton.frame = CGRectMake(toolbarWidth - margin - buttonWidth, buttonY, buttonWidth, buttonHeight);
    self.confirmButton.frame = CGRectMake(CGRectGetMinX(self.cancelButton.frame) - margin - buttonWidth,
                                          buttonY,
                                          buttonWidth,
                                          buttonHeight);
    self.coordinateLabel.frame = CGRectMake(10.0,
                                            0.0,
                                            MAX(0.0, CGRectGetMinX(self.confirmButton.frame) - 18.0),
                                            toolbarHeight);
    self.confirmButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.confirmButton.bounds
                                                                     cornerRadius:self.confirmButton.layer.cornerRadius].CGPath;
    self.cancelButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cancelButton.bounds
                                                                    cornerRadius:self.cancelButton.layer.cornerRadius].CGPath;
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    [self moveToImagePoint:[recognizer locationInView:self.imageView]];
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [recognizer setTranslation:CGPointZero inView:self.imageView];
        return;
    }
    if (recognizer.state != UIGestureRecognizerStateChanged &&
        recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    CGPoint translation = [recognizer translationInView:self.imageView];
    CGPoint point = CGPointMake(self.selectedImagePoint.x + translation.x,
                                self.selectedImagePoint.y + translation.y);
    [self moveToImagePoint:point];
    [recognizer setTranslation:CGPointZero inView:self.imageView];
}

- (void)moveToImagePoint:(CGPoint)point {
    self.selectedImagePoint = [self clampedImagePoint:point];
    if ([self.delegate respondsToSelector:@selector(pointPickerView:didMoveToImagePoint:)]) {
        [self.delegate pointPickerView:self didMoveToImagePoint:self.selectedImagePoint];
    }
}

- (void)showStartMarkerAtImagePoint:(CGPoint)point {
    [self clearStartMarker];
    CGFloat zoomScale = MAX(0.01, self.scrollView.zoomScale);
    CGFloat size = 22.0 / zoomScale;
    UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    marker.tag = AnClickPointPickerStartMarkerTag;
    marker.center = [self clampedImagePoint:point];
    marker.userInteractionEnabled = NO;
    marker.backgroundColor = UIColor.clearColor;
    marker.layer.cornerRadius = size * 0.5;
    marker.layer.borderWidth = MAX(1.0, 1.8 / zoomScale);
    marker.layer.borderColor = UIColor.systemGreenColor.CGColor;

    CGFloat dotSize = MAX(2.0, 4.0 / zoomScale);
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake((size - dotSize) * 0.5,
                                                           (size - dotSize) * 0.5,
                                                           dotSize,
                                                           dotSize)];
    dot.backgroundColor = UIColor.systemGreenColor;
    dot.layer.cornerRadius = dotSize * 0.5;
    dot.userInteractionEnabled = NO;
    [marker addSubview:dot];
    [self.imageView insertSubview:marker belowSubview:self.cursorView];
}

- (void)clearStartMarker {
    [[self.imageView viewWithTag:AnClickPointPickerStartMarkerTag] removeFromSuperview];
}

- (void)refreshStartMarkerScale {
    UIView *marker = [self.imageView viewWithTag:AnClickPointPickerStartMarkerTag];
    if (!marker) {
        return;
    }
    CGPoint center = marker.center;
    [self showStartMarkerAtImagePoint:center];
}

- (void)confirmTapped {
    if ([self.delegate respondsToSelector:@selector(pointPickerViewDidConfirm:)]) {
        [self.delegate pointPickerViewDidConfirm:self];
    }
}

- (void)cancelTapped {
    if ([self.delegate respondsToSelector:@selector(pointPickerViewDidCancel:)]) {
        [self.delegate pointPickerViewDidCancel:self];
    }
}

@end
