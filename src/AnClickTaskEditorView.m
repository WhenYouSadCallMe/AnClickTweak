#import "AnClickTaskEditorView.h"
#import <math.h>

typedef NS_ENUM(NSInteger, ACEditorRowKind) {
    ACEditorRowKindActionGrid = 0,
    ACEditorRowKindCoordinate,
    ACEditorRowKindSwipeStart,
    ACEditorRowKindSwipeEnd,
    ACEditorRowKindRecognitionClickTargetMode,
    ACEditorRowKindPointPick,
    ACEditorRowKindColorPick,
    ACEditorRowKindJitter,
    ACEditorRowKindRepeat,
    ACEditorRowKindDoubleTapInterval,
    ACEditorRowKindTemplate,
    ACEditorRowKindColor,
    ACEditorRowKindColorMatchMode,
    ACEditorRowKindThreshold,
    ACEditorRowKindOCRMode,
    ACEditorRowKindOCRMatchMode,
    ACEditorRowKindOCRText,
    ACEditorRowKindOCRSimilarity,
    ACEditorRowKindNetworkURL,
    ACEditorRowKindNetworkMethod,
    ACEditorRowKindNetworkHeaders,
    ACEditorRowKindNetworkBody,
    ACEditorRowKindNetworkRetryMode,
    ACEditorRowKindNetworkRetryLimit,
    ACEditorRowKindNetworkTimeout,
    ACEditorRowKindNetworkContains,
    ACEditorRowKindNetworkFalse,
    ACEditorRowKindJumpTarget,
    ACEditorRowKindMacroRecord,
    ACEditorRowKindMacroSummary,
    ACEditorRowKindMacroSpeed,
    ACEditorRowKindSwipeDuration,
    ACEditorRowKindSwipeStep,
    ACEditorRowKindDelay,
    ACEditorRowKindInterval,
    ACEditorRowKindLongPress,
    ACEditorRowKindRecognitionRetryMode,
    ACEditorRowKindRecognitionRetryInterval,
    ACEditorRowKindSuccessActionMode,
    ACEditorRowKindFailureActionMode,
    ACEditorRowKindSuccessActionConfig,
    ACEditorRowKindFailureActionConfig,
    ACEditorRowKindSuccessBranch,
    ACEditorRowKindFailureBranch,
    ACEditorRowKindSingleStep,
    ACEditorRowKindDelete,
};

@interface ACEditorInputCell : UITableViewCell
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UILabel *unitLabel;
@property (nonatomic, strong) UIView *swatchView;
@end

@implementation ACEditorInputCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _iconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _iconLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightSemibold];
        _iconLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = UIColor.labelColor;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _textField = [[UITextField alloc] initWithFrame:CGRectZero];
        _textField.font = [UIFont monospacedDigitSystemFontOfSize:14.0 weight:UIFontWeightMedium];
        _textField.textAlignment = NSTextAlignmentRight;
        _textField.borderStyle = UITextBorderStyleRoundedRect;
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _textField.translatesAutoresizingMaskIntoConstraints = NO;

        _unitLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _unitLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
        _unitLabel.textColor = UIColor.secondaryLabelColor;
        _unitLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _swatchView = [[UIView alloc] initWithFrame:CGRectZero];
        _swatchView.layer.cornerRadius = 7.0;
        _swatchView.layer.borderWidth = 1.0;
        _swatchView.layer.borderColor = UIColor.separatorColor.CGColor;
        _swatchView.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_iconLabel];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_textField];
        [self.contentView addSubview:_unitLabel];
        [self.contentView addSubview:_swatchView];

        [NSLayoutConstraint activateConstraints:@[
            [_iconLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_iconLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconLabel.widthAnchor constraintEqualToConstant:26.0],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconLabel.trailingAnchor constant:8.0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_textField.leadingAnchor constant:-8.0],

            [_unitLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0],
            [_unitLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_unitLabel.widthAnchor constraintGreaterThanOrEqualToConstant:20.0],

            [_swatchView.trailingAnchor constraintEqualToAnchor:_unitLabel.leadingAnchor constant:-8.0],
            [_swatchView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_swatchView.widthAnchor constraintEqualToConstant:28.0],
            [_swatchView.heightAnchor constraintEqualToConstant:28.0],

            [_textField.trailingAnchor constraintEqualToAnchor:_swatchView.leadingAnchor constant:-8.0],
            [_textField.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_textField.widthAnchor constraintGreaterThanOrEqualToConstant:94.0],
            [_textField.heightAnchor constraintEqualToConstant:34.0],

            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:54.0],
        ]];
    }
    return self;
}

@end

@interface ACEditorSliderCell : UITableViewCell
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *valueLabel;
@end

@implementation ACEditorSliderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _iconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _iconLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightSemibold];
        _iconLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = UIColor.labelColor;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _slider = [[UISlider alloc] initWithFrame:CGRectZero];
        _slider.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _valueLabel.textColor = UIColor.secondaryLabelColor;
        _valueLabel.textAlignment = NSTextAlignmentRight;
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_iconLabel];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_slider];
        [self.contentView addSubview:_valueLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_iconLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_iconLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16.0],
            [_iconLabel.widthAnchor constraintEqualToConstant:26.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconLabel.trailingAnchor constant:8.0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_iconLabel.centerYAnchor],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0],
            [_valueLabel.centerYAnchor constraintEqualToAnchor:_iconLabel.centerYAnchor],
            [_valueLabel.widthAnchor constraintEqualToConstant:48.0],
            [_slider.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_slider.trailingAnchor constraintEqualToAnchor:_valueLabel.trailingAnchor],
            [_slider.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8.0],
            [_slider.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12.0],
        ]];
    }
    return self;
}

@end

@interface ACEditorSegmentedCell : UITableViewCell
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@end

@implementation ACEditorSegmentedCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _iconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _iconLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightSemibold];
        _iconLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = UIColor.labelColor;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[]];
        _segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_iconLabel];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_segmentedControl];

        [NSLayoutConstraint activateConstraints:@[
            [_iconLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_iconLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconLabel.widthAnchor constraintEqualToConstant:26.0],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconLabel.trailingAnchor constant:8.0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_segmentedControl.leadingAnchor constant:-10.0],

            [_segmentedControl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0],
            [_segmentedControl.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_segmentedControl.widthAnchor constraintGreaterThanOrEqualToConstant:156.0],
            [_segmentedControl.heightAnchor constraintEqualToConstant:32.0],

            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:54.0],
        ]];
    }
    return self;
}

@end

@interface ACEditorActionChoiceCell : UITableViewCell
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, copy) void (^selectionHandler)(AnClickActionMode mode);
- (void)configureWithTitle:(NSString *)title
                      icon:(NSString *)icon
                     items:(NSArray<NSDictionary *> *)items
              selectedMode:(AnClickActionMode)selectedMode;
@end

@implementation ACEditorActionChoiceCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _iconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _iconLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightSemibold];
        _iconLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = UIColor.labelColor;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.translatesAutoresizingMaskIntoConstraints = NO;

        _stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
        _stackView.axis = UILayoutConstraintAxisHorizontal;
        _stackView.spacing = 8.0;
        _stackView.alignment = UIStackViewAlignmentCenter;
        _stackView.translatesAutoresizingMaskIntoConstraints = NO;

        [_scrollView addSubview:_stackView];
        [self.contentView addSubview:_iconLabel];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_scrollView];

        [NSLayoutConstraint activateConstraints:@[
            [_iconLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_iconLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
            [_iconLabel.widthAnchor constraintEqualToConstant:26.0],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconLabel.trailingAnchor constant:8.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_iconLabel.centerYAnchor],

            [_scrollView.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_scrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0],
            [_scrollView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:10.0],
            [_scrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12.0],
            [_scrollView.heightAnchor constraintEqualToConstant:34.0],

            [_stackView.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
            [_stackView.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
            [_stackView.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
            [_stackView.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
            [_stackView.heightAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.heightAnchor],

            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:84.0],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.selectionHandler = nil;
}

- (void)configureWithTitle:(NSString *)title
                      icon:(NSString *)icon
                     items:(NSArray<NSDictionary *> *)items
              selectedMode:(AnClickActionMode)selectedMode {
    self.iconLabel.text = icon ?: @"";
    self.titleLabel.text = title ?: @"";
    for (UIView *view in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    for (NSDictionary *item in items) {
        AnClickActionMode mode = (AnClickActionMode)[item[@"mode"] integerValue];
        NSString *itemTitle = [item[@"title"] isKindOfClass:NSString.class] ? item[@"title"] : @"动作";
        BOOL selected = mode == selectedMode;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = mode;
        [button setTitle:itemTitle forState:UIControlStateNormal];
        [button setTitleColor:selected ? UIColor.whiteColor : UIColor.labelColor forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 12.0, 0, 12.0);
        button.backgroundColor = selected ? UIColor.systemBlueColor : UIColor.secondarySystemGroupedBackgroundColor;
        button.layer.cornerRadius = 15.0;
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = (selected ? UIColor.systemBlueColor : UIColor.separatorColor).CGColor;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button addTarget:self action:@selector(handleChoiceButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.stackView addArrangedSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.heightAnchor constraintEqualToConstant:30.0],
            [button.widthAnchor constraintGreaterThanOrEqualToConstant:58.0],
        ]];
    }
}

- (void)handleChoiceButton:(UIButton *)button {
    if (self.selectionHandler) {
        self.selectionHandler((AnClickActionMode)button.tag);
    }
}

@end

@interface ACEditorButtonCell : UITableViewCell
@property (nonatomic, strong) UIButton *button;
@end

@implementation ACEditorButtonCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _button = [UIButton buttonWithType:UIButtonTypeSystem];
        _button.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        _button.layer.cornerRadius = 12.0;
        _button.layer.borderWidth = 1.0;
        _button.layer.borderColor = UIColor.separatorColor.CGColor;
        _button.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        _button.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_button];
        [NSLayoutConstraint activateConstraints:@[
            [_button.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14.0],
            [_button.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0],
            [_button.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10.0],
            [_button.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10.0],
            [_button.heightAnchor constraintEqualToConstant:42.0],
        ]];
    }
    return self;
}

