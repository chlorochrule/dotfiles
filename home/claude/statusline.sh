#!/usr/bin/env bash
# Claude Code statusLine: renders one line from the session JSON on stdin.
#
#   <model> <effort> | <dir> (<branch>) [wt:<worktree>] | ctx <n>% | 5h <n>%
#
# 5h is the claude.ai rate limit; when it's absent (API key, or a local
# Ollama model via claude-q36/claude-q3cn) the session cost is shown instead.
# Fields that Claude Code omits or sends as null are just left out.
set -u

input="$(cat)"

# One jq call; \x1f (not tab) as the separator so empty fields survive `read`.
IFS=$'\x1f' read -r model effort dir ctx five_hour cost worktree < <(
  jq -r '[
    (.model.display_name // .model.id // "?"),
    (.effort.level // ""),
    (.workspace.current_dir // .cwd // ""),
    (.context_window.used_percentage // "" | tostring),
    (.rate_limits.five_hour.used_percentage // "" | tostring),
    (.cost.total_cost_usd // "" | tostring),
    (.worktree.name // .workspace.git_worktree // "")
  ] | join("\u001f")' <<<"$input" 2>/dev/null
)

reset=$'\033[0m'
dim=$'\033[2m'

# Green below 50%, yellow below 80%, red above.
color_pct() {
  local n="${1%%.*}"
  if [ "$n" -ge 80 ]; then
    printf '\033[31m'
  elif [ "$n" -ge 50 ]; then
    printf '\033[33m'
  else
    printf '\033[32m'
  fi
}

parts=()

seg="${model:-?}"
[ -n "$effort" ] && seg+=" ${dim}${effort}${reset}"
parts+=("$seg")

if [ -n "$dir" ]; then
  seg="${dir##*/}"
  branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
  [ -n "$branch" ] && seg+=" ($branch)"
  [ -n "$worktree" ] && seg+=" ${dim}wt:${worktree}${reset}"
  parts+=("$seg")
fi

if [ -n "$ctx" ]; then
  parts+=("ctx $(color_pct "$ctx")${ctx%%.*}%${reset}")
fi

if [ -n "$five_hour" ]; then
  parts+=("5h $(color_pct "$five_hour")${five_hour%%.*}%${reset}")
elif [ -n "$cost" ]; then
  parts+=("$(printf '$%.2f' "$cost")")
fi

sep=" ${dim}|${reset} "
out="${parts[0]}"
for p in "${parts[@]:1}"; do
  out+="${sep}${p}"
done
printf '%s\n' "$out"
