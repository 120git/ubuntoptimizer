#!/usr/bin/env bash
# =============================================================================
# Benchmark Module - System performance testing
# =============================================================================

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Run system benchmark
benchmark_run() {
    log_info "Running system benchmark..."
    
    echo -e "\n${COLOR_CYAN}System Benchmark${COLOR_RESET}"
    echo "================="
    
    # CPU benchmark
    log_info "Testing CPU performance..."
    local cpu_start
    local cpu_end
    cpu_start=$(date +%s%N)
    dd if=/dev/zero bs=1M count=1024 2>/dev/null | md5sum >/dev/null
    cpu_end=$(date +%s%N)
    local cpu_time=$(( (cpu_end - cpu_start) / 1000000 ))
    echo -e "${COLOR_GREEN}CPU Test:${COLOR_RESET} ${cpu_time}ms"
    
    # Disk I/O benchmark
    log_info "Testing disk I/O performance..."
    local disk_result
    disk_result=$(dd if=/dev/zero of=/tmp/ubopt_test bs=64k count=16k conv=fdatasync 2>&1 | grep -o '[0-9.]* MB/s' || echo "N/A")
    rm -f /tmp/ubopt_test
    echo -e "${COLOR_GREEN}Disk I/O:${COLOR_RESET} ${disk_result}"
    
    log_success "Benchmark completed"
}

# Run benchmark if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    benchmark_run "$@"
fi
