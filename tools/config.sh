#!/usr/bin/env bash
# =============================================================================
# Config Parser for ubopt
# Supports nested YAML keys and arrays with yq (preferred) or Bash fallback
# =============================================================================

set -Eeuo pipefail

# Prevent duplicate sourcing
[[ -n "${UBOPT_CONFIG_LOADED:-}" ]] && return 0
readonly UBOPT_CONFIG_LOADED=1

# Default config path
UBOPT_CONFIG_FILE="${UBOPT_CONFIG_FILE:-/etc/ubopt/ubopt.yaml}"

# Config cache (associative array) - global scope
declare -gA CONFIG_CACHE

# Detect yq availability
YQ_AVAILABLE=false
if command -v yq &>/dev/null; then
    # Verify it's mikefarah's yq (not python-yq)
    if yq --version 2>&1 | grep -q "mikefarah"; then
        YQ_AVAILABLE=true
    fi
fi

# =============================================================================
# CONFIG FUNCTIONS
# =============================================================================

# Load configuration file into cache
# Usage: cfg_load [path]
cfg_load() {
    local config_file="${1:-${UBOPT_CONFIG_FILE}}"
    
    if [[ ! -f "${config_file}" ]]; then
        log_warn "Config file not found: ${config_file}"
        return 1
    fi
    
    log_debug "Loading config from ${config_file}"
    
    if [[ "${YQ_AVAILABLE}" == "true" ]]; then
        # Use yq to parse entire config into flat key-value pairs
        while IFS='=' read -r key value; do
            [[ -z "${key}" ]] && continue
            CONFIG_CACHE["${key}"]="${value}"
        done < <(yq eval '.. | select(tag != "!!map" and tag != "!!seq") | (path | join(".")) + "=" + .' "${config_file}" 2>/dev/null || true)
    else
        # Fallback: simple Bash parser for common patterns
        _cfg_parse_bash "${config_file}"
    fi
    
    log_debug "Loaded ${#CONFIG_CACHE[@]} config keys"
    return 0
}

# Get config value by path
# Usage: cfg_get "path.to.key" "default_value"
# Returns: value or default
cfg_get() {
    local key="$1"
    local default="${2:-}"
    
    # Load config if not already loaded (CONFIG_CACHE declared globally at top of file)
    set +u
    local cache_size="${#CONFIG_CACHE[@]}"
    set -u
    if [[ ${cache_size} -eq 0 ]]; then
        cfg_load || true
    fi
    
    # Check cache
    if [[ -n "${CONFIG_CACHE[${key}]:-}" ]]; then
        echo "${CONFIG_CACHE[${key}]}"
        return 0
    fi
    
    # Try yq direct query if available
    if [[ "${YQ_AVAILABLE}" == "true" ]] && [[ -f "${UBOPT_CONFIG_FILE}" ]]; then
        local value
        value=$(yq eval ".${key}" "${UBOPT_CONFIG_FILE}" 2>/dev/null || echo "null")
        if [[ "${value}" != "null" ]] && [[ -n "${value}" ]]; then
            echo "${value}"
            return 0
        fi
    fi
    
    # Return default
    echo "${default}"
    return 0
}

# Get array values from config
# Usage: cfg_get_array "path.to.array"
# Returns: newline-separated values
cfg_get_array() {
    local key="$1"
    
    if [[ "${YQ_AVAILABLE}" == "true" ]] && [[ -f "${UBOPT_CONFIG_FILE}" ]]; then
        yq eval ".${key}[]" "${UBOPT_CONFIG_FILE}" 2>/dev/null || true
    else
        # Fallback: check cache for indexed keys (key.0, key.1, etc.)
        local idx=0
        while true; do
            local val="${CONFIG_CACHE[${key}.${idx}]:-}"
            if [[ -z "${val}" ]]; then
                break
            fi
            echo "${val}"
            idx=$((idx + 1))
        done
    fi
}

