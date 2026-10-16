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

  # Merged in place, not symlinked: Claude Code writes to this file.
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

  home.packages = with pkgs; [
    playwright-test
    playwright-mcp
    pi-coding-agent
  ];

  # No-op unless the Ollama app is running and the base model is pulled.
  home.activation.ollamaContextModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ollama=/Applications/Ollama.app/Contents/Resources/ollama
    ollamaCreateIfBaseExists() {
      base="$1"
      derived="$2"
      modelfile="$3"
      if [ -x "$ollama" ] && "$ollama" list 2>/dev/null | grep -qF "$base"; then
        "$ollama" create "$derived" -f "$modelfile" >/dev/null 2>&1 || true
      fi
    }
    ollamaCreateIfBaseExists "qwen3.8:27b-nvfp4" "qwen3.8-27b-nvfp4-262k" "${./ollama/qwen3.8-27b-nvfp4-262k.Modelfile}"
    ollamaCreateIfBaseExists "qwen3-coder-next" "qwen3-coder-next-262k" "${./ollama/qwen3-coder-next-262k.Modelfile}"
  '';

  home.file.".pi/agent/models.json".source = ./pi/models.json;

  home.file.".pi/agent/extensions/web-search.ts".source = ./pi/web-search.ts;

  # Claude Code against a local Ollama model; plain `claude` is unaffected.
  programs.zsh.initContent = ''
    claude-q38() {
      ANTHROPIC_BASE_URL=http://localhost:11434 \
      ANTHROPIC_AUTH_TOKEN=ollama \
      ANTHROPIC_MODEL=qwen3.8-27b-nvfp4-262k \
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

  # Only mcpServers is merged: ~/.claude.json also holds runtime state.
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
