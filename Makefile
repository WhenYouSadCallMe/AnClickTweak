ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AnClick
OPENCV_HEADERS = $(THEOS_PROJECT_DIR)/opencv-ios-headers
OPENCV_LIB = $(THEOS_PROJECT_DIR)/opencv-ios-lib/libopencv_merged.a

AnClick_FILES = \
	src/AnClickCore.mm \
	src/AnClickOCR.mm \
	src/AnClickFakeTouch.m \
	src/AnClickRecorder.m \
	src/AnClickUI.m \
	vendor/HammerTouch.m

AnClick_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_OBJCFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_CCFLAGS = -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_OBJCCFLAGS = -fobjc-arc -std=c++17 -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_CXXFLAGS = -std=c++17 -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_LDFLAGS = $(OPENCV_LIB) -lc++ -lz
AnClick_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics Accelerate Vision ImageIO AVFoundation MediaPlayer
AnClick_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
