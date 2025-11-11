Cool Llama – LinuxOptimizer (ubopt)
===================================

Enterprise-ready Linux optimization, hardening, monitoring & policy toolkit.

Features
--------
- Modular Bash architecture (updates, hardening, health, backup, benchmark, report)
- RBAC (admin, operator, auditor) enforcement
- Secure (signed / hashed) OTA policy distribution (local or remote)
- Textfile Prometheus exporter + Grafana dashboard
- REST telemetry API (/health, /report, /metrics, /version)
- Signed release artifacts with SBOM + provenance

Documentation
-------------
.. toctree::
   :maxdepth: 2
   :caption: Contents

   cli_reference
   api_reference
   developer_guide
   operations_guide
   usage
   config_reference

Quick Start
-----------
1. Install package (.deb or .rpm) or run from source.
2. Enable systemd timers: updates, exporter, OTA.
3. (Optional) Start REST API: `systemctl enable --now ubopt-api.service`.
4. Validate config: `ubopt update config-test --config /etc/ubopt/ubopt.yaml`.
5. Generate report: `ubopt --role auditor report`.

RBAC Overview
-------------
- admin: full control (update, hardening, backup, benchmark, report, config_test, view_logs, health)
- operator: operational tasks (report, health, backup, view_logs, benchmark)
- auditor: read-only (report, health, view_logs)

Policy Updates (OTA)
--------------------
Run weekly via systemd timer. Supports `--source file://` for offline or air‑gapped environments.

REST API
--------
Local-only (127.0.0.1) by default. Optional bearer token from `/etc/ubopt/api.token`.

Observability
-------------
Exporter writes metrics to textfile collector; Grafana dashboard JSON included under `grafana/`.

License
-------
MIT License – see `LICENSE` in the repository.
