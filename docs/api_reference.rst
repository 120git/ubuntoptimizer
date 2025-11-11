API Reference
=============

Overview
--------
The lightweight ubopt REST API is provided by the ``ubopt-api`` systemd socket-activated service.
It binds only to ``127.0.0.1:8080`` by default for local security. Reverse proxies or SSH tunnels
can expose it remotely if desired.

Authentication
--------------
If the file ``/etc/ubopt/api.token`` exists and is non-empty, clients must supply a
``Authorization: Bearer <token>`` header. Absence of the header or mismatched token
returns ``401 Unauthorized``.

Socket Activation
-----------------
The API is started on demand by ``ubopt-api.socket``. The ``ubopt-api.service`` runs
``api/ubopt-api.sh`` which uses ``socat`` to serve requests. Idle timeout behavior is
inherited from systemd socket defaults.

Endpoints
---------
All responses are JSON unless otherwise noted.

``GET /health``
  Returns current health checks.

``GET /report``
  Returns consolidated system report including optimization state.

``GET /metrics``
  Exposes Prometheus text-format metrics collected by ubopt exporter.
  Content-Type: ``text/plain; version=0.0.4``.

``GET /version``
  Returns ubopt version string and build metadata if available.

Error Handling
--------------
Errors respond with JSON body::

  {"error": "message", "status": <http_status_int>}

RBAC Integration
----------------
API internally calls the same module entrypoints as the CLI. RBAC enforcement
occurs before privileged actions. Read-only endpoints (health, report, metrics, version)
do not require elevated roles. Future mutating endpoints should call ``rbac_enforce``
with the appropriate action key.

Extensibility
-------------
To add a new endpoint:
1. Extend the case block in ``api/ubopt-api.sh``.
2. Add optional RBAC gating if it performs changes.
3. Update this document and regenerate docs.

Security Notes
--------------
- Bind localhost only; use firewall or reverse proxy for remote access.
- Keep the token file root-readable only: ``chmod 600 /etc/ubopt/api.token``.
- Consider rotating tokens and integrating with external secret managers.
