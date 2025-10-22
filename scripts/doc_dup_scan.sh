#!/usr/bin/env bash
set -euo pipefail
echo "[dup-scan] 扫描重复标题（占位：基于标题）"
mapfile -t titles < <(grep -RhoP "^#\s+.+$" docs | sed 's/^# //')
dups=$(printf "%s\n" "${titles[@]}" | sort | uniq -d || true)
if [ -n "${dups}" ]; then
  echo "::warning::发现可能重复的标题："
  printf "%s\n" "${dups}"
fi
echo "[dup-scan] 完成"