@end

@interface ACEditorActionGridCell : UITableViewCell
@property (nonatomic, copy) void (^selectionHandler)(AnClickActionMode mode);
- (void)configureWithSelectedMode:(AnClickActionMode)mode;
@end

@implementation ACEditorActionGridCell {
    NSArray<UIButton *> *_buttons;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        NSArray<NSDictionary *> *items = @[
            @{@"title": @"👆 点击", @"mode": @(AnClickActionModeTap)},
            @{@"title": @"👆 双击", @"mode": @(AnClickActionModeDoubleTap)},
            @{@"title": @"⏳ 长按", @"mode": @(AnClickActionModeLongPress)},
            @{@"title": @"↗ 滑动", @"mode": @(AnClickActionModeSwipe)},
            @{@"title": @"✌ 多指", @"mode": @(AnClickActionModeTwoFingerTap)},
            @{@"title": @"🖼 识图", @"mode": @(AnClickActionModeImage)},
            @{@"title": @"● 录制", @"mode": @(AnClickActionModeMacro)},
            @{@"title": @"📝 识字", @"mode": @(AnClickActionModeOCR)},
            @{@"title": @"🎨 识色", @"mode": @(AnClickActionModeColor)},
            @{@"title": @"🌐 网络", @"mode": @(AnClickActionModeNetwork)},
            @{@"title": @"🔀 跳转", @"mode": @(AnClickActionModeJump)},
            @{@"title": @"⏱ 延时", @"mode": @(AnClickActionModeDelay)},
        ];
        NSMutableArray *buttons = [NSMutableArray array];
        UIStackView *outer = [[UIStackView alloc] initWithFrame:CGRectZero];
        outer.axis = UILayoutConstraintAxisVertical;
        outer.spacing = 10.0;
        outer.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:outer];
        [NSLayoutConstraint activateConstraints:@[
            [outer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14.0],
            [outer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0],
            [outer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
            [outer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],
        ]];
        NSUInteger columns = 3;
        NSUInteger rows = (items.count + columns - 1) / columns;
        for (NSUInteger row = 0; row < rows; row++) {
            UIStackView *line = [[UIStackView alloc] initWithFrame:CGRectZero];
            line.axis = UILayoutConstraintAxisHorizontal;
            line.spacing = 8.0;
            line.distribution = UIStackViewDistributionFillEqually;
            [outer addArrangedSubview:line];
            NSUInteger start = row * columns;
            NSUInteger end = MIN(items.count, start + columns);
            for (NSUInteger i = start; i < end; i++) {
                UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
                [button setTitle:items[i][@"title"] forState:UIControlStateNormal];
                button.tag = [items[i][@"mode"] integerValue];
                button.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
                button.layer.cornerRadius = 10.0;
                button.layer.borderWidth = 1.0;
                [button addTarget:self action:@selector(handleModeButton:) forControlEvents:UIControlEventTouchUpInside];
                [button.heightAnchor constraintEqualToConstant:38.0].active = YES;
                [line addArrangedSubview:button];
                [buttons addObject:button];
            }
            if (end - start < columns) {
                for (NSUInteger i = end - start; i < columns; i++) {
                    UIView *spacer = [[UIView alloc] initWithFrame:CGRectZero];
                    [line addArrangedSubview:spacer];
                }
            }
        }
        _buttons = [buttons copy];
    }
    return self;
}

- (void)handleModeButton:(UIButton *)sender {
    if (self.selectionHandler) {
        self.selectionHandler((AnClickActionMode)sender.tag);
    }
}

- (void)configureWithSelectedMode:(AnClickActionMode)mode {
    for (UIButton *button in _buttons) {
        BOOL selected = button.tag == mode;
        button.backgroundColor = selected ? UIColor.systemBlueColor : UIColor.secondarySystemGroupedBackgroundColor;
        button.layer.borderColor = (selected ? UIColor.systemBlueColor : UIColor.separatorColor).CGColor;
        [button setTitleColor:(selected ? UIColor.whiteColor : UIColor.labelColor) forState:UIControlStateNormal];
    }
}

@end

@interface AnClickTaskEditorView () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UITableView *tableView;
@property (nonatomic, strong, readwrite) AnClickTaskModel *model;
@property (nonatomic, assign) NSInteger taskIndex;
@property (nonatomic, copy) NSString *branchTitle;
@property (nonatomic, copy) NSString *actionName;
@property (nonatomic, weak) UITextField *activeTextField;
@property (nonatomic, assign) UIEdgeInsets baseContentInset;
@property (nonatomic, assign) UIEdgeInsets baseScrollIndicatorInsets;
@end

@implementation AnClickTaskEditorView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _model = [[AnClickTaskModel alloc] init];
        _taskIndex = -1;
        _branchTitle = @"";
        _actionName = @"动作";
        [self buildView];
        [self registerKeyboardObservers];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)buildView {
    UIColor *background = UIColor.systemGroupedBackgroundColor;
    self.backgroundColor = background;
    self.layer.cornerRadius = 16.0;
    self.layer.masksToBounds = YES;

    _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    _cancelButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [_cancelButton addTarget:self action:@selector(handleCancel) forControlEvents:UIControlEventTouchUpInside];
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;

    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_saveButton setTitle:@"保存" forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
    [_saveButton addTarget:self action:@selector(handleSave) forControlEvents:UIControlEventTouchUpInside];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_closeButton setTitle:@"×" forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont systemFontOfSize:28.0 weight:UIFontWeightSemibold];
    [_closeButton addTarget:self action:@selector(handleClose) forControlEvents:UIControlEventTouchUpInside];
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.7;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.estimatedRowHeight = 60.0;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _tableView.backgroundColor = background;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [_tableView registerClass:ACEditorActionGridCell.class forCellReuseIdentifier:@"ActionGrid"];
    [_tableView registerClass:ACEditorInputCell.class forCellReuseIdentifier:@"Input"];
    [_tableView registerClass:ACEditorSliderCell.class forCellReuseIdentifier:@"Slider"];
    [_tableView registerClass:ACEditorSegmentedCell.class forCellReuseIdentifier:@"Segmented"];
    [_tableView registerClass:ACEditorActionChoiceCell.class forCellReuseIdentifier:@"ActionChoice"];
    [_tableView registerClass:ACEditorButtonCell.class forCellReuseIdentifier:@"Button"];

    [self addSubview:_cancelButton];
    [self addSubview:_saveButton];
    [self addSubview:_closeButton];
    [self addSubview:_titleLabel];
    [self addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_cancelButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14.0],
        [_cancelButton.topAnchor constraintEqualToAnchor:self.topAnchor constant:8.0],
        [_cancelButton.widthAnchor constraintEqualToConstant:56.0],
        [_cancelButton.heightAnchor constraintEqualToConstant:42.0],

        [_closeButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10.0],
        [_closeButton.topAnchor constraintEqualToAnchor:_cancelButton.topAnchor],
        [_closeButton.widthAnchor constraintEqualToConstant:38.0],
        [_closeButton.heightAnchor constraintEqualToAnchor:_cancelButton.heightAnchor],

        [_saveButton.trailingAnchor constraintEqualToAnchor:_closeButton.leadingAnchor constant:-4.0],
        [_saveButton.topAnchor constraintEqualToAnchor:_cancelButton.topAnchor],
        [_saveButton.widthAnchor constraintEqualToConstant:56.0],
        [_saveButton.heightAnchor constraintEqualToAnchor:_cancelButton.heightAnchor],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_cancelButton.trailingAnchor constant:8.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_saveButton.leadingAnchor constant:-8.0],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_cancelButton.centerYAnchor],

        [_tableView.topAnchor constraintEqualToAnchor:_cancelButton.bottomAnchor constant:1.0],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
    _baseContentInset = _tableView.contentInset;
    if (@available(iOS 13.0, *)) {
        _baseScrollIndicatorInsets = _tableView.verticalScrollIndicatorInsets;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _baseScrollIndicatorInsets = _tableView.scrollIndicatorInsets;
#pragma clang diagnostic pop
    }
}

- (void)registerKeyboardObservers {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(handleKeyboardWillChangeFrame:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleKeyboardWillHide:)
                   name:UIKeyboardWillHideNotification
                 object:nil];
}

