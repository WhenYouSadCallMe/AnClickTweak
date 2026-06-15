#import "AnClickColorPickerView.h"
#import <math.h>

static const NSInteger ACColorPickerMarkerTagBase = 43100;
static const NSInteger ACColorPickerRowTagBase = 43200;
static const NSUInteger ACColorPickerMaxSamples = 32;

@interface AnClickColorPickerView () <UIScrollViewDelegate>
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *cursorView;
@property (nonatomic, strong) UIScrollView *listView;
@property (nonatomic, strong) UIView *toolbar;
@property (nonatomic, strong) UIView *swatchView;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, copy) NSArray<NSDictionary *> *samples;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, strong) UIColor *surfaceColor;
@property (nonatomic, strong) UIColor *separatorColor;
@property (nonatomic, strong) UIColor *primaryTextColor;
@property (nonatomic, strong) UIColor *controlFillColor;
@property (nonatomic, strong) UIColor *highlightColor;
@property (nonatomic, strong) UIColor *dangerColor;
@end

@implementation AnClickColorPickerView

- (instancetype)initWithFrame:(CGRect)frame
                        image:(UIImage *)image
                 surfaceColor:(UIColor *)surfaceColor
               separatorColor:(UIColor *)separatorColor
             primaryTextColor:(UIColor *)primaryTextColor
             controlFillColor:(UIColor *)controlFillColor
               highlightColor:(UIColor *)highlightColor
                  dangerColor:(UIColor *)dangerColor {
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
    _dangerColor = dangerColor ?: UIColor.systemRedColor;
    _samples = @[];
    _selectedIndex = -1;
    _infoText = @"双指查看截图后点选颜色";
    _swatchColor = [UIColor colorWithWhite:1 alpha:0.10];

    self.backgroundColor = UIColor.blackColor;

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.delegate = self;
    scrollView.backgroundColor = UIColor.blackColor;
    scrollView.minimumZoomScale = 1.0;
    scrollView.maximumZoomScale = 8.0;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    [self addSubview:scrollView];
    self.scrollView = scrollView;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    imageView.userInteractionEnabled = YES;
    [scrollView addSubview:imageView];
    self.imageView = imageView;
    scrollView.contentSize = imageView.bounds.size;

    UIView *cursor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 9, 9)];
    cursor.backgroundColor = UIColor.systemYellowColor;
    cursor.layer.cornerRadius = 4.5;
    cursor.layer.borderWidth = 1.0;
    cursor.layer.borderColor = UIColor.blackColor.CGColor;
    cursor.layer.shadowColor = UIColor.blackColor.CGColor;
    cursor.layer.shadowOpacity = 0.55;
    cursor.layer.shadowRadius = 1.0;
    cursor.layer.shadowOffset = CGSizeZero;
    cursor.hidden = YES;
    cursor.userInteractionEnabled = NO;
    [imageView addSubview:cursor];
    self.cursorView = cursor;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleImageTap:)];
    [imageView addGestureRecognizer:tap];

    UIScrollView *listView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    listView.backgroundColor = [_surfaceColor colorWithAlphaComponent:0.86];
    listView.layer.cornerRadius = 12.0;
    listView.layer.borderWidth = 1.0;
    listView.layer.borderColor = [_separatorColor colorWithAlphaComponent:0.72].CGColor;
    listView.clipsToBounds = YES;
    listView.showsVerticalScrollIndicator = YES;
    listView.hidden = YES;
    [self addSubview:listView];
    self.listView = listView;

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

    UIView *swatchView = [[UIView alloc] initWithFrame:CGRectZero];
    swatchView.layer.cornerRadius = 6.0;
    swatchView.layer.borderWidth = 1.0;
    swatchView.layer.borderColor = [_separatorColor colorWithAlphaComponent:0.92].CGColor;
    swatchView.backgroundColor = _swatchColor;
    [toolbar addSubview:swatchView];
    self.swatchView = swatchView;

    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    infoLabel.textColor = _primaryTextColor;
    infoLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    infoLabel.adjustsFontSizeToFitWidth = YES;
    infoLabel.minimumScaleFactor = 0.6;
    infoLabel.text = _infoText;
    [toolbar addSubview:infoLabel];
    self.infoLabel = infoLabel;

    self.deleteButton = [self buttonWithTitle:@"删点" action:@selector(deleteTapped)];
    self.deleteButton.enabled = NO;
    self.deleteButton.alpha = 0.45;
    [toolbar addSubview:self.deleteButton];

    self.confirmButton = [self buttonWithTitle:@"确定" action:@selector(confirmTapped)];
    [toolbar addSubview:self.confirmButton];

    self.cancelButton = [self buttonWithTitle:@"取消" action:@selector(cancelTapped)];
    [toolbar addSubview:self.cancelButton];

    CGFloat minZoom = [self minimumZoomScaleForImageSize:image.size inBoundsSize:self.bounds.size];
    scrollView.minimumZoomScale = minZoom;
    scrollView.zoomScale = minZoom;
    [self centerImageContent];
    [self relayoutChrome];
    return self;
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    BOOL primary = [title isEqualToString:@"确定"];
    BOOL destructive = [title isEqualToString:@"删点"];
    UIColor *accentColor = destructive ? self.dangerColor : self.highlightColor;
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    button.backgroundColor = primary || destructive ? accentColor : self.controlFillColor;
    [button setTitleColor:(primary || destructive ? UIColor.whiteColor : self.primaryTextColor) forState:UIControlStateNormal];
    button.layer.cornerRadius = 8.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = (primary || destructive
        ? [accentColor colorWithAlphaComponent:0.86]
        : [self.separatorColor colorWithAlphaComponent:0.82]).CGColor;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOffset = CGSizeMake(0, primary || destructive ? 2 : 1);
    button.layer.shadowRadius = primary || destructive ? 4.0 : 2.0;
    button.layer.shadowOpacity = primary || destructive ? 0.12 : 0.04;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)setInfoText:(NSString *)infoText {
    _infoText = [infoText copy] ?: @"";
    self.infoLabel.text = _infoText;
}

- (void)setSwatchColor:(UIColor *)swatchColor {
    _swatchColor = swatchColor ?: [UIColor colorWithWhite:1 alpha:0.10];
    self.swatchView.backgroundColor = _swatchColor;
}

- (void)setDeleteEnabled:(BOOL)deleteEnabled {
    _deleteEnabled = deleteEnabled;
    self.deleteButton.enabled = deleteEnabled;
    self.deleteButton.alpha = deleteEnabled ? 1.0 : 0.45;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.scrollView.frame = self.bounds;
    [self updateZoomForCurrentBounds];
    [self relayoutChrome];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return scrollView == self.scrollView ? self.imageView : nil;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if (scrollView != self.scrollView) {
        return;
    }
    [self centerImageContent];
    [self rebuildMarkers];
    if (!self.cursorView.hidden) {
        [self showCursorAtImagePoint:self.cursorView.center];
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

- (void)relayoutChrome {
    UIEdgeInsets safeInsets = self.safeAreaInsets;
    CGFloat margin = 8.0;
    CGFloat toolbarHeight = 52.0;
    CGFloat availableWidth = MAX(1.0, self.bounds.size.width - safeInsets.left - safeInsets.right - margin * 2.0);
    CGFloat toolbarWidth = MIN(availableWidth, 390.0);
    CGFloat toolbarX = safeInsets.left + (availableWidth - toolbarWidth) * 0.5 + margin;
    CGFloat toolbarY = self.bounds.size.height - safeInsets.bottom - toolbarHeight - margin;
    toolbarY = MAX(safeInsets.top + margin, toolbarY);
    self.toolbar.frame = CGRectMake(toolbarX, toolbarY, toolbarWidth, toolbarHeight);

    CGFloat listMaxHeight = MIN(168.0, MAX(0.0, toolbarY - safeInsets.top - margin * 2.0));
    CGFloat rowHeight = 34.0;
    CGFloat rowGap = 5.0;
    CGFloat wantedListHeight = self.samples.count == 0
        ? 0.0
        : MIN(listMaxHeight, (rowHeight + rowGap) * self.samples.count - rowGap + 12.0);
    self.listView.frame = CGRectMake(toolbarX, toolbarY - wantedListHeight - 6.0, toolbarWidth, wantedListHeight);

    CGFloat swatchSize = MIN(34.0, MAX(24.0, toolbarWidth * 0.18));
    self.swatchView.frame = CGRectMake(10.0, (toolbarHeight - swatchSize) * 0.5, swatchSize, swatchSize);
    CGFloat buttonWidth = MIN(56.0, MAX(0.0, floor((toolbarWidth - margin * 4.0) / 3.0)));
    CGFloat buttonHeight = 34.0;
    CGFloat buttonY = (toolbarHeight - buttonHeight) * 0.5;
    self.cancelButton.frame = CGRectMake(toolbarWidth - margin - buttonWidth, buttonY, buttonWidth, buttonHeight);
    self.confirmButton.frame = CGRectMake(CGRectGetMinX(self.cancelButton.frame) - margin - buttonWidth,
                                          buttonY,
                                          buttonWidth,
                                          buttonHeight);
    self.deleteButton.frame = CGRectMake(CGRectGetMinX(self.confirmButton.frame) - margin - buttonWidth,
                                         buttonY,
                                         buttonWidth,
                                         buttonHeight);
    self.cancelButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.cancelButton.bounds cornerRadius:self.cancelButton.layer.cornerRadius].CGPath;
    self.confirmButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.confirmButton.bounds cornerRadius:self.confirmButton.layer.cornerRadius].CGPath;
    self.deleteButton.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.deleteButton.bounds cornerRadius:self.deleteButton.layer.cornerRadius].CGPath;

    CGFloat infoX = CGRectGetMaxX(self.swatchView.frame) + 8.0;
    CGFloat infoWidth = MAX(0.0, CGRectGetMinX(self.deleteButton.frame) - infoX - 8.0);
    self.infoLabel.frame = CGRectMake(infoX, 0.0, infoWidth, toolbarHeight);
    [self rebuildList];
}

