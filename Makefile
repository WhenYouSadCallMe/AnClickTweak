ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AnClick

AnClick_FILES = \
	src/AnClickCore.mm \
	src/AnClickFakeTouch.m \
	src/AnClickRecorder.m \
	src/AnClickUI.m \
	vendor/PTFakeTouch.m

OPENCV_FRAMEWORK_PATH ?= $(THEOS_PROJECT_DIR)/opencv2.framework
OPENCV_HEADERS ?= $(OPENCV_FRAMEWORK_PATH)/Headers
OPENCV_INCLUDE_FLAGS = -Iinclude -I$(OPENCV_HEADERS) -I$(OPENCV_FRAMEWORK_PATH)/Versions/A/Headers

AnClick_CFLAGS = -fobjc-arc $(OPENCV_INCLUDE_FLAGS)
AnClick_OBJCFLAGS = -fobjc-arc $(OPENCV_INCLUDE_FLAGS)
AnClick_OBJCCFLAGS = -fobjc-arc -std=c++17 $(OPENCV_INCLUDE_FLAGS)
AnClick_CPPFLAGS = $(OPENCV_INCLUDE_FLAGS)
AnClick_CCFLAGS = -std=c++17 $(OPENCV_INCLUDE_FLAGS)
AnClick_CXXFLAGS = -std=c++17 $(OPENCV_INCLUDE_FLAGS)
AnClick_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics
AnClick_LDFLAGS = -F$(dir $(OPENCV_FRAMEWORK_PATH)) -framework opencv2
AnClick_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
