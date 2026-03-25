PREFIX ?= /usr/local

.PHONY: install uninstall

install:
	install -d $(PREFIX)/bin
	install -d $(PREFIX)/lib/macbox
	install -m 755 macbox $(PREFIX)/bin/macbox
	install -m 644 lib/common.sh $(PREFIX)/lib/macbox/common.sh
	install -m 644 lib/create.sh $(PREFIX)/lib/macbox/create.sh
	install -m 644 lib/enter.sh $(PREFIX)/lib/macbox/enter.sh
	install -m 644 lib/list.sh $(PREFIX)/lib/macbox/list.sh
	install -m 644 lib/stop.sh $(PREFIX)/lib/macbox/stop.sh
	install -m 644 lib/rm.sh $(PREFIX)/lib/macbox/rm.sh
	install -m 644 lib/init.sh $(PREFIX)/lib/macbox/init.sh

uninstall:
	rm -f $(PREFIX)/bin/macbox
	rm -rf $(PREFIX)/lib/macbox
