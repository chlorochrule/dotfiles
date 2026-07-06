{ config, lib, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  linkDotfile = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

  # ~/.claude/<name>/ を「共通(home/claude/<name>) + このホスト固有
  # (./claude/<name>、存在すれば)」をファイル単位でマージして構成する。
  # 同名ファイルがあればホスト固有側を優先する。
  # 新規ファイル追加時は(ディレクトリ全体シンボリックリンクと違い)rebuildが必要。
  claudeDirNames = [ "commands" "skills" "agents" "hooks" ];

  readDirIfExists = path: if builtins.pathExists path then builtins.readDir path else { };

  entriesFor = name:
    let
      commonPath = ../../home/claude + "/${name}";
      hostPath = ./claude + "/${name}";
      commonRel = "home/claude/${name}";
      hostRel = "hosts/MacBookPro-minami/claude/${name}";
      toEntries = relDir: files:
        lib.mapAttrs' (fname: _:
          lib.nameValuePair ".claude/${name}/${fname}" { source = linkDotfile "${relDir}/${fname}"; }
        ) files;
    in
    (toEntries commonRel (readDirIfExists commonPath))
    // (toEntries hostRel (readDirIfExists hostPath));
in
{
  programs.git.settings.user = {
    name = "Naoto Minami";
    email = "minami.polly@gmail.com";
  };

  home.file = lib.foldl' (acc: name: acc // (entriesFor name)) { } claudeDirNames // {
    ".claude/settings.json".source =
      linkDotfile "hosts/MacBookPro-minami/claude-settings.json";
  };

  # Playwright本体(CLI/ライブラリとしての利用)とPlaywright MCPサーバー。
  # このホストでのブラウザ自動化・DevTools連携用途に限定するためホスト固有に置く。
  home.packages = with pkgs; [
    playwright-test
    playwright-mcp
  ];

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
      --arg pwBin "${pkgs.playwright-mcp}/bin/mcp-server-playwright" \
      '.mcpServers = ((.mcpServers // {}) + {
        "chrome-devtools": { type: "stdio", command: "npx", args: ["-y", "chrome-devtools-mcp@latest"] },
        "playwright": { type: "stdio", command: $pwBin }
      })' \
      "$claudeJson" > "$tmp"
    mv "$tmp" "$claudeJson"
  '';
}
