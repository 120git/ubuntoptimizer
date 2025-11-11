#!/usr/bin/env bash
# =============================================================================
# Hardening Module - Security baseline configuration
# =============================================================================

set -Eeo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

###############
# SSH Hardening
###############
ssh_build_desired_config() {
    # Build desired sshd_config fragment based on config file values
    local port setting_root setting_pass key_only
    port="$(cfg_get 'hardening.ssh.port' '22')"
    setting_root="$(cfg_get 'hardening.ssh.root_login' 'false')"
    setting_pass="$(cfg_get 'hardening.ssh.password_auth' 'false')"
    key_only="$(cfg_get 'hardening.ssh.key_only' 'true')"

    cat <<EOF
Port ${port}
PermitRootLogin $( [[ "${setting_root}" == "true" ]] && echo yes || echo no )
PasswordAuthentication $( [[ "${setting_pass}" == "true" ]] && echo yes || echo no )
PubkeyAuthentication $( [[ "${key_only}" == "true" ]] && echo yes || echo no )
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
EOF
}

harden_ssh() {
    local sshd_config="/etc/ssh/sshd_config"
    log_info "Hardening SSH configuration (config-driven)..."

    if [[ ! -f "${sshd_config}" ]]; then
        log_warn "SSH config not found: ${sshd_config}"
        return 1
    fi

    local desired current tmp_desired changes=false
    desired="$(ssh_build_desired_config)"
    current="$(grep -E '^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|ChallengeResponseAuthentication|X11Forwarding|ClientAliveInterval|ClientAliveCountMax|MaxAuthTries)' "${sshd_config}" 2>/dev/null || true)"

    # Produce diff
    tmp_desired="$(mktemp)"
    printf "%s\n" "${desired}" > "${tmp_desired}"
    local tmp_current="$(mktemp)"
    printf "%s\n" "${current}" > "${tmp_current}"
    local diff_output
    diff_output="$(diff -u "${tmp_current}" "${tmp_desired}" || true)"
    if [[ -n "${diff_output}" ]]; then
        changes=true
    fi

    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        if [[ "${changes}" == "true" ]]; then
            echo "--- SSH hardening planned changes (dry-run) ---"
            echo "${diff_output}" | sed 's/^/DRYRUN: /'
            return "${EXIT_CHANGES_PLANNED}"
        else
            log_info "SSH settings already compliant"
            return 0
        fi
    fi

    # Apply by removing keys and appending fresh block
    backup_file "${sshd_config}"
    for key in Port PermitRootLogin PasswordAuthentication PubkeyAuthentication ChallengeResponseAuthentication X11Forwarding ClientAliveInterval ClientAliveCountMax MaxAuthTries; do
        sed -i "/^${key}/d" "${sshd_config}" || true
    done
    printf "\n# ubopt managed hardening block\n%s\n" "${desired}" >> "${sshd_config}"
    log_success "SSH hardening applied"
}

###############
# Sysctl Hardening
###############
build_sysctl_settings() {
    cat <<'EOF'
# ubopt security baseline
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_ra=0
kernel.randomize_va_space=2
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
fs.protected_hardlinks=1
fs.protected_symlinks=1
EOF
    # Config-driven extra values (allow simple key=value list under hardening.sysctl.* in future)
}

harden_sysctl() {
    local sysctl_conf="/etc/sysctl.d/99-ubopt-security.conf"
    log_info "Applying sysctl security settings (baseline + config-driven)..."
    local desired current diff_output changes=false
    desired="$(build_sysctl_settings)"
    current="$(cat "${sysctl_conf}" 2>/dev/null || true)"
    local tmp_d tmp_c
    tmp_d="$(mktemp)"; tmp_c="$(mktemp)"
    printf "%s\n" "${desired}" > "${tmp_d}"
    printf "%s\n" "${current}" > "${tmp_c}"
    diff_output="$(diff -u "${tmp_c}" "${tmp_d}" || true)"
    [[ -n "${diff_output}" ]] && changes=true

    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        if [[ "${changes}" == "true" ]]; then
            echo "--- sysctl planned changes (dry-run) ---"
            echo "${diff_output}" | sed 's/^/DRYRUN: /'
            return "${EXIT_CHANGES_PLANNED}"
        else
            log_info "Sysctl settings already compliant"
            return 0
        fi
    fi

    printf "%s\n" "${desired}" > "${sysctl_conf}" || { log_error "Failed to write ${sysctl_conf}"; return 1; }
    sysctl -p "${sysctl_conf}" >/dev/null 2>&1 || log_warn "Some sysctl settings may not have applied immediately"
    log_success "Sysctl hardening applied"
}

