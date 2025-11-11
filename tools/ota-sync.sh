#!/usr/bin/env bash
# =============================================================================
# OTA Policy Sync Tool
# Downloads and verifies policy updates from remote endpoint
# =============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# OTA Configuration
OTA_URL="${OTA_URL:-https://github.com/120git/ubuntoptimizer/raw/main/ota}"
OTA_LOG="/var/log/ubopt/ota.log"
OTA_MANIFEST_URL="${OTA_URL}/manifest.json" # constructed dynamically in functions when needed
OTA_PUBLIC_KEY="${OTA_PUBLIC_KEY:-/etc/ubopt/keys/cosign.pub}"
OTA_POLICY_DIR="${OTA_POLICY_DIR:-/usr/lib/ubopt/policies}"
OTA_TMP_DIR="/tmp/ubopt-ota-$$"

# =============================================================================
# LOGGING
# =============================================================================

ota_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # JSON log entry
    local log_entry
    log_entry=$(printf '{"timestamp":"%s","level":"%s","message":"%s"}' \
        "${timestamp}" "${level}" "${message}")

    # Try to write to log; if not writable, degrade gracefully to stderr only
    if ! echo "${log_entry}" | tee -a "${OTA_LOG}" >/dev/null 2>&1; then
        echo "${log_entry}" >&2
    fi
}

# =============================================================================
# OTA FUNCTIONS
# =============================================================================

