#!/usr/bin/env bash
# ==========================================
# Ultimate Linux System Optimization Suite
# Works with: Ubuntu, Debian, Fedora, RHEL, Arch
# Author: Linux Guru (ChatGPT)
# Version: 2.0
# ==========================================

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Global variables
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LOG_FILE="/var/log/system-optimize.log"
BACKUP_DIR="/var/backups/system-optimize"
VERSION="2.0"

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[96m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ASCII Cool Llama logo
print_logo() {
    echo -ne "${CYAN}"
    cat <<'ASCII_EOF'
              
           ██████╗ ██████╗  ██████╗ ██╗         
          ██╔════╝██╔═══██╗██╔═══██╗██║         
          ██║     ██║   ██║██║   ██║██║         
          ██║     ██║   ██║██║   ██║██║         
          ╚██████╗╚██████╔╝╚██████╔╝███████╗    
           ╚═════╝ ╚═════╝  ╚═════╝ ╚══════╝    
                                                 
          ██╗     ██╗      █████╗ ███╗   ███╗ █████╗ 
          ██║     ██║     ██╔══██╗████╗ ████║██╔══██╗
          ██║     ██║     ███████║██╔████╔██║███████║
          ██║     ██║     ██╔══██║██║╚██╔╝██║██╔══██║
          ███████╗███████╗██║  ██║██║ ╚═╝ ██║██║  ██║
          ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝
                                                 
            System Optimizer for Ubuntu & Friends
ASCII_EOF
    echo -e "${NC}"
}

# Function to log messages
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | sudo tee -a "$LOG_FILE"
    case "$level" in
        INFO) echo -e "${GREEN}ℹ️ ${message}${NC}" ;;
        WARN) echo -e "${YELLOW}⚠️ ${message}${NC}" ;;
        ERROR) echo -e "${RED}❌ ${message}${NC}" ;;
        SUCCESS) echo -e "${GREEN}✅ ${message}${NC}" ;;
    esac
}

# Function to check root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

# Function to create necessary directories
init_directories() {
    sudo mkdir -p "$BACKUP_DIR"
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
}

# Function to show progress
show_progress() {
    local message=$1
    echo -ne "${BLUE}⏳ ${message}...${NC}\r"
}

# Function to check system requirements
check_requirements() {
    local required_tools=("curl" "wget" "htop" "lsof" "iotop")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log "WARN" "Required tool '$tool' is not installed. Installing..."
            case "$DISTRO" in
                ubuntu|debian)
                    sudo apt-get install -y "$tool"
                    ;;
                fedora|rhel|centos)
                    sudo dnf install -y "$tool"
                    ;;
                arch|manjaro)
                    sudo pacman -S --noconfirm "$tool"
                    ;;
            esac
        fi
    done
}

# Function to backup important configurations
backup_system() {
    local backup_date=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$backup_date"
    
    log "INFO" "Creating system backup at $backup_path"
    sudo mkdir -p "$backup_path"
    
    # Backup important configuration files
    sudo cp -r /etc/fstab "$backup_path/"
    sudo cp -r /etc/sysctl.conf "$backup_path/"
    sudo cp -r /etc/systemd/system.conf "$backup_path/"
    
    # Backup package lists
    case "$DISTRO" in
        ubuntu|debian)
            dpkg --get-selections > "$backup_path/package_list"
            ;;
        fedora|rhel|centos)
            rpm -qa > "$backup_path/package_list"
            ;;
        arch|manjaro)
            pacman -Qqe > "$backup_path/package_list"
            ;;
    esac
    
    log "SUCCESS" "Backup completed successfully"
}

# Function to benchmark system
benchmark_system() {
    log "INFO" "Running quick system benchmark..."
    
    # CPU benchmark
    log "INFO" "Testing CPU performance..."
    cpu_score=$(dd if=/dev/zero bs=1M count=1024 2>&1 | grep copied | awk '{print $8}')
    
    # Memory benchmark
    log "INFO" "Testing memory performance..."
    free -h | sudo tee -a "$LOG_FILE"
    
    # Disk benchmark
    log "INFO" "Testing disk performance..."
    dd if=/dev/zero of=/tmp/test bs=64k count=16k conv=fdatasync 2>&1 | sudo tee -a "$LOG_FILE"
    rm /tmp/test
    
    log "SUCCESS" "Benchmark completed"
}

# Initialize script
init_directories
log "INFO" "Starting Ultimate Linux System Optimization Suite v${VERSION}"

