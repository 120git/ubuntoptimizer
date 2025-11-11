Developer Guide
===============

Project Layout
--------------
``cmd/ubopt``
  Main CLI dispatcher script.
``modules/*.sh``
  Feature modules (update, hardening, health, report). Each exposes a ``run`` style function or case logic.
``providers/*.sh``
  Package/provider abstractions (apt, dnf, pacman).
``lib/*.sh``
  Shared libraries (rbac, logging, helpers).
``tools/*.sh``
  Supporting utilities (OTA sync, validation, maintenance helpers).
``api/ubopt-api.sh``
  Lightweight REST API (socat based).
``rbac/``
  Role and policy YAML definitions.
``ota/``
  Manifest and fetched policy packs (post-sync).
``systemd/``
  Unit and timer/service definitions.
``tests/``
  E2E and fixture-based tests.
``docs/``
  Sphinx documentation source.

Coding Conventions
------------------
- Bash strict mode: ``set -euo pipefail`` inside scripts that are entrypoints.
- Functions prefixed by domain: ``rbac_*``, ``ota_*``.
- Avoid subshells in hot paths; prefer builtins.
- JSON output: assemble strings carefully, prefer printf for escaping.

RBAC Implementation
-------------------
Roles are defined in YAML. Loader in ``lib/rbac.sh`` performs a minimal parse (no external deps).
``rbac_enforce <role> <action>`` exits non-zero if unauthorized.
Action normalization maps CLI verbs to internal RBAC keys.

OTA Update Flow
---------------
1. ``tools/ota-sync.sh --check`` reads manifest (remote or local) and compares versions.
2. Signature / checksum verified (cosign or ``.sha256`` sidecar).
3. ``--apply`` downloads policy pack assets, writes to ``ota/policies``.
4. Logs JSON lines to ``/var/log/ubopt/ota.log`` or ``/tmp`` fallback when non-root.

Adding Modules
--------------
1. Create ``modules/<name>.sh`` with a function or case handling ``$1`` subcommands.
2. Register dispatch in ``cmd/ubopt`` help and action mapping.
3. Add RBAC action if privileged.
4. Add tests under ``tests/e2e``.

Testing
-------
- Local smoke: ``make e2e-local``.
- Config validation: ``make config-test`` (runs schema checks).
- OTA: Provide mock manifest + policies under ``tests/ota`` for CI.

Packaging
---------
Deb/RPM specs live in packaging directories (not shown here if pruned). Build workflows create packages,
sign with Cosign, and attach SBOMs (Syft-generated) to releases.

Release Artifacts
-----------------
- Packages (.deb, .rpm)
- SBOMs (root + API component)
- Signatures (.sig / cosign attest)
- Docs tarball (built Sphinx HTML)

Contribution Flow
-----------------
1. Branch from main.
2. Add/modify code + tests.
3. Run lint and local tests.
4. Update CHANGELOG (unreleased section).
5. Open PR; CI must pass including new RBAC/OTA docs jobs.

Future Enhancements
-------------------
- Pluggable metrics exporters.
- gRPC or Unix socket API option.
- Policy bundle differential updates.
- Formal JSON schemas for state files.
