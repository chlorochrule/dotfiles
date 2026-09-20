# dotfiles

macOSの環境設定を、Nix(nix-darwin、home-manager)とHomebrewとmiseで宣言的に管理するリポジトリです。
Claude Codeの設定一式(rules、skills、hooks)の配布、ターミナルマルチプレクサherdrとの連携、操作ログを可視化するローカルの観測スタックも、このリポジトリで管理しています。

内容は著者(minami)個人の環境設定です。
`hosts/MacBookPro-minami/`は著者のマシンの定義なので、自分の環境で使う場合は「新しいマシンのセットアップ」の手順で自分のホスト定義を追加してください。

## 管理ツールの分担

| ツール | 役割 |
|---|---|
| Nix(nix-darwin、home-manager) | macOSのシステム設定、グローバルなCLIツール、dotfilesの配置、Homebrew自体の設定 |
| Homebrew | GUIアプリ(cask)のインストールだけに使う。formulaは使わない |
| mise | プロジェクトごとの言語ランタイム(node、python等)のバージョン管理 |

ランタイムはmise、CLIツールはNixという分担ですが、`nodejs`だけはNix側に置いています。
`mason.nvim`がLSPサーバーをnpm経由でインストールするため、ディレクトリに関係なく常に同じ`nodejs`を使える必要があるからです。

## 前提となる環境

- macOS(Apple Silicon、`aarch64-darwin`)
- ログインシェルがzsh

## 新しいマシンのセットアップ

### 1. Nixのインストール

Nixは、Determinate Nixではなくupstream版を、daemon方式(multi-user)でインストールします。

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

インストールが終わったら、ターミナルを開き直してください。

### 2. リポジトリの取得

```bash
mkdir -p ~/src/github.com/chlorochrule
git clone https://github.com/chlorochrule/dotfiles ~/src/github.com/chlorochrule/dotfiles
ln -s ~/src/github.com/chlorochrule/dotfiles ~/.dotfiles
```

### 3. ホスト定義の追加

ホスト定義のディレクトリ名には、マシンのホスト名を使います。
ホスト名は次のコマンドで確認できます。

```bash
scutil --get LocalHostName
```

`hosts/<ホスト名>/`を作り、`default.nix`を置きます。
必須のファイルはこれだけです。

```nix
# hosts/<ホスト名>/default.nix
{
  hostname = "<ホスト名>"; # scutil --get LocalHostName の出力と一致させる
  username = "<ユーザー名>";
  system = "aarch64-darwin";
}
```

そのマシンだけの設定は、同じディレクトリに次のファイルを置いて書きます。
どちらも任意です。

- **`darwin.nix`**：そのマシンだけのnix-darwin設定(Homebrewのcaskの一覧、Dockの構成など)
- **`home.nix`**：そのマシンだけのhome-manager設定(gitのユーザー情報、`~/.claude/settings.json`など)

最後に、`flake.nix`の`hosts`リストへ追加したディレクトリを1行加えます。

```nix
hosts = [
  ./hosts/MacBookPro-minami
  ./hosts/<ホスト名>
];
```

flakeはgit管理下のファイルしか読まないので、追加したファイルは`git add`しておきます。

```bash
cd ~/.dotfiles
git add hosts/<ホスト名> flake.nix
```

### 4. nix-darwinのブートストラップ

初回は`darwin-rebuild`コマンドがまだ無いので、`nix run`で実行します。

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake ~/.dotfiles
```

`/etc/bashrc`や`/etc/zshrc`のように、nix-darwinが管理するファイルがすでに存在すると、`Unexpected files in /etc`のようなエラーで止まります。
その場合は、表示される指示に従って対象ファイルを`<ファイル名>.before-nix-darwin`にリネームしてから、もう一度実行してください。

2回目以降は`darwin-rebuild`コマンドを直接使えます。
home-manager側の設定(zsh、git、mise、Ghostty等)も、このコマンドで一緒に適用されます。

## 日常の運用コマンド

```bash
# 設定の変更を適用する(編集したファイルはgit addしておく)
sudo darwin-rebuild switch --flake ~/.dotfiles
# nhでも同じことができる。ビルドの進み具合と、変わるパッケージの差分が表示される
# (flakeの場所は環境変数NH_DARWIN_FLAKEで指定済み。sudoはnhが内部で求める)
nh darwin switch
nh darwin build              # 適用せずにビルドと差分の確認だけ行う

