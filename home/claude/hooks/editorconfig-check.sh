#!/usr/bin/env bash
# PostToolUse(Edit/Write)フック。編集・作成されたファイルが.editorconfigに
# 準拠しているかチェックし、違反があればClaudeに差し戻す。
set -eu

input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"

[ -n "$file" ] || exit 0
[ -f "$file" ] || exit 0

editorconfig-checker "$file" 1>&2 || exit 2
