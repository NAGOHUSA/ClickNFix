#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-}"
step() { echo "$1"; }
run() { if [[ "$DRY_RUN" == "--dry-run" ]]; then echo "[DRY RUN] $*"; else eval "$*"; fi; }
step "10% Preparing cache cleanup"
run "rm -rf ~/Library/Caches/*"
step "70% Clearing user temporary files"
run "rm -rf /private/var/folders/*/*/*/C/* 2>/dev/null || true"
step "100% completed"
