#import "ANRootViewController.h"
#import "ANLauncherInstaller.h"

static CFStringRef const ANLauncherShowNotification = CFSTR("com.anclick.launcher.show");
static CFStringRef const ANLauncherExpandNotification = CFSTR("com.anclick.launcher.expand");
static CFStringRef const ANLauncherRunNotification = CFSTR("com.anclick.launcher.run");
static CFStringRef const ANLauncherStopNotification = CFSTR("com.anclick.launcher.stop");

@interface ANRootViewController ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, assign) BOOL didAutoLoadPanel;
@end

@implementation ANRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"安姐连点器v1.0";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.075 alpha:1.0];
    [self buildUI];
    [self refreshInstallStatus];
    [self appendLog:@"IPA 会加载内置 AnClick.dylib 并显示同款悬浮窗；要在任意界面使用，需要安装到注入目录并重启界面。"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.didAutoLoadPanel) {
        return;
    }
    self.didAutoLoadPanel = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self loadBundledDylib];
    });
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action color:(UIColor *)color {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.72;
    button.backgroundColor = color ?: [UIColor colorWithRed:0.18 green:0.18 blue:0.16 alpha:1.0];
    button.layer.cornerRadius = 7;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.heightAnchor constraintEqualToConstant:44].active = YES;
    return button;
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font alpha:(CGFloat)alpha {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.textColor = [UIColor colorWithWhite:1 alpha:alpha];
    label.font = font;
    label.numberOfLines = 0;
    return label;
}

- (UIStackView *)buttonRowWithButtons:(NSArray<UIButton *> *)buttons {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.distribution = UIStackViewDistributionFillEqually;
    return row;
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

    self.statusLabel = [self labelWithText:@"检查中" font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] alpha:0.95];
    self.statusLabel.backgroundColor = [UIColor colorWithRed:0.045 green:0.045 blue:0.04 alpha:1.0];
    self.statusLabel.layer.cornerRadius = 7;
    self.statusLabel.layer.borderWidth = 1;
    self.statusLabel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    self.statusLabel.layer.masksToBounds = YES;
    [stack addArrangedSubview:self.statusLabel];
    [self.statusLabel.heightAnchor constraintGreaterThanOrEqualToConstant:74].active = YES;

    UILabel *hintLabel = [self labelWithText:@"打开 IPA 会先显示当前进程同款悬浮窗。要去任意 App 或系统界面使用，需要先安装/更新 dylib，再重启界面，让 SpringBoard 和目标 App 重新加载。"
                                        font:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular]
                                       alpha:0.70];
    [stack addArrangedSubview:hintLabel];

    UIButton *loadButton = [self buttonWithTitle:@"加载悬浮窗"
                                          action:@selector(loadBundledDylib)
                                           color:[UIColor colorWithRed:0.12 green:0.55 blue:0.82 alpha:1.0]];
    UIButton *installButton = [self buttonWithTitle:@"安装/更新dylib"
                                             action:@selector(installBundledDylib)
                                              color:[UIColor colorWithRed:0.86 green:0.55 blue:0.16 alpha:1.0]];
    [stack addArrangedSubview:[self buttonRowWithButtons:@[loadButton, installButton]]];

    UIButton *restartButton = [self buttonWithTitle:@"重启界面"
                                             action:@selector(restartSpringBoard)
                                              color:[UIColor colorWithRed:0.72 green:0.13 blue:0.10 alpha:1.0]];
    [stack addArrangedSubview:restartButton];

    UIButton *refreshButton = [self buttonWithTitle:@"刷新状态"
                                             action:@selector(refreshInstallStatus)
                                              color:[UIColor colorWithRed:0.18 green:0.18 blue:0.16 alpha:1.0]];

    UIButton *showButton = [self buttonWithTitle:@"显示同款"
                                          action:@selector(showFloatingPanel)
                                           color:[UIColor colorWithRed:0.12 green:0.55 blue:0.82 alpha:1.0]];
    UIButton *expandButton = [self buttonWithTitle:@"展开配置"
                                            action:@selector(postExpandCommand)
                                             color:[UIColor colorWithRed:0.30 green:0.42 blue:0.86 alpha:1.0]];
    [stack addArrangedSubview:[self buttonRowWithButtons:@[refreshButton, showButton, expandButton]]];

    UIButton *runButton = [self buttonWithTitle:@"播放任务"
                                         action:@selector(postRunCommand)
                                          color:[UIColor colorWithRed:0.12 green:0.62 blue:0.28 alpha:1.0]];
    UIButton *stopButton = [self buttonWithTitle:@"停止任务"
                                          action:@selector(postStopCommand)
                                           color:[UIColor colorWithRed:0.72 green:0.13 blue:0.10 alpha:1.0]];
    [stack addArrangedSubview:[self buttonRowWithButtons:@[runButton, stopButton]]];

    UILabel *logLabel = [self labelWithText:@"运行日志" font:[UIFont systemFontOfSize:15 weight:UIFontWeightBold] alpha:0.95];
    [stack addArrangedSubview:logLabel];

    self.logTextView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.logTextView.backgroundColor = [UIColor colorWithRed:0.045 green:0.045 blue:0.04 alpha:1.0];
    self.logTextView.textColor = UIColor.whiteColor;
    self.logTextView.tintColor = [UIColor colorWithRed:0.94 green:0.64 blue:0.23 alpha:1.0];
    self.logTextView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.logTextView.layer.cornerRadius = 7;
    self.logTextView.layer.borderWidth = 1;
    self.logTextView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    self.logTextView.editable = NO;
    [stack addArrangedSubview:self.logTextView];
    [self.logTextView.heightAnchor constraintGreaterThanOrEqualToConstant:260].active = YES;

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

