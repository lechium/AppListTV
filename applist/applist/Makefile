ARCHS = arm64
TARGET = appletv:clang

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AppList
AppList_FILES = $(wildcard *.m)
AppList_INSTALL_PATH = /System/Library/PreferenceBundles
AppList_FRAMEWORKS = UIKit TVSettingKit
AppList_LIBRARIES = applist 
AppList_CFLAGS = -I. -ITVSettings -I../public -F. -fobjc-arc
AppList_LDFLAGS = -F. -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk

