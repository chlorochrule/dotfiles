# dotfiles

macOSの環境設定を、Nix(nix-darwin、home-manager)とHomebrewとmiseで宣言的に管理するリポジトリです。
Claude Codeの設定一式、ターミナルマルチプレクサherdrとの連携、ローカルの観測スタックもここで管理しています。

内容は著者(minami)個人の環境設定です。
`hosts/MacBookPro-minami/`は著者のマシンの定義なので、自分の環境で使う場合は「新しいマシンのセットアップ」の手順で自分のホスト定義を追加してください。

設定ごとの理由は、`.claude/rules/`にまとめています。

## 管理ツールの分担

| ツール | 役割 |
|---|---|
| Nix(nix-darwin、home-manager) | macOSのシステム設定、CLIツール、dotfilesの配置、Homebrew自体の設定 |
| Homebrew | GUIアプリ(cask)のインストールだけに使う |
| mise | プロジェクトごとの言語ランタイムのバージョン管理 |

`nodejs`だけはNix側に置いています。
`mason.nvim`がnpm経由でLSPサーバーを入れるため、ディレクトリに関係なく同じ`nodejs`が要るからです。

## 新しいマシンのセットアップ

前提はApple SiliconのmacOSと、ログインシェルのzshです。

### 1. Nixのインストール

upstream版のNixを、daemon方式(multi-user)で入れます。

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

`hosts/<ホスト名>/default.nix`を作ります。
ホスト名は`scutil --get LocalHostName`で確認できます。

```nix
# hosts/<ホスト名>/default.nix
{
  hostname = "<ホスト名>"; # scutil --get LocalHostName の出力と一致させる
  username = "<ユーザー名>";
  system = "aarch64-darwin";
}
```

そのマシンだけの設定は、任意で同じディレクトリの`darwin.nix`(caskやDockなど)と`home.nix`(gitのユーザー情報、`~/.claude/settings.json`など)に書きます。

`flake.nix`の`hosts`リストに`./hosts/<ホスト名>`を加え、追加したファイルを`git add`します(flakeはgit管理下のファイルしか読みません)。

### 4. nix-darwinのブートストラップ

初回は`darwin-rebuild`がまだ無いので、`nix run`で実行します。

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake ~/.dotfiles
```

`Unexpected files in /etc`で止まった場合は、表示に従って対象ファイルを`<ファイル名>.before-nix-darwin`にリネームしてから再実行してください。

## 日常の運用コマンド

```bash
sudo darwin-rebuild switch --flake ~/.dotfiles   # 設定を適用する
nh darwin switch                                 # 同上。進捗と差分を表示する(flakeとsudoはnhが扱う)
nh darwin build                                  # 適用せずにビルドと差分の確認だけ行う

nix flake update [<input名>]                     # flakeのinputsを更新する

darwin-rebuild --list-generations                # 世代の一覧
sudo darwin-rebuild switch --rollback            # ロールバック
sudo nix-collect-garbage --delete-older-than 30d # GC(毎週日曜3時にも自動で実行)

