#!/usr/bin/env bash
# Recreates the modules/ folder layout with empty main/variables/outputs files.
# Usage (from the infra/ folder):  bash scripts/create-modules.sh
set -euo pipefail

MODULES=(vpc security_groups alb app rds s3 bastion)
FILES=(main.tf variables.tf outputs.tf)

for module in "${MODULES[@]}"; do
  mkdir -p "modules/$module"
  for file in "${FILES[@]}"; do
    # only create the file if it doesn't exist (never overwrite real code)
    [ -f "modules/$module/$file" ] || touch "modules/$module/$file"
  done
done

echo "Created modules/: ${MODULES[*]}"