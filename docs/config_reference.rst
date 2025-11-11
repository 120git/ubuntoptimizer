Configuration Reference
=======================

This document enumerates the primary keys available in `/etc/ubopt/ubopt.yaml` and their behavior.

General
-------
`general.verbose` (bool)
  Enable verbose terminal output.
`general.auto_backup` (bool)
  Perform backup before state‑changing operations.

Updates
-------
`updates.schedule` (string)
  `daily|weekly|cron expression` controlling timer cadence.
`updates.reboot` (string)
  `never|when-required|always`.
`updates.auto_check` (bool)
  Automatic background update checks.
`updates.auto_apply_security` (bool)
`updates.auto_apply_all` (bool)

Hardening
---------
`hardening.ssh.enabled` (bool)
`hardening.ssh.port` (int)
`hardening.ssh.password_auth` (bool)
`hardening.ssh.root_login` (bool)
`hardening.ssh.key_only` (bool)
`hardening.auditd.enabled` (bool)
`hardening.auditd.rules[]` (array of paths)
`hardening.auditd.suid_monitoring` (bool)
`hardening.mandatory_access_control.enabled` (bool)
`hardening.mandatory_access_control.mode` (string) `enforce|complain`

Backup
------
`backup.dest` (path)
`backup.includes[]` (array of paths)
`backup.excludes[]` (array of paths)
`backup.compression` (string) `gz|xz|zstd|none`
`backup.mode` (string) `tar|rsync`
`backup.retention.count` (int)
`backup.retention.days` (int)

Benchmark
---------
`benchmark.duration` (int seconds)
`benchmark.format` (`text|json`)
`benchmark.cpu.threads` (int) 0=auto
`benchmark.disk.size_mb` (int)

Report
------
`report.targets[]` (`stdout|file`)
`report.sections[]` (`system_info|updates|hardening|health|benchmark`)

Logging
-------
`logging.level` (`debug|info|warn|error`)
`logging.directory` (path)
`logging.json` (bool) – Log file JSON line format.
`logging.syslog` (bool) – Mirror messages to syslog.

Monitoring
----------
`monitoring.enabled` (bool)
`monitoring.check_interval` (minutes)
`monitoring.thresholds.disk_usage_percent` (int)
`monitoring.thresholds.memory_usage_percent` (int)
`monitoring.thresholds.cpu_load_multiplier` (float)
`monitoring.thresholds.updates_overdue_days` (int)

Notes
-----
- Unknown keys are ignored; they do not produce errors.
- Array values are exposed via `cfg_get_array` in modules.
- Dry-run pathways never mutate system files; exit code 20 signals planned change.
