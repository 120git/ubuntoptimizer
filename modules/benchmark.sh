#!/usr/bin/env bash
# =============================================================================
# Benchmark Module - Advanced system performance testing
# Features: cpu/disk/mem tests, tool fallbacks, JSON output
# =============================================================================

set -Eeo pipefail

# Source common library if not already sourced
if [[ -z "${UBOPT_COMMON_LOADED:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
    # shellcheck source=../lib/common.sh
    source "${SCRIPT_DIR}/lib/common.sh"
fi

# Default settings from config
BENCHMARK_DURATION="$(cfg_get 'benchmark.duration' '10')"
BENCHMARK_CPU_THREADS="$(cfg_get 'benchmark.cpu.threads' '0')"  # 0 = auto-detect
BENCHMARK_DISK_SIZE_MB="$(cfg_get 'benchmark.disk.size_mb' '1024')"
BENCHMARK_FORMAT="$(cfg_get 'benchmark.format' 'text')"

# =============================================================================
# CPU BENCHMARK
# =============================================================================

benchmark_cpu() {
    local duration="${1:-${BENCHMARK_DURATION}}"
    local threads="${2:-${BENCHMARK_CPU_THREADS}}"
    
    # Auto-detect thread count
    if [[ ${threads} -eq 0 ]]; then
        threads=$(nproc 2>/dev/null || echo "1")
    fi
    
    log_info "Running CPU benchmark (duration: ${duration}s, threads: ${threads})..."
    
    local tool="unknown"
    local result=""
    local events=0
    local events_per_sec="0.00"
    
    # Try sysbench first
    if command -v sysbench &>/dev/null; then
        tool="sysbench"
        log_debug "Using sysbench for CPU test"
        
        local output
        output=$(sysbench cpu --cpu-max-prime=20000 --threads="${threads}" --time="${duration}" run 2>&1)
        
        # Parse events per second
        if echo "${output}" | grep -q "events per second:"; then
            events_per_sec=$(echo "${output}" | grep "events per second:" | awk '{print $NF}')
        fi
        
        result="events_per_sec: ${events_per_sec}"
        
    # Fallback to openssl speed test
    elif command -v openssl &>/dev/null; then
        tool="openssl"
        log_debug "Using openssl for CPU test"
        
        local output
        output=$(timeout "${duration}s" openssl speed -multi "${threads}" sha256 2>&1 || true)
        
        # Parse throughput (MB/s)
        if echo "${output}" | grep -q "sha256"; then
            local throughput
            throughput=$(echo "${output}" | grep "sha256" | tail -1 | awk '{print $(NF-1)}')
            result="throughput_kb_sec: ${throughput}"
        else
            result="completed"
        fi
        
    else
        log_warn "No CPU benchmark tool available (sysbench, openssl)"
        return "${EXIT_UNSUPPORTED}"
    fi
    
    # Output results
    if [[ "${BENCHMARK_FORMAT}" == "json" ]]; then
        cat <<EOF
{
  "test": "cpu",
  "tool": "${tool}",
  "threads": ${threads},
  "duration_sec": ${duration},
  "result": "${result}",
  "host": "$(hostname -f 2>/dev/null || hostname)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    else
        echo -e "${COLOR_GREEN}CPU Benchmark:${COLOR_RESET}"
        echo "  Tool: ${tool}"
        echo "  Threads: ${threads}"
        echo "  Duration: ${duration}s"
        echo "  Result: ${result}"
    fi
}

# =============================================================================
# DISK BENCHMARK
# =============================================================================

benchmark_disk() {
    local size_mb="${1:-${BENCHMARK_DISK_SIZE_MB}}"
    local test_file="/tmp/ubopt_bench_$$"
    
    log_info "Running disk I/O benchmark (size: ${size_mb}MB)..."
    
    local tool="unknown"
    local read_mbps="0.00"
    local write_mbps="0.00"
    
    # Try fio first (comprehensive I/O benchmark)
    if command -v fio &>/dev/null; then
        tool="fio"
        log_debug "Using fio for disk test"
        
        local output
        output=$(fio --name=ubopt_test --filename="${test_file}" --size="${size_mb}M" \
                     --rw=readwrite --bs=4k --direct=1 --ioengine=libaio --numjobs=1 \
                     --time_based --runtime="${BENCHMARK_DURATION}" --group_reporting \
                     --output-format=normal 2>&1 || true)
        
        # Parse throughput
        if echo "${output}" | grep -q "READ:"; then
            read_mbps=$(echo "${output}" | grep "READ:" | grep -oP 'BW=\K[0-9.]+(?=MiB/s)' || echo "0.00")
        fi
        if echo "${output}" | grep -q "WRITE:"; then
            write_mbps=$(echo "${output}" | grep "WRITE:" | grep -oP 'BW=\K[0-9.]+(?=MiB/s)' || echo "0.00")
        fi
        
        rm -f "${test_file}"
        
    # Fallback to dd (basic sequential I/O)
    else
        tool="dd"
        log_debug "Using dd for disk test"
        
        # Write test
        local write_output
        write_output=$(dd if=/dev/zero of="${test_file}" bs=1M count="${size_mb}" conv=fdatasync 2>&1 || true)
        if echo "${write_output}" | grep -q "MB/s"; then
            write_mbps=$(echo "${write_output}" | grep -oP '[0-9.]+(?= MB/s)')
        fi
        
        # Read test
        local read_output
        read_output=$(dd if="${test_file}" of=/dev/null bs=1M 2>&1 || true)
        if echo "${read_output}" | grep -q "MB/s"; then
            read_mbps=$(echo "${read_output}" | grep -oP '[0-9.]+(?= MB/s)')
        fi
        
        rm -f "${test_file}"
    fi
    
    # Output results
    if [[ "${BENCHMARK_FORMAT}" == "json" ]]; then
        cat <<EOF
{
  "test": "disk",
  "tool": "${tool}",
  "size_mb": ${size_mb},
  "read_mbps": ${read_mbps},
  "write_mbps": ${write_mbps},
  "host": "$(hostname -f 2>/dev/null || hostname)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    else
        echo -e "${COLOR_GREEN}Disk I/O Benchmark:${COLOR_RESET}"
        echo "  Tool: ${tool}"
        echo "  Size: ${size_mb}MB"
        echo "  Read: ${read_mbps} MB/s"
        echo "  Write: ${write_mbps} MB/s"
    fi
}

# =============================================================================
# MEMORY BENCHMARK
# =============================================================================

benchmark_mem() {
    local duration="${1:-${BENCHMARK_DURATION}}"
    
    log_info "Running memory benchmark (duration: ${duration}s)..."
    
    local tool="unknown"
    local ops_per_sec="0.00"
    local bandwidth_mbps="0.00"
    
    # Try stress-ng first
    if command -v stress-ng &>/dev/null; then
        tool="stress-ng"
        log_debug "Using stress-ng for memory test"
        
        local output
        output=$(stress-ng --vm 1 --vm-bytes 512M --vm-method all --metrics-brief \
                          --timeout "${duration}s" 2>&1 || true)
        
        # Parse operations per second
        if echo "${output}" | grep -q "bogo ops/s"; then
            ops_per_sec=$(echo "${output}" | grep "bogo ops/s" | awk '{print $(NF-2)}')
        fi
        
    # Fallback to reading /proc/meminfo and simple memory test
    else
        tool="meminfo"
        log_debug "Using meminfo for memory statistics"
        
        local total_mem
        local free_mem
        local used_pct
        
        if [[ -f /proc/meminfo ]]; then
            total_mem=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
            free_mem=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
            used_pct=$(awk "BEGIN {printf \"%.2f\", (($total_mem - $free_mem) / $total_mem) * 100}")
            
            bandwidth_mbps="${used_pct}"  # Store as utilization percentage
        fi
    fi
    
    # Output results
    if [[ "${BENCHMARK_FORMAT}" == "json" ]]; then
        cat <<EOF
{
  "test": "memory",
  "tool": "${tool}",
  "duration_sec": ${duration},
  "ops_per_sec": ${ops_per_sec},
  "bandwidth_or_utilization": ${bandwidth_mbps},
  "host": "$(hostname -f 2>/dev/null || hostname)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    else
        echo -e "${COLOR_GREEN}Memory Benchmark:${COLOR_RESET}"
        echo "  Tool: ${tool}"
        echo "  Duration: ${duration}s"
        [[ "${tool}" == "stress-ng" ]] && echo "  Ops/sec: ${ops_per_sec}"
        [[ "${tool}" == "meminfo" ]] && echo "  Memory utilization: ${bandwidth_mbps}%"
    fi
}

# =============================================================================
# MAIN BENCHMARK RUNNER
# =============================================================================

benchmark_run() {
    local tests="cpu,disk,mem"  # Default: all tests
    local duration="${BENCHMARK_DURATION}"
    local format="${BENCHMARK_FORMAT}"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tests)
                tests="$2"
                shift 2
                ;;
            --duration)
                duration="$2"
                shift 2
                ;;
            --format)
                format="$2"
                BENCHMARK_FORMAT="${format}"
                shift 2
                ;;
            --help|-h)
                benchmark_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                benchmark_help
                exit 1
                ;;
        esac
    done
    
    log_info "Starting system benchmark suite..."
    
    [[ "${format}" != "json" ]] && echo -e "\n${COLOR_CYAN}System Benchmark Suite${COLOR_RESET}"
    [[ "${format}" != "json" ]] && echo "======================="
    [[ "${format}" != "json" ]] && echo ""
    
    # JSON array start
    [[ "${format}" == "json" ]] && echo "{"
    [[ "${format}" == "json" ]] && echo "  \"benchmarks\": ["
    
    local first=true
    
    # Run selected tests
    IFS=',' read -ra TEST_ARRAY <<< "${tests}"
    for test in "${TEST_ARRAY[@]}"; do
        test=$(echo "${test}" | xargs)  # Trim whitespace
        
        [[ "${format}" == "json" && "${first}" == "false" ]] && echo "    ,"
        
        case "${test}" in
            cpu)
                [[ "${format}" == "json" ]] && echo -n "    "
                benchmark_cpu "${duration}"
                ;;
            disk)
                [[ "${format}" == "json" ]] && echo -n "    "
                benchmark_disk
                ;;
            mem|memory)
                [[ "${format}" == "json" ]] && echo -n "    "
                benchmark_mem "${duration}"
                ;;
            *)
                log_warn "Unknown test: ${test}"
                ;;
        esac
        
        [[ "${format}" != "json" ]] && echo ""
        first=false
    done
    
    # JSON array end
    [[ "${format}" == "json" ]] && echo ""
    [[ "${format}" == "json" ]] && echo "  ]"
    [[ "${format}" == "json" ]] && echo "}"
    
    log_success "Benchmark suite completed"
}

# =============================================================================
# HELP
# =============================================================================

benchmark_help() {
    cat <<EOF
${COLOR_CYAN}Benchmark Module - System Performance Testing${COLOR_RESET}

Usage:
  $(basename "$0") [options]

Options:
  --tests <tests>       Comma-separated list of tests to run
                        Available: cpu, disk, mem
                        Default: cpu,disk,mem
  
  --duration <seconds>  Duration for CPU/memory tests in seconds
                        Default: ${BENCHMARK_DURATION}
  
  --format <format>     Output format: text or json
                        Default: ${BENCHMARK_FORMAT}
  
  -h, --help           Show this help message

Tests:
  cpu    - CPU performance test (sysbench or openssl fallback)
  disk   - Disk I/O throughput test (fio or dd fallback)
  mem    - Memory performance test (stress-ng or meminfo fallback)

Examples:
  # Run all benchmarks with defaults
  $(basename "$0")
  
  # Run only CPU and disk tests
  $(basename "$0") --tests cpu,disk
  
  # Run with 30 second duration and JSON output
  $(basename "$0") --duration 30 --format json
  
  # CPU test with custom thread count
  $(basename "$0") --tests cpu --duration 15

Configuration:
  Config file: /etc/ubopt/ubopt.yaml
  - benchmark.duration: Default test duration
  - benchmark.cpu.threads: CPU thread count (0=auto)
  - benchmark.disk.size_mb: Disk test file size
  - benchmark.format: Output format (text/json)

EOF
}

# Run benchmark if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    benchmark_run "$@"
fi
