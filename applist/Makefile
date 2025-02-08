export THEOS=/Users/$(shell whoami)/Projects/theos
export GO_EASY_ON_ME=1
target = appletv
THEOS_DEVICE_IP = living-room.local 
INSTALL_TARGET_PROCESSES = TVSettings
DEBUG = 1

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libapplist

libapplist_FILES = $(wildcard *.m) $(wildcard applications/*.m)
libapplist_LIBRARIES = prefs
libapplist_FRAMEWORKS = CoreServices
libapplist_INSTALL_PATH = /usr/lib/
libapplist_CFLAGS = -I./ -Iinclude -IPublic -Iapplications -fobjc-arc -F./ -F../ -v -Ikbtask
libapplist_LDFLAGS = -F. -L. -lkbtask #-undefined dynamic_lookup
include $(THEOS_MAKE_PATH)/library.mk
SUBPROJECTS += applist
include $(THEOS_MAKE_PATH)/aggregate.mk

