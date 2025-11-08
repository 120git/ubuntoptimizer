#!/usr/bin/env bash
# =============================================================================
# Logging Module - Enhanced logging capabilities
# =============================================================================

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Rotate logs
logging_rotate() {
    local max_size_mb="${1:-10}"
    local max_files="${2:-5}"
    
    log_info "Rotating logs (max: ${max_size_mb}MB, keep: ${max_files} files)..."
    
    if [[ ! -f "${UBOPT_LOG_FILE}" ]]; then
        log_info "No log file to rotate"
        return 0
    fi
    
    local file_size_mb
    file_size_mb=$(du -m "${UBOPT_LOG_FILE}" | cut -f1)
    
    if [[ "${file_size_mb}" -lt "${max_size_mb}" ]]; then
        log_info "Log file size (${file_size_mb}MB) below threshold"
        return 0
    fi
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would rotate ${UBOPT_LOG_FILE}"
        return 0
    fi
    
    # Rotate existing logs
    for ((i=max_files-1; i>=1; i--)); do
        if [[ -f "${UBOPT_LOG_FILE}.${i}" ]]; then
            mv "${UBOPT_LOG_FILE}.${i}" "${UBOPT_LOG_FILE}.$((i+1))"
        fi
    done
    
    # Move current log to .1
    mv "${UBOPT_LOG_FILE}" "${UBOPT_LOG_FILE}.1"
    touch "${UBOPT_LOG_FILE}"
    chmod 644 "${UBOPT_LOG_FILE}"
    
    # Remove old logs beyond max_files
    for ((i=max_files+1; i<=max_files+10; i++)); do
        rm -f "${UBOPT_LOG_FILE}.${i}"
    done
    
    log_success "Log rotation completed"
}

# Show recent logs
logging_show() {
    local lines="${1:-50}"
    
    if [[ ! -f "${UBOPT_LOG_FILE}" ]]; then
        log_warn "No log file found at ${UBOPT_LOG_FILE}"
        return 1
    fi
    
    tail -n "${lines}" "${UBOPT_LOG_FILE}"
}

# Run logging action if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-show}" in
        rotate)
            logging_rotate "${2:-10}" "${3:-5}"
            ;;
        show)
            logging_show "${2:-50}"
            ;;
        *)
            log_error "Unknown logging action: $1"
            exit 1
            ;;
    esac
fi
