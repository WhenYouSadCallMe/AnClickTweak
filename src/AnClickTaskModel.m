#import "AnClickTaskModel.h"
#import <math.h>
#import <string.h>

static NSString * const ACKeyMode = @"mode";
static NSString * const ACKeyDelay = @"delay";
static NSString * const ACKeyRepeat = @"repeat";
static NSString * const ACKeyInterval = @"interval";
static const NSTimeInterval ACFastDoubleTapInterval = 0.06;
static NSString * const ACDefaultNetworkContentType = @"application/json; charset=utf-8";
static NSString * const ACDefaultNetworkUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1";

static NSDictionary *ACDefaultNetworkHeaders(void) {
    return @{
        @"Content-Type": ACDefaultNetworkContentType,
        @"Accept": @"application/json, text/plain, */*",
        @"User-Agent": ACDefaultNetworkUserAgent,
    };
}
static NSString * const ACKeyRandomDelay = @"randomDelay";
static NSString * const ACKeyJitterRadius = @"jitterRadius";
static NSString * const ACKeyDescription = @"desc";
static NSString * const ACKeyExpanded = @"isExpanded";

static double ACClampedDouble(id value, double minimum, double maximum, double defaultValue) {
    if (![value respondsToSelector:@selector(doubleValue)]) {
        return defaultValue;
    }
    double result = [value doubleValue];
    if (!isfinite(result)) {
        return defaultValue;
    }
    return MIN(maximum, MAX(minimum, result));
}

static NSInteger ACClampedInteger(id value, NSInteger minimum, NSInteger maximum, NSInteger defaultValue) {
    if (![value respondsToSelector:@selector(integerValue)]) {
        return defaultValue;
    }
    return MIN(maximum, MAX(minimum, [value integerValue]));
}

static NSString *ACStringValue(id value) {
    return [value isKindOfClass:NSString.class] ? [value copy] : @"";
}

static NSDictionary *ACDictionaryValue(id value) {
    return [value isKindOfClass:NSDictionary.class] ? [value copy] : @{};
}

static NSArray *ACArrayValue(id value) {
    return [value isKindOfClass:NSArray.class] ? [value copy] : @[];
}

static NSValue *ACValueWithCGPoint(CGPoint point) {
    return [NSValue valueWithBytes:&point objCType:@encode(CGPoint)];
}

static BOOL ACNSValueGetCGPoint(NSValue *value, CGPoint *point) {
    if (![value isKindOfClass:NSValue.class] || !point || strcmp(value.objCType, @encode(CGPoint)) != 0) {
        return NO;
    }
    [value getValue:point];
    return YES;
}

static BOOL ACNSValueGetCGRect(NSValue *value, CGRect *rect) {
    if (![value isKindOfClass:NSValue.class] || !rect || strcmp(value.objCType, @encode(CGRect)) != 0) {
        return NO;
    }
    [value getValue:rect];
    return YES;
}

static AnClickActionMode ACSupportedActionMode(id value) {
    if (![value respondsToSelector:@selector(integerValue)]) {
        return AnClickActionModeNone;
    }

    AnClickActionMode mode = (AnClickActionMode)[value integerValue];
    switch (mode) {
        case AnClickActionModeTap:
        case AnClickActionModeDoubleTap:
        case AnClickActionModeLongPress:
        case AnClickActionModeSwipe:
        case AnClickActionModeTwoFingerTap:
        case AnClickActionModeImage:
        case AnClickActionModeMacro:
        case AnClickActionModeOCR:
        case AnClickActionModeColor:
        case AnClickActionModeNetwork:
        case AnClickActionModeJump:
        case AnClickActionModeDelay:
        case AnClickActionModeOpenApp:
            return mode;
        default:
            return AnClickActionModeNone;
    }
}

static NSValue *ACValueObject(id value) {
    return [value isKindOfClass:NSValue.class] ? value : nil;
}

