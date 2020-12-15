target = appletv
THEOS_DEVICE_IP = guest-room.local
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libapplist

libapplist_FILES = $(wildcard *.m) $(wildcard applications/*.m)
libapplist_CFLAGS = -I./ -Iinclude -IPublic -Iapplications -fobjc-arc
libapplist_LDFLAGS = -undefined dynamic_lookup
include $(THEOS_MAKE_PATH)/library.mk
SUBPROJECTS += applist
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 TVSettings"
