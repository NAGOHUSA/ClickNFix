#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-}"
UID_VALUE="$(id -u)"
if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo "[DRY RUN] diskutil resetUserPermissions / $UID_VALUE"
  echo "100% completed"
  exit 0
fi

echo "20% Running permission repair"
diskutil resetUserPermissions / "$UID_VALUE"
echo "100% completed"
