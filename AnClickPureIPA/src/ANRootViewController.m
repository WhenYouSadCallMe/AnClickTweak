#import "ANRootViewController.h"
#import "ANTaskRunner.h"
#import "ANSystemTouch.h"

@interface ANRootViewController () <UITextViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) ANTaskRunner *runner;
@property (nonatomic, strong) UITextView *taskTextView;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UITextField *delayField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *runButton;
@property (nonatomic, strong) UIButton *stopButton;
@end

@implementation ANRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"安姐连点器v1.0";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.075 alpha:1.0];
    self.runner = [[ANTaskRunner alloc] init];
    __weak typeof(self) weakSelf = self;
    self.runner.logBlock = ^(NSString *message) {
        [weakSelf appendLog:message];
    };
    self.runner.stateBlock = ^(BOOL running) {
        [weakSelf updateRunningState:running];
    };
    [self buildUI];
    [self loadTasksFromDisk];
    [self appendLog:[ANSystemTouch systemTouchAvailable] ? @"系统 HID 可用" : @"系统 HID 不可用，请检查 TrollStore 权限"];
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    button.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.16 alpha:1.0];
    button.layer.cornerRadius = 7;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (void)styleTextView:(UITextView *)textView {
    textView.backgroundColor = [UIColor colorWithRed:0.045 green:0.045 blue:0.04 alpha:1.0];
    textView.textColor = UIColor.whiteColor;
    textView.tintColor = [UIColor colorWithRed:0.94 green:0.64 blue:0.23 alpha:1.0];
    textView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    textView.layer.cornerRadius = 7;
    textView.layer.borderWidth = 1;
    textView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
}

- (void)buildUI {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];

    UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stack];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.text = @"待机";
    self.statusLabel.textColor = UIColor.whiteColor;
    self.statusLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.statusLabel.numberOfLines = 0;
    [stack addArrangedSubview:self.statusLabel];

    UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    hintLabel.text = @"纯 IPA 版：点击运行后按延时切到目标 App，任务会按 JSON 执行。";
    hintLabel.textColor = [UIColor colorWithWhite:1 alpha:0.68];
    hintLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    hintLabel.numberOfLines = 0;
    [stack addArrangedSubview:hintLabel];

    UIStackView *delayRow = [[UIStackView alloc] initWithFrame:CGRectZero];
    delayRow.axis = UILayoutConstraintAxisHorizontal;
    delayRow.spacing = 8;
    delayRow.alignment = UIStackViewAlignmentCenter;
    [stack addArrangedSubview:delayRow];

    UILabel *delayLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    delayLabel.text = @"开始延时";
    delayLabel.textColor = UIColor.whiteColor;
    delayLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [delayRow addArrangedSubview:delayLabel];

    self.delayField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.delayField.text = @"3";
    self.delayField.keyboardType = UIKeyboardTypeDecimalPad;
    self.delayField.textColor = UIColor.whiteColor;
    self.delayField.tintColor = [UIColor colorWithRed:0.94 green:0.64 blue:0.23 alpha:1.0];
    self.delayField.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightBold];
    self.delayField.backgroundColor = [UIColor colorWithRed:0.045 green:0.045 blue:0.04 alpha:1.0];
    self.delayField.layer.cornerRadius = 6;
    self.delayField.layer.borderWidth = 1;
    self.delayField.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    self.delayField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    self.delayField.leftViewMode = UITextFieldViewModeAlways;
    self.delayField.translatesAutoresizingMaskIntoConstraints = NO;
    [delayRow addArrangedSubview:self.delayField];
    [self.delayField.widthAnchor constraintEqualToConstant:86].active = YES;

    UILabel *secondLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    secondLabel.text = @"秒";
    secondLabel.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    secondLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [delayRow addArrangedSubview:secondLabel];

    UIStackView *buttonRow = [[UIStackView alloc] initWithFrame:CGRectZero];
    buttonRow.axis = UILayoutConstraintAxisHorizontal;
    buttonRow.spacing = 8;
    buttonRow.distribution = UIStackViewDistributionFillEqually;
    [stack addArrangedSubview:buttonRow];

    self.runButton = [self buttonWithTitle:@"运行" action:@selector(runTasks)];
    self.runButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.62 blue:0.28 alpha:1.0];
    [buttonRow addArrangedSubview:self.runButton];
    self.stopButton = [self buttonWithTitle:@"停止" action:@selector(stopTasks)];
    self.stopButton.backgroundColor = [UIColor colorWithRed:0.72 green:0.13 blue:0.10 alpha:1.0];
    [buttonRow addArrangedSubview:self.stopButton];
    [buttonRow addArrangedSubview:[self buttonWithTitle:@"保存" action:@selector(saveTasksToDisk)]];
    [buttonRow addArrangedSubview:[self buttonWithTitle:@"示例" action:@selector(fillSampleTasks)]];

    UILabel *taskLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    taskLabel.text = @"任务 JSON";
    taskLabel.textColor = UIColor.whiteColor;
    taskLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [stack addArrangedSubview:taskLabel];

    self.taskTextView = [[UITextView alloc] initWithFrame:CGRectZero];
    [self styleTextView:self.taskTextView];
    [stack addArrangedSubview:self.taskTextView];
    [self.taskTextView.heightAnchor constraintGreaterThanOrEqualToConstant:300].active = YES;

    UILabel *logLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    logLabel.text = @"运行日志";
    logLabel.textColor = UIColor.whiteColor;
    logLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [stack addArrangedSubview:logLabel];

    self.logTextView = [[UITextView alloc] initWithFrame:CGRectZero];
    [self styleTextView:self.logTextView];
    self.logTextView.editable = NO;
    [stack addArrangedSubview:self.logTextView];
    [self.logTextView.heightAnchor constraintGreaterThanOrEqualToConstant:180].active = YES;

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-12],
        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-16],
        [stack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-24],
    ]];
}

