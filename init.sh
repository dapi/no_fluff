#!/usr/bin/env bash

# No Fluff local-checkout bootstrap. It prepares only the documented local
# Docker/Dip development environment and never copies secrets or deploys.

set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required for No Fluff local development." >&2
    exit 1
  fi
}

require_command mise
require_command docker

mise trust
mise install

mise exec -- dip --version >/dev/null

if ! docker info >/dev/null 2>&1; then
  echo "Docker is installed but its daemon is not available." >&2
  exit 1
fi

mise exec -- dip provision

cat <<'EOF'
No Fluff local environment is provisioned.

Useful commands:
  dip rails s
  dip jobs
  dip test
  dip rubocop
  dip brakeman

No secrets or .env files were copied. Load required developer credentials from
named pass entries through an explicitly configured local .envrc.
EOF
