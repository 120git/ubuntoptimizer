.PHONY: install uninstall test dev lint shellcheck bats ci clean

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin
SYSD_DIR := /etc/systemd/system
LOGDIR := /var/log/ubopt
BACKUPDIR := /var/backups/ubopt

install:
	@echo "Installing ubopt CLI to $(BINDIR)"
	install -d $(BINDIR)
	install -m 0755 cmd/ubopt $(BINDIR)/ubopt
	@echo "Installing library and modules to $(PREFIX)/lib/ubopt"
	install -d $(PREFIX)/lib/ubopt/lib $(PREFIX)/lib/ubopt/providers $(PREFIX)/lib/ubopt/modules
	install -m 0644 lib/common.sh $(PREFIX)/lib/ubopt/lib/common.sh
	install -m 0644 providers/*.sh $(PREFIX)/lib/ubopt/providers/
	install -m 0644 modules/*.sh $(PREFIX)/lib/ubopt/modules/
	@echo "Installing configuration example to /etc/ubopt"
	install -d /etc/ubopt
	install -m 0644 etc/ubopt.example.yaml /etc/ubopt/config.yaml.example
	@echo "Installing systemd units"
	install -m 0644 systemd/ubopt-agent.service $(SYSD_DIR)/ubopt-agent.service
	install -m 0644 systemd/ubopt-agent.timer $(SYSD_DIR)/ubopt-agent.timer
	@echo "Creating log and backup directories"
	install -d -m 0755 $(LOGDIR) $(BACKUPDIR)
	@echo "Enable timer with: sudo systemctl enable --now ubopt-agent.timer"

uninstall:
	@echo "Uninstalling ubopt"
	rm -f $(BINDIR)/ubopt
	rm -rf $(PREFIX)/lib/ubopt
	rm -f $(SYSD_DIR)/ubopt-agent.service $(SYSD_DIR)/ubopt-agent.timer
	@echo "Disable timer with: sudo systemctl disable --now ubopt-agent.timer || true"

shellcheck:
	shellcheck cmd/ubopt lib/common.sh providers/*.sh modules/*.sh

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
