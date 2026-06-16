#import "AnClickTaskEditorView.h"
#import <math.h>

static const NSTimeInterval ACFastDoubleTapInterval = 0.06;
static NSString * const ACEditorDefaultNetworkContentType = @"application/json; charset=utf-8";
static NSString * const ACEditorDefaultNetworkUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1";

static NSDictionary *ACEditorDefaultNetworkHeaders(void) {
    return @{
        @"Content-Type": ACEditorDefaultNetworkContentType,
        @"Accept": @"application/json, text/plain, */*",
        @"User-Agent": ACEditorDefaultNetworkUserAgent,
    };
}

static const NSUInteger ACEditorMaxMultiPoints = 32;
static const NSInteger ACEditorPostPairValueTagOffset = 20000;
static const NSInteger ACEditorPostPairResultTagOffset = 40000;
static const NSInteger ACEditorPostPairDeleteTagOffset = 60000;

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
    ACEditorRowKindNetworkRequestMode,
    ACEditorRowKindNetworkHeaders,
    ACEditorRowKindNetworkBody,
    ACEditorRowKindNetworkAddPostPair,
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
    ACEditorRowKindSuccessRecognitionResultActionMode,
    ACEditorRowKindFailureRecognitionResultActionMode,
    ACEditorRowKindSuccessRecognitionResultClickTargetMode,
    ACEditorRowKindFailureRecognitionResultClickTargetMode,
    ACEditorRowKindSuccessRecognitionResultCoordinate,
    ACEditorRowKindFailureRecognitionResultCoordinate,
    ACEditorRowKindSuccessRecognitionResultPointPick,
    ACEditorRowKindFailureRecognitionResultPointPick,
    ACEditorRowKindSuccessRecognitionResultLongPress,
    ACEditorRowKindFailureRecognitionResultLongPress,
    ACEditorRowKindSuccessBranchMultiPointSummary,
    ACEditorRowKindFailureBranchMultiPointSummary,
    ACEditorRowKindSuccessBranchMultiPointAdd,
    ACEditorRowKindFailureBranchMultiPointAdd,
    ACEditorRowKindSuccessBranchMultiPointClear,
    ACEditorRowKindFailureBranchMultiPointClear,
    ACEditorRowKindSuccessBranchSwipeStart,
    ACEditorRowKindFailureBranchSwipeStart,
    ACEditorRowKindSuccessBranchSwipeEnd,
    ACEditorRowKindFailureBranchSwipeEnd,
    ACEditorRowKindSuccessBranchSwipeDuration,
    ACEditorRowKindFailureBranchSwipeDuration,
    ACEditorRowKindSuccessBranchSwipeStep,
    ACEditorRowKindFailureBranchSwipeStep,
    ACEditorRowKindSuccessBranchNetworkURL,
    ACEditorRowKindFailureBranchNetworkURL,
    ACEditorRowKindSuccessBranchNetworkMethod,
    ACEditorRowKindFailureBranchNetworkMethod,
    ACEditorRowKindSuccessBranchNetworkRequestMode,
    ACEditorRowKindFailureBranchNetworkRequestMode,
    ACEditorRowKindSuccessBranchNetworkHeaders,
    ACEditorRowKindFailureBranchNetworkHeaders,
    ACEditorRowKindSuccessBranchNetworkBody,
    ACEditorRowKindFailureBranchNetworkBody,
    ACEditorRowKindSuccessBranchNetworkAddPostPair,
    ACEditorRowKindFailureBranchNetworkAddPostPair,
    ACEditorRowKindSuccessBranchNetworkTimeout,
    ACEditorRowKindFailureBranchNetworkTimeout,
    ACEditorRowKindSuccessBranchNetworkContains,
    ACEditorRowKindFailureBranchNetworkContains,
    ACEditorRowKindSuccessBranchNetworkFalse,
    ACEditorRowKindFailureBranchNetworkFalse,
    ACEditorRowKindSuccessBranchDelay,
    ACEditorRowKindFailureBranchDelay,
    ACEditorRowKindSuccessBranchThreshold,
    ACEditorRowKindFailureBranchThreshold,
    ACEditorRowKindSuccessBranchOCRText,
    ACEditorRowKindFailureBranchOCRText,
    ACEditorRowKindSuccessBranchOCRSimilarity,
    ACEditorRowKindFailureBranchOCRSimilarity,
    ACEditorRowKindSuccessBranch,
    ACEditorRowKindFailureBranch,
    ACEditorRowKindSingleStep,
    ACEditorRowKindDelete,
    ACEditorRowKindNetworkPostPairBase = 1000,
    ACEditorRowKindSuccessBranchNetworkPostPairBase = 1100,
    ACEditorRowKindFailureBranchNetworkPostPairBase = 1200,
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
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.78;
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

- (void)prepareForReuse {
    [super prepareForReuse];
    self.iconLabel.text = @"";
    self.iconLabel.textColor = UIColor.labelColor;
    self.titleLabel.text = @"";
    self.textField.delegate = nil;
    self.textField.tag = 0;
    self.textField.text = @"";
    self.textField.placeholder = nil;
    self.textField.keyboardType = UIKeyboardTypeDefault;
    self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textField.enabled = YES;
    self.unitLabel.text = @"";
    self.swatchView.hidden = YES;
    self.swatchView.backgroundColor = UIColor.clearColor;
}

@end

@interface ACEditorPostPairCell : UITableViewCell
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, strong) UIButton *resultButton;
@property (nonatomic, strong) UILabel *resultBadgeLabel;
@property (nonatomic, strong) UIButton *deleteButton;
@end

@implementation ACEditorPostPairCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _iconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _iconLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
        _iconLabel.textColor = UIColor.systemBlueColor;
        _iconLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = UIColor.labelColor;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.minimumScaleFactor = 0.75;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _keyField = [[UITextField alloc] initWithFrame:CGRectZero];
        _keyField.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightMedium];
        _keyField.borderStyle = UITextBorderStyleRoundedRect;
        _keyField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _keyField.placeholder = @"键";
        _keyField.translatesAutoresizingMaskIntoConstraints = NO;

        _valueField = [[UITextField alloc] initWithFrame:CGRectZero];
        _valueField.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightMedium];
        _valueField.borderStyle = UITextBorderStyleRoundedRect;
        _valueField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _valueField.placeholder = @"值";
        _valueField.translatesAutoresizingMaskIntoConstraints = NO;

        _resultButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _resultButton.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        [_resultButton setTitle:@"识字" forState:UIControlStateNormal];
        _resultButton.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.12];
        _resultButton.layer.cornerRadius = 7.0;
        _resultButton.translatesAutoresizingMaskIntoConstraints = NO;

        _resultBadgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _resultBadgeLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
        _resultBadgeLabel.textColor = UIColor.systemBlueColor;
        _resultBadgeLabel.textAlignment = NSTextAlignmentCenter;
        _resultBadgeLabel.text = @"OCR";
        _resultBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _deleteButton.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
        [_deleteButton setTitle:@"删" forState:UIControlStateNormal];
        [_deleteButton setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
        _deleteButton.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.10];
        _deleteButton.layer.cornerRadius = 7.0;
        _deleteButton.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_iconLabel];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_keyField];
        [self.contentView addSubview:_valueField];
        [self.contentView addSubview:_resultButton];
        [self.contentView addSubview:_resultBadgeLabel];
        [self.contentView addSubview:_deleteButton];

        [NSLayoutConstraint activateConstraints:@[
            [_iconLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_iconLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:15.0],
            [_iconLabel.widthAnchor constraintEqualToConstant:26.0],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconLabel.trailingAnchor constant:8.0],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_iconLabel.centerYAnchor],
            [_titleLabel.widthAnchor constraintEqualToConstant:78.0],

            [_keyField.leadingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor constant:8.0],
            [_keyField.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_keyField.heightAnchor constraintEqualToConstant:34.0],

            [_valueField.leadingAnchor constraintEqualToAnchor:_keyField.trailingAnchor constant:8.0],
            [_valueField.trailingAnchor constraintEqualToAnchor:_resultButton.leadingAnchor constant:-8.0],
            [_valueField.centerYAnchor constraintEqualToAnchor:_keyField.centerYAnchor],
            [_valueField.widthAnchor constraintEqualToAnchor:_keyField.widthAnchor],
            [_valueField.heightAnchor constraintEqualToAnchor:_keyField.heightAnchor],

            [_resultButton.trailingAnchor constraintEqualToAnchor:_deleteButton.leadingAnchor constant:-6.0],
            [_resultButton.centerYAnchor constraintEqualToAnchor:_keyField.centerYAnchor],
            [_resultButton.widthAnchor constraintEqualToConstant:46.0],
            [_resultButton.heightAnchor constraintEqualToConstant:32.0],

            [_resultBadgeLabel.trailingAnchor constraintEqualToAnchor:_resultButton.trailingAnchor],
            [_resultBadgeLabel.bottomAnchor constraintEqualToAnchor:_resultButton.topAnchor constant:-2.0],

            [_deleteButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0],
            [_deleteButton.centerYAnchor constraintEqualToAnchor:_keyField.centerYAnchor],
            [_deleteButton.widthAnchor constraintEqualToConstant:34.0],
            [_deleteButton.heightAnchor constraintEqualToConstant:32.0],

            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:58.0],
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.iconLabel.text = @"";
    self.titleLabel.text = @"";
    self.keyField.delegate = nil;
    self.valueField.delegate = nil;
    [self.resultButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [self.deleteButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    self.keyField.tag = 0;
    self.valueField.tag = 0;
    self.resultButton.tag = 0;
    self.deleteButton.tag = 0;
    self.keyField.text = @"";
    self.valueField.text = @"";
    self.keyField.placeholder = @"键";
    self.valueField.placeholder = @"值";
    self.keyField.keyboardType = UIKeyboardTypeDefault;
    self.valueField.keyboardType = UIKeyboardTypeDefault;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.valueField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.valueField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.resultButton.hidden = NO;
    self.resultBadgeLabel.hidden = NO;
    self.deleteButton.hidden = NO;
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
@property (nonatomic, assign) AnClickActionMode selectedMode;
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
    self.selectedMode = selectedMode;
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
    [self focusSelectedChoiceWithoutAnimation];
}

- (void)focusSelectedChoiceWithoutAnimation {
    AnClickActionMode selectedMode = self.selectedMode;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.selectedMode != selectedMode) {
            return;
        }
        [strongSelf.contentView layoutIfNeeded];
        [strongSelf.scrollView layoutIfNeeded];
        UIButton *selectedButton = nil;
        for (UIView *view in strongSelf.stackView.arrangedSubviews) {
            if ([view isKindOfClass:UIButton.class] && view.tag == selectedMode) {
                selectedButton = (UIButton *)view;
                break;
            }
        }
        if (!selectedButton) {
            return;
        }
        CGRect targetRect = [selectedButton convertRect:selectedButton.bounds toView:strongSelf.scrollView];
        targetRect = CGRectInset(targetRect, -10.0, 0.0);
        [strongSelf.scrollView scrollRectToVisible:targetRect animated:NO];
    });
}

- (void)handleChoiceButton:(UIButton *)button {
    if (self.selectionHandler) {
        self.selectionHandler((AnClickActionMode)button.tag);
    }
}

@end

