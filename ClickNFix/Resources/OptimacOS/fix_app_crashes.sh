#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-}"
run() { if [[ "$DRY_RUN" == "--dry-run" ]]; then echo "[DRY RUN] $*"; else eval "$*"; fi; }
echo "20% Clearing crash-related caches"
run "rm -rf ~/Library/Caches/com.apple.coresymbolicationd"
echo "70% Restarting preference daemon"
run "launchctl kickstart -k gui/$(id -u)/com.apple.cfprefsd.xpc.daemon || true"
echo "100% completed"
