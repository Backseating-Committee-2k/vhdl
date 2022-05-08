KVERSION ?= $(shell uname -r)

obj-m = bss2k.o

all:
	$(MAKE) -C /lib/modules/$(KVERSION)/build M=$(CURDIR) modules

install:
	$(MAKE) -C /lib/modules/$(KVERSION)/build M=$(CURDIR) modules_install

clean:
	$(MAKE) -C /lib/modules/$(KVERSION)/build M=$(CURDIR) clean
