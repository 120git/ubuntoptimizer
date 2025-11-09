#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# shellcheck source=../modules/health.sh
source "${SCRIPT_DIR}/modules/health.sh"

report_main() {
  local state_dir="/var/lib/ubopt"
  local state_file="${state_dir}/state.json"
  local out_json

  # Health JSON
  local health_json
  health_json=$(health_check json || echo '{}')

  # Updates summary (minimal placeholder)
  local provider="${UBOPT_PROVIDER:-unknown}"
  local distro="${UBOPT_DISTRO:-unknown}"
  local checked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local updates_json
  updates_json=$(printf '{"provider":"%s","distro":"%s","checked_at":"%s"}' "${provider}" "${distro}" "${checked_at}")

  # Hardening summary (heuristic + timestamp if available)
  local hardening_status
  if grep -q "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    hardening_status=enabled
  else
    hardening_status=unknown
  fi
  local last_hardening_timestamp=""
  if [[ -f "${state_file}" ]] && command -v jq &>/dev/null; then
    last_hardening_timestamp=$(jq -r '.last_hardening_timestamp // empty' "${state_file}" || true)
  fi
  local hardening_json
  if [[ -n "${last_hardening_timestamp}" ]]; then
    hardening_json=$(printf '{"ssh":"%s","last_hardening_timestamp":"%s"}' "$hardening_status" "$last_hardening_timestamp")
  else
    hardening_json=$(printf '{"ssh":"%s"}' "$hardening_status")
  fi

  # Snapshot metadata if present from update module
  local last_update_snapshot=""
  if [[ -f "${state_file}" ]] && command -v jq &>/dev/null; then
    last_update_snapshot=$(jq -r '.last_snapshot // empty' "${state_file}" || true)
  fi
  local snapshot_json
  if [[ -n "${last_update_snapshot}" ]]; then
    snapshot_json=$(printf '{"last_update_snapshot":"%s"}' "${last_update_snapshot}")
  else
    snapshot_json='{}'
  fi

  out_json=$(printf '{"hardening":%s,"updates":%s,"health":%s,"snapshot":%s}' "${hardening_json}" "${updates_json}" "${health_json}" "${snapshot_json}")
  echo "${out_json}"

  # Merge and persist enriched state if not dry-run
  if [[ "${UBOPT_DRY_RUN}" != "true" ]]; then
    if mkdir -p "${state_dir}" 2>/dev/null; then
      if command -v jq &>/dev/null && [[ -f "${state_file}" ]]; then
        # Merge preserving existing keys, updating hardening/updates/health/snapshot sections
        local merged
        merged=$(jq -c \
          --argjson new "${out_json}" \
          '.hardening=$new.hardening | .updates=$new.updates | .health=$new.health | .snapshot=$new.snapshot | .provider=$new.updates.provider | .distro=$new.updates.distro' \
          "${state_file}" 2>/dev/null || echo "${out_json}")
        echo "${merged}" > "${state_file}" 2>/dev/null || true
      else
        echo "${out_json}" > "${state_file}" 2>/dev/null || true
      fi
    fi
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  report_main "$@"
fi
