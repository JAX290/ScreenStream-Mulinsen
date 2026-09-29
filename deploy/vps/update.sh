#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/mulinsen-screenstream}"
if [[ "${EUID}" -ne 0 ]]; then
  echo "请使用：sudo bash update.sh"
  exit 1
fi

cd "${INSTALL_DIR}"
if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
else
  COMPOSE=(docker-compose)
fi
"${COMPOSE[@]}" pull
"${COMPOSE[@]}" up -d
docker image prune -f
echo "VPS 服务已更新。"