- (BOOL)sampleHasCoordinate:(NSDictionary *)sample {
    return [sample[@"x"] respondsToSelector:@selector(doubleValue)] &&
        [sample[@"y"] respondsToSelector:@selector(doubleValue)];
}

- (NSString *)roleForIndex:(NSUInteger)index {
    return index == 0 ? @"点击点" : [NSString stringWithFormat:@"校验%lu", (unsigned long)index];
}

- (NSString *)hexForSample:(NSDictionary *)sample {
    NSInteger red = MIN(255, MAX(0, [sample[@"red"] integerValue]));
    NSInteger green = MIN(255, MAX(0, [sample[@"green"] integerValue]));
    NSInteger blue = MIN(255, MAX(0, [sample[@"blue"] integerValue]));
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX", (long)red, (long)green, (long)blue];
}

- (UIColor *)colorForSample:(NSDictionary *)sample {
    NSInteger red = MIN(255, MAX(0, [sample[@"red"] integerValue]));
    NSInteger green = MIN(255, MAX(0, [sample[@"green"] integerValue]));
    NSInteger blue = MIN(255, MAX(0, [sample[@"blue"] integerValue]));
    return [UIColor colorWithRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:1.0];
}

- (void)updateSamples:(NSArray<NSDictionary *> *)samples selectedIndex:(NSInteger)selectedIndex {
    self.samples = [samples copy] ?: @[];
    self.selectedIndex = selectedIndex;
    [self rebuildMarkers];
    [self rebuildList];
    self.deleteEnabled = self.samples.count > 0;
}

