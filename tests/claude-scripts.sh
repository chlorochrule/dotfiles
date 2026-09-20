#!/usr/bin/env bash
# Regression tests for the Claude Code scripts under home/claude/.
# Run from anywhere: tests/claude-scripts.sh (also run by CI). Needs jq and git.
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/home/claude/hooks/guard-bash.sh"
statusline="$root/home/claude/statusline.sh"

failures=0
pass() { printf 'ok   %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  failures=$((failures + 1))
}

# guard-bash.sh: expect exit 2 (blocked) or 0 (allowed) for a Bash command.
guard_expect() {
  local want="$1" cmd="$2" got
  jq -n --arg c "$cmd" '{tool_input: {command: $c}}' | "$guard" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    pass "guard[$want] $cmd"
  else
    fail "guard[$want] $cmd (got $got)"
  fi
}

# Single-quoted on purpose: these are literal command strings, not expansions.
# shellcheck disable=SC2016
{
  guard_expect 2 'rm -rf ~'
  guard_expect 2 'rm -rf ~/'
  guard_expect 2 'rm -rf "$HOME"'
  guard_expect 2 'rm -fr ${HOME}/*'
  guard_expect 2 'rm -rf /'
  guard_expect 2 'sudo rm -rf /*'
  guard_expect 2 'cd x && rm -r -f ~'
  guard_expect 2 "rm -rf $HOME"
  guard_expect 2 'rm --recursive /Users'
  guard_expect 2 'git push --force'
  guard_expect 2 'git push -f origin main'
  guard_expect 2 'git -C foo push -uf origin x'
  guard_expect 2 'git push origin +main'
  guard_expect 2 'echo ok; git push --force origin main'
  guard_expect 2 'sudo -u root rm -rf ~'
  guard_expect 2 'env -i rm -rf /'
  guard_expect 2 'git --git-dir .git push -f'
  guard_expect 2 'git --git-dir=.git push --force'
  guard_expect 2 'git -c a=b -C dir push --force'
  guard_expect 2 'if true; then rm -rf ~; fi'
  guard_expect 2 '(rm -rf ~)'
  guard_expect 2 'for r in a; do git push -f; done'
  guard_expect 2 '! git push --force'
  guard_expect 2 'echo $(git push -f)'

  guard_expect 0 'rm -rf ./build'
  guard_expect 0 'rm -rf ~/tmp/foo'
  guard_expect 0 'rm ~/.foo'
  guard_expect 0 'rm -rf "$HOME/.cache/foo"'
  guard_expect 0 'git push'
  guard_expect 0 'git push origin main'
  guard_expect 0 'git push --force-with-lease'
  guard_expect 0 'git push --follow-tags'
  guard_expect 0 'git commit -m "rm -rf ~ is bad"'
  guard_expect 0 'ls | grep -f foo'
  guard_expect 0 'echo "git push --force"'
  guard_expect 0 'git commit -m "wip; git push -f later"'
  guard_expect 0 "echo 'a | rm -rf ~'"
  guard_expect 0 'sudo -u root ls ~'
  guard_expect 0 'env -i FOO=1 make build'
  guard_expect 0 'if [ -d build ]; then rm -rf build; fi'
  guard_expect 0 'git commit -m "fix (rm -rf ~) handling"'
  guard_expect 0 'for f in *.txt; do echo "$f"; done'
  guard_expect 0 ''
}

# statusline.sh: compare the output with ANSI escapes stripped.
statusline_expect() {
  local name="$1" json="$2" want="$3" got
  got="$(printf '%s' "$json" | "$statusline" | sed 's/\x1b\[[0-9;]*m//g')"
  if [ "$got" = "$want" ]; then
    pass "statusline $name"
  else
    fail "statusline $name: got '$got', want '$want'"
  fi
}

# Template given explicitly: macOS mktemp ignores TMPDIR without one.
nogit="$(mktemp -d "${TMPDIR:-/tmp}/claude-scripts.XXXXXX")"
trap 'rm -rf "$nogit"' EXIT

d="$nogit"
statusline_expect full "$(jq -nc --arg d "$d" '{
  model: {display_name: "Opus"}, effort: {level: "high"},
  workspace: {current_dir: $d}, context_window: {used_percentage: 8},
  rate_limits: {five_hour: {used_percentage: 23.5}}, cost: {total_cost_usd: 0.01}
}')" "Opus high | ${d##*/} | ctx 8% | 5h 23%"
statusline_expect cost-fallback "$(jq -nc --arg d "$d" '{
  model: {id: "qwen3.6-27b-262k"}, cwd: $d,
  context_window: {used_percentage: 83.7}, cost: {total_cost_usd: 1.5}
}')" "qwen3.6-27b-262k | ${d##*/} | ctx 83% | \$1.50"
statusline_expect nulls "$(jq -nc --arg d "$d" '{
  model: {display_name: "Opus"}, workspace: {current_dir: $d},
  context_window: {used_percentage: null}
}')" "Opus | ${d##*/}"
statusline_expect empty-object '{}' '?'
statusline_expect not-json 'not json' '?'

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
