#import "AnClickTaskModel.h"

static NSString * const ACKeyMode = @"mode";
static NSString * const ACKeyDelay = @"delay";
static NSString * const ACKeyRepeat = @"repeat";
static NSString * const ACKeyInterval = @"interval";
static NSString * const ACKeyRandomDelay = @"randomDelay";
static NSString * const ACKeyJitterRadius = @"jitterRadius";
static NSString * const ACKeyDescription = @"desc";
static NSString * const ACKeyExpanded = @"isExpanded";

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
        _taskDescription = @"";
        _templatePath = @"";
        _useMatchPoint = YES;
        _successActionMode = AnClickActionModeTap;
        _failureActionMode = AnClickActionModeNone;
        _threshold = 0.80;
        _ocrMode = AnClickOCRModeAppleVision;
        _ocrMatchMode = AnClickOCRMatchModeContains;
        _ocrText = @"";
        _colorTolerance = 18.0;
        _networkURL = @"";
        _networkMethod = @"GET";
        _networkRetryForever = YES;
        _networkRetryLimit = 1;
        _networkTimeout = 8.0;
        _networkContains = @"";
        _networkFalse = @"";
        _networkPostBody = @"";
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
    _delay = [dictionary[ACKeyDelay] respondsToSelector:@selector(doubleValue)] ? MAX(0.0, [dictionary[ACKeyDelay] doubleValue]) : 0.0;
    _repeatCount = [dictionary[ACKeyRepeat] respondsToSelector:@selector(integerValue)] ? MAX(1, [dictionary[ACKeyRepeat] integerValue]) : 1;
    _interval = [dictionary[ACKeyInterval] respondsToSelector:@selector(doubleValue)] ? MIN(30.0, MAX(0.0, [dictionary[ACKeyInterval] doubleValue])) : _interval;
    _randomDelay = [dictionary[ACKeyRandomDelay] boolValue];
    _jitterRadius = [dictionary[ACKeyJitterRadius] respondsToSelector:@selector(doubleValue)] ? MIN(200.0, MAX(0.0, [dictionary[ACKeyJitterRadius] doubleValue])) : 0.0;
    _taskDescription = [dictionary[ACKeyDescription] isKindOfClass:NSString.class] ? [dictionary[ACKeyDescription] copy] : @"";
    _expanded = [dictionary[ACKeyExpanded] boolValue];

    _templatePath = [dictionary[@"templatePath"] isKindOfClass:NSString.class] ? [dictionary[@"templatePath"] copy] : @"";
    _useMatchPoint = dictionary[@"useMatchPoint"] ? [dictionary[@"useMatchPoint"] boolValue] : YES;
    _successActionMode = [dictionary[@"imageActionMode"] respondsToSelector:@selector(integerValue)] ? (AnClickActionMode)[dictionary[@"imageActionMode"] integerValue] : AnClickActionModeTap;
    _failureActionMode = [dictionary[@"failureActionMode"] respondsToSelector:@selector(integerValue)] ? (AnClickActionMode)[dictionary[@"failureActionMode"] integerValue] : AnClickActionModeNone;
    _threshold = [dictionary[@"threshold"] respondsToSelector:@selector(doubleValue)] ? MIN(1.0, MAX(0.0, [dictionary[@"threshold"] doubleValue])) : 0.80;

    _ocrMode = [dictionary[@"ocrMode"] respondsToSelector:@selector(integerValue)] ? (AnClickOCRMode)[dictionary[@"ocrMode"] integerValue] : AnClickOCRModeAppleVision;
    _ocrMatchMode = [dictionary[@"ocrMatchMode"] respondsToSelector:@selector(integerValue)] ? (AnClickOCRMatchMode)[dictionary[@"ocrMatchMode"] integerValue] : AnClickOCRMatchModeContains;
    _ocrText = [dictionary[@"ocrText"] isKindOfClass:NSString.class] ? [dictionary[@"ocrText"] copy] : @"";

    _colorRed = [dictionary[@"colorRed"] respondsToSelector:@selector(integerValue)] ? MIN(255, MAX(0, [dictionary[@"colorRed"] integerValue])) : 0;
    _colorGreen = [dictionary[@"colorGreen"] respondsToSelector:@selector(integerValue)] ? MIN(255, MAX(0, [dictionary[@"colorGreen"] integerValue])) : 0;
    _colorBlue = [dictionary[@"colorBlue"] respondsToSelector:@selector(integerValue)] ? MIN(255, MAX(0, [dictionary[@"colorBlue"] integerValue])) : 0;
    _colorTolerance = [dictionary[@"colorTolerance"] respondsToSelector:@selector(doubleValue)] ? MIN(255.0, MAX(0.0, [dictionary[@"colorTolerance"] doubleValue])) : 18.0;

    _networkURL = [dictionary[@"networkURL"] isKindOfClass:NSString.class] ? [dictionary[@"networkURL"] copy] : @"";
    _networkMethod = [dictionary[@"networkMethod"] isKindOfClass:NSString.class] ? [dictionary[@"networkMethod"] copy] : @"GET";
    _networkRequestOnly = [dictionary[@"networkRequestOnly"] boolValue];
    _networkUsesPost = [dictionary[@"networkUsesPost"] boolValue];
    _networkRetryForever = dictionary[@"networkRetryForever"] ? [dictionary[@"networkRetryForever"] boolValue] : YES;
    _networkRetryLimit = [dictionary[@"networkRetryLimit"] respondsToSelector:@selector(integerValue)] ? MAX(1, [dictionary[@"networkRetryLimit"] integerValue]) : 1;
    _networkTimeout = [dictionary[@"networkTimeout"] respondsToSelector:@selector(doubleValue)] ? MIN(60.0, MAX(1.0, [dictionary[@"networkTimeout"] doubleValue])) : 8.0;
    _networkContains = [dictionary[@"networkContains"] isKindOfClass:NSString.class] ? [dictionary[@"networkContains"] copy] : @"";
    _networkFalse = [dictionary[@"networkFalse"] isKindOfClass:NSString.class] ? [dictionary[@"networkFalse"] copy] : @"";
    _networkPostBody = [dictionary[@"networkPostBody"] isKindOfClass:NSString.class] ? [dictionary[@"networkPostBody"] copy] : @"";
    _networkPostBodyUsesOCRResult = [dictionary[@"networkPostBodyUsesOCRResult"] boolValue];

    _point = [dictionary[@"point"] isKindOfClass:NSValue.class] ? dictionary[@"point"] : nil;
    _pointScreenSize = [dictionary[@"pointScreenSize"] isKindOfClass:NSValue.class] ? dictionary[@"pointScreenSize"] : nil;
    _successPoint = [dictionary[@"successPoint"] isKindOfClass:NSValue.class] ? dictionary[@"successPoint"] : nil;
    _successPointScreenSize = [dictionary[@"successPointScreenSize"] isKindOfClass:NSValue.class] ? dictionary[@"successPointScreenSize"] : nil;
    _failurePoint = [dictionary[@"failurePoint"] isKindOfClass:NSValue.class] ? dictionary[@"failurePoint"] : nil;
    _failurePointScreenSize = [dictionary[@"failurePointScreenSize"] isKindOfClass:NSValue.class] ? dictionary[@"failurePointScreenSize"] : nil;
    _path = [dictionary[@"path"] isKindOfClass:NSArray.class] ? [dictionary[@"path"] copy] : @[];
    _multiPoints = [dictionary[@"multiPoints"] isKindOfClass:NSArray.class] ? [dictionary[@"multiPoints"] copy] : @[];
    _events = [dictionary[@"events"] isKindOfClass:NSArray.class] ? [dictionary[@"events"] copy] : @[];
    _colorPoints = [dictionary[@"colorPoints"] isKindOfClass:NSArray.class] ? [dictionary[@"colorPoints"] copy] : @[];
    _networkPostPairs = [dictionary[@"networkPostPairs"] isKindOfClass:NSArray.class] ? [dictionary[@"networkPostPairs"] copy] : @[];

    NSMutableDictionary *extra = [dictionary mutableCopy];
    NSArray<NSString *> *modeledKeys = @[
        ACKeyMode, ACKeyDelay, ACKeyRepeat, ACKeyInterval, ACKeyRandomDelay, ACKeyJitterRadius, ACKeyDescription, ACKeyExpanded,
        @"templatePath", @"useMatchPoint", @"imageActionMode", @"failureActionMode", @"threshold",
        @"ocrMode", @"ocrMatchMode", @"ocrText",
        @"colorRed", @"colorGreen", @"colorBlue", @"colorTolerance",
        @"networkURL", @"networkMethod", @"networkRequestOnly", @"networkUsesPost", @"networkRetryForever", @"networkRetryLimit", @"networkTimeout", @"networkContains", @"networkFalse", @"networkPostBody", @"networkPostBodyUsesOCRResult",
        @"point", @"pointScreenSize", @"successPoint", @"successPointScreenSize", @"failurePoint", @"failurePointScreenSize", @"path", @"multiPoints", @"events", @"colorPoints", @"networkPostPairs",
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
    if (self.taskDescription.length > 0) {
        dictionary[ACKeyDescription] = self.taskDescription;
    }
    if (self.templatePath.length > 0) {
        dictionary[@"templatePath"] = self.templatePath;
    }
    dictionary[@"useMatchPoint"] = @(self.useMatchPoint);
    dictionary[@"imageActionMode"] = @(self.successActionMode);
    dictionary[@"failureActionMode"] = @(self.failureActionMode);
    dictionary[@"threshold"] = @(MIN(1.0, MAX(0.0, self.threshold)));
    dictionary[@"ocrMode"] = @(self.ocrMode);
    dictionary[@"ocrMatchMode"] = @(self.ocrMatchMode);
    if (self.ocrText.length > 0) {
        dictionary[@"ocrText"] = self.ocrText;
    }
    dictionary[@"colorTolerance"] = @(MIN(255.0, MAX(0.0, self.colorTolerance)));
    if (self.colorRed || self.colorGreen || self.colorBlue) {
        dictionary[@"colorRed"] = @(MIN(255, MAX(0, self.colorRed)));
        dictionary[@"colorGreen"] = @(MIN(255, MAX(0, self.colorGreen)));
        dictionary[@"colorBlue"] = @(MIN(255, MAX(0, self.colorBlue)));
    }
    if (self.networkURL.length > 0) {
        dictionary[@"networkURL"] = self.networkURL;
    }
    dictionary[@"networkMethod"] = self.networkMethod.length > 0 ? self.networkMethod : @"GET";
    dictionary[@"networkRequestOnly"] = @(self.networkRequestOnly);
    dictionary[@"networkUsesPost"] = @(self.networkUsesPost);
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

    if (self.point) dictionary[@"point"] = self.point;
    if (self.pointScreenSize) dictionary[@"pointScreenSize"] = self.pointScreenSize;
    if (self.successPoint) dictionary[@"successPoint"] = self.successPoint;
    if (self.successPointScreenSize) dictionary[@"successPointScreenSize"] = self.successPointScreenSize;
    if (self.failurePoint) dictionary[@"failurePoint"] = self.failurePoint;
    if (self.failurePointScreenSize) dictionary[@"failurePointScreenSize"] = self.failurePointScreenSize;
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