- (void)rebuildMarkers {
    for (NSUInteger index = 0; index < ACColorPickerMaxSamples; index++) {
        [[self.imageView viewWithTag:ACColorPickerMarkerTagBase + (NSInteger)index] removeFromSuperview];
    }
    CGFloat zoomScale = MAX(0.01, self.scrollView.zoomScale);
    for (NSUInteger index = 0; index < self.samples.count && index < ACColorPickerMaxSamples; index++) {
        NSDictionary *sample = self.samples[index];
        if (![self sampleHasCoordinate:sample]) {
            continue;
        }
        BOOL selected = self.selectedIndex == (NSInteger)index;
        CGFloat markerSize = (selected ? 20.0 : (index == 0 ? 18.0 : 15.0)) / zoomScale;
        UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, markerSize, markerSize)];
        marker.tag = ACColorPickerMarkerTagBase + (NSInteger)index;
        marker.userInteractionEnabled = NO;
        marker.backgroundColor = UIColor.clearColor;
        marker.layer.cornerRadius = markerSize * 0.5;
        marker.layer.borderWidth = MAX(0.8, (selected ? 2.0 : 1.2) / zoomScale);
        marker.layer.borderColor = (selected ? UIColor.systemRedColor : (index == 0 ? self.highlightColor : UIColor.systemGreenColor)).CGColor;
        marker.layer.shadowColor = UIColor.blackColor.CGColor;
        marker.layer.shadowOpacity = 0.28;
        marker.layer.shadowRadius = 1.0 / zoomScale;
        marker.layer.shadowOffset = CGSizeZero;
        marker.center = CGPointMake([sample[@"x"] doubleValue], [sample[@"y"] doubleValue]);

        UILabel *numberLabel = [[UILabel alloc] initWithFrame:marker.bounds];
        numberLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)index + 1];
        numberLabel.textColor = UIColor.blackColor;
        numberLabel.textAlignment = NSTextAlignmentCenter;
        numberLabel.font = [UIFont monospacedDigitSystemFontOfSize:MAX(5.0, 9.0 / zoomScale) weight:UIFontWeightHeavy];
        numberLabel.backgroundColor = selected ? UIColor.systemRedColor : (index == 0 ? self.highlightColor : UIColor.systemGreenColor);
        numberLabel.layer.cornerRadius = markerSize * 0.5;
        numberLabel.clipsToBounds = YES;
        numberLabel.userInteractionEnabled = NO;
        [marker addSubview:numberLabel];
        [self.imageView addSubview:marker];
    }
}

