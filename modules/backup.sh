#!/usr/bin/env bash
# =============================================================================
# Backup Module - Advanced system configuration backup
# Features: includes/excludes, compression, retention, metadata with checksums
# =============================================================================

set -Eeo pipefail

# Source common library if not already sourced
if [[ -z "${UBOPT_COMMON_LOADED:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
    # shellcheck source=../lib/common.sh
    source "${SCRIPT_DIR}/lib/common.sh"
fi

# Default settings from config
BACKUP_DEST="$(cfg_get 'backup.dest' '/var/backups/ubopt')"
BACKUP_COMPRESSION="$(cfg_get 'backup.compression' 'xz')"
BACKUP_MODE="$(cfg_get 'backup.mode' 'tar')"
BACKUP_RETENTION_COUNT="$(cfg_get 'backup.retention.count' '7')"
BACKUP_RETENTION_DAYS="$(cfg_get 'backup.retention.days' '30')"

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

# Create comprehensive backup
backup_create() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="ubopt_backup_${timestamp}"
    local hostname
    hostname=$(hostname -f 2>/dev/null || hostname)
    
    log_info "Creating system backup: ${backup_name}"
    
    # Validate destination
    if [[ ! -d "${BACKUP_DEST}" ]]; then
        if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] Would create backup directory: ${BACKUP_DEST}"
        else
            mkdir -p "${BACKUP_DEST}" || {
                log_error "Cannot create backup destination: ${BACKUP_DEST}"
                return "${EXIT_ERROR}"
            }
        fi
    fi
    
    if [[ "${UBOPT_DRY_RUN}" != "true" ]] && [[ ! -w "${BACKUP_DEST}" ]]; then
        log_error "Backup destination not writable: ${BACKUP_DEST}"
        return "${EXIT_ERROR}"
    fi
    
    # Read includes from config
    local includes=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && includes+=("$line")
    done < <(cfg_get_array 'backup.includes')
    
    # Default includes if none configured
    if [[ ${#includes[@]} -eq 0 ]]; then
        includes=(
            "/etc/ubopt"
            "/etc/ssh/sshd_config"
            "/etc/sysctl.conf"
            "/etc/fstab"
            "/var/lib/ubopt"
        )
    fi
    
    # Validate includes exist
    local valid_includes=()
    for path in "${includes[@]}"; do
        if [[ -e "$path" ]]; then
            valid_includes+=("$path")
        else
            log_warn "Include path not found: $path"
        fi
    done
    
    if [[ ${#valid_includes[@]} -eq 0 ]]; then
        log_error "No valid paths to backup"
        return "${EXIT_ERROR}"
    fi
    
    # Read excludes from config
    local excludes=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && excludes+=("$line")
    done < <(cfg_get_array 'backup.excludes')
    
    # Determine archive extension
    local archive_ext
    case "${BACKUP_COMPRESSION}" in
        gz) archive_ext=".tar.gz" ;;
        xz) archive_ext=".tar.xz" ;;
        zstd) archive_ext=".tar.zst" ;;
        none) archive_ext=".tar" ;;
        *) 
            log_warn "Unknown compression: ${BACKUP_COMPRESSION}, using xz"
            BACKUP_COMPRESSION="xz"
            archive_ext=".tar.xz"
            ;;
    esac
    
    local archive_path="${BACKUP_DEST}/${backup_name}${archive_ext}"
    local metadata_path="${BACKUP_DEST}/${backup_name}.meta.json"
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would create archive: ${archive_path}"
        log_info "[DRY-RUN] Includes (${#valid_includes[@]}): ${valid_includes[*]}"
        [[ ${#excludes[@]} -gt 0 ]] && log_info "[DRY-RUN] Excludes (${#excludes[@]}): ${excludes[*]}"
        log_info "[DRY-RUN] Compression: ${BACKUP_COMPRESSION}"
        log_info "[DRY-RUN] Mode: ${BACKUP_MODE}"
        log_info "[DRY-RUN] Retention: ${BACKUP_RETENTION_COUNT} backups, ${BACKUP_RETENTION_DAYS} days"
        exit "${EXIT_CHANGES_PLANNED}"
    fi
    
    # Create archive
    log_info "Creating ${BACKUP_MODE} archive with ${BACKUP_COMPRESSION} compression..."
    
    local tar_opts=("--create" "--file=${archive_path}")
    
    # Add compression flag
    case "${BACKUP_COMPRESSION}" in
        gz) tar_opts+=("--gzip") ;;
        xz) tar_opts+=("--xz") ;;
        zstd) tar_opts+=("--zstd") ;;
    esac
    
    # Add excludes
    for exclude in "${excludes[@]}"; do
        tar_opts+=("--exclude=${exclude}")
    done
    
    # Add includes
    tar_opts+=("${valid_includes[@]}")
    
    if ! tar "${tar_opts[@]}" 2>/dev/null; then
        log_error "Failed to create backup archive"
        rm -f "${archive_path}"
        return "${EXIT_ERROR}"
    fi
    
    # Calculate checksum
    local checksum
    checksum=$(sha256sum "${archive_path}" | awk '{print $1}')
    
    # Get archive size
    local size_bytes
    size_bytes=$(stat -c%s "${archive_path}" 2>/dev/null || stat -f%z "${archive_path}" 2>/dev/null)
    
    # Build includes JSON array
    local includes_json=""
    for inc in "${valid_includes[@]}"; do
        includes_json+="    \"${inc}\","$'\n'
    done
    includes_json="${includes_json%,$'\n'}"
    
    # Build excludes JSON array
    local excludes_json=""
    if [[ ${#excludes[@]} -gt 0 ]]; then
        for exc in "${excludes[@]}"; do
            excludes_json+="    \"${exc}\","$'\n'
        done
        excludes_json="${excludes_json%,$'\n'}"
    fi
    
    # Create metadata file
    cat > "${metadata_path}" <<EOF
{
  "backup_name": "${backup_name}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "hostname": "${hostname}",
  "archive_path": "${archive_path}",
  "size_bytes": ${size_bytes},
  "compression": "${BACKUP_COMPRESSION}",
  "mode": "${BACKUP_MODE}",
  "checksum_sha256": "${checksum}",
  "includes": [
${includes_json}
  ],
  "excludes": [
${excludes_json}
  ],
  "ubopt_version": "${UBOPT_VERSION}"
}
EOF
    
    local size_human
    size_human=$(numfmt --to=iec-i --suffix=B "${size_bytes}" 2>/dev/null || echo "${size_bytes} bytes")
    
    log_success "Backup created: ${archive_path}"
    log_info "Size: ${size_human}"
    log_info "Checksum: ${checksum}"
    log_info "Metadata: ${metadata_path}"
    
    # Apply retention policy
    backup_cleanup
    
    return "${EXIT_OK}"
}

# Cleanup old backups per retention policy
backup_cleanup() {
    log_info "Applying retention policy..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would apply retention: keep ${BACKUP_RETENTION_COUNT} backups, ${BACKUP_RETENTION_DAYS} days"
        return 0
    fi
    
    # Remove backups older than retention days
    if [[ -d "${BACKUP_DEST}" ]]; then
        local removed=0
        while IFS= read -r -d '' file; do
            rm -f "$file" "${file%.tar*}.meta.json" 2>/dev/null || true
            removed=$((removed + 1))
        done < <(find "${BACKUP_DEST}" -name "ubopt_backup_*.tar*" -type f -mtime "+${BACKUP_RETENTION_DAYS}" -print0 2>/dev/null)
        [[ ${removed} -gt 0 ]] && log_info "Removed ${removed} backup(s) older than ${BACKUP_RETENTION_DAYS} days"
    fi
    
    # Keep only N most recent backups
    local backup_files
    mapfile -t backup_files < <(find "${BACKUP_DEST}" -name "ubopt_backup_*.tar*" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | awk '{print $2}')
    
    if [[ ${#backup_files[@]} -gt ${BACKUP_RETENTION_COUNT} ]]; then
        local to_remove=("${backup_files[@]:${BACKUP_RETENTION_COUNT}}")
        for file in "${to_remove[@]}"; do
            log_info "Removing old backup: $(basename "$file")"
            rm -f "$file" "${file%.tar*}.meta.json" 2>/dev/null || true
        done
    fi
    
    log_success "Retention policy applied (keeping ${BACKUP_RETENTION_COUNT} backups)"
}

# List available backups
backup_list() {
    if [[ ! -d "${BACKUP_DEST}" ]]; then
        log_warn "Backup directory does not exist: ${BACKUP_DEST}"
        return 1
    fi
    
    echo "Available backups in ${BACKUP_DEST}:"
    echo ""
    
    local found=0
    while IFS= read -r -d '' meta_file; do
        found=1
        if [[ -f "${meta_file}" ]]; then
            local timestamp size_bytes checksum compression
            timestamp=$(grep -o '"timestamp":"[^"]*"' "${meta_file}" | cut -d'"' -f4)
            size_bytes=$(grep -o '"size_bytes":[0-9]*' "${meta_file}" | cut -d: -f2)
            checksum=$(grep -o '"checksum_sha256":"[^"]*"' "${meta_file}" | cut -d'"' -f4)
            compression=$(grep -o '"compression":"[^"]*"' "${meta_file}" | cut -d'"' -f4)
            
            local size_human
            size_human=$(numfmt --to=iec-i --suffix=B "${size_bytes}" 2>/dev/null || echo "${size_bytes} bytes")
            
            echo "Backup: $(basename "${meta_file%.meta.json}")"
            echo "  Date: ${timestamp}"
            echo "  Size: ${size_human} (${compression})"
            echo "  SHA256: ${checksum}"
            echo ""
        fi
    done < <(find "${BACKUP_DEST}" -name "*.meta.json" -print0 2>/dev/null | sort -rz)
    
    if [[ ${found} -eq 0 ]]; then
        echo "No backups found."
    fi
}

# Show backup help
backup_help() {
    cat <<EOF
Usage: ubopt backup [COMMAND] [OPTIONS]

Commands:
  create       Create a new backup (default)
  list         List available backups
  cleanup      Apply retention policy to existing backups
  help         Show this help message

Options:
  --dry-run    Show what would be done without making changes
  --verbose    Enable verbose output

Configuration (from etc/ubopt.yaml):
  backup.dest              Backup destination directory
  backup.compression       Compression: gz, xz, zstd, none
  backup.mode              Mode: tar, rsync
  backup.retention.count   Number of backups to keep
  backup.retention.days    Days to keep backups
  backup.includes[]        Paths to include in backup
  backup.excludes[]        Paths to exclude from backup

Examples:
  ubopt backup create              Create a backup with config defaults
  ubopt backup create --dry-run    Preview backup operation
  ubopt backup list                List all existing backups
  ubopt backup cleanup             Remove old backups per policy

EOF
}

# =============================================================================
# MAIN
# =============================================================================

backup_main() {
    local command="${1:-create}"
    shift 2>/dev/null || true
    
    case "${command}" in
        create)
            backup_create "$@"
            ;;
        list)
            backup_list "$@"
            ;;
        cleanup)
            backup_cleanup "$@"
            ;;
        help|--help|-h)
            backup_help
            ;;
        *)
            log_error "Unknown backup command: ${command}"
            backup_help
            return 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    backup_main "$@"
fi
