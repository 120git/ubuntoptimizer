#!/usr/bin/env bash
# =============================================================================
# Health Module - System health monitoring and reporting
# =============================================================================

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Generate health report in JSON format
health_check_json() {
    local hostname
    local kernel
    local uptime_seconds
    local uptime_pretty
    local disk_usage
    local memory_total
    local memory_used
    local memory_percent
    local cpu_count
    local load_1min
    local load_5min
    local load_15min
    
    hostname=$(hostname)
    kernel=$(uname -r)
    uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
    uptime_pretty=$(uptime -p 2>/dev/null || echo "unknown")
    
    # Disk usage for root filesystem
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    
    # Memory info
    memory_total=$(free -m | awk 'NR==2 {print $2}')
    memory_used=$(free -m | awk 'NR==2 {print $3}')
    memory_percent=$(awk "BEGIN {printf \"%.0f\", (${memory_used}/${memory_total})*100}")
    
    # CPU info
    cpu_count=$(nproc)
    load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    load_5min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $2}' | tr -d ',')
    load_15min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $3}')
    
    # Build JSON output
    cat <<EOF
{
  "hostname": "${hostname}",
  "kernel": "${kernel}",
  "uptime_seconds": ${uptime_seconds},
  "uptime": "${uptime_pretty}",
  "disk": {
    "root_usage_percent": ${disk_usage}
  },
  "memory": {
    "total_mb": ${memory_total},
    "used_mb": ${memory_used},
    "usage_percent": ${memory_percent}
  },
  "cpu": {
    "count": ${cpu_count},
    "load_1min": ${load_1min},
    "load_5min": ${load_5min},
    "load_15min": ${load_15min}
  },
  "distribution": "$(get_distro_name)"
}
EOF
}

# Display human-readable health report
health_check_human() {
    log_info "System Health Report"
    echo ""
    echo -e "${COLOR_CYAN}═══════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_CYAN}    Cool Llama System Health${COLOR_RESET}"
    echo -e "${COLOR_CYAN}═══════════════════════════════════${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BLUE}Hostname:${COLOR_RESET}     $(hostname)"
    echo -e "${COLOR_BLUE}Distribution:${COLOR_RESET} $(get_distro_name)"
    echo -e "${COLOR_BLUE}Kernel:${COLOR_RESET}       $(uname -r)"
    echo -e "${COLOR_BLUE}Uptime:${COLOR_RESET}       $(uptime -p 2>/dev/null || echo 'unknown')"
    echo ""
    echo -e "${COLOR_BLUE}CPU Cores:${COLOR_RESET}    $(nproc)"
    echo -e "${COLOR_BLUE}Load Avg:${COLOR_RESET}     $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    echo -e "${COLOR_BLUE}Memory:${COLOR_RESET}"
    free -h | grep -E "Mem|Swap" | awk '{printf "  %-8s %8s / %8s (%s used)\n", $1":", $3, $2, "("int($3/$2*100)"%"}'
    echo ""
    echo -e "${COLOR_BLUE}Disk Usage:${COLOR_RESET}"
    df -h / /home 2>/dev/null | awk 'NR==1 || /\/$/ || /\/home$/' | \
        awk 'NR==1 {print "  "$0} NR>1 {printf "  %-20s %8s / %8s (%s)\n", $6, $3, $2, $5}'
    echo ""
}

# Main health check entry point
health_check() {
    local output_format="${1:-human}"
    
    case "${output_format}" in
        json)
            health_check_json
            ;;
        human|*)
            health_check_human
            ;;
    esac
}

# Run health check if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    health_check "$@"
fi
