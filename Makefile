ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AnClick
OPENCV_FRAMEWORK_DIR = $(THEOS_PROJECT_DIR)
OPENCV_HEADERS = $(OPENCV_FRAMEWORK_DIR)/opencv2.framework/Headers

AnClick_FILES = \
	src/AnClickCore.mm \
	src/AnClickFakeTouch.m \
	src/AnClickRecorder.m \
	src/AnClickUI.m \
	vendor/PTFakeTouch.m

AnClick_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_OBJCFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_CCFLAGS = -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_OBJCCFLAGS = -fobjc-arc -std=c++17 -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_CXXFLAGS = -std=c++17 -I$(THEOS_PROJECT_DIR)/include -I$(OPENCV_HEADERS)
AnClick_LDFLAGS = -F$(OPENCV_FRAMEWORK_DIR) -framework opencv2
AnClick_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics
AnClick_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
