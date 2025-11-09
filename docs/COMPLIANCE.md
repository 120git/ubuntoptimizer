# Compliance Mapping

This document maps implemented ubopt controls to common CIS-style categories to help auditors and operators understand coverage. It is advisory and evolves with the tool.

## Scope
- Distros: Debian/Ubuntu, Fedora/CentOS/RHEL, Arch (best-effort)
- Surfaces: OS configuration hardening, update management, logging/observability

## Control Mapping

### 1.1 System Updates and Patch Management
- What: `modules/update.sh` supports check/apply/full update flows with provider abstraction (APT/DNF/Pacman).
- Evidence: `ubopt report` JSON includes update status and timestamps; state persisted at `/var/lib/ubopt/state.json`.
- Automation: Systemd timers (`systemd/`) for periodic checks; Prometheus textfile exporter exposes metrics for pending updates.
- Rollback readiness: Best-effort pre-update snapshot for Btrfs/ZFS; pre/post hooks for quiesce/validation.

### 1.2 Secure Configuration Baseline
- What: `modules/hardening.sh` applies baseline SSH, sysctl, firewall hardening where applicable.
- Idempotency: Logs `idempotency changed=<true|false>`; reruns should be no-op.
- Policies: `policies/*.yaml` define policy packs; `tools/validate_config.sh` validates keys and enums.

### 1.3 Logging and Auditing
- What: Central `lib/log.sh` logging with rotation (logrotate config) and Prometheus exporter in `exporters/`.
- Evidence: Logs under `/var/log/ubopt`; metrics in `/var/lib/node_exporter/textfile_collector/` where configured.

### 1.4 Access and Remote Services
- What: SSH hardening (Protocol, Kex, MACs, root login) enforced by `modules/hardening.sh` based on policy.
- Evidence: `ubopt report` includes hardening status. Config backups created prior to change where supported.

### 1.5 System Integrity and Recovery
- What: Pre-update snapshot (Btrfs/ZFS) via `modules/update.sh` with metadata recorded to state; pre/post hooks allow consistency checks and application-specific recovery steps.

### 1.6 Monitoring and Alerting
- What: Prometheus metrics via textfile exporter; Grafana dashboard (`grafana/dashboards/ubopt-overview.json`).
- Alerts: See `prometheus/alerts/ubopt-rules.yaml` for example alerting rules.

## Artifacts and Evidence
- JSON state: `/var/lib/ubopt/state.json`
- Reports: `ubopt report` (stdout JSON)
- Logs: `/var/log/ubopt/*.log`
- Metrics: textfile collector directory
- Packaging: Debian and RPM packages with SBOMs and signed releases

## Limitations
- Policy enforcement is best-effort and may vary by distro/version.
- Snapshot creation requires Btrfs or ZFS and appropriate permissions.
- Some hardening items require manual validation in air-gapped or heavily customized environments.

## Change Management
- Release notes: `CHANGELOG.md` (Conventional Commits)
- CI: Multi-distro matrix containers run smoke tests; configuration validation in CI with `tools/validate_config.sh`.
