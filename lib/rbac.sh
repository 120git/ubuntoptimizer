#!/usr/bin/env bash
# =============================================================================
# RBAC (Role-Based Access Control) Library for ubopt
# Provides role-based command authorization
# =============================================================================

set -Eeuo pipefail

# Prevent duplicate sourcing
[[ -n "${UBOPT_RBAC_LOADED:-}" ]] && return 0
readonly UBOPT_RBAC_LOADED=1

# RBAC configuration paths
RBAC_ROLES_FILE="${RBAC_ROLES_FILE:-/etc/ubopt/roles.yaml}"
RBAC_FALLBACK_FILE="${SCRIPT_DIR:-}/rbac/roles.yaml"

# Role definitions cache (associative arrays require bash 4+)
declare -A ROLE_PERMISSIONS

# =============================================================================
# RBAC FUNCTIONS
# =============================================================================

# Load role definitions from YAML file
# Uses simple grep-based parsing (no yq dependency)
rbac_load_roles() {
    local roles_file="${RBAC_ROLES_FILE}"
    
    # Fallback to repo copy if system file doesn't exist
    if [[ ! -f "${roles_file}" ]]; then
        roles_file="${RBAC_FALLBACK_FILE}"
    fi
    
    if [[ ! -f "${roles_file}" ]]; then
        log_error "RBAC: roles file not found: ${roles_file}"
        return 1
    fi
    
    log_debug "RBAC: Loading roles from ${roles_file}"
    
    # Parse roles and permissions (naive YAML parsing)
    local current_role=""
    local in_permissions=false
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Detect role definition
        if [[ "$line" =~ ^[[:space:]]{2}([a-z_]+):$ ]]; then
            current_role="${BASH_REMATCH[1]}"
            in_permissions=false
            log_debug "RBAC: Found role: ${current_role}"
            continue
        fi
        
        # Detect permissions section
        if [[ "$line" =~ ^[[:space:]]{4}permissions: ]]; then
            in_permissions=true
            continue
        fi
        
        # Parse permission entries
        if [[ "$in_permissions" == true ]] && [[ "$line" =~ ^[[:space:]]{6}-[[:space:]]([a-z_]+) ]]; then
            local perm="${BASH_REMATCH[1]}"
            if [[ -n "${current_role}" ]]; then
                # Append permission to role (comma-separated list)
                if [[ -z "${ROLE_PERMISSIONS[$current_role]:-}" ]]; then
                    ROLE_PERMISSIONS[$current_role]="$perm"
                else
                    ROLE_PERMISSIONS[$current_role]="${ROLE_PERMISSIONS[$current_role]},$perm"
                fi
                log_debug "RBAC: Added permission '${perm}' to role '${current_role}'"
            fi
        fi
        
        # Exit permissions section on different indentation
        if [[ "$in_permissions" == true ]] && [[ "$line" =~ ^[[:space:]]{4}[a-z] ]]; then
            in_permissions=false
        fi
    done < "${roles_file}"
    
    # Verify roles loaded
    if [[ ${#ROLE_PERMISSIONS[@]} -eq 0 ]]; then
        log_error "RBAC: No roles loaded from ${roles_file}"
        return 1
    fi
    
    log_debug "RBAC: Loaded ${#ROLE_PERMISSIONS[@]} role(s)"
    return 0
}

# Check if a role has permission for an action
# Usage: rbac_check <role> <action>
# Returns: 0 if authorized, 1 if unauthorized
rbac_check() {
    local role="$1"
    local action="$2"
    
    # Load roles if not already loaded
    if [[ ${#ROLE_PERMISSIONS[@]} -eq 0 ]]; then
        rbac_load_roles || return 1
    fi
    
    # Check if role exists
    if [[ -z "${ROLE_PERMISSIONS[$role]:-}" ]]; then
        log_error "RBAC: Unknown role: ${role}"
        echo "{\"error\":\"unknown_role\",\"role\":\"${role}\",\"action\":\"${action}\"}"
        return 1
    fi
    
    # Get permissions for role
    local perms="${ROLE_PERMISSIONS[$role]}"
    
    # Check if action is in permissions list
    if [[ ",$perms," == *",$action,"* ]]; then
        log_debug "RBAC: Role '${role}' authorized for action '${action}'"
        return 0
    else
        log_warn "RBAC: Role '${role}' denied action '${action}'"
        echo "{\"error\":\"unauthorized\",\"role\":\"${role}\",\"action\":\"${action}\"}"
        return 1
    fi
}

# List all available roles
rbac_list_roles() {
    # Load roles if not already loaded
    if [[ ${#ROLE_PERMISSIONS[@]} -eq 0 ]]; then
        rbac_load_roles || return 1
    fi
    
    echo "Available roles:"
    for role in "${!ROLE_PERMISSIONS[@]}"; do
        echo "  - ${role}"
        echo "    Permissions: ${ROLE_PERMISSIONS[$role]}"
    done
}

# Get default role based on user privileges
rbac_get_default_role() {
    if [[ "$EUID" -eq 0 ]]; then
        echo "admin"
    else
        echo "operator"
    fi
}

# Validate action name (normalize subcommand to action)
rbac_normalize_action() {
    local subcmd="$1"
    
    case "${subcmd}" in
        update|hardening|backup|report|health|benchmark)
            echo "${subcmd}"
            ;;
        config|config-test)
            echo "config_test"
            ;;
        logs)
            echo "view_logs"
            ;;
        *)
            echo "${subcmd}"
            ;;
    esac
}

# =============================================================================
# RBAC ENFORCEMENT WRAPPER
# =============================================================================

# Enforce RBAC check before command execution
# Usage: rbac_enforce <role> <subcommand>
# Exits with error JSON if unauthorized
rbac_enforce() {
    local role="$1"
    local subcmd="$2"
    local action
    
    action=$(rbac_normalize_action "${subcmd}")
    
    if ! rbac_check "${role}" "${action}" 2>/dev/null; then
        # rbac_check already printed JSON error
        exit 1
    fi
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Auto-load roles on source (but don't fail)
rbac_load_roles 2>/dev/null || true
