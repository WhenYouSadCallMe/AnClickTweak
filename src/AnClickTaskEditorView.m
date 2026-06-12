#import "AnClickTaskEditorView.h"

typedef NS_ENUM(NSInteger, ACEditorRowKind) {
    ACEditorRowKindActionGrid = 0,
    ACEditorRowKindCoordinate,
    ACEditorRowKindPointPick,
    ACEditorRowKindTemplate,
    ACEditorRowKindColor,
    ACEditorRowKindThreshold,
    ACEditorRowKindOCRText,
    ACEditorRowKindNetworkURL,
    ACEditorRowKindDelay,
    ACEditorRowKindInterval,
    ACEditorRowKindLongPress,
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
            @{@"title": @"⏳ 长按", @"mode": @(AnClickActionModeLongPress)},
            @{@"title": @"↗ 滑动", @"mode": @(AnClickActionModeSwipe)},
            @{@"title": @"🎨 识色", @"mode": @(AnClickActionModeColor)},
            @{@"title": @"🖼 识图", @"mode": @(AnClickActionModeImage)},
            @{@"title": @"🌐 网络", @"mode": @(AnClickActionModeNetwork)},
            @{@"title": @"📝 OCR", @"mode": @(AnClickActionModeOCR)},
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
        for (NSUInteger row = 0; row < 2; row++) {
            UIStackView *line = [[UIStackView alloc] initWithFrame:CGRectZero];
            line.axis = UILayoutConstraintAxisHorizontal;
            line.spacing = 8.0;
            line.distribution = UIStackViewDistributionFillEqually;
            [outer addArrangedSubview:line];
            NSUInteger start = row * 4;
            NSUInteger end = MIN(items.count, start + 4);
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
            if (row == 1 && end - start < 4) {
                for (NSUInteger i = end - start; i < 4; i++) {
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
            return @[];
        case 3:
            return [self logicRows];
        case 4:
            return self.taskIndex >= 0 ? @[@(ACEditorRowKindDelete)] : @[];
        default:
            return @[];
    }
}

- (NSArray<NSNumber *> *)parameterRows {
    switch (self.model.actionMode) {
        case AnClickActionModeNone:
            return @[];
        case AnClickActionModeDelay:
            return @[@(ACEditorRowKindDelay)];
        case AnClickActionModeImage:
            return @[@(ACEditorRowKindTemplate), @(ACEditorRowKindThreshold)];
        case AnClickActionModeColor:
            return @[@(ACEditorRowKindColor), @(ACEditorRowKindThreshold), @(ACEditorRowKindPointPick)];
        case AnClickActionModeOCR:
            return @[@(ACEditorRowKindOCRText), @(ACEditorRowKindCoordinate), @(ACEditorRowKindPointPick)];
        case AnClickActionModeNetwork:
            return @[@(ACEditorRowKindNetworkURL)];
        case AnClickActionModeTap:
        case AnClickActionModeDoubleTap:
        case AnClickActionModeTwoFingerTap:
        case AnClickActionModeSwipe:
            return @[@(ACEditorRowKindCoordinate), @(ACEditorRowKindPointPick)];
        case AnClickActionModeLongPress:
            return @[@(ACEditorRowKindCoordinate), @(ACEditorRowKindLongPress), @(ACEditorRowKindPointPick)];
        default:
            return @[];
    }
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
    if (row == ACEditorRowKindThreshold) {
        ACEditorSliderCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Slider" forIndexPath:indexPath];
        cell.iconLabel.text = @"⚖";
        cell.titleLabel.text = self.model.actionMode == AnClickActionModeColor ? @"相似度容差" : @"相似度阈值";
        cell.slider.tag = row;
        cell.slider.minimumValue = 0.0;
        cell.slider.maximumValue = self.model.actionMode == AnClickActionModeColor ? 255.0 : 1.0;
        cell.slider.value = self.model.actionMode == AnClickActionModeColor ? (float)self.model.colorTolerance : (float)self.model.threshold;
        cell.valueLabel.text = self.model.actionMode == AnClickActionModeColor
            ? [NSString stringWithFormat:@"%.0f", self.model.colorTolerance]
            : [NSString stringWithFormat:@"%.0f%%", self.model.threshold * 100.0];
        [cell.slider removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
        [cell.slider addTarget:self action:@selector(handleSliderChanged:) forControlEvents:UIControlEventValueChanged];
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
            cell.titleLabel.text = @"目标坐标";
            cell.textField.text = self.model.point ? [NSString stringWithFormat:@"%.0f, %.0f", point.x, point.y] : @"未拾取";
            cell.textField.enabled = NO;
            break;
        }
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
        case ACEditorRowKindColor:
            [self updateModelColorFromHex:text];
            break;
        case ACEditorRowKindOCRText:
            self.model.ocrText = text;
            break;
        case ACEditorRowKindNetworkURL:
            self.model.networkURL = text;
            break;
        case ACEditorRowKindDelay:
            self.model.delay = MAX(0.0, text.doubleValue) / 1000.0;
            break;
        case ACEditorRowKindInterval:
            self.model.interval = MAX(0.0, text.doubleValue) / 1000.0;
            break;
        case ACEditorRowKindLongPress:
            [self setLongPressMilliseconds:MAX(0, text.integerValue)];
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
    if (self.model.actionMode == AnClickActionModeColor) {
        self.model.colorTolerance = slider.value;
    } else {
        self.model.threshold = slider.value;
    }
    UIView *view = slider;
    while (view && ![view isKindOfClass:ACEditorSliderCell.class]) {
        view = view.superview;
    }
    ACEditorSliderCell *cell = [view isKindOfClass:ACEditorSliderCell.class] ? (ACEditorSliderCell *)view : nil;
    cell.valueLabel.text = self.model.actionMode == AnClickActionModeColor
        ? [NSString stringWithFormat:@"%.0f", self.model.colorTolerance]
        : [NSString stringWithFormat:@"%.0f%%", self.model.threshold * 100.0];
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

- (NSInteger)longPressMilliseconds {
    id value = self.model.extraFields[@"pressDurationMs"];
    if ([value respondsToSelector:@selector(integerValue)]) {
        return MAX(0, [value integerValue]);
    }
    return 0;
}

- (void)setLongPressMilliseconds:(NSInteger)milliseconds {
    NSMutableDictionary *extra = [self.model.extraFields mutableCopy] ?: [NSMutableDictionary dictionary];
    if (milliseconds > 0) {
        extra[@"pressDurationMs"] = @(milliseconds);
    } else {
        [extra removeObjectForKey:@"pressDurationMs"];
    }
    self.model.extraFields = extra;
}

- (NSString *)branchTextForSuccess:(BOOL)success {
    id value = self.model.extraFields[success ? @"successBranchIndex" : @"failureBranchIndex"];
    if ([value respondsToSelector:@selector(integerValue)] && [value integerValue] >= 0) {
        return [NSString stringWithFormat:@"%ld", (long)[value integerValue] + 1];
    }
    return @"";
}

- (void)setBranchText:(NSString *)text success:(BOOL)success {
    NSMutableDictionary *extra = [self.model.extraFields mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *key = success ? @"successBranchIndex" : @"failureBranchIndex";
    NSInteger number = text.integerValue;
    if (text.length > 0 && number > 0) {
        extra[key] = @(number - 1);
    } else {
        [extra removeObjectForKey:key];
    }
    self.model.extraFields = extra;
}

@end
