#!/usr/bin/env bash
# Run an arbitrary shell command inside each Zoea child repo.
#
# Usage:
#   scripts/foreach.sh "<command>"
#
# Examples:
#   scripts/foreach.sh "git status -s"
#   scripts/foreach.sh "git fetch"
#   scripts/foreach.sh "git checkout main && git pull"
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <command>" >&2
  exit 2
fi

CMD="$*"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPOS=(zoea-server zoea-core zoea-tools zoea-web-ui zoea-deploy gateway-tui-client)

bold=$'\033[1m'; dim=$'\033[2m'; reset=$'\033[0m'

for dir in "${REPOS[@]}"; do
  if [ ! -d "$dir/.git" ]; then
    printf "${dim}== %s (skipped, not cloned) ==${reset}\n" "$dir"
    continue
  fi
  printf "${bold}== %s ==${reset}\n" "$dir"
  ( cd "$dir" && bash -c "$CMD" ) || printf "${dim}(command failed in %s, continuing)${reset}\n" "$dir"
done
