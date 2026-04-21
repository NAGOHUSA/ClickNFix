#!/bin/bash
set -euo pipefail
DRY_RUN="${1:-}"
CMD='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -seed -r -domain local -domain system -domain user'
if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo "[DRY RUN] $CMD"
  echo "100% completed"
  exit 0
fi

echo "40% Resetting Launch Services"
eval "$CMD"
echo "100% completed"
