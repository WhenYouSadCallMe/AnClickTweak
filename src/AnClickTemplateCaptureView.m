#import "AnClickTemplateCaptureView.h"
#import <math.h>

typedef NS_OPTIONS(NSInteger, AnClickCaptureSelectionEditMode) {
    AnClickCaptureSelectionEditModeNone = 0,
    AnClickCaptureSelectionEditModeMove = 1 << 0,
    AnClickCaptureSelectionEditModeLeft = 1 << 1,
    AnClickCaptureSelectionEditModeRight = 1 << 2,
    AnClickCaptureSelectionEditModeTop = 1 << 3,
    AnClickCaptureSelectionEditModeBottom = 1 << 4,
};

@interface AnClickTemplateCaptureView () <UIScrollViewDelegate>
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *selectionView;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, assign) BOOL drawingSelection;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) AnClickCaptureSelectionEditMode selectionEditMode;
@property (nonatomic, assign) CGRect selectionStartFrame;
@end

@implementation AnClickTemplateCaptureView

- (CGRect)selectionFrame {
    return self.selectionView.hidden ? CGRectZero : self.selectionView.frame;
}

- (instancetype)initWithFrame:(CGRect)frame image:(UIImage *)image {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    _image = image;
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
    hint.text = @"双指缩放移动，单指框选/拖边调整";
    hint.textColor = UIColor.systemYellowColor;
    hint.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    hint.adjustsFontSizeToFitWidth = YES;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.72];
    hint.layer.cornerRadius = 13.0;
    hint.layer.borderWidth = 1.0;
    hint.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.22].CGColor;
    hint.layer.shadowColor = UIColor.blackColor.CGColor;
    hint.layer.shadowOffset = CGSizeMake(0, 3.0);
    hint.layer.shadowRadius = 8.0;
    hint.layer.shadowOpacity = 0.32;
    hint.clipsToBounds = NO;
    [self addSubview:hint];
    hint.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *selection = [[UIView alloc] initWithFrame:CGRectZero];
    selection.backgroundColor = UIColor.clearColor;
    selection.layer.borderColor = UIColor.systemYellowColor.CGColor;
    selection.layer.borderWidth = 2.0;
    selection.userInteractionEnabled = NO;
    selection.hidden = YES;
    [imageView addSubview:selection];
    self.selectionView = selection;

    UIPanGestureRecognizer *drawPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrawPan:)];
    drawPan.maximumNumberOfTouches = 1;
    drawPan.cancelsTouchesInView = NO;
    [imageView addGestureRecognizer:drawPan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleOverlayTap:)];
    tap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tap];

    UIButton *saveButton = [self actionButtonWithTitle:@"保存" action:@selector(handleSave)];
    saveButton.tag = 3001;
    saveButton.hidden = YES;
    [self addSubview:saveButton];
    self.saveButton = saveButton;

    UIButton *cancelButton = [self actionButtonWithTitle:@"取消" action:@selector(handleCancel)];
    cancelButton.tag = 3002;
    [self addSubview:cancelButton];
    self.cancelButton = cancelButton;

    [NSLayoutConstraint activateConstraints:@[
        [hint.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:10.0],
        [hint.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12.0],
        [hint.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12.0],
        [hint.heightAnchor constraintEqualToConstant:42.0]
    ]];

    CGFloat minZoom = [self minimumZoomScaleForImageSize:image.size inBoundsSize:scrollView.bounds.size];
    scrollView.minimumZoomScale = minZoom;
    scrollView.zoomScale = minZoom;
    [self centerImageContent];
    [self relayout];
    return self;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    BOOL primary = [title isEqualToString:@"保存"];
    [button setTitleColor:(primary ? UIColor.whiteColor : UIColor.whiteColor) forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    button.backgroundColor = primary ? [UIColor systemBlueColor] : [[UIColor whiteColor] colorWithAlphaComponent:0.12];
    button.layer.cornerRadius = 8.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.16].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.scrollView.frame = self.bounds;
    [self relayout];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return scrollView == self.scrollView ? self.imageView : nil;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) {
        return;
    }
    [self centerImageContent];
    [self relayout];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.scrollView) {
        [self relayout];
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

- (void)centerImageContent {
    CGSize boundsSize = self.scrollView.bounds.size;
    CGRect frame = self.imageView.frame;
    frame.origin.x = frame.size.width < boundsSize.width ? (boundsSize.width - frame.size.width) * 0.5 : 0.0;
    frame.origin.y = frame.size.height < boundsSize.height ? (boundsSize.height - frame.size.height) * 0.5 : 0.0;
    self.imageView.frame = frame;
}

- (void)relayout {
    CGFloat minZoom = [self minimumZoomScaleForImageSize:self.image.size inBoundsSize:self.scrollView.bounds.size];
    self.scrollView.minimumZoomScale = minZoom;
    if (self.scrollView.zoomScale < minZoom) {
        self.scrollView.zoomScale = minZoom;
    }
    [self centerImageContent];

    UIEdgeInsets insets = self.safeAreaInsets;
    CGFloat margin = 14.0;
    CGFloat gap = 12.0;
    CGFloat buttonWidth = 86.0;
    CGFloat buttonHeight = 44.0;
    CGFloat bottomY = self.bounds.size.height - buttonHeight - MAX(margin, insets.bottom + margin);
    CGFloat cancelX = self.bounds.size.width - insets.right - margin - buttonWidth;
    self.cancelButton.frame = CGRectMake(cancelX, bottomY, buttonWidth, buttonHeight);

    if (self.selectionView.hidden || CGRectIsEmpty(self.selectionView.frame)) {
        self.saveButton.hidden = YES;
        self.cancelButton.hidden = NO;
        return;
    }

    CGRect selectionFrame = [self.selectionView.superview convertRect:self.selectionView.frame toView:self];
    CGFloat totalWidth = buttonWidth * 2.0 + gap;
    CGFloat minX = insets.left + margin;
    CGFloat maxX = self.bounds.size.width - insets.right - totalWidth - margin;
    CGFloat x = MIN(MAX(CGRectGetMidX(selectionFrame) - totalWidth * 0.5, minX), maxX);

    CGFloat belowY = CGRectGetMaxY(selectionFrame) + margin;
    CGFloat aboveY = CGRectGetMinY(selectionFrame) - buttonHeight - margin;
    CGFloat minY = MAX(margin, insets.top + margin);
    CGFloat maxY = self.bounds.size.height - buttonHeight - MAX(margin, insets.bottom + margin);
    CGFloat y = belowY <= maxY ? belowY : (aboveY >= minY ? aboveY : maxY);

    self.saveButton.frame = CGRectMake(x, y, buttonWidth, buttonHeight);
    self.cancelButton.frame = CGRectMake(x + buttonWidth + gap, y, buttonWidth, buttonHeight);
    self.saveButton.hidden = NO;
    self.cancelButton.hidden = NO;
}

- (CGRect)clampedSelectionFrame:(CGRect)frame {
    CGRect bounds = self.imageView ? self.imageView.bounds : self.bounds;
    CGFloat minSide = 8.0;
    CGFloat maxWidth = MAX(minSide, bounds.size.width);
    CGFloat maxHeight = MAX(minSide, bounds.size.height);
    frame.size.width = MIN(MAX(frame.size.width, minSide), maxWidth);
    frame.size.height = MIN(MAX(frame.size.height, minSide), maxHeight);
    frame.origin.x = MIN(MAX(frame.origin.x, 0.0), bounds.size.width - frame.size.width);
    frame.origin.y = MIN(MAX(frame.origin.y, 0.0), bounds.size.height - frame.size.height);
    return frame;
}

- (CGRect)selectionFrameFromPoint:(CGPoint)startPoint toPoint:(CGPoint)endPoint {
    return [self clampedSelectionFrame:CGRectStandardize(CGRectMake(startPoint.x,
                                                                     startPoint.y,
                                                                     endPoint.x - startPoint.x,
                                                                     endPoint.y - startPoint.y))];
}

- (CGFloat)selectionHitOutset {
    CGFloat zoomScale = MAX(self.scrollView.zoomScale, 0.01);
    return MAX(10.0, 24.0 / zoomScale);
}

- (AnClickCaptureSelectionEditMode)selectionEditModeAtImagePoint:(CGPoint)point {
    if (self.selectionView.hidden || CGRectIsEmpty(self.selectionView.frame)) {
        return AnClickCaptureSelectionEditModeNone;
    }
    CGRect frame = self.selectionView.frame;
    CGFloat hitOutset = [self selectionHitOutset];
    CGRect hitFrame = CGRectInset(frame, -hitOutset, -hitOutset);
    if (!CGRectContainsPoint(hitFrame, point)) {
        return AnClickCaptureSelectionEditModeNone;
    }
    AnClickCaptureSelectionEditMode mode = AnClickCaptureSelectionEditModeNone;
    CGFloat leftDistance = fabs(point.x - CGRectGetMinX(frame));
    CGFloat rightDistance = fabs(point.x - CGRectGetMaxX(frame));
    CGFloat topDistance = fabs(point.y - CGRectGetMinY(frame));
    CGFloat bottomDistance = fabs(point.y - CGRectGetMaxY(frame));
    if (MIN(leftDistance, rightDistance) <= hitOutset) {
        mode |= leftDistance <= rightDistance ? AnClickCaptureSelectionEditModeLeft : AnClickCaptureSelectionEditModeRight;
    }
    if (MIN(topDistance, bottomDistance) <= hitOutset) {
        mode |= topDistance <= bottomDistance ? AnClickCaptureSelectionEditModeTop : AnClickCaptureSelectionEditModeBottom;
    }
    if (mode != AnClickCaptureSelectionEditModeNone) {
        return mode;
    }
    return CGRectContainsPoint(frame, point) ? AnClickCaptureSelectionEditModeMove : AnClickCaptureSelectionEditModeNone;
}

- (CGRect)selectionFrameByEditingFrame:(CGRect)baseFrame mode:(AnClickCaptureSelectionEditMode)mode translation:(CGPoint)translation {
    CGRect bounds = self.imageView ? self.imageView.bounds : self.bounds;
    CGFloat minSide = 8.0;
    if (mode == AnClickCaptureSelectionEditModeMove) {
        CGRect movedFrame = baseFrame;
        movedFrame.origin.x += translation.x;
        movedFrame.origin.y += translation.y;
        return [self clampedSelectionFrame:movedFrame];
    }
    CGFloat minX = CGRectGetMinX(baseFrame);
    CGFloat maxX = CGRectGetMaxX(baseFrame);
    CGFloat minY = CGRectGetMinY(baseFrame);
    CGFloat maxY = CGRectGetMaxY(baseFrame);
    CGFloat boundsMaxX = MAX(0.0, bounds.size.width);
    CGFloat boundsMaxY = MAX(0.0, bounds.size.height);
    if (mode & AnClickCaptureSelectionEditModeLeft) {
        minX = MIN(maxX - minSide, MAX(0.0, minX + translation.x));
    }
    if (mode & AnClickCaptureSelectionEditModeRight) {
        maxX = MAX(minX + minSide, MIN(boundsMaxX, maxX + translation.x));
    }
    if (mode & AnClickCaptureSelectionEditModeTop) {
        minY = MIN(maxY - minSide, MAX(0.0, minY + translation.y));
    }
    if (mode & AnClickCaptureSelectionEditModeBottom) {
        maxY = MAX(minY + minSide, MIN(boundsMaxY, maxY + translation.y));
    }
    return [self clampedSelectionFrame:CGRectMake(minX, minY, maxX - minX, maxY - minY)];
}

- (void)finishSelectionInteraction {
    self.drawingSelection = NO;
    self.selectionEditMode = AnClickCaptureSelectionEditModeNone;
    self.selectionStartFrame = CGRectZero;
    if (self.selectionView.frame.size.width < 8.0 || self.selectionView.frame.size.height < 8.0) {
        self.selectionView.hidden = YES;
        self.selectionView.frame = CGRectZero;
        self.saveButton.hidden = YES;
    } else {
        self.selectionView.hidden = NO;
    }
    [self relayout];
}

- (void)handleOverlayTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    CGPoint point = [recognizer locationInView:self];
    if (CGRectContainsPoint(CGRectInset(self.saveButton.frame, -8.0, -8.0), point)) {
        [self handleSave];
    } else if (CGRectContainsPoint(CGRectInset(self.cancelButton.frame, -8.0, -8.0), point)) {
        [self handleCancel];
    }
}