# Check if config key exists
# Usage: cfg_has "path.to.key"
# Returns: 0 if exists, 1 otherwise
cfg_has() {
    local key="$1"
    
    if [[ -n "${CONFIG_CACHE[${key}]:-}" ]]; then
        return 0
    fi
    
    if [[ "${YQ_AVAILABLE}" == "true" ]] && [[ -f "${UBOPT_CONFIG_FILE}" ]]; then
        local value
        value=$(yq eval ".${key}" "${UBOPT_CONFIG_FILE}" 2>/dev/null || echo "null")
        if [[ "${value}" != "null" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# =============================================================================
# BASH FALLBACK PARSER (LIMITED)
# =============================================================================

# Simple Bash YAML parser for common patterns
# Limitations: supports flat keys, simple nesting (one level), basic arrays
_cfg_parse_bash() {
    local file="$1"
    local current_section=""
    local array_key=""
    local array_idx=0
    local current_subsection=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Detect section (top-level key with colon, no value)
        if [[ "$line" =~ ^([a-z_][a-z0-9_]*):([[:space:]]*)$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            current_subsection=""
            array_key=""
            array_idx=0
            continue
        fi
        
        # Nested key at 2-space indent (second level)
        if [[ "$line" =~ ^[[:space:]]{2}([a-z_][a-z0-9_]*):([[:space:]]*)(.*)$ ]]; then
            local nested_key="${BASH_REMATCH[1]}"
            local nested_val="${BASH_REMATCH[3]}"
            
            if [[ -n "${current_section}" ]]; then
                local full_key="${current_section}.${nested_key}"
                
                # Check if value is empty (nested section or array)
                if [[ -z "${nested_val}" ]]; then
                    current_subsection="${nested_key}"
                    # This could be an array or a subsection, tentatively set array_key
                    array_key="${full_key}"
                    array_idx=0
                else
                    # Remove quotes if present
                    nested_val="${nested_val%\"}"
                    nested_val="${nested_val#\"}"
                    nested_val="${nested_val%\'}"
                    nested_val="${nested_val#\'}"
                    CONFIG_CACHE["${full_key}"]="${nested_val}"
                    current_subsection=""
                    array_key=""
                fi
            fi
            continue
        fi
        
        # Deeper nested key at 4-space indent (third level)
        if [[ "$line" =~ ^[[:space:]]{4}([a-z_][a-z0-9_]*):([[:space:]]*)(.*)$ ]]; then
            local deep_key="${BASH_REMATCH[1]}"
            local deep_val="${BASH_REMATCH[3]}"
            
            if [[ -n "${current_section}" ]] && [[ -n "${current_subsection}" ]]; then
                local full_key="${current_section}.${current_subsection}.${deep_key}"
                
                # Clear the tentative array_key from parent since we have a real subsection
                array_key=""
                
                # Check if this is an array key (empty value)
                if [[ -z "${deep_val}" ]]; then
                    array_key="${full_key}"
                    array_idx=0
                else
                    # Strip inline comments and all trailing whitespace
                    deep_val="${deep_val%%#*}"
                    # Trim trailing whitespace
                    while [[ "${deep_val}" =~ [[:space:]]$ ]]; do
                        deep_val="${deep_val%?}"
                    done
                    # Trim leading whitespace
                    while [[ "${deep_val}" =~ ^[[:space:]] ]]; do
                        deep_val="${deep_val#?}"
                    done
                    
                    # Remove quotes
                    deep_val="${deep_val%\"}"
                    deep_val="${deep_val#\"}"
                    deep_val="${deep_val%\'}"
                    deep_val="${deep_val#\'}"
                    CONFIG_CACHE["${full_key}"]="${deep_val}"
                fi
            fi
            continue
        fi
        
        # Array item at 4-space or 6-space indent (starts with dash)
        if [[ "$line" =~ ^[[:space:]]{4,6}-[[:space:]]+(.+)$ ]]; then
            local item="${BASH_REMATCH[1]}"
            item="${item%\"}"
            item="${item#\"}"
            item="${item%\'}"
            item="${item#\'}"
            
            if [[ -n "${array_key}" ]]; then
                CONFIG_CACHE["${array_key}.${array_idx}"]="${item}"
                array_idx=$((array_idx + 1))
            fi
            continue
        fi
        
        # Top-level key:value
        if [[ "$line" =~ ^([a-z_][a-z0-9_]*):([[:space:]]+)(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[3]}"
            val="${val%\"}"
            val="${val#\"}"
            val="${val%\'}"
            val="${val#\'}"
            CONFIG_CACHE["${key}"]="${val}"
            current_section=""
            current_subsection=""
            array_key=""
            continue
        fi
    done < "${file}"
    
    return 0
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Print all loaded config (debug)
cfg_dump() {
    echo "=== Config Dump ==="
    for key in "${!CONFIG_CACHE[@]}"; do
        echo "${key}=${CONFIG_CACHE[$key]}"
    done | sort
}

# Validate config structure
# Usage: cfg_validate
cfg_validate() {
    local config_file="${UBOPT_CONFIG_FILE}"
    
    if [[ ! -f "${config_file}" ]]; then
        log_error "Config file not found: ${config_file}"
        return 1
    fi
    
    # Basic YAML syntax check with yq
    if [[ "${YQ_AVAILABLE}" == "true" ]]; then
        if ! yq eval '.' "${config_file}" &>/dev/null; then
            log_error "Invalid YAML syntax in ${config_file}"
            return 1
        fi
    else
        # Fallback: basic structure check
        if ! _cfg_parse_bash "${config_file}" 2>/dev/null; then
            log_error "Failed to parse config: ${config_file}"
            return 1
        fi
    fi
    
    log_success "Config validation passed"
    return 0
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Auto-load config if file exists (non-fatal)
if [[ -f "${UBOPT_CONFIG_FILE}" ]]; then
    cfg_load "${UBOPT_CONFIG_FILE}" 2>/dev/null || true
fi