- (void)configureWithModel:(AnClickTaskModel *)model
                 taskIndex:(NSInteger)taskIndex
               branchTitle:(NSString *)branchTitle
                actionName:(NSString *)actionName {
    self.model = [model copy] ?: [[AnClickTaskModel alloc] init];
    [self normalizeModelForCurrentActionMode];
    self.taskIndex = taskIndex;
    self.branchTitle = branchTitle ?: @"";
    self.actionName = actionName.length > 0 ? actionName : @"动作";
    if (self.branchTitle.length > 0) {
        self.titleLabel.text = [NSString stringWithFormat:@"%@配置", self.branchTitle];
    } else if (taskIndex >= 0) {
        self.titleLabel.text = [NSString stringWithFormat:@"编辑任务 #%02ld", (long)taskIndex + 1];
    } else {
        self.titleLabel.text = @"新增任务";
    }
    [self reloadForm];
}

- (void)reloadForm {
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.model.actionMode == AnClickActionModeNone && (section == 1 || section == 2)) {
        return 0;
    }
    return [self rowsForSection:section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self rowsForSection:section].count == 0) {
        return @"";
    }
    switch (section) {
        case 0: return @"动作类型";
        case 1: return [self parameterSectionTitleForCurrentMode];
        case 2: return [self timingSectionTitleForCurrentMode];
        case 3: return @"逻辑分支";
        case 4: return @"";
        default: return @"";
    }
}

- (NSString *)parameterSectionTitleForCurrentMode {
    switch (self.model.actionMode) {
        case AnClickActionModeTap:
        case AnClickActionModeDoubleTap:
        case AnClickActionModeLongPress:
        case AnClickActionModeTwoFingerTap:
            return @"触点参数";
        case AnClickActionModeSwipe:
            return @"滑动轨迹";
        case AnClickActionModeImage:
            return @"识图参数";
        case AnClickActionModeOCR:
            return @"识字参数";
        case AnClickActionModeColor:
            return @"识色参数";
        case AnClickActionModeNetwork:
            return @"网络请求";
        case AnClickActionModeJump:
            return @"跳转目标";
        case AnClickActionModeMacro:
            return @"录制参数";
        case AnClickActionModeDelay:
            return @"延时参数";
        default:
            return @"目标参数";
    }
}

- (NSString *)timingSectionTitleForCurrentMode {
    switch (self.model.actionMode) {
        case AnClickActionModeTap:
        case AnClickActionModeTwoFingerTap:
            return @"重复设置";
        case AnClickActionModeDoubleTap:
            return @"双击设置";
        case AnClickActionModeLongPress:
            return @"长按设置";
        case AnClickActionModeSwipe:
            return @"滑动设置";
        case AnClickActionModeImage:
        case AnClickActionModeOCR:
        case AnClickActionModeColor:
            return @"识别重试";
        case AnClickActionModeNetwork:
            return @"重试与超时";
        case AnClickActionModeMacro:
            return @"回放设置";
        case AnClickActionModeDelay:
            return @"延时设置";
        default:
            return @"动作设置";
    }
}

- (NSArray<NSNumber *> *)rowsForSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @[@(ACEditorRowKindActionGrid)];
        case 1:
            return [self parameterRows];
        case 2:
            return [self timingRows];
        case 3:
            return [self logicRows];
        case 4:
            return self.taskIndex >= 0 ? @[@(ACEditorRowKindDelete)] : @[];
        default:
            return @[];
    }
}

- (NSArray<NSNumber *> *)parameterRows {
    NSArray<NSNumber *> *candidates = @[
        @(ACEditorRowKindRecognitionClickTargetMode),
        @(ACEditorRowKindCoordinate),
        @(ACEditorRowKindSwipeStart),
        @(ACEditorRowKindSwipeEnd),
        @(ACEditorRowKindPointPick),
        @(ACEditorRowKindColorPick),
        @(ACEditorRowKindTemplate),
        @(ACEditorRowKindColor),
        @(ACEditorRowKindColorMatchMode),
        @(ACEditorRowKindThreshold),
        @(ACEditorRowKindOCRMode),
        @(ACEditorRowKindOCRMatchMode),
        @(ACEditorRowKindOCRText),
        @(ACEditorRowKindOCRSimilarity),
        @(ACEditorRowKindNetworkURL),
        @(ACEditorRowKindNetworkMethod),
        @(ACEditorRowKindNetworkHeaders),
        @(ACEditorRowKindNetworkBody),
        @(ACEditorRowKindNetworkContains),
        @(ACEditorRowKindNetworkFalse),
        @(ACEditorRowKindJumpTarget),
        @(ACEditorRowKindMacroRecord),
        @(ACEditorRowKindMacroSummary),
    ];
    NSMutableArray<NSNumber *> *rows = [NSMutableArray array];
    for (NSNumber *row in candidates) {
        if ([self shouldShowRowForKind:(ACEditorRowKind)row.integerValue]) {
            [rows addObject:row];
        }
    }
    return rows;
}

- (NSArray<NSNumber *> *)timingRows {
    NSArray<NSNumber *> *candidates = @[
        @(ACEditorRowKindDelay),
        @(ACEditorRowKindRepeat),
        @(ACEditorRowKindInterval),
        @(ACEditorRowKindDoubleTapInterval),
        @(ACEditorRowKindLongPress),
        @(ACEditorRowKindSwipeDuration),
        @(ACEditorRowKindSwipeStep),
        @(ACEditorRowKindMacroSpeed),
        @(ACEditorRowKindJitter),
        @(ACEditorRowKindNetworkRetryMode),
        @(ACEditorRowKindNetworkRetryLimit),
        @(ACEditorRowKindNetworkTimeout),
        @(ACEditorRowKindRecognitionRetryMode),
        @(ACEditorRowKindRecognitionRetryInterval),
    ];
    NSMutableArray<NSNumber *> *rows = [NSMutableArray array];
    for (NSNumber *row in candidates) {
        if ([self shouldShowRowForKind:(ACEditorRowKind)row.integerValue]) {
            [rows addObject:row];
        }
    }
    return rows;
}

- (BOOL)isEditingBranchActionConfig {
    return self.branchTitle.length > 0;
}

- (BOOL)branchActionModeCanUseRecognitionPoint:(AnClickActionMode)mode {
    return mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeTwoFingerTap;
}

- (NSArray<NSNumber *> *)branchActionModesForSuccess:(BOOL)success {
    NSMutableArray<NSNumber *> *modes = [NSMutableArray array];
    if (!success) {
        [modes addObject:@(AnClickActionModeNone)];
    }
    if ([self isEditingBranchActionConfig]) {
        [modes addObjectsFromArray:@[
            @(AnClickActionModeTap),
            @(AnClickActionModeDoubleTap),
            @(AnClickActionModeLongPress),
            @(AnClickActionModeSwipe),
            @(AnClickActionModeNetwork),
            @(AnClickActionModeDelay),
            @(AnClickActionModeTwoFingerTap),
            @(AnClickActionModeJump),
        ]];
        return modes;
    }
    [modes addObjectsFromArray:@[
        @(AnClickActionModeTap),
        @(AnClickActionModeDoubleTap),
        @(AnClickActionModeLongPress),
        @(AnClickActionModeSwipe),
        @(AnClickActionModeTwoFingerTap),
        @(AnClickActionModeMacro),
        @(AnClickActionModeNetwork),
        @(AnClickActionModeDelay),
    ]];
    if (![self isEditingBranchActionConfig]) {
        [modes addObjectsFromArray:@[
            @(AnClickActionModeImage),
            @(AnClickActionModeOCR),
            @(AnClickActionModeColor),
        ]];
    }
    [modes addObject:@(AnClickActionModeJump)];
    return modes;
}

