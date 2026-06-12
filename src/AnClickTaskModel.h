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

@property (nonatomic, copy) NSString *templatePath;
@property (nonatomic, assign) BOOL useMatchPoint;
@property (nonatomic, assign) AnClickActionMode successActionMode;
@property (nonatomic, assign) AnClickActionMode failureActionMode;
@property (nonatomic, assign) double threshold;

@property (nonatomic, assign) AnClickOCRMode ocrMode;
@property (nonatomic, assign) AnClickOCRMatchMode ocrMatchMode;
@property (nonatomic, copy) NSString *ocrText;

@property (nonatomic, assign) NSInteger colorRed;
@property (nonatomic, assign) NSInteger colorGreen;
@property (nonatomic, assign) NSInteger colorBlue;
@property (nonatomic, assign) double colorTolerance;

@property (nonatomic, copy) NSString *networkURL;
@property (nonatomic, copy) NSString *networkMethod;
@property (nonatomic, assign) BOOL networkRequestOnly;
@property (nonatomic, assign) BOOL networkUsesPost;
@property (nonatomic, assign) BOOL networkRetryForever;
@property (nonatomic, assign) NSInteger networkRetryLimit;
@property (nonatomic, assign) NSTimeInterval networkTimeout;
@property (nonatomic, copy) NSString *networkContains;
@property (nonatomic, copy) NSString *networkFalse;
@property (nonatomic, copy) NSString *networkPostBody;
@property (nonatomic, assign) BOOL networkPostBodyUsesOCRResult;

@property (nonatomic, strong, nullable) NSValue *point;
@property (nonatomic, strong, nullable) NSValue *pointScreenSize;
@property (nonatomic, strong, nullable) NSValue *successPoint;
@property (nonatomic, strong, nullable) NSValue *successPointScreenSize;
@property (nonatomic, strong, nullable) NSValue *failurePoint;
@property (nonatomic, strong, nullable) NSValue *failurePointScreenSize;
@property (nonatomic, copy) NSArray *path;
@property (nonatomic, copy) NSArray *multiPoints;
@property (nonatomic, copy) NSArray *events;
@property (nonatomic, copy) NSArray *colorPoints;
@property (nonatomic, copy) NSArray *networkPostPairs;

@property (nonatomic, copy) NSDictionary<NSString *, id> *extraFields;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSMutableDictionary *)dictionaryRepresentation;

+ (NSArray<AnClickTaskModel *> *)modelsFromDictionaries:(NSArray *)tasks;
+ (NSArray<NSDictionary *> *)dictionariesFromModels:(NSArray<AnClickTaskModel *> *)models;

@end

NS_ASSUME_NONNULL_END
