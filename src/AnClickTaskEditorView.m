#import "AnClickTaskEditorView.h"
#import <math.h>

typedef NS_ENUM(NSInteger, ACEditorRowKind) {
    ACEditorRowKindActionGrid = 0,
    ACEditorRowKindCoordinate,
    ACEditorRowKindSwipeStart,
    ACEditorRowKindSwipeEnd,
    ACEditorRowKindPointPick,
    ACEditorRowKindJitter,
    ACEditorRowKindPressure,
    ACEditorRowKindRepeat,
    ACEditorRowKindDoubleTapInterval,
    ACEditorRowKindTemplate,
    ACEditorRowKindTemplatePath,
    ACEditorRowKindTemplateROI,
    ACEditorRowKindMatchClickOffset,
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
    ACEditorRowKindMacroPath,
    ACEditorRowKindMacroArguments,
    ACEditorRowKindMacroSpeed,
    ACEditorRowKindSwipeDuration,
    ACEditorRowKindSwipeStep,
    ACEditorRowKindPinchDistance,
    ACEditorRowKindRotateAngles,
    ACEditorRowKindGestureDuration,
    ACEditorRowKindDelay,
    ACEditorRowKindInterval,
    ACEditorRowKindLongPress,
    ACEditorRowKindRecognitionRetryMode,
    ACEditorRowKindRecognitionRetryInterval,
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
            @{@"title": @"🤏 缩小", @"mode": @(AnClickActionModePinchIn)},
            @{@"title": @"↔ 放大", @"mode": @(AnClickActionModePinchOut)},
            @{@"title": @"⟳ 旋转", @"mode": @(AnClickActionModeRotate)},
            @{@"title": @"🖼 识图", @"mode": @(AnClickActionModeImage)},
            @{@"title": @"🎬 宏", @"mode": @(AnClickActionModeMacro)},
            @{@"title": @"📝 OCR", @"mode": @(AnClickActionModeOCR)},
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
        case 1: return @"目标参数 - 动态数据驱动";
        case 2: return @"时间控制";
        case 3: return @"逻辑分支";
        case 4: return @"";
        default: return @"";
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
        @(ACEditorRowKindCoordinate),
        @(ACEditorRowKindSwipeStart),
        @(ACEditorRowKindSwipeEnd),
        @(ACEditorRowKindPointPick),
        @(ACEditorRowKindTemplate),
        @(ACEditorRowKindTemplatePath),
        @(ACEditorRowKindTemplateROI),
        @(ACEditorRowKindMatchClickOffset),
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
        @(ACEditorRowKindMacroPath),
        @(ACEditorRowKindMacroArguments),
        @(ACEditorRowKindPinchDistance),
        @(ACEditorRowKindRotateAngles),
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
        @(ACEditorRowKindGestureDuration),
        @(ACEditorRowKindMacroSpeed),
        @(ACEditorRowKindJitter),
        @(ACEditorRowKindPressure),
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

- (BOOL)shouldShowRowForKind:(ACEditorRowKind)kind {
    AnClickActionMode mode = self.model.actionMode;
    if (mode == AnClickActionModeNone) {
        return kind == ACEditorRowKindActionGrid;
    }

    BOOL pointMode = mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeTwoFingerTap ||
        mode == AnClickActionModePinchIn ||
        mode == AnClickActionModePinchOut ||
        mode == AnClickActionModeRotate;
    BOOL recognitionMode = mode == AnClickActionModeImage ||
        mode == AnClickActionModeOCR ||
        mode == AnClickActionModeColor;

    switch (kind) {
        case ACEditorRowKindActionGrid:
            return YES;
        case ACEditorRowKindCoordinate:
            return pointMode || mode == AnClickActionModeColor;
        case ACEditorRowKindSwipeStart:
        case ACEditorRowKindSwipeEnd:
            return mode == AnClickActionModeSwipe;
        case ACEditorRowKindPointPick:
            return pointMode || mode == AnClickActionModeSwipe || mode == AnClickActionModeColor;
        case ACEditorRowKindJitter:
            return mode == AnClickActionModeTap ||
                mode == AnClickActionModeDoubleTap ||
                mode == AnClickActionModeLongPress ||
                mode == AnClickActionModeSwipe ||
                mode == AnClickActionModeTwoFingerTap ||
                mode == AnClickActionModePinchIn ||
                mode == AnClickActionModePinchOut ||
                mode == AnClickActionModeRotate ||
                mode == AnClickActionModeMacro;
        case ACEditorRowKindPressure:
            return mode == AnClickActionModeTap;
        case ACEditorRowKindRepeat:
            return mode == AnClickActionModeTap || mode == AnClickActionModeTwoFingerTap;
        case ACEditorRowKindDoubleTapInterval:
            return mode == AnClickActionModeDoubleTap;
        case ACEditorRowKindLongPress:
            return mode == AnClickActionModeLongPress;
        case ACEditorRowKindSwipeDuration:
        case ACEditorRowKindSwipeStep:
            return mode == AnClickActionModeSwipe;
        case ACEditorRowKindPinchDistance:
            return mode == AnClickActionModePinchIn || mode == AnClickActionModePinchOut;
        case ACEditorRowKindRotateAngles:
            return mode == AnClickActionModeRotate;
        case ACEditorRowKindGestureDuration:
            return mode == AnClickActionModePinchIn || mode == AnClickActionModePinchOut || mode == AnClickActionModeRotate;
        case ACEditorRowKindTemplate:
        case ACEditorRowKindTemplatePath:
        case ACEditorRowKindTemplateROI:
        case ACEditorRowKindMatchClickOffset:
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
        case ACEditorRowKindMacroPath:
        case ACEditorRowKindMacroArguments:
        case ACEditorRowKindMacroSpeed:
            return mode == AnClickActionModeMacro;
        case ACEditorRowKindDelay:
            return mode == AnClickActionModeDelay;
        case ACEditorRowKindInterval:
            return mode == AnClickActionModeTap || mode == AnClickActionModeTwoFingerTap;
        case ACEditorRowKindRecognitionRetryMode:
        case ACEditorRowKindRecognitionRetryInterval:
        case ACEditorRowKindSuccessBranch:
        case ACEditorRowKindFailureBranch:
            return recognitionMode;
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
        return @[@(ACEditorRowKindSuccessBranch), @(ACEditorRowKindFailureBranch), @(ACEditorRowKindSingleStep)];
    }
    return self.model.actionMode == AnClickActionModeNone ? @[] : @[@(ACEditorRowKindSingleStep)];
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
            [strongSelf.delegate taskEditorView:strongSelf didSelectActionMode:mode];
            strongSelf.model.actionMode = mode;
            [strongSelf notifyModelChanged];
            [strongSelf reloadForm];
        };
        [cell configureWithSelectedMode:self.model.actionMode];
        return cell;
    }
    if (row == ACEditorRowKindThreshold || row == ACEditorRowKindOCRSimilarity) {
        ACEditorSliderCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Slider" forIndexPath:indexPath];
        cell.iconLabel.text = row == ACEditorRowKindOCRSimilarity ? @"🔎" : @"⚖";
        cell.titleLabel.text = row == ACEditorRowKindOCRSimilarity
            ? @"OCR 相似度"
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
        row == ACEditorRowKindTemplate ||
        row == ACEditorRowKindSingleStep ||
        row == ACEditorRowKindDelete) {
        ACEditorButtonCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Button" forIndexPath:indexPath];
        [cell.button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        cell.button.tag = row;
        UIColor *titleColor = UIColor.systemBlueColor;
        NSString *title = @"";
        SEL action = @selector(handleButtonRow:);
        if (row == ACEditorRowKindPointPick) {
            title = self.model.actionMode == AnClickActionModeColor ? @"⌖ 在屏幕上拾取颜色及坐标" : @"⌖ 在屏幕上拾取坐标";
        } else if (row == ACEditorRowKindTemplate) {
            title = self.model.templatePath.length > 0 ? @"🖼 重新截图选择识别图像" : @"🖼 截图选择识别图像";
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
        row == ACEditorRowKindOCRMode ||
        row == ACEditorRowKindOCRMatchMode ||
        row == ACEditorRowKindNetworkMethod ||
        row == ACEditorRowKindNetworkRetryMode ||
        row == ACEditorRowKindRecognitionRetryMode;
}

- (void)configureSegmentedCell:(ACEditorSegmentedCell *)cell row:(ACEditorRowKind)row {
    cell.segmentedControl.tag = row;
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
        case ACEditorRowKindOCRMode:
            cell.iconLabel.text = @"🧠";
            cell.titleLabel.text = @"OCR 模式";
            items = @[@"Apple", @"Tesseract"];
            selectedIndex = self.model.ocrMode == AnClickOCRModeTesseract ? 1 : 0;
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
            cell.titleLabel.text = self.model.actionMode == AnClickActionModeColor ? @"目标坐标" : @"触点坐标";
            cell.textField.text = self.model.point ? [NSString stringWithFormat:@"%.0f, %.0f", point.x, point.y] : @"未拾取";
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
        case ACEditorRowKindPressure:
            cell.iconLabel.text = @"▣";
            cell.titleLabel.text = @"点击压力";
            cell.textField.text = [NSString stringWithFormat:@"%.2f", self.model.pressure];
            cell.textField.keyboardType = UIKeyboardTypeDecimalPad;
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
        case ACEditorRowKindTemplatePath:
            cell.iconLabel.text = @"🖼";
            cell.titleLabel.text = @"图片路径";
            cell.textField.text = self.model.templatePath;
            break;
        case ACEditorRowKindTemplateROI:
            cell.iconLabel.text = @"▢";
            cell.titleLabel.text = @"匹配区域 ROI";
            cell.textField.text = self.model.hasTemplateROI ? [self rectText:self.model.templateROI] : @"全屏";
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            break;
        case ACEditorRowKindMatchClickOffset:
            cell.iconLabel.text = @"＋";
            cell.titleLabel.text = @"成功点击偏移";
            cell.textField.text = self.model.hasMatchClickOffset ? [self pointText:self.model.matchClickOffset] : @"0, 0";
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
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
        case ACEditorRowKindMacroPath:
            cell.iconLabel.text = @"🎬";
            cell.titleLabel.text = @"宏路径";
            cell.textField.text = self.model.macroPath;
            break;
        case ACEditorRowKindMacroArguments:
            cell.iconLabel.text = @"$";
            cell.titleLabel.text = @"子脚本参数";
            cell.textField.text = self.model.macroArguments;
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
        case ACEditorRowKindPinchDistance:
            cell.iconLabel.text = @"↔";
            cell.titleLabel.text = @"距离变化";
            cell.textField.text = [NSString stringWithFormat:@"%.0f, %.0f", self.model.gestureFromDistance, self.model.gestureToDistance];
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            break;
        case ACEditorRowKindRotateAngles:
            cell.iconLabel.text = @"⟳";
            cell.titleLabel.text = @"旋转角度";
            cell.textField.text = [NSString stringWithFormat:@"%.0f, %.0f", self.model.rotationStartAngle, self.model.rotationEndAngle];
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            break;
        case ACEditorRowKindGestureDuration:
            cell.iconLabel.text = @"⏱";
            cell.titleLabel.text = @"手势时长";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.gestureDuration * 1000.0];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
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
            cell.titleLabel.text = @"后置延时";
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
            cell.titleLabel.text = @"成功时执行动作";
            cell.textField.text = [self branchTextForSuccess:YES];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            break;
        case ACEditorRowKindFailureBranch:
            cell.iconLabel.text = @"✕";
            cell.iconLabel.textColor = UIColor.systemRedColor;
            cell.titleLabel.text = @"失败时执行动作";
            cell.textField.text = [self branchTextForSuccess:NO];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            break;
        default:
            break;
    }
    if (row != ACEditorRowKindSuccessBranch && row != ACEditorRowKindFailureBranch) {
        cell.iconLabel.textColor = UIColor.labelColor;
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
        case ACEditorRowKindPressure:
            self.model.pressure = MIN(1.0, MAX(0.0, text.doubleValue));
            break;
        case ACEditorRowKindRepeat:
            self.model.repeatCount = MAX(1, text.integerValue);
            break;
        case ACEditorRowKindDoubleTapInterval:
            self.model.doubleTapInterval = MIN(2.0, MAX(0.02, text.doubleValue / 1000.0));
            break;
        case ACEditorRowKindTemplatePath:
            self.model.templatePath = text;
            break;
        case ACEditorRowKindTemplateROI:
            [self updateTemplateROIFromText:text];
            break;
        case ACEditorRowKindMatchClickOffset:
            [self updateMatchClickOffsetFromText:text];
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
        case ACEditorRowKindMacroPath:
            self.model.macroPath = text;
            break;
        case ACEditorRowKindMacroArguments:
            self.model.macroArguments = text;
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
        case ACEditorRowKindPinchDistance:
            [self updatePinchDistancesFromText:text];
            break;
        case ACEditorRowKindRotateAngles:
            [self updateRotateAnglesFromText:text];
            break;
        case ACEditorRowKindGestureDuration:
            self.model.gestureDuration = MIN(10.0, MAX(0.05, text.doubleValue / 1000.0));
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
        case ACEditorRowKindOCRMode:
            self.model.ocrMode = selected == 1 ? AnClickOCRModeTesseract : AnClickOCRModeAppleVision;
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
            if (self.model.actionMode == AnClickActionModeColor) {
                [self.delegate taskEditorViewDidRequestColorPick:self];
            } else {
                [self.delegate taskEditorViewDidRequestPointPick:self];
            }
            break;
        case ACEditorRowKindTemplate:
            [self.delegate taskEditorViewDidRequestTemplateCapture:self];
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

- (NSString *)rectText:(CGRect)rect {
    return [NSString stringWithFormat:@"%.0f, %.0f, %.0f, %.0f",
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height];
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

- (BOOL)rectFromText:(NSString *)text rect:(CGRect *)rect {
    NSArray<NSString *> *parts = [self numberPartsFromText:text];
    if (parts.count < 4) {
        return NO;
    }
    *rect = CGRectMake(parts[0].doubleValue, parts[1].doubleValue, MAX(0.0, parts[2].doubleValue), MAX(0.0, parts[3].doubleValue));
    return YES;
}

- (void)updateModelPointFromText:(NSString *)text {
    CGPoint point = CGPointZero;
    if ([self pointFromText:text point:&point]) {
        self.model.point = [NSValue valueWithCGPoint:point];
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

- (void)updateTemplateROIFromText:(NSString *)text {
    CGRect rect = CGRectZero;
    if ([self rectFromText:text rect:&rect] && rect.size.width > 0.0 && rect.size.height > 0.0) {
        self.model.templateROI = rect;
        self.model.hasTemplateROI = YES;
    } else if (text.length == 0 || [text isEqualToString:@"全屏"]) {
        self.model.hasTemplateROI = NO;
        self.model.templateROI = CGRectZero;
    }
}

- (void)updateMatchClickOffsetFromText:(NSString *)text {
    CGPoint point = CGPointZero;
    if ([self pointFromText:text point:&point]) {
        self.model.matchClickOffset = point;
        self.model.hasMatchClickOffset = YES;
    } else if (text.length == 0) {
        self.model.hasMatchClickOffset = NO;
        self.model.matchClickOffset = CGPointZero;
    }
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

- (void)updatePinchDistancesFromText:(NSString *)text {
    NSArray<NSString *> *parts = [self numberPartsFromText:text];
    if (parts.count < 2) {
        return;
    }
    self.model.gestureFromDistance = MIN(1000.0, MAX(1.0, parts[0].doubleValue));
    self.model.gestureToDistance = MIN(1000.0, MAX(1.0, parts[1].doubleValue));
}

- (void)updateRotateAnglesFromText:(NSString *)text {
    NSArray<NSString *> *parts = [self numberPartsFromText:text];
    if (parts.count < 2) {
        return;
    }
    self.model.rotationStartAngle = MIN(360.0, MAX(-360.0, parts[0].doubleValue));
    self.model.rotationEndAngle = MIN(360.0, MAX(-360.0, parts[1].doubleValue));
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
            self.model.successBranchIndex = index;
        } else {
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