# flakeのinputsを最新にする(flake.lockを書き換えるだけなのでsudoは不要)
nix flake update
nix flake update <input名>   # 特定のinputだけ

# 世代の一覧とロールバック
darwin-rebuild --list-generations
sudo darwin-rebuild switch --rollback

# ガベージコレクション
sudo nix-collect-garbage --delete-older-than 30d
```

ガベージコレクションは、`darwin.nix`の`nix.gc`で毎週日曜3時にも自動で実行されます。
Nix storeの重複ファイルをまとめる`nix-store --optimise`も、`nix.optimise`で同じ日の4時15分に実行されます。

### Nixで入れたツールの使い方

```bash
, cowsay hello        # 入れていないコマンドを、その場で1回だけ実行する(comma)
git dft               # 構文を解析したdiff(difftastic)。普通のgit diffはdeltaのまま
git dlog / git dshow  # log -pとshowのdifftastic版
ast-grep run -l python -p 'f($A)' -r 'g($A)'   # 構文木で検索・置換する
```

存在しないコマンドを打つと、そのコマンドを含むnixpkgsのパッケージが表示されます(nix-indexのcommand-not-found)。
表示される`nix-env -iA`での導入は使わず、必要ならflakeの`home.packages`に追加してください。

### ローカルLLM(Ollama)の準備と起動

`hosts/MacBookPro-minami/`は、Claude CodeをローカルのOllamaのモデルで動かすラッパーを定義しています。
モデルは初回だけ手動で取得します(合わせて数十GB)。

```bash
ollama pull qwen3.6:27b        # dense 27B、18GB(q4_K_M)
ollama pull qwen3-coder-next   # 80B MoE(3B active)、46GB
```

取得した後にもう一度rebuildすると、256Kのコンテキスト長を設定した派生モデル(`*-262k`)が作られます[^ollama-ctx]。
以降は次のコマンドでClaude Codeを起動できます。

```bash
claude-q36    # Qwen3.6-27B
claude-q3cn   # Qwen3-Coder-Next
```

[^ollama-ctx]: Ollamaの既定のコンテキスト長(4096)は、Claude Codeのシステムプロンプトだけでほぼ埋まってしまいます。
    詳しくは`.claude/rules/nix-hosts.md`を参照してください。

## コードの整形とCI

Neovimでは、保存時にconform.nvimがLua(stylua)、Nix(nixfmt)、Terraform(`terraform fmt`)のファイルを整形します。
これ以外のファイルタイプは、保存しても整形しません。

GitHub Actions(`.github/workflows/check.yml`)は、mainへのpushとプルリクエストのたびに次の検査を実行します。

- `nix flake check`と、全ホストの`darwinConfigurations`の評価
- nixfmt、styluaによる整形の検査
- editorconfig-checker、shellcheck、actionlint(ワークフローの検査)による検査
- Claude Codeの`settings.json`の、schemastoreのスキーマによる検査(Claude Codeは綴りを誤ったキーを黙って無視するため)
- `docker-compose.yml`と`dependabot.yml`の、スキーマによる検査
- `tests/claude-scripts.sh`による、Claude Code用スクリプト(`guard-bash.sh`、`statusline.sh`)の回帰テスト
- gitleaksによる、履歴全体の秘密情報の検査

`terraform fmt`と`terraform validate`だけは、別のワークフロー(`.github/workflows/terraform.yml`)で実行します。
実行するのは、`terraform/`か`flake.lock`が変わったときだけです。
terraformはunfreeライセンスなのでNixのバイナリキャッシュに無く、CIでは毎回ソースからビルドされて5分以上かかるためです。

`.github/workflows/update-flake-lock.yml`は、毎週土曜の3時(JST)に`flake.lock`のinputsを更新し、プルリクエストを作ります。
GitHub Actionsのトークンで作ったプルリクエストでは検査が自動では実行されません。
そのため、このワークフローが`workflow_dispatch`で`check.yml`と`terraform.yml`を起動します[^flake-lock-pr]。
Actionsの画面から手動で実行することもできます。

CIの各ステップは`Makefile`のターゲットを呼んでいるだけなので、ローカルでも同じ検査を実行できます。
検査のツールは`flake.lock`のnixpkgsから取得するので、CIとローカルで同じバージョンが使われます。

```bash
make check      # CIと同じ検査をすべて実行する
make nixfmt     # 1つだけ実行する(ターゲットの一覧はMakefileを参照)
make fmt        # nixfmt、stylua、terraform fmtでの整形を一括で適用する
```

GitHub Actionsで使っているアクションのバージョンは、Dependabot(`.github/dependabot.yml`)が毎週まとめて更新のプルリクエストを作ります。

[^flake-lock-pr]: プルリクエストを作れるようにするには、リポジトリの設定を1つ変える必要があります。
    Settings → Actions → Generalで、「Allow GitHub Actions to create and approve pull requests」を有効にしてください。

リポジトリ全体を一括で整形したコミットは、`.git-blame-ignore-revs`に登録しています。
GitHubのblame表示はこのファイルを自動で読み込むので、一括整形のコミットは表示されません。
ローカルの`git blame`でも除外したい場合は、次の設定を一度だけ実行してください。

```bash
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

