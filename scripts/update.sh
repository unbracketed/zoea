#!/usr/bin/env bash
# Pull --ff-only across every Zoea child repo present in the workspace.
# Skips repos that have a dirty working tree or aren't on a branch.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPOS=(zoea-server zoea-core zoea-tools zoea-web-ui zoea-deploy gateway-tui-client)

log() { printf "\033[1;34m[update]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[update]\033[0m %s\n" "$*" >&2; }

for dir in "${REPOS[@]}"; do
  if [ ! -d "$dir/.git" ]; then
    warn "$dir: not present, skipping"
    continue
  fi

  dirty="$(git -C "$dir" status --porcelain)"
  if [ -n "$dirty" ]; then
    warn "$dir: dirty working tree, skipping"
    continue
  fi

  branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD || true)"
  if [ -z "$branch" ]; then
    warn "$dir: detached HEAD, skipping"
    continue
  fi

  log "$dir: pulling on $branch"
  git -C "$dir" pull --ff-only
done
