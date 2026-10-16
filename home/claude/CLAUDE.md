## ファイル末尾の改行

すべてのファイルは末尾を改行1つで終える。末尾に複数の改行(空行)がある場合は1行にまとめる。

## 開発環境の管理

このMacでは開発環境をnixとmiseで管理している。
また、設定一式はdotfilesとして管理しており、実体は
`/Users/minami/src/github.com/chlorochrule/dotfiles`にある
(`~/.dotfiles`はそこへのシンボリックリンク)。

## このMacで使えるツール

- 入っていないコマンドは`, <cmd>`(comma)で、インストールせずに1回だけ実行できる。
  常用するツールが必要なときは、dotfilesのflakeの`home.packages`に追加することを提案する
- 構文を踏まえた検索・置換には`ast-grep`を使える(文字列やコメントの中を誤って置換しない)
- 構文単位のdiffは`git dft`(difftastic)で見られる

## sandboxの外で実行するコマンド

`sandbox.excludedCommands`のコマンド(`gh`、`git push`/`fetch`/`pull`、`nix`、`nh`、`make`、
`terraform`、`docker`など)は、単独で実行したときだけsandboxの外で動く。
`&&`やパイプで繋いだり`git -C`を付けたりするとsandboxの中で実行され、TLSの検証や
SSH、nix daemonへの接続で失敗する。

- これらは他のコマンドと繋がず、1回に1つずつ実行する。`cd`が要るなら別の呼び出しで先に行う
- 出力の加工は、パイプではなくコマンド自身のオプションで行う(`gh`なら`--jq`や`--template`)
- これらが権限やネットワークのエラーで落ちたら、原因を探す前に単独で実行し直して切り分ける
