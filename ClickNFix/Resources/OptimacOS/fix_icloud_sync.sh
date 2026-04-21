#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-}"
run() { if [[ "$DRY_RUN" == "--dry-run" ]]; then echo "[DRY RUN] $*"; else eval "$*"; fi; }
echo "20% Restarting iCloud agents"
run "launchctl kickstart -k gui/$(id -u)/com.apple.bird || true"
echo "60% Refreshing iCloud daemon"
run "brctl log --wait --shorten 2>/dev/null || true"
echo "100% completed"
