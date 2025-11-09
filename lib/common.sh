#!/usr/bin/env bash
# =============================================================================
# Cool Llama Linux Optimizer - Common Library
# Provides: logging, distro detection, safe traps, flag parsing
# =============================================================================

set -Eeuo pipefail

# Prevent duplicate sourcing
[[ -n "${UBOPT_COMMON_LOADED:-}" ]] && return 0
readonly UBOPT_COMMON_LOADED=1

# =============================================================================
# GLOBALS
# =============================================================================

UBOPT_VERSION="1.0.0"
UBOPT_LOG_DIR="${UBOPT_LOG_DIR:-/var/log/ubopt}"
UBOPT_LOG_FILE="${UBOPT_LOG_FILE:-${UBOPT_LOG_DIR}/ubopt.log}"
UBOPT_CONFIG_DIR="${UBOPT_CONFIG_DIR:-/etc/ubopt}"
UBOPT_DRY_RUN="${UBOPT_DRY_RUN:-false}"
UBOPT_VERBOSE="${UBOPT_VERBOSE:-false}"
UBOPT_DISTRO=""
UBOPT_PROVIDER=""

# Colors
readonly COLOR_CYAN='\033[96m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Initialize logging directory and file
init_logging() {
    # Try preferred log dir first
    if [[ ! -d "${UBOPT_LOG_DIR}" ]]; then
        mkdir -p "${UBOPT_LOG_DIR}" 2>/dev/null || true
    fi

    # If not writable, fallback to local ./logs
    if [[ ! -w "${UBOPT_LOG_DIR}" ]]; then
        local fallback_dir="$(pwd)/logs"
        mkdir -p "${fallback_dir}" 2>/dev/null || true
        UBOPT_LOG_DIR="${fallback_dir}"
        UBOPT_LOG_FILE="${UBOPT_LOG_DIR}/ubopt.log"
    fi

    # Ensure file exists
    if [[ ! -f "${UBOPT_LOG_FILE}" ]]; then
        touch "${UBOPT_LOG_FILE}" 2>/dev/null || true
    fi

    chmod 644 "${UBOPT_LOG_FILE}" 2>/dev/null || true
}

# Log message in JSON format
# Usage: log_json LEVEL MESSAGE [extra_key=value ...]
log_json() {
    local level="$1"
    shift
    local message="$1"
    shift
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local json="{\"timestamp\":\"${timestamp}\",\"level\":\"${level}\",\"message\":\"${message}\""
    
    # Add extra fields
    while [[ $# -gt 0 ]]; do
        local key="${1%%=*}"
        local value="${1#*=}"
        json+=",\"${key}\":\"${value}\""
        shift
    done
    
    json+="}"
    
    # Write to log file
    echo "${json}" >> "${UBOPT_LOG_FILE}" 2>/dev/null || true
    
    # Also log to syslog if available
    if command -v logger &>/dev/null; then
        logger -t ubopt -p "user.${level}" "${message}"
    fi
}

# Log info message
log_info() {
    local message="$*"
    log_json "info" "${message}"
    
    if [[ "${UBOPT_VERBOSE}" == "true" ]]; then
        echo -e "${COLOR_CYAN}ℹ${COLOR_RESET} ${message}" >&2
    fi
}

# Log warning message
log_warn() {
    local message="$*"
    log_json "warning" "${message}"
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} ${message}" >&2
}

# Log error message
log_error() {
    local message="$*"
    log_json "error" "${message}"
    echo -e "${COLOR_RED}✗${COLOR_RESET} ${message}" >&2
}

# Log success message
log_success() {
    local message="$*"
    log_json "info" "${message}"
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} ${message}" >&2
}

