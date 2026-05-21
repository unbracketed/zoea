#!/usr/bin/env bash
# Compact branch + dirty + ahead/behind summary for every Zoea child repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPOS=(zoea-server zoea-core zoea-tools zoea-web-ui zoea-deploy gateway-tui-client)

bold=$'\033[1m'; dim=$'\033[2m'; red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'; reset=$'\033[0m'

printf "%-22s %-20s %-10s %s\n" "REPO" "BRANCH" "DIRTY" "AHEAD/BEHIND"
printf "%-22s %-20s %-10s %s\n" "----" "------" "-----" "------------"

for dir in "${REPOS[@]}"; do
  if [ ! -d "$dir/.git" ]; then
    printf "%-22s ${dim}%s${reset}\n" "$dir" "(not cloned)"
    continue
  fi

  branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD || echo "(detached)")"
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    dirty="${yellow}yes${reset}"
  else
    dirty="${green}no${reset}"
  fi

  # fetch nothing — just report against existing remote-tracking branch
  ahead_behind=""
  if upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    counts="$(git -C "$dir" rev-list --left-right --count "$upstream"...HEAD 2>/dev/null || echo "")"
    if [ -n "$counts" ]; then
      behind="$(echo "$counts" | awk '{print $1}')"
      ahead="$(echo "$counts" | awk '{print $2}')"
      ahead_behind="+$ahead / -$behind  ${dim}vs $upstream${reset}"
    fi
  else
    ahead_behind="${dim}(no upstream)${reset}"
  fi

  printf "%-22s %-20s %-19b %b\n" "$dir" "$branch" "$dirty" "$ahead_behind"
done
