CC ?= gcc
CFLAGS = -Wall -Wcast-align -Wcast-qual -Wimplicit -Wpointer-arith -Wredundant-decls -Wreturn-type -Wshadow
PREFIX = /usr/local

include VERSION

all: rxtxcpu

rxtxcpu.o: EXTRA_CFLAGS = \
	-std=c99 \
	'-DRXTXCPU_VERSION="$(RXTXCPU_VERSION)"'

rxtxnuma.o rxtxqueue.o: EXTRA_CFLAGS = \
	-std=c99 \
	'-DRXTXUTILS_VERSION="$(RXTXUTILS_VERSION)"'

cpu.o rxtx.o: EXTRA_CFLAGS = \
	-std=c99

%.o: %.c
	$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -c -o $@ $<

rxtxcpu rxcpu txcpu: cpu.o ext.o interface.o ring_set.o rxtx.o rxtx_ring.o rxtx_savefile.o rxtx_stats.o rxtxcpu.o sig.o
	$(CC) $(CFLAGS) -o rxtxcpu $^ -lpcap -lpthread
	rm -f rxcpu txcpu
	ln -s rxtxcpu rxcpu
	ln -s rxtxcpu txcpu

rxtxnuma rxnuma txnuma: cpu.o ext.o interface.o ring_set.o rxtx.o rxtx_ring.o rxtx_savefile.o rxtx_stats.o rxtxnuma.o sig.o
	$(CC) $(CFLAGS) -o rxtxnuma $^ -lpcap -lpthread
	rm -f rxnuma txnuma
	ln -s rxtxnuma rxnuma
	ln -s rxtxnuma txnuma

rxtxqueue rxqueue txqueue: cpu.o ext.o interface.o ring_set.o rxtx.o rxtx_ring.o rxtx_savefile.o rxtx_stats.o rxtxqueue.o sig.o
	$(CC) $(CFLAGS) -o rxtxqueue $^ -lpcap -lpthread
	rm -f rxqueue txqueue
	ln -s rxtxqueue rxqueue
	ln -s rxtxqueue txqueue

.PHONY: clean
clean:
	rm -f cpu.o ext.o interface.o ring_set.o rxtx.o rxtx_ring.o rxtx_savefile.o rxtx_stats.o rxtxcpu.o sig.o rxtxcpu rxcpu txcpu rxtxnuma rxnuma txnuma rxtxqueue rxqueue txqueue

.PHONY: install
install: rxtxcpu rxcpu txcpu
	mkdir -p $(DESTDIR)$(PREFIX)/sbin
	install $^ $(DESTDIR)$(PREFIX)/sbin/

.PHONY: uninstall
uninstall:
	rm $(DESTDIR)$(PREFIX)/sbin/rxtxcpu
	rm $(DESTDIR)$(PREFIX)/sbin/rxcpu
	rm $(DESTDIR)$(PREFIX)/sbin/txcpu
