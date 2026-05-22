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

AnClick_CFLAGS = -fobjc-arc -Iinclude
AnClick_CCFLAGS = -std=c++17 -Iinclude -I$(THEOS_PROJECT_DIR)/opencv2.framework/Headers
AnClick_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics
AnClick_LDFLAGS = -F$(THEOS_PROJECT_DIR) -framework opencv2
AnClick_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
