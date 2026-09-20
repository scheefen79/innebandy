#!/usr/bin/env bash
set -euo pipefail

bash "$(dirname "$0")/repo-guards.sh"

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
