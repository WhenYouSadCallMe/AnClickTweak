ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AnClickPureIPA

AnClickPureIPA_FILES = \
	src/main.m \
	src/ANAppDelegate.m \
	src/ANRootViewController.m \
	src/ANLauncherInstaller.m

AnClickPureIPA_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/src
AnClickPureIPA_OBJCFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/src
AnClickPureIPA_FRAMEWORKS = UIKit Foundation
AnClickPureIPA_CODESIGN_FLAGS = -SResources/entitlements.plist
AnClickPureIPA_RESOURCE_FILES = Resources/Info.plist

include $(THEOS_MAKE_PATH)/application.mk

ipa: all
	@bash scripts/package_ipa.sh