# Log debug message (only if verbose)
log_debug() {
    if [[ "${UBOPT_VERBOSE}" == "true" ]]; then
        local message="$*"
        log_json "debug" "${message}"
        echo -e "${COLOR_BLUE}DEBUG:${COLOR_RESET} ${message}" >&2
    fi
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

# Error trap handler
error_handler() {
    local line_no=$1
    local bash_lineno=$2
    local func_name="${3:-main}"
    
    log_error "Error occurred in function '${func_name}' at line ${line_no} (bash line ${bash_lineno})"
}

# Set up error trap
setup_error_trap() {
    trap 'error_handler ${LINENO} ${BASH_LINENO} "${FUNCNAME[0]}"' ERR
}

# Cleanup trap handler
cleanup_handler() {
    log_debug "Cleanup handler called"
}

# Set up cleanup trap
setup_cleanup_trap() {
    trap cleanup_handler EXIT
}

# =============================================================================
# DISTRO DETECTION
# =============================================================================

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        # Source in subshell to avoid readonly collisions
        local distro_id
        distro_id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        UBOPT_DISTRO="${distro_id}"
        
        case "${UBOPT_DISTRO}" in
            ubuntu|debian|linuxmint|pop)
                UBOPT_PROVIDER="apt"
                ;;
            fedora|rhel|centos|rocky|alma)
                UBOPT_PROVIDER="dnf"
                ;;
            arch|manjaro|endeavouros)
                UBOPT_PROVIDER="pacman"
                ;;
            *)
                log_warn "Unsupported distribution: ${UBOPT_DISTRO}"
                UBOPT_PROVIDER="unknown"
                return 1
                ;;
        esac
        
        log_debug "Detected distro: ${UBOPT_DISTRO}, provider: ${UBOPT_PROVIDER}"
        return 0
    else
        log_error "Cannot detect distribution: /etc/os-release not found"
        return 1
    fi
}

# Get distribution pretty name
get_distro_name() {
    if [[ -f /etc/os-release ]]; then
        # Extract PRETTY_NAME without sourcing to avoid readonly collisions
        grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"'
    else
        echo "Unknown"
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Check if running as root
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "This operation requires root privileges. Please run with sudo."
        return 1
    fi
    return 0
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Parse yes/no response
parse_bool() {
    local value="${1:-false}"
    value=$(echo "${value}" | tr '[:upper:]' '[:lower:]')
    
    case "${value}" in
        true|yes|y|1|on)
            echo "true"
            ;;
        *)
            echo "false"
            ;;
    esac
}

# Confirm action (respects dry-run)
confirm_action() {
    local prompt="$1"
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would ask: ${prompt}"
        return 0
    fi
    
    echo -n "${prompt} [y/N]: " >&2
    read -r response
    
    case "${response}" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Execute command with dry-run support
run_cmd() {
    local cmd="$*"
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: ${cmd}"
        return 0
    fi
    
    log_debug "Executing: ${cmd}"
    eval "${cmd}"
}

# Safe file backup
backup_file() {
    local file="$1"
    
    if [[ ! -f "${file}" ]]; then
        log_warn "Cannot backup ${file}: file does not exist"
        return 1
    fi
    
    local backup="${file}.ubopt.$(date +%Y%m%d_%H%M%S).bak"
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would backup ${file} to ${backup}"
        return 0
    fi
    
    cp -p "${file}" "${backup}"
    log_success "Backed up ${file} to ${backup}"
    return 0
}

# =============================================================================
# FLAG PARSING
# =============================================================================

# Parse common flags
# Sets global variables: UBOPT_DRY_RUN, UBOPT_VERBOSE
parse_common_flags() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                UBOPT_DRY_RUN="true"
                export UBOPT_DRY_RUN
                shift
                ;;
            --verbose|-v)
                UBOPT_VERBOSE="true"
                export UBOPT_VERBOSE
                shift
                ;;
            --help|-h)
                return 99  # Special return code to indicate help was requested
                ;;
            *)
                # Unknown flag, let caller handle it
                return 0
                ;;
        esac
    done
    return 0
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Initialize common library
init_common() {
    setup_error_trap
    setup_cleanup_trap
    init_logging
    detect_distro || true
    
    log_debug "Cool Llama Linux Optimizer v${UBOPT_VERSION} initialized"
}

# Auto-initialize when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_common
fi
