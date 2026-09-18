{ config, lib, pkgs, hostname, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  linkDotfile = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  programs.git.settings.user = {
    name = "Naoto Minami";
    email = "minami.polly@gmail.com";
  };

  # ~/.claude/settings.json はマージ対象外の単一ファイル(home/default.nixの
  # claudeMergedEntriesFor参照)なので、ホスト固有のここで直接宣言する。
  home.file.".claude/settings.json".source =
    linkDotfile "hosts/${hostname}/claude/settings.json";

  # Playwright本体(CLI/ライブラリとしての利用)とPlaywright MCPサーバー。
  # このホストでのブラウザ自動化・DevTools連携用途に限定するためホスト固有に置く。
  home.packages = with pkgs; [
    playwright-test
    playwright-mcp
  ];

  # ollama serveをlaunchd agentとして自動起動する(127.0.0.1:11434)。
  # ollama CLIパッケージもこのオプション経由で自動的にhome.packagesへ入る。
  # Claude Codeからはclaude-q36/claude-q3cn(下記zsh関数)経由で利用する。
  # OLLAMA_CONTEXT_LENGTHはデフォルトの4096のままだと、Claude Codeが送る
  # 長大なsystem prompt+tool定義だけでcontext windowを使い切ってしまい、
  # 実際のユーザー指示が無視される問題が実測(4016トークンで既に4096に迫る)で
  # 確認できたため、両モデルの実際のコンテキストウィンドウ(256K)に合わせる。
  services.ollama = {
    enable = true;
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "262144";
    };
  };

  # Ollama経由でローカルLLMをClaude Codeから使うためのラッパー。
  # 通常の`claude`(Anthropic本家)には一切影響しない。
  # CLAUDE_CODE_MAX_CONTEXT_TOKENSは、Claude Codeのモデルカタログに
  # 無いモデル名を指定した際に出る"unrecognized_model"警告を避けるため
  # (指定しないとauto-compactが実際のウィンドウを知らず200kと仮定する)。
  # どちらのモデルも実際のコンテキストウィンドウは256K。
  programs.zsh.initContent = ''
    claude-q36() {
      ANTHROPIC_BASE_URL=http://localhost:11434 \
      ANTHROPIC_AUTH_TOKEN=ollama \
      ANTHROPIC_MODEL=qwen3.6:27b \
      CLAUDE_CODE_MAX_CONTEXT_TOKENS=256000 \
      command claude "$@"
    }

    claude-q3cn() {
      ANTHROPIC_BASE_URL=http://localhost:11434 \
      ANTHROPIC_AUTH_TOKEN=ollama \
      ANTHROPIC_MODEL=qwen3-coder-next \
      CLAUDE_CODE_MAX_CONTEXT_TOKENS=256000 \
      command claude "$@"
    }
  '';

  # Claude Codeのユーザースコープ(全プロジェクト共通)MCPサーバー設定。
  # ~/.claude.jsonにはプロジェクト履歴やtrust状態などClaude Codeが書き込む
  # 可変な実行時状態も同居しているため、home.fileでファイル全体をリンクせず、
  # mcpServersキーだけをjqでマージする(他のキーやサーバーには触れない)。
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
