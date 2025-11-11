Operations Guide
================

Installation
------------
- Install packages (deb/rpm) or run ``make install`` for a local test install.
- System directories used:
  - ``/etc/ubopt``: configs, RBAC roles, API token
  - ``/usr/lib/ubopt``: libraries, modules, tools
  - ``/var/lib/ubopt``: state
  - ``/var/log/ubopt``: logs

Systemd Units
-------------
- ``ubopt-ota.timer``: weekly OTA policy sync. Start with::

    systemctl enable --now ubopt-ota.timer

- ``ubopt-api.socket``: socket-activated local API. Start with::

    systemctl enable --now ubopt-api.socket

RBAC
----
- Default roles defined in ``rbac/``; deploy organization-specific policy packs via OTA.
- CLI supports ``--role <role>``; if omitted, defaults to configured role or a safe default.
- Unauthorized actions return JSON error and non-zero exit.

OTA Policies
------------
- Configure source via env ``OTA_URL`` or pass ``--source`` to the sync tool.
- Local/offline mode supported with ``file://`` or directory path pointing to a tree containing
  ``manifest.json`` and ``policies/``.
- Signature verification:
  - Cosign signatures when configured, or
  - ``.sha256`` sidecar files for manifest and each asset.

Troubleshooting
---------------
- Logs: check ``/var/log/ubopt/*.log`` (or ``/tmp`` when non-root execution).
- API: ensure ``socat`` is installed and ``ubopt-api.socket`` is active.
- RBAC: run with ``--role admin`` to bypass in break-glass scenarios (if policy permits).
- OTA exits non-zero on failed verification; run with ``--verbose`` to inspect details.

Observability
-------------
- Prometheus metrics textfile written under the configured path by the exporter module.
- Import the provided Grafana dashboard JSON to visualize optimization posture.

Backups and Rollback
--------------------
- Modules write snapshots of key configs before changes when hooks are enabled.
- State is tracked in ``/var/lib/ubopt/state.json``; copy before major upgrades.

Air-gapped Environments
-----------------------
- Use local OTA mode: distribute a signed policy bundle via removable media.
- Example layout::

    tests/ota/
      manifest.json
      manifest.json.sha256
      policies/
        baseline.yaml
        baseline.yaml.sha256

- Then run::

    tools/ota-sync.sh --check --apply --source file://$(pwd)/tests/ota

