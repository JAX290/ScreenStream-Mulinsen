#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY="JAX290/ScreenStream-Mulinsen"
BRANCH="main"

if [[ "${EUID}" -ne 0 ]]; then
  echo "请使用 root 运行：curl -fsSL https://raw.githubusercontent.com/${REPOSITORY}/${BRANCH}/deploy/vps/bootstrap.sh | sudo bash"
  exit 1
fi

for command in curl tar; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "缺少命令：${command}。请先安装 curl 和 tar。"
    exit 1
  fi
done

TEMP_DIR="$(mktemp -d /tmp/mulinsen-screenstream.XXXXXX)"
cleanup() {
  rm -rf -- "${TEMP_DIR}"
}
trap cleanup EXIT

ARCHIVE_URL="https://github.com/${REPOSITORY}/archive/refs/heads/${BRANCH}.tar.gz"
echo "正在从 GitHub 下载 ScreenStream 木林森版……"
curl --fail --location --silent --show-error "${ARCHIVE_URL}" -o "${TEMP_DIR}/source.tar.gz"
tar -xzf "${TEMP_DIR}/source.tar.gz" -C "${TEMP_DIR}"

SOURCE_DIR="${TEMP_DIR}/ScreenStream-Mulinsen-${BRANCH}"
if [[ ! -f "${SOURCE_DIR}/deploy/vps/install.sh" ]]; then
  echo "下载内容不完整，未找到安装脚本。"
  exit 1
fi

chmod +x "${SOURCE_DIR}/deploy/vps/install.sh"
bash "${SOURCE_DIR}/deploy/vps/install.sh"
