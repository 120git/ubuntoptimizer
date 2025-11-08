# Cool Llama Linux Optimizer - CLI Documentation

## Command Reference

### Global Options

```bash
--dry-run          # Preview changes without applying them
--verbose, -v      # Enable detailed output
--help, -h         # Show help message
--version          # Show version information
```

### Commands

## update

Manage system package updates and security patches.

### Subcommands

#### `update check`
Check for available system updates.

```bash
ubopt update check
```

**Exit Codes:**
- `0`: No updates available
- `20`: Updates are available
- `1`: Error occurred

**Examples:**
```bash
# Check for updates
ubopt update check

# Verbose check
ubopt update check --verbose
```

#### `update apply`
Apply available system updates.

```bash
ubopt update apply [OPTIONS]
```

**Options:**
- `--security`: Only apply security updates

**Examples:**
```bash
# Apply all updates (dry-run)
ubopt update apply --dry-run

# Apply only security updates
ubopt update apply --security

# Apply all updates
sudo ubopt update apply
```

---

## hardening

Apply security hardening baseline to the system.

### Subcommands

#### `hardening apply`
Apply security hardening configurations.

```bash
ubopt hardening apply
```

**What it does:**
- Hardens SSH configuration (disable root login, password auth)
- Applies secure sysctl settings
- Configures firewall baseline (UFW or firewalld)

**Examples:**
```bash
# Preview hardening changes
sudo ubopt hardening apply --dry-run

# Apply hardening
sudo ubopt hardening apply
```

---

## health

Display system health and status information.

### Usage

```bash
ubopt health [OPTIONS]
```

**Options:**
- `--json`: Output in JSON format

**Examples:**
```bash
# Human-readable health report
ubopt health

# JSON output for parsing
ubopt health --json

# Pipe JSON to jq
ubopt health --json | jq .
```

**JSON Schema:**
```json
{
  "hostname": "string",
  "kernel": "string",
  "uptime_seconds": number,
  "uptime": "string",
  "disk": {
    "root_usage_percent": number
  },
  "memory": {
    "total_mb": number,
    "used_mb": number,
    "usage_percent": number
  },
  "cpu": {
    "count": number,
    "load_1min": number,
    "load_5min": number,
    "load_15min": number
  },
  "distribution": "string"
}
```

---

## backup

Create backup of system configuration files.

### Usage

```bash
ubopt backup [DIRECTORY]
```

**Arguments:**
- `DIRECTORY`: Backup destination (default: `/var/backups/ubopt`)

**Examples:**
```bash
# Create backup with default location
sudo ubopt backup

# Create backup in custom location
sudo ubopt backup /tmp/my-backup

# Dry-run
sudo ubopt backup --dry-run
```

---

## benchmark

Run system performance benchmarks.

### Usage

```bash
ubopt benchmark
```

**What it tests:**
- CPU performance
- Disk I/O performance

**Examples:**
```bash
# Run benchmarks
ubopt benchmark

# Verbose output
ubopt benchmark --verbose
```

---

## report

Generate comprehensive system report.

### Usage

```bash
ubopt report
```

**Includes:**
- System health information
- Update availability check
- System specifications

**Examples:**
```bash
# Generate full report
ubopt report

# Redirect to file
ubopt report > system-report.txt
```

---

## Common Workflows

### Daily Maintenance

```bash
# Check system health
ubopt health

# Check for updates
ubopt update check

# If updates available, preview them
ubopt update apply --dry-run

# Apply updates
sudo ubopt update apply
```

### Initial System Setup

```bash
# Generate baseline report
ubopt report > initial-report.txt

# Create configuration backup
sudo ubopt backup

# Apply security hardening
sudo ubopt hardening apply --dry-run  # Preview
sudo ubopt hardening apply             # Apply

# Update system
sudo ubopt update apply
```

### Security Audit