static BOOL ACCGRectFromObject(id object, CGRect *rect) {
    if (ACNSValueGetCGRect(object, rect)) {
        return YES;
    }
    if ([object isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = object;
        id x = dictionary[@"x"] ?: dictionary[@"left"];
        id y = dictionary[@"y"] ?: dictionary[@"top"];
        id width = dictionary[@"width"] ?: dictionary[@"w"];
        id height = dictionary[@"height"] ?: dictionary[@"h"];
        if ([x respondsToSelector:@selector(doubleValue)] &&
            [y respondsToSelector:@selector(doubleValue)] &&
            [width respondsToSelector:@selector(doubleValue)] &&
            [height respondsToSelector:@selector(doubleValue)]) {
            *rect = CGRectMake([x doubleValue], [y doubleValue], [width doubleValue], [height doubleValue]);
            return YES;
        }
    }
    return NO;
}

static BOOL ACCGPointFromObject(id object, CGPoint *point) {
    if (ACNSValueGetCGPoint(object, point)) {
        return YES;
    }
    if ([object isKindOfClass:NSDictionary.class]) {
        NSDictionary *dictionary = object;
        id x = dictionary[@"x"] ?: dictionary[@"dx"];
        id y = dictionary[@"y"] ?: dictionary[@"dy"];
        if ([x respondsToSelector:@selector(doubleValue)] &&
            [y respondsToSelector:@selector(doubleValue)]) {
            *point = CGPointMake([x doubleValue], [y doubleValue]);
            return YES;
        }
    }
    return NO;
}

@implementation AnClickTaskModel

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _actionMode = AnClickActionModeNone;
        _delay = 0.0;
        _repeatCount = 1;
        _interval = 1.0 / 240.0;
        _taskDescription = @"";
        _doubleTapInterval = ACFastDoubleTapInterval;
        _longPressDuration = 0.50;
        _swipeDuration = 0.30;
        _swipeStep = 12.0;
        _templatePath = @"";
        _useMatchPoint = YES;
        _successActionMode = AnClickActionModeTap;
        _failureActionMode = AnClickActionModeNone;
        _threshold = 0.80;
        _ocrMode = AnClickOCRModeAppleVision;
        _ocrMatchMode = AnClickOCRMatchModeContains;
        _ocrText = @"";
        _ocrSimilarity = 0.80;
        _colorTolerance = 18.0;
        _colorMatchMode = 0;
        _networkURL = @"";
        _networkMethod = @"GET";
        _networkHeaders = ACDefaultNetworkHeaders();
        _networkRequestOnly = YES;
        _networkRetryForever = YES;
        _networkRetryLimit = 1;
        _networkTimeout = 8.0;
        _networkContains = @"";
        _networkFalse = @"";
        _networkPostBody = @"";
        _networkPostExtraFields = @"";
        _jumpTaskIndex = -1;
        _targetBundleID = @"";
        _macroSpeed = 1.0;
        _recognitionRetryUntilFound = NO;
        _recognitionRetryInterval = 1.0;
        _successBranchIndex = -1;
        _failureBranchIndex = -1;
        _successActionConfig = @{};
        _failureActionConfig = @{};
        _successRecognitionActionConfig = @{};
        _failureRecognitionActionConfig = @{};
        _path = @[];
        _multiPoints = @[];
        _events = @[];
        _colorPoints = @[];
        _networkPostPairs = @[];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (!self || ![dictionary isKindOfClass:NSDictionary.class]) {
        return self;
    }

    _actionMode = ACSupportedActionMode(dictionary[ACKeyMode]);
    _delay = ACClampedDouble(dictionary[ACKeyDelay], 0.0, 3600.0, 0.0);
    _repeatCount = ACClampedInteger(dictionary[ACKeyRepeat], 1, 9999, 1);
    _interval = ACClampedDouble(dictionary[ACKeyInterval], 0.0, 30.0, _interval);
    _randomDelay = [dictionary[ACKeyRandomDelay] boolValue];
    _jitterRadius = ACClampedDouble(dictionary[ACKeyJitterRadius], 0.0, 200.0, 0.0);
    _taskDescription = ACStringValue(dictionary[ACKeyDescription]);
    _expanded = [dictionary[ACKeyExpanded] boolValue];

    _doubleTapInterval = ACFastDoubleTapInterval;
    _longPressDuration = ACClampedDouble(dictionary[@"pressDuration"], 0.0, 10.0, _longPressDuration);
    if ([dictionary[@"pressDurationMs"] respondsToSelector:@selector(doubleValue)]) {
        _longPressDuration = ACClampedDouble(dictionary[@"pressDurationMs"], 0.0, 10000.0, _longPressDuration * 1000.0) / 1000.0;
    }
    _swipeDuration = ACClampedDouble(dictionary[@"swipeDuration"], 0.05, 10.0, _swipeDuration);
    _swipeStep = ACClampedDouble(dictionary[@"swipeStep"], 1.0, 200.0, _swipeStep);

    _templatePath = ACStringValue(dictionary[@"templatePath"]);
    _useMatchPoint = dictionary[@"useMatchPoint"] ? [dictionary[@"useMatchPoint"] boolValue] : YES;
    BOOL hasExplicitSuccessActionMode = dictionary[@"imageActionMode"] != nil;
    BOOL hasExplicitFailureActionMode = dictionary[@"failureActionMode"] != nil;
    _successActionMode = ACSupportedActionMode(dictionary[@"imageActionMode"]);
    if (_successActionMode == AnClickActionModeNone && _actionMode != AnClickActionModeNetwork) {
        _successActionMode = AnClickActionModeTap;
    }
    _failureActionMode = ACSupportedActionMode(dictionary[@"failureActionMode"]);
    _threshold = ACClampedDouble(dictionary[@"threshold"], 0.0, 1.0, 0.80);
    CGRect roi = CGRectZero;
    _hasTemplateROI = ACCGRectFromObject(dictionary[@"templateROI"] ?: dictionary[@"roi"], &roi);
    _templateROI = _hasTemplateROI ? roi : CGRectZero;
    CGPoint offset = CGPointZero;
    _hasMatchClickOffset = ACCGPointFromObject(dictionary[@"matchClickOffset"] ?: dictionary[@"clickOffset"], &offset);
    _matchClickOffset = _hasMatchClickOffset ? offset : CGPointZero;

    _ocrMode = AnClickOCRModeAppleVision;
    _ocrMatchMode = [dictionary[@"ocrMatchMode"] respondsToSelector:@selector(integerValue)] ? (AnClickOCRMatchMode)[dictionary[@"ocrMatchMode"] integerValue] : AnClickOCRMatchModeContains;
    if (_ocrMatchMode != AnClickOCRMatchModeRegex) {
        _ocrMatchMode = AnClickOCRMatchModeContains;
    }
    _ocrText = ACStringValue(dictionary[@"ocrText"]);
    _ocrSimilarity = ACClampedDouble(dictionary[@"ocrSimilarity"], 0.0, 1.0, 0.80);

    _colorRed = ACClampedInteger(dictionary[@"colorRed"], 0, 255, 0);
    _colorGreen = ACClampedInteger(dictionary[@"colorGreen"], 0, 255, 0);
    _colorBlue = ACClampedInteger(dictionary[@"colorBlue"], 0, 255, 0);
    _colorTolerance = ACClampedDouble(dictionary[@"colorTolerance"], 0.0, 255.0, 18.0);
    _colorMatchMode = ACClampedInteger(dictionary[@"colorMatchMode"], 0, 1, 0);

    _networkURL = ACStringValue(dictionary[@"networkURL"]);
    _networkMethod = ACStringValue(dictionary[@"networkMethod"]).length > 0 ? [ACStringValue(dictionary[@"networkMethod"]) uppercaseString] : @"GET";
    NSDictionary *headers = ACDictionaryValue(dictionary[@"networkHeaders"]);
    _networkHeaders = headers.count > 0 ? headers : ACDefaultNetworkHeaders();
    BOOL hasExplicitNetworkRequestOnly = dictionary[@"networkRequestOnly"] != nil;
    _networkRequestOnly = hasExplicitNetworkRequestOnly ? [dictionary[@"networkRequestOnly"] boolValue] : YES;
    _networkUsesPost = [dictionary[@"networkUsesPost"] boolValue];
    _networkRetryForever = dictionary[@"networkRetryForever"] ? [dictionary[@"networkRetryForever"] boolValue] : YES;
    _networkRetryLimit = ACClampedInteger(dictionary[@"networkRetryLimit"], 1, 9999, 1);
    _networkTimeout = ACClampedDouble(dictionary[@"networkTimeout"], 1.0, 60.0, 8.0);
    _networkContains = ACStringValue(dictionary[@"networkContains"]);
    _networkFalse = ACStringValue(dictionary[@"networkFalse"]);
    if (!hasExplicitNetworkRequestOnly) {
        _networkRequestOnly = (_networkContains.length == 0 && _networkFalse.length == 0);
    }
    _networkPostBody = ACStringValue(dictionary[@"networkPostBody"]);
    _networkPostBodyUsesOCRResult = [dictionary[@"networkPostBodyUsesOCRResult"] boolValue];
    _networkPostExtraFields = ACStringValue(dictionary[@"networkPostExtraFields"]);

    id jumpValue = dictionary[@"jumpTaskIndex"] ?: dictionary[@"jumpTaskId"] ?: dictionary[@"targetTaskIndex"];
    _jumpTaskIndex = ACClampedInteger(jumpValue, -1, NSIntegerMax, -1);
    _targetBundleID = ACStringValue(dictionary[@"targetBundleID"] ?: dictionary[@"bundleID"] ?: dictionary[@"applicationBundleID"]);

    _macroSpeed = ACClampedDouble(dictionary[@"macroSpeed"], 0.1, 10.0, 1.0);

    _recognitionRetryUntilFound = [dictionary[@"recognitionRetryUntilFound"] boolValue];
    _recognitionRetryInterval = ACClampedDouble(dictionary[@"recognitionRetryInterval"], 0.2, 30.0, 1.0);
    _successBranchIndex = ACClampedInteger(dictionary[@"successBranchIndex"], -1, NSIntegerMax, -1);
    _failureBranchIndex = ACClampedInteger(dictionary[@"failureBranchIndex"], -1, NSIntegerMax, -1);
    if (!hasExplicitSuccessActionMode && _successBranchIndex >= 0) {
        _successActionMode = AnClickActionModeJump;
    }
    if (!hasExplicitFailureActionMode && _failureBranchIndex >= 0) {
        _failureActionMode = AnClickActionModeJump;
    }
    _successActionConfig = ACDictionaryValue(dictionary[@"successActionConfig"]);
    _failureActionConfig = ACDictionaryValue(dictionary[@"failureActionConfig"]);
    _successRecognitionActionConfig = ACDictionaryValue(dictionary[@"successRecognitionActionConfig"]);
    _failureRecognitionActionConfig = ACDictionaryValue(dictionary[@"failureRecognitionActionConfig"]);

    _point = ACValueObject(dictionary[@"point"]);
    _pointScreenSize = ACValueObject(dictionary[@"pointScreenSize"]);
    _successPoint = ACValueObject(dictionary[@"successPoint"]);
    _successPointScreenSize = ACValueObject(dictionary[@"successPointScreenSize"]);
    _failurePoint = ACValueObject(dictionary[@"failurePoint"]);
    _failurePointScreenSize = ACValueObject(dictionary[@"failurePointScreenSize"]);
    _pathScreenSize = ACValueObject(dictionary[@"pathScreenSize"]);
    _multiPointScreenSize = ACValueObject(dictionary[@"multiPointScreenSize"]);
    _eventsScreenSize = ACValueObject(dictionary[@"eventsScreenSize"]);
    _colorPointScreenSize = ACValueObject(dictionary[@"colorPointScreenSize"]);
    _path = ACArrayValue(dictionary[@"path"]);
    _multiPoints = ACArrayValue(dictionary[@"multiPoints"]);
    _events = ACArrayValue(dictionary[@"events"]);
    _colorPoints = ACArrayValue(dictionary[@"colorPoints"]);
    _networkPostPairs = ACArrayValue(dictionary[@"networkPostPairs"]);
    if (!_point && _colorPoints.count > 0) {
        NSDictionary *anchor = [_colorPoints.firstObject isKindOfClass:NSDictionary.class] ? _colorPoints.firstObject : nil;
        if ([anchor[@"x"] respondsToSelector:@selector(doubleValue)] &&
            [anchor[@"y"] respondsToSelector:@selector(doubleValue)]) {
            _point = ACValueWithCGPoint(CGPointMake([anchor[@"x"] doubleValue], [anchor[@"y"] doubleValue]));
            if (!_pointScreenSize && _colorPointScreenSize) {
                _pointScreenSize = _colorPointScreenSize;
            }
        }
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[self dictionaryRepresentation] forKey:@"dictionary"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSSet *classes = [NSSet setWithObjects:
        NSDictionary.class,
        NSMutableDictionary.class,
        NSArray.class,
        NSMutableArray.class,
        NSString.class,
        NSNumber.class,
        NSValue.class,
        nil];
    NSDictionary *dictionary = [coder decodeObjectOfClasses:classes forKey:@"dictionary"];
    return [self initWithDictionary:dictionary ?: @{}];
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithDictionary:[self dictionaryRepresentation]];
}

