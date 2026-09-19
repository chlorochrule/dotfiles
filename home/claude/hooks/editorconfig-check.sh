#!/usr/bin/env bash
# PostToolUse (Edit/Write) hook: checks edited/created files against
# .editorconfig and hands violations back to Claude.
set -eu

input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"

[ -n "$file" ] || exit 0
[ -f "$file" ] || exit 0

# .editorconfig itself is a template full of generated values, so it's not
# a meaningful target for its own lint.
case "$file" in
  */.editorconfig|.editorconfig) exit 0 ;;
esac

editorconfig-checker "$file" 1>&2 || exit 2
