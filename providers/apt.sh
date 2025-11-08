#!/usr/bin/env bash
# =============================================================================
# APT Provider - Package management for Debian/Ubuntu
# =============================================================================

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Update package lists
apt_update() {
    log_info "Updating APT package lists..."
    run_cmd "apt-get update -qq"
}

# Upgrade packages
apt_upgrade() {
    local security_only="${1:-false}"
    
    if [[ "${security_only}" == "true" ]]; then
        log_info "Upgrading security packages only..."
        run_cmd "apt-get upgrade -y --only-upgrade -o Dir::Etc::SourceList=/etc/apt/sources.list.d/security.list"
    else
        log_info "Upgrading all packages..."
        run_cmd "apt-get upgrade -y"
    fi
}

# Full system upgrade
apt_full_upgrade() {
    log_info "Performing full system upgrade..."
    run_cmd "apt-get full-upgrade -y"
}

# Remove unused packages
apt_autoremove() {
    log_info "Removing unused packages..."
    run_cmd "apt-get autoremove --purge -y"
}

# Clean package cache
apt_clean() {
    log_info "Cleaning package cache..."
    run_cmd "apt-get autoclean -y"
    run_cmd "apt-get clean -y"
}

# Check for security updates
apt_check_security() {
    log_info "Checking for security updates..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would check for security updates"
        return 0
    fi
    
    # Update package lists first
    apt-get update -qq 2>/dev/null || true
    
    # Check for upgradable packages
    local upgradable
    upgradable=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
    
    if [[ "${upgradable}" -gt 0 ]]; then
        log_warn "Found ${upgradable} packages with available updates"
        return 20  # Exit code 20 indicates updates available
    else
        log_success "No security updates available"
        return 0
    fi
}

# List installed packages
apt_list_installed() {
    dpkg --get-selections | grep -v deinstall | awk '{print $1}'
}

# Export package list to file
apt_export_packages() {
    local output_file="$1"
    log_info "Exporting package list to ${output_file}..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would export packages to ${output_file}"
        return 0
    fi
    
    dpkg --get-selections > "${output_file}"
    log_success "Package list exported"
}
