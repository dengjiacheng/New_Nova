#!/usr/bin/env bash
set -euo pipefail
echo "[gate] 检查已接受的 DCP（status: accepted）..."
set +e
grep -R "status:\s*accepted" docs/dcp >/dev/null 2>&1
has=$?
set -e
if [ "$has" -ne 0 ]; then
  echo "::error::未找到已接受的 DCP。代码 PR 在 DCP 接受前禁止通过。"
  exit 1
fi
echo "[gate] 通过"
