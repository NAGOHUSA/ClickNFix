#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-}"
if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo "[DRY RUN] dscacheutil -flushcache"
  echo "[DRY RUN] launchctl kickstart -k system/com.apple.mDNSResponder"
  echo "100% completed"
  exit 0
fi

echo "50% Flushing DNS cache"
dscacheutil -flushcache
launchctl kickstart -k system/com.apple.mDNSResponder || true
echo "100% completed"
