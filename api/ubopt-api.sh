#!/usr/bin/env bash
# =============================================================================
# ubopt REST Telemetry API (lightweight)
# - Listens on 127.0.0.1:8080 by default (configurable)
# - Endpoints (GET): /health, /report, /metrics, /version
# - Optional bearer token auth via /etc/ubopt/api.token
# - Implementation prefers socat, falls back to nc when available
# =============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &>/dev/null && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd)" || true

API_HOST="${UBOPT_API_HOST:-127.0.0.1}"
API_PORT="${UBOPT_API_PORT:-8080}"
API_TOKEN_FILE="${UBOPT_API_TOKEN_FILE:-/etc/ubopt/api.token}"
METRICS_FILE="${UBOPT_METRICS_FILE:-/var/lib/node_exporter/textfile_collector/ubopt_metrics.prom}"

UBOPT_BIN="${UBOPT_BIN:-}"
if [[ -z "${UBOPT_BIN}" ]]; then
  if command -v ubopt &>/dev/null; then
    UBOPT_BIN="$(command -v ubopt)"
  elif [[ -x "${ROOT_DIR}/cmd/ubopt" ]]; then
    UBOPT_BIN="${ROOT_DIR}/cmd/ubopt"
  else
    UBOPT_BIN="ubopt"
  fi
fi

send_response() {
  local status_line="$1"; shift
  local content_type="$1"; shift
  local body="$1"; shift || true
  printf "%s\r\n" "${status_line}"
  printf "Content-Type: %s\r\n" "${content_type}"
  printf "Connection: close\r\n\r\n"
  [[ -n "${body}" ]] && printf "%s" "${body}"
}

read_request() {
  # Reads the HTTP request line and headers from stdin into globals
  REQUEST_LINE=""
  AUTH_HEADER=""
  while IFS=$'\r' read -r line; do
    # Strip leading \n if present
    line="${line//$'\n'/}"
    [[ -z "${REQUEST_LINE}" ]] && REQUEST_LINE="${line}"
    # Headers follow until empty line
    if [[ -z "${line}" ]]; then
      break
    fi
    case "${line}" in
      "Authorization: "*) AUTH_HEADER="${line#Authorization: }" ;;
    esac
  done
}

check_auth() {
  # If token file exists, require matching bearer token
  if [[ -f "${API_TOKEN_FILE}" ]]; then
    local expected
    expected="Bearer $(tr -d '\n' < "${API_TOKEN_FILE}")"
    if [[ "${AUTH_HEADER:-}" != "${expected}" ]]; then
      send_response "HTTP/1.1 401 Unauthorized" "application/json" '{"error":"unauthorized"}'
      return 1
    fi
  fi
  return 0
}

handle_request() {
  read_request || true
  # Default to 404 if request not understood
  local method path proto
  method="${REQUEST_LINE%% *}"
  path_proto="${REQUEST_LINE#* }"
  path="${path_proto%% *}"
  proto="${REQUEST_LINE##* }"

  # Only GET supported
  if [[ "${method}" != "GET" ]]; then
    send_response "HTTP/1.1 405 Method Not Allowed" "application/json" '{"error":"method_not_allowed"}'
    return 0
  fi

  # Auth check if required
  if ! check_auth; then
    return 0
  fi

  case "${path}" in
    /health)
      if output="$(${UBOPT_BIN} health --json 2>/dev/null)"; then
        send_response "HTTP/1.1 200 OK" "application/json" "${output}"
      else
        send_response "HTTP/1.1 500 Internal Server Error" "application/json" '{"error":"health_failed"}'
      fi
      ;;
    /report)
      if output="$(${UBOPT_BIN} report 2>/dev/null)"; then
        send_response "HTTP/1.1 200 OK" "application/json" "${output}"
      else
        send_response "HTTP/1.1 500 Internal Server Error" "application/json" '{"error":"report_failed"}'
      fi
      ;;
    /metrics)
      if [[ -f "${METRICS_FILE}" ]]; then
        send_response "HTTP/1.1 200 OK" "text/plain; version=0.0.4" "$(cat "${METRICS_FILE}")"
      else
        send_response "HTTP/1.1 404 Not Found" "application/json" '{"error":"metrics_not_found"}'
      fi
      ;;
    /version)
      local ver="unknown"
      if [[ -f "${ROOT_DIR}/VERSION" ]]; then ver="$(cat "${ROOT_DIR}/VERSION")"; fi
      send_response "HTTP/1.1 200 OK" "text/plain" "${ver}\n"
      ;;
    /)
      send_response "HTTP/1.1 200 OK" "text/plain" "ubopt API: /health /report /metrics /version\n"
      ;;
    *)
      send_response "HTTP/1.1 404 Not Found" "application/json" '{"error":"not_found"}'
      ;;
  esac
}

run_server_socat() {
  # Use socat to fork per-connection and execute handler
  exec socat -T5 TCP-LISTEN:"${API_PORT}",bind="${API_HOST}",reuseaddr,fork EXEC:"${SCRIPT_DIR}/api/ubopt-api.sh --handle"
}

run_server_nc() {
  echo "Error: socat is required for ubopt-api. Please install 'socat'." >&2
  exit 1
}

main() {
  if [[ "${1:-}" == "--handle" ]]; then
    handle_request
    exit 0
  fi
  # Prefer socat if available
  if command -v socat &>/dev/null; then
    run_server_socat
  elif command -v nc &>/dev/null; then
    run_server_nc
  else
    echo "Error: neither socat nor nc is available" >&2
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
