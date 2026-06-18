#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AnClickTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^AnClickRecognitionMatchCompletion)(NSDictionary *_Nullable match);

@interface AnClickRecognitionService : NSObject

- (void)prewarmWithCompletion:(void (^_Nullable)(void))completion;

- (void)findTemplateImageMatch:(UIImage *)templateImage
                     threshold:(double)threshold
                    completion:(AnClickRecognitionMatchCompletion)completion;

- (void)findText:(NSString *)targetText
            mode:(AnClickOCRMode)mode
        useRegex:(BOOL)useRegex
      completion:(AnClickRecognitionMatchCompletion)completion;

- (void)findColorPatternMatchWithPoints:(NSArray<NSDictionary *> *)points
                              tolerance:(double)tolerance
                             completion:(AnClickRecognitionMatchCompletion)completion;

- (void)cancelPendingRequests;

@end

NS_ASSUME_NONNULL_END