- (void)handleDrawPan:(UIPanGestureRecognizer *)recognizer {
    CGPoint point = [self clampedPoint:[recognizer locationInView:self.imageView]];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.selectionEditMode = [self selectionEditModeAtImagePoint:point];
        if (self.selectionEditMode != AnClickCaptureSelectionEditModeNone) {
            self.drawingSelection = NO;
            self.selectionStartFrame = self.selectionView.frame;
            [recognizer setTranslation:CGPointZero inView:self.imageView];
            self.saveButton.hidden = YES;
            return;
        }
        self.drawingSelection = YES;
        self.selectionStartFrame = CGRectZero;
        self.dragStartPoint = point;
        self.selectionView.hidden = NO;
        self.selectionView.frame = CGRectMake(point.x, point.y, 1.0, 1.0);
        self.saveButton.hidden = YES;
        return;
    }
    if (self.selectionEditMode != AnClickCaptureSelectionEditModeNone) {
        if (recognizer.state == UIGestureRecognizerStateChanged || recognizer.state == UIGestureRecognizerStateEnded) {
            CGPoint translation = [recognizer translationInView:self.imageView];
            self.selectionView.frame = [self selectionFrameByEditingFrame:self.selectionStartFrame mode:self.selectionEditMode translation:translation];
        }
        if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed) {
            [self finishSelectionInteraction];
        }
        return;
    }
    if (self.drawingSelection && (recognizer.state == UIGestureRecognizerStateChanged || recognizer.state == UIGestureRecognizerStateEnded)) {
        CGRect frame = [self selectionFrameFromPoint:self.dragStartPoint toPoint:point];
        self.selectionView.frame = frame;
        self.selectionView.hidden = CGRectGetWidth(frame) < 2.0 || CGRectGetHeight(frame) < 2.0;
    }
    if (self.drawingSelection && (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed)) {
        [self finishSelectionInteraction];
    }
}

- (CGPoint)clampedPoint:(CGPoint)point {
    CGRect bounds = self.imageView ? self.imageView.bounds : self.bounds;
    point.x = MIN(MAX(point.x, 0.0), bounds.size.width);
    point.y = MIN(MAX(point.y, 0.0), bounds.size.height);
    return point;
}

- (void)handleSave {
    if (!self.selectionView || self.selectionView.hidden || CGRectIsEmpty(self.selectionView.frame)) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(templateCaptureView:didSelectFrame:)]) {
        [self.delegate templateCaptureView:self didSelectFrame:self.selectionView.frame];
    }
}

- (void)handleCancel {
    if ([self.delegate respondsToSelector:@selector(templateCaptureViewDidCancel:)]) {
        [self.delegate templateCaptureViewDidCancel:self];
    }
}

@end
