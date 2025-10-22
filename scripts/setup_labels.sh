#!/usr/bin/env bash
set -euo pipefail
labels=( "autopilot" "type:doc-plan" "backend" "web" "android" "flutter" "python" "java" "risk:low" "risk:medium" "risk:high" )
for l in "${labels[@]}"; do gh label create "$l" --force || true; done
echo "labels done"