## ファイル構成

```
~/.dotfiles/
├── .claude/
│   ├── skills/                  # このリポジトリでの作業に使うskill(Claude Codeが自動で検出する)
│   │                            # ~/.claude/へは配置しない(home/claude/skills/とは別物)
│   │                            # 例: upgrade-services(services/のバージョンを上げる手順)
│   └── rules/                   # 各設定の理由をまとめたClaude Code向けの背景情報
│                                # frontmatterのpathsで、該当ファイルを読んだときだけロードされる
├── .github/                     # CI、flake.lockの自動更新、Dependabot(「コードの整形とCI」参照)
├── Makefile                     # CIと同じ検査をローカルで実行する(make check)
├── .git-blame-ignore-revs       # git blameから除外する一括整形コミット
├── flake.nix                    # inputsの定義と、hosts/をdarwinConfigurationsへ展開する処理
├── darwin.nix                   # 全マシン共通のnix-darwin設定
│                                # (system.defaults、フォント、sudoのTouch ID、Nixの自動GC等)
├── hosts/
│   └── <hostname>/
│       ├── default.nix          # マシン固有の値(hostname、username、system)
│       ├── darwin.nix           # (任意)マシン固有のnix-darwin設定。例: Homebrewのcask
│       ├── home.nix             # (任意)マシン固有のhome-manager設定
│       │                        # 例: gitのユーザー情報、ローカルLLM(Ollama)関連
│       └── claude/              # (任意)このマシンだけの~/.claude/の中身
│           └── settings.json    # このマシンの~/.claude/settings.json
├── home/
│   ├── default.nix              # 全マシン共通のhome-manager設定
│   │                            # (zsh、git、delta、mise、direnv、fzf、starship、Ghostty等)
│   └── claude/                  # 全マシン共通の~/.claude/の中身
│       ├── CLAUDE.md
│       ├── statusline.sh        # Claude Codeのステータスライン
│       ├── hooks/               # editorconfig-check.sh、guard-bash.sh、herdr-agent-state.sh
│       └── skills/              # 全プロジェクトで使うskill
│                                # commit-message(コミットメッセージの規約)
├── .config/nvim/                # Neovimの設定(Lua、lazy.nvim)
├── .config/herdr/config.toml    # herdrの設定
├── .tigrc, .editorconfig, bin/  # ~/から実ファイルへシンボリックリンクする
├── services/                    # ローカル専用サービス(Docker Compose定義)。Nixの管理外
│   ├── README.md                # 詳細な手順(「ローカルサービス」参照)
│   ├── langfuse/
│   ├── grafana/
│   └── prometheus/
├── terraform/local/             # 上の3サービスをプロビジョニングするTerraform。Nixの管理外
├── tests/claude-scripts.sh      # home/claude/のスクリプトの回帰テスト(CIでも実行する)
└── CLAUDE.md                    # このリポジトリで作業するClaude Code向けの指示
```

`home/`配下や`.tigrc`などの実ファイルは、home-managerの`mkOutOfStoreSymlink`で`~/`からシンボリックリンクされます。
Nix storeにコピーされないので、編集した内容はrebuildしなくてもすぐに反映されます。
ただし`~/.claude/settings.json`だけは扱いが異なります(次節)。

### `~/.claude/`への配置

