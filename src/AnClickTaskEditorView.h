#import <UIKit/UIKit.h>
#import "AnClickTaskModel.h"

NS_ASSUME_NONNULL_BEGIN

@class AnClickTaskEditorView;

@protocol AnClickTaskEditorViewDelegate <NSObject>
- (void)taskEditorViewDidCancel:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidClose:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidSave:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidDeleteTask:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidRequestPointPick:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidRequestColorPick:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidRequestTemplateCapture:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidRequestRecording:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidRequestSingleStepTest:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidRequestSuccessActionConfig:(AnClickTaskEditorView *)editorView;
- (void)taskEditorViewDidRequestFailureActionConfig:(AnClickTaskEditorView *)editorView;
- (void)taskEditorView:(AnClickTaskEditorView *)editorView didRequestRecognitionResultPointPickForSuccess:(BOOL)success;
- (void)taskEditorView:(AnClickTaskEditorView *)editorView didSelectActionMode:(AnClickActionMode)mode;
- (void)taskEditorView:(AnClickTaskEditorView *)editorView didUpdateModel:(AnClickTaskModel *)model;
@end

@interface AnClickTaskEditorView : UIView

@property (nonatomic, weak, nullable) id<AnClickTaskEditorViewDelegate> delegate;
@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic, strong, readonly) AnClickTaskModel *model;

- (void)configureWithModel:(AnClickTaskModel *)model
                 taskIndex:(NSInteger)taskIndex
               branchTitle:(nullable NSString *)branchTitle
                actionName:(NSString *)actionName;
- (void)commitActiveEditing;
- (void)reloadForm;

@end

NS_ASSUME_NONNULL_END
