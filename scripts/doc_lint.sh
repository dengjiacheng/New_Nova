#!/usr/bin/env bash
set -euo pipefail
echo "[doc-lint] checking Markdown basics..."
violations=0
while IFS= read -r -d '' f; do
  if grep -P "^\t" "$f" >/dev/null; then
    echo "::error file=$f::Tab 缩进不允许（请用空格）"
    violations=$((violations+1))
  fi
  lines=$(wc -l < "$f" | tr -d ' ')
  if [ "$lines" -gt 2000 ]; then
    echo "::warning file=$f::文档过长（$lines 行 > 2000 行），建议拆分"
  fi
done < <(find docs -type f -name "*.md" -print0)
if [ "$violations" -gt 0 ]; then
  echo "[doc-lint] 失败：$violations 处问题"; exit 1
fi
echo "[doc-lint] 通过"
