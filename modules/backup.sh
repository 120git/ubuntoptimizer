#!/usr/bin/env bash
# =============================================================================
# Backup Module - System configuration backup
# =============================================================================

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Backup system configuration
backup_create() {
    local backup_dir="${1:-/var/backups/ubopt}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${backup_dir}/backup_${timestamp}"
    
    log_info "Creating system backup at ${backup_path}..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would create backup at ${backup_path}"
        return 0
    fi
    
    # Create backup directory
    mkdir -p "${backup_path}"
    
    # Backup important config files
    local files_to_backup=(
        "/etc/fstab"
        "/etc/sysctl.conf"
        "/etc/ssh/sshd_config"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -f "${file}" ]]; then
            cp -p "${file}" "${backup_path}/" 2>/dev/null || log_warn "Failed to backup ${file}"
        fi
    done
    
    log_success "Backup created at ${backup_path}"
}

# Run backup if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    backup_create "$@"
fi