```bash
# Check current health
ubopt health --json > health-before.json

# Apply hardening (dry-run first)
sudo ubopt hardening apply --dry-run
sudo ubopt hardening apply

# Verify changes
ubopt health --json > health-after.json
diff health-before.json health-after.json
```

### Automated Daily Updates

Enable the systemd timer for daily security updates:

```bash
# Install systemd units
sudo make install

# Enable and start timer
sudo systemctl enable ubopt-agent.timer
sudo systemctl start ubopt-agent.timer

# Check timer status
systemctl status ubopt-agent.timer

# View logs
journalctl -u ubopt-agent.service
```

---

## Environment Variables

- `UBOPT_DRY_RUN`: Enable dry-run mode (`true`/`false`)
- `UBOPT_VERBOSE`: Enable verbose output (`true`/`false`)
- `UBOPT_LOG_DIR`: Override log directory (default: `/var/log/ubopt`)
- `UBOPT_CONFIG_DIR`: Override config directory (default: `/etc/ubopt`)

**Examples:**
```bash
# Force dry-run mode
UBOPT_DRY_RUN=true ubopt update apply

# Verbose mode
UBOPT_VERBOSE=true ubopt health
```

---

## Configuration File

Copy the example configuration and customize:

```bash
sudo mkdir -p /etc/ubopt
sudo cp etc/ubopt.example.yaml /etc/ubopt/config.yaml
sudo $EDITOR /etc/ubopt/config.yaml
```

See `ubopt.example.yaml` for all available options.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0    | Success |
| 1    | General error |
| 20   | Updates available (check commands) |

---

## Logging

All operations are logged to:
- `/var/log/ubopt/ubopt.log` (JSON format)
- System syslog (via `logger`)

View recent logs:
```bash
# Last 50 lines
sudo tail -f /var/log/ubopt/ubopt.log

# With jq for pretty printing
sudo tail /var/log/ubopt/ubopt.log | jq .

# Via journalctl
journalctl -t ubopt
```

---

## Troubleshooting

### Permission Denied

Most operations require root privileges:
```bash
sudo ubopt update apply
```

### Dry-run doesn't show changes

Enable verbose mode:
```bash
ubopt update apply --dry-run --verbose
```

### Logs not created

Ensure log directory exists and is writable:
```bash
sudo mkdir -p /var/log/ubopt
sudo chmod 755 /var/log/ubopt
```

### Unsupported Distribution

Check if your distribution is detected:
```bash
ubopt health --verbose
```

Currently supported:
- Ubuntu, Debian, Linux Mint, Pop!_OS (APT)
- Fedora, RHEL, Rocky, AlmaLinux (DNF)
- Arch, Manjaro, EndeavourOS (Pacman)

---

## Examples by Distribution

### Ubuntu/Debian
```bash
# Security updates only
sudo ubopt update apply --security

# Full upgrade
sudo ubopt update apply
```

### Fedora/RHEL
```bash
# Minimal security upgrade
sudo ubopt update apply --security

# Full system refresh
sudo ubopt update apply
```

### Arch Linux
```bash
# Full system upgrade
sudo ubopt update apply
```

---

## Integration Examples

### Cron

```cron
# Check for updates daily at 3 AM
0 3 * * * /usr/local/bin/ubopt update check

# Apply security updates weekly
0 4 * * 0 /usr/local/bin/ubopt update apply --security
```

### Monitoring Script

```bash
#!/bin/bash
# Save health snapshot
ubopt health --json > /var/log/health-$(date +%Y%m%d).json

# Alert if updates available
if ubopt update check; then
    echo "System up to date"
else
    echo "Updates available!" | mail -s "System Updates" admin@example.com
fi
```

### CI/CD Pipeline

```yaml
# .gitlab-ci.yml example
security_check:
  script:
    - ubopt health --json
    - ubopt update check
  only:
    - schedules
```

---

For more information and updates, visit:
https://github.com/120git/cool-llama-linuxoptimizer
