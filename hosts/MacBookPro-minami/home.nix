{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.git.settings.user = {
    name = "Naoto Minami";
    email = "minami.polly@gmail.com";
  };

  # Merged in place, not symlinked — see .claude/rules/nix-hosts.md.
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

  # Playwright CLI/library and its MCP server. Host-specific: scoped to
  # this machine's browser automation / DevTools use.
  home.packages = with pkgs; [
    playwright-test
    playwright-mcp
  ];

  # Runs ollama serve as a launchd agent (127.0.0.1:11434); also pulls in
  # the ollama CLI. Used from Claude Code via claude-q36/claude-q3cn below.
  # See .claude/rules/nix-hosts.md for the context-window setup.
  services.ollama = {
    enable = true;
  };

  # Creates 256K-context derived models (*-262k) from already-pulled base
  # models — see .claude/rules/nix-hosts.md for why. No-op if the base
  # model isn't pulled yet; picked up on a later rebuild once it is.
  home.activation.ollamaContextModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ollamaCreateIfBaseExists() {
      base="$1"
      derived="$2"
      modelfile="$3"
      if ${pkgs.ollama}/bin/ollama list 2>/dev/null | grep -qF "$base"; then
        ${pkgs.ollama}/bin/ollama create "$derived" -f "$modelfile" >/dev/null 2>&1 || true
      fi
    }
    ollamaCreateIfBaseExists "qwen3.6:27b" "qwen3.6-27b-262k" "${./ollama/qwen3.6-27b-262k.Modelfile}"
    ollamaCreateIfBaseExists "qwen3-coder-next" "qwen3-coder-next-262k" "${./ollama/qwen3-coder-next-262k.Modelfile}"
  '';

  # Wrappers to run Claude Code against a local Ollama model instead of
  # Anthropic's service; plain `claude` is unaffected. ANTHROPIC_MODEL
  # names the 262k-context derived model from the activation above — see
  # .claude/rules/nix-hosts.md for CLAUDE_CODE_MAX_CONTEXT_TOKENS.
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

  # User-scoped (all-projects) Claude Code MCP servers, merged into
  # ~/.claude.json — see .claude/rules/nix-hosts.md for why this is a jq
  # merge rather than a full-file link. chrome-devtools-mcp: not in
  # nixpkgs, so run via npx; pinned to @latest, accepting the Chrome
  # DevTools team as a trusted-but-unpinned upstream. context7: up-to-date,
  # version-specific library docs; uses Upstash's hosted endpoint (no local
  # code runs) without an API key, so it's on the anonymous rate limit.
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
        "context7": { type: "http", url: "https://mcp.context7.com/mcp" },
        "playwright": { type: "stdio", command: $pwBin }
      })' \
      "$claudeJson" > "$tmp"
    mv "$tmp" "$claudeJson"
  '';
}
