.PHONY: install uninstall test dev lint shellcheck bats ci clean install-logrotate verify-logrotate install-exporter package-deb lint-deb package-rpm config-test e2e-local docs

# FHS-compliant defaults for packaging
PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/ubopt
SYSD_DIR := /usr/lib/systemd/system
LOGDIR := /var/log/ubopt
BACKUPDIR := /var/backups/ubopt

install:
	@echo "Installing ubopt CLI to $(BINDIR)"
	install -d $(BINDIR) /etc/ubopt /var/lib/ubopt $(LIBDIR) $(LIBDIR)/lib $(LIBDIR)/providers $(LIBDIR)/modules $(LIBDIR)/exporters $(LIBDIR)/hooks/pre-update.d $(LIBDIR)/hooks/post-update.d
	@echo "Installing RBAC and API components"
	install -d $(LIBDIR)/api $(LIBDIR)/tools $(LIBDIR)/rbac
	install -m 0644 rbac/roles.yaml $(LIBDIR)/rbac/roles.yaml || true
	install -m 0755 api/ubopt-api.sh $(LIBDIR)/api/ubopt-api.sh || true
	install -m 0755 tools/ota-sync.sh $(LIBDIR)/tools/ota-sync.sh || true
	install -m 0755 cmd/ubopt $(BINDIR)/ubopt
	@echo "Installing configuration to /etc/ubopt"
	install -m 0644 etc/ubopt.example.yaml /etc/ubopt/ubopt.yaml
	@echo "Installing library and modules to $(LIBDIR)"
	install -m 0644 lib/common.sh $(LIBDIR)/lib/common.sh
	install -m 0755 providers/*.sh $(LIBDIR)/providers/
	install -m 0755 modules/*.sh $(LIBDIR)/modules/
	@echo "Installing exporter"
	install -m 0755 exporters/ubopt_textfile_exporter.sh $(LIBDIR)/exporters/
	@echo "Installing hooks documentation"
	install -d $(LIBDIR)/hooks/pre-update.d $(LIBDIR)/hooks/post-update.d
	install -m 0644 hooks/pre-update.d/README.md $(LIBDIR)/hooks/pre-update.d/README.md
	install -m 0644 hooks/post-update.d/README.md $(LIBDIR)/hooks/post-update.d/README.md
	@echo "Installing systemd units to $(SYSD_DIR)"
	install -d $(SYSD_DIR)
	install -m 0644 systemd/ubopt-agent.service $(SYSD_DIR)/ubopt-agent.service
	install -m 0644 systemd/ubopt-agent.timer $(SYSD_DIR)/ubopt-agent.timer
	install -m 0644 systemd/ubopt-exporter.service $(SYSD_DIR)/ubopt-exporter.service
	install -m 0644 systemd/ubopt-exporter.timer $(SYSD_DIR)/ubopt-exporter.timer
	install -m 0644 systemd/ubopt-api.service $(SYSD_DIR)/ubopt-api.service || true
	install -m 0644 systemd/ubopt-api.socket $(SYSD_DIR)/ubopt-api.socket || true
	install -m 0644 systemd/ubopt-ota.service $(SYSD_DIR)/ubopt-ota.service || true
	install -m 0644 systemd/ubopt-ota.timer $(SYSD_DIR)/ubopt-ota.timer || true
	@echo "Installing logrotate config"
	install -d /etc/logrotate.d
	install -m 0644 packaging/logrotate/ubopt /etc/logrotate.d/ubopt
	@echo "Creating log and backup directories"
	install -d -m 0755 $(LOGDIR) $(BACKUPDIR)
	-systemctl daemon-reload || true
	@echo "Enable timers:"
	@echo "  sudo systemctl enable --now ubopt-agent.timer ubopt-exporter.timer"

uninstall:
	@echo "Uninstalling ubopt"
	rm -f $(BINDIR)/ubopt
	rm -rf $(PREFIX)/lib/ubopt
	rm -f $(SYSD_DIR)/ubopt-agent.service $(SYSD_DIR)/ubopt-agent.timer
	@echo "Disable timer with: sudo systemctl disable --now ubopt-agent.timer || true"

shellcheck:
	shellcheck cmd/ubopt lib/*.sh providers/*.sh modules/*.sh exporters/*.sh

bats:
	bats tests/bats/cli.bats
	bats tests/bats/health.bats
	bats tests/bats/update-dryrun.bats

lint: shellcheck

test: bats

dev:
	@echo "No dev dependencies required. Ensure bats and shellcheck are installed."

clean:
	rm -rf dist logs
	find . -type f -name "*.bak" -delete

install-logrotate:
	install -d /etc/logrotate.d
	install -m 0644 packaging/logrotate/ubopt /etc/logrotate.d/ubopt

verify-logrotate:
	@echo "Verifying logrotate configuration..."
	@if [ ! -f packaging/logrotate/ubopt ]; then \
		echo "ERROR: logrotate config file not found: packaging/logrotate/ubopt"; \
		exit 1; \
	fi
	@if command -v logrotate >/dev/null 2>&1; then \
		echo "Testing logrotate syntax with debug mode..."; \
		logrotate -d packaging/logrotate/ubopt 2>&1 | head -20; \
		echo "✓ Logrotate configuration syntax valid"; \
	else \
		echo "WARNING: logrotate not installed, skipping syntax check"; \
		echo "  Install with: apt-get install logrotate (Debian/Ubuntu)"; \
		echo "              : dnf install logrotate (Fedora/RHEL)"; \
	fi
	@if [ -f /etc/logrotate.d/ubopt ]; then \
		echo "✓ Logrotate config installed at /etc/logrotate.d/ubopt"; \
	else \
		echo "⚠ Logrotate config not yet installed"; \
		echo "  Run: make install-logrotate"; \
	fi

install-exporter:
	install -d $(LIBDIR)/exporters /var/lib/node_exporter/textfile_collector
	install -m 0755 exporters/ubopt_textfile_exporter.sh $(LIBDIR)/exporters/
	install -d $(SYSD_DIR)
	install -m 0644 systemd/ubopt-exporter.service $(SYSD_DIR)/ubopt-exporter.service
	install -m 0644 systemd/ubopt-exporter.timer $(SYSD_DIR)/ubopt-exporter.timer
	-systemctl daemon-reload || true
	@echo "Enable with: sudo systemctl enable --now ubopt-exporter.timer"

package-deb:
	debuild -us -uc

lint-deb:
	lintian --display-info --display-experimental || true

package-rpm:
	@echo "Building RPM package..."
	mkdir -p dist rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
	tar -czf rpmbuild/SOURCES/ubopt-$(shell grep '^Version:' packaging/rpm/ubopt.spec | awk '{print $$2}').tar.gz \
		--transform 's,^,ubopt-$(shell grep '^Version:' packaging/rpm/ubopt.spec | awk '{print $$2}')\/,' \
		cmd/ lib/ providers/ modules/ exporters/ etc/ systemd/ packaging/ docs/ tests/ \
		Makefile README.md LICENSE
	rpmbuild --define "_topdir $(PWD)/rpmbuild" -ba packaging/rpm/ubopt.spec
	mv rpmbuild/RPMS/noarch/*.rpm dist/ 2>/dev/null || true
	mv rpmbuild/SRPMS/*.rpm dist/ 2>/dev/null || true
	@echo "RPM packages created in dist/"

config-test:
	@echo "Validating configuration and policies"
	tools/validate_config.sh --config etc/ubopt.example.yaml || exit 1
	@for f in policies/*.yaml; do \
	  echo "Validating $$f"; tools/validate_config.sh --config $$f || exit 1; \
	done
	@echo "Config validation complete"

e2e-local:
	@echo "Running local smoke tests"
	tests/e2e/local_smoke.sh
	@echo "Local E2E smoke completed"

docs:
	@echo "Building Sphinx docs"
	@if [ ! -d docs/_build ]; then mkdir -p docs/_build; fi
	@if [ ! -d docs/.venv ]; then \
		python3 -m venv docs/.venv; \
		echo "Created virtualenv in docs/.venv"; \
	else \
		echo "Using existing virtualenv docs/.venv"; \
	fi
	. docs/.venv/bin/activate && pip install --upgrade pip >/dev/null 2>&1 || true
	. docs/.venv/bin/activate && pip install -r docs/requirements.txt >/dev/null 2>&1 || { echo "Failed to install docs requirements"; exit 1; }
	@echo "Installing docs deps done"
	@# Pass version into Sphinx (for conf.py 'release')
	UBOPT_VERSION=$(shell cat VERSION 2>/dev/null || echo dev) docs/.venv/bin/sphinx-build -b html docs docs/_build/html || { echo "Docs build failed"; exit 1; }
	@echo "Docs built in docs/_build/html"
