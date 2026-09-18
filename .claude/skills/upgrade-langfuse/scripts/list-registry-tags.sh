#!/usr/bin/env bash
# Docker Hub(またはdocker.langfuse.com経由でDocker Hubをミラーしているレジストリ)から
# 指定イメージの利用可能なタグ一覧を取得する。
#
# docker.langfuse.com/library系のレジストリはいずれもDocker Hubのトークン発行元
# (auth.docker.io)を使う認証プロキシなので、同じトークンフローで済む。
#
# 使い方:
#   list-registry-tags.sh <registry-host> <repository>
# 例:
#   list-registry-tags.sh docker.langfuse.com langfuse/langfuse
#   list-registry-tags.sh docker.langfuse.com langfuse/langfuse-worker
#   list-registry-tags.sh registry-1.docker.io library/postgres
#   list-registry-tags.sh registry-1.docker.io library/redis
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <registry-host> <repository>" >&2
  exit 1
fi

registry="$1"
repo="$2"

auth_url="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull"
token="$(curl -fsSL "$auth_url" | jq -r .token)"
curl -fsSL -H "Authorization: Bearer ${token}" "https://${registry}/v2/${repo}/tags/list" | jq -r '.tags[]'
