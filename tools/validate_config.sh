#!/usr/bin/env bash
set -Eeuo pipefail

# Simple YAML validator for ubopt configs
# - Validates required keys exist
# - Validates enums for some keys
# - Emits JSON lines with errors to stdout
# - Exits non-zero on invalid input
# No external network; uses POSIX tools only.

usage() {
  cat <<EOF
Usage: $0 --config FILE | --dir DIR

Validates ubopt YAML config(s).
Emits JSON lines: {"file":"...","error":"...","key":"..."}
EOF
}

CONFIG=""
DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"; shift 2;;
    --dir)
      DIR="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo '{"error":"unknown_argument","arg":"'$1'"}'
      exit 2;;
  esac
done

if [[ -z "$CONFIG" && -z "$DIR" ]]; then
  usage; exit 2
fi

# Required keys and enum constraints
required_keys=(
  "updates.schedule"
  "updates.reboot"
  "hardening.ssh"
  "hardening.firewall"
  "report.targets"
  "logging.level"
)

declare -A enum_sets
enum_sets[updates.reboot]="never when-required always"
enum_sets[logging.level]="debug info warn error"

# Load a YAML file and check key existence using naive grep/awk
validate_file() {
  local file="$1"
  local invalid=0
  # Normalize to key paths using awk (naive: supports 2-level nested + arrays)
  # We'll check existence with grep -q for simple patterns.
  for key in "${required_keys[@]}"; do
    IFS='.' read -r k1 k2 <<<"$key"
    case "$key" in
      *.targets)
        if ! grep -Eq "^${k1}:[[:space:]]*$" "$file" && ! grep -Eq "^${k1}:" "$file"; then
          echo '{"file":"'$file'","error":"missing_key","key":"'$key'"}'; invalid=1
        fi
        ;;
      *)
        if ! grep -Eq "^${k1}:[[:space:]]*" "$file"; then
          echo '{"file":"'$file'","error":"missing_section","key":"'$k1'"}'; invalid=1
        elif ! grep -Eq "^[[:space:]]{2}${k2}:[[:space:]]*" "$file"; then
          echo '{"file":"'$file'","error":"missing_key","key":"'$key'"}'; invalid=1
        fi
        ;;
    esac
  done

  # Enum checks
  for k in "${!enum_sets[@]}"; do
    IFS='.' read -r p1 p2 <<<"$k"
    # Extract value (naive: key: value on a single line)
    local val
    val=$(awk -v p2="$p2" 'match($0, /^[[:space:]]{2}/){ if ($1==p2":") { $1=""; sub(/^\s+/, ""); print; exit } }' "$file" | head -n1)
    # Fallback generic grep if awk misses
    if [[ -z "$val" ]]; then
      val=$(grep -E "^[[:space:]]{2}${p2}:[[:space:]]*" "$file" | head -n1 | sed -E 's/^[[:space:]]{2}'"${p2}"':[[:space:]]*//')
    fi
    # Trim leading/trailing whitespace
    val=$(echo "$val" | xargs)
    if [[ -n "$val" ]]; then
      local allowed=" ${enum_sets[$k]} "
      if [[ "$allowed" != *" $val "* ]]; then
        echo '{"file":"'$file'","error":"invalid_enum","key":"'$k'","value":"'"$val"'"}'
        invalid=1
      fi
    fi
  done

  return $invalid
}

status=0
if [[ -n "$CONFIG" ]]; then
  validate_file "$CONFIG" || status=1
fi
if [[ -n "$DIR" ]]; then
  shopt -s nullglob
  for f in "$DIR"/*.yaml "$DIR"/*.yml; do
    validate_file "$f" || status=1
  done
fi

exit $status
