#!/usr/bin/env bash
# =============================================================================
# Update Module - System package updates and security patches
# =============================================================================

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Load provider functions
load_provider() {
    local provider="$1"
    local provider_file="${SCRIPT_DIR}/providers/${provider}.sh"
    
    if [[ -f "${provider_file}" ]]; then
        # shellcheck source=../providers/apt.sh
        source "${provider_file}"
        log_debug "Loaded provider: ${provider}"
    else
        log_error "Provider not found: ${provider}"
        return 1
    fi
}

# Check for security updates
update_check() {
    log_info "Checking for security updates..."
    
    # Ensure we have detected the distro
    if [[ -z "${UBOPT_PROVIDER}" ]] || [[ "${UBOPT_PROVIDER}" == "unknown" ]]; then
        log_error "Cannot determine package provider"
        return 1
    fi
    
    # Load the appropriate provider
    load_provider "${UBOPT_PROVIDER}"
    
    # Call provider-specific check function
    case "${UBOPT_PROVIDER}" in
        apt)
            apt_check_security
            ;;
        dnf)
            dnf_check_security
            ;;
        pacman)
            pacman_check_security
            ;;
        *)
            log_error "Unsupported provider: ${UBOPT_PROVIDER}"
            return 1
            ;;
    esac
}

# Perform system update
update_apply() {
    local security_only="${1:-false}"
    local state_dir="/var/lib/ubopt"
    local state_file="${state_dir}/state.json"
    local snapshot_label="ubopt-$(date +%Y%m%d_%H%M%S)"
    local snapshot_path=""
    
    log_info "Starting system update process..."
    
    # Check if we need root
    if [[ "${UBOPT_DRY_RUN}" != "true" ]]; then
        require_root || return 1
    fi
    
    # Ensure we have detected the distro
    if [[ -z "${UBOPT_PROVIDER}" ]] || [[ "${UBOPT_PROVIDER}" == "unknown" ]]; then
        log_error "Cannot determine package provider"
        return 1
    fi
    
    # Pre-update hooks
    run_pre_update_hooks || return 1

    # Attempt snapshot (best-effort)
    if [[ "${UBOPT_DRY_RUN}" != "true" ]]; then
        create_pre_update_snapshot || true
    else
        log_info "[DRY-RUN] Snapshot skipped"
    fi

    # Load the appropriate provider
    load_provider "${UBOPT_PROVIDER}"
    
    # Execute update based on provider
    case "${UBOPT_PROVIDER}" in
        apt)
            apt_update
            apt_upgrade "${security_only}"
            apt_autoremove
            apt_clean
            ;;
        dnf)
            dnf_update
            dnf_upgrade "${security_only}"
            dnf_autoremove
            dnf_clean
            ;;
        pacman)
            pacman_update
            pacman_upgrade "${security_only}"
            pacman_autoremove
            pacman_clean
            ;;
        *)
            log_error "Unsupported provider: ${UBOPT_PROVIDER}"
            return 1
            ;;
    esac
    
    log_success "System update completed successfully"

    # Post-update hooks
    run_post_update_hooks || true

    # Record snapshot info if any (enriched: last_snapshot + last_snapshot_timestamp)
    if [[ -n "${UBOPT_SNAPSHOT_PATH:-}" ]]; then
        if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] Would record snapshot metadata"
        else
            mkdir -p "${state_dir}" 2>/dev/null || true
            local snap_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            if command -v jq &>/dev/null && [[ -f "${state_file}" ]]; then
                tmp=$(mktemp)
                jq -c --arg path "${UBOPT_SNAPSHOT_PATH}" --arg ts "${snap_ts}" '.last_snapshot=$path | .last_snapshot_timestamp=$ts' "${state_file}" > "$tmp" 2>/dev/null || echo '{"last_snapshot":"'"${UBOPT_SNAPSHOT_PATH}"'","last_snapshot_timestamp":"'"${snap_ts}"'"}' > "$tmp"
                mv "$tmp" "${state_file}" || echo '{"last_snapshot":"'"${UBOPT_SNAPSHOT_PATH}"'","last_snapshot_timestamp":"'"${snap_ts}"'"}' > "${state_file}"
            else
                echo '{"last_snapshot":"'"${UBOPT_SNAPSHOT_PATH}"'","last_snapshot_timestamp":"'"${snap_ts}"'"}' > "${state_file}"
            fi
            log_info "Snapshot metadata recorded: ${UBOPT_SNAPSHOT_PATH}"
        fi
    fi
    return 0
}

