#!/usr/bin/env bash

# Minimal deployment script for NovaServer only.
# Requires: ssh/scp/tar on local machine, Python 3.11 and systemd on remote host.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_DIR="${REMOTE_DIR:-/opt/nova}"
SSH_PORT="${SSH_PORT:-22}"
PYTHON_BIN="${PYTHON_BIN:-python3.11}"

if [[ -z "${REMOTE_HOST}" ]]; then
  echo "ERROR: REMOTE_HOST environment variable is required." >&2
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command '$1' not found in PATH." >&2
    exit 1
  fi
}

require_cmd tar
require_cmd ssh

SSH_PASSWORD="${SSH_PASSWORD:-}"

if [[ -n "${SSH_PASSWORD}" ]]; then
  require_cmd sshpass
  SSH_CMD=(sshpass -p "${SSH_PASSWORD}" ssh -p "${SSH_PORT}" -o StrictHostKeyChecking=no)
  SCP_CMD=(sshpass -p "${SSH_PASSWORD}" scp -P "${SSH_PORT}" -o StrictHostKeyChecking=no)
else
  SSH_CMD=(ssh -p "${SSH_PORT}" -o StrictHostKeyChecking=no)
  SCP_CMD=(scp -P "${SSH_PORT}" -o StrictHostKeyChecking=no)
fi

echo ">>> Stopping existing service and cleaning previous deployment"
"${SSH_CMD[@]}" "${REMOTE_HOST}" "REMOTE_DIR='${REMOTE_DIR}' bash -s" <<'CLEANUP'
set -euo pipefail

if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-units --full -all | grep -Fq 'novaserver.service'; then
    systemctl stop novaserver.service || true
    systemctl disable novaserver.service || true
  fi

  # 停掉可能占用 80 端口的常见 Web 服务。
  for service in nginx.service httpd.service apache2.service caddy.service; do
    if systemctl list-unit-files --type=service | grep -Fq "${service}"; then
      systemctl stop "${service}" >/dev/null 2>&1 || true
      systemctl disable "${service}" >/dev/null 2>&1 || true
    fi
  done
fi

pkill -f "uvicorn app.main:app" >/dev/null 2>&1 || true

# 强制释放目标端口，避免残留进程阻塞部署。
ports=(80 8000)
for port in "${ports[@]}"; do
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${port}/tcp" >/dev/null 2>&1 || true
  elif command -v lsof >/dev/null 2>&1; then
    mapfile -t pids < <(lsof -t -i tcp:"${port}" 2>/dev/null || true)
    if [[ ${#pids[@]} -gt 0 ]]; then
      kill "${pids[@]}" >/dev/null 2>&1 || true
    fi
  elif command -v ss >/dev/null 2>&1; then
    mapfile -t pids < <(ss -ltnp 2>/dev/null | awk -v port=":${port}" '$4 ~ port {print $7}' | sed 's/^pid=//;s/,.*//' | sort -u)
    if [[ ${#pids[@]} -gt 0 ]]; then
      kill "${pids[@]}" >/dev/null 2>&1 || true
    fi
  fi
done

rm -rf "${REMOTE_DIR}/NovaServer" "${REMOTE_DIR}/.venv"
mkdir -p "${REMOTE_DIR}"
CLEANUP

echo ">>> Transferring NovaServer sources"
TRANSFER_ITEMS=(NovaServer scripts)
if [[ -f "${PROJECT_ROOT}/pyproject.toml" ]]; then
  TRANSFER_ITEMS+=(pyproject.toml)
fi

tar -czf - -C "${PROJECT_ROOT}" "${TRANSFER_ITEMS[@]}" | \
  "${SSH_CMD[@]}" "${REMOTE_HOST}" "tar -xzf - -C '${REMOTE_DIR}'"

echo ">>> Installing NovaServer dependencies and configuring service"
"${SSH_CMD[@]}" "${REMOTE_HOST}" "PYTHON_BIN='${PYTHON_BIN}' REMOTE_DIR='${REMOTE_DIR}' bash -s" <<'REMOTE_CMDS'
set -euo pipefail

cd "${REMOTE_DIR}"

# Configure PostgreSQL (create user/db, ensure md5 authentication)
PG_SERVICE="postgresql"
if systemctl list-unit-files | grep -Fq "postgresql-14.service"; then
  PG_SERVICE="postgresql-14"
fi

PG_HBA="/var/lib/pgsql/data/pg_hba.conf"
if [[ ! -f "${PG_HBA}" && -f "/var/lib/pgsql/14/data/pg_hba.conf" ]]; then
  PG_HBA="/var/lib/pgsql/14/data/pg_hba.conf"
fi

if [[ -f "${PG_HBA}" ]]; then
  sed -i -E "s/^(host\s+.*127\\.0\\.0\\.1\/32\s+).*/\1md5/" "${PG_HBA}"
  sed -i -E "s/^(host\s+.*::1\/128\s+).*/\1md5/" "${PG_HBA}"
  if ! grep -q "host[[:space:]]\+nova[[:space:]]\+nova[[:space:]]\+127\.0\.0\.1/32[[:space:]]\+md5" "${PG_HBA}"; then
    cat <<'HBA' >> "${PG_HBA}"
host    nova    nova    127.0.0.1/32    md5
host    nova    nova    ::1/128         md5
HBA
  fi
  systemctl restart "${PG_SERVICE}"
fi

if ! su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='nova'\"" | grep -q 1; then
  su - postgres -c "psql -c \"CREATE USER nova WITH PASSWORD 'nova';\""
fi

if su - postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='nova'\"" | grep -q 1; then
  su - postgres -c "psql -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='nova';\""
  su - postgres -c "psql -c \"DROP DATABASE nova;\""
fi
su - postgres -c "psql -c \"CREATE DATABASE nova OWNER nova;\""

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "ERROR: ${PYTHON_BIN} not found on remote host." >&2
  exit 1
fi

${PYTHON_BIN} -m venv NovaServer/.venv || true
source NovaServer/.venv/bin/activate
pip install --upgrade pip
if [[ -f "${REMOTE_DIR}/pyproject.toml" ]]; then
  pip install -e .
else
  pip install -e NovaServer
fi

SERVICE_FILE=/etc/systemd/system/novaserver.service
cat <<UNIT > "${SERVICE_FILE}"
[Unit]
Description=NovaServer FastAPI Service
After=network.target

[Service]
WorkingDirectory=${REMOTE_DIR}/NovaServer
Environment=PATH=${REMOTE_DIR}/NovaServer/.venv/bin
ExecStart=${REMOTE_DIR}/NovaServer/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 80
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now novaserver.service

activate_script="${REMOTE_DIR}/NovaServer/.venv/bin/activate"
if [[ -f "${activate_script}" ]]; then
  source "${activate_script}"
  if [[ -f "${REMOTE_DIR}/NovaServer/alembic.ini" ]]; then
    cd "${REMOTE_DIR}/NovaServer"
    alembic upgrade head
    cd "${REMOTE_DIR}"
  fi
  if [[ -f "${REMOTE_DIR}/scripts/init_admin.py" ]]; then
    python "${REMOTE_DIR}/scripts/init_admin.py"
  fi
fi
REMOTE_CMDS

echo ">>> Deployment completed"
"${SSH_CMD[@]}" "${REMOTE_HOST}" "systemctl status novaserver.service --no-pager"
