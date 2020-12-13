ARCHS = arm64
TARGET = appletv:clang

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AppList
AppList_FILES = $(wildcard *.m)
AppList_INSTALL_PATH = /System/Library/PreferenceBundles
AppList_FRAMEWORKS = UIKit TVSettingKit
AppList_LIBRARIES = applist 
AppList_CFLAGS+= -I. -ITVSettings -ITVSettingsKit -I../public -F.
AppList_LDFLAGS = -F. -undefined dynamic_lookup



include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	#$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	#$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/AppList.plist$(ECHO_END)
