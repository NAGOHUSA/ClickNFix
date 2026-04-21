#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-}"
step() { echo "$1"; }
run() { if [[ "$DRY_RUN" == "--dry-run" ]]; then echo "[DRY RUN] $*"; else eval "$*"; fi; }
safe_rm_contents() {
  local target="$1"
  local resolved_target
  [[ -n "$target" ]] || return 0
  [[ "$target" != *".."* ]] || { echo "Skipping unsafe cache path: $target"; return 0; }
  if [[ -d "$target" ]]; then
    resolved_target="$(cd "$target" 2>/dev/null && pwd -P || true)"
    case "$resolved_target" in
      "$HOME/Library/Caches" | "$HOME/Library/Caches"/*) ;;
      *) echo "Skipping unsafe cache path: $target"; return 0 ;;
    esac
    run "find \"$target\" -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
  fi
}
step "10% Preparing cache cleanup"
safe_rm_contents "$HOME/Library/Caches"
step "70% Clearing browser and app transient caches"
safe_rm_contents "$HOME/Library/Caches/com.apple.Safari"
safe_rm_contents "$HOME/Library/Caches/com.apple.Spotlight"
step "100% completed"