- (BOOL)branchActionMode:(AnClickActionMode)mode isAllowedForSuccess:(BOOL)success {
    for (NSNumber *modeNumber in [self branchActionModesForSuccess:success]) {
        if (modeNumber.integerValue == mode) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)branchActionModeNeedsFullConfig:(AnClickActionMode)mode success:(BOOL)success {
    if (![self branchActionMode:mode isAllowedForSuccess:success] ||
        mode == AnClickActionModeNone ||
        mode == AnClickActionModeJump) {
        return NO;
    }
    return ![self branchActionModeCanUseRecognitionPoint:mode];
}

- (NSString *)branchActionShortTitleForMode:(AnClickActionMode)mode {
    switch (mode) {
        case AnClickActionModeNone: return @"无";
        case AnClickActionModeTap: return @"点击";
        case AnClickActionModeDoubleTap: return @"双击";
        case AnClickActionModeLongPress: return @"长按";
        case AnClickActionModeSwipe: return @"滑动";
        case AnClickActionModeTwoFingerTap: return @"多指";
        case AnClickActionModeImage: return @"识图";
        case AnClickActionModeMacro: return @"录制";
        case AnClickActionModeOCR: return @"识字";
        case AnClickActionModeColor: return @"识色";
        case AnClickActionModeNetwork: return @"网络";
        case AnClickActionModeJump: return @"跳转";
        case AnClickActionModeDelay: return @"延时";
        default: return @"动作";
    }
}

- (NSArray<NSDictionary *> *)branchActionItemsForSuccess:(BOOL)success {
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    for (NSNumber *modeNumber in [self branchActionModesForSuccess:success]) {
        AnClickActionMode mode = (AnClickActionMode)modeNumber.integerValue;
        [items addObject:@{
            @"title": [self branchActionShortTitleForMode:mode],
            @"mode": @(mode),
        }];
    }
    return items;
}

- (BOOL)branchActionConfigExistsForSuccess:(BOOL)success {
    NSDictionary *config = success ? self.model.successActionConfig : self.model.failureActionConfig;
    if (config.count > 0) {
        return YES;
    }
    config = success ? self.model.successRecognitionActionConfig : self.model.failureRecognitionActionConfig;
    return config.count > 0;
}

- (NSDictionary *)draftBranchConfigForMode:(AnClickActionMode)mode {
    if (mode == AnClickActionModeNone || mode == AnClickActionModeJump) {
        return @{};
    }
    NSMutableDictionary *config = [@{
        @"mode": @(mode),
        @"repeat": @1,
        @"interval": @0.03,
        @"imageActionMode": @(AnClickActionModeTap),
        @"failureActionMode": @(AnClickActionModeNone),
        @"useMatchPoint": @YES,
    } mutableCopy];
    if (mode == AnClickActionModeDelay) {
        config[@"delay"] = @0.50;
    } else if (mode == AnClickActionModeNetwork) {
        config[@"networkMethod"] = @"GET";
        config[@"networkTimeout"] = @8.0;
        config[@"networkRetryForever"] = @YES;
        config[@"networkRetryLimit"] = @3;
    } else if (mode == AnClickActionModeSwipe) {
        config[@"swipeDuration"] = @0.30;
        config[@"swipeStep"] = @1.0;
    } else if (mode == AnClickActionModeImage) {
        config[@"threshold"] = @0.80;
    } else if (mode == AnClickActionModeColor) {
        config[@"colorTolerance"] = @18.0;
    } else if (mode == AnClickActionModeOCR) {
        config[@"ocrMatchMode"] = @(AnClickOCRMatchModeContains);
        config[@"ocrSimilarity"] = @0.80;
    }
    return config;
}

- (void)setBranchActionMode:(AnClickActionMode)mode success:(BOOL)success {
    if (![self branchActionMode:mode isAllowedForSuccess:success]) {
        mode = success ? AnClickActionModeTap : AnClickActionModeNone;
    }
    AnClickActionMode previous = success ? self.model.successActionMode : self.model.failureActionMode;
    if (success) {
        self.model.successActionMode = mode;
        if (mode != AnClickActionModeJump) {
            self.model.successBranchIndex = -1;
        }
        if (previous != mode) {
            NSDictionary *config = [self draftBranchConfigForMode:mode];
            self.model.successActionConfig = config;
            self.model.successRecognitionActionConfig = (mode == AnClickActionModeImage ||
                mode == AnClickActionModeOCR ||
                mode == AnClickActionModeColor) ? config : @{};
        }
    } else {
        self.model.failureActionMode = mode;
        if (mode != AnClickActionModeJump) {
            self.model.failureBranchIndex = -1;
        }
        if (previous != mode) {
            NSDictionary *config = [self draftBranchConfigForMode:mode];
            self.model.failureActionConfig = config;
            self.model.failureRecognitionActionConfig = (mode == AnClickActionModeImage ||
                mode == AnClickActionModeOCR ||
                mode == AnClickActionModeColor) ? config : @{};
        }
    }
    [self notifyModelChanged];
    [self reloadForm];
}

- (BOOL)shouldShowRowForKind:(ACEditorRowKind)kind {
    AnClickActionMode mode = self.model.actionMode;
    if (mode == AnClickActionModeNone) {
        return kind == ACEditorRowKindActionGrid;
    }

    BOOL basicPointMode = mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeTwoFingerTap;
    BOOL recognitionMode = mode == AnClickActionModeImage ||
        mode == AnClickActionModeOCR ||
        mode == AnClickActionModeColor;
    BOOL recognitionPointMode = recognitionMode && [self branchActionModeCanUseRecognitionPoint:self.model.successActionMode];
    BOOL customRecognitionPointMode = recognitionPointMode && !self.model.useMatchPoint;

    switch (kind) {
        case ACEditorRowKindActionGrid:
            return YES;
        case ACEditorRowKindCoordinate:
            return basicPointMode || customRecognitionPointMode;
        case ACEditorRowKindSwipeStart:
        case ACEditorRowKindSwipeEnd:
            return mode == AnClickActionModeSwipe;
        case ACEditorRowKindRecognitionClickTargetMode:
            return recognitionPointMode;
        case ACEditorRowKindPointPick:
            return basicPointMode || mode == AnClickActionModeSwipe || customRecognitionPointMode;
        case ACEditorRowKindColorPick:
            return mode == AnClickActionModeColor;
        case ACEditorRowKindJitter:
            return mode == AnClickActionModeTap ||
                mode == AnClickActionModeDoubleTap ||
                mode == AnClickActionModeLongPress ||
                mode == AnClickActionModeSwipe ||
                mode == AnClickActionModeTwoFingerTap ||
                mode == AnClickActionModeMacro;
        case ACEditorRowKindRepeat:
            return mode == AnClickActionModeTap || mode == AnClickActionModeTwoFingerTap;
        case ACEditorRowKindDoubleTapInterval:
            return mode == AnClickActionModeDoubleTap;
        case ACEditorRowKindLongPress:
            return mode == AnClickActionModeLongPress;
        case ACEditorRowKindSwipeDuration:
        case ACEditorRowKindSwipeStep:
            return mode == AnClickActionModeSwipe;
        case ACEditorRowKindTemplate:
            return mode == AnClickActionModeImage;
        case ACEditorRowKindThreshold:
            return mode == AnClickActionModeImage || mode == AnClickActionModeColor;
        case ACEditorRowKindColor:
        case ACEditorRowKindColorMatchMode:
            return mode == AnClickActionModeColor;
        case ACEditorRowKindOCRMode:
        case ACEditorRowKindOCRMatchMode:
        case ACEditorRowKindOCRText:
        case ACEditorRowKindOCRSimilarity:
            return mode == AnClickActionModeOCR;
        case ACEditorRowKindNetworkURL:
        case ACEditorRowKindNetworkMethod:
        case ACEditorRowKindNetworkHeaders:
        case ACEditorRowKindNetworkBody:
        case ACEditorRowKindNetworkRetryMode:
        case ACEditorRowKindNetworkRetryLimit:
        case ACEditorRowKindNetworkTimeout:
        case ACEditorRowKindNetworkContains:
        case ACEditorRowKindNetworkFalse:
            return mode == AnClickActionModeNetwork;
        case ACEditorRowKindJumpTarget:
            return mode == AnClickActionModeJump;
        case ACEditorRowKindMacroRecord:
        case ACEditorRowKindMacroSummary:
        case ACEditorRowKindMacroSpeed:
            return mode == AnClickActionModeMacro;
        case ACEditorRowKindDelay:
            return mode == AnClickActionModeDelay;
        case ACEditorRowKindInterval:
            return (mode == AnClickActionModeTap || mode == AnClickActionModeTwoFingerTap) &&
                self.model.repeatCount > 1;
        case ACEditorRowKindRecognitionRetryMode:
        case ACEditorRowKindRecognitionRetryInterval:
        case ACEditorRowKindSuccessActionMode:
        case ACEditorRowKindFailureActionMode:
            return recognitionMode;
        case ACEditorRowKindSuccessActionConfig:
            return recognitionMode && [self branchActionModeNeedsFullConfig:self.model.successActionMode success:YES];
        case ACEditorRowKindFailureActionConfig:
            return recognitionMode && [self branchActionModeNeedsFullConfig:self.model.failureActionMode success:NO];
        case ACEditorRowKindSuccessBranch:
            return recognitionMode && self.model.successActionMode == AnClickActionModeJump;
        case ACEditorRowKindFailureBranch:
            return recognitionMode && self.model.failureActionMode == AnClickActionModeJump;
        case ACEditorRowKindSingleStep:
        case ACEditorRowKindDelete:
            return mode != AnClickActionModeNone;
    }
    return NO;
}

- (NSArray<NSNumber *> *)logicRows {
    if (self.model.actionMode == AnClickActionModeImage ||
        self.model.actionMode == AnClickActionModeOCR ||
        self.model.actionMode == AnClickActionModeColor) {
        NSMutableArray<NSNumber *> *rows = [NSMutableArray arrayWithObject:@(ACEditorRowKindSuccessActionMode)];
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessActionConfig]) {
            [rows addObject:@(ACEditorRowKindSuccessActionConfig)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessBranch]) {
            [rows addObject:@(ACEditorRowKindSuccessBranch)];
        }
        [rows addObject:@(ACEditorRowKindFailureActionMode)];
        if ([self shouldShowRowForKind:ACEditorRowKindFailureActionConfig]) {
            [rows addObject:@(ACEditorRowKindFailureActionConfig)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureBranch]) {
            [rows addObject:@(ACEditorRowKindFailureBranch)];
        }
        [rows addObject:@(ACEditorRowKindSingleStep)];
        return rows;
    }
    return self.model.actionMode == AnClickActionModeNone ? @[] : @[@(ACEditorRowKindSingleStep)];
}

