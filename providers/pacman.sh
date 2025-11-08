#!/usr/bin/env bash
# =============================================================================
# Pacman Provider - Package management for Arch Linux
# =============================================================================

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Update package lists
pacman_update() {
    log_info "Synchronizing Pacman database..."
    run_cmd "pacman -Sy --noconfirm"
}

# Upgrade packages
pacman_upgrade() {
    local security_only="${1:-false}"
    
    # Pacman doesn't have security-only upgrades
    log_info "Upgrading all packages..."
    run_cmd "pacman -Syu --noconfirm"
}

# Full system upgrade
pacman_full_upgrade() {
    log_info "Performing full system upgrade..."
    run_cmd "pacman -Syyu --noconfirm"
}

# Remove unused packages
pacman_autoremove() {
    log_info "Removing unused packages..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would remove orphaned packages"
        return 0
    fi
    
    local orphans
    orphans=$(pacman -Qdtq 2>/dev/null || echo "")
    
    if [[ -n "${orphans}" ]]; then
        run_cmd "pacman -Rns ${orphans} --noconfirm"
    else
        log_info "No orphaned packages found"
    fi
}

# Clean package cache
pacman_clean() {
    log_info "Cleaning package cache..."
    
    if command_exists paccache; then
        run_cmd "paccache -r"
    else
        run_cmd "pacman -Sc --noconfirm"
    fi
}

# Check for security updates
pacman_check_security() {
    log_info "Checking for package updates..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would check for updates"
        return 0
    fi
    
    # Sync database
    pacman -Sy --noconfirm 2>/dev/null || true
    
    # Check for upgradable packages
    local updates
    updates=$(pacman -Qu 2>/dev/null | wc -l || echo "0")
    
    if [[ "${updates}" -gt 0 ]]; then
        log_warn "Found ${updates} packages with available updates"
        return 20  # Exit code 20 indicates updates available
    else
        log_success "System is up to date"
        return 0
    fi
}

# List installed packages
pacman_list_installed() {
    pacman -Qqe
}

# Export package list to file
pacman_export_packages() {
    local output_file="$1"
    log_info "Exporting package list to ${output_file}..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would export packages to ${output_file}"
        return 0
    fi
    
    pacman -Qqe > "${output_file}"
    log_success "Package list exported"
}
