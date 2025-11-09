.PHONY: install uninstall test dev lint shellcheck bats ci clean install-logrotate install-exporter package-deb lint-deb

# FHS-compliant defaults for packaging
PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/ubopt
SYSD_DIR := /usr/lib/systemd/system
LOGDIR := /var/log/ubopt
BACKUPDIR := /var/backups/ubopt

install:
	@echo "Installing ubopt CLI to $(BINDIR)"
	install -d $(BINDIR) /etc/ubopt /var/lib/ubopt $(LIBDIR) $(LIBDIR)/lib $(LIBDIR)/providers $(LIBDIR)/modules $(LIBDIR)/exporters
	install -m 0755 cmd/ubopt $(BINDIR)/ubopt
	@echo "Installing configuration to /etc/ubopt"
	install -m 0644 etc/ubopt.example.yaml /etc/ubopt/ubopt.yaml
	@echo "Installing library and modules to $(LIBDIR)"
	install -m 0644 lib/common.sh $(LIBDIR)/lib/common.sh
	install -m 0755 providers/*.sh $(LIBDIR)/providers/
	install -m 0755 modules/*.sh $(LIBDIR)/modules/
	@echo "Installing exporter"
	install -m 0755 exporters/ubopt_textfile_exporter.sh $(LIBDIR)/exporters/
	@echo "Installing systemd units to $(SYSD_DIR)"
	install -d $(SYSD_DIR)
	install -m 0644 systemd/ubopt-agent.service $(SYSD_DIR)/ubopt-agent.service
	install -m 0644 systemd/ubopt-agent.timer $(SYSD_DIR)/ubopt-agent.timer
	install -m 0644 systemd/ubopt-exporter.service $(SYSD_DIR)/ubopt-exporter.service
	install -m 0644 systemd/ubopt-exporter.timer $(SYSD_DIR)/ubopt-exporter.timer
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