- (void)normalizeModelForCurrentActionMode {
    AnClickActionMode mode = self.model.actionMode;
    BOOL pointMode = mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeTwoFingerTap ||
        mode == AnClickActionModeImage ||
        mode == AnClickActionModeOCR ||
        mode == AnClickActionModeColor;

    if (mode != AnClickActionModeDelay) {
        self.model.delay = 0.0;
    }
    if (mode != AnClickActionModeTap && mode != AnClickActionModeTwoFingerTap) {
        self.model.interval = 0.0;
        self.model.repeatCount = 1;
    }
    if (!pointMode) {
        self.model.point = nil;
        self.model.pointScreenSize = nil;
    }
    if (mode != AnClickActionModeSwipe) {
        self.model.path = @[];
        self.model.pathScreenSize = nil;
    }
    if (mode != AnClickActionModeTwoFingerTap) {
        self.model.multiPoints = @[];
        self.model.multiPointScreenSize = nil;
    }
    if (mode != AnClickActionModeImage) {
        self.model.templatePath = @"";
    }
    self.model.hasTemplateROI = NO;
    self.model.templateROI = CGRectZero;
    self.model.hasMatchClickOffset = NO;
    self.model.matchClickOffset = CGPointZero;
    if (mode != AnClickActionModeOCR) {
        self.model.ocrText = @"";
        self.model.ocrMatchMode = AnClickOCRMatchModeContains;
        self.model.ocrMode = AnClickOCRModeAppleVision;
    }
    if (mode != AnClickActionModeColor) {
        self.model.colorPoints = @[];
        self.model.colorPointScreenSize = nil;
    }
    if (mode != AnClickActionModeNetwork) {
        self.model.networkURL = @"";
        self.model.networkHeaders = @{};
        self.model.networkPostBody = @"";
        self.model.networkPostPairs = @[];
        self.model.networkContains = @"";
        self.model.networkFalse = @"";
        self.model.networkRequestOnly = NO;
        self.model.networkUsesPost = NO;
        self.model.networkMethod = @"GET";
    }
    if (mode != AnClickActionModeJump) {
        self.model.jumpTaskIndex = -1;
    }
    if (mode != AnClickActionModeMacro) {
        self.model.events = @[];
        self.model.eventsScreenSize = nil;
        self.model.macroSpeed = 1.0;
    }
    if (mode != AnClickActionModeImage &&
        mode != AnClickActionModeOCR &&
        mode != AnClickActionModeColor) {
        self.model.successBranchIndex = -1;
        self.model.failureBranchIndex = -1;
        self.model.successActionMode = AnClickActionModeTap;
        self.model.failureActionMode = AnClickActionModeNone;
        self.model.recognitionRetryUntilFound = NO;
    } else {
        if (![self branchActionMode:self.model.successActionMode isAllowedForSuccess:YES]) {
            self.model.successActionMode = AnClickActionModeTap;
            self.model.successActionConfig = @{};
            self.model.successRecognitionActionConfig = @{};
        }
        if (self.model.successActionMode != AnClickActionModeJump) {
            self.model.successBranchIndex = -1;
        }
        if (![self branchActionMode:self.model.failureActionMode isAllowedForSuccess:NO]) {
            self.model.failureActionMode = AnClickActionModeNone;
            self.model.failureActionConfig = @{};
            self.model.failureRecognitionActionConfig = @{};
        }
        if (self.model.failureActionMode != AnClickActionModeJump) {
            self.model.failureBranchIndex = -1;
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ACEditorRowKind row = [self rowsForSection:indexPath.section][(NSUInteger)indexPath.row].integerValue;
    if (row == ACEditorRowKindActionGrid) {
        ACEditorActionGridCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ActionGrid" forIndexPath:indexPath];
        __weak typeof(self) weakSelf = self;
        cell.selectionHandler = ^(AnClickActionMode mode) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (strongSelf.model.actionMode == mode) return;
            BOOL recognitionMode = mode == AnClickActionModeImage ||
                mode == AnClickActionModeOCR ||
                mode == AnClickActionModeColor;
            strongSelf.model.actionMode = mode;
            if (recognitionMode) {
                strongSelf.model.useMatchPoint = YES;
            }
            [strongSelf normalizeModelForCurrentActionMode];
            [strongSelf notifyModelChanged];
            [strongSelf.delegate taskEditorView:strongSelf didSelectActionMode:mode];
            [strongSelf reloadForm];
        };
        [cell configureWithSelectedMode:self.model.actionMode];
        return cell;
    }
    if (row == ACEditorRowKindSuccessActionMode || row == ACEditorRowKindFailureActionMode) {
        ACEditorActionChoiceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ActionChoice" forIndexPath:indexPath];
        BOOL success = row == ACEditorRowKindSuccessActionMode;
        AnClickActionMode selectedMode = success ? self.model.successActionMode : self.model.failureActionMode;
        __weak typeof(self) weakSelf = self;
        cell.selectionHandler = ^(AnClickActionMode mode) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf setBranchActionMode:mode success:success];
        };
        [cell configureWithTitle:success ? @"成功后动作" : @"失败后动作"
                            icon:success ? @"✓" : @"✕"
                           items:[self branchActionItemsForSuccess:success]
                    selectedMode:selectedMode];
        cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
        return cell;
    }
    if (row == ACEditorRowKindThreshold || row == ACEditorRowKindOCRSimilarity) {
        ACEditorSliderCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Slider" forIndexPath:indexPath];
        cell.iconLabel.text = row == ACEditorRowKindOCRSimilarity ? @"🔎" : @"⚖";
        cell.titleLabel.text = row == ACEditorRowKindOCRSimilarity
            ? @"识字相似度"
            : (self.model.actionMode == AnClickActionModeColor ? @"相似度容差" : @"相似度阈值");
        cell.slider.tag = row;
        cell.slider.minimumValue = 0.0;
        cell.slider.maximumValue = (row == ACEditorRowKindThreshold && self.model.actionMode == AnClickActionModeColor) ? 255.0 : 1.0;
        cell.slider.value = row == ACEditorRowKindOCRSimilarity
            ? (float)self.model.ocrSimilarity
            : (self.model.actionMode == AnClickActionModeColor ? (float)self.model.colorTolerance : (float)self.model.threshold);
        cell.valueLabel.text = row == ACEditorRowKindOCRSimilarity
            ? [NSString stringWithFormat:@"%.0f%%", self.model.ocrSimilarity * 100.0]
            : (self.model.actionMode == AnClickActionModeColor
            ? [NSString stringWithFormat:@"%.0f", self.model.colorTolerance]
            : [NSString stringWithFormat:@"%.0f%%", self.model.threshold * 100.0]);
        [cell.slider removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
        [cell.slider addTarget:self action:@selector(handleSliderChanged:) forControlEvents:UIControlEventValueChanged];
        return cell;
    }
    if ([self isSegmentedRow:row]) {
        ACEditorSegmentedCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Segmented" forIndexPath:indexPath];
        [self configureSegmentedCell:cell row:row];
        return cell;
    }
    if (row == ACEditorRowKindPointPick ||
        row == ACEditorRowKindColorPick ||
        row == ACEditorRowKindTemplate ||
        row == ACEditorRowKindMacroRecord ||
        row == ACEditorRowKindSuccessActionConfig ||
        row == ACEditorRowKindFailureActionConfig ||
        row == ACEditorRowKindSingleStep ||
        row == ACEditorRowKindDelete) {
        ACEditorButtonCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Button" forIndexPath:indexPath];
        [cell.button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        cell.button.tag = row;
        UIColor *titleColor = UIColor.systemBlueColor;
        NSString *title = @"";
        SEL action = @selector(handleButtonRow:);
        if (row == ACEditorRowKindPointPick) {
            if (self.model.actionMode == AnClickActionModeTwoFingerTap) {
                title = @"⌖ 在屏幕上添加多指触点";
            } else if (self.model.actionMode == AnClickActionModeImage ||
                       self.model.actionMode == AnClickActionModeOCR ||
                       self.model.actionMode == AnClickActionModeColor) {
                title = @"⌖ 设置自定义点击坐标";
            } else {
                title = @"⌖ 在屏幕上拾取坐标";
            }
        } else if (row == ACEditorRowKindColorPick) {
            title = @"⌖ 在屏幕上拾取颜色及坐标";
        } else if (row == ACEditorRowKindTemplate) {
            title = self.model.templatePath.length > 0 ? @"🖼 重新截图选择识别图像" : @"🖼 截图选择识别图像";
        } else if (row == ACEditorRowKindMacroRecord) {
            title = self.model.events.count > 0 ? @"● 重新录制动作" : @"● 开始录制动作";
        } else if (row == ACEditorRowKindSuccessActionConfig || row == ACEditorRowKindFailureActionConfig) {
            BOOL success = row == ACEditorRowKindSuccessActionConfig;
            AnClickActionMode mode = success ? self.model.successActionMode : self.model.failureActionMode;
            NSString *role = success ? @"成功后" : @"失败后";
            NSString *verb = [self branchActionConfigExistsForSuccess:success] ? @"修改" : @"设置";
            if (mode == AnClickActionModeImage) {
                title = [NSString stringWithFormat:@"🖼 %@%@识图截图", verb, role];
            } else if (mode == AnClickActionModeColor) {
                title = [NSString stringWithFormat:@"🎨 %@%@识色取色", verb, role];
            } else {
                title = [NSString stringWithFormat:@"%@ %@%@配置", verb, role, [self branchActionShortTitleForMode:mode]];
            }
        } else if (row == ACEditorRowKindSingleStep) {
            title = @"运行此单步测试";
        } else {
            title = @"🗑 删除此任务";
            titleColor = UIColor.systemRedColor;
            cell.button.backgroundColor = [UIColor colorWithRed:1.0 green:0.16 blue:0.12 alpha:0.10];
            cell.button.layer.borderColor = [UIColor colorWithRed:1.0 green:0.16 blue:0.12 alpha:0.28].CGColor;
        }
        [cell.button setTitle:title forState:UIControlStateNormal];
        [cell.button setTitleColor:titleColor forState:UIControlStateNormal];
        [cell.button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
        if (row != ACEditorRowKindDelete) {
            cell.button.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
            cell.button.layer.borderColor = UIColor.separatorColor.CGColor;
        }
        return cell;
    }
    ACEditorInputCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Input" forIndexPath:indexPath];
    [self configureInputCell:cell row:row];
    return cell;
}

- (BOOL)isSegmentedRow:(ACEditorRowKind)row {
    return row == ACEditorRowKindColorMatchMode ||
        row == ACEditorRowKindRecognitionClickTargetMode ||
        row == ACEditorRowKindOCRMode ||
        row == ACEditorRowKindOCRMatchMode ||
        row == ACEditorRowKindNetworkMethod ||
        row == ACEditorRowKindNetworkRetryMode ||
        row == ACEditorRowKindRecognitionRetryMode;
}

- (void)configureSegmentedCell:(ACEditorSegmentedCell *)cell row:(ACEditorRowKind)row {
    cell.segmentedControl.tag = row;
    cell.iconLabel.textColor = UIColor.labelColor;
    [cell.segmentedControl removeAllSegments];
    NSArray<NSString *> *items = @[];
    NSInteger selectedIndex = 0;
    switch (row) {
        case ACEditorRowKindColorMatchMode:
            cell.iconLabel.text = @"🎨";
            cell.titleLabel.text = @"匹配模式";
            items = @[@"相等", @"不等"];
            selectedIndex = MIN(1, MAX(0, self.model.colorMatchMode));
            break;
        case ACEditorRowKindRecognitionClickTargetMode:
            cell.iconLabel.text = @"⌖";
            cell.titleLabel.text = @"点击位置";
            items = @[@"识别中心", @"自定义坐标"];
            selectedIndex = self.model.useMatchPoint ? 0 : 1;
            break;
        case ACEditorRowKindOCRMode:
            cell.iconLabel.text = @"🧠";
            cell.titleLabel.text = @"识字引擎";
            items = @[@"Apple"];
            selectedIndex = 0;
            break;
        case ACEditorRowKindOCRMatchMode:
            cell.iconLabel.text = @"≋";
            cell.titleLabel.text = @"匹配模式";
            items = @[@"包含", @"正则", @"等于"];
            selectedIndex = self.model.ocrMatchMode == AnClickOCRMatchModeRegex
                ? 1
                : (self.model.ocrMatchMode == AnClickOCRMatchModeEqual ? 2 : 0);
            break;
        case ACEditorRowKindNetworkMethod:
            cell.iconLabel.text = @"⇄";
            cell.titleLabel.text = @"请求方法";
            items = @[@"GET", @"POST"];
            selectedIndex = [[self.model.networkMethod uppercaseString] isEqualToString:@"POST"] || self.model.networkUsesPost ? 1 : 0;
            break;
        case ACEditorRowKindNetworkRetryMode:
            cell.iconLabel.text = @"↻";
            cell.titleLabel.text = @"重试模式";
            items = @[@"次数", @"无限"];
            selectedIndex = self.model.networkRetryForever ? 1 : 0;
            break;
        case ACEditorRowKindRecognitionRetryMode:
            cell.iconLabel.text = @"🔁";
            cell.titleLabel.text = @"识别重试";
            items = @[@"按次数", @"直到命中"];
            selectedIndex = self.model.recognitionRetryUntilFound ? 1 : 0;
            break;
        default:
            break;
    }
    for (NSUInteger i = 0; i < items.count; i++) {
        [cell.segmentedControl insertSegmentWithTitle:items[i] atIndex:i animated:NO];
    }
    cell.segmentedControl.selectedSegmentIndex = selectedIndex;
    [cell.segmentedControl removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
    [cell.segmentedControl addTarget:self action:@selector(handleSegmentChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)configureInputCell:(ACEditorInputCell *)cell row:(ACEditorRowKind)row {
    cell.textField.delegate = self;
    cell.textField.tag = row;
    [cell.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    [cell.textField addTarget:self action:@selector(handleTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    cell.iconLabel.textColor = UIColor.labelColor;
    cell.swatchView.hidden = YES;
    cell.unitLabel.text = @"";
    cell.textField.keyboardType = UIKeyboardTypeDefault;
    cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    cell.textField.enabled = YES;
    switch (row) {
        case ACEditorRowKindCoordinate: {
            CGPoint point = self.model.point ? self.model.point.CGPointValue : CGPointZero;
            cell.iconLabel.text = @"⌖";
            if (self.model.actionMode == AnClickActionModeColor) {
                cell.titleLabel.text = @"自定义点击坐标";
            } else if (self.model.actionMode == AnClickActionModeTwoFingerTap) {
                cell.titleLabel.text = @"多指触点";
            } else if (self.model.actionMode == AnClickActionModeImage || self.model.actionMode == AnClickActionModeOCR) {
                cell.titleLabel.text = @"自定义点击坐标";
            } else {
                cell.titleLabel.text = @"触点坐标";
            }
            if (self.model.actionMode == AnClickActionModeTwoFingerTap && self.model.multiPoints.count > 0) {
                cell.textField.text = [NSString stringWithFormat:@"已取 %lu 点", (unsigned long)self.model.multiPoints.count];
            } else {
                cell.textField.text = self.model.point ? [NSString stringWithFormat:@"%.0f, %.0f", point.x, point.y] : @"未拾取";
            }
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            break;
        }
        case ACEditorRowKindSwipeStart: {
            CGPoint point = [self swipePointAtIndex:0];
            cell.iconLabel.text = @"↗";
            cell.titleLabel.text = @"起点坐标";
            cell.textField.text = [self hasSwipePointAtIndex:0] ? [NSString stringWithFormat:@"%.0f, %.0f", point.x, point.y] : @"未拾取";
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            break;
        }
        case ACEditorRowKindSwipeEnd: {
            CGPoint point = [self swipePointAtIndex:1];
            cell.iconLabel.text = @"⇥";
            cell.titleLabel.text = @"终点坐标";
            cell.textField.text = [self hasSwipePointAtIndex:1] ? [NSString stringWithFormat:@"%.0f, %.0f", point.x, point.y] : @"未拾取";
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            break;
        }
        case ACEditorRowKindJitter:
            cell.iconLabel.text = @"◎";
            cell.titleLabel.text = @"抖动半径";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.jitterRadius];
            cell.textField.keyboardType = UIKeyboardTypeDecimalPad;
            cell.unitLabel.text = @"px";
            break;
        case ACEditorRowKindRepeat:
            cell.iconLabel.text = @"×";
            cell.titleLabel.text = @"重复次数";
            cell.textField.text = [NSString stringWithFormat:@"%ld", (long)MAX(1, self.model.repeatCount)];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            break;
        case ACEditorRowKindDoubleTapInterval:
            cell.iconLabel.text = @"⏱";
            cell.titleLabel.text = @"双击间隔";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.doubleTapInterval * 1000.0];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
            break;
        case ACEditorRowKindColor: {
            cell.iconLabel.text = @"🎨";
            cell.titleLabel.text = @"目标颜色";
            cell.textField.text = [self hexColorText];
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
            cell.swatchView.hidden = NO;
            cell.swatchView.backgroundColor = [UIColor colorWithRed:self.model.colorRed / 255.0
                                                              green:self.model.colorGreen / 255.0
                                                               blue:self.model.colorBlue / 255.0
                                                              alpha:1.0];
            break;
        }
        case ACEditorRowKindOCRText:
            cell.iconLabel.text = @"📝";
            cell.titleLabel.text = @"目标文字";
            cell.textField.text = self.model.ocrText;
            break;
        case ACEditorRowKindNetworkURL:
            cell.iconLabel.text = @"🌐";
            cell.titleLabel.text = @"请求地址";
            cell.textField.text = self.model.networkURL;
            cell.textField.keyboardType = UIKeyboardTypeURL;
            break;
        case ACEditorRowKindNetworkHeaders:
            cell.iconLabel.text = @"☰";
            cell.titleLabel.text = @"请求头";
            cell.textField.text = [self headersText:self.model.networkHeaders];
            break;
        case ACEditorRowKindNetworkBody:
            cell.iconLabel.text = @"{}";
            cell.titleLabel.text = @"请求体";
            cell.textField.text = self.model.networkPostBody;
            break;
        case ACEditorRowKindNetworkRetryLimit:
            cell.iconLabel.text = @"#";
            cell.titleLabel.text = @"重试次数";
            cell.textField.text = [NSString stringWithFormat:@"%ld", (long)MAX(1, self.model.networkRetryLimit)];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            break;
        case ACEditorRowKindNetworkTimeout:
            cell.iconLabel.text = @"⏲";
            cell.titleLabel.text = @"超时时间";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.networkTimeout];
            cell.textField.keyboardType = UIKeyboardTypeDecimalPad;
            cell.unitLabel.text = @"s";
            break;
        case ACEditorRowKindNetworkContains:
            cell.iconLabel.text = @"✓";
            cell.iconLabel.textColor = UIColor.systemGreenColor;
            cell.titleLabel.text = @"成功匹配内容";
            cell.textField.text = self.model.networkContains;
            break;
        case ACEditorRowKindNetworkFalse:
            cell.iconLabel.text = @"✕";
            cell.iconLabel.textColor = UIColor.systemRedColor;
            cell.titleLabel.text = @"失败匹配内容";
            cell.textField.text = self.model.networkFalse;
            break;
        case ACEditorRowKindJumpTarget:
            cell.iconLabel.text = @"🔀";
            cell.titleLabel.text = @"跳转任务 ID";
            cell.textField.text = self.model.jumpTaskIndex >= 0 ? [NSString stringWithFormat:@"%ld", (long)self.model.jumpTaskIndex + 1] : @"";
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            break;
        case ACEditorRowKindMacroSummary:
            cell.iconLabel.text = @"●";
            cell.titleLabel.text = @"录制内容";
            cell.textField.text = self.model.events.count > 0
                ? [NSString stringWithFormat:@"已录 %lu 步", (unsigned long)self.model.events.count]
                : @"未录制";
            cell.textField.enabled = NO;
            break;
        case ACEditorRowKindMacroSpeed:
            cell.iconLabel.text = @"⏩";
            cell.titleLabel.text = @"回放速度";
            cell.textField.text = [NSString stringWithFormat:@"%.2f", self.model.macroSpeed];
            cell.textField.keyboardType = UIKeyboardTypeDecimalPad;
            cell.unitLabel.text = @"x";
            break;
        case ACEditorRowKindSwipeDuration:
            cell.iconLabel.text = @"⏱";
            cell.titleLabel.text = @"滑动时长";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.swipeDuration * 1000.0];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
            break;
        case ACEditorRowKindSwipeStep:
            cell.iconLabel.text = @"⋯";
            cell.titleLabel.text = @"轨迹步长";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.swipeStep];
            cell.textField.keyboardType = UIKeyboardTypeDecimalPad;
            cell.unitLabel.text = @"px";
            break;
        case ACEditorRowKindDelay:
            cell.iconLabel.text = @"⏱";
            cell.titleLabel.text = @"延时时长";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.delay * 1000.0];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
            break;
        case ACEditorRowKindInterval:
            cell.iconLabel.text = @"⏱";
            cell.titleLabel.text = @"点击间隔";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.interval * 1000.0];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
            break;
        case ACEditorRowKindRecognitionRetryInterval:
            cell.iconLabel.text = @"🔁";
            cell.titleLabel.text = @"识别间隔";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.recognitionRetryInterval * 1000.0];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
            break;
        case ACEditorRowKindLongPress:
            cell.iconLabel.text = @"👆";
            cell.titleLabel.text = @"长按时长";
            cell.textField.text = [NSString stringWithFormat:@"%ld", (long)[self longPressMilliseconds]];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
            break;
        case ACEditorRowKindSuccessBranch:
            cell.iconLabel.text = @"✓";
            cell.iconLabel.textColor = UIColor.systemGreenColor;
            cell.titleLabel.text = @"成功跳转任务";
            cell.textField.text = [self branchTextForSuccess:YES];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            break;
        case ACEditorRowKindFailureBranch:
            cell.iconLabel.text = @"✕";
            cell.iconLabel.textColor = UIColor.systemRedColor;
            cell.titleLabel.text = @"失败跳转任务";
            cell.textField.text = [self branchTextForSuccess:NO];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            break;
        default:
            break;
    }
}