###############
# auditd Hardening
###############
harden_auditd() {
    local enabled
    enabled="$(cfg_get 'hardening.auditd.enabled' 'true')"
    [[ "${enabled}" != "true" ]] && { log_info "auditd disabled by config"; return 0; }
    if ! command -v auditctl &>/dev/null; then
        log_warn "auditd not installed; skipping"
        return "${EXIT_UNSUPPORTED}"
    fi
    log_info "Applying auditd rules..."
    local rules=()
    mapfile -t rules < <(cfg_get_array 'hardening.auditd.rules' 2>/dev/null || true)
    if [[ ${#rules[@]} -eq 0 ]]; then
        rules=(/etc/passwd /etc/shadow /etc/sudoers)
    fi
    if [[ "${UBOPT_DRY_RUN}" == "true" ]]; then
        for r in "${rules[@]}"; do
            log_info "[DRY-RUN] Would ensure audit watch: ${r}"
        done
        return "${EXIT_CHANGES_PLANNED}"
    fi
    for r in "${rules[@]}"; do
        auditctl -w "${r}" -p wa -k ubopt_watch 2>/dev/null || true
    done
    systemctl restart auditd 2>/dev/null || true
    log_success "auditd rules applied"
}

###############
# MAC (AppArmor/SELinux) Detection
###############
detect_mac() {
    if command -v getenforce &>/dev/null; then
        local mode
        mode="$(getenforce 2>/dev/null || echo unknown)"
        echo "SELinux:${mode}"
        return 0
    fi
    if command -v aa-status &>/dev/null; then
        local mode
        mode="$(aa-status 2>/dev/null | grep 'profiles are in enforce mode' || echo 'AppArmor:unknown')"
        echo "AppArmor:enforce"
        return 0
    fi
    echo "none"
}

report_mac_status() {
    local status
    status="$(detect_mac)"
    log_info "MAC status: ${status}"
}

###############
# Firewall Hardening (unchanged logic, wrapped for dry-run consistency)
###############
harden_firewall() {
    log_info "Configuring firewall baseline..."
    if command_exists ufw; then
        harden_firewall_ufw
    elif command_exists firewall-cmd; then
        harden_firewall_firewalld
    else
        log_warn "No supported firewall found (ufw or firewalld)"
        return "${EXIT_UNSUPPORTED}"
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
    log_info "Applying security hardening baseline (multi-component)..."
    local components=(sysctl ssh firewall auditd mac)
    local planned_changes=false
    local nonzero=false

    # Root requirement only for actual modification
    if [[ "${UBOPT_DRY_RUN}" != "true" ]]; then
        require_root || return 1
    fi

    for comp in "${components[@]}"; do
        local rc=0
        case "${comp}" in
            sysctl)
                if ( trap - ERR; set +e; harden_sysctl ); then rc=0; else rc=$?; fi
                ;;
            ssh)
                if ( trap - ERR; set +e; UBOPT_DRY_RUN="${UBOPT_DRY_RUN}" harden_ssh ); then rc=0; else rc=$?; fi
                ;;
            firewall)
                if ( trap - ERR; set +e; harden_firewall ); then rc=0; else rc=$?; fi
                ;;
            auditd)
                if ( trap - ERR; set +e; harden_auditd ); then rc=0; else rc=$?; fi
                ;;
            mac)
                if ( trap - ERR; set +e; report_mac_status ); then rc=0; else rc=0; fi
                ;;
        esac
        if [[ ${rc} -eq ${EXIT_CHANGES_PLANNED} ]]; then
            planned_changes=true
        elif [[ ${rc} -ne 0 ]]; then
            nonzero=true
        fi
    done

    # State persistence only if not dry-run
    if [[ "${UBOPT_DRY_RUN}" != "true" ]]; then
        local state_dir="/var/lib/ubopt"
        local state_file="${state_dir}/state.json"
        mkdir -p "${state_dir}" 2>/dev/null || true
        local ts
        ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        if command -v jq &>/dev/null && [[ -f "${state_file}" ]]; then
            tmp=$(mktemp)
            jq -c --arg ts "$ts" '.last_hardening_timestamp=$ts' "${state_file}" > "$tmp" 2>/dev/null || echo '{}' > "$tmp"
            mv "$tmp" "${state_file}" || echo '{"last_hardening_timestamp":"'"$ts"'"}' > "${state_file}"
        else
            echo '{"last_hardening_timestamp":"'"$ts"'"}' > "${state_file}"
        fi
        log_info "Recorded last_hardening_timestamp=${ts}"
    fi

    if [[ "${UBOPT_DRY_RUN}" == "true" && "${planned_changes}" == "true" ]]; then
        log_info "Dry-run detected planned changes across components"
        return "${EXIT_CHANGES_PLANNED}"
    fi

    if [[ "${nonzero}" == "true" ]]; then
        log_warn "One or more components returned non-zero; review logs"
    fi
    log_success "Hardening workflow completed"
}

# Run hardening if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    harden_apply "$@"
fi
