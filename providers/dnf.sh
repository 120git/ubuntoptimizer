#!/usr/bin/env bash
# =============================================================================
# DNF Provider - Package management for Fedora/RHEL
# =============================================================================

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Update package lists
dnf_update() {
    log_info "Updating DNF package metadata..."
    run_cmd "dnf check-update -q" || true
}

# Upgrade packages
dnf_upgrade() {
    local security_only="${1:-false}"
    
    if [[ "${security_only}" == "true" ]]; then
        log_info "Upgrading security packages only..."
        run_cmd "dnf upgrade-minimal --security -y"
    else
        log_info "Upgrading all packages..."
        run_cmd "dnf upgrade -y"
    fi
}

# Full system upgrade
dnf_full_upgrade() {
    log_info "Performing full system upgrade..."
    run_cmd "dnf upgrade --refresh -y"
}

# Remove unused packages
dnf_autoremove() {
    log_info "Removing unused packages..."
    run_cmd "dnf autoremove -y"
}

# Clean package cache
dnf_clean() {
    log_info "Cleaning package cache..."
    run_cmd "dnf clean all -y"
}

# Check for security updates
dnf_check_security() {
    log_info "Checking for security updates..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would check for security updates"
        return 0
    fi
    
    # Check for available security updates
    local updates
    updates=$(dnf updateinfo list security 2>/dev/null | grep -c "security" || echo "0")
    
    if [[ "${updates}" -gt 0 ]]; then
        log_warn "Found ${updates} security updates available"
        return 20  # Exit code 20 indicates updates available
    else
        log_success "No security updates available"
        return 0
    fi
}

# List installed packages
dnf_list_installed() {
    rpm -qa --queryformat "%{NAME}\n"
}

# Export package list to file
dnf_export_packages() {
    local output_file="$1"
    log_info "Exporting package list to ${output_file}..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would export packages to ${output_file}"
        return 0
    fi
    
    rpm -qa > "${output_file}"
    log_success "Package list exported"
}
