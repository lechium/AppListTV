export THEOS=/Users/$(shell whoami)/Projects/theos
target = appletv
THEOS_DEVICE_IP = guest-room.local
INSTALL_TARGET_PROCESSES = TVSettings

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libapplist

libapplist_FILES = $(wildcard *.m) $(wildcard applications/*.m)
libapplist_LIBRARIES = prefs
libapplist_FRAMEWORKS = CoreServices
libapplist_INSTALL_PATH = /fs/jb/usr/lib/
libapplist_CFLAGS = -I./ -Iinclude -IPublic -Iapplications -fobjc-arc -Ikbtask
libapplist_LDFLAGS = -lkbtask -undefined dynamic_lookup
include $(THEOS_MAKE_PATH)/library.mk
SUBPROJECTS += applist
include $(THEOS_MAKE_PATH)/aggregate.mk

