---
paths:
  - "hosts/**"
  - "home/**"
  - "darwin.nix"
  - "flake.nix"
---

# hosts/, home/, darwin.nix, flake.nix background

Context for working on the Nix (nix-darwin + home-manager) configuration.
Human-facing setup/operation docs are in the repo README; this is the
"why" behind choices that aren't obvious from the code itself.

## Ollama local LLM context window (`hosts/MacBookPro-minami/home.nix`)

- Ollama's default `num_ctx` is 4096. Claude Code's system prompt + tool
  definitions alone come close to that on their own (~4016 tokens
  measured), so with the default, the actual user instruction gets crowded
  out and Ollama-backed sessions start responding to unrelated content.
- Fix has two parts: `OLLAMA_CONTEXT_LENGTH=262144` (256K, both models'
  real trained context) at the service level, *and* a derived model
  (`*-262k`) created per base model via `ollama create` with `PARAMETER
  num_ctx` baked in. The per-model derived model exists so that pulling a
  different, smaller model into this same Ollama instance later doesn't
  also force 256K context (and its memory cost) onto that model.
- `CLAUDE_CODE_MAX_CONTEXT_TOKENS=256000` in the `claude-q36`/`claude-q3cn`
  zsh wrappers avoids Claude Code's "unrecognized_model" warning for model
  names outside its catalog — without it, auto-compact assumes 200k and
  can trigger at the wrong point.
- Memory footprint: ~20GB for Qwen3.6-27B, ~59GB for Qwen3-Coder-Next (both
  at 256K context).
- These wrappers never affect the plain `claude` command (Anthropic's own
  service) — the env vars are wrapper-local.

## node_exporter user home path (`hosts/MacBookPro-minami/darwin.nix`)

- `services.prometheus.exporters.node` creates a
  `_prometheus-node-exporter` system user. nix-darwin computes its default
  home as `/var/lib/prometheus-node-exporter`, but the account actually
  recorded in `dscl` has `/private/var/lib/...` — same real path (`/var`
  symlinks to `/private/var`), different string. nix-darwin can't update an
  existing user's home and fails activation on the mismatch, hence the
  `lib.mkForce` override to the recorded value.

## git pre-commit hook distribution (`home/default.nix`)

- Distributed via `init.templateDir`, not the simpler-looking global
  `core.hooksPath`: setting `core.hooksPath` globally disables every
  repo's own `.git/hooks` (breaks pre-commit framework, husky, etc. in any
  repo on this machine). `templateDir` only copies the hook into
  `.git/hooks` at `clone`/`init` time, leaving existing repos untouched
  until you re-run `git init` in them.
- The template's `pre-commit` script references the Nix store path
  directly, not a symlink to it: `git clone`/`init` copies the template
  file byte-for-byte, so a symlink would be copied as a symlink and break
  once GC collects the store path it pointed to. `gitleaks` itself is
  invoked via PATH (not a store path) since PATH already tracks the
  current generation.

## `~/.claude/{commands,skills,agents,hooks}` merge (`home/default.nix`)

- Built by merging `home/claude/<name>/` (all machines) with
  `hosts/<hostname>/claude/<name>/` (this machine only, if present) at the
  file level — host-specific files win on a name collision.
- This is a file-level `home.file` mapping, not a directory symlink, so
  **new files added under either directory need a rebuild to show up**
  (files edited in place update immediately, like any other
  `mkOutOfStoreSymlink` target).
- `~/.claude/settings.json` and `~/.claude/CLAUDE.md` are exempt from this
  merge — each is handled as a single file instead (see below).

## `~/.claude/settings.json` (`hosts/MacBookPro-minami/home.nix`)

- Kept as a real file, not a symlink: Claude Code itself writes to this
  file (`/model`, `/plugin`, `/config`, runtime-added permissions, plugin
  configs). A repo-tracked symlink would turn every runtime write into an
  uncommitted git diff; a Nix-store symlink would make writes fail outright
  (the store is read-only).
- Instead, `home.activation.claudeSettings` jq-merges the repo's
  `claude/settings.json` on top of whatever's already on disk, on every
  rebuild: keys declared in the repo win (and revert on the next rebuild
  if changed at runtime); keys not declared in the repo (e.g. plugin-added
  config) are left alone.

## `~/.claude.json` `mcpServers` merge (`hosts/MacBookPro-minami/home.nix`)

- `~/.claude.json` also holds Claude Code's own mutable runtime state
  (project history, trust decisions), so it's never linked wholesale —
  only the `mcpServers` key is jq-merged in on activation.

## `herdr-nix` flake input

- herdr isn't packaged in nixpkgs, so `flake.nix` pulls it from its
  official flake (`herdr-nix`) instead of building from source. `herdr-nix`
  is a thin wrapper that just fetches herdr's prebuilt binary via Cachix
  with hash verification — the Cachix cache config itself lives in
  `darwin.nix`'s `nix.extraOptions`.

## `flake.nix` host wiring

- `optionalHostFile` lets a host directory omit `darwin.nix`/`home.nix`
  entirely (only `default.nix` is required): evaluation just skips modules
  for files that don't exist, so a new bare-minimum host needs no stub
  files.

## zsh XDG migration (`home/default.nix`)

- `programs.zsh.dotDir = "${config.xdg.configHome}/zsh"` moves zsh's config
  files off `$HOME`, ahead of home-manager's own default changing to this
  in a future release. home-manager handles the `ZDOTDIR` bootstrap itself
  (writes `~/.zshenv` to source `$ZDOTDIR/.zshenv`) — no manual `ZDOTDIR`
  wiring needed.
- `programs.zsh.history.path` is pinned to `${config.home.homeDirectory}/.zsh_history`
  (its own pre-migration default) rather than following `dotDir`, so
  existing shell history isn't orphaned at the old path. Don't remove this
  override without also handling the existing history file.
