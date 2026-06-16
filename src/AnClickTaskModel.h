#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "AnClickTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface AnClickTaskModel : NSObject <NSSecureCoding, NSCopying>

@property (nonatomic, assign) AnClickActionMode actionMode;
@property (nonatomic, assign) NSTimeInterval delay;
@property (nonatomic, assign) NSInteger repeatCount;
@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, assign) BOOL randomDelay;
@property (nonatomic, assign) CGFloat jitterRadius;
@property (nonatomic, copy) NSString *taskDescription;
@property (nonatomic, assign) BOOL expanded;

@property (nonatomic, assign) NSTimeInterval doubleTapInterval;
@property (nonatomic, assign) NSTimeInterval longPressDuration;
@property (nonatomic, assign) NSTimeInterval swipeDuration;
@property (nonatomic, assign) CGFloat swipeStep;

@property (nonatomic, copy) NSString *templatePath;
@property (nonatomic, assign) BOOL useMatchPoint;
@property (nonatomic, assign) AnClickActionMode successActionMode;
@property (nonatomic, assign) AnClickActionMode failureActionMode;
@property (nonatomic, assign) double threshold;
@property (nonatomic, assign) BOOL hasTemplateROI;
@property (nonatomic, assign) CGRect templateROI;
@property (nonatomic, assign) BOOL hasMatchClickOffset;
@property (nonatomic, assign) CGPoint matchClickOffset;

@property (nonatomic, assign) AnClickOCRMode ocrMode;
@property (nonatomic, assign) AnClickOCRMatchMode ocrMatchMode;
@property (nonatomic, copy) NSString *ocrText;
@property (nonatomic, assign) double ocrSimilarity;

@property (nonatomic, assign) NSInteger colorRed;
@property (nonatomic, assign) NSInteger colorGreen;
@property (nonatomic, assign) NSInteger colorBlue;
@property (nonatomic, assign) double colorTolerance;
@property (nonatomic, assign) NSInteger colorMatchMode;

@property (nonatomic, copy) NSString *networkURL;
@property (nonatomic, copy) NSString *networkMethod;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *networkHeaders;
@property (nonatomic, assign) BOOL networkRequestOnly;
@property (nonatomic, assign) BOOL networkUsesPost;
@property (nonatomic, assign) BOOL networkRetryForever;
@property (nonatomic, assign) NSInteger networkRetryLimit;
@property (nonatomic, assign) NSTimeInterval networkTimeout;
@property (nonatomic, copy) NSString *networkContains;
@property (nonatomic, copy) NSString *networkFalse;
@property (nonatomic, copy) NSString *networkPostBody;
@property (nonatomic, assign) BOOL networkPostBodyUsesOCRResult;
@property (nonatomic, copy) NSString *networkPostExtraFields;

@property (nonatomic, assign) NSInteger jumpTaskIndex;
@property (nonatomic, copy) NSString *targetBundleID;

@property (nonatomic, assign) double macroSpeed;

@property (nonatomic, assign) BOOL recognitionRetryUntilFound;
@property (nonatomic, assign) NSTimeInterval recognitionRetryInterval;
@property (nonatomic, assign) NSInteger successBranchIndex;
@property (nonatomic, assign) NSInteger failureBranchIndex;
@property (nonatomic, copy) NSDictionary *successActionConfig;
@property (nonatomic, copy) NSDictionary *failureActionConfig;
@property (nonatomic, copy) NSDictionary *successRecognitionActionConfig;
@property (nonatomic, copy) NSDictionary *failureRecognitionActionConfig;

@property (nonatomic, strong, nullable) NSValue *point;
@property (nonatomic, strong, nullable) NSValue *pointScreenSize;
@property (nonatomic, strong, nullable) NSValue *successPoint;
@property (nonatomic, strong, nullable) NSValue *successPointScreenSize;
@property (nonatomic, strong, nullable) NSValue *failurePoint;
@property (nonatomic, strong, nullable) NSValue *failurePointScreenSize;
@property (nonatomic, strong, nullable) NSValue *pathScreenSize;
@property (nonatomic, strong, nullable) NSValue *multiPointScreenSize;
@property (nonatomic, strong, nullable) NSValue *eventsScreenSize;
@property (nonatomic, strong, nullable) NSValue *colorPointScreenSize;
@property (nonatomic, copy) NSArray *path;
@property (nonatomic, copy) NSArray *multiPoints;
@property (nonatomic, copy) NSArray *events;
@property (nonatomic, copy) NSArray *colorPoints;
@property (nonatomic, copy) NSArray *networkPostPairs;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSMutableDictionary *)dictionaryRepresentation;

+ (NSArray<AnClickTaskModel *> *)modelsFromDictionaries:(NSArray *)tasks;
+ (NSArray<NSDictionary *> *)dictionariesFromModels:(NSArray<AnClickTaskModel *> *)models;

@end

NS_ASSUME_NONNULL_END
