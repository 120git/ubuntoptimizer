# Post-Update Hooks

Place executable `*.sh` scripts here to run AFTER package updates.
Execution order: lexical sort.
Behavior:
- Non-zero exit status is logged as a WARNING; update continues.
- Scripts run with root privileges (if update not in --dry-run).
- In dry-run mode, scripts are listed but not executed.

Example:
```bash
#!/usr/bin/env bash
# 90-notify.sh
set -Eeuo pipefail
echo "Update completed on $(hostname) at $(date -u +%FT%TZ)" | systemd-cat -t ubopt
```
