#!/usr/bin/env bash
set -euo pipefail

tracked_env_files="$(git ls-files '.env*')"
if [[ "$tracked_env_files" != ".env.example" ]]; then
  echo "Unexpected tracked environment file: $tracked_env_files" >&2
  exit 1
fi

if git ls-files | grep -q '^\.vercel/'; then
  echo ".vercel must not be tracked." >&2
  exit 1
fi

if git grep -nE '(sbp_[A-Za-z0-9_-]{20,}|sb_secret_[A-Za-z0-9_-]{20,}|gh[opsu]_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.)' -- ':!pnpm-lock.yaml'; then
  echo "Possible tracked secret detected." >&2
  exit 1
fi

if git grep -nE '@(gmail|hotmail|outlook)\.com'; then
  echo "Possible real personal email detected in a tracked production artifact." >&2
  exit 1
fi

pnpm lint
pnpm typecheck
pnpm test -- --run
pnpm db:reset
pnpm db:test
pnpm db:lint
pnpm db:test:concurrency
pnpm db:test:manual-concurrency
pnpm db:test:extra-concurrency
pnpm db:test:completion-concurrency
pnpm db:test:player-concurrency
pnpm db:test:team-concurrency
pnpm db:test:production-bootstrap
pnpm build
git diff --check

echo "Local production preflight passed. No remote system was changed."
