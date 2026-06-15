ARCHS = arm64
TARGET := iphone:clang:latest:14.0
DEBUG = 0
FINALPACKAGE = 1
STRIP = 1
ANCLICK_VERSION = 2.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UIKitBridge
OPENCV_HEADERS = $(THEOS_PROJECT_DIR)/opencv-ios-headers
OPENCV_LIB = $(THEOS_PROJECT_DIR)/opencv-ios-lib/libopencv_merged.a

UIKitBridge_FILES = \
	src/AnClickCore.mm \
	src/AnClickOCR.mm \
	src/AnClickFakeTouch.m \
	src/AnClickRecorder.m \
	src/AnClickTaskModel.m \
	src/AnClickTaskEngine.m \
	src/AnClickNetworkService.m \
	src/AnClickRecognitionService.m \
	src/AnClickPickerService.m \
	src/AnClickTemplateCaptureView.m \
	src/AnClickPointPickerView.m \
	src/AnClickColorPickerView.m \
	src/AnClickTaskEditorView.m \
	src/AnClickUI.m \
	vendor/HammerTouch.m

UIKitBridge_CFLAGS = -Oz -DANCLICK_RELEASE_SILENT=1 -DANCLICK_VERSION=\"$(ANCLICK_VERSION)\" -fobjc-arc -fvisibility=hidden -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
UIKitBridge_OBJCFLAGS = -Oz -DANCLICK_RELEASE_SILENT=1 -DANCLICK_VERSION=\"$(ANCLICK_VERSION)\" -fobjc-arc -fvisibility=hidden -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
UIKitBridge_CCFLAGS = -Oz -DANCLICK_RELEASE_SILENT=1 -DANCLICK_VERSION=\"$(ANCLICK_VERSION)\" -fvisibility=hidden -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
UIKitBridge_OBJCCFLAGS = -Oz -DANCLICK_RELEASE_SILENT=1 -DANCLICK_VERSION=\"$(ANCLICK_VERSION)\" -fobjc-arc -std=c++17 -fvisibility=hidden -fvisibility-inlines-hidden -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
UIKitBridge_CXXFLAGS = -Oz -DANCLICK_RELEASE_SILENT=1 -DANCLICK_VERSION=\"$(ANCLICK_VERSION)\" -std=c++17 -fvisibility=hidden -fvisibility-inlines-hidden -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
UIKitBridge_LDFLAGS = $(OPENCV_LIB) -lc++ -lz -Wl,-S -Wl,-x
UIKitBridge_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics Accelerate Vision ImageIO AVFoundation MediaPlayer
UIKitBridge_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