- (NSString *)tasksPath {
    NSURL *documentsURL = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[documentsURL path] stringByAppendingPathComponent:@"pure_ipa_tasks.json"];
}

- (void)fillSampleTasks {
    self.taskTextView.text = [self sampleJSON];
    [self appendLog:@"已填入示例任务"];
}

- (NSString *)sampleJSON {
    return @"[\n"
        "  {\n"
        "    \"mode\": \"network\",\n"
        "    \"url\": \"http://49.235.153.44:27890/get_status_anclick\",\n"
        "    \"method\": \"GET\",\n"
        "    \"contains\": \"true\",\n"
        "    \"blockContains\": \"false\",\n"
        "    \"timeout\": 5,\n"
        "    \"retryLimit\": 1\n"
        "  },\n"
        "  {\n"
        "    \"mode\": \"tap\",\n"
        "    \"x\": 180,\n"
        "    \"y\": 420,\n"
        "    \"delay\": 0.2\n"
        "  },\n"
        "  {\n"
        "    \"mode\": \"ocr\",\n"
        "    \"text\": \"资金安全\",\n"
        "    \"action\": \"tap\",\n"
        "    \"delay\": 0.1\n"
        "  }\n"
        "]";
}

- (void)loadTasksFromDisk {
    NSString *path = [self tasksPath];
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    self.taskTextView.text = text.length > 0 ? text : [self sampleJSON];
}

- (void)saveTasksToDisk {
    NSError *error = nil;
    BOOL ok = [self.taskTextView.text writeToFile:[self tasksPath] atomically:YES encoding:NSUTF8StringEncoding error:&error];
    [self appendLog:ok ? @"任务已保存" : [NSString stringWithFormat:@"保存失败：%@", error.localizedDescription ?: @"未知错误"]];
}

- (NSArray<NSDictionary *> *)parsedTasks {
    NSData *data = [self.taskTextView.text dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length == 0) {
        [self appendLog:@"任务 JSON 为空"];
        return @[];
    }
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![object isKindOfClass:NSArray.class]) {
        [self appendLog:[NSString stringWithFormat:@"JSON 解析失败：%@", error.localizedDescription ?: @"需要数组"]];
        return @[];
    }
    NSMutableArray<NSDictionary *> *tasks = [NSMutableArray array];
    for (id item in (NSArray *)object) {
        if ([item isKindOfClass:NSDictionary.class]) {
            [tasks addObject:item];
        }
    }
    return tasks;
}

- (void)runTasks {
    [self.view endEditing:YES];
    NSArray<NSDictionary *> *tasks = [self parsedTasks];
    if (tasks.count == 0) {
        return;
    }
    NSTimeInterval delay = MAX(0.0, self.delayField.text.doubleValue);
    [self.runner startWithTasks:tasks startDelay:delay];
}

- (void)stopTasks {
    [self.runner stop];
}

- (void)updateRunningState:(BOOL)running {
    self.statusLabel.text = running ? @"运行中" : @"待机";
    self.runButton.enabled = !running;
    self.runButton.alpha = running ? 0.5 : 1.0;
}

- (void)appendLog:(NSString *)message {
    if (message.length == 0) {
        return;
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [formatter stringFromDate:NSDate.date], message];
    NSString *oldText = self.logTextView.text ?: @"";
    self.logTextView.text = [oldText stringByAppendingString:line];
    NSRange bottom = NSMakeRange(MAX((NSUInteger)0, self.logTextView.text.length), 0);
    [self.logTextView scrollRangeToVisible:bottom];
}

@end
