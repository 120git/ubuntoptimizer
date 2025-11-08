# Cool Llama Linux Optimizer - Architecture

## Overview

Cool Llama Linux Optimizer (ubopt) is an enterprise-grade, modular system optimization and security toolkit for Linux distributions. Built with strict Bash best practices, it provides cross-distribution support through a provider-based architecture.

## Design Principles

1. **Modularity**: Each functionality is isolated in its own module
2. **Safety First**: Dry-run mode, backups, and rollback capabilities
3. **Cross-Distribution**: Provider abstraction for package managers
4. **Observability**: Structured JSON logging and comprehensive health monitoring
5. **Security**: Hardening baselines, minimal privileges, input validation

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     CLI Entrypoint                       │
│                      (cmd/ubopt)                         │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ├──> Common Library (lib/common.sh)
                       │    ├── Logging (JSON + syslog)
                       │    ├── Distro Detection
                       │    ├── Error Handling
                       │    └── Utility Functions
                       │
                       ├──> Providers (providers/*.sh)
                       │    ├── APT (Ubuntu/Debian)
                       │    ├── DNF (Fedora/RHEL)
                       │    └── Pacman (Arch)
                       │
                       └──> Modules (modules/*.sh)
                            ├── Update
                            ├── Hardening
                            ├── Health
                            ├── Backup
                            ├── Benchmark
                            └── Logging
```

## Directory Structure

```
cool-llama-linuxoptimizer/
├── cmd/
│   └── ubopt                   # Main CLI entrypoint
├── lib/
│   └── common.sh               # Core library
├── providers/
│   ├── apt.sh                  # Debian/Ubuntu provider
│   ├── dnf.sh                  # Fedora/RHEL provider
│   └── pacman.sh               # Arch Linux provider
├── modules/
│   ├── update.sh               # System update logic
│   ├── hardening.sh            # Security hardening
│   ├── health.sh               # Health monitoring
│   ├── backup.sh               # Configuration backup
│   ├── benchmark.sh            # Performance testing
│   └── logging.sh              # Log management
├── etc/
│   └── ubopt.example.yaml      # Configuration template
├── systemd/
│   ├── ubopt-agent.service     # Systemd service
│   └── ubopt-agent.timer       # Daily update timer
├── docs/
│   ├── ARCHITECTURE.md         # This file
│   └── CLI.md                  # CLI documentation
└── tests/bats/
    ├── cli.bats                # CLI tests
    ├── health.bats             # Health module tests
    └── update-dryrun.bats      # Update dry-run tests
```

## Component Responsibilities

### CLI Entrypoint (`cmd/ubopt`)
- Command parsing and dispatch
- Global flag handling (--dry-run, --verbose)
- Help and version information
- ASCII logo display

### Common Library (`lib/common.sh`)
- **Logging**: JSON-formatted logs with syslog integration
- **Distro Detection**: Identify distribution and select provider
- **Error Handling**: Trap-based error handling with stack traces
- **Utilities**: File backup, command execution, confirmation prompts

### Providers (`providers/*.sh`)
- **APT**: Debian, Ubuntu, Linux Mint, Pop!_OS
- **DNF**: Fedora, RHEL, Rocky, AlmaLinux
- **Pacman**: Arch, Manjaro, EndeavourOS

Each provider implements:
- `*_update()`: Refresh package database
- `*_upgrade()`: Install package updates
- `*_check_security()`: Check for security updates
- `*_autoremove()`: Remove unused packages
- `*_clean()`: Clean package cache

### Modules (`modules/*.sh`)
- **Update**: Security and full system updates
- **Hardening**: SSH, sysctl, firewall baseline configuration
- **Health**: System health reporting (JSON and human-readable)
- **Backup**: Configuration file backup and rotation
- **Benchmark**: CPU and disk performance testing
- **Logging**: Log rotation and viewing

## Data Flow

### Update Command Flow
```
ubopt update check
  ├─> Load common.sh
  ├─> Detect distribution
  ├─> Load appropriate provider (apt/dnf/pacman)
  ├─> Call provider's check_security()
  ├─> Log results (JSON)
  └─> Return exit code (0=no updates, 20=updates available)
```

### Health Check Flow
```
ubopt health --json
  ├─> Load common.sh
  ├─> Collect system metrics
  │   ├── Hostname, kernel
  │   ├── CPU count and load
  │   ├── Memory usage
  │   └── Disk usage
  ├─> Format as JSON
  └─> Output to stdout
```

## Configuration

Configuration is loaded from:
1. `/etc/ubopt/config.yaml` (system-wide)
2. `~/.config/ubopt/config.yaml` (user-specific)
3. Environment variables (`UBOPT_*`)
4. Command-line flags

## Logging

All operations are logged in two formats:
1. **JSON**: Structured logs at `/var/log/ubopt/ubopt.log`
2. **Syslog**: Via `logger` command for integration with system logging

## Security Considerations

- **Privilege Escalation**: Only escalate when necessary
- **Input Validation**: All user inputs are validated
- **Safe Defaults**: Conservative configuration defaults
- **Dry-Run Mode**: Test changes without applying them
- **Backups**: Automatic backups before modifications
- **Audit Trail**: Complete JSON log of all operations

## Extension Points

### Adding a New Provider
1. Create `providers/yourpkg.sh`
2. Implement required functions
3. Add detection logic to `common.sh`

### Adding a New Module
1. Create `modules/yourmodule.sh`
2. Source `common.sh`
3. Implement module functions
4. Add command handler to `cmd/ubopt`

## Exit Codes

- `0`: Success
- `1`: General error
- `20`: Updates available (check commands)
- `99`: Help requested (internal)

## Testing Strategy

- **Unit Tests**: Bats tests for individual modules
- **Integration Tests**: End-to-end command testing
- **CI/CD**: GitHub Actions with shellcheck and bats
- **Manual Testing**: Vagrant multi-distro testing

## Performance

- Minimal dependencies (pure Bash + standard tools)
- Fast distro detection and provider selection
- Efficient JSON generation (no external parsers)
- Parallel operations where safe

## Future Enhancements

- Web dashboard for monitoring
- Plugin system for custom checks
- Integration with monitoring systems (Prometheus, Grafana)
- Cloud-init integration
- Ansible module
