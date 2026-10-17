#!/usr/bin/env bash
# SessionStart hook: reports the session's directory to herdr as the pane
# token `dir`, shown as `$dir` in the sidebar's agent rows.
set -eu

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0

input="$(cat)"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
[ -n "$cwd" ] || cwd="$PWD"

herdr pane report-metadata "$HERDR_PANE_ID" --source dotfiles:dir \
  --token "dir=$(basename "$cwd")" >/dev/null 2>&1 || true