- (void)handleTextFieldChanged:(UITextField *)textField {
    NSString *text = textField.text ?: @"";
    switch ((ACEditorRowKind)textField.tag) {
        case ACEditorRowKindCoordinate:
            [self updateModelPointFromText:text];
            break;
        case ACEditorRowKindSwipeStart:
            [self updateSwipePointAtIndex:0 text:text];
            break;
        case ACEditorRowKindSwipeEnd:
            [self updateSwipePointAtIndex:1 text:text];
            break;
        case ACEditorRowKindJitter:
            self.model.jitterRadius = MIN(200.0, MAX(0.0, text.doubleValue));
            break;
        case ACEditorRowKindRepeat:
            self.model.repeatCount = MAX(1, text.integerValue);
            break;
        case ACEditorRowKindDoubleTapInterval:
            self.model.doubleTapInterval = MIN(2.0, MAX(0.02, text.doubleValue / 1000.0));
            break;
        case ACEditorRowKindColor:
            [self updateModelColorFromHex:text];
            break;
        case ACEditorRowKindOCRText:
            self.model.ocrText = text;
            break;
        case ACEditorRowKindNetworkURL:
            self.model.networkURL = text;
            break;
        case ACEditorRowKindNetworkHeaders:
            self.model.networkHeaders = [self headersFromText:text];
            break;
        case ACEditorRowKindNetworkBody:
            self.model.networkPostBody = text;
            break;
        case ACEditorRowKindNetworkRetryLimit:
            self.model.networkRetryLimit = MAX(1, text.integerValue);
            break;
        case ACEditorRowKindNetworkTimeout:
            self.model.networkTimeout = MIN(60.0, MAX(1.0, text.doubleValue));
            break;
        case ACEditorRowKindNetworkContains:
            self.model.networkContains = text;
            break;
        case ACEditorRowKindNetworkFalse:
            self.model.networkFalse = text;
            break;
        case ACEditorRowKindJumpTarget:
            self.model.jumpTaskIndex = text.length > 0 ? MAX(0, text.integerValue - 1) : -1;
            break;
        case ACEditorRowKindMacroSpeed:
            self.model.macroSpeed = MIN(10.0, MAX(0.1, text.doubleValue));
            break;
        case ACEditorRowKindSwipeDuration:
            self.model.swipeDuration = MIN(10.0, MAX(0.05, text.doubleValue / 1000.0));
            break;
        case ACEditorRowKindSwipeStep:
            self.model.swipeStep = MIN(200.0, MAX(1.0, text.doubleValue));
            break;
        case ACEditorRowKindDelay:
            self.model.delay = MAX(0.0, text.doubleValue) / 1000.0;
            break;
        case ACEditorRowKindInterval:
            self.model.interval = MAX(0.0, text.doubleValue) / 1000.0;
            break;
        case ACEditorRowKindLongPress:
            self.model.longPressDuration = MAX(0, text.integerValue) / 1000.0;
            break;
        case ACEditorRowKindRecognitionRetryInterval:
            self.model.recognitionRetryInterval = MIN(30.0, MAX(0.2, text.doubleValue / 1000.0));
            break;
        case ACEditorRowKindSuccessBranch:
            [self setBranchText:text success:YES];
            break;
        case ACEditorRowKindFailureBranch:
            [self setBranchText:text success:NO];
            break;
        default:
            break;
    }
    [self notifyModelChanged];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.activeTextField = textField;
    [self scrollActiveFieldIntoViewAnimated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (self.activeTextField == textField) {
        self.activeTextField = nil;
    }
    if (textField.tag == ACEditorRowKindRepeat) {
        [self reloadForm];
    }
}

- (void)handleKeyboardWillChangeFrame:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect localKeyboardFrame = [self convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.bounds) - CGRectGetMinY(localKeyboardFrame));
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)([notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
    UIEdgeInsets contentInset = self.baseContentInset;
    contentInset.bottom += overlap;
    UIEdgeInsets indicatorInsets = self.baseScrollIndicatorInsets;
    indicatorInsets.bottom += overlap;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options
                     animations:^{
                         self.tableView.contentInset = contentInset;
                         if (@available(iOS 13.0, *)) {
                             self.tableView.verticalScrollIndicatorInsets = indicatorInsets;
                         } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                             self.tableView.scrollIndicatorInsets = indicatorInsets;
#pragma clang diagnostic pop
                         }
                     }
                     completion:^(__unused BOOL finished) {
                         [self scrollActiveFieldIntoViewAnimated:YES];
                     }];
}