# Full system upgrade
update_full() {
    log_info "Starting full system upgrade..."
    
    # Check if we need root
    if [[ "${UBOPT_DRY_RUN}" != "true" ]]; then
        require_root || return 1
    fi
    
    # Ensure we have detected the distro
    if [[ -z "${UBOPT_PROVIDER}" ]] || [[ "${UBOPT_PROVIDER}" == "unknown" ]]; then
        log_error "Cannot determine package provider"
        return 1
    fi
    
    # Load the appropriate provider
    load_provider "${UBOPT_PROVIDER}"
    
    # Execute full upgrade based on provider
    case "${UBOPT_PROVIDER}" in
        apt)
            apt_update
            apt_full_upgrade
            apt_autoremove
            apt_clean
            ;;
        dnf)
            dnf_full_upgrade
            dnf_autoremove
            dnf_clean
            ;;
        pacman)
            pacman_full_upgrade
            pacman_autoremove
            pacman_clean
            ;;
        *)
            log_error "Unsupported provider: ${UBOPT_PROVIDER}"
            return 1
            ;;
    esac
    
    log_success "Full system upgrade completed successfully"
    return 0
}

# Execute pre-update hooks (abort on failure)
run_pre_update_hooks() {
    local hook_dir="${SCRIPT_DIR}/hooks/pre-update.d"
    if [[ ! -d "${hook_dir}" ]]; then
        log_debug "No pre-update hooks directory"
        return 0
    fi
    local hooks=()
    mapfile -t hooks < <(find "${hook_dir}" -maxdepth 1 -type f -name "*.sh" | sort)
    if [[ ${#hooks[@]} -eq 0 ]]; then
        log_debug "No pre-update hooks found"
        return 0
    fi
    for h in "${hooks[@]}"; do
        if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] Would run pre-update hook: ${h}"
            continue
        fi
        if [[ -x "${h}" ]]; then
            log_info "Running pre-update hook: ${h}"
            if ! "${h}"; then
                log_error "Pre-update hook failed: ${h}"; return 1
            fi
        else
            log_warn "Skipping non-executable pre-update hook: ${h}"
        fi
    done
    return 0
}

# Execute post-update hooks (warn on failure)
run_post_update_hooks() {
    local hook_dir="${SCRIPT_DIR}/hooks/post-update.d"
    if [[ ! -d "${hook_dir}" ]]; then
        log_debug "No post-update hooks directory"
        return 0
    fi
    local hooks=()
    mapfile -t hooks < <(find "${hook_dir}" -maxdepth 1 -type f -name "*.sh" | sort)
    if [[ ${#hooks[@]} -eq 0 ]]; then
        log_debug "No post-update hooks found"
        return 0
    fi
    for h in "${hooks[@]}"; do
        if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] Would run post-update hook: ${h}"
            continue
        fi
        if [[ -x "${h}" ]]; then
            log_info "Running post-update hook: ${h}"
            if ! "${h}"; then
                log_warn "Post-update hook failed: ${h}"; continue
            fi
        else
            log_warn "Skipping non-executable post-update hook: ${h}"
        fi
    done
    return 0
}

# Create pre-update snapshot for btrfs or zfs root
create_pre_update_snapshot() {
    local root_fs
    root_fs=$(findmnt -n -o FSTYPE / || echo "")
    case "${root_fs}" in
        btrfs)
            local subvol
            subvol=$(findmnt -n -o SOURCE / | sed 's/.*\[//; s/\]//')
            local snap_parent="/" # assume default root
            local snap_path="${snap_parent}ubopt-snapshots/${snapshot_label}"  
            mkdir -p "${snap_parent}ubopt-snapshots" || true
            btrfs subvolume snapshot / "${snap_path}" >/dev/null 2>&1 && {
                UBOPT_SNAPSHOT_PATH="${snap_path}"; export UBOPT_SNAPSHOT_PATH; log_success "btrfs snapshot created: ${snap_path}"; return 0; } || {
                log_warn "btrfs snapshot failed"; return 1; }
            ;;
        zfs)
            local zroot
            zroot=$(zfs list -H -o name | grep -E '^rpool/ROOT' | head -n1 || true)
            if [[ -n "${zroot}" ]]; then
                local snap_name="${zroot}@${snapshot_label}"
                if zfs snapshot "${snap_name}" >/dev/null 2>&1; then
                    UBOPT_SNAPSHOT_PATH="${snap_name}"; export UBOPT_SNAPSHOT_PATH; log_success "ZFS snapshot created: ${snap_name}"; return 0
                else
                    log_warn "ZFS snapshot failed"
                fi
            fi
            ;;
        *)
            log_debug "Snapshot skipped: unsupported fs ${root_fs}"
            ;;
    esac
    return 0
}

# Main update entry point
update_main() {
    local action="${1:-check}"
    local security_only="${2:-false}"
    
    case "${action}" in
        check)
            update_check
            ;;
        apply)
            update_apply "${security_only}"
            ;;
        full)
            update_full
            ;;
        *)
            log_error "Unknown update action: ${action}"
            return 1
            ;;
    esac
}

# Run update if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    update_main "$@"
fi