# Function to display system info
show_system_info() {
    log "INFO" "Collecting system information..."
    echo -e "\n${BOLD}System Information:${NC}"
    echo -e "${BLUE}------------------------${NC}"
    echo -e "${BOLD}OS:${NC} $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo -e "${BOLD}Kernel:${NC} $(uname -r)"
    echo -e "${BOLD}CPU:${NC} $(lscpu | grep 'Model name' | cut -d':' -f2- | sed 's/^[ \t]*//')"
    echo -e "${BOLD}Memory:${NC} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${BOLD}Disk Usage:${NC}"
    df -h / | awk 'NR==2 {print $5 " used (" $3 " of " $2 ")"}'
}

# Function to check system health
check_system_health() {
    log "INFO" "Performing system health check..."
    
    # Check CPU temperature if possible
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
        log "INFO" "CPU Temperature: ${temp}°C"
    fi
    
    # Check disk health
    if command -v smartctl &>/dev/null; then
        log "INFO" "Checking disk health..."
        for disk in $(lsblk -d -o name | grep -v "name"); do
            sudo smartctl -H "/dev/${disk}" 2>/dev/null || true
        done
    fi
    
    # Check for high CPU processes
    log "INFO" "Checking resource usage..."
    ps aux | awk 'NR>1{if($3>50.0) print "High CPU: "$11" ("$3"%)"}'
    
    # Check memory usage
    free -h | awk '/^Mem:/ {print "Memory Usage: " $3 "/" $2 " (" int($3/$2*100) "%)"}'
}

# ---- Identify Distro ----
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    log "ERROR" "Could not detect Linux distribution."
    exit 1
fi

log "INFO" "Detected distro: $PRETTY_NAME"
show_system_info
check_system_health

# Function to update system packages
update_system() {
    log "INFO" "Starting system update..."
    
    case "$DISTRO" in
        ubuntu|debian)
            show_progress "Updating package lists"
            sudo apt update -y 2>&1 | sudo tee -a "$LOG_FILE"
            
            show_progress "Upgrading packages"
            sudo apt full-upgrade -y 2>&1 | sudo tee -a "$LOG_FILE"
            
            show_progress "Removing unused packages"
            sudo apt autoremove --purge -y 2>&1 | sudo tee -a "$LOG_FILE"
            
            show_progress "Cleaning package cache"
            sudo apt autoclean -y 2>&1 | sudo tee -a "$LOG_FILE"
            sudo apt clean -y 2>&1 | sudo tee -a "$LOG_FILE"
            
            # Update snap packages if available
            if command -v snap &>/dev/null; then
                show_progress "Updating snap packages"
                sudo snap refresh 2>&1 | sudo tee -a "$LOG_FILE"
            fi
            ;;
            
        fedora)
            show_progress "Upgrading system packages"
            sudo dnf upgrade --refresh -y 2>&1 | sudo tee -a "$LOG_FILE"
            
            show_progress "Removing unused packages"
            sudo dnf autoremove -y 2>&1 | sudo tee -a "$LOG_FILE"
            
            show_progress "Cleaning package cache"
            sudo dnf clean all -y 2>&1 | sudo tee -a "$LOG_FILE"
            ;;
            
        rhel|centos)
            show_progress "Upgrading system packages"
            sudo yum update -y 2>&1 | sudo tee -a "$LOG_FILE"
            
            show_progress "Removing unused packages"
            sudo yum autoremove -y 2>&1 | sudo tee -a "$LOG_FILE"
            
            show_progress "Cleaning package cache"
            sudo yum clean all -y 2>&1 | sudo tee -a "$LOG_FILE"
            ;;
            
        arch|manjaro)
            show_progress "Syncing and upgrading packages"
            sudo pacman -Syu --noconfirm 2>&1 | sudo tee -a "$LOG_FILE"
            
            show_progress "Removing orphaned packages"
            sudo pacman -Rns $(pacman -Qdtq) --noconfirm 2>/dev/null || true
            
            show_progress "Cleaning package cache"
            sudo paccache -r 2>&1 | sudo tee -a "$LOG_FILE"
            ;;
            
        *)
            log "WARN" "Unsupported distro for automatic package management."
            return 1
            ;;
    esac
    
    log "SUCCESS" "System update completed successfully"
}

# Execute system update
update_system

