#!/usr/bin/env bash
# 標準入力で受け取ったタグ一覧(1行1タグ)から、現在のバージョンと同じメジャー
# バージョン内での最新パッチを求める。バージョン形式は"X.Y"(postgres)・
# "X.Y.Z"(redis・langfuse)のどちらにも対応する。
#
# 現在より新しいメジャーバージョンが存在する場合は警告として別行に表示する
# (それをそのまま上げてよいかはこのスクリプトでは判断できない。上げる場合は
# Changelogを確認し、ユーザーに確認を取ってから明示的に指定すること)。
#
# 使い方:
#   <タグ一覧> | latest-patch.sh <現在のバージョン>
# 例:
#   list-registry-tags.sh registry-1.docker.io library/postgres | latest-patch.sh 17.11
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: <tags on stdin> | $0 <current-version>" >&2
  exit 1
fi

current="$1"
current_major="${current%%.*}"

tags="$(grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$')"

same_major="$(printf '%s\n' "$tags" | grep -E "^${current_major}\." | sort -V | tail -1)"
echo "same major (${current_major}.x) latest patch: ${same_major:-not found}"

max_major="$(printf '%s\n' "$tags" | cut -d. -f1 | sort -n | tail -1)"
if [ -n "$max_major" ] && [ "$max_major" -gt "$current_major" ]; then
  echo "warning: newer major series exists: ${max_major}.x" \
    "(check the changelog before upgrading across a major version)"
fi