, cowsay hello                                   # 入れていないコマンドを1回だけ実行する
git dft / git dlog / git dshow                   # difftasticでの構文diff
```

存在しないコマンドを打つと、それを含むnixpkgsのパッケージが表示されます。
常用するなら`nix-env -iA`ではなく、flakeの`home.packages`に追加してください。

### ローカルLLM(Ollama)

Ollamaは公式アプリ(cask `ollama-app`)で入れています。
rebuildの後に一度`/Applications/Ollama.app`を起動し、モデルを取得します(合わせて数十GB)。

```bash
ollama pull qwen3.8:27b-nvfp4
ollama pull qwen3-coder-next
```

アプリを起動した状態でもう一度rebuildすると、256Kコンテキストの派生モデル(`*-262k`)が作られます。
以降は次のコマンドで使えます。

```bash
claude-q38    # Claude Code + Qwen3.8-27B
claude-q3cn   # Claude Code + Qwen3-Coder-Next
pi --model ollama/qwen3.8-27b-nvfp4-262k
pi --model ollama/qwen3-coder-next-262k
```

- Claude CodeのWebSearchを使うには、一度`ollama signin`が必要です。
- auto modeの分類器もローカルモデルで動くため、時間切れで操作が拒否されることがあります。
- piの`web_search`ツール(DuckDuckGo)はベストエフォートです。`pi --exclude-tools web_search`で無効にできます。
- モデルが要求するOllamaのバージョンは、`ollama pull`の412エラーや、manifestのconfigの`requires`で確認できます。

### ローカル画像生成(ComfyUI)

ComfyUIは公式アプリ(cask `comfy`)で入れています。
rebuildの後に一度`/Applications/Comfy Desktop.app`を起動し、初回のウィザードでGPUにMPSを選んでください。
起動中は`127.0.0.1:8188`でサーバーが動きます。
本体は`~/ComfyUI-Installs/`、モデルと出力は`~/ComfyUI-Shared/`に置かれ、どちらもdotfilesの管理外です。

MPSではfp8版が動かないので、FLUX.2はGGUF版、それ以外はbf16版を使います。
GGUF版を読むカスタムノードを入れ、ComfyUIを再起動します。

```bash
cd ~/ComfyUI-Installs/ComfyUI/ComfyUI
git clone https://github.com/city96/ComfyUI-GGUF custom_nodes/ComfyUI-GGUF
.venv/bin/python -m pip install gguf
```

モデルを取得します(合わせて約105GB)。

```bash
cd ~/ComfyUI-Shared/models
hf=https://huggingface.co
f2=$hf/Comfy-Org/flux2-dev/resolve/main/split_files
qi=$hf/Comfy-Org/Qwen-Image-2.1/resolve/main
# FLUX.2 [dev]
curl -fLC - -o unet/flux2-dev-Q8_0.gguf $hf/city96/FLUX.2-dev-gguf/resolve/main/flux2-dev-Q8_0.gguf
curl -fLC - -o text_encoders/mistral_3_small_flux2_bf16.safetensors \
  $f2/text_encoders/mistral_3_small_flux2_bf16.safetensors
