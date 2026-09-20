#!/usr/bin/env bash
# PreToolUse (Bash) hook: blocks a few destructive commands outright,
# regardless of permission mode, allow rules, or the sandbox. exit 2 hands
# the reason back to Claude.
#
# Blocked:
# - recursive rm whose target is /, the home directory, or /Users
# - git push with --force/-f or a +refspec (--force-with-lease is allowed)
#
# Pattern matching on the command text only; it doesn't see through
# `sh -c`, xargs, or scripts, and backslash-escaped quotes can throw off the
# quote handling. It's a guard against slips, not a boundary.
set -eu

input="$(cat)"
# Separators inside quotes (git commit -m "wip; git push -f later") are
# blanked out here so the split below doesn't turn them into commands.
cmd="$(jq -r '.tool_input.command // empty
  | gsub("(?<q>\"[^\"]*\"|'"'"'[^'"'"']*'"'"')"; .q | gsub("[;&|()\n]"; " "))' <<<"$input")"

[ -n "$cmd" ] || exit 0

block() {
  echo "guard-bash: blocked: $1" >&2
  echo "Ask the user to run it themselves if it's really intended." >&2
  exit 2
}

is_dangerous_rm_target() {
  local t="${1%/}"
  # shellcheck disable=SC2088 # "~" is matched literally, on purpose
  case "$t" in
    # All patterns are quoted, so they match the literal (unexpanded) text:
    # "/" itself ends up as "" after stripping the trailing slash, and "/*"
    # means someone literally wrote `rm -rf /*`.
    "" | "/*" | "/Users" | "/Users/*" | "~" | "~/*" | "$HOME" | "$HOME/*")
      return 0
      ;;
    "\$HOME" | "\$HOME/*" | "\${HOME}" | "\${HOME}/*")
      return 0
      ;;
  esac
  return 1
}

check_rm() {
  local recursive=0 a
  for a in "$@"; do
    case "$a" in
      --recursive | -[a-zA-Z]*[rR]* | -[rR]*) recursive=1 ;;
    esac
  done
  [ "$recursive" = 1 ] || return 0
  for a in "$@"; do
    case "$a" in
      -*) continue ;;
    esac
    if is_dangerous_rm_target "$a"; then
      block "recursive rm on '$a'"
    fi
  done
}

check_git_push() {
  local a
  for a in "$@"; do
    case "$a" in
      --force-with-lease* | --force-if-includes) ;;
      --force) block "git push --force (use --force-with-lease)" ;;
      --*) ;;
      -*f*) block "git push $a (use --force-with-lease)" ;;
      +*) block "git push with a +refspec ($a) is a force push" ;;
    esac
  done
}

# Split on ;, &, |, parentheses and newlines (covers &&, ||, pipelines and
# subshells), then look at the first real word of each segment.
segments="$(printf '%s\n' "$cmd" | tr ';&|()' '\n')"

while IFS= read -r seg; do
  # Quotes don't matter for the checks below; dropping them keeps
  # rm -rf "$HOME" and rm -rf $HOME equivalent.
  seg="${seg//\"/}"
  seg="${seg//\'/}"
  read -ra words <<<"$seg" || true
  [ "${#words[@]}" -gt 0 ] || continue

  # Skip leading VAR=value assignments and wrappers like sudo/command/env,
  # including the wrappers' own options (sudo -u root, env -i).
  i=0
  while [ "$i" -lt "${#words[@]}" ]; do
    case "${words[$i]}" in
      *=* | sudo | command | env | exec | nohup | time) i=$((i + 1)) ;;
      # Shell keywords/groups in front of a command: `if x; then rm ...`,
      # `for ...; do git push ...`, `{ docker ...; }`, `! cmd`.
      if | then | else | elif | do | while | until | '!' | '{' | '}') i=$((i + 1)) ;;
      # sudo/env options that take a separate value.
      -u | -g | -h | -C | -D | -U | -S | --user | --group | --chdir) i=$((i + 2)) ;;
      -*)
        if [ "$i" -gt 0 ]; then
          i=$((i + 1))
        else
          break
        fi
        ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "${#words[@]}" ] || continue

  prog="${words[$i]##*/}"
  args=("${words[@]:$((i + 1))}")

  case "$prog" in
    rm)
      check_rm "${args[@]+"${args[@]}"}"
      ;;
    git)
      # Find the subcommand, skipping git's global options, including the
      # ones whose value is a separate word (-C <dir>, --git-dir <dir>).
      j=0
      while [ "$j" -lt "${#args[@]}" ]; do
        case "${args[$j]}" in
          -C | -c | --git-dir | --work-tree | --namespace | --config-env) j=$((j + 2)) ;;
          -*) j=$((j + 1)) ;;
          *) break ;;
        esac
      done
      if [ "$j" -lt "${#args[@]}" ]; then
        rest=("${args[@]:$((j + 1))}")
        if [ "${args[$j]}" = push ]; then
          check_git_push "${rest[@]+"${rest[@]}"}"
        fi
      fi
      ;;
  esac
done <<<"$segments"

exit 0
