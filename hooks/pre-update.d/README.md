# Pre-Update Hooks

Place executable `*.sh` scripts here to run BEFORE package updates.
Execution order: lexical sort (0-*, 10-*, etc.).
Behavior:
- Non-zero exit status ABORTS the update process.
- Scripts run with root privileges (if update not in --dry-run).
- In dry-run mode, scripts are listed but not executed.

Example:
```bash
#!/usr/bin/env bash
# 00-check-disk.sh
set -Eeuo pipefail
FREE=$(df -P / | awk 'NR==2{print $4}')
if [[ $FREE -lt 500000 ]]; then
  echo "Insufficient disk space for update" >&2
  exit 1
fi
```