`~/.claude/`の`commands/`、`skills/`、`agents/`、`hooks/`は、2つのディレクトリをファイル単位でマージして作ります。
マージ元は、全マシン共通の`home/claude/<name>/`と、マシン固有の`hosts/<hostname>/claude/<name>/`です。
同じ名前のファイルがあれば、マシン固有のほうが優先されます。
リンクはファイル単位で張るので、新しいファイルを追加したときはrebuildが必要です[^claude-merge]。

`~/.claude/CLAUDE.md`と`~/.claude/statusline.sh`は、`home/claude/`の同名のファイルへのシンボリックリンクです。

`~/.claude/settings.json`は、シンボリックリンクではなく実ファイルとして置きます。
Claude Code自身が実行時にこのファイルへ書き込む(モデルの選択、権限の追加、プラグインの設定など)ためです。
rebuildのたびに`hosts/<hostname>/claude/settings.json`の内容が上書きマージされ、リポジトリに書いていないキーはそのまま残ります。
リポジトリに書いたキーは、実行時に変えても次のrebuildで元に戻ります。
逆に、リポジトリからキーを消しても`~/.claude/settings.json`からは消えません。
設定を無効にしたいときは、キーを消すのではなく値を変えてください(例: `"sandbox": {"enabled": false}`)。

[^claude-merge]: マージの仕組みは`.claude/rules/nix-hosts.md`を参照してください。

### Claude Codeの安全設定

`hosts/MacBookPro-minami/claude/settings.json`は、`permissions.defaultMode`を`"auto"`にしてコマンドの実行を広く任せる代わりに、次の4つで守りを固めています。

- **sandbox**：Bashのコマンドを、macOSのSeatbeltで隔離して実行します。
  書き込めるのは作業ディレクトリとセッション用の一時ディレクトリだけで、`~/.ssh`、`~/.aws`、`~/.gnupg`と、GitHubやAWSのトークンの環境変数は読めません。
  sandboxの中では動かないコマンドは、`excludedCommands`でsandboxの外で実行します。
  対象は、nix daemonのソケットに接続する`nix`、`darwin-rebuild`、`nh`、`,`(comma)と、Dockerのソケットに接続する`docker`です。
  Go製で、Seatbelt下では失敗する`gh`と`terraform`も外しています[^sandbox-go]。
  `git push`などのリモート操作も、sandboxの中からは`~/.ssh`を読めずSSHでの接続に失敗するので外しています。
  `git init`(と、内部でそれを呼ぶ`uv init`)も外しています。
  sandboxは`.git/config`と`.git/hooks`への書き込みを常に拒否するからです(この2つはコードを実行させる経路になり得るため)。
  同じ理由で`git remote add`や`git config`もsandboxの中では失敗しますが、頻度が低いので外していません。
  失敗したときは、Claude Codeがsandboxの外で実行し直し、auto modeの分類器がその可否を判断します。
  この一覧は、このリポジトリでの作業と、npmやuvでの一般的な作業で使うコマンドを実際に試して決めたものです。
  ほかのプロジェクトで失敗するコマンドがあれば、`excludedCommands`に追加してください。
  ただし、除外が効くのはそのコマンドを単独で実行したときだけです。
  `cd ... && terraform ...`や`terraform ... | grep ...`のようにほかのコマンドと組み合わせると、sandboxの中で実行されます。
- **sandboxの書き込み許可**：npm、uv、pip、denoのキャッシュ(`~/.npm`、`~/.cache/uv`など)だけは書き込めるようにしています。
  これが無いと、`npm install`や`uv add`がキャッシュに書き込めずに失敗します。
  パッケージマネージャー自体をsandboxの外に出すと、`npm install`のpostinstallスクリプトなども無制限に動いてしまうので、キャッシュだけを許可しています。
- **`permissions.deny`**：Claude Codeのファイル操作ツールから、上の3つのディレクトリを読み書きできないようにします。
  このリポジトリの`.claude/settings.json`でも、Terraformが生成するファイルを同じように保護しています。
  対象は`services/*/.env`と`terraform/local/terraform.tfstate*`で、どちらも秘密情報を含みます。
- **`home/claude/hooks/guard-bash.sh`**(PreToolUseフック)：危険なコマンドを、権限の設定に関係なく止めます。
  対象は、ホームディレクトリやルートを対象にした再帰的な`rm`と、`--force-with-lease`ではない強制pushです。
  コマンドの文字列で判定しているだけなので、`sh -c`やスクリプトの中までは見ません。