- (void)loadBundledDylib {
    __weak typeof(self) weakSelf = self;
    BOOL loaded = [ANLauncherInstaller showLoadedPanelWithLog:^(NSString *message) {
        [weakSelf appendLog:message];
    }];
    [self refreshInstallStatus];
    if (loaded) {
        [self appendLog:@"IPA 内同款悬浮窗已唤起"];
    }
}

- (void)installBundledDylib {
    __weak typeof(self) weakSelf = self;
    BOOL installed = [ANLauncherInstaller installBundledDylibWithLog:^(NSString *message) {
        [weakSelf appendLog:message];
    }];
    [self refreshInstallStatus];
    [self appendLog:installed ? @"安装/更新完成，请点击重启界面后去目标 App 使用" : @"安装/更新未完成"];
}

- (void)restartSpringBoard {
    __weak typeof(self) weakSelf = self;
    BOOL restarted = [ANLauncherInstaller restartSpringBoardWithLog:^(NSString *message) {
        [weakSelf appendLog:message];
    }];
    [self appendLog:restarted ? @"已发送重启界面请求，稍等系统界面重载" : @"重启界面未执行，请手动 respring 或重启目标 App"];
}

- (void)refreshInstallStatus {
    self.statusLabel.text = [NSString stringWithFormat:@" %@ ", [ANLauncherInstaller installedStatusText]];
}

- (void)postLauncherNotification:(CFStringRef)name title:(NSString *)title {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         name,
                                         NULL,
                                         NULL,
                                         true);
    [self appendLog:[NSString stringWithFormat:@"已发送：%@", title]];
}

- (void)showFloatingPanel {
    [self loadBundledDylib];
    [self postShowCommand];
}

- (void)postShowCommand {
    [ANLauncherInstaller showLoadedPanelWithLog:nil];
    [self postLauncherNotification:ANLauncherShowNotification title:@"显示悬浮窗"];
}

- (void)postExpandCommand {
    [ANLauncherInstaller showLoadedPanelWithLog:nil];
    [self postLauncherNotification:ANLauncherExpandNotification title:@"展开配置"];
}

- (void)postRunCommand {
    [ANLauncherInstaller showLoadedPanelWithLog:nil];
    [self postLauncherNotification:ANLauncherRunNotification title:@"播放任务"];
}

- (void)postStopCommand {
    [ANLauncherInstaller showLoadedPanelWithLog:nil];
    [self postLauncherNotification:ANLauncherStopNotification title:@"停止任务"];
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
    NSRange bottom = NSMakeRange(self.logTextView.text.length, 0);
    [self.logTextView scrollRangeToVisible:bottom];
}

@end