- (void)handleKeyboardWillHide:(NSNotification *)notification {
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)([notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options
                     animations:^{
                         self.tableView.contentInset = self.baseContentInset;
                         if (@available(iOS 13.0, *)) {
                             self.tableView.verticalScrollIndicatorInsets = self.baseScrollIndicatorInsets;
                         } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                             self.tableView.scrollIndicatorInsets = self.baseScrollIndicatorInsets;
#pragma clang diagnostic pop
                         }
                     }
                     completion:nil];
}

- (void)scrollActiveFieldIntoViewAnimated:(BOOL)animated {
    if (!self.activeTextField || !self.activeTextField.window) {
        return;
    }
    CGRect fieldRect = [self.activeTextField convertRect:self.activeTextField.bounds toView:self.tableView];
    fieldRect = CGRectInset(fieldRect, -12.0, -16.0);
    [self.tableView scrollRectToVisible:fieldRect animated:animated];
}

- (void)handleSliderChanged:(UISlider *)slider {
    ACEditorRowKind row = (ACEditorRowKind)slider.tag;
    if (row == ACEditorRowKindOCRSimilarity) {
        self.model.ocrSimilarity = slider.value;
    } else if (self.model.actionMode == AnClickActionModeColor) {
        self.model.colorTolerance = slider.value;
    } else {
        self.model.threshold = slider.value;
    }
    UIView *view = slider;
    while (view && ![view isKindOfClass:ACEditorSliderCell.class]) {
        view = view.superview;
    }
    ACEditorSliderCell *cell = [view isKindOfClass:ACEditorSliderCell.class] ? (ACEditorSliderCell *)view : nil;
    cell.valueLabel.text = row == ACEditorRowKindOCRSimilarity
        ? [NSString stringWithFormat:@"%.0f%%", self.model.ocrSimilarity * 100.0]
        : (self.model.actionMode == AnClickActionModeColor
        ? [NSString stringWithFormat:@"%.0f", self.model.colorTolerance]
        : [NSString stringWithFormat:@"%.0f%%", self.model.threshold * 100.0]);
    [self notifyModelChanged];
}