@interface ACEditorButtonCell : UITableViewCell
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) NSLayoutConstraint *previewHeightConstraint;
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
        _previewImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _previewImageView.contentMode = UIViewContentModeScaleAspectFit;
        _previewImageView.clipsToBounds = YES;
        _previewImageView.layer.cornerRadius = 10.0;
        _previewImageView.layer.borderWidth = 1.0;
        _previewImageView.layer.borderColor = UIColor.separatorColor.CGColor;
        _previewImageView.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
        _previewImageView.hidden = YES;
        _previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_button];
        [self.contentView addSubview:_previewImageView];
        _previewHeightConstraint = [_previewImageView.heightAnchor constraintEqualToConstant:0.0];
        [NSLayoutConstraint activateConstraints:@[
            [_button.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14.0],
            [_button.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14.0],
            [_button.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10.0],
            [_button.heightAnchor constraintEqualToConstant:42.0],
            [_previewImageView.leadingAnchor constraintEqualToAnchor:_button.leadingAnchor],
            [_previewImageView.trailingAnchor constraintEqualToAnchor:_button.trailingAnchor],
            [_previewImageView.topAnchor constraintEqualToAnchor:_button.bottomAnchor constant:8.0],
            [_previewImageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10.0],
            _previewHeightConstraint,
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
- (NSDictionary *)draftBranchConfigForMode:(AnClickActionMode)mode;
- (NSDictionary *)branchPointActionConfigForSuccess:(BOOL)success;
- (void)storeBranchPointActionConfig:(NSDictionary *)pointConfig success:(BOOL)success;
- (NSMutableDictionary *)recognitionResultActionConfigForBranchSuccess:(BOOL)success;
- (void)storeRecognitionResultActionConfig:(NSDictionary *)actionConfig forBranchSuccess:(BOOL)success;
- (BOOL)pointFromText:(NSString *)text point:(CGPoint *)point;
- (NSString *)pointText:(CGPoint)point;
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
    [_tableView registerClass:ACEditorPostPairCell.class forCellReuseIdentifier:@"PostPair"];
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
            return [self isEditingBranchActionConfig] ? @[] : @[@(ACEditorRowKindActionGrid)];
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
        @(ACEditorRowKindOCRMatchMode),
        @(ACEditorRowKindOCRText),
        @(ACEditorRowKindOCRSimilarity),
        @(ACEditorRowKindNetworkURL),
        @(ACEditorRowKindNetworkMethod),
        @(ACEditorRowKindNetworkRequestMode),
        @(ACEditorRowKindNetworkAddPostPair),
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
            if (row.integerValue == ACEditorRowKindNetworkAddPostPair) {
                [rows addObjectsFromArray:[self networkPostPairRows]];
            }
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

- (BOOL)isNetworkPostPairRow:(ACEditorRowKind)row {
    return (row >= ACEditorRowKindNetworkPostPairBase &&
        row < ACEditorRowKindNetworkPostPairBase + 100) ||
        (row >= ACEditorRowKindSuccessBranchNetworkPostPairBase &&
        row < ACEditorRowKindSuccessBranchNetworkPostPairBase + 100) ||
        (row >= ACEditorRowKindFailureBranchNetworkPostPairBase &&
        row < ACEditorRowKindFailureBranchNetworkPostPairBase + 100);
}

- (BOOL)isNetworkPostPairValueTag:(NSInteger)tag {
    NSInteger keyTag = tag - ACEditorPostPairValueTagOffset;
    return [self isNetworkPostPairRow:(ACEditorRowKind)keyTag];
}

- (BOOL)isNetworkPostPairResultTag:(NSInteger)tag {
    NSInteger keyTag = tag - ACEditorPostPairResultTagOffset;
    return [self isNetworkPostPairRow:(ACEditorRowKind)keyTag];
}

- (BOOL)isNetworkPostPairDeleteTag:(NSInteger)tag {
    NSInteger keyTag = tag - ACEditorPostPairDeleteTagOffset;
    return [self isNetworkPostPairRow:(ACEditorRowKind)keyTag];
}

- (ACEditorRowKind)networkPostPairRowForValueTag:(NSInteger)tag {
    return (ACEditorRowKind)(tag - ACEditorPostPairValueTagOffset);
}

- (ACEditorRowKind)networkPostPairRowForResultTag:(NSInteger)tag {
    return (ACEditorRowKind)(tag - ACEditorPostPairResultTagOffset);
}

- (ACEditorRowKind)networkPostPairRowForDeleteTag:(NSInteger)tag {
    return (ACEditorRowKind)(tag - ACEditorPostPairDeleteTagOffset);
}

- (NSUInteger)networkPostPairIndexForRow:(ACEditorRowKind)row {
    if (row >= ACEditorRowKindSuccessBranchNetworkPostPairBase &&
        row < ACEditorRowKindSuccessBranchNetworkPostPairBase + 100) {
        return (NSUInteger)(row - ACEditorRowKindSuccessBranchNetworkPostPairBase);
    }
    if (row >= ACEditorRowKindFailureBranchNetworkPostPairBase &&
        row < ACEditorRowKindFailureBranchNetworkPostPairBase + 100) {
        return (NSUInteger)(row - ACEditorRowKindFailureBranchNetworkPostPairBase);
    }
    return (NSUInteger)(row - ACEditorRowKindNetworkPostPairBase);
}

- (NSUInteger)networkPostPairIndexForValueTag:(NSInteger)tag {
    return [self networkPostPairIndexForRow:[self networkPostPairRowForValueTag:tag]];
}

- (NSArray<NSNumber *> *)networkPostPairRows {
    if (self.model.actionMode != AnClickActionModeNetwork ||
        ![[self.model.networkMethod uppercaseString] isEqualToString:@"POST"]) {
        return @[];
    }
    NSMutableArray<NSNumber *> *rows = [NSMutableArray array];
    NSUInteger count = MIN((NSUInteger)8, self.model.networkPostPairs.count);
    for (NSUInteger index = 0; index < count; index++) {
        [rows addObject:@(ACEditorRowKindNetworkPostPairBase + (NSInteger)index)];
    }
    return rows;
}

- (NSArray *)branchNetworkPostPairsForSuccess:(BOOL)success {
    NSDictionary *config = [self branchPointActionConfigForSuccess:success];
    NSArray *pairs = [config[@"networkPostPairs"] isKindOfClass:NSArray.class] ? config[@"networkPostPairs"] : @[];
    return pairs ?: @[];
}

- (void)setBranchNetworkPostPairs:(NSArray *)pairs success:(BOOL)success {
    [self storeBranchInlineValue:pairs ?: @[] key:@"networkPostPairs" success:success];
}

- (NSArray *)networkPostPairsForRow:(ACEditorRowKind)row {
    if (row >= ACEditorRowKindSuccessBranchNetworkPostPairBase &&
        row < ACEditorRowKindSuccessBranchNetworkPostPairBase + 100) {
        return [self branchNetworkPostPairsForSuccess:YES];
    }
    if (row >= ACEditorRowKindFailureBranchNetworkPostPairBase &&
        row < ACEditorRowKindFailureBranchNetworkPostPairBase + 100) {
        return [self branchNetworkPostPairsForSuccess:NO];
    }
    return self.model.networkPostPairs ?: @[];
}

- (BOOL)networkPostPairRowBelongsToBranch:(ACEditorRowKind)row success:(BOOL *)success {
    if (row >= ACEditorRowKindSuccessBranchNetworkPostPairBase &&
        row < ACEditorRowKindSuccessBranchNetworkPostPairBase + 100) {
        if (success) *success = YES;
        return YES;
    }
    if (row >= ACEditorRowKindFailureBranchNetworkPostPairBase &&
        row < ACEditorRowKindFailureBranchNetworkPostPairBase + 100) {
        if (success) *success = NO;
        return YES;
    }
    return NO;
}

- (NSArray<NSNumber *> *)branchNetworkPostPairRowsForSuccess:(BOOL)success {
    NSString *method = [self branchInlineStringValueForSuccess:success key:@"networkMethod"];
    if (![[method uppercaseString] isEqualToString:@"POST"]) {
        return @[];
    }
    NSArray *pairs = [self branchNetworkPostPairsForSuccess:success];
    NSMutableArray<NSNumber *> *rows = [NSMutableArray array];
    NSUInteger count = MIN((NSUInteger)8, pairs.count);
    NSInteger base = success ? ACEditorRowKindSuccessBranchNetworkPostPairBase : ACEditorRowKindFailureBranchNetworkPostPairBase;
    for (NSUInteger index = 0; index < count; index++) {
        [rows addObject:@(base + (NSInteger)index)];
    }
    return rows;
}

- (BOOL)branchActionModeCanUseRecognitionPoint:(AnClickActionMode)mode {
    return mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeTwoFingerTap;
}

- (BOOL)recognitionResultActionModeCanInlineConfigure:(AnClickActionMode)mode {
    return mode == AnClickActionModeTap ||
        mode == AnClickActionModeDoubleTap ||
        mode == AnClickActionModeLongPress ||
        mode == AnClickActionModeTwoFingerTap ||
        mode == AnClickActionModeSwipe ||
        mode == AnClickActionModeNetwork ||
        mode == AnClickActionModeDelay ||
        mode == AnClickActionModeJump;
}

- (BOOL)branchActionModeUsesRecognitionResultAction:(AnClickActionMode)mode {
    return mode == AnClickActionModeImage ||
        mode == AnClickActionModeOCR ||
        mode == AnClickActionModeColor;
}

- (NSArray<NSNumber *> *)branchActionModesForSuccess:(BOOL)success {
    NSMutableArray<NSNumber *> *modes = [NSMutableArray array];
    if (!success || self.model.actionMode == AnClickActionModeNetwork) {
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
    if (mode == AnClickActionModeOCR) {
        return NO;
    }
    if (mode == AnClickActionModeSwipe || mode == AnClickActionModeNetwork) {
        return NO;
    }
    if (self.model.actionMode == AnClickActionModeNetwork) {
        return YES;
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

- (BOOL)branchSelectedActionIsRecognitionForSuccess:(BOOL)success {
    AnClickActionMode mode = success ? self.model.successActionMode : self.model.failureActionMode;
    return [self branchActionModeUsesRecognitionResultAction:mode];
}

- (NSArray<NSValue *> *)branchMultiPointsForSuccess:(BOOL)success {
    NSDictionary *config = [self branchPointActionConfigForSuccess:success];
    NSArray *points = [config[@"multiPoints"] isKindOfClass:NSArray.class] ? config[@"multiPoints"] : @[];
    NSMutableArray<NSValue *> *result = [NSMutableArray array];
    for (id value in points) {
        if ([value isKindOfClass:NSValue.class]) {
            [result addObject:value];
        }
    }
    return result;
}

- (void)storeBranchMultiPoints:(NSArray<NSValue *> *)points success:(BOOL)success {
    NSMutableDictionary *config = [[self branchPointActionConfigForSuccess:success] mutableCopy];
    config[@"multiPoints"] = [points copy] ?: @[];
    config[@"useMatchPoint"] = @NO;
    [self storeBranchPointActionConfig:config success:success];
}

- (void)clearBranchMultiPoints:(BOOL)success {
    [self storeBranchMultiPoints:@[] success:success];
}

- (NSMutableDictionary *)mutableBranchConfigForSuccess:(BOOL)success {
    NSDictionary *config = success ? self.model.successActionConfig : self.model.failureActionConfig;
    if (![config isKindOfClass:NSDictionary.class] || config.count == 0) {
        config = success ? self.model.successRecognitionActionConfig : self.model.failureRecognitionActionConfig;
    }
    AnClickActionMode mode = success ? self.model.successActionMode : self.model.failureActionMode;
    NSMutableDictionary *mutableConfig = ([config isKindOfClass:NSDictionary.class] && config.count > 0)
        ? [config mutableCopy]
        : [[self draftBranchConfigForMode:mode] mutableCopy];
    mutableConfig[@"mode"] = @(mode);
    return mutableConfig;
}

- (void)storeMutableBranchConfig:(NSDictionary *)config success:(BOOL)success {
    if (![config isKindOfClass:NSDictionary.class]) {
        return;
    }
    if (success) {
        self.model.successActionConfig = config;
        self.model.successRecognitionActionConfig = [self branchSelectedActionIsRecognitionForSuccess:YES] ? config : @{};
    } else {
        self.model.failureActionConfig = config;
        self.model.failureRecognitionActionConfig = [self branchSelectedActionIsRecognitionForSuccess:NO] ? config : @{};
    }
}

- (AnClickActionMode)recognitionResultActionModeForBranchSuccess:(BOOL)success {
    NSDictionary *config = [self mutableBranchConfigForSuccess:success];
    id value = config[@"imageActionMode"];
    if (![value respondsToSelector:@selector(integerValue)]) {
        return AnClickActionModeTap;
    }
    AnClickActionMode mode = (AnClickActionMode)[value integerValue];
    if (![self recognitionResultActionModeCanInlineConfigure:mode]) {
        return AnClickActionModeTap;
    }
    return mode;
}

- (AnClickActionMode)branchPointActionModeForSuccess:(BOOL)success {
    if ([self branchSelectedActionIsRecognitionForSuccess:success]) {
        return [self recognitionResultActionModeForBranchSuccess:success];
    }
    return success ? self.model.successActionMode : self.model.failureActionMode;
}

- (double)branchInlineDoubleValueForSuccess:(BOOL)success key:(NSString *)key defaultValue:(double)defaultValue {
    NSDictionary *config = [self branchPointActionConfigForSuccess:success];
    id value = config[key];
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : defaultValue;
}

- (NSString *)branchInlineStringValueForSuccess:(BOOL)success key:(NSString *)key {
    NSDictionary *config = [self branchPointActionConfigForSuccess:success];
    id value = config[key];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

- (BOOL)branchInlineBoolValueForSuccess:(BOOL)success key:(NSString *)key defaultValue:(BOOL)defaultValue {
    NSDictionary *config = [self branchPointActionConfigForSuccess:success];
    id value = config[key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : defaultValue;
}

- (void)storeBranchInlineValue:(id)value key:(NSString *)key success:(BOOL)success {
    NSMutableDictionary *config = [[self branchPointActionConfigForSuccess:success] mutableCopy];
    if (value) {
        config[key] = value;
    } else {
        [config removeObjectForKey:key];
    }
    [self storeBranchPointActionConfig:config success:success];
}

- (BOOL)branchPointRowsAvailableForSuccess:(BOOL)success judgementMode:(BOOL)judgementMode {
    if (!judgementMode) {
        return NO;
    }
    return [self branchActionModeCanUseRecognitionPoint:[self branchPointActionModeForSuccess:success]];
}

- (BOOL)branchPointTargetModeRowAvailableForSuccess:(BOOL)success recognitionMode:(BOOL)recognitionMode {
    if (![self branchPointRowsAvailableForSuccess:success judgementMode:recognitionMode]) {
        return NO;
    }
    if ([self branchPointActionModeForSuccess:success] == AnClickActionModeTwoFingerTap) {
        return NO;
    }
    return success || [self branchSelectedActionIsRecognitionForSuccess:success];
}

- (BOOL)recognitionResultUsesMatchPointForBranchSuccess:(BOOL)success {
    if (!success &&
        ![self branchSelectedActionIsRecognitionForSuccess:NO] &&
        [self branchActionModeCanUseRecognitionPoint:self.model.failureActionMode]) {
        return NO;
    }
    NSDictionary *config = [self branchPointActionConfigForSuccess:success];
    id value = config[@"useMatchPoint"];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : YES;
}

- (CGPoint)recognitionResultPointForBranchSuccess:(BOOL)success hasPoint:(BOOL *)hasPoint {
    NSDictionary *config = [self branchPointActionConfigForSuccess:success];
    id value = config[@"point"];
    if ([value isKindOfClass:NSValue.class]) {
        if (hasPoint) {
            *hasPoint = YES;
        }
        return [(NSValue *)value CGPointValue];
    }
    if (hasPoint) {
        *hasPoint = NO;
    }
    return CGPointZero;
}

- (NSTimeInterval)recognitionResultLongPressDurationForBranchSuccess:(BOOL)success {
    NSDictionary *config = [self branchPointActionConfigForSuccess:success];
    id millisecondValue = config[@"pressDurationMs"];
    if ([millisecondValue respondsToSelector:@selector(doubleValue)]) {
        return MAX(0.0, [millisecondValue doubleValue] / 1000.0);
    }
    id value = config[@"pressDuration"];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return MAX(0.0, [value doubleValue]);
    }
    return self.model.longPressDuration > 0.0 ? self.model.longPressDuration : 0.50;
}

- (NSArray<NSDictionary *> *)recognitionResultActionItems {
    NSArray<NSNumber *> *modes = @[
        @(AnClickActionModeTap),
        @(AnClickActionModeDoubleTap),
        @(AnClickActionModeLongPress),
        @(AnClickActionModeTwoFingerTap),
        @(AnClickActionModeSwipe),
        @(AnClickActionModeNetwork),
        @(AnClickActionModeDelay),
        @(AnClickActionModeJump),
    ];
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    for (NSNumber *modeNumber in modes) {
        AnClickActionMode mode = (AnClickActionMode)modeNumber.integerValue;
        [items addObject:@{
            @"title": [self branchActionShortTitleForMode:mode],
            @"mode": @(mode),
        }];
    }
    return items;
}

- (AnClickActionMode)branchModeForSuccess:(BOOL)success {
    return success ? self.model.successActionMode : self.model.failureActionMode;
}

- (double)branchDoubleValueForSuccess:(BOOL)success key:(NSString *)key defaultValue:(double)defaultValue {
    NSDictionary *config = [self mutableBranchConfigForSuccess:success];
    id value = config[key];
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : defaultValue;
}

- (NSString *)branchStringValueForSuccess:(BOOL)success key:(NSString *)key {
    NSDictionary *config = [self mutableBranchConfigForSuccess:success];
    id value = config[key];
    return [value isKindOfClass:NSString.class] ? value : @"";
}

- (void)storeBranchValue:(id)value key:(NSString *)key success:(BOOL)success {
    NSMutableDictionary *config = [self mutableBranchConfigForSuccess:success];
    if (value) {
        config[key] = value;
    } else {
        [config removeObjectForKey:key];
    }
    [self storeMutableBranchConfig:config success:success];
}

- (NSDictionary *)branchPointActionConfigForSuccess:(BOOL)success {
    if ([self branchSelectedActionIsRecognitionForSuccess:success]) {
        return [self recognitionResultActionConfigForBranchSuccess:success];
    }
    return [self mutableBranchConfigForSuccess:success];
}

- (void)storeBranchPointActionConfig:(NSDictionary *)pointConfig success:(BOOL)success {
    if ([self branchSelectedActionIsRecognitionForSuccess:success]) {
        [self storeRecognitionResultActionConfig:pointConfig forBranchSuccess:success];
        return;
    }
    [self storeMutableBranchConfig:pointConfig success:success];
}

- (NSMutableDictionary *)recognitionResultActionConfigForBranchSuccess:(BOOL)success {
    NSMutableDictionary *parentConfig = [self mutableBranchConfigForSuccess:success];
    AnClickActionMode mode = [self recognitionResultActionModeForBranchSuccess:success];
    NSDictionary *existingConfig = [parentConfig[@"successActionConfig"] isKindOfClass:NSDictionary.class]
        ? parentConfig[@"successActionConfig"]
        : nil;
    NSMutableDictionary *config = ([existingConfig isKindOfClass:NSDictionary.class] &&
                                   [existingConfig[@"mode"] respondsToSelector:@selector(integerValue)] &&
                                   [existingConfig[@"mode"] integerValue] == mode)
        ? [existingConfig mutableCopy]
        : [[self draftBranchConfigForMode:mode] mutableCopy];
    config[@"mode"] = @(mode);
    return config;
}

- (void)storeRecognitionResultActionConfig:(NSDictionary *)actionConfig forBranchSuccess:(BOOL)success {
    if (![actionConfig isKindOfClass:NSDictionary.class]) {
        return;
    }
    NSMutableDictionary *parentConfig = [self mutableBranchConfigForSuccess:success];
    AnClickActionMode mode = [self recognitionResultActionModeForBranchSuccess:success];
    NSMutableDictionary *mutableActionConfig = [actionConfig mutableCopy];
    mutableActionConfig[@"mode"] = @(mode);
    parentConfig[@"imageActionMode"] = @(mode);
    parentConfig[@"successActionConfig"] = mutableActionConfig;
    [self storeMutableBranchConfig:parentConfig success:success];
}

- (void)storeRecognitionResultUseMatchPoint:(BOOL)useMatchPoint forBranchSuccess:(BOOL)success {
    NSMutableDictionary *config = [[self branchPointActionConfigForSuccess:success] mutableCopy];
    config[@"useMatchPoint"] = @(useMatchPoint);
    [self storeBranchPointActionConfig:config success:success];
    [self notifyModelChanged];
    [self reloadForm];
}

- (void)storeRecognitionResultPointText:(NSString *)text forBranchSuccess:(BOOL)success {
    CGPoint point = CGPointZero;
    if (![self pointFromText:text point:&point]) {
        return;
    }
    NSMutableDictionary *config = [[self branchPointActionConfigForSuccess:success] mutableCopy];
    config[@"point"] = [NSValue valueWithCGPoint:point];
    config[@"useMatchPoint"] = @NO;
    [self storeBranchPointActionConfig:config success:success];
}

- (void)storeRecognitionResultLongPressText:(NSString *)text forBranchSuccess:(BOOL)success {
    NSMutableDictionary *config = [[self branchPointActionConfigForSuccess:success] mutableCopy];
    NSTimeInterval duration = MAX(0.0, text.doubleValue / 1000.0);
    config[@"pressDuration"] = @(duration);
    config[@"pressDurationMs"] = @(MAX(0, text.integerValue));
    [self storeBranchPointActionConfig:config success:success];
}

- (void)setRecognitionResultActionMode:(AnClickActionMode)mode forBranchSuccess:(BOOL)success {
    if (![self recognitionResultActionModeCanInlineConfigure:mode]) {
        mode = AnClickActionModeTap;
    }
    NSMutableDictionary *config = [self mutableBranchConfigForSuccess:success];
    AnClickActionMode previous = [self recognitionResultActionModeForBranchSuccess:success];
    config[@"imageActionMode"] = @(mode);
    if (previous != mode) {
        [config removeObjectForKey:@"successActionConfig"];
        if (mode == AnClickActionModeDelay) {
            config[@"successActionConfig"] = [self draftBranchConfigForMode:mode];
        } else if (mode == AnClickActionModeNetwork) {
            NSMutableDictionary *childConfig = [[self draftBranchConfigForMode:mode] mutableCopy];
            childConfig[@"networkRequestOnly"] = @YES;
            config[@"successActionConfig"] = childConfig;
        } else if (mode == AnClickActionModeSwipe) {
            config[@"successActionConfig"] = [self draftBranchConfigForMode:mode];
        } else if ([self branchActionModeCanUseRecognitionPoint:mode]) {
            NSMutableDictionary *childConfig = [[self draftBranchConfigForMode:mode] mutableCopy];
            childConfig[@"useMatchPoint"] = @(success);
            config[@"successActionConfig"] = childConfig;
        }
    }
    [self storeMutableBranchConfig:config success:success];
    [self notifyModelChanged];
    [self reloadForm];
}

- (NSDictionary *)draftBranchConfigForMode:(AnClickActionMode)mode {
    if (mode == AnClickActionModeNone || mode == AnClickActionModeJump) {
        return @{};
    }
    NSMutableDictionary *config = [@{
        @"mode": @(mode),
        @"repeat": @1,
        @"interval": @(1.0 / 240.0),
        @"imageActionMode": @(AnClickActionModeTap),
        @"failureActionMode": @(AnClickActionModeNone),
        @"useMatchPoint": @YES,
    } mutableCopy];
    if (mode == AnClickActionModeDelay) {
        config[@"delay"] = @0.50;
    } else if (mode == AnClickActionModeNetwork) {
        config[@"networkMethod"] = @"GET";
        config[@"networkRequestOnly"] = @YES;
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
            NSMutableDictionary *config = [[self draftBranchConfigForMode:mode] mutableCopy];
            if (self.model.actionMode == AnClickActionModeNetwork &&
                [self branchActionModeCanUseRecognitionPoint:mode]) {
                config[@"useMatchPoint"] = @NO;
            }
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
            NSMutableDictionary *config = [[self draftBranchConfigForMode:mode] mutableCopy];
            if ([self branchActionModeCanUseRecognitionPoint:mode]) {
                config[@"useMatchPoint"] = @NO;
            }
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
    BOOL judgementMode = recognitionMode || mode == AnClickActionModeNetwork;
    AnClickActionMode successActionMode = self.model.successActionMode;
    AnClickActionMode failureActionMode = self.model.failureActionMode;
    AnClickActionMode successInlineMode = [self branchPointActionModeForSuccess:YES];
    AnClickActionMode failureInlineMode = [self branchPointActionModeForSuccess:NO];

    switch (kind) {
        case ACEditorRowKindActionGrid:
            return YES;
        case ACEditorRowKindCoordinate:
            return basicPointMode;
        case ACEditorRowKindSwipeStart:
        case ACEditorRowKindSwipeEnd:
            return mode == AnClickActionModeSwipe;
        case ACEditorRowKindRecognitionClickTargetMode:
            return NO;
        case ACEditorRowKindPointPick:
            return basicPointMode || mode == AnClickActionModeSwipe;
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
            return NO;
        case ACEditorRowKindOCRMatchMode:
        case ACEditorRowKindOCRText:
        case ACEditorRowKindOCRSimilarity:
            return mode == AnClickActionModeOCR;
        case ACEditorRowKindNetworkURL:
        case ACEditorRowKindNetworkMethod:
        case ACEditorRowKindNetworkRequestMode:
        case ACEditorRowKindNetworkTimeout:
            return mode == AnClickActionModeNetwork;
        case ACEditorRowKindNetworkHeaders:
            return NO;
        case ACEditorRowKindNetworkRetryMode:
        case ACEditorRowKindNetworkRetryLimit:
        case ACEditorRowKindNetworkContains:
        case ACEditorRowKindNetworkFalse:
            return mode == AnClickActionModeNetwork && !self.model.networkRequestOnly;
        case ACEditorRowKindNetworkBody:
            return NO;
        case ACEditorRowKindNetworkAddPostPair:
            return mode == AnClickActionModeNetwork &&
                [[self.model.networkMethod uppercaseString] isEqualToString:@"POST"];
        case ACEditorRowKindNetworkPostPairBase:
            return mode == AnClickActionModeNetwork &&
                [[self.model.networkMethod uppercaseString] isEqualToString:@"POST"] &&
                self.model.networkPostPairs.count > 0;
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
            return recognitionMode;
        case ACEditorRowKindSuccessActionMode:
        case ACEditorRowKindFailureActionMode:
            return judgementMode;
        case ACEditorRowKindSuccessActionConfig:
            return judgementMode && (self.model.successActionMode == AnClickActionModeImage ||
                self.model.successActionMode == AnClickActionModeColor);
        case ACEditorRowKindFailureActionConfig:
            return judgementMode && (self.model.failureActionMode == AnClickActionModeImage ||
                self.model.failureActionMode == AnClickActionModeColor);
        case ACEditorRowKindSuccessRecognitionResultActionMode:
            return judgementMode && [self branchSelectedActionIsRecognitionForSuccess:YES];
        case ACEditorRowKindFailureRecognitionResultActionMode:
            return judgementMode && [self branchSelectedActionIsRecognitionForSuccess:NO];
        case ACEditorRowKindSuccessRecognitionResultClickTargetMode:
            return [self branchPointTargetModeRowAvailableForSuccess:YES recognitionMode:judgementMode];
        case ACEditorRowKindFailureRecognitionResultClickTargetMode:
            return [self branchPointTargetModeRowAvailableForSuccess:NO recognitionMode:judgementMode];
        case ACEditorRowKindSuccessRecognitionResultCoordinate:
            if ([self branchPointActionModeForSuccess:YES] == AnClickActionModeTwoFingerTap) {
                return NO;
            }
            return [self branchPointRowsAvailableForSuccess:YES judgementMode:judgementMode] &&
                ![self recognitionResultUsesMatchPointForBranchSuccess:YES];
        case ACEditorRowKindFailureRecognitionResultCoordinate:
            if ([self branchPointActionModeForSuccess:NO] == AnClickActionModeTwoFingerTap) {
                return NO;
            }
            return [self branchPointRowsAvailableForSuccess:NO judgementMode:judgementMode] &&
                ![self recognitionResultUsesMatchPointForBranchSuccess:NO];
        case ACEditorRowKindSuccessRecognitionResultPointPick:
            return [self shouldShowRowForKind:ACEditorRowKindSuccessRecognitionResultCoordinate];
        case ACEditorRowKindFailureRecognitionResultPointPick:
            return [self shouldShowRowForKind:ACEditorRowKindFailureRecognitionResultCoordinate];
        case ACEditorRowKindSuccessRecognitionResultLongPress:
            return [self branchPointRowsAvailableForSuccess:YES judgementMode:judgementMode] &&
                [self branchPointActionModeForSuccess:YES] == AnClickActionModeLongPress;
        case ACEditorRowKindFailureRecognitionResultLongPress:
            return [self branchPointRowsAvailableForSuccess:NO judgementMode:judgementMode] &&
                [self branchPointActionModeForSuccess:NO] == AnClickActionModeLongPress;
        case ACEditorRowKindSuccessBranchMultiPointSummary:
        case ACEditorRowKindSuccessBranchMultiPointAdd:
            return judgementMode && [self branchPointActionModeForSuccess:YES] == AnClickActionModeTwoFingerTap;
        case ACEditorRowKindFailureBranchMultiPointSummary:
        case ACEditorRowKindFailureBranchMultiPointAdd:
            return judgementMode && [self branchPointActionModeForSuccess:NO] == AnClickActionModeTwoFingerTap;
        case ACEditorRowKindSuccessBranchMultiPointClear:
            return judgementMode &&
                [self branchPointActionModeForSuccess:YES] == AnClickActionModeTwoFingerTap &&
                [self branchMultiPointsForSuccess:YES].count > 0;
        case ACEditorRowKindFailureBranchMultiPointClear:
            return judgementMode &&
                [self branchPointActionModeForSuccess:NO] == AnClickActionModeTwoFingerTap &&
                [self branchMultiPointsForSuccess:NO].count > 0;
        case ACEditorRowKindSuccessBranchSwipeStart:
        case ACEditorRowKindSuccessBranchSwipeEnd:
        case ACEditorRowKindSuccessBranchSwipeDuration:
        case ACEditorRowKindSuccessBranchSwipeStep:
            return judgementMode && successInlineMode == AnClickActionModeSwipe;
        case ACEditorRowKindFailureBranchSwipeStart:
        case ACEditorRowKindFailureBranchSwipeEnd:
        case ACEditorRowKindFailureBranchSwipeDuration:
        case ACEditorRowKindFailureBranchSwipeStep:
            return judgementMode && failureInlineMode == AnClickActionModeSwipe;
        case ACEditorRowKindSuccessBranchNetworkURL:
        case ACEditorRowKindSuccessBranchNetworkMethod:
        case ACEditorRowKindSuccessBranchNetworkRequestMode:
        case ACEditorRowKindSuccessBranchNetworkTimeout:
            return judgementMode && successInlineMode == AnClickActionModeNetwork;
        case ACEditorRowKindSuccessBranchNetworkAddPostPair:
            return judgementMode &&
                successInlineMode == AnClickActionModeNetwork &&
                [[self branchInlineStringValueForSuccess:YES key:@"networkMethod"] uppercaseString].length > 0 &&
                [[[self branchInlineStringValueForSuccess:YES key:@"networkMethod"] uppercaseString] isEqualToString:@"POST"];
        case ACEditorRowKindSuccessBranchNetworkHeaders:
            return NO;
        case ACEditorRowKindSuccessBranchNetworkBody:
            return NO;
        case ACEditorRowKindSuccessBranchNetworkPostPairBase:
            return judgementMode &&
                successInlineMode == AnClickActionModeNetwork &&
                [[[self branchInlineStringValueForSuccess:YES key:@"networkMethod"] uppercaseString] isEqualToString:@"POST"] &&
                [self branchNetworkPostPairsForSuccess:YES].count > 0;
        case ACEditorRowKindSuccessBranchNetworkContains:
        case ACEditorRowKindSuccessBranchNetworkFalse:
            return judgementMode &&
                successInlineMode == AnClickActionModeNetwork &&
                ![self branchInlineBoolValueForSuccess:YES key:@"networkRequestOnly" defaultValue:YES];
        case ACEditorRowKindFailureBranchNetworkURL:
        case ACEditorRowKindFailureBranchNetworkMethod:
        case ACEditorRowKindFailureBranchNetworkRequestMode:
        case ACEditorRowKindFailureBranchNetworkTimeout:
            return judgementMode && failureInlineMode == AnClickActionModeNetwork;
        case ACEditorRowKindFailureBranchNetworkAddPostPair:
            return judgementMode &&
                failureInlineMode == AnClickActionModeNetwork &&
                [[[self branchInlineStringValueForSuccess:NO key:@"networkMethod"] uppercaseString] isEqualToString:@"POST"];
        case ACEditorRowKindFailureBranchNetworkHeaders:
            return NO;
        case ACEditorRowKindFailureBranchNetworkBody:
            return NO;
        case ACEditorRowKindFailureBranchNetworkPostPairBase:
            return judgementMode &&
                failureInlineMode == AnClickActionModeNetwork &&
                [[[self branchInlineStringValueForSuccess:NO key:@"networkMethod"] uppercaseString] isEqualToString:@"POST"] &&
                [self branchNetworkPostPairsForSuccess:NO].count > 0;
        case ACEditorRowKindFailureBranchNetworkContains:
        case ACEditorRowKindFailureBranchNetworkFalse:
            return judgementMode &&
                failureInlineMode == AnClickActionModeNetwork &&
                ![self branchInlineBoolValueForSuccess:NO key:@"networkRequestOnly" defaultValue:YES];
        case ACEditorRowKindSuccessBranchDelay:
            return judgementMode && successInlineMode == AnClickActionModeDelay;
        case ACEditorRowKindFailureBranchDelay:
            return judgementMode && failureInlineMode == AnClickActionModeDelay;
        case ACEditorRowKindSuccessBranchThreshold:
            return successActionMode == AnClickActionModeImage || successActionMode == AnClickActionModeColor;
        case ACEditorRowKindFailureBranchThreshold:
            return failureActionMode == AnClickActionModeImage || failureActionMode == AnClickActionModeColor;
        case ACEditorRowKindSuccessBranchOCRText:
        case ACEditorRowKindSuccessBranchOCRSimilarity:
            return successActionMode == AnClickActionModeOCR;
        case ACEditorRowKindFailureBranchOCRText:
        case ACEditorRowKindFailureBranchOCRSimilarity:
            return failureActionMode == AnClickActionModeOCR;
        case ACEditorRowKindSuccessBranch:
            return judgementMode && (self.model.successActionMode == AnClickActionModeJump ||
                ([self branchSelectedActionIsRecognitionForSuccess:YES] &&
                 [self recognitionResultActionModeForBranchSuccess:YES] == AnClickActionModeJump));
        case ACEditorRowKindFailureBranch:
            return judgementMode && (self.model.failureActionMode == AnClickActionModeJump ||
                ([self branchSelectedActionIsRecognitionForSuccess:NO] &&
                 [self recognitionResultActionModeForBranchSuccess:NO] == AnClickActionModeJump));
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
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessRecognitionResultActionMode]) {
            [rows addObject:@(ACEditorRowKindSuccessRecognitionResultActionMode)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessRecognitionResultClickTargetMode]) {
            [rows addObject:@(ACEditorRowKindSuccessRecognitionResultClickTargetMode)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessRecognitionResultCoordinate]) {
            [rows addObject:@(ACEditorRowKindSuccessRecognitionResultCoordinate)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessRecognitionResultPointPick]) {
            [rows addObject:@(ACEditorRowKindSuccessRecognitionResultPointPick)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessRecognitionResultLongPress]) {
            [rows addObject:@(ACEditorRowKindSuccessRecognitionResultLongPress)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessBranchMultiPointSummary]) {
            [rows addObject:@(ACEditorRowKindSuccessBranchMultiPointSummary)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessBranchMultiPointAdd]) {
            [rows addObject:@(ACEditorRowKindSuccessBranchMultiPointAdd)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessBranchMultiPointClear]) {
            [rows addObject:@(ACEditorRowKindSuccessBranchMultiPointClear)];
        }
        NSArray<NSNumber *> *successInlineRows = @[
            @(ACEditorRowKindSuccessBranchSwipeStart),
            @(ACEditorRowKindSuccessBranchSwipeEnd),
            @(ACEditorRowKindSuccessBranchSwipeDuration),
            @(ACEditorRowKindSuccessBranchSwipeStep),
            @(ACEditorRowKindSuccessBranchNetworkURL),
            @(ACEditorRowKindSuccessBranchNetworkMethod),
            @(ACEditorRowKindSuccessBranchNetworkRequestMode),
            @(ACEditorRowKindSuccessBranchNetworkAddPostPair),
            @(ACEditorRowKindSuccessBranchNetworkTimeout),
            @(ACEditorRowKindSuccessBranchNetworkContains),
            @(ACEditorRowKindSuccessBranchNetworkFalse),
            @(ACEditorRowKindSuccessBranchDelay),
        ];
        for (NSNumber *rowNumber in successInlineRows) {
            if ([self shouldShowRowForKind:(ACEditorRowKind)rowNumber.integerValue]) {
                [rows addObject:rowNumber];
                if (rowNumber.integerValue == ACEditorRowKindSuccessBranchNetworkAddPostPair) {
                    [rows addObjectsFromArray:[self branchNetworkPostPairRowsForSuccess:YES]];
                }
            }
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessBranchThreshold]) {
            [rows addObject:@(ACEditorRowKindSuccessBranchThreshold)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessBranchOCRText]) {
            [rows addObject:@(ACEditorRowKindSuccessBranchOCRText)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessBranchOCRSimilarity]) {
            [rows addObject:@(ACEditorRowKindSuccessBranchOCRSimilarity)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindSuccessBranch]) {
            [rows addObject:@(ACEditorRowKindSuccessBranch)];
        }
        [rows addObject:@(ACEditorRowKindFailureActionMode)];
        if ([self shouldShowRowForKind:ACEditorRowKindFailureActionConfig]) {
            [rows addObject:@(ACEditorRowKindFailureActionConfig)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureRecognitionResultActionMode]) {
            [rows addObject:@(ACEditorRowKindFailureRecognitionResultActionMode)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureRecognitionResultClickTargetMode]) {
            [rows addObject:@(ACEditorRowKindFailureRecognitionResultClickTargetMode)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureRecognitionResultCoordinate]) {
            [rows addObject:@(ACEditorRowKindFailureRecognitionResultCoordinate)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureRecognitionResultPointPick]) {
            [rows addObject:@(ACEditorRowKindFailureRecognitionResultPointPick)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureRecognitionResultLongPress]) {
            [rows addObject:@(ACEditorRowKindFailureRecognitionResultLongPress)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureBranchMultiPointSummary]) {
            [rows addObject:@(ACEditorRowKindFailureBranchMultiPointSummary)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureBranchMultiPointAdd]) {
            [rows addObject:@(ACEditorRowKindFailureBranchMultiPointAdd)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureBranchMultiPointClear]) {
            [rows addObject:@(ACEditorRowKindFailureBranchMultiPointClear)];
        }
        NSArray<NSNumber *> *failureInlineRows = @[
            @(ACEditorRowKindFailureBranchSwipeStart),
            @(ACEditorRowKindFailureBranchSwipeEnd),
            @(ACEditorRowKindFailureBranchSwipeDuration),
            @(ACEditorRowKindFailureBranchSwipeStep),
            @(ACEditorRowKindFailureBranchNetworkURL),
            @(ACEditorRowKindFailureBranchNetworkMethod),
            @(ACEditorRowKindFailureBranchNetworkRequestMode),
            @(ACEditorRowKindFailureBranchNetworkAddPostPair),
            @(ACEditorRowKindFailureBranchNetworkTimeout),
            @(ACEditorRowKindFailureBranchNetworkContains),
            @(ACEditorRowKindFailureBranchNetworkFalse),
            @(ACEditorRowKindFailureBranchDelay),
        ];
        for (NSNumber *rowNumber in failureInlineRows) {
            if ([self shouldShowRowForKind:(ACEditorRowKind)rowNumber.integerValue]) {
                [rows addObject:rowNumber];
                if (rowNumber.integerValue == ACEditorRowKindFailureBranchNetworkAddPostPair) {
                    [rows addObjectsFromArray:[self branchNetworkPostPairRowsForSuccess:NO]];
                }
            }
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureBranchThreshold]) {
            [rows addObject:@(ACEditorRowKindFailureBranchThreshold)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureBranchOCRText]) {
            [rows addObject:@(ACEditorRowKindFailureBranchOCRText)];
        }
        if ([self shouldShowRowForKind:ACEditorRowKindFailureBranchOCRSimilarity]) {
            [rows addObject:@(ACEditorRowKindFailureBranchOCRSimilarity)];
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
        self.model.networkHeaders = ACEditorDefaultNetworkHeaders();
        self.model.networkPostBody = @"";
        self.model.networkPostPairs = @[];
        self.model.networkContains = @"";
        self.model.networkFalse = @"";
        self.model.networkRequestOnly = NO;
        self.model.networkUsesPost = NO;
        self.model.networkMethod = @"GET";
    } else if (self.model.networkHeaders.count == 0) {
        self.model.networkHeaders = ACEditorDefaultNetworkHeaders();
    } else if (!self.model.networkRequestOnly &&
               self.model.networkContains.length == 0 &&
               self.model.networkFalse.length == 0) {
        self.model.networkRequestOnly = YES;
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
        mode != AnClickActionModeColor &&
        mode != AnClickActionModeNetwork) {
        self.model.successBranchIndex = -1;
        self.model.failureBranchIndex = -1;
        self.model.successActionMode = AnClickActionModeTap;
        self.model.failureActionMode = AnClickActionModeNone;
        self.model.recognitionRetryUntilFound = NO;
    } else if (mode == AnClickActionModeNetwork) {
        self.model.successBranchIndex = -1;
        self.model.failureBranchIndex = -1;
        self.model.successActionMode = AnClickActionModeNone;
        self.model.failureActionMode = AnClickActionModeNone;
        self.model.successActionConfig = @{};
        self.model.failureActionConfig = @{};
        self.model.successRecognitionActionConfig = @{};
        self.model.failureRecognitionActionConfig = @{};
        self.model.recognitionRetryUntilFound = NO;
    } else {
        if (![self branchActionMode:self.model.successActionMode isAllowedForSuccess:YES]) {
            self.model.successActionMode = mode == AnClickActionModeNetwork ? AnClickActionModeNone : AnClickActionModeTap;
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
    if ([self isNetworkPostPairRow:row]) {
        ACEditorPostPairCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PostPair" forIndexPath:indexPath];
        [self configurePostPairCell:cell row:row];
        return cell;
    }
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
            } else if (mode == AnClickActionModeNetwork) {
                strongSelf.model.successActionMode = AnClickActionModeNone;
                strongSelf.model.failureActionMode = AnClickActionModeNone;
                strongSelf.model.successActionConfig = @{};
                strongSelf.model.failureActionConfig = @{};
                strongSelf.model.networkRequestOnly = YES;
                strongSelf.model.networkMethod = @"GET";
                strongSelf.model.networkUsesPost = NO;
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
        NSString *title = [NSString stringWithFormat:@"%@后动作：%@",
                           success ? @"成功" : @"失败",
                           [self branchActionShortTitleForMode:selectedMode]];
        [cell configureWithTitle:title
                            icon:success ? @"✓" : @"✕"
                           items:[self branchActionItemsForSuccess:success]
                    selectedMode:selectedMode];
        cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
        return cell;
    }
    if (row == ACEditorRowKindSuccessRecognitionResultActionMode ||
        row == ACEditorRowKindFailureRecognitionResultActionMode) {
        ACEditorActionChoiceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ActionChoice" forIndexPath:indexPath];
        BOOL success = row == ACEditorRowKindSuccessRecognitionResultActionMode;
        AnClickActionMode ownerMode = success ? self.model.successActionMode : self.model.failureActionMode;
        AnClickActionMode selectedMode = [self recognitionResultActionModeForBranchSuccess:success];
        __weak typeof(self) weakSelf = self;
        cell.selectionHandler = ^(AnClickActionMode mode) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf setRecognitionResultActionMode:mode forBranchSuccess:success];
        };
        NSString *role = success ? @"成功后" : @"失败后";
        NSString *title = [NSString stringWithFormat:@"%@%@命中动作：%@",
                           role,
                           [self branchActionShortTitleForMode:ownerMode],
                           [self branchActionShortTitleForMode:selectedMode]];
        [cell configureWithTitle:title
                            icon:success ? @"↳" : @"↯"
                           items:[self recognitionResultActionItems]
                    selectedMode:selectedMode];
        cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
        return cell;
    }
    if (row == ACEditorRowKindThreshold ||
        row == ACEditorRowKindOCRSimilarity ||
        row == ACEditorRowKindSuccessBranchThreshold ||
        row == ACEditorRowKindFailureBranchThreshold ||
        row == ACEditorRowKindSuccessBranchOCRSimilarity ||
        row == ACEditorRowKindFailureBranchOCRSimilarity) {
        ACEditorSliderCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Slider" forIndexPath:indexPath];
        BOOL branchSuccess = row == ACEditorRowKindSuccessBranchThreshold || row == ACEditorRowKindSuccessBranchOCRSimilarity;
        BOOL branchFailure = row == ACEditorRowKindFailureBranchThreshold || row == ACEditorRowKindFailureBranchOCRSimilarity;
        BOOL branchRow = branchSuccess || branchFailure;
        BOOL branchOCR = row == ACEditorRowKindSuccessBranchOCRSimilarity || row == ACEditorRowKindFailureBranchOCRSimilarity;
        AnClickActionMode branchMode = branchRow ? [self branchModeForSuccess:branchSuccess] : AnClickActionModeNone;
        cell.iconLabel.text = (row == ACEditorRowKindOCRSimilarity || branchOCR) ? @"🔎" : @"⚖";
        cell.iconLabel.textColor = branchSuccess ? UIColor.systemGreenColor : (branchFailure ? UIColor.systemRedColor : UIColor.labelColor);
        if (branchRow) {
            NSString *prefix = branchSuccess ? @"成功分支" : @"失败分支";
            cell.titleLabel.text = branchOCR
                ? [NSString stringWithFormat:@"%@识字相似度", prefix]
                : [NSString stringWithFormat:@"%@%@", prefix, branchMode == AnClickActionModeColor ? @"识色容差" : @"识图阈值"];
        } else {
            cell.titleLabel.text = row == ACEditorRowKindOCRSimilarity
                ? @"识字相似度"
                : (self.model.actionMode == AnClickActionModeColor ? @"相似度容差" : @"相似度阈值");
        }
        cell.slider.tag = row;
        cell.slider.minimumValue = 0.0;
        BOOL colorTolerance = branchRow ? branchMode == AnClickActionModeColor : (row == ACEditorRowKindThreshold && self.model.actionMode == AnClickActionModeColor);
        cell.slider.maximumValue = colorTolerance ? 255.0 : 1.0;
        if (branchRow) {
            double value = branchOCR
                ? [self branchDoubleValueForSuccess:branchSuccess key:@"ocrSimilarity" defaultValue:0.80]
                : [self branchDoubleValueForSuccess:branchSuccess key:(colorTolerance ? @"colorTolerance" : @"threshold") defaultValue:(colorTolerance ? 18.0 : 0.80)];
            cell.slider.value = (float)value;
            cell.valueLabel.text = colorTolerance ? [NSString stringWithFormat:@"%.0f", value] : [NSString stringWithFormat:@"%.0f%%", value * 100.0];
        } else {
            cell.slider.value = row == ACEditorRowKindOCRSimilarity
                ? (float)self.model.ocrSimilarity
                : (self.model.actionMode == AnClickActionModeColor ? (float)self.model.colorTolerance : (float)self.model.threshold);
            cell.valueLabel.text = row == ACEditorRowKindOCRSimilarity
                ? [NSString stringWithFormat:@"%.0f%%", self.model.ocrSimilarity * 100.0]
                : (self.model.actionMode == AnClickActionModeColor
                ? [NSString stringWithFormat:@"%.0f", self.model.colorTolerance]
                : [NSString stringWithFormat:@"%.0f%%", self.model.threshold * 100.0]);
        }
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
        row == ACEditorRowKindNetworkAddPostPair ||
        row == ACEditorRowKindSuccessBranchNetworkAddPostPair ||
        row == ACEditorRowKindFailureBranchNetworkAddPostPair ||
        row == ACEditorRowKindTemplate ||
        row == ACEditorRowKindMacroRecord ||
        row == ACEditorRowKindSuccessActionConfig ||
        row == ACEditorRowKindFailureActionConfig ||
        row == ACEditorRowKindSuccessRecognitionResultPointPick ||
        row == ACEditorRowKindFailureRecognitionResultPointPick ||
        row == ACEditorRowKindSuccessBranchMultiPointAdd ||
        row == ACEditorRowKindFailureBranchMultiPointAdd ||
        row == ACEditorRowKindSuccessBranchMultiPointClear ||
        row == ACEditorRowKindFailureBranchMultiPointClear ||
        row == ACEditorRowKindSingleStep ||
        row == ACEditorRowKindDelete) {
        ACEditorButtonCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Button" forIndexPath:indexPath];
        [cell.button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        cell.button.tag = row;
        cell.previewImageView.image = nil;
        cell.previewImageView.hidden = YES;
        cell.previewHeightConstraint.constant = 0.0;
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
        } else if (row == ACEditorRowKindNetworkAddPostPair) {
            title = self.model.networkPostPairs.count >= 8 ? @"JSON 参数最多 8 组" : @"+ 添加 JSON 参数";
            titleColor = self.model.networkPostPairs.count >= 8 ? UIColor.secondaryLabelColor : UIColor.systemBlueColor;
        } else if (row == ACEditorRowKindSuccessBranchNetworkAddPostPair ||
                   row == ACEditorRowKindFailureBranchNetworkAddPostPair) {
            BOOL success = row == ACEditorRowKindSuccessBranchNetworkAddPostPair;
            NSUInteger count = [self branchNetworkPostPairsForSuccess:success].count;
            title = count >= 8
                ? [NSString stringWithFormat:@"%@分支 JSON 参数最多 8 组", success ? @"成功" : @"失败"]
                : [NSString stringWithFormat:@"+ 添加%@分支 JSON 参数", success ? @"成功" : @"失败"];
            titleColor = count >= 8 ? UIColor.secondaryLabelColor : UIColor.systemBlueColor;
        } else if (row == ACEditorRowKindTemplate) {
            title = self.model.templatePath.length > 0 ? @"🖼 重新截图选择识别图像" : @"🖼 截图选择识别图像";
        } else if (row == ACEditorRowKindMacroRecord) {
            title = self.model.events.count > 0 ? @"● 重新录制动作" : @"● 开始录制动作";
        } else if (row == ACEditorRowKindSuccessActionConfig || row == ACEditorRowKindFailureActionConfig) {
            BOOL success = row == ACEditorRowKindSuccessActionConfig;
            AnClickActionMode mode = success ? self.model.successActionMode : self.model.failureActionMode;
            if (mode == AnClickActionModeImage) {
                title = [NSString stringWithFormat:@"🖼 %@后识图截图", success ? @"成功" : @"失败"];
            } else if (mode == AnClickActionModeColor) {
                title = [NSString stringWithFormat:@"🎨 %@后识色取色", success ? @"成功" : @"失败"];
            } else if (mode == AnClickActionModeOCR) {
                title = [NSString stringWithFormat:@"📝 %@后识字参数", success ? @"成功" : @"失败"];
            } else {
                title = [NSString stringWithFormat:@"%@后%@", success ? @"成功" : @"失败", [self branchActionShortTitleForMode:mode]];
            }
        } else if (row == ACEditorRowKindSuccessRecognitionResultPointPick ||
                   row == ACEditorRowKindFailureRecognitionResultPointPick) {
            BOOL success = row == ACEditorRowKindSuccessRecognitionResultPointPick;
            BOOL nestedRecognition = [self branchSelectedActionIsRecognitionForSuccess:success];
            title = [NSString stringWithFormat:@"⌖ 设置%@分支%@点击坐标",
                     success ? @"成功" : @"失败",
                     nestedRecognition ? @"命中后" : @""];
        } else if (row == ACEditorRowKindSuccessBranchMultiPointAdd ||
                   row == ACEditorRowKindFailureBranchMultiPointAdd) {
            BOOL success = row == ACEditorRowKindSuccessBranchMultiPointAdd;
            NSUInteger count = [self branchMultiPointsForSuccess:success].count;
            title = [NSString stringWithFormat:@"⌖ 添加%@分支多指触点 #%lu",
                     success ? @"成功" : @"失败",
                     (unsigned long)MIN(count + 1, ACEditorMaxMultiPoints)];
        } else if (row == ACEditorRowKindSuccessBranchMultiPointClear ||
                   row == ACEditorRowKindFailureBranchMultiPointClear) {
            title = [NSString stringWithFormat:@"清空%@分支多指触点",
                     row == ACEditorRowKindSuccessBranchMultiPointClear ? @"成功" : @"失败"];
            titleColor = UIColor.systemRedColor;
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
        NSString *previewPath = [self templatePreviewPathForButtonRow:row];
        UIImage *previewImage = previewPath.length > 0 ? [UIImage imageWithContentsOfFile:previewPath] : nil;
        if (previewImage.CGImage) {
            cell.previewImageView.image = previewImage;
            cell.previewImageView.hidden = NO;
            cell.previewHeightConstraint.constant = 96.0;
        }
        return cell;
    }
    ACEditorInputCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Input" forIndexPath:indexPath];
    [self configureInputCell:cell row:row];
    return cell;
}

- (NSString *)templatePreviewPathForButtonRow:(ACEditorRowKind)row {
    if (row == ACEditorRowKindTemplate) {
        return self.model.templatePath ?: @"";
    }
    if (row != ACEditorRowKindSuccessActionConfig &&
        row != ACEditorRowKindFailureActionConfig) {
        return @"";
    }

    BOOL success = row == ACEditorRowKindSuccessActionConfig;
    AnClickActionMode mode = success ? self.model.successActionMode : self.model.failureActionMode;
    if (mode != AnClickActionModeImage) {
        return @"";
    }
    NSDictionary *config = success ? self.model.successActionConfig : self.model.failureActionConfig;
    NSString *path = [config[@"templatePath"] isKindOfClass:NSString.class] ? config[@"templatePath"] : @"";
    if (path.length == 0) {
        NSDictionary *recognitionConfig = success ? self.model.successRecognitionActionConfig : self.model.failureRecognitionActionConfig;
        path = [recognitionConfig[@"templatePath"] isKindOfClass:NSString.class] ? recognitionConfig[@"templatePath"] : @"";
    }
    return path;
}

- (BOOL)isSegmentedRow:(ACEditorRowKind)row {
    return row == ACEditorRowKindColorMatchMode ||
        row == ACEditorRowKindRecognitionClickTargetMode ||
        row == ACEditorRowKindSuccessRecognitionResultClickTargetMode ||
        row == ACEditorRowKindFailureRecognitionResultClickTargetMode ||
        row == ACEditorRowKindOCRMatchMode ||
        row == ACEditorRowKindNetworkMethod ||
        row == ACEditorRowKindSuccessBranchNetworkMethod ||
        row == ACEditorRowKindFailureBranchNetworkMethod ||
        row == ACEditorRowKindNetworkRequestMode ||
        row == ACEditorRowKindSuccessBranchNetworkRequestMode ||
        row == ACEditorRowKindFailureBranchNetworkRequestMode ||
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
        case ACEditorRowKindSuccessRecognitionResultClickTargetMode:
        case ACEditorRowKindFailureRecognitionResultClickTargetMode: {
            BOOL success = row == ACEditorRowKindSuccessRecognitionResultClickTargetMode;
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = [self branchSelectedActionIsRecognitionForSuccess:success] ? @"命中点击位置" : @"点击位置";
            items = @[@"识别中心", @"自定义坐标"];
            selectedIndex = [self recognitionResultUsesMatchPointForBranchSuccess:success] ? 0 : 1;
            break;
        }
        case ACEditorRowKindOCRMatchMode:
            cell.iconLabel.text = @"≋";
            cell.titleLabel.text = @"匹配模式";
            items = @[@"包含", @"正则"];
            selectedIndex = self.model.ocrMatchMode == AnClickOCRMatchModeRegex ? 1 : 0;
            break;
        case ACEditorRowKindNetworkMethod:
        case ACEditorRowKindSuccessBranchNetworkMethod:
        case ACEditorRowKindFailureBranchNetworkMethod: {
            BOOL branchRow = row == ACEditorRowKindSuccessBranchNetworkMethod || row == ACEditorRowKindFailureBranchNetworkMethod;
            BOOL success = row == ACEditorRowKindSuccessBranchNetworkMethod;
            cell.iconLabel.text = @"⇄";
            cell.iconLabel.textColor = branchRow ? (success ? UIColor.systemGreenColor : UIColor.systemRedColor) : UIColor.labelColor;
            cell.titleLabel.text = branchRow
                ? [NSString stringWithFormat:@"%@分支请求方法", success ? @"成功" : @"失败"]
                : @"请求方法";
            items = @[@"GET", @"POST"];
            NSString *method = branchRow
                ? [self branchInlineStringValueForSuccess:success key:@"networkMethod"]
                : self.model.networkMethod;
            selectedIndex = [[method uppercaseString] isEqualToString:@"POST"] || (!branchRow && self.model.networkUsesPost) ? 1 : 0;
            break;
        }
        case ACEditorRowKindNetworkRequestMode:
        case ACEditorRowKindSuccessBranchNetworkRequestMode:
        case ACEditorRowKindFailureBranchNetworkRequestMode: {
            BOOL branchRow = row == ACEditorRowKindSuccessBranchNetworkRequestMode || row == ACEditorRowKindFailureBranchNetworkRequestMode;
            BOOL success = row == ACEditorRowKindSuccessBranchNetworkRequestMode;
            cell.iconLabel.text = @"☑";
            cell.iconLabel.textColor = branchRow ? (success ? UIColor.systemGreenColor : UIColor.systemRedColor) : UIColor.labelColor;
            cell.titleLabel.text = branchRow
                ? [NSString stringWithFormat:@"%@分支执行模式", success ? @"成功" : @"失败"]
                : @"执行模式";
            items = @[@"判断返回", @"仅请求"];
            BOOL requestOnly = branchRow
                ? [self branchInlineBoolValueForSuccess:success key:@"networkRequestOnly" defaultValue:YES]
                : self.model.networkRequestOnly;
            selectedIndex = requestOnly ? 1 : 0;
            break;
        }
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

- (void)configurePostPairCell:(ACEditorPostPairCell *)cell row:(ACEditorRowKind)row {
    NSUInteger index = [self networkPostPairIndexForRow:row];
    BOOL successBranch = NO;
    BOOL branchRow = [self networkPostPairRowBelongsToBranch:row success:&successBranch];
    NSArray *pairs = branchRow ? [self branchNetworkPostPairsForSuccess:successBranch] : (self.model.networkPostPairs ?: @[]);
    NSDictionary *pair = index < pairs.count && [pairs[index] isKindOfClass:NSDictionary.class] ? pairs[index] : @{};
    NSString *key = [pair[@"key"] isKindOfClass:NSString.class] ? pair[@"key"] : @"";
    BOOL useResult = [pair[@"useResult"] boolValue];
    NSString *value = useResult
        ? @"{识字结果}"
        : ([pair[@"value"] isKindOfClass:NSString.class] ? pair[@"value"] : @"");

    cell.iconLabel.text = @"＋";
    cell.iconLabel.textColor = UIColor.systemBlueColor;
    if (branchRow) {
        cell.titleLabel.text = [NSString stringWithFormat:@"%@分支 POST #%lu", successBranch ? @"成功" : @"失败", (unsigned long)index + 1];
    } else {
        cell.titleLabel.text = [NSString stringWithFormat:@"POST #%lu", (unsigned long)index + 1];
    }
    BOOL showOCRResult = self.model.actionMode == AnClickActionModeOCR;

    [cell.keyField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    [cell.valueField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    [cell.resultButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.deleteButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    cell.keyField.delegate = self;
    cell.valueField.delegate = self;
    cell.keyField.tag = row;
    cell.valueField.tag = row + ACEditorPostPairValueTagOffset;
    cell.resultButton.tag = row + ACEditorPostPairResultTagOffset;
    cell.deleteButton.tag = row + ACEditorPostPairDeleteTagOffset;
    cell.keyField.text = key;
    cell.valueField.text = value;
    cell.keyField.placeholder = @"键";
    cell.valueField.placeholder = @"值";
    cell.keyField.keyboardType = UIKeyboardTypeDefault;
    cell.valueField.keyboardType = UIKeyboardTypeDefault;
    cell.keyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    cell.valueField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    cell.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    cell.valueField.autocorrectionType = UITextAutocorrectionTypeNo;
    [cell.keyField addTarget:self action:@selector(handleTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [cell.valueField addTarget:self action:@selector(handleTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [cell.resultButton addTarget:self action:@selector(handlePostPairResultButton:) forControlEvents:UIControlEventTouchUpInside];
    [cell.deleteButton addTarget:self action:@selector(handlePostPairDeleteButton:) forControlEvents:UIControlEventTouchUpInside];
    cell.resultButton.hidden = !showOCRResult;
    cell.resultBadgeLabel.hidden = !showOCRResult;
}

- (void)configureInputCell:(ACEditorInputCell *)cell row:(ACEditorRowKind)row {
    cell.textField.delegate = self;
    cell.textField.tag = row;
    [cell.textField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged];
    [cell.textField addTarget:self action:@selector(handleTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    cell.iconLabel.text = @"";
    cell.iconLabel.textColor = UIColor.labelColor;
    cell.titleLabel.text = @"";
    cell.textField.text = @"";
    cell.textField.placeholder = nil;
    cell.swatchView.hidden = YES;
    cell.swatchView.backgroundColor = UIColor.clearColor;
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
        case ACEditorRowKindSuccessRecognitionResultCoordinate:
        case ACEditorRowKindFailureRecognitionResultCoordinate: {
            BOOL success = row == ACEditorRowKindSuccessRecognitionResultCoordinate;
            BOOL hasPoint = NO;
            CGPoint point = [self recognitionResultPointForBranchSuccess:success hasPoint:&hasPoint];
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            BOOL nestedRecognition = [self branchSelectedActionIsRecognitionForSuccess:success];
            cell.titleLabel.text = [NSString stringWithFormat:@"%@分支%@坐标",
                                    success ? @"成功" : @"失败",
                                    nestedRecognition ? @"命中后" : @""];
            cell.textField.text = hasPoint ? [self pointText:point] : @"未拾取";
            cell.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
            break;
        }
        case ACEditorRowKindSuccessBranchMultiPointSummary:
        case ACEditorRowKindFailureBranchMultiPointSummary: {
            BOOL success = row == ACEditorRowKindSuccessBranchMultiPointSummary;
            NSArray<NSValue *> *points = [self branchMultiPointsForSuccess:success];
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = [NSString stringWithFormat:@"%@分支多指触点", success ? @"成功" : @"失败"];
            if (points.count == 0) {
                cell.textField.text = @"未取点";
            } else {
                NSMutableArray<NSString *> *items = [NSMutableArray array];
                NSUInteger count = MIN(points.count, 4);
                for (NSUInteger i = 0; i < count; i++) {
                    CGPoint point = points[i].CGPointValue;
                    [items addObject:[NSString stringWithFormat:@"%.0f,%.0f", point.x, point.y]];
                }
                NSString *suffix = points.count > count ? @" ..." : @"";
                cell.textField.text = [NSString stringWithFormat:@"已取 %lu 点：%@%@",
                                       (unsigned long)points.count,
                                       [items componentsJoinedByString:@" | "],
                                       suffix];
            }
            cell.textField.enabled = NO;
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
        case ACEditorRowKindSuccessBranchSwipeStart:
        case ACEditorRowKindFailureBranchSwipeStart: {
            BOOL success = row == ACEditorRowKindSuccessBranchSwipeStart;
            NSDictionary *config = [self branchPointActionConfigForSuccess:success];
            NSArray *path = [config[@"path"] isKindOfClass:NSArray.class] ? config[@"path"] : @[];
            NSValue *value = ([path isKindOfClass:NSArray.class] && path.count > 0 && [path[0] isKindOfClass:NSValue.class]) ? path[0] : nil;
            CGPoint point = value ? value.CGPointValue : CGPointZero;
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支滑动起点" : @"失败分支滑动起点";
            cell.textField.text = value ? [self pointText:point] : @"未拾取";
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
        case ACEditorRowKindSuccessBranchSwipeEnd:
        case ACEditorRowKindFailureBranchSwipeEnd: {
            BOOL success = row == ACEditorRowKindSuccessBranchSwipeEnd;
            NSDictionary *config = [self branchPointActionConfigForSuccess:success];
            NSArray *path = [config[@"path"] isKindOfClass:NSArray.class] ? config[@"path"] : @[];
            NSValue *value = ([path isKindOfClass:NSArray.class] && path.count > 1 && [path[1] isKindOfClass:NSValue.class]) ? path[1] : nil;
            CGPoint point = value ? value.CGPointValue : CGPointZero;
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支滑动终点" : @"失败分支滑动终点";
            cell.textField.text = value ? [self pointText:point] : @"未拾取";
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
            self.model.doubleTapInterval = ACFastDoubleTapInterval;
            cell.textField.text = [NSString stringWithFormat:@"%.0f", ACFastDoubleTapInterval * 1000.0];
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
        case ACEditorRowKindSuccessBranchOCRText:
        case ACEditorRowKindFailureBranchOCRText: {
            BOOL success = row == ACEditorRowKindSuccessBranchOCRText;
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支识字文字" : @"失败分支识字文字";
            cell.textField.text = [self branchStringValueForSuccess:success key:@"ocrText"];
            break;
        }
        case ACEditorRowKindNetworkURL:
            cell.iconLabel.text = @"🌐";
            cell.titleLabel.text = @"请求地址";
            cell.textField.text = self.model.networkURL;
            cell.textField.keyboardType = UIKeyboardTypeURL;
            break;
        case ACEditorRowKindSuccessBranchNetworkURL:
        case ACEditorRowKindFailureBranchNetworkURL: {
            BOOL success = row == ACEditorRowKindSuccessBranchNetworkURL;
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支网络地址" : @"失败分支网络地址";
            cell.textField.text = [self branchInlineStringValueForSuccess:success key:@"networkURL"];
            cell.textField.keyboardType = UIKeyboardTypeURL;
            break;
        }
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
        case ACEditorRowKindSuccessBranchNetworkTimeout:
        case ACEditorRowKindFailureBranchNetworkTimeout: {
            BOOL success = row == ACEditorRowKindSuccessBranchNetworkTimeout;
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支超时时间" : @"失败分支超时时间";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", [self branchInlineDoubleValueForSuccess:success key:@"networkTimeout" defaultValue:8.0]];
            cell.textField.keyboardType = UIKeyboardTypeDecimalPad;
            cell.unitLabel.text = @"s";
            break;
        }
        case ACEditorRowKindSuccessBranchDelay:
        case ACEditorRowKindFailureBranchDelay: {
            BOOL success = row == ACEditorRowKindSuccessBranchDelay;
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支延时" : @"失败分支延时";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", [self branchInlineDoubleValueForSuccess:success key:@"delay" defaultValue:0.50] * 1000.0];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
            break;
        }
        case ACEditorRowKindNetworkContains:
            cell.iconLabel.text = @"✓";
            cell.iconLabel.textColor = UIColor.systemGreenColor;
            cell.titleLabel.text = @"成功匹配内容";
            cell.textField.text = self.model.networkContains;
            break;
        case ACEditorRowKindSuccessBranchNetworkContains:
        case ACEditorRowKindFailureBranchNetworkContains: {
            BOOL success = row == ACEditorRowKindSuccessBranchNetworkContains;
            cell.iconLabel.text = success ? @"✓" : @"✕";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支匹配成功内容" : @"失败分支匹配成功内容";
            cell.textField.text = [self branchInlineStringValueForSuccess:success key:@"networkContains"];
            break;
        }
        case ACEditorRowKindNetworkFalse:
            cell.iconLabel.text = @"✕";
            cell.iconLabel.textColor = UIColor.systemRedColor;
            cell.titleLabel.text = @"失败匹配内容";
            cell.textField.text = self.model.networkFalse;
            break;
        case ACEditorRowKindSuccessBranchNetworkFalse:
        case ACEditorRowKindFailureBranchNetworkFalse: {
            BOOL success = row == ACEditorRowKindSuccessBranchNetworkFalse;
            cell.iconLabel.text = success ? @"✓" : @"✕";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支匹配失败内容" : @"失败分支匹配失败内容";
            cell.textField.text = [self branchInlineStringValueForSuccess:success key:@"networkFalse"];
            break;
        }
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
        case ACEditorRowKindSuccessBranchSwipeDuration:
        case ACEditorRowKindFailureBranchSwipeDuration: {
            BOOL success = row == ACEditorRowKindSuccessBranchSwipeDuration;
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支滑动时长" : @"失败分支滑动时长";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", [self branchInlineDoubleValueForSuccess:success key:@"swipeDuration" defaultValue:0.30] * 1000.0];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
            break;
        }
        case ACEditorRowKindSwipeStep:
            cell.iconLabel.text = @"⋯";
            cell.titleLabel.text = @"轨迹步长";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", self.model.swipeStep];
            cell.textField.keyboardType = UIKeyboardTypeDecimalPad;
            cell.unitLabel.text = @"px";
            break;
        case ACEditorRowKindSuccessBranchSwipeStep:
        case ACEditorRowKindFailureBranchSwipeStep: {
            BOOL success = row == ACEditorRowKindSuccessBranchSwipeStep;
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功分支轨迹步长" : @"失败分支轨迹步长";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", [self branchInlineDoubleValueForSuccess:success key:@"swipeStep" defaultValue:1.0]];
            cell.textField.keyboardType = UIKeyboardTypeDecimalPad;
            cell.unitLabel.text = @"px";
            break;
        }
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
        case ACEditorRowKindSuccessRecognitionResultLongPress:
        case ACEditorRowKindFailureRecognitionResultLongPress: {
            BOOL success = row == ACEditorRowKindSuccessRecognitionResultLongPress;
            NSTimeInterval duration = [self recognitionResultLongPressDurationForBranchSuccess:success];
            cell.iconLabel.text = success ? @"↳" : @"↯";
            cell.iconLabel.textColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;
            cell.titleLabel.text = success ? @"成功命中后长按" : @"失败命中后长按";
            cell.textField.text = [NSString stringWithFormat:@"%.0f", duration * 1000.0];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.unitLabel.text = @"ms";
            break;
        }
        case ACEditorRowKindSuccessBranch:
            cell.iconLabel.text = @"✓";
            cell.iconLabel.textColor = UIColor.systemGreenColor;
            cell.titleLabel.text = [self branchSelectedActionIsRecognitionForSuccess:YES] &&
                [self recognitionResultActionModeForBranchSuccess:YES] == AnClickActionModeJump
                ? @"成功分支命中后跳转"
                : @"成功跳转任务";
            cell.textField.text = [self branchTextForSuccess:YES];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            break;
        case ACEditorRowKindFailureBranch:
            cell.iconLabel.text = @"✕";
            cell.iconLabel.textColor = UIColor.systemRedColor;
            cell.titleLabel.text = [self branchSelectedActionIsRecognitionForSuccess:NO] &&
                [self recognitionResultActionModeForBranchSuccess:NO] == AnClickActionModeJump
                ? @"失败分支命中后跳转"
                : @"失败跳转任务";
            cell.textField.text = [self branchTextForSuccess:NO];
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            break;
        default:
            break;
    }
}

- (void)handleTextFieldChanged:(UITextField *)textField {
    NSString *text = textField.text ?: @"";
    NSInteger rawTag = textField.tag;
    if ([self isNetworkPostPairValueTag:rawTag]) {
        [self updateNetworkPostPairForRow:[self networkPostPairRowForValueTag:rawTag] valueText:text];
        [self notifyModelChanged];
        return;
    }
    ACEditorRowKind rowKind = (ACEditorRowKind)textField.tag;
    if ([self isNetworkPostPairRow:rowKind]) {
        [self updateNetworkPostPairForRow:rowKind keyText:text];
        [self notifyModelChanged];
        return;
    }
    switch (rowKind) {
        case ACEditorRowKindCoordinate:
            [self updateModelPointFromText:text];
            break;
        case ACEditorRowKindSuccessRecognitionResultCoordinate:
            [self storeRecognitionResultPointText:text forBranchSuccess:YES];
            break;
        case ACEditorRowKindFailureRecognitionResultCoordinate:
            [self storeRecognitionResultPointText:text forBranchSuccess:NO];
            break;
        case ACEditorRowKindSwipeStart:
            [self updateSwipePointAtIndex:0 text:text];
            break;
        case ACEditorRowKindSuccessBranchSwipeStart:
        case ACEditorRowKindFailureBranchSwipeStart: {
            BOOL success = rowKind == ACEditorRowKindSuccessBranchSwipeStart;
            CGPoint point = CGPointZero;
            if ([self pointFromText:text point:&point]) {
                NSMutableDictionary *config = [[self branchPointActionConfigForSuccess:success] mutableCopy];
                NSArray *path = [config[@"path"] isKindOfClass:NSArray.class] ? config[@"path"] : @[];
                NSValue *end = (path.count > 1 && [path[1] isKindOfClass:NSValue.class]) ? path[1] : nil;
                config[@"path"] = end ? @[[NSValue valueWithCGPoint:point], end] : @[[NSValue valueWithCGPoint:point]];
                [self storeBranchPointActionConfig:config success:success];
            }
            break;
        }
        case ACEditorRowKindSwipeEnd:
            [self updateSwipePointAtIndex:1 text:text];
            break;
        case ACEditorRowKindSuccessBranchSwipeEnd:
        case ACEditorRowKindFailureBranchSwipeEnd: {
            BOOL success = rowKind == ACEditorRowKindSuccessBranchSwipeEnd;
            CGPoint point = CGPointZero;
            if ([self pointFromText:text point:&point]) {
                NSMutableDictionary *config = [[self branchPointActionConfigForSuccess:success] mutableCopy];
                NSArray *path = [config[@"path"] isKindOfClass:NSArray.class] ? config[@"path"] : @[];
                NSValue *start = (path.count > 0 && [path[0] isKindOfClass:NSValue.class]) ? path[0] : nil;
                config[@"path"] = start ? @[start, [NSValue valueWithCGPoint:point]] : @[[NSValue valueWithCGPoint:point]];
                [self storeBranchPointActionConfig:config success:success];
            }
            break;
        }
        case ACEditorRowKindJitter:
            self.model.jitterRadius = MIN(200.0, MAX(0.0, text.doubleValue));
            break;
        case ACEditorRowKindRepeat:
            self.model.repeatCount = MAX(1, text.integerValue);
            break;
        case ACEditorRowKindDoubleTapInterval:
            self.model.doubleTapInterval = ACFastDoubleTapInterval;
            break;
        case ACEditorRowKindColor:
            [self updateModelColorFromHex:text];
            break;
        case ACEditorRowKindOCRText:
            self.model.ocrText = text;
            break;
        case ACEditorRowKindSuccessBranchOCRText:
            [self storeBranchValue:text key:@"ocrText" success:YES];
            break;
        case ACEditorRowKindFailureBranchOCRText:
            [self storeBranchValue:text key:@"ocrText" success:NO];
            break;
        case ACEditorRowKindNetworkURL:
            self.model.networkURL = text;
            break;
        case ACEditorRowKindSuccessBranchNetworkURL:
            [self storeBranchInlineValue:text key:@"networkURL" success:YES];
            break;
        case ACEditorRowKindFailureBranchNetworkURL:
            [self storeBranchInlineValue:text key:@"networkURL" success:NO];
            break;
        case ACEditorRowKindNetworkHeaders:
            self.model.networkHeaders = [self headersFromText:text];
            break;
        case ACEditorRowKindSuccessBranchNetworkHeaders:
            [self storeBranchInlineValue:[self headersFromText:text] key:@"networkHeaders" success:YES];
            break;
        case ACEditorRowKindFailureBranchNetworkHeaders:
            [self storeBranchInlineValue:[self headersFromText:text] key:@"networkHeaders" success:NO];
            break;
        case ACEditorRowKindNetworkBody:
            self.model.networkPostBody = text;
            break;
        case ACEditorRowKindSuccessBranchNetworkBody:
            [self storeBranchInlineValue:text key:@"networkPostBody" success:YES];
            break;
        case ACEditorRowKindFailureBranchNetworkBody:
            [self storeBranchInlineValue:text key:@"networkPostBody" success:NO];
            break;
        case ACEditorRowKindNetworkRetryLimit:
            self.model.networkRetryLimit = MAX(1, text.integerValue);
            break;
        case ACEditorRowKindNetworkTimeout:
            self.model.networkTimeout = MIN(60.0, MAX(1.0, text.doubleValue));
            break;
        case ACEditorRowKindSuccessBranchNetworkTimeout:
            [self storeBranchInlineValue:@(MIN(60.0, MAX(1.0, text.doubleValue))) key:@"networkTimeout" success:YES];
            break;
        case ACEditorRowKindFailureBranchNetworkTimeout:
            [self storeBranchInlineValue:@(MIN(60.0, MAX(1.0, text.doubleValue))) key:@"networkTimeout" success:NO];
            break;
        case ACEditorRowKindNetworkContains:
            self.model.networkContains = text;
            break;
        case ACEditorRowKindSuccessBranchNetworkContains:
            [self storeBranchInlineValue:text key:@"networkContains" success:YES];
            break;
        case ACEditorRowKindFailureBranchNetworkContains:
            [self storeBranchInlineValue:text key:@"networkContains" success:NO];
            break;
        case ACEditorRowKindNetworkFalse:
            self.model.networkFalse = text;
            break;
        case ACEditorRowKindSuccessBranchNetworkFalse:
            [self storeBranchInlineValue:text key:@"networkFalse" success:YES];
            break;
        case ACEditorRowKindFailureBranchNetworkFalse:
            [self storeBranchInlineValue:text key:@"networkFalse" success:NO];
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
        case ACEditorRowKindSuccessBranchSwipeDuration:
            [self storeBranchInlineValue:@(MIN(10.0, MAX(0.05, text.doubleValue / 1000.0))) key:@"swipeDuration" success:YES];
            break;
        case ACEditorRowKindFailureBranchSwipeDuration:
            [self storeBranchInlineValue:@(MIN(10.0, MAX(0.05, text.doubleValue / 1000.0))) key:@"swipeDuration" success:NO];
            break;
        case ACEditorRowKindSwipeStep:
            self.model.swipeStep = MIN(200.0, MAX(1.0, text.doubleValue));
            break;
        case ACEditorRowKindSuccessBranchSwipeStep:
            [self storeBranchInlineValue:@(MIN(200.0, MAX(1.0, text.doubleValue))) key:@"swipeStep" success:YES];
            break;
        case ACEditorRowKindFailureBranchSwipeStep:
            [self storeBranchInlineValue:@(MIN(200.0, MAX(1.0, text.doubleValue))) key:@"swipeStep" success:NO];
            break;
        case ACEditorRowKindDelay:
            self.model.delay = MAX(0.0, text.doubleValue) / 1000.0;
            break;
        case ACEditorRowKindSuccessBranchDelay:
            [self storeBranchInlineValue:@(MAX(0.0, text.doubleValue) / 1000.0) key:@"delay" success:YES];
            break;
        case ACEditorRowKindFailureBranchDelay:
            [self storeBranchInlineValue:@(MAX(0.0, text.doubleValue) / 1000.0) key:@"delay" success:NO];
            break;
        case ACEditorRowKindInterval:
            self.model.interval = MAX(0.0, text.doubleValue) / 1000.0;
            break;
        case ACEditorRowKindLongPress:
            self.model.longPressDuration = MAX(0, text.integerValue) / 1000.0;
            break;
        case ACEditorRowKindSuccessRecognitionResultLongPress:
            [self storeRecognitionResultLongPressText:text forBranchSuccess:YES];
            break;
        case ACEditorRowKindFailureRecognitionResultLongPress:
            [self storeRecognitionResultLongPressText:text forBranchSuccess:NO];
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
    if (row == ACEditorRowKindSuccessBranchThreshold ||
        row == ACEditorRowKindFailureBranchThreshold) {
        BOOL success = row == ACEditorRowKindSuccessBranchThreshold;
        AnClickActionMode branchMode = [self branchModeForSuccess:success];
        NSString *key = branchMode == AnClickActionModeColor ? @"colorTolerance" : @"threshold";
        [self storeBranchValue:@(slider.value) key:key success:success];
    } else if (row == ACEditorRowKindSuccessBranchOCRSimilarity ||
               row == ACEditorRowKindFailureBranchOCRSimilarity) {
        [self storeBranchValue:@(slider.value)
                            key:@"ocrSimilarity"
                        success:(row == ACEditorRowKindSuccessBranchOCRSimilarity)];
    } else if (row == ACEditorRowKindOCRSimilarity) {
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
    BOOL branchColorTolerance = NO;
    if (row == ACEditorRowKindSuccessBranchThreshold || row == ACEditorRowKindFailureBranchThreshold) {
        branchColorTolerance = [self branchModeForSuccess:(row == ACEditorRowKindSuccessBranchThreshold)] == AnClickActionModeColor;
    }
    if (row == ACEditorRowKindSuccessBranchThreshold ||
        row == ACEditorRowKindFailureBranchThreshold ||
        row == ACEditorRowKindSuccessBranchOCRSimilarity ||
        row == ACEditorRowKindFailureBranchOCRSimilarity) {
        cell.valueLabel.text = branchColorTolerance
            ? [NSString stringWithFormat:@"%.0f", slider.value]
            : [NSString stringWithFormat:@"%.0f%%", slider.value * 100.0];
    } else {
        cell.valueLabel.text = row == ACEditorRowKindOCRSimilarity
            ? [NSString stringWithFormat:@"%.0f%%", self.model.ocrSimilarity * 100.0]
            : (self.model.actionMode == AnClickActionModeColor
            ? [NSString stringWithFormat:@"%.0f", self.model.colorTolerance]
            : [NSString stringWithFormat:@"%.0f%%", self.model.threshold * 100.0]);
    }
    [self notifyModelChanged];
}

- (void)handlePostPairResultButton:(UIButton *)button {
    if (![self isNetworkPostPairResultTag:button.tag]) {
        return;
    }
    ACEditorRowKind row = [self networkPostPairRowForResultTag:button.tag];
    [self updateNetworkPostPairForRow:row valueText:@"{识字结果}"];
    [self notifyModelChanged];
    [self reloadForm];
}

- (void)handlePostPairDeleteButton:(UIButton *)button {
    if (![self isNetworkPostPairDeleteTag:button.tag]) {
        return;
    }
    ACEditorRowKind row = [self networkPostPairRowForDeleteTag:button.tag];
    NSUInteger index = [self networkPostPairIndexForRow:row];
    NSMutableArray *pairs = [[self networkPostPairsForRow:row] mutableCopy] ?: [NSMutableArray array];
    if (index >= pairs.count) {
        return;
    }
    [pairs removeObjectAtIndex:index];
    [self storeNetworkPostPairs:pairs forRow:row];
    [self notifyModelChanged];
    [self reloadForm];
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
        case ACEditorRowKindSuccessRecognitionResultClickTargetMode:
            [self storeRecognitionResultUseMatchPoint:(selected != 1) forBranchSuccess:YES];
            break;
        case ACEditorRowKindFailureRecognitionResultClickTargetMode:
            [self storeRecognitionResultUseMatchPoint:(selected != 1) forBranchSuccess:NO];
            break;
        case ACEditorRowKindOCRMatchMode:
            self.model.ocrMatchMode = selected == 1 ? AnClickOCRMatchModeRegex : AnClickOCRMatchModeContains;
            break;
        case ACEditorRowKindNetworkMethod:
            self.model.networkMethod = selected == 1 ? @"POST" : @"GET";
            self.model.networkUsesPost = selected == 1;
            [self reloadForm];
            break;
        case ACEditorRowKindSuccessBranchNetworkMethod:
            [self storeBranchInlineValue:(selected == 1 ? @"POST" : @"GET") key:@"networkMethod" success:YES];
            [self reloadForm];
            break;
        case ACEditorRowKindFailureBranchNetworkMethod:
            [self storeBranchInlineValue:(selected == 1 ? @"POST" : @"GET") key:@"networkMethod" success:NO];
            [self reloadForm];
            break;
        case ACEditorRowKindNetworkRequestMode:
            self.model.networkRequestOnly = selected == 1;
            [self reloadForm];
            break;
        case ACEditorRowKindSuccessBranchNetworkRequestMode:
            [self storeBranchInlineValue:@(selected == 1) key:@"networkRequestOnly" success:YES];
            [self reloadForm];
            break;
        case ACEditorRowKindFailureBranchNetworkRequestMode:
            [self storeBranchInlineValue:@(selected == 1) key:@"networkRequestOnly" success:NO];
            [self reloadForm];
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
    [self commitActiveEditing];
    switch ((ACEditorRowKind)button.tag) {
        case ACEditorRowKindPointPick:
            [self.delegate taskEditorViewDidRequestPointPick:self];
            break;
        case ACEditorRowKindColorPick:
            [self.delegate taskEditorViewDidRequestColorPick:self];
            break;
        case ACEditorRowKindNetworkAddPostPair:
            [self addNetworkPostPairRow];
            break;
        case ACEditorRowKindSuccessBranchNetworkAddPostPair:
            [self addBranchNetworkPostPairRowForSuccess:YES];
            break;
        case ACEditorRowKindFailureBranchNetworkAddPostPair:
            [self addBranchNetworkPostPairRowForSuccess:NO];
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
        case ACEditorRowKindSuccessRecognitionResultPointPick:
            [self.delegate taskEditorView:self didRequestRecognitionResultPointPickForSuccess:YES];
            break;
        case ACEditorRowKindFailureRecognitionResultPointPick:
            [self.delegate taskEditorView:self didRequestRecognitionResultPointPickForSuccess:NO];
            break;
        case ACEditorRowKindSuccessBranchMultiPointAdd:
            [self.delegate taskEditorView:self didRequestRecognitionResultPointPickForSuccess:YES];
            break;
        case ACEditorRowKindFailureBranchMultiPointAdd:
            [self.delegate taskEditorView:self didRequestRecognitionResultPointPickForSuccess:NO];
            break;
        case ACEditorRowKindSuccessBranchMultiPointClear:
            [self clearBranchMultiPoints:YES];
            [self notifyModelChanged];
            [self reloadForm];
            break;
        case ACEditorRowKindFailureBranchMultiPointClear:
            [self clearBranchMultiPoints:NO];
            [self notifyModelChanged];
            [self reloadForm];
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
    [self commitActiveEditing];
    [self.delegate taskEditorViewDidSave:self];
}

- (void)notifyModelChanged {
    [self.delegate taskEditorView:self didUpdateModel:self.model];
}

- (void)commitActiveEditing {
    UITextField *textField = self.activeTextField;
    if ([textField isKindOfClass:UITextField.class]) {
        [self handleTextFieldChanged:textField];
    }
    [self endEditing:YES];
    [self notifyModelChanged];
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

- (void)storeNetworkPostPairs:(NSArray *)pairs forRow:(ACEditorRowKind)row {
    BOOL success = NO;
    if ([self networkPostPairRowBelongsToBranch:row success:&success]) {
        [self setBranchNetworkPostPairs:pairs success:success];
    } else {
        self.model.networkPostPairs = pairs;
    }
}

- (void)updateNetworkPostPairForRow:(ACEditorRowKind)row keyText:(NSString *)keyText {
    NSUInteger index = [self networkPostPairIndexForRow:row];
    if (index >= 8) {
        return;
    }
    NSMutableArray *pairs = [[self networkPostPairsForRow:row] mutableCopy] ?: [NSMutableArray array];
    while (pairs.count <= index) {
        [pairs addObject:@{}];
    }
    NSDictionary *oldPair = [pairs[index] isKindOfClass:NSDictionary.class] ? pairs[index] : @{};
    NSString *value = [oldPair[@"value"] isKindOfClass:NSString.class] ? oldPair[@"value"] : @"";
    BOOL useResult = [oldPair[@"useResult"] boolValue];
    pairs[index] = @{
        @"key": [keyText ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet],
        @"value": value ?: @"",
        @"useResult": @(useResult),
    };
    [self storeNetworkPostPairs:pairs forRow:row];
}

- (void)updateNetworkPostPairForRow:(ACEditorRowKind)row valueText:(NSString *)valueText {
    NSUInteger index = [self networkPostPairIndexForRow:row];
    if (index >= 8) {
        return;
    }
    NSMutableArray *pairs = [[self networkPostPairsForRow:row] mutableCopy] ?: [NSMutableArray array];
    while (pairs.count <= index) {
        [pairs addObject:@{}];
    }
    NSDictionary *oldPair = [pairs[index] isKindOfClass:NSDictionary.class] ? pairs[index] : @{};
    NSString *key = [oldPair[@"key"] isKindOfClass:NSString.class] ? oldPair[@"key"] : @"";
    NSString *value = [valueText ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *lowerValue = value.lowercaseString;
    BOOL useResult = [value isEqualToString:@"{识字结果}"] ||
        [value isEqualToString:@"{{ocr}}"] ||
        [lowerValue isEqualToString:@"$ocr"] ||
        [lowerValue isEqualToString:@"${ocr}"];
    pairs[index] = @{
        @"key": key ?: @"",
        @"value": useResult ? @"" : (value ?: @""),
        @"useResult": @(useResult),
    };
    [self storeNetworkPostPairs:pairs forRow:row];
}

- (void)addNetworkPostPairRow {
    NSMutableArray *pairs = [self.model.networkPostPairs mutableCopy] ?: [NSMutableArray array];
    if (pairs.count >= 8) {
        return;
    }
    [pairs addObject:@{@"key": @"", @"value": @"", @"useResult": @NO}];
    self.model.networkPostPairs = pairs;
    [self notifyModelChanged];
    [self reloadForm];
}

- (void)addBranchNetworkPostPairRowForSuccess:(BOOL)success {
    NSMutableArray *pairs = [[self branchNetworkPostPairsForSuccess:success] mutableCopy] ?: [NSMutableArray array];
    if (pairs.count >= 8) {
        return;
    }
    [pairs addObject:@{@"key": @"", @"value": @"", @"useResult": @NO}];
    [self setBranchNetworkPostPairs:pairs success:success];
    [self notifyModelChanged];
    [self reloadForm];
}

- (NSInteger)longPressMilliseconds {
    return MAX(0, (NSInteger)llround(self.model.longPressDuration * 1000.0));
}

- (void)setLongPressMilliseconds:(NSInteger)milliseconds {
    self.model.longPressDuration = MAX(0, milliseconds) / 1000.0;
}

- (NSString *)branchTextForSuccess:(BOOL)success {
    if ([self branchSelectedActionIsRecognitionForSuccess:success] &&
        [self recognitionResultActionModeForBranchSuccess:success] == AnClickActionModeJump) {
        NSDictionary *config = [self recognitionResultActionConfigForBranchSuccess:success];
        id value = config[@"successBranchIndex"] ?: config[@"jumpTaskIndex"] ?: config[@"targetTaskIndex"] ?: config[@"jumpTaskId"];
        NSInteger index = [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : -1;
        return index >= 0 ? [NSString stringWithFormat:@"%ld", (long)index + 1] : @"";
    }
    NSInteger index = success ? self.model.successBranchIndex : self.model.failureBranchIndex;
    return index >= 0 ? [NSString stringWithFormat:@"%ld", (long)index + 1] : @"";
}

- (void)setBranchText:(NSString *)text success:(BOOL)success {
    NSInteger number = text.integerValue;
    NSInteger index = (text.length > 0 && number > 0) ? number - 1 : -1;
    if ([self branchSelectedActionIsRecognitionForSuccess:success] &&
        [self recognitionResultActionModeForBranchSuccess:success] == AnClickActionModeJump) {
        NSMutableDictionary *config = [self recognitionResultActionConfigForBranchSuccess:success];
        config[@"mode"] = @(AnClickActionModeJump);
        if (index >= 0) {
            config[@"successBranchIndex"] = @(index);
            config[@"jumpTaskIndex"] = @(index);
        } else {
            [config removeObjectForKey:@"successBranchIndex"];
            [config removeObjectForKey:@"jumpTaskIndex"];
        }
        [self storeRecognitionResultActionConfig:config forBranchSuccess:success];
        return;
    }
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
