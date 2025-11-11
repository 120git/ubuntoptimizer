Usage Guide
===========

CLI Entrypoint
--------------
Use the `ubopt` command or run module scripts directly.

Examples:
- Health JSON: ``ubopt health --json``
- Update check (dry-run): ``ubopt update check --dry-run``
- Backup (dry-run): ``ubopt backup create --dry-run``
- Benchmark JSON: ``ubopt benchmark --tests cpu,disk --duration 10 --format json``
- Hardening (dry-run): ``ubopt hardening apply --dry-run``

Help Snapshot
-------------
The build captures CLI help at docs build time here::

  docs/_generated/ubopt_help.txt

Configuration
-------------
Copy `etc/ubopt.example.yaml` to `/etc/ubopt/ubopt.yaml` and adjust to your needs.
See :doc:`config_reference` for available keys.

Dry-Run Convention
------------------
Commands that would change state accept `--dry-run` and exit with code 20 to indicate a plan without making changes.

Logging
-------
Logs go to `/var/log/ubopt/ubopt.log` or fallback to `./logs/ubopt.log` when not writable.
Use `UBOPT_VERBOSE=true` for additional terminal output.
