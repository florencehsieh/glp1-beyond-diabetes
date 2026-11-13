#!/usr/bin/env bash
# Rebuild every glp1.* table and data/results/*.csv, in order.
# Run from the repo root:  bash sql/pipeline/run_all.sh
set -euo pipefail
for f in sql/pipeline/[0-9][0-9]_*.sql; do
  echo "== $f"
  psql -d aact -v ON_ERROR_STOP=1 -f "$f"
done
