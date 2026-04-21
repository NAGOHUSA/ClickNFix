#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-}"
step() { echo "$1"; }
run() { if [[ "$DRY_RUN" == "--dry-run" ]]; then echo "[DRY RUN] $*"; else eval "$*"; fi; }
safe_rm_contents() {
  local target="$1"
  if [[ -d "$target" ]]; then
    run "find \"$target\" -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
  fi
}
step "10% Preparing cache cleanup"
safe_rm_contents "$HOME/Library/Caches"
step "70% Clearing browser and app transient caches"
safe_rm_contents "$HOME/Library/Caches/com.apple.Safari"
safe_rm_contents "$HOME/Library/Caches/com.apple.Spotlight"
step "100% completed"
