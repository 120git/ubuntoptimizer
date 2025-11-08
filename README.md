# Cool Llama Linux Optimizer (ubopt)

"Cool Llama" is an enterprise-grade, modular Linux optimization & security toolkit.

It started life as a single Bash script (`system-optimize.sh`) and has evolved into a structured, provider‑aware CLI (`ubopt`) with separate modules for updates, hardening, health reporting, backups, benchmarking, and logging. This README unifies the legacy script feature list with the new modular architecture and sets out the roadmap toward a richer future implementation.

## Logo

```
              
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
```
## Overview

`ubopt` provides:

* Cross‑distro package update abstraction (apt, dnf, pacman)
* Security hardening baseline (SSH, sysctl, firewall)
* Health reporting (JSON & human)
* Configuration backups
* Performance benchmarking (CPU & disk)
* Structured JSON logging with rotation & syslog fallback
* Dry‑run mode for every mutating action
* Systemd timer for scheduled security updates

The legacy `system-optimize.sh` interactive menu remains for simple one‑off optimization; the modular CLI is the strategic path forward.

## Current Features (Bash CLI)

* Update management: check, apply, security‑only
* Hardening: SSH lockdown, sysctl tuning, firewall enable (ufw/firewalld)
* Health: uptime, load, memory, disk, CPU load JSON
* Backup: key configuration snapshots with timestamp
* Benchmark: simple CPU timing + disk throughput
* Logging: JSON events + human helpers, rotation module
* Report: combined health + update summary
* Legacy script: menu‑driven optimization tasks

## Requirements

* Bash 5+
* Standard coreutils
* Package manager (apt/dnf/pacman) depending on distro
* Optional: `shellcheck`, `bats` for development
* Root/sudo for applying changes (dry‑run works unprivileged)

## Quick Start (Repository Clone)

Clone the repository:
```bash
git clone https://github.com/120git/ubuntoptimizer.git
cd ubuntoptimizer
cd cool-llama-linuxoptimizer
```

### Use the modular CLI (`ubopt`)

Run help:
```bash
./cmd/ubopt --help
```

Install system‑wide (optional):
```bash
sudo make install
ubopt update check
```

### Legacy menu script

```bash
sudo ./system-optimize.sh
```

## Logs & Backups

* Modular CLI logs: `/var/log/ubopt/*.log` (fallback to `./logs/` if not root)
* Backups: `/var/backups/ubopt/` (or working directory in dry‑run)

## Supported Distributions

* Ubuntu / Debian family
* Fedora / RHEL / CentOS
* Arch / Manjaro

Automatic detection selects provider; unsupported distros can still use generic health and benchmarking.

## Architecture (Bash Phase)

```
cmd/ubopt                # CLI dispatcher
lib/common.sh            # Logging, distro detection, shared utils
providers/apt.sh|...     # Package manager abstraction
modules/update.sh        # Update orchestration
modules/hardening.sh     # Security baseline
modules/health.sh        # Health metrics output
modules/backup.sh        # Backup routines
modules/benchmark.sh     # Simple performance tests
modules/logging.sh       # Log rotation & inspection
systemd/*.service|*.timer# Scheduled security updates
tests/bats/*.bats        # Functional tests
```

## Roadmap (Next Major Iteration)

We plan to migrate to a Python + Typer/Rich implementation with:

* Rich TUI dashboards & progress bars
* Async operations & concurrency
* Plugin system for custom optimizations
* Profile‑driven tuning (conservative / balanced / aggressive)
* Advanced rollback state tracking
* Extended benchmarking suite
* SBOM + signed releases (initial Shell pipeline already prepared)

## Contributing

Pull requests welcome. Please run `make lint test` before submitting and favor small, focused changes. For larger proposals open an issue first.

## License

MIT License – see `LICENSE`.

## Copyright

© 2025 Cool Llama

## Security

Hardening operations strive to be idempotent and reversible (backups created before changes). Always review dry‑run output first on critical systems.

## Acknowledgements

Inspired by community best practices for Linux hardening & maintenance; built to be auditable and minimal.