- (void)rebuildList {
    for (UIView *view in self.listView.subviews) {
        [view removeFromSuperview];
    }
    CGFloat rowHeight = 34.0;
    CGFloat gap = 5.0;
    CGFloat width = MAX(1.0, self.listView.bounds.size.width);
    for (NSUInteger index = 0; index < self.samples.count; index++) {
        NSDictionary *sample = self.samples[index];
        BOOL selected = self.selectedIndex == (NSInteger)index;
        UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem];
        row.tag = ACColorPickerRowTagBase + (NSInteger)index;
        row.frame = CGRectMake(0.0, (rowHeight + gap) * index, width, rowHeight);
        row.backgroundColor = selected ? [self.highlightColor colorWithAlphaComponent:0.12] : [self.surfaceColor colorWithAlphaComponent:0.90];
        row.layer.cornerRadius = 8.0;
        row.layer.borderWidth = 1.0;
        row.layer.borderColor = (selected
            ? [self.highlightColor colorWithAlphaComponent:0.62]
            : [self.separatorColor colorWithAlphaComponent:0.82]).CGColor;
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.contentEdgeInsets = UIEdgeInsetsMake(0, 38, 0, 8);
        row.titleLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
        row.titleLabel.adjustsFontSizeToFitWidth = YES;
        row.titleLabel.minimumScaleFactor = 0.62;
        [row setTitleColor:self.primaryTextColor forState:UIControlStateNormal];
        [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];

        NSString *coord = [self sampleHasCoordinate:sample]
            ? [NSString stringWithFormat:@"X%.0f Y%.0f", [sample[@"x"] doubleValue], [sample[@"y"] doubleValue]]
            : @"旧颜色";
        [row setTitle:[NSString stringWithFormat:@"%lu %@ %@ %@",
                       (unsigned long)index + 1,
                       [self roleForIndex:index],
                       [self hexForSample:sample],
                       coord]
             forState:UIControlStateNormal];

        UIView *swatch = [[UIView alloc] initWithFrame:CGRectMake(10, 8, 18, 18)];
        swatch.userInteractionEnabled = NO;
        swatch.backgroundColor = [self colorForSample:sample];
        swatch.layer.cornerRadius = 4.0;
        swatch.layer.borderWidth = 1.0;
        swatch.layer.borderColor = [self.separatorColor colorWithAlphaComponent:0.90].CGColor;
        [row addSubview:swatch];
        [self.listView addSubview:row];
    }
    CGFloat contentHeight = self.samples.count == 0 ? 0.0 : (rowHeight + gap) * self.samples.count - gap;
    self.listView.contentSize = CGSizeMake(width, contentHeight);
    self.listView.hidden = self.samples.count == 0;
}

- (CGPoint)clampedImagePoint:(CGPoint)point {
    CGRect bounds = self.imageView ? self.imageView.bounds : CGRectMake(0, 0, self.image.size.width, self.image.size.height);
    point.x = MIN(MAX(point.x, 0.0), bounds.size.width);
    point.y = MIN(MAX(point.y, 0.0), bounds.size.height);
    return point;
}

- (void)showCursorAtImagePoint:(CGPoint)point {
    CGPoint clamped = [self clampedImagePoint:point];
    CGFloat zoomScale = MAX(0.01, self.scrollView.zoomScale);
    CGFloat cursorSize = 9.0 / zoomScale;
    self.cursorView.bounds = CGRectMake(0, 0, cursorSize, cursorSize);
    self.cursorView.center = clamped;
    self.cursorView.layer.cornerRadius = cursorSize * 0.5;
    self.cursorView.layer.borderWidth = 1.0 / zoomScale;
    self.cursorView.layer.shadowRadius = 1.0 / zoomScale;
    self.cursorView.hidden = NO;
}

- (void)hideCursor {
    self.cursorView.hidden = YES;
}

- (void)handleImageTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }
    CGPoint point = [self clampedImagePoint:[recognizer locationInView:self.imageView]];
    if ([self.delegate respondsToSelector:@selector(colorPickerView:didTapImagePoint:)]) {
        [self.delegate colorPickerView:self didTapImagePoint:point];
    }
}

- (void)rowTapped:(UIButton *)button {
    NSInteger index = button.tag - ACColorPickerRowTagBase;
    if (index < 0 || index >= (NSInteger)self.samples.count) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(colorPickerView:didSelectSampleAtIndex:)]) {
        [self.delegate colorPickerView:self didSelectSampleAtIndex:(NSUInteger)index];
    }
}

- (void)deleteTapped {
    if ([self.delegate respondsToSelector:@selector(colorPickerViewDidDeleteSample:)]) {
        [self.delegate colorPickerViewDidDeleteSample:self];
    }
}

- (void)confirmTapped {
    if ([self.delegate respondsToSelector:@selector(colorPickerViewDidConfirm:)]) {
        [self.delegate colorPickerViewDidConfirm:self];
    }
}

- (void)cancelTapped {
    if ([self.delegate respondsToSelector:@selector(colorPickerViewDidCancel:)]) {
        [self.delegate colorPickerViewDidCancel:self];
    }
}

@end
