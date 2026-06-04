ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AnClickPureIPA
OPENCV_HEADERS = $(THEOS_PROJECT_DIR)/../opencv-ios-headers
OPENCV_LIB = $(THEOS_PROJECT_DIR)/../opencv-ios-lib/libopencv_merged.a

AnClickPureIPA_FILES = \
	src/main.m \
	src/ANAppDelegate.m \
	src/ANRootViewController.m \
	src/ANTaskRunner.m \
	src/ANSystemTouch.m \
	src/ANFakeTouchBridge.m \
	../src/AnClickCore.mm \
	../src/AnClickOCR.mm

AnClickPureIPA_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/src -I$(THEOS_PROJECT_DIR)/../include -I$(OPENCV_HEADERS)
AnClickPureIPA_OBJCFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/src -I$(THEOS_PROJECT_DIR)/../include -I$(OPENCV_HEADERS)
AnClickPureIPA_OBJCCFLAGS = -fobjc-arc -std=c++17 -I$(THEOS_PROJECT_DIR)/src -I$(THEOS_PROJECT_DIR)/../include -I$(OPENCV_HEADERS)
AnClickPureIPA_LDFLAGS = $(OPENCV_LIB) -lc++ -lz
AnClickPureIPA_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics Vision ImageIO AVFoundation MediaPlayer
AnClickPureIPA_PRIVATE_FRAMEWORKS = IOKit
AnClickPureIPA_CODESIGN_FLAGS = -SResources/entitlements.plist
AnClickPureIPA_RESOURCE_FILES = Resources/Info.plist

include $(THEOS_MAKE_PATH)/application.mk

ipa: all
	@bash scripts/package_ipa.sh