curl -fLC - -o vae/flux2-vae.safetensors $f2/vae/flux2-vae.safetensors
# 8ステップで生成するためのLoRA(任意)
curl -fLC - -o loras/Flux2TurboComfyv2.safetensors $f2/loras/Flux2TurboComfyv2.safetensors
# Qwen-Image 2.1
curl -fLC - -o diffusion_models/qwen_image_2.1_bf16.safetensors $qi/diffusion_models/qwen_image_2.1_bf16.safetensors
curl -fLC - -o text_encoders/qwen3vl_8b_bf16.safetensors $qi/text_encoders/qwen3vl_8b_bf16.safetensors
curl -fLC - -o vae/qwen_image_2.1_vae_bf16.safetensors $qi/vae/qwen_image_2.1_vae_bf16.safetensors
```

公式テンプレートを使うときは、FLUX.2のローダーを`UnetLoaderGGUF`に替え、各モデルを上のファイルに選び直してください。
FLUX.2は約71GBあるので、Ollamaの大きなモデルと同時に動かすとメモリが足りなくなるおそれがあります。

## 検査とCI

`.github/workflows/`のCIは、各ステップで`Makefile`のターゲットを呼んでいます。
ローカルでも同じ検査を実行できます。

```bash
make check   # CIと同じ検査をすべて実行する
make nixfmt  # 1つだけ実行する(ターゲットの一覧はMakefileを参照)
make fmt     # nixfmt、stylua、terraform fmtで整形する
```

- `flake.lock`は毎週土曜に自動で更新のプルリクエストが作られます。
  そのためには、リポジトリのSettings → Actions → Generalで「Allow GitHub Actions to create and approve pull requests」を有効にしておきます。
- Actionsのバージョンは、Dependabotが毎週更新します。
- 一括整形のコミットを`git blame`から除外するには、`git config blame.ignoreRevsFile .git-blame-ignore-revs`を一度実行します。

## ファイル構成

```
~/.dotfiles/
├── .claude/
│   ├── rules/              # 設定ごとの理由(該当ファイルを読んだときにClaude Codeがロードする)
│   └── skills/             # このリポジトリでの作業用のskill(~/.claude/へは配置しない)
├── .github/, Makefile      # CIと、同じ検査をローカルで実行するMakefile
├── flake.nix               # inputsと、hosts/をdarwinConfigurationsへ展開する処理
├── darwin.nix              # 全マシン共通のnix-darwin設定
├── hosts/<hostname>/
│   ├── default.nix         # マシン固有の値(hostname、username、system)
│   ├── darwin.nix          # (任意)マシン固有のnix-darwin設定
│   ├── home.nix            # (任意)マシン固有のhome-manager設定
│   ├── claude/             # (任意)このマシンだけの~/.claude/の中身
│   ├── ollama/             # (任意)Ollamaの派生モデルのModelfile
│   └── pi/                 # (任意)~/.pi/agent/へリンクするファイル
├── home/
│   ├── default.nix         # 全マシン共通のhome-manager設定
│   ├── claude/             # 全マシン共通の~/.claude/の中身(CLAUDE.md、hooks、skills等)
│   └── chrome/             # VimiumのBackup(手動でRestoreする)
├── .config/                # Neovim、herdrの設定
├── .tigrc, .editorconfig, bin/
├── services/               # ローカル専用サービスのDocker Compose定義
├── terraform/local/        # 上のサービスをプロビジョニングするTerraform
├── tests/                  # home/claude/のスクリプトの回帰テスト
└── CLAUDE.md               # このリポジトリで作業するClaude Code向けの指示
```

`home/`配下や`.tigrc`などは`~/`からシンボリックリンクされるので、編集はrebuildなしで反映されます。
ただし、次の2点は例外です。

- `~/.claude/`の`commands/`、`skills/`、`agents/`、`hooks/`は、`home/claude/`と`hosts/<hostname>/claude/`をファイル単位でマージしたものです。
  新しいファイルを追加したときはrebuildが必要です。
- `~/.claude/settings.json`は実ファイルで、rebuildのたびにリポジトリの内容が上書きマージされます。
  リポジトリからキーを消しても残るので、無効にしたいときは値を変えてください(例: `"sandbox": {"enabled": false}`)。

## Claude Codeの設定

`permissions.defaultMode`を`"auto"`にする代わりに、sandbox、`permissions.deny`、`home/claude/hooks/guard-bash.sh`で守りを固めています。
詳細と理由は`.claude/rules/claude-code.md`にあります。

- sandboxの外で実行するコマンドは`excludedCommands`に並べています。
  除外が効くのはコマンドを単独で実行したときだけで、`&&`やパイプで繋ぐとsandboxの中で実行されます。
  ほかのプロジェクトで失敗するコマンドがあれば追加してください。
- MCPサーバー(Chrome DevTools、Playwright、Context7)は、`hosts/MacBookPro-minami/home.nix`で`~/.claude.json`へ登録します。
- claudecode.nvimで、NeovimをIDEとして接続できます。
  同じディレクトリで起動したClaude Codeから`/ide`を実行します。
  選択範囲の送信は`<Leader>cs`、diffの受け入れと拒否は`<Leader>cy`と`<Leader>cn`です。
- herdrの更新で統合フックが変わったときは、`herdr integration install claude`を実行し直し、結果を`home/claude/hooks/herdr-agent-state.sh`へ反映します。

## 運用上の注意

- `darwin-rebuild switch`の`$HOME is not owned by you`という警告は、`sudo`で実行したためで実害はありません。
- flakeはgit管理下のファイルしか読みません。新しいファイルはrebuildの前に`git add`してください。
- unfreeのパッケージを追加するときは、`darwin.nix`の`allowUnfreePredicate`にも名前を加えてください。
- `homebrew.casks`に無いcaskは、rebuild時に設定ディレクトリごと削除(zap)されます。
  GUIアプリは必ず`hosts/<hostname>/darwin.nix`の一覧に加え、外すときに設定を残したい場合は先に退避してください。
  公式以外のtapは`homebrew.taps`にも書いてください。
  手で入れたアプリは、caskに加えればそのまま管理下に入ります。
- caskはrebuildのたびに、自動更新するものも含めてアップグレードされます。
  特定のcaskを外すには`greedy = false`を付けます。
- キー配列や`com.apple.symbolichotkeys`のショートカットは`darwin.nix`で管理しており、システム設定で変えてもrebuildで戻ります。
- gitleaksのpre-commitフックは`init.templateDir`で配布しています。
  既存のリポジトリに入れるには、そのリポジトリで`git init`を実行し直してください(既存のフックは上書きされません)。
- piは`nixpkgs-unstable`から入れています。新しい版は`nix flake update nixpkgs-unstable`の後にrebuildで取り込みます。
- Claude for Chromeは手動でインストールします。
  Vimiumの設定は、オプション画面の「Backup and Restore」で`home/chrome/vimium-options.json`をRestoreします。
  変更したらBackupで書き出したファイルで上書きしてコミットしてください。

## ローカルサービス(Langfuse、Grafana、Prometheus)

Claude Codeの操作ログを記録するLangfuse、ダッシュボードのGrafana、メトリクスを集めるPrometheusを、このMacの中だけで動かせます。
使うかどうかは任意です。

```bash
cd ~/.dotfiles/terraform/local
terraform init
terraform apply
```

手順と運用コマンドは[services/README.md](services/README.md)にまとめています。
