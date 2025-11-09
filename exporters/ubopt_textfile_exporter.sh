#!/usr/bin/env bash
set -Eeuo pipefail

# Textfile exporter writes metrics for node_exporter to scrape from disk.
# Default path aligns with Node Exporter textfile collector conventions.
OUT_DIR="${UBOPT_EXPORTER_OUT_DIR:-/var/lib/node_exporter/textfile_collector}"
OUT_FILE="${OUT_DIR}/ubopt.prom"

mkdir -p "$OUT_DIR"

ts="$(date -u +%s)"
host="$(hostname)"
kernel="$(uname -r)"
os="$({ . /etc/os-release 2>/dev/null || true; echo "${PRETTY_NAME:-$NAME:-unknown}"; })"
root_used="$(df -P / | awk 'NR==2{gsub(/%/,"",$5); print $5}')"

{
  echo "# HELP ubopt_info Static information about host from ubopt."
  echo "# TYPE ubopt_info gauge"
  echo "ubopt_info{host=\"${host}\",kernel=\"${kernel}\",os=\"${os}\"} 1"

  echo "# HELP ubopt_root_fs_used_percent Root filesystem used percent."
  echo "# TYPE ubopt_root_fs_used_percent gauge"
  echo "ubopt_root_fs_used_percent ${root_used}"

  echo "# HELP ubopt_last_export_epoch Time when exporter last ran."
  echo "# TYPE ubopt_last_export_epoch gauge"
  echo "ubopt_last_export_epoch ${ts}"
} > "${OUT_FILE}.tmp"

mv "${OUT_FILE}.tmp" "${OUT_FILE}"
