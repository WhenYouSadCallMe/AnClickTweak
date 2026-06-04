#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ANTaskRunnerLogBlock)(NSString *message);
typedef void (^ANTaskRunnerStateBlock)(BOOL running);

@interface ANTaskRunner : NSObject

@property (nonatomic, copy, nullable) ANTaskRunnerLogBlock logBlock;
@property (nonatomic, copy, nullable) ANTaskRunnerStateBlock stateBlock;
@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;

- (void)startWithTasks:(NSArray<NSDictionary *> *)tasks startDelay:(NSTimeInterval)startDelay;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
