{ config, lib, pkgs, ... }:
{
  programs.git.settings.user = {
    name = "Naoto Minami";
    email = "minami.polly@gmail.com";
  };

  # ~/.claude/settings.jsonはClaude Code自身も`/model`・`/plugin`・`/config`等で
  # 書き込むため、リンクにしない。mkOutOfStoreSymlinkだと書き込みがgit管理下の
  # 実ファイルに差分として現れ、Nix storeへのリンクだと書き込み自体が失敗する。
  # 代わりに実ファイルとして置き、rebuildのたびに./claude/settings.jsonで宣言した
  # キーだけを上書きマージする(宣言していないキーは実行時の値を維持する)。
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    claudeSettings="${config.home.homeDirectory}/.claude/settings.json"
    current='{}'
    if [ -f "$claudeSettings" ]; then
      current="$(cat "$claudeSettings")"
    fi
    tmp="$(mktemp)"
    printf '%s' "$current" | ${pkgs.jq}/bin/jq -s '.[0] * .[1]' - ${./claude/settings.json} > "$tmp"
    mkdir -p "$(dirname "$claudeSettings")"
    mv "$tmp" "$claudeSettings"
  '';

  # Playwright本体(CLI/ライブラリとしての利用)とPlaywright MCPサーバー。
  # このホストでのブラウザ自動化・DevTools連携用途に限定するためホスト固有に置く。
  home.packages = with pkgs; [
    playwright-test
    playwright-mcp
  ];

  # ollama serveをlaunchd agentとして自動起動する(127.0.0.1:11434)。
  # ollama CLIパッケージもこのオプション経由で自動的にhome.packagesへ入る。
  # Claude Codeからはclaude-q36/claude-q3cn(下記zsh関数)経由で利用する。
  # コンテキスト長はサービス全体のOLLAMA_CONTEXT_LENGTHではなく、下のactivationで
  # モデルごとに派生モデル(*-262k)を作りPARAMETER num_ctxとして焼き込む方式にしている。
  # サービス全体の環境変数にすると、将来別の軽量モデルをこのOllamaインスタンスに
  # 追加pullした際にもそちらへ256Kコンテキストが強制され、不要なメモリ消費や
  # 読み込み遅延を招くため。
  services.ollama = {
    enable = true;
  };

  # ollama pull済みの基本モデルから、コンテキスト長262144(256K)を焼き込んだ
  # 派生モデル(*-262k)をollama createで作る。Ollamaのデフォルトnum_ctxは4096しか
  # 無く、Claude Codeが送る長大なsystem prompt+tool定義だけでcontext windowを
  # 使い切ってしまい、実際のユーザー指示が無視される問題が実測(4016トークンで
  # 既に4096に迫る)で確認できたため、両モデルの実際のコンテキストウィンドウ
  # (256K)に合わせる。基本モデルが未pullの間(初回provisioning前等)は
  # 何もしない(次回rebuild時にpull済みなら作られる)。
  home.activation.ollamaContextModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ollamaCreateIfBaseExists() {
      base="$1"
      derived="$2"
      modelfile="$3"
      if ${pkgs.ollama}/bin/ollama list 2>/dev/null | grep -qF "$base"; then
        ${pkgs.ollama}/bin/ollama create "$derived" -f "$modelfile" >/dev/null 2>&1 || true
      fi
    }
    if command -v ${pkgs.ollama}/bin/ollama >/dev/null 2>&1; then
      ollamaCreateIfBaseExists "qwen3.6:27b" "qwen3.6-27b-262k" "${./ollama/qwen3.6-27b-262k.Modelfile}"
      ollamaCreateIfBaseExists "qwen3-coder-next" "qwen3-coder-next-262k" "${./ollama/qwen3-coder-next-262k.Modelfile}"
    fi
  '';

  # Ollama経由でローカルLLMをClaude Codeから使うためのラッパー。
  # 通常の`claude`(Anthropic本家)には一切影響しない。
  # ANTHROPIC_MODELは上のactivationが作る262kコンテキスト版の派生モデル名を指す。
  # CLAUDE_CODE_MAX_CONTEXT_TOKENSは、Claude Codeのモデルカタログに
  # 無いモデル名を指定した際に出る"unrecognized_model"警告を避けるため
  # (指定しないとauto-compactが実際のウィンドウを知らず200kと仮定する)。
  # どちらのモデルも実際のコンテキストウィンドウは256K。
  programs.zsh.initContent = ''
    claude-q36() {
      ANTHROPIC_BASE_URL=http://localhost:11434 \
      ANTHROPIC_AUTH_TOKEN=ollama \
      ANTHROPIC_MODEL=qwen3.6-27b-262k \
      CLAUDE_CODE_MAX_CONTEXT_TOKENS=256000 \
      command claude "$@"
    }

    claude-q3cn() {
      ANTHROPIC_BASE_URL=http://localhost:11434 \
      ANTHROPIC_AUTH_TOKEN=ollama \
      ANTHROPIC_MODEL=qwen3-coder-next-262k \
      CLAUDE_CODE_MAX_CONTEXT_TOKENS=256000 \
      command claude "$@"
    }
  '';

  # Claude Codeのユーザースコープ(全プロジェクト共通)MCPサーバー設定。
  # ~/.claude.jsonにはプロジェクト履歴やtrust状態などClaude Codeが書き込む
  # 可変な実行時状態も同居しているため、home.fileでファイル全体をリンクせず、
  # mcpServersキーだけをjqでマージする(他のキーやサーバーには触れない)。
  # chrome-devtools-mcpはnixpkgs未収録のためnpx経由。開発元(Chrome DevToolsチーム)を
  # 信頼し、バージョン未固定で中身が変わりうるリスクを受容したうえで@latestを使う。
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeJson="${config.home.homeDirectory}/.claude.json"
    if [ ! -f "$claudeJson" ]; then
      echo '{}' > "$claudeJson"
    fi
    tmp="$(mktemp)"
    ${pkgs.jq}/bin/jq \
      --arg pwBin "${pkgs.playwright-mcp}/bin/playwright-mcp" \
      '.mcpServers = ((.mcpServers // {}) + {
        "chrome-devtools": { type: "stdio", command: "npx", args: ["-y", "chrome-devtools-mcp@latest"] },
        "playwright": { type: "stdio", command: $pwBin }
      })' \
      "$claudeJson" > "$tmp"
    mv "$tmp" "$claudeJson"
  '';
}
