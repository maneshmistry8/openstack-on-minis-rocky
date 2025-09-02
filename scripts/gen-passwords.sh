#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v kolla-genpwd >/dev/null 2>&1; then
  echo "kolla-genpwd not found. Activate venv and pip install -r requirements.txt" >&2
  exit 1
fi
mkdir -p kolla
kolla-genpwd -p kolla/passwords.yml
echo "Generated kolla/passwords.yml (not committed)"