# Function to optimize system performance
optimize_system() {
    log "INFO" "Starting system optimization..."
    
    # Optimize systemd journal
    show_progress "Optimizing systemd journal"
    sudo journalctl --vacuum-time=14d 2>/dev/null || true
    sudo journalctl --vacuum-size=500M 2>/dev/null || true
    
    # Optimize SSD/NVMe if present
    if command -v systemctl &>/dev/null && systemctl list-unit-files | grep -q fstrim.timer; then
        show_progress "Optimizing SSD/NVMe drives"
        sudo systemctl enable fstrim.timer
        sudo systemctl start fstrim.timer
        sudo fstrim -av 2>&1 | sudo tee -a "$LOG_FILE"
    fi
    
    # Optimize memory management
    show_progress "Optimizing memory management"
    if [ -w /etc/sysctl.conf ]; then
        # Create backup
        sudo cp /etc/sysctl.conf "${BACKUP_DIR}/sysctl.conf.bak"
        
        # Remove existing settings if any
        sudo sed -i '/vm.swappiness/d' /etc/sysctl.conf
        sudo sed -i '/vm.vfs_cache_pressure/d' /etc/sysctl.conf
        sudo sed -i '/vm.dirty_ratio/d' /etc/sysctl.conf
        sudo sed -i '/vm.dirty_background_ratio/d' /etc/sysctl.conf
        
        # Add optimized settings
        {
            echo "# Optimized memory management settings"
            echo "vm.swappiness=10"
            echo "vm.vfs_cache_pressure=50"
            echo "vm.dirty_ratio=10"
            echo "vm.dirty_background_ratio=5"
            echo "vm.dirty_writeback_centisecs=1500"
        } | sudo tee -a /etc/sysctl.conf
        
        sudo sysctl -p 2>&1 | sudo tee -a "$LOG_FILE"
    fi
    
    # Optimize I/O scheduler for SSDs
    show_progress "Optimizing I/O scheduler"
    for disk in $(lsblk -d -o name | grep -v "name"); do
        if [ -w "/sys/block/$disk/queue/scheduler" ]; then
            echo "mq-deadline" | sudo tee "/sys/block/$disk/queue/scheduler" 2>/dev/null || true
        fi
    done
    
    # Check and optimize service status
    show_progress "Checking system services"
    local failed_services=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
    if [ "$failed_services" -gt 0 ]; then
        log "WARN" "Found $failed_services failed services"
        systemctl --failed --no-legend 2>&1 | sudo tee -a "$LOG_FILE"
    fi
    
    # Optimize and clean package managers
    show_progress "Optimizing package managers"
    
    # Flatpak optimization
    if command -v flatpak &>/dev/null; then
        log "INFO" "Optimizing Flatpak"
        flatpak uninstall --unused -y 2>&1 | sudo tee -a "$LOG_FILE"
        flatpak repair --system 2>&1 | sudo tee -a "$LOG_FILE"
    fi
    
    # Snap optimization
    if command -v snap &>/dev/null; then
        log "INFO" "Optimizing Snap"
        snap list --all | awk '/disabled/{print $1, $3}' | \
        while read snapname revision; do
            sudo snap remove "$snapname" --revision="$revision" 2>&1 | sudo tee -a "$LOG_FILE"
        done
    fi
    
    # Clean user cache
    show_progress "Cleaning user cache"
    find /home -type f -name .DS_Store -delete 2>/dev/null || true
    find /home -type f -name Thumbs.db -delete 2>/dev/null || true
    
    # Optimize man database
    show_progress "Optimizing man database"
    sudo mandb -c 2>/dev/null || true
    
    log "SUCCESS" "System optimization completed"
}

# Function to show menu
show_menu() {
    clear
    print_logo
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BOLD}       Cool Llama System Optimizer${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "1) Run Full System Optimization"
    echo -e "2) Update System Only"
    echo -e "3) Optimize System Only"
    echo -e "4) Show System Information"
    echo -e "5) Check System Health"
    echo -e "6) Create System Backup"
    echo -e "7) Run System Benchmark"
    echo -e "8) View Logs"
    echo -e "9) Exit"
    echo
    echo -n "Please select an option [1-9]: "
}

# Function to handle user input
handle_menu() {
    local choice
    read -r choice
    case $choice in
        1)
            backup_system
            update_system
            optimize_system
            benchmark_system
            ;;
        2)
            update_system
            ;;
        3)
            optimize_system
            ;;
        4)
            show_system_info
            ;;
        5)
            check_system_health
            ;;
        6)
            backup_system
            ;;
        7)
            benchmark_system
            ;;
        8)
            if [ -f "$LOG_FILE" ]; then
                less "$LOG_FILE"
            else
                log "ERROR" "Log file not found"
            fi
            ;;
        9)
            log "INFO" "Exiting..."
            exit 0
            ;;
        *)
            log "ERROR" "Invalid option"
            ;;
    esac
}

# Main execution
check_root
check_requirements

while true; do
    show_menu
    handle_menu
    echo
    read -p "Press Enter to continue..."
done
