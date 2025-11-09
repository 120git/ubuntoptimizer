#!/usr/bin/env bash
# =============================================================================
# Hardening Module - Security baseline configuration
# =============================================================================

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Harden SSH configuration
harden_ssh() {
    local sshd_config="/etc/ssh/sshd_config"
    
    log_info "Hardening SSH configuration..."
    
    if [[ ! -f "${sshd_config}" ]]; then
        log_warn "SSH config not found: ${sshd_config}"
        return 1
    fi
    
    # Backup original config
    backup_file "${sshd_config}"
    
    # Apply hardening settings
    local settings=(
        "PermitRootLogin no"
        "PasswordAuthentication no"
        "PubkeyAuthentication yes"
        "X11Forwarding no"
        "MaxAuthTries 3"
        "ClientAliveInterval 300"
        "ClientAliveCountMax 2"
    )
    
    for setting in "${settings[@]}"; do
        local key="${setting%% *}"
        
        if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] Would set: ${setting}"
        else
            # Remove existing setting
            sed -i "/^${key}/d" "${sshd_config}"
            # Add new setting
            echo "${setting}" >> "${sshd_config}"
            log_debug "Applied: ${setting}"
        fi
    done
    
    log_success "SSH hardening completed"
}

# Apply sysctl security settings
harden_sysctl() {
    local sysctl_conf="/etc/sysctl.d/99-ubopt-security.conf"
    
    log_info "Applying sysctl security settings..."
    
    local settings=(
        "# Cool Llama Security Hardening"
        "net.ipv4.conf.all.rp_filter=1"
        "net.ipv4.conf.default.rp_filter=1"
        "net.ipv4.icmp_echo_ignore_broadcasts=1"
        "net.ipv4.conf.all.accept_source_route=0"
        "net.ipv4.conf.default.accept_source_route=0"
        "net.ipv4.conf.all.accept_redirects=0"
        "net.ipv4.conf.default.accept_redirects=0"
        "net.ipv4.conf.all.secure_redirects=0"
        "net.ipv4.conf.default.secure_redirects=0"
        "net.ipv4.conf.all.send_redirects=0"
        "net.ipv4.conf.default.send_redirects=0"
        "net.ipv6.conf.all.accept_redirects=0"
        "net.ipv6.conf.default.accept_redirects=0"
        "kernel.randomize_va_space=2"
    )
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would write sysctl settings to ${sysctl_conf}"
        return 0
    fi
    
    # Write settings to file
    printf "%s\n" "${settings[@]}" > "${sysctl_conf}"
    
    # Apply settings
    sysctl -p "${sysctl_conf}" >/dev/null 2>&1
    
    log_success "Sysctl hardening completed"
}

# Configure firewall baseline
harden_firewall() {
    log_info "Configuring firewall baseline..."
    
    # Check for firewall tools
    if command_exists ufw; then
        harden_firewall_ufw
    elif command_exists firewall-cmd; then
        harden_firewall_firewalld
    else
        log_warn "No supported firewall found (ufw or firewalld)"
        return 1
    fi
}

# Configure UFW (Ubuntu/Debian)
harden_firewall_ufw() {
    log_info "Configuring UFW..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would configure UFW"
        return 0
    fi
    
    # Default deny incoming
    ufw default deny incoming >/dev/null 2>&1
    # Default allow outgoing
    ufw default allow outgoing >/dev/null 2>&1
    # Allow SSH
    ufw allow 22/tcp >/dev/null 2>&1
    # Enable UFW
    ufw --force enable >/dev/null 2>&1
    
    log_success "UFW configured"
}

# Configure firewalld (Fedora/RHEL)
harden_firewall_firewalld() {
    log_info "Configuring firewalld..."
    
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would configure firewalld"
        return 0
    fi
    
    systemctl enable firewalld >/dev/null 2>&1
    systemctl start firewalld >/dev/null 2>&1
    firewall-cmd --set-default-zone=public >/dev/null 2>&1
    firewall-cmd --permanent --add-service=ssh >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
    
    log_success "Firewalld configured"
}

# Main hardening entry point
harden_apply() {
    log_info "Applying security hardening baseline..."
    local changed=false
    
    # Check if we need root
    if [[ "${UBOPT_DRY_RUN}" != "true" ]]; then
        require_root || return 1
    fi
    
    # Apply hardening steps
    # Determine if settings already applied (simple heuristic)
    if grep -q "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null && \
       grep -q "net.ipv4.conf.all.rp_filter=1" /etc/sysctl.d/99-ubopt-security.conf 2>/dev/null; then
        changed=false
    else
        changed=true
    fi

    harden_sysctl
    harden_ssh
    harden_firewall
    
    log_success "Security hardening completed"
    log_info "idempotency changed=${changed}"
    log_warn "Please review changes and restart services as needed"

    # Persist last hardening timestamp in state file
    if [[ "${UBOPT_DRY_RUN}" != "true" ]]; then
        local state_dir="/var/lib/ubopt"
        local state_file="${state_dir}/state.json"
        local ts
        ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        mkdir -p "${state_dir}" 2>/dev/null || true
        if command -v jq &>/dev/null && [[ -f "${state_file}" ]]; then
            tmp=$(mktemp)
            jq -c --arg ts "$ts" '.last_hardening_timestamp=$ts' "${state_file}" > "$tmp" 2>/dev/null || echo "{}" > "$tmp"
            mv "$tmp" "${state_file}" || echo '{"last_hardening_timestamp":"'"$ts"'"}' > "${state_file}"
        else
            echo '{"last_hardening_timestamp":"'"$ts"'"}' > "${state_file}"
        fi
        log_info "Recorded last_hardening_timestamp=${ts}"
    fi
}

# Run hardening if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    harden_apply "$@"
fi
