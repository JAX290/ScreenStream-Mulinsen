#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-/opt/mulinsen-screenstream}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "请使用 root 运行：sudo bash install.sh"
  exit 1
fi

prompt() {
  local variable="$1" label="$2" default_value="$3" value
  read -r -p "${label} [${default_value}]: " value
  printf -v "${variable}" '%s' "${value:-$default_value}"
}

random_secret() {
  openssl rand -base64 30 | tr -d '=+/\n' | cut -c1-32
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

echo "=== 木林森 ScreenStream VPS 一键部署 ==="
prompt ROOT_DOMAIN "根域名" "mulinsen.win"
prompt ACME_EMAIL "证书通知邮箱" "admin@${ROOT_DOMAIN}"
prompt DEVICE_PATH "设备路径" "phone/nova6"
prompt RETENTION_DAYS "录像保留天数" "30"
prompt PUBLISH_USER "手机推流用户名" "nova6-publisher"
read -r -s -p "手机推流密码（直接回车自动生成）: " PUBLISH_PASSWORD
echo
PUBLISH_PASSWORD="${PUBLISH_PASSWORD:-$(random_secret)}"

if [[ ! "${ROOT_DOMAIN}" =~ ^([a-zA-Z0-9][a-zA-Z0-9-]*\.)+[a-zA-Z]{2,}$ ]]; then
  echo "根域名格式不正确。"
  exit 1
fi
if [[ ! "${ACME_EMAIL}" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
  echo "邮箱格式不正确。"
  exit 1
fi
if [[ ! "${DEVICE_PATH}" =~ ^[a-zA-Z0-9_.-]+(/[a-zA-Z0-9_.-]+)*$ ]]; then
  echo "设备路径格式不正确，只能使用字母、数字、点、下划线、短横线和斜杠。"
  exit 1
fi
if [[ ! "${RETENTION_DAYS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "录像保留天数必须是正整数。"
  exit 1
fi
if [[ ! "${PUBLISH_USER}" =~ ^[a-zA-Z0-9_.-]+$ ]] || [[ ! "${PUBLISH_PASSWORD}" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
  echo "推流用户名和密码只能使用字母、数字、点、下划线和短横线。"
  exit 1
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "没有检测到 Tailscale。请先在 VPS 安装并登录 Tailscale。"
  exit 1
fi
TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n 1)"
if [[ -z "${TAILSCALE_IP}" ]]; then
  echo "Tailscale 尚未连接，请先执行 tailscale up。"
  exit 1
fi

INGEST_DOMAIN="ingest.${ROOT_DOMAIN}"
VIEW_DOMAIN="view.${ROOT_DOMAIN}"
API_DOMAIN="api.${ROOT_DOMAIN}"

echo
echo "请确认 Cloudflare 已设置以下三条 A 记录并指向本 VPS："
echo "  ${INGEST_DOMAIN}  -> VPS 公网 IP，DNS Only（灰色云）"
echo "  ${VIEW_DOMAIN}    -> VPS 公网 IP，DNS Only（灰色云）"
echo "  ${API_DOMAIN}     -> ${TAILSCALE_IP}，DNS Only（灰色云）"
read -r -p "已完成 DNS 设置？输入 y 继续: " DNS_READY
[[ "${DNS_READY}" == "y" || "${DNS_READY}" == "Y" ]] || exit 1

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y docker.io openssl ca-certificates curl
if ! docker compose version >/dev/null 2>&1; then
  if ! apt-get install -y docker-compose-v2; then
    apt-get install -y docker-compose
  fi
fi
systemctl enable --now docker

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

mkdir -p "${INSTALL_DIR}"/{site,apk1,recordings,data/caddy,data/caddy-config,data/download-gate}
chown -R 65534:65534 "${INSTALL_DIR}/data/download-gate"
cp "${SCRIPT_DIR}/docker-compose.yml" "${INSTALL_DIR}/docker-compose.yml"
cp -a "${SCRIPT_DIR}/site/." "${INSTALL_DIR}/site/"
mkdir -p "${INSTALL_DIR}/download-gate"
cp "${SCRIPT_DIR}/download-gate/Dockerfile" "${INSTALL_DIR}/download-gate/Dockerfile"
cp "${SCRIPT_DIR}/download-gate/server.py" "${INSTALL_DIR}/download-gate/server.py"

APK_SOURCE="$(cd "${SCRIPT_DIR}/../.." && pwd)/apk"
if [[ -d "${APK_SOURCE}" ]]; then
  cp -a "${APK_SOURCE}/." "${INSTALL_DIR}/apk1/"
fi

cp "${SCRIPT_DIR}/Caddyfile.template" "${INSTALL_DIR}/Caddyfile"
cp "${SCRIPT_DIR}/mediamtx.yml.template" "${INSTALL_DIR}/mediamtx.yml"

replace() {
  local file="$1" key="$2" value
  value="$(escape_sed "$3")"
  sed -i "s|__${key}__|${value}|g" "${file}"
}

for file in "${INSTALL_DIR}/Caddyfile" "${INSTALL_DIR}/mediamtx.yml"; do
  replace "${file}" INGEST_DOMAIN "${INGEST_DOMAIN}"
  replace "${file}" VIEW_DOMAIN "${VIEW_DOMAIN}"
done
replace "${INSTALL_DIR}/Caddyfile" API_DOMAIN "${API_DOMAIN}"
replace "${INSTALL_DIR}/mediamtx.yml" API_DOMAIN "${API_DOMAIN}"
replace "${INSTALL_DIR}/Caddyfile" ACME_EMAIL "${ACME_EMAIL}"
replace "${INSTALL_DIR}/mediamtx.yml" PUBLISH_USER "${PUBLISH_USER}"
replace "${INSTALL_DIR}/mediamtx.yml" PUBLISH_PASSWORD "${PUBLISH_PASSWORD}"
replace "${INSTALL_DIR}/mediamtx.yml" DEVICE_PATH "${DEVICE_PATH}"
replace "${INSTALL_DIR}/mediamtx.yml" RETENTION_DAYS "${RETENTION_DAYS}"

cat > "${INSTALL_DIR}/DEPLOYMENT_INFO.txt" <<EOF
手机推流地址：rtsps://${PUBLISH_USER}:${PUBLISH_PASSWORD}@${INGEST_DOMAIN}:8322/${DEVICE_PATH}
网页查看地址：http://${API_DOMAIN}（仅 Tailscale）
APK 下载地址：http://${VIEW_DOMAIN}/apk1
下载控制面板：http://${API_DOMAIN}/download-control（仅 Tailscale）
API 健康检查：http://${API_DOMAIN}/health
Tailscale IP：${TAILSCALE_IP}
EOF
chmod 600 "${INSTALL_DIR}/DEPLOYMENT_INFO.txt"

cd "${INSTALL_DIR}"
compose up -d caddy

CERT_FILE="${INSTALL_DIR}/data/caddy/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${INGEST_DOMAIN}/${INGEST_DOMAIN}.crt"
echo "正在申请 HTTPS/RTSPS 证书……"
for _ in $(seq 1 60); do
  [[ -f "${CERT_FILE}" ]] && break
  sleep 3
done
if [[ ! -f "${CERT_FILE}" ]]; then
  echo "证书尚未生成。请检查 DNS 与 80/443 端口，然后运行："
  echo "  cd ${INSTALL_DIR}，然后执行 docker compose logs caddy"
  exit 1
fi

compose up -d

echo
echo "部署完成。重要信息保存在：${INSTALL_DIR}/DEPLOYMENT_INFO.txt"
cat "${INSTALL_DIR}/DEPLOYMENT_INFO.txt"
echo
echo "请在云厂商防火墙放行 TCP 80、443、8322；只有临时 APK 下载入口可从公网访问。"
