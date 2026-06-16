#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AnClickActionMode) {
    AnClickActionModeNone = -1,
    AnClickActionModeTap = 0,
    AnClickActionModeDoubleTap = 1,
    AnClickActionModeLongPress = 2,
    AnClickActionModeSwipe = 3,
    AnClickActionModeTwoFingerTap = 4,
    AnClickActionModePinchIn = 5,
    AnClickActionModePinchOut = 6,
    AnClickActionModeRotate = 7,
    AnClickActionModeImage = 8,
    AnClickActionModeMacro = 9,
    AnClickActionModeOCR = 10,
    AnClickActionModeColor = 11,
    AnClickActionModeNetwork = 12,
    AnClickActionModeJump = 13,
    AnClickActionModeDelay = 14,
    AnClickActionModeOpenApp = 15,
    AnClickActionModeCount = 16,
};

typedef NS_ENUM(NSInteger, AnClickOCRMode) {
    AnClickOCRModeAppleVision = 0,
    AnClickOCRModeTesseract = 1,
};

typedef NS_ENUM(NSInteger, AnClickOCRMatchMode) {
    AnClickOCRMatchModeContains = 0,
    AnClickOCRMatchModeRegex = 1,
    AnClickOCRMatchModeEqual = 2,
};