[^sandbox-go]: 公式ドキュメントに、Go製のCLIはSeatbelt下でTLSの検証に失敗するという既知の問題として記載されています。
    このマシンでも、`terraform validate`がsandboxの中ではプラグインを読み込めずに失敗しました。

### Claude Codeのその他の設定

- **ステータスライン**：`home/claude/statusline.sh`が、モデル、effort、ディレクトリとブランチ、コンテキストの使用率を表示します。
  claude.aiのプランで使っているときは5時間枠のレート制限の使用率を、それ以外(APIキーやローカルのOllama)ではセッションのコストを表示します。
- **MCPサーバー**：Chrome DevTools、Playwright、Context7を、全プロジェクト共通で使えるように`~/.claude.json`へ登録します。
  登録の処理は`hosts/MacBookPro-minami/home.nix`にあります。
  Context7は、ライブラリのバージョンごとのドキュメントを返すサービスです。
  Upstashがホストするエンドポイントに、APIキーなし(匿名のレート制限)で接続します。
- **skill**：`home/claude/skills/`のskillは、全プロジェクトで使えます。
  `commit-message`は、コミットメッセージとプルリクエスト本文の書き方の規約です。

## 運用上の注意

### Nixとflake

- `darwin-rebuild switch`には`sudo`が必要です。
  `$HOME is not owned by you`という警告が出ますが、`sudo`で実行したためrootのホームディレクトリが使われているだけで、実害はありません。
- flakeはgit管理下のファイルしか読みません。
  新しいファイルを追加したら、rebuildの前に`git add`してください。
- unfreeライセンスのパッケージ(BSLの`terraform`など)を追加するときは、`darwin.nix`の`nixpkgs.config.allowUnfreePredicate`にパッケージ名も追加してください。

### Homebrewのcask

- `homebrew.onActivation.cleanup`を`"zap"`にしているので、`homebrew.casks`に書いていないcaskはrebuild時にアンインストールされます。
  caskの一覧は`hosts/<hostname>/darwin.nix`にあります。
  GUIアプリをHomebrewで入れるときは、必ずこのリストに追加してください。
- zapは、アプリ本体だけでなく、caskが定義する設定ディレクトリやキャッシュも削除します。
  リストからcaskを外すときに設定を残したい場合(別のcaskへ移行するときなど)は、先に設定ディレクトリを別の場所へコピーしておいてください。
- `autoUpdate`と`upgrade`を`true`にしているので、rebuildのたびにHomebrewの情報が更新され、古くなったcaskがアップグレードされます。
  ただし、アプリ自身に更新機能があるcask(`auto_updates`)はHomebrewのアップグレード対象から外れ、アプリ自身の更新機能で更新されます。
  rebuild時にHomebrewで更新させたいcaskには、`greedy = true`を付けてください(現在は`intellij-idea`だけです)。

### その他

- 全リポジトリ共通のgitleaksのpre-commitフックは、`init.templateDir`で配布しています。
  テンプレートは`git clone`と`git init`のときにだけコピーされるので、既存のリポジトリに入れるには、そのリポジトリで`git init`を実行し直してください(既存のフックは上書きされません)。
- Chrome拡張機能のClaude for Chromeは、Chromeウェブストアから手動でインストールします。
  Nixでは管理していません。
- Ollamaは、nixpkgsのDarwinリリースブランチに収録されたバージョンです。
  新しいモデルが要求するバージョンに届かない場合は、`nixpkgs-unstable`をflakeのinputに追加してください。
  そのうえで、`hosts/<hostname>/darwin.nix`の`nixpkgs.overlays`でollamaだけを差し替えます。
- herdrのメジャーアップデートで統合フックの内容が変わったときは、`herdr integration install claude`を実行し直してください。
  生成されたファイルは`home/claude/hooks/herdr-agent-state.sh`へ反映します。

## ローカルサービス(Langfuse、Grafana、Prometheus)

Claude Codeの操作ログを記録するLangfuse、そのダッシュボードを表示するGrafana、macOSのメトリクスを集めるPrometheusを、このMacの中だけで動かせます。
使うかどうかは任意で、3つまとめてTerraformでプロビジョニングします。

```bash
cd ~/.dotfiles/terraform/local
terraform init
terraform apply
```

各サービスの役割、初回セットアップの手順、バージョンアップなどの運用コマンドは、[services/README.md](services/README.md)にまとめています。
