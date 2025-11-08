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
