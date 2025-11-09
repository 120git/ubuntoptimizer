Name:           ubopt
Version:        0.1.0
Release:        1%{?dist}
Summary:        Cool Llama LinuxOptimizer CLI and agent

License:        MIT
URL:            https://github.com/120git/ubuntoptimizer
Source0:        ubopt-%{version}.tar.gz

BuildArch:      noarch
Requires:       bash >= 4.0
Requires:       coreutils
Requires:       systemd

%description
Cool Llama LinuxOptimizer (ubopt) is a modular Linux security and updater
suite providing CLI, systemd agent, Prometheus exporter, and logrotate
integration.

%prep
%setup -q

%build
# No build required for bash scripts

%install
# Create directory structure
install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_prefix}/lib/ubopt/lib
install -d %{buildroot}%{_prefix}/lib/ubopt/providers
install -d %{buildroot}%{_prefix}/lib/ubopt/modules
install -d %{buildroot}%{_prefix}/lib/ubopt/exporters
install -d %{buildroot}%{_sysconfdir}/ubopt
install -d %{buildroot}%{_sysconfdir}/logrotate.d
install -d %{buildroot}%{_unitdir}
install -d %{buildroot}%{_localstatedir}/log/ubopt
install -d %{buildroot}%{_localstatedir}/lib/ubopt

# Install binary
install -m 0755 cmd/ubopt %{buildroot}%{_bindir}/ubopt

# Install libraries and modules
install -m 0644 lib/common.sh %{buildroot}%{_prefix}/lib/ubopt/lib/common.sh
install -m 0755 providers/*.sh %{buildroot}%{_prefix}/lib/ubopt/providers/
install -m 0755 modules/*.sh %{buildroot}%{_prefix}/lib/ubopt/modules/
install -m 0755 exporters/ubopt_textfile_exporter.sh %{buildroot}%{_prefix}/lib/ubopt/exporters/

# Install configuration
install -m 0644 etc/ubopt.example.yaml %{buildroot}%{_sysconfdir}/ubopt/ubopt.yaml

# Install systemd units
install -m 0644 systemd/ubopt-agent.service %{buildroot}%{_unitdir}/ubopt-agent.service
install -m 0644 systemd/ubopt-agent.timer %{buildroot}%{_unitdir}/ubopt-agent.timer
install -m 0644 systemd/ubopt-exporter.service %{buildroot}%{_unitdir}/ubopt-exporter.service
install -m 0644 systemd/ubopt-exporter.timer %{buildroot}%{_unitdir}/ubopt-exporter.timer

# Install logrotate config
install -m 0644 packaging/logrotate/ubopt %{buildroot}%{_sysconfdir}/logrotate.d/ubopt

%files
%license LICENSE
%doc README.md
%{_bindir}/ubopt
%{_prefix}/lib/ubopt/
%config(noreplace) %{_sysconfdir}/ubopt/ubopt.yaml
%{_sysconfdir}/logrotate.d/ubopt
%{_unitdir}/ubopt-agent.service
%{_unitdir}/ubopt-agent.timer
%{_unitdir}/ubopt-exporter.service
%{_unitdir}/ubopt-exporter.timer
%dir %{_localstatedir}/log/ubopt
%dir %{_localstatedir}/lib/ubopt

%post
# Reload systemd and enable timers (best-effort)
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable ubopt-agent.timer >/dev/null 2>&1 || true
systemctl enable ubopt-exporter.timer >/dev/null 2>&1 || true
systemctl start ubopt-agent.timer >/dev/null 2>&1 || true
systemctl start ubopt-exporter.timer >/dev/null 2>&1 || true

%preun
# Stop and disable timers before removal
if [ $1 -eq 0 ]; then
  systemctl stop ubopt-agent.timer >/dev/null 2>&1 || true
  systemctl stop ubopt-exporter.timer >/dev/null 2>&1 || true
  systemctl disable ubopt-agent.timer >/dev/null 2>&1 || true
  systemctl disable ubopt-exporter.timer >/dev/null 2>&1 || true
fi

%postun
# Reload systemd after removal
if [ $1 -eq 0 ]; then
  systemctl daemon-reload >/dev/null 2>&1 || true
fi

%changelog
* Sat Nov 08 2025 Cool Llama <team@cool-llama.dev> - 0.1.0-1
- Initial RPM packaging of ubopt
- CLI, agent, exporter, logrotate integration
