## README.mdの更新

このリポジトリでの作業が全て完了し、`git push`する前には、必ず`README.md`が
現在の構成(ファイル構成、セットアップ手順、運用コマンド等)と一致しているか確認し、
古くなっていれば更新すること。

## dotfilesを編集する場合のルール

1. `services/`配下でterraform管理できる設定は全てterraform管理する。
    ただし、upstreamのdocker-compose.yml自体をそのまま追従させたいファイルや、
    秘密情報を含まない静的な設定ファイル(例: 各`docker-compose.yml`、
    `services/prometheus/prometheus.yml`)は対象外とし、直接コミットしてよい
    (背景は`.claude/rules/services-terraform.md`および各ファイル冒頭のコメントを参照)。