- (void)handleSegmentChanged:(UISegmentedControl *)segmentedControl {
    NSInteger selected = segmentedControl.selectedSegmentIndex;
    switch ((ACEditorRowKind)segmentedControl.tag) {
        case ACEditorRowKindColorMatchMode:
            self.model.colorMatchMode = selected == 1 ? 1 : 0;
            break;
        case ACEditorRowKindRecognitionClickTargetMode:
            self.model.useMatchPoint = selected != 1;
            [self reloadForm];
            break;
        case ACEditorRowKindOCRMode:
            self.model.ocrMode = AnClickOCRModeAppleVision;
            break;
        case ACEditorRowKindOCRMatchMode:
            self.model.ocrMatchMode = selected == 1
                ? AnClickOCRMatchModeRegex
                : (selected == 2 ? AnClickOCRMatchModeEqual : AnClickOCRMatchModeContains);
            break;
        case ACEditorRowKindNetworkMethod:
            self.model.networkMethod = selected == 1 ? @"POST" : @"GET";
            self.model.networkUsesPost = selected == 1;
            break;
        case ACEditorRowKindNetworkRetryMode:
            self.model.networkRetryForever = selected == 1;
            break;
        case ACEditorRowKindRecognitionRetryMode:
            self.model.recognitionRetryUntilFound = selected == 1;
            break;
        default:
            break;
    }
    [self notifyModelChanged];
}

- (void)handleButtonRow:(UIButton *)button {
    switch ((ACEditorRowKind)button.tag) {
        case ACEditorRowKindPointPick:
            [self.delegate taskEditorViewDidRequestPointPick:self];
            break;
        case ACEditorRowKindColorPick:
            [self.delegate taskEditorViewDidRequestColorPick:self];
            break;
        case ACEditorRowKindTemplate:
            [self.delegate taskEditorViewDidRequestTemplateCapture:self];
            break;
        case ACEditorRowKindMacroRecord:
            [self.delegate taskEditorViewDidRequestRecording:self];
            break;
        case ACEditorRowKindSuccessActionConfig:
            [self.delegate taskEditorViewDidRequestSuccessActionConfig:self];
            break;
        case ACEditorRowKindFailureActionConfig:
            [self.delegate taskEditorViewDidRequestFailureActionConfig:self];
            break;
        case ACEditorRowKindSingleStep:
            [self.delegate taskEditorViewDidRequestSingleStepTest:self];
            break;
        case ACEditorRowKindDelete:
            [self.delegate taskEditorViewDidDeleteTask:self];
            break;
        default:
            break;
    }
}

- (void)handleCancel {
    [self.delegate taskEditorViewDidCancel:self];
}

- (void)handleClose {
    [self.delegate taskEditorViewDidClose:self];
}

- (void)handleSave {
    [self notifyModelChanged];
    [self.delegate taskEditorViewDidSave:self];
}

- (void)notifyModelChanged {
    [self.delegate taskEditorView:self didUpdateModel:self.model];
}

- (NSString *)hexColorText {
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX",
            (long)MIN(255, MAX(0, self.model.colorRed)),
            (long)MIN(255, MAX(0, self.model.colorGreen)),
            (long)MIN(255, MAX(0, self.model.colorBlue))];
}

- (void)updateModelColorFromHex:(NSString *)hex {
    NSString *clean = [[hex stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    if (clean.length != 6) {
        return;
    }
    unsigned value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:clean];
    if (![scanner scanHexInt:&value]) {
        return;
    }
    self.model.colorRed = (value >> 16) & 0xFF;
    self.model.colorGreen = (value >> 8) & 0xFF;
    self.model.colorBlue = value & 0xFF;
}

- (NSString *)pointText:(CGPoint)point {
    return [NSString stringWithFormat:@"%.0f, %.0f", point.x, point.y];
}

- (NSArray<NSString *> *)numberPartsFromText:(NSString *)text {
    NSString *normalized = [[text ?: @"" stringByReplacingOccurrencesOfString:@"，" withString:@","] stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (normalized.length == 0) {
        return @[];
    }
    return [normalized componentsSeparatedByString:@","];
}

- (BOOL)pointFromText:(NSString *)text point:(CGPoint *)point {
    NSArray<NSString *> *parts = [self numberPartsFromText:text];
    if (parts.count < 2) {
        return NO;
    }
    *point = CGPointMake(parts[0].doubleValue, parts[1].doubleValue);
    return YES;
}

- (void)updateModelPointFromText:(NSString *)text {
    CGPoint point = CGPointZero;
    if ([self pointFromText:text point:&point]) {
        self.model.point = [NSValue valueWithCGPoint:point];
        if (self.model.actionMode == AnClickActionModeImage ||
            self.model.actionMode == AnClickActionModeOCR ||
            self.model.actionMode == AnClickActionModeColor) {
            self.model.useMatchPoint = NO;
        }
    }
}

- (BOOL)hasSwipePointAtIndex:(NSUInteger)index {
    return self.model.path.count > index && [self.model.path[index] isKindOfClass:NSValue.class];
}

- (CGPoint)swipePointAtIndex:(NSUInteger)index {
    return [self hasSwipePointAtIndex:index] ? [self.model.path[index] CGPointValue] : CGPointZero;
}

- (void)updateSwipePointAtIndex:(NSUInteger)index text:(NSString *)text {
    CGPoint point = CGPointZero;
    if (![self pointFromText:text point:&point]) {
        return;
    }
    NSMutableArray *path = [self.model.path mutableCopy] ?: [NSMutableArray array];
    while (path.count <= index) {
        [path addObject:[NSValue valueWithCGPoint:CGPointZero]];
    }
    path[index] = [NSValue valueWithCGPoint:point];
    self.model.path = path;
}

- (NSString *)headersText:(NSDictionary<NSString *, NSString *> *)headers {
    if (headers.count == 0) {
        return @"";
    }
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *key in headers) {
        id value = headers[key];
        [parts addObject:[NSString stringWithFormat:@"%@: %@", key, value ?: @""]];
    }
    return [parts componentsJoinedByString:@"; "];
}

- (NSDictionary<NSString *, NSString *> *)headersFromText:(NSString *)text {
    NSMutableDictionary<NSString *, NSString *> *headers = [NSMutableDictionary dictionary];
    NSArray<NSString *> *pairs = [text componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@";\n"]];
    for (NSString *pair in pairs) {
        NSRange separator = [pair rangeOfString:@":"];
        if (separator.location == NSNotFound) {
            separator = [pair rangeOfString:@"="];
        }
        if (separator.location == NSNotFound) {
            continue;
        }
        NSString *key = [[pair substringToIndex:separator.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *value = [[pair substringFromIndex:NSMaxRange(separator)] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (key.length > 0) {
            headers[key] = value ?: @"";
        }
    }
    return headers;
}

- (NSInteger)longPressMilliseconds {
    return MAX(0, (NSInteger)llround(self.model.longPressDuration * 1000.0));
}

- (void)setLongPressMilliseconds:(NSInteger)milliseconds {
    self.model.longPressDuration = MAX(0, milliseconds) / 1000.0;
}

- (NSString *)branchTextForSuccess:(BOOL)success {
    NSInteger index = success ? self.model.successBranchIndex : self.model.failureBranchIndex;
    return index >= 0 ? [NSString stringWithFormat:@"%ld", (long)index + 1] : @"";
}

- (void)setBranchText:(NSString *)text success:(BOOL)success {
    NSInteger number = text.integerValue;
    NSInteger index = (text.length > 0 && number > 0) ? number - 1 : -1;
    if (text.length > 0 && number > 0) {
        if (success) {
            self.model.successActionMode = AnClickActionModeJump;
            self.model.successBranchIndex = index;
        } else {
            self.model.failureActionMode = AnClickActionModeJump;
            self.model.failureBranchIndex = index;
        }
    } else {
        if (success) {
            self.model.successBranchIndex = -1;
        } else {
            self.model.failureBranchIndex = -1;
        }
    }
}

@end