- (NSMutableDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    AnClickActionMode actionMode = ACSupportedActionMode(@(self.actionMode));
    AnClickActionMode successActionMode = ACSupportedActionMode(@(self.successActionMode));
    AnClickActionMode failureActionMode = ACSupportedActionMode(@(self.failureActionMode));
    if (successActionMode == AnClickActionModeNone && actionMode != AnClickActionModeNetwork) {
        successActionMode = AnClickActionModeTap;
    }
    dictionary[ACKeyMode] = @(actionMode);
    dictionary[ACKeyDelay] = @(actionMode == AnClickActionModeDelay ? MAX(0.0, self.delay) : 0.0);
    dictionary[ACKeyRepeat] = @(MAX(1, self.repeatCount));
    dictionary[ACKeyInterval] = @((actionMode == AnClickActionModeTap || actionMode == AnClickActionModeTwoFingerTap)
        ? MIN(30.0, MAX(0.0, self.interval))
        : 0.0);
    dictionary[ACKeyExpanded] = @(self.expanded);
    if (self.randomDelay) {
        dictionary[ACKeyRandomDelay] = @YES;
    }
    if (self.jitterRadius > 0.001) {
        dictionary[ACKeyJitterRadius] = @(MIN(200.0, MAX(0.0, self.jitterRadius)));
    }
    if (self.taskDescription.length > 0) {
        dictionary[ACKeyDescription] = self.taskDescription;
    }
    dictionary[@"doubleTapInterval"] = @(ACFastDoubleTapInterval);
    dictionary[@"pressDurationMs"] = @((NSInteger)llround(MIN(10.0, MAX(0.0, self.longPressDuration)) * 1000.0));
    dictionary[@"pressDuration"] = @(MIN(10.0, MAX(0.0, self.longPressDuration)));
    dictionary[@"swipeDuration"] = @(MIN(10.0, MAX(0.05, self.swipeDuration)));
    dictionary[@"swipeStep"] = @(MIN(200.0, MAX(1.0, self.swipeStep)));
    if (self.templatePath.length > 0) {
        dictionary[@"templatePath"] = self.templatePath;
    }
    dictionary[@"useMatchPoint"] = @(self.useMatchPoint);
    dictionary[@"imageActionMode"] = @(successActionMode);
    dictionary[@"failureActionMode"] = @(failureActionMode);
    dictionary[@"threshold"] = @(MIN(1.0, MAX(0.0, self.threshold)));
    dictionary[@"ocrMode"] = @(self.ocrMode);
    dictionary[@"ocrMatchMode"] = @(self.ocrMatchMode);
    if (self.ocrText.length > 0) {
        dictionary[@"ocrText"] = self.ocrText;
    }
    dictionary[@"ocrSimilarity"] = @(MIN(1.0, MAX(0.0, self.ocrSimilarity)));
    dictionary[@"colorTolerance"] = @(MIN(255.0, MAX(0.0, self.colorTolerance)));
    dictionary[@"colorMatchMode"] = @(MIN(1, MAX(0, self.colorMatchMode)));
    if (actionMode == AnClickActionModeColor ||
        self.colorPoints.count > 0 ||
        self.colorRed || self.colorGreen || self.colorBlue) {
        dictionary[@"colorRed"] = @(MIN(255, MAX(0, self.colorRed)));
        dictionary[@"colorGreen"] = @(MIN(255, MAX(0, self.colorGreen)));
        dictionary[@"colorBlue"] = @(MIN(255, MAX(0, self.colorBlue)));
    }
    if (actionMode == AnClickActionModeColor &&
        self.colorPoints.count == 0 &&
        self.point &&
        self.useMatchPoint) {
        CGPoint point = CGPointZero;
        if (!ACNSValueGetCGPoint(self.point, &point)) {
            point = CGPointZero;
        }
        dictionary[@"colorPoints"] = @[@{
            @"x": @(point.x),
            @"y": @(point.y),
            @"dx": @0.0,
            @"dy": @0.0,
            @"red": @(MIN(255, MAX(0, self.colorRed))),
            @"green": @(MIN(255, MAX(0, self.colorGreen))),
            @"blue": @(MIN(255, MAX(0, self.colorBlue))),
        }];
        if (self.pointScreenSize) {
            dictionary[@"colorPointScreenSize"] = self.pointScreenSize;
        }
    }
    if (self.networkURL.length > 0) {
        dictionary[@"networkURL"] = self.networkURL;
    }
    NSString *method = self.networkMethod.length > 0 ? [self.networkMethod uppercaseString] : (self.networkUsesPost ? @"POST" : @"GET");
    dictionary[@"networkMethod"] = [method isEqualToString:@"POST"] ? @"POST" : @"GET";
    if (actionMode == AnClickActionModeNetwork && self.networkHeaders.count > 0) {
        dictionary[@"networkHeaders"] = self.networkHeaders;
    }
    dictionary[@"networkRequestOnly"] = @(self.networkRequestOnly);
    dictionary[@"networkUsesPost"] = @([[dictionary objectForKey:@"networkMethod"] isEqualToString:@"POST"] || self.networkUsesPost);
    dictionary[@"networkRetryForever"] = @(self.networkRetryForever);
    dictionary[@"networkRetryLimit"] = @(MAX(1, self.networkRetryLimit));
    dictionary[@"networkTimeout"] = @(MIN(60.0, MAX(1.0, self.networkTimeout)));
    if (self.networkContains.length > 0) {
        dictionary[@"networkContains"] = self.networkContains;
    }
    if (self.networkFalse.length > 0) {
        dictionary[@"networkFalse"] = self.networkFalse;
    }
    dictionary[@"networkPostBodyUsesOCRResult"] = @(self.networkPostBodyUsesOCRResult);
    if (self.networkPostExtraFields.length > 0) {
        dictionary[@"networkPostExtraFields"] = self.networkPostExtraFields;
    }
    if (self.jumpTaskIndex >= 0) {
        dictionary[@"jumpTaskIndex"] = @(self.jumpTaskIndex);
    }
    if (self.targetBundleID.length > 0) {
        dictionary[@"targetBundleID"] = self.targetBundleID;
    }
    dictionary[@"macroSpeed"] = @(MIN(10.0, MAX(0.1, self.macroSpeed)));
    dictionary[@"recognitionRetryUntilFound"] = @(self.recognitionRetryUntilFound);
    dictionary[@"recognitionRetryInterval"] = @(MIN(30.0, MAX(0.2, self.recognitionRetryInterval)));
    if (self.successBranchIndex >= 0) dictionary[@"successBranchIndex"] = @(self.successBranchIndex);
    if (self.failureBranchIndex >= 0) dictionary[@"failureBranchIndex"] = @(self.failureBranchIndex);
    if (self.successActionConfig.count > 0) dictionary[@"successActionConfig"] = self.successActionConfig;
    if (self.failureActionConfig.count > 0) dictionary[@"failureActionConfig"] = self.failureActionConfig;
    if (self.successRecognitionActionConfig.count > 0) dictionary[@"successRecognitionActionConfig"] = self.successRecognitionActionConfig;
    if (self.failureRecognitionActionConfig.count > 0) dictionary[@"failureRecognitionActionConfig"] = self.failureRecognitionActionConfig;

    if (self.point) dictionary[@"point"] = self.point;
    if (self.pointScreenSize) dictionary[@"pointScreenSize"] = self.pointScreenSize;
    if (self.successPoint) dictionary[@"successPoint"] = self.successPoint;
    if (self.successPointScreenSize) dictionary[@"successPointScreenSize"] = self.successPointScreenSize;
    if (self.failurePoint) dictionary[@"failurePoint"] = self.failurePoint;
    if (self.failurePointScreenSize) dictionary[@"failurePointScreenSize"] = self.failurePointScreenSize;
    if (self.pathScreenSize) dictionary[@"pathScreenSize"] = self.pathScreenSize;
    if (self.multiPointScreenSize) dictionary[@"multiPointScreenSize"] = self.multiPointScreenSize;
    if (self.eventsScreenSize) dictionary[@"eventsScreenSize"] = self.eventsScreenSize;
    if (self.colorPointScreenSize) dictionary[@"colorPointScreenSize"] = self.colorPointScreenSize;
    if (self.path.count > 0) dictionary[@"path"] = self.path;
    if (self.multiPoints.count > 0) dictionary[@"multiPoints"] = self.multiPoints;
    if (self.events.count > 0) dictionary[@"events"] = self.events;
    if (self.colorPoints.count > 0) dictionary[@"colorPoints"] = self.colorPoints;
    if (self.networkPostPairs.count > 0) dictionary[@"networkPostPairs"] = self.networkPostPairs;
    return dictionary;
}

+ (NSArray<AnClickTaskModel *> *)modelsFromDictionaries:(NSArray *)tasks {
    NSMutableArray<AnClickTaskModel *> *models = [NSMutableArray array];
    for (id task in tasks) {
        if ([task isKindOfClass:AnClickTaskModel.class]) {
            [models addObject:task];
        } else if ([task isKindOfClass:NSDictionary.class]) {
            [models addObject:[[AnClickTaskModel alloc] initWithDictionary:task]];
        }
    }
    return models;
}

+ (NSArray<NSDictionary *> *)dictionariesFromModels:(NSArray<AnClickTaskModel *> *)models {
    NSMutableArray<NSDictionary *> *tasks = [NSMutableArray array];
    for (id model in models) {
        if ([model isKindOfClass:AnClickTaskModel.class]) {
            [tasks addObject:[model dictionaryRepresentation]];
        } else if ([model isKindOfClass:NSDictionary.class]) {
            [tasks addObject:model];
        }
    }
    return tasks;
}

@end
