# Release Verification Guide

This document provides step-by-step instructions for verifying ubopt releases.

## 1. CI/CD Pipeline Verification

### Check E2E Matrix Status
After pushing the trigger commit, verify all container tests pass:

```bash
# Visit GitHub Actions page
https://github.com/120git/ubuntoptimizer/actions

# Look for workflow runs:
# - CI (with e2e matrix job)
# - E2E (multi-distro matrix)
# - Release (triggered by tag)
```

**Expected matrix coverage:**
- ✓ Debian 12
- ✓ Ubuntu 22.04
- ✓ Fedora 41
- ✓ CentOS Stream 9
- ✓ Arch Linux (latest)

Each should execute:
- Health JSON validation
- Update dry-run check
- Hardening idempotency test
- Exporter metric file presence

## 2. Release Artifacts Verification

### Check GitHub Release Page
```bash
# Visit release page
https://github.com/120git/ubuntoptimizer/releases/tag/v0.3.0
```

**Expected artifacts:**
- `ubopt-0.3.0.tar.gz` - Source tarball
- `ubopt_0.3.0-1_amd64.deb` - Debian/Ubuntu package
- `ubopt-0.3.0-1.x86_64.rpm` - RPM package (Fedora/RHEL/CentOS)
- `sbom-deb-0.3.0.spdx.json` - Debian SBOM
- `sbom-rpm-0.3.0.spdx.json` - RPM SBOM
- `provenance.json` - Build provenance
- `*.sig` files - Cosign signatures for each artifact

## 3. Package Signature Verification

### Debian Package Verification
```bash
# Download the release artifacts
wget https://github.com/120git/ubuntoptimizer/releases/download/v0.3.0/ubopt_0.3.0-1_amd64.deb
wget https://github.com/120git/ubuntoptimizer/releases/download/v0.3.0/ubopt_0.3.0-1_amd64.deb.sig

# Verify with Cosign (requires cosign.pub from repo)
cosign verify-blob \
  --key cosign.pub \
  --signature ubopt_0.3.0-1_amd64.deb.sig \
  ubopt_0.3.0-1_amd64.deb

# Expected output: Verified OK
```

### RPM Package Verification
```bash
# Download RPM
wget https://github.com/120git/ubuntoptimizer/releases/download/v0.3.0/ubopt-0.3.0-1.x86_64.rpm

# Verify package integrity
rpm -Kv ubopt-0.3.0-1.x86_64.rpm

# Expected output shows digest and signature checks
```

### SBOM Verification
```bash
# Download and inspect SBOMs
wget https://github.com/120git/ubuntoptimizer/releases/download/v0.3.0/sbom-deb-0.3.0.spdx.json
wget https://github.com/120git/ubuntoptimizer/releases/download/v0.3.0/sbom-rpm-0.3.0.spdx.json

# Validate SBOM format (requires jq)
jq '.name, .packages[].name' sbom-deb-0.3.0.spdx.json | head -20
```

## 4. Local Package Installation Tests

### Debian/Ubuntu Test
```bash
# Install package
sudo dpkg -i ubopt_0.3.0-1_amd64.deb
sudo apt-get install -f  # Fix dependencies if needed

# Verify installation
ubopt --version
ubopt health --json

# Check systemd units
systemctl status ubopt-agent.timer
systemctl status ubopt-exporter.timer

# Verify files
ls -la /usr/bin/ubopt
ls -la /usr/lib/ubopt/
ls -la /etc/ubopt/
```

### Fedora/RHEL/CentOS Test
```bash
# Install package
sudo dnf install ubopt-0.3.0-1.x86_64.rpm

# Or with yum
sudo yum install ubopt-0.3.0-1.x86_64.rpm

# Verify same as above
ubopt --version
ubopt health --json
```

## 5. Ansible Fleet Deployment Test

### Prerequisites
Create an inventory file:

```yaml
# inventory.yml
all:
  hosts:
    test-node-1:
      ansible_host: 192.168.1.10
      ansible_user: ubuntu
    test-node-2:
      ansible_host: 192.168.1.11
      ansible_user: ubuntu
  vars:
    ubopt_config:
      updates:
        schedule: daily
        reboot: when-required
      logging:
        level: info
```

### Deploy with Ansible
```bash
# Test connectivity
ansible all -i inventory.yml -m ping

# Deploy ubopt
ansible-playbook ansible/playbooks/site.yml -i inventory.yml

# Verify on remote hosts
ansible all -i inventory.yml -m shell -a "ubopt health --json"
ansible all -i inventory.yml -m shell -a "systemctl status ubopt-agent.timer"

# Check state files
ansible all -i inventory.yml -m shell -a "cat /var/lib/ubopt/state.json" --become
```

### Expected Output
Each host should report:
- ubopt installed and configured
- Timers enabled and running
- Health JSON output valid
- State file present with metadata

## 6. Monitoring Integration