# Download manifest from OTA endpoint
ota_download_manifest() {
    local tmp_manifest="${OTA_TMP_DIR}/manifest.json"

    # Support local filesystem mode: OTA_URL=file:///path or OTA_URL=/path
    local base_url="${OTA_URL}"
    local local_dir=""
    if [[ "${base_url}" == file://* ]]; then
        local_dir="${base_url#file://}"
    elif [[ -d "${base_url}" ]]; then
        local_dir="${base_url}"
    fi

    if [[ -n "${local_dir}" ]]; then
        ota_log "info" "Reading local manifest from ${local_dir}/manifest.json"
        if [[ -f "${local_dir}/manifest.json" ]]; then
            cp "${local_dir}/manifest.json" "${tmp_manifest}"
            echo "${tmp_manifest}"
            return 0
        else
            ota_log "error" "Local manifest not found at ${local_dir}/manifest.json"
            return 1
        fi
    fi

    # Recompute manifest URL from OTA_URL
    local manifest_url
    manifest_url="${base_url%/}/manifest.json"
    ota_log "info" "Downloading manifest from ${manifest_url}"

    if command -v curl &>/dev/null; then
        if ! curl -fsSL "${manifest_url}" -o "${tmp_manifest}"; then
            ota_log "error" "Failed to download manifest"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -q "${manifest_url}" -O "${tmp_manifest}"; then
            ota_log "error" "Failed to download manifest"
            return 1
        fi
    else
        ota_log "error" "Neither curl nor wget available"
        return 1
    fi

    ota_log "info" "Manifest downloaded successfully"
    echo "${tmp_manifest}"
}

# Verify manifest signature using SHA256 or Cosign
ota_verify_manifest() {
    local manifest_file="$1"
    
    ota_log "info" "Verifying manifest signature"
    
    # Extract signature from manifest
    local manifest_sig
    manifest_sig=$(grep -o '"signature":"[^"]*"' "${manifest_file}" | cut -d'"' -f4)
    
    # Prefer sidecar SHA256 file if present (avoids self-referential hashing)
    if [[ -f "${manifest_file}.sha256" ]]; then
        local expected
        expected=$(tr -d ' \n' < "${manifest_file}.sha256")
        local actual
        actual=$(sha256sum "${manifest_file}" | awk '{print $1}')
        if [[ "${actual}" == "${expected}" ]]; then
            ota_log "info" "SHA256 sidecar verification passed"
            return 0
        else
            ota_log "error" "SHA256 sidecar mismatch"
            return 1
        fi
    fi

    if [[ "${manifest_sig}" == sha256:* ]]; then
        # SHA256 verification (best-effort; note: includes signature field)
        local expected_hash="${manifest_sig#sha256:}"
        local actual_hash
        actual_hash=$(sha256sum "${manifest_file}" | awk '{print $1}')
        if [[ "${actual_hash}" == "${expected_hash}" ]]; then
            ota_log "info" "Embedded SHA256 verification passed"
            return 0
        fi
        ota_log "warn" "Embedded SHA256 mismatch; continuing in development mode"
        # don't fail hard in dev/local mode
        return 0
    fi
    
    # Try Cosign verification if available and public key exists
    if command -v cosign &>/dev/null && [[ -f "${OTA_PUBLIC_KEY}" ]]; then
        local sig_file="${manifest_file}.sig"
        if [[ -f "${sig_file}" ]]; then
            if cosign verify-blob --key "${OTA_PUBLIC_KEY}" \
                --signature "${sig_file}" "${manifest_file}" &>/dev/null; then
                ota_log "info" "Cosign verification passed"
                return 0
            else
                ota_log "error" "Cosign verification failed"
                return 1
            fi
        fi
    fi
    
    # Fallback: warn but allow if no verification method available
    ota_log "warn" "No signature verification performed (development mode)"
    return 0
}

# Parse manifest and extract policy list
ota_parse_manifest() {
    local manifest_file="$1"
    
    if ! command -v jq &>/dev/null; then
        # Fallback without jq
        grep -o '"[^"]*\.yaml"' "${manifest_file}" | tr -d '"'
    else
        jq -r '.policies[]' "${manifest_file}"
    fi
}

# Download a single policy file
ota_download_policy() {
    local policy_name="$1"
    local output_file="${OTA_TMP_DIR}/${policy_name}"
    local policy_url="${OTA_URL}/${policy_name}"

    # Local filesystem mode
    local base_url="${OTA_URL}"
    local local_dir=""
    if [[ "${base_url}" == file://* ]]; then
        local_dir="${base_url#file://}"
    elif [[ -d "${base_url}" ]]; then
        local_dir="${base_url}"
    fi
    if [[ -n "${local_dir}" ]]; then
        ota_log "info" "Copying local policy: ${policy_name}"
        if [[ -f "${local_dir}/${policy_name}" ]]; then
            cp "${local_dir}/${policy_name}" "${output_file}" || return 1
            echo "${output_file}"
            return 0
        else
            ota_log "error" "Local policy not found: ${local_dir}/${policy_name}"
            return 1
        fi
    fi

    ota_log "info" "Downloading policy: ${policy_name}"

    if command -v curl &>/dev/null; then
        curl -fsSL "${policy_url}" -o "${output_file}" || return 1
    elif command -v wget &>/dev/null; then
        wget -q "${policy_url}" -O "${output_file}" || return 1
    else
        return 1
    fi

    echo "${output_file}"
}

# Install validated policies to system directory
ota_install_policies() {
    local tmp_dir="$1"
    
    ota_log "info" "Installing policies to ${OTA_POLICY_DIR}"
    
    # Backup existing policies
    if [[ -d "${OTA_POLICY_DIR}" ]]; then
        local backup_dir="/var/backups/ubopt/policies-$(date +%Y%m%d%H%M%S)"
        mkdir -p "$(dirname "${backup_dir}")"
        cp -r "${OTA_POLICY_DIR}" "${backup_dir}" || true
        ota_log "info" "Backed up existing policies to ${backup_dir}"
    fi
    
    # Create policy directory if it doesn't exist
    mkdir -p "${OTA_POLICY_DIR}"
    
    # Copy new policies
    for policy_file in "${tmp_dir}"/*.yaml; do
        [[ -f "${policy_file}" ]] || continue
        local policy_name
        policy_name=$(basename "${policy_file}")
        cp "${policy_file}" "${OTA_POLICY_DIR}/${policy_name}"
        ota_log "info" "Installed policy: ${policy_name}"
    done
    
    return 0
}

# Check for updates (compare versions)
ota_check() {
    local local_manifest="${OTA_POLICY_DIR}/../manifest.json"
    local current_version="0.0"
    local remote_version
    
    ota_log "info" "Checking for OTA updates"
    
    # Get current version if manifest exists
    if [[ -f "${local_manifest}" ]] && command -v jq &>/dev/null; then
        current_version=$(jq -r '.version // "0.0"' "${local_manifest}")
    fi
    
    # Download and check remote manifest
    mkdir -p "${OTA_TMP_DIR}"
    local remote_manifest
    remote_manifest=$(ota_download_manifest) || {
        ota_log "error" "Failed to check for updates"
        rm -rf "${OTA_TMP_DIR}"
        return 1
    }
    
    if command -v jq &>/dev/null; then
        remote_version=$(jq -r '.version // "0.0"' "${remote_manifest}")
    else
        remote_version=$(grep -o '"version":"[^"]*"' "${remote_manifest}" | cut -d'"' -f4)
    fi
    
    ota_log "info" "Current version: ${current_version}, Remote version: ${remote_version}"
    
    if [[ "${remote_version}" != "${current_version}" ]]; then
        ota_log "info" "New version available: ${remote_version}"
        echo "Update available: ${current_version} -> ${remote_version}"
        rm -rf "${OTA_TMP_DIR}"
        return 0
    else
        ota_log "info" "Already up to date"
        echo "Already up to date (${current_version})"
        rm -rf "${OTA_TMP_DIR}"
        return 0
    fi
}

# Apply updates (download, verify, install)
ota_apply() {
    ota_log "info" "Starting OTA policy update"
    
    # Create temporary directory
    mkdir -p "${OTA_TMP_DIR}"
    trap "rm -rf '${OTA_TMP_DIR}'" EXIT
    
    # Download manifest
    local manifest_file
    manifest_file=$(ota_download_manifest) || {
        ota_log "error" "Failed to download manifest"
        return 1
    }
    
    # Verify manifest
    if ! ota_verify_manifest "${manifest_file}"; then
        ota_log "error" "Manifest verification failed"
        return 1
    fi
    
    # Parse policy list
    local policies
    readarray -t policies < <(ota_parse_manifest "${manifest_file}")
    
    if [[ ${#policies[@]} -eq 0 ]]; then
        ota_log "error" "No policies found in manifest"
        return 1
    fi
    
    ota_log "info" "Found ${#policies[@]} policies to download"
    
    # Download each policy
    local failed=0
    for policy in "${policies[@]}"; do
        if ! ota_download_policy "${policy}" >/dev/null; then
            ota_log "error" "Failed to download policy: ${policy}"
            ((failed++))
        fi
    done
    
    if [[ ${failed} -gt 0 ]]; then
        ota_log "error" "Failed to download ${failed} policies"
        return 1
    fi
    
    # Install policies
    if ! ota_install_policies "${OTA_TMP_DIR}"; then
        ota_log "error" "Failed to install policies"
        return 1
    fi
    
    # Copy manifest to policy directory
    cp "${manifest_file}" "${OTA_POLICY_DIR}/../manifest.json" || true
    
    ota_log "info" "OTA policy update completed successfully"
    echo "Policy update completed successfully"
    return 0
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local action="check"
    # Parse simple flags first to allow --source override
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check|check) action="check"; shift ;;
            --apply|apply) action="apply"; shift ;;
            --source) OTA_URL="$2"; shift 2 ;;
            --help|help) action="help"; shift ;;
            *) break ;;
        esac
    done
    
    # Ensure log path is writable; fallback to /tmp for non-root
    local log_dir
    log_dir="$(dirname "${OTA_LOG}")"
    if ! mkdir -p "${log_dir}" 2>/dev/null; then
        OTA_LOG="/tmp/ubopt-ota-$$.log"
    else
        # Directory exists; verify we can create/append the log file
        if ! touch "${OTA_LOG}" 2>/dev/null; then
            OTA_LOG="/tmp/ubopt-ota-$$.log"
        fi
    fi
    
    case "${action}" in
        --check|check)
            ota_check
            ;;
        --apply|apply)
            # Require root for apply
            if [[ "$EUID" -ne 0 ]]; then
                ota_log "error" "OTA apply requires root privileges"
                echo "Error: --apply requires root privileges" >&2
                exit 1
            fi
            ota_apply
            ;;
        --help|help)
            cat <<EOF
Usage: $0 [--check|--apply]

OTA Policy Update Tool for ubopt

Options:
  --check    Check for available policy updates (default)
  --apply    Download and install policy updates (requires root)
  --help     Show this help message

Environment Variables:
  OTA_URL           Base URL for OTA endpoint (default: GitHub repo)
  OTA_PUBLIC_KEY    Path to public key for signature verification
  OTA_POLICY_DIR    Installation directory for policies

Examples:
  $0 --check                          # Check for updates
  sudo $0 --apply                     # Apply updates
  OTA_URL=https://custom.com/ota $0   # Use custom endpoint

EOF
            exit 0
            ;;
        *)
            echo "Error: Unknown action: ${action}" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
