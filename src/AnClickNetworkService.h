#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AnClickNetworkRequestCompletion)(BOOL matched,
                                                BOOL requestSucceeded,
                                                NSString *body,
                                                NSInteger statusCode,
                                                NSError *_Nullable error);

@interface AnClickNetworkService : NSObject

- (NSString *_Nullable)normalizedURLString:(NSString *_Nullable)urlText;
- (NSString *)stringFromData:(NSData *_Nullable)data;

- (BOOL)hasJudgementConditionWithTrueText:(NSString *_Nullable)trueText
                                falseText:(NSString *_Nullable)falseText;
- (BOOL)body:(NSString *_Nullable)body matchesRegexPattern:(NSString *_Nullable)pattern;
- (BOOL)body:(NSString *_Nullable)body matchesRuleText:(NSString *_Nullable)ruleText;
- (BOOL)body:(NSString *_Nullable)body matchesTrueText:(NSString *_Nullable)trueText
    falseText:(NSString *_Nullable)falseText
    defaultExpectedTrue:(BOOL)defaultExpectedTrue;
- (BOOL)body:(NSString *_Nullable)body matchesBlockText:(NSString *_Nullable)falseText
    defaultExpectedTrue:(BOOL)defaultExpectedTrue;
- (NSString *)statusTextWithMatched:(BOOL)matched
                    requestSucceeded:(BOOL)requestSucceeded
                          statusCode:(NSInteger)statusCode
                               error:(NSError *_Nullable)error;

- (void)performRequestWithURLString:(NSString *_Nullable)urlString
                              method:(NSString *_Nullable)method
                             headers:(NSDictionary *_Nullable)headers
                            postBody:(NSString *_Nullable)postBody
                            trueText:(NSString *_Nullable)trueText
                           falseText:(NSString *_Nullable)falseText
                 defaultExpectedTrue:(BOOL)defaultExpectedTrue
                             timeout:(NSTimeInterval)timeout
                          completion:(nullable AnClickNetworkRequestCompletion)completion;

- (void)cancelActiveTasks;

@end

NS_ASSUME_NONNULL_END
