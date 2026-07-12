.PHONY: install install-local uninstall dev test lint clean format docs release package-deb

PREFIX ?= /usr/local
DESTDIR ?=

BIN_DIR = $(DESTDIR)$(PREFIX)/bin
LIB_DIR = $(DESTDIR)$(PREFIX)/lib/hyprglass-studio
SHARE_DIR = $(DESTDIR)$(PREFIX)/share/hyprglass-studio
APPLICATIONS_DIR = $(DESTDIR)$(PREFIX)/share/applications
DOC_DIR = $(DESTDIR)$(PREFIX)/share/doc/hyprglass-studio
LICENSE_DIR = $(DESTDIR)$(PREFIX)/share/licenses/hyprglass-studio

install:
	install -Dm755 scripts/hyprglass-studio-launcher "$(BIN_DIR)/hyprglass-studio"
	install -dm755 "$(LIB_DIR)"
	cp -a src "$(LIB_DIR)/"
	find "$(LIB_DIR)/src" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	find "$(LIB_DIR)/src" -type f -exec chmod 644 {} +
	install -Dm644 requirements.txt "$(LIB_DIR)/requirements.txt"
	install -dm755 "$(SHARE_DIR)"
	install -Dm755 install.sh "$(SHARE_DIR)/install.sh"
	install -Dm755 uninstall.sh "$(SHARE_DIR)/uninstall.sh"
	cp -a scripts "$(SHARE_DIR)/scripts"
	find "$(SHARE_DIR)/scripts" -type f -name '*.sh' -exec chmod 755 {} +
	find "$(SHARE_DIR)/scripts" -type f -name '*.py' -exec chmod 755 {} +
	cp -a profiles "$(SHARE_DIR)/profiles"
	chmod 644 "$(SHARE_DIR)/profiles"/*.conf
	cp -a templates "$(SHARE_DIR)/templates"
	chmod 644 "$(SHARE_DIR)/templates"/*
	install -Dm644 assets/hyprglass-studio.desktop "$(APPLICATIONS_DIR)/hyprglass-studio.desktop"
	install -Dm644 README.md "$(DOC_DIR)/README.md"
	install -Dm644 LICENSE "$(LICENSE_DIR)/LICENSE"
	install -Dm644 docs/INSTALLATION.md "$(DOC_DIR)/INSTALLATION.md"
	install -Dm644 docs/CONFIGURATION.md "$(DOC_DIR)/CONFIGURATION.md" 2>/dev/null || true
	install -Dm644 docs/PROFILES.md "$(DOC_DIR)/PROFILES.md" 2>/dev/null || true
	install -Dm644 docs/WALLUST-INTEGRATION.md "$(DOC_DIR)/WALLUST-INTEGRATION.md" 2>/dev/null || true

install-local:
	./install.sh

uninstall:
	./uninstall.sh

dev:
	python -m src.server --port 8765

test:
	python -m pytest -v

lint:
	shellcheck install.sh uninstall.sh
	ruff check .

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name '*.pyc' -delete
	find . -type f -name '*.pyo' -delete

format:
	ruff format .

docs:
	mkdocs build

release:
	git tag "$$(cat VERSION)"
	git push origin "$$(cat VERSION)"

package-deb:
	./scripts/build-deb.sh