### Grafana Dashboard Import
```bash
# 1. Access Grafana UI (e.g., http://localhost:3000)
# 2. Navigate to: Dashboards → Import
# 3. Upload: grafana/dashboards/ubopt-overview.json
# 4. Select Prometheus data source
# 5. Click Import

# Expected panels:
# - Root Filesystem Usage (gauge)
# - Last Export Time (stat)
# - Host Info (table)
```

### Prometheus Alert Rules
```bash
# Copy alert rules to Prometheus config directory
sudo cp prometheus/alerts/ubopt-rules.yaml /etc/prometheus/rules/

# Update prometheus.yml to include the rules
# Add to rule_files section:
rule_files:
  - "/etc/prometheus/rules/ubopt-rules.yaml"

# Reload Prometheus
curl -X POST http://localhost:9090/-/reload
# Or restart service
sudo systemctl restart prometheus

# Verify rules loaded
# Visit: http://localhost:9090/rules
# Should see: RootFSHigh, ExporterStale, SecurityUpdatesPending
```

### Test Metrics Collection
```bash
# On monitored host, trigger exporter
sudo /usr/lib/ubopt/exporters/ubopt_textfile_exporter.sh

# Check metrics file
cat /var/lib/node_exporter/textfile_collector/ubopt_metrics.prom

# Expected metrics:
# ubopt_last_export_timestamp_seconds
# ubopt_security_updates_pending
# ubopt_root_disk_usage_percent
# ubopt_health_status
```

## 7. Compliance Verification

### Review Compliance Documentation
```bash
# Read compliance mapping
cat docs/COMPLIANCE.md

# Verify controls:
# - 1.1 System Updates (update module)
# - 1.2 Secure Configuration (hardening module)
# - 1.3 Logging and Auditing (logging + exporter)
# - 1.4 Access Control (SSH hardening)
# - 1.5 System Integrity (snapshots + hooks)
# - 1.6 Monitoring (Prometheus + Grafana)
```

### Audit Trail
```bash
# Check logs
sudo tail -f /var/log/ubopt/ubopt.log

# Review state history
sudo jq . /var/lib/ubopt/state.json

# Verify hooks execution
ls -la /usr/lib/ubopt/hooks/pre-update.d/
ls -la /usr/lib/ubopt/hooks/post-update.d/
```

## 8. Rollback Testing

### Create Test Snapshot
```bash
# On Btrfs system
sudo btrfs subvolume list /

# On ZFS system
sudo zfs list -t snapshot

# Trigger update with snapshot
sudo ubopt update apply --dry-run
# (Check for snapshot creation in logs)
```

### Verify Hook Execution
```bash
# Add test pre-update hook
sudo tee /usr/lib/ubopt/hooks/pre-update.d/test-hook.sh > /dev/null <<'EOF'
#!/bin/bash
echo "[TEST] Pre-update hook executed at $(date)" | logger -t ubopt-hook
exit 0
EOF

sudo chmod +x /usr/lib/ubopt/hooks/pre-update.d/test-hook.sh

# Run update and check logs
sudo ubopt update apply --dry-run
sudo journalctl -t ubopt-hook --since "1 minute ago"
```

## Troubleshooting

### Common Issues

**Issue: Cosign verification fails**
```bash
# Ensure you have the correct public key
wget https://raw.githubusercontent.com/120git/ubuntoptimizer/main/cosign.pub

# Verify key format
cat cosign.pub
```

**Issue: RPM signature not found**
```bash
# RPM packages may not be GPG-signed by default in CI
# Cosign signatures are provided separately (.sig files)
```

**Issue: Ansible deployment fails**
```bash
# Check SSH connectivity
ansible all -i inventory.yml -m ping

# Run with verbose output
ansible-playbook ansible/playbooks/site.yml -i inventory.yml -vvv

# Check sudo permissions
ansible all -i inventory.yml -m shell -a "sudo whoami"
```

**Issue: Metrics not appearing in Prometheus**
```bash
# Verify node_exporter is running with textfile collector
systemctl status node_exporter

# Check textfile collector directory
ls -la /var/lib/node_exporter/textfile_collector/

# Verify file permissions
sudo chmod 644 /var/lib/node_exporter/textfile_collector/ubopt_metrics.prom

# Test scrape endpoint
curl http://localhost:9100/metrics | grep ubopt
```

## Success Criteria

✅ **Release artifacts present:**
- Source tarball available
- Debian and RPM packages built
- SBOMs generated for both packages
- Signatures created with Cosign

✅ **CI/CD pipeline:**
- All container matrix tests pass (5 distros)
- Config validation succeeds
- Integration tests pass

✅ **Package installation:**
- Installs cleanly on Debian/Ubuntu and Fedora/RHEL
- All files in correct FHS locations
- Systemd units enabled and active

✅ **Ansible deployment:**
- Playbook executes without errors
- Configuration templated correctly
- Service timers running on all hosts

✅ **Monitoring:**
- Grafana dashboard displays host metrics
- Prometheus alerts loading correctly
- Exporter running and producing valid metrics

✅ **Compliance:**
- Controls mapped to standard frameworks
- Audit trail available via logs and state
- Hooks and snapshots functioning
