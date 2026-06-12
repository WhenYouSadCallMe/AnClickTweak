#import "AnClickTaskModel.h"
#import <math.h>

static NSString * const ACKeyMode = @"mode";
static NSString * const ACKeyDelay = @"delay";
static NSString * const ACKeyRepeat = @"repeat";
static NSString * const ACKeyInterval = @"interval";
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

static NSValue *ACValueObject(id value) {
    return [value isKindOfClass:NSValue.class] ? value : nil;
}

static BOOL ACCGRectFromObject(id object, CGRect *rect) {
    if ([object isKindOfClass:NSValue.class]) {
        *rect = [object CGRectValue];
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
    if ([object isKindOfClass:NSValue.class]) {
        *point = [object CGPointValue];
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
        _interval = 0.03;
        _pressure = 1.0;
        _taskDescription = @"";
        _doubleTapInterval = 0.10;
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
        _networkHeaders = @{};
        _networkRetryForever = YES;
        _networkRetryLimit = 1;
        _networkTimeout = 8.0;
        _networkContains = @"";
        _networkFalse = @"";
        _networkPostBody = @"";
        _networkPostExtraFields = @"";
        _jumpTaskIndex = -1;
        _macroPath = @"";
        _macroArguments = @"";
        _macroSpeed = 1.0;
        _gestureFromDistance = 168.0;
        _gestureToDistance = 58.0;
        _gestureRadius = 64.0;
        _rotationStartAngle = -45.0;
        _rotationEndAngle = 135.0;
        _gestureDuration = 0.30;
        _recognitionRetryUntilFound = NO;
        _recognitionRetryInterval = 1.0;
        _successBranchIndex = -1;
        _failureBranchIndex = -1;
        _successActionTaskIndex = -1;
        _failureActionTaskIndex = -1;
        _successActionConfig = @{};
        _failureActionConfig = @{};
        _successRecognitionActionConfig = @{};
        _failureRecognitionActionConfig = @{};
        _path = @[];
        _multiPoints = @[];
        _events = @[];
        _colorPoints = @[];
        _networkPostPairs = @[];
        _extraFields = @{};
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (!self || ![dictionary isKindOfClass:NSDictionary.class]) {
        return self;
    }

    _actionMode = [dictionary[ACKeyMode] respondsToSelector:@selector(integerValue)] ? (AnClickActionMode)[dictionary[ACKeyMode] integerValue] : AnClickActionModeNone;
    _delay = ACClampedDouble(dictionary[ACKeyDelay], 0.0, 3600.0, 0.0);
    _repeatCount = ACClampedInteger(dictionary[ACKeyRepeat], 1, 9999, 1);
    _interval = ACClampedDouble(dictionary[ACKeyInterval], 0.0, 30.0, _interval);
    _randomDelay = [dictionary[ACKeyRandomDelay] boolValue];
    _jitterRadius = ACClampedDouble(dictionary[ACKeyJitterRadius], 0.0, 200.0, 0.0);
    _pressure = ACClampedDouble(dictionary[@"pressure"], 0.0, 1.0, 1.0);
    _taskDescription = ACStringValue(dictionary[ACKeyDescription]);
    _expanded = [dictionary[ACKeyExpanded] boolValue];

    _doubleTapInterval = ACClampedDouble(dictionary[@"doubleTapInterval"], 0.02, 2.0, _doubleTapInterval);
    _longPressDuration = ACClampedDouble(dictionary[@"pressDuration"], 0.0, 10.0, _longPressDuration);
    if ([dictionary[@"pressDurationMs"] respondsToSelector:@selector(doubleValue)]) {
        _longPressDuration = ACClampedDouble(dictionary[@"pressDurationMs"], 0.0, 10000.0, _longPressDuration * 1000.0) / 1000.0;
    }
    _swipeDuration = ACClampedDouble(dictionary[@"swipeDuration"], 0.05, 10.0, _swipeDuration);
    _swipeStep = ACClampedDouble(dictionary[@"swipeStep"], 1.0, 200.0, _swipeStep);

    _templatePath = ACStringValue(dictionary[@"templatePath"]);
    _useMatchPoint = dictionary[@"useMatchPoint"] ? [dictionary[@"useMatchPoint"] boolValue] : YES;
    _successActionMode = [dictionary[@"imageActionMode"] respondsToSelector:@selector(integerValue)] ? (AnClickActionMode)[dictionary[@"imageActionMode"] integerValue] : AnClickActionModeTap;
    _failureActionMode = [dictionary[@"failureActionMode"] respondsToSelector:@selector(integerValue)] ? (AnClickActionMode)[dictionary[@"failureActionMode"] integerValue] : AnClickActionModeNone;
    _threshold = ACClampedDouble(dictionary[@"threshold"], 0.0, 1.0, 0.80);
    CGRect roi = CGRectZero;
    _hasTemplateROI = ACCGRectFromObject(dictionary[@"templateROI"] ?: dictionary[@"roi"], &roi);
    _templateROI = _hasTemplateROI ? roi : CGRectZero;
    CGPoint offset = CGPointZero;
    _hasMatchClickOffset = ACCGPointFromObject(dictionary[@"matchClickOffset"] ?: dictionary[@"clickOffset"], &offset);
    _matchClickOffset = _hasMatchClickOffset ? offset : CGPointZero;

    _ocrMode = [dictionary[@"ocrMode"] respondsToSelector:@selector(integerValue)] ? (AnClickOCRMode)[dictionary[@"ocrMode"] integerValue] : AnClickOCRModeAppleVision;
    _ocrMatchMode = [dictionary[@"ocrMatchMode"] respondsToSelector:@selector(integerValue)] ? (AnClickOCRMatchMode)[dictionary[@"ocrMatchMode"] integerValue] : AnClickOCRMatchModeContains;
    _ocrText = ACStringValue(dictionary[@"ocrText"]);
    _ocrSimilarity = ACClampedDouble(dictionary[@"ocrSimilarity"], 0.0, 1.0, 0.80);

    _colorRed = ACClampedInteger(dictionary[@"colorRed"], 0, 255, 0);
    _colorGreen = ACClampedInteger(dictionary[@"colorGreen"], 0, 255, 0);
    _colorBlue = ACClampedInteger(dictionary[@"colorBlue"], 0, 255, 0);
    _colorTolerance = ACClampedDouble(dictionary[@"colorTolerance"], 0.0, 255.0, 18.0);
    _colorMatchMode = ACClampedInteger(dictionary[@"colorMatchMode"], 0, 1, 0);

    _networkURL = ACStringValue(dictionary[@"networkURL"]);
    _networkMethod = ACStringValue(dictionary[@"networkMethod"]).length > 0 ? [ACStringValue(dictionary[@"networkMethod"]) uppercaseString] : @"GET";
    _networkHeaders = ACDictionaryValue(dictionary[@"networkHeaders"]);
    _networkRequestOnly = [dictionary[@"networkRequestOnly"] boolValue];
    _networkUsesPost = [dictionary[@"networkUsesPost"] boolValue];
    _networkRetryForever = dictionary[@"networkRetryForever"] ? [dictionary[@"networkRetryForever"] boolValue] : YES;
    _networkRetryLimit = ACClampedInteger(dictionary[@"networkRetryLimit"], 1, 9999, 1);
    _networkTimeout = ACClampedDouble(dictionary[@"networkTimeout"], 1.0, 60.0, 8.0);
    _networkContains = ACStringValue(dictionary[@"networkContains"]);
    _networkFalse = ACStringValue(dictionary[@"networkFalse"]);
    _networkPostBody = ACStringValue(dictionary[@"networkPostBody"]);
    _networkPostBodyUsesOCRResult = [dictionary[@"networkPostBodyUsesOCRResult"] boolValue];
    _networkPostExtraFields = ACStringValue(dictionary[@"networkPostExtraFields"]);

    id jumpValue = dictionary[@"jumpTaskIndex"] ?: dictionary[@"jumpTaskId"] ?: dictionary[@"targetTaskIndex"];
    _jumpTaskIndex = ACClampedInteger(jumpValue, -1, NSIntegerMax, -1);

    _macroPath = ACStringValue(dictionary[@"macroPath"]);
    _macroArguments = ACStringValue(dictionary[@"macroArguments"]);
    _macroSpeed = ACClampedDouble(dictionary[@"macroSpeed"], 0.1, 10.0, 1.0);

    _gestureFromDistance = ACClampedDouble(dictionary[@"gestureFromDistance"], 1.0, 1000.0, _gestureFromDistance);
    _gestureToDistance = ACClampedDouble(dictionary[@"gestureToDistance"], 1.0, 1000.0, _gestureToDistance);
    _gestureRadius = ACClampedDouble(dictionary[@"gestureRadius"], 1.0, 1000.0, _gestureRadius);
    _rotationStartAngle = ACClampedDouble(dictionary[@"rotationStartAngle"], -360.0, 360.0, _rotationStartAngle);
    _rotationEndAngle = ACClampedDouble(dictionary[@"rotationEndAngle"], -360.0, 360.0, _rotationEndAngle);
    _gestureDuration = ACClampedDouble(dictionary[@"gestureDuration"], 0.05, 10.0, _gestureDuration);

    _recognitionRetryUntilFound = [dictionary[@"recognitionRetryUntilFound"] boolValue];
    _recognitionRetryInterval = ACClampedDouble(dictionary[@"recognitionRetryInterval"], 0.2, 30.0, 1.0);
    _successBranchIndex = ACClampedInteger(dictionary[@"successBranchIndex"], -1, NSIntegerMax, -1);
    _failureBranchIndex = ACClampedInteger(dictionary[@"failureBranchIndex"], -1, NSIntegerMax, -1);
    _successActionTaskIndex = ACClampedInteger(dictionary[@"successActionTaskIndex"], -1, NSIntegerMax, -1);
    _failureActionTaskIndex = ACClampedInteger(dictionary[@"failureActionTaskIndex"], -1, NSIntegerMax, -1);
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

    NSMutableDictionary *extra = [dictionary mutableCopy];
    NSArray<NSString *> *modeledKeys = @[
        ACKeyMode, ACKeyDelay, ACKeyRepeat, ACKeyInterval, ACKeyRandomDelay, ACKeyJitterRadius, ACKeyDescription, ACKeyExpanded,
        @"pressure", @"doubleTapInterval", @"pressDuration", @"pressDurationMs", @"swipeDuration", @"swipeStep",
        @"templatePath", @"useMatchPoint", @"imageActionMode", @"failureActionMode", @"threshold", @"templateROI", @"roi", @"matchClickOffset", @"clickOffset",
        @"ocrMode", @"ocrMatchMode", @"ocrText", @"ocrSimilarity",
        @"colorRed", @"colorGreen", @"colorBlue", @"colorTolerance", @"colorMatchMode",
        @"networkURL", @"networkMethod", @"networkHeaders", @"networkRequestOnly", @"networkUsesPost", @"networkRetryForever", @"networkRetryLimit", @"networkTimeout", @"networkContains", @"networkFalse", @"networkPostBody", @"networkPostBodyUsesOCRResult", @"networkPostExtraFields",
        @"jumpTaskIndex", @"jumpTaskId", @"targetTaskIndex",
        @"macroPath", @"macroArguments", @"macroSpeed",
        @"gestureFromDistance", @"gestureToDistance", @"gestureRadius", @"rotationStartAngle", @"rotationEndAngle", @"gestureDuration",
        @"recognitionRetryUntilFound", @"recognitionRetryInterval", @"successBranchIndex", @"failureBranchIndex", @"successActionTaskIndex", @"failureActionTaskIndex",
        @"successActionConfig", @"failureActionConfig", @"successRecognitionActionConfig", @"failureRecognitionActionConfig",
        @"point", @"pointScreenSize", @"successPoint", @"successPointScreenSize", @"failurePoint", @"failurePointScreenSize", @"pathScreenSize", @"multiPointScreenSize", @"eventsScreenSize", @"colorPointScreenSize", @"path", @"multiPoints", @"events", @"colorPoints", @"networkPostPairs",
    ];
    [extra removeObjectsForKeys:modeledKeys];
    _extraFields = [extra copy];
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
    NSMutableDictionary *dictionary = [self.extraFields mutableCopy] ?: [NSMutableDictionary dictionary];
    dictionary[ACKeyMode] = @(self.actionMode);
    dictionary[ACKeyDelay] = @(MAX(0.0, self.delay));
    dictionary[ACKeyRepeat] = @(MAX(1, self.repeatCount));
    dictionary[ACKeyInterval] = @(MIN(30.0, MAX(0.0, self.interval)));
    dictionary[ACKeyExpanded] = @(self.expanded);
    if (self.randomDelay) {
        dictionary[ACKeyRandomDelay] = @YES;
    }
    if (self.jitterRadius > 0.001) {
        dictionary[ACKeyJitterRadius] = @(MIN(200.0, MAX(0.0, self.jitterRadius)));
    }
    dictionary[@"pressure"] = @(MIN(1.0, MAX(0.0, self.pressure)));
    if (self.taskDescription.length > 0) {
        dictionary[ACKeyDescription] = self.taskDescription;
    }
    dictionary[@"doubleTapInterval"] = @(MIN(2.0, MAX(0.02, self.doubleTapInterval)));
    dictionary[@"pressDurationMs"] = @((NSInteger)llround(MIN(10.0, MAX(0.0, self.longPressDuration)) * 1000.0));
    dictionary[@"pressDuration"] = @(MIN(10.0, MAX(0.0, self.longPressDuration)));
    dictionary[@"swipeDuration"] = @(MIN(10.0, MAX(0.05, self.swipeDuration)));
    dictionary[@"swipeStep"] = @(MIN(200.0, MAX(1.0, self.swipeStep)));
    if (self.templatePath.length > 0) {
        dictionary[@"templatePath"] = self.templatePath;
    }
    dictionary[@"useMatchPoint"] = @(self.useMatchPoint);
    dictionary[@"imageActionMode"] = @(self.successActionMode);
    dictionary[@"failureActionMode"] = @(self.failureActionMode);
    dictionary[@"threshold"] = @(MIN(1.0, MAX(0.0, self.threshold)));
    if (self.hasTemplateROI) {
        dictionary[@"templateROI"] = [NSValue valueWithCGRect:self.templateROI];
    }
    if (self.hasMatchClickOffset) {
        dictionary[@"matchClickOffset"] = [NSValue valueWithCGPoint:self.matchClickOffset];
    }
    dictionary[@"ocrMode"] = @(self.ocrMode);
    dictionary[@"ocrMatchMode"] = @(self.ocrMatchMode);
    if (self.ocrText.length > 0) {
        dictionary[@"ocrText"] = self.ocrText;
    }
    dictionary[@"ocrSimilarity"] = @(MIN(1.0, MAX(0.0, self.ocrSimilarity)));
    dictionary[@"colorTolerance"] = @(MIN(255.0, MAX(0.0, self.colorTolerance)));
    dictionary[@"colorMatchMode"] = @(MIN(1, MAX(0, self.colorMatchMode)));
    if (self.colorRed || self.colorGreen || self.colorBlue) {
        dictionary[@"colorRed"] = @(MIN(255, MAX(0, self.colorRed)));
        dictionary[@"colorGreen"] = @(MIN(255, MAX(0, self.colorGreen)));
        dictionary[@"colorBlue"] = @(MIN(255, MAX(0, self.colorBlue)));
    }
    if (self.networkURL.length > 0) {
        dictionary[@"networkURL"] = self.networkURL;
    }
    NSString *method = self.networkMethod.length > 0 ? [self.networkMethod uppercaseString] : (self.networkUsesPost ? @"POST" : @"GET");
    dictionary[@"networkMethod"] = [method isEqualToString:@"POST"] ? @"POST" : @"GET";
    if (self.networkHeaders.count > 0) {
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
    if (self.networkPostBody.length > 0) {
        dictionary[@"networkPostBody"] = self.networkPostBody;
    }
    dictionary[@"networkPostBodyUsesOCRResult"] = @(self.networkPostBodyUsesOCRResult);
    if (self.networkPostExtraFields.length > 0) {
        dictionary[@"networkPostExtraFields"] = self.networkPostExtraFields;
    }
    if (self.jumpTaskIndex >= 0) {
        dictionary[@"jumpTaskIndex"] = @(self.jumpTaskIndex);
    }
    if (self.macroPath.length > 0) {
        dictionary[@"macroPath"] = self.macroPath;
    }
    if (self.macroArguments.length > 0) {
        dictionary[@"macroArguments"] = self.macroArguments;
    }
    dictionary[@"macroSpeed"] = @(MIN(10.0, MAX(0.1, self.macroSpeed)));
    dictionary[@"gestureFromDistance"] = @(MIN(1000.0, MAX(1.0, self.gestureFromDistance)));
    dictionary[@"gestureToDistance"] = @(MIN(1000.0, MAX(1.0, self.gestureToDistance)));
    dictionary[@"gestureRadius"] = @(MIN(1000.0, MAX(1.0, self.gestureRadius)));
    dictionary[@"rotationStartAngle"] = @(MIN(360.0, MAX(-360.0, self.rotationStartAngle)));
    dictionary[@"rotationEndAngle"] = @(MIN(360.0, MAX(-360.0, self.rotationEndAngle)));
    dictionary[@"gestureDuration"] = @(MIN(10.0, MAX(0.05, self.gestureDuration)));
    dictionary[@"recognitionRetryUntilFound"] = @(self.recognitionRetryUntilFound);
    dictionary[@"recognitionRetryInterval"] = @(MIN(30.0, MAX(0.2, self.recognitionRetryInterval)));
    if (self.successBranchIndex >= 0) dictionary[@"successBranchIndex"] = @(self.successBranchIndex);
    if (self.failureBranchIndex >= 0) dictionary[@"failureBranchIndex"] = @(self.failureBranchIndex);
    if (self.successActionTaskIndex >= 0) dictionary[@"successActionTaskIndex"] = @(self.successActionTaskIndex);
    if (self.failureActionTaskIndex >= 0) dictionary[@"failureActionTaskIndex"] = @(self.failureActionTaskIndex);
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
