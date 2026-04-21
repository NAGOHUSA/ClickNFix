#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-}"
step() { echo "$1"; }
run() { if [[ "$DRY_RUN" == "--dry-run" ]]; then echo "[DRY RUN] $*"; else eval "$*"; fi; }
step "10% Preparing Finder reset"
run "defaults delete com.apple.finder 2>/dev/null || true"
step "60% Relaunching Finder"
run "osascript -e 'tell application \"Finder\" to quit' || true"
run "open -a Finder"
step "100% completed"
