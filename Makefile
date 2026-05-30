ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AnClick

AnClick_FILES = \
	src/AnClickCore.mm \
	src/AnClickFakeTouch.m \
	src/AnClickRecorder.m \
	src/AnClickUI.m \
	vendor/PTFakeTouch.m

AnClick_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/include
AnClick_OBJCFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/include
AnClick_CCFLAGS = -I$(THEOS_PROJECT_DIR)/include
AnClick_OBJCCFLAGS = -fobjc-arc -std=c++17 -I$(THEOS_PROJECT_DIR)/include
AnClick_CXXFLAGS = -std=c++17 -I$(THEOS_PROJECT_DIR)/include
AnClick_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics
AnClick_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
