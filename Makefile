SHELL   := /bin/sh
PREFIX  ?= $(HOME)/.local
BINDIR  ?= $(PREFIX)/bin

.PHONY: all test unit integration docs lint install uninstall

all: test

test: unit integration

unit:
	zsh test/unit.zsh

integration:
	zsh test/integration.zsh

docs:
	zsh tools/gen-command-docs.zsh

lint:
	@for f in bin/zui lib/zui.zsh lib/zui/*.zsh lib/zui/commands/*.zsh test/*.zsh tools/*.zsh; do \
		zsh -n "$$f" || exit 1; \
	done
	@echo "syntax ok"

install:
	mkdir -p "$(DESTDIR)$(BINDIR)"
	ln -sf "$(CURDIR)/bin/zui" "$(DESTDIR)$(BINDIR)/zui"
	@echo "installed $(BINDIR)/zui -> $(CURDIR)/bin/zui"

uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/zui"
