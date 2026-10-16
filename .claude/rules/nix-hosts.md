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

## Ollama from the official app, not nixpkgs (`hosts/MacBookPro-minami/darwin.nix`)

- Qwen3.8-27B runs as `qwen3.8:27b-nvfp4`, a safetensors model that
  Ollama serves through its MLX engine. nixpkgs' ollama is built with
  `-DOLLAMA_MLX_BACKENDS=""`, so pulling it fails with "this model
  requires MLX support, but the MLX runtime is not available". Only the
  official build ships MLX (`mlx_metal_v3`/`v4` with `mlx.metallib`),
  hence the `ollama-app` cask instead of `services.ollama`.
- Measured on M5 Max at 256K context (Ollama 0.34.3), against the
  previous `qwen3.8:27b` (GGUF Q4_K_M, which is the same blob as
  `27b-mtp-q4_K_M`): decode ~43 vs ~21 tok/s, prefill ~470 vs ~270 tok/s
  at ~20K tokens and ~420 vs ~160-200 tok/s at ~80-95K, and 18.5 vs
  20.7GB loaded. Ollama 0.34.4 also runs MTP speculative decoding on it.
  Tool calls (pi and `/v1/messages`), thinking and image input work.
- The cask's binary path, not `ollama` on PATH, is used by the
  `ollamaContextModels` activation so it never falls back to a nixpkgs
  build; the activation is a no-op while the app isn't running.

## Ollama local LLM context window (`hosts/MacBookPro-minami/home.nix`)

- Ollama's default `num_ctx` is 4096. Claude Code's system prompt + tool
  definitions alone come close to that on their own (~4016 tokens
  measured), so with the default, the actual user instruction gets crowded
  out and Ollama-backed sessions start responding to unrelated content.
- Fix: a derived model (`*-262k`) created per base model via `ollama
  create` with `PARAMETER num_ctx 262144` (256K, both models' real trained
  context) baked in. This works the same for the nvfp4 (MLX) base:
  loaded by name with no options, it reports `context_length` 262144.
  This is deliberately *not* set server-wide via `OLLAMA_CONTEXT_LENGTH`
  (d17eed7): that would also force 256K context (and its memory cost)
  onto any other, smaller model later pulled into this same Ollama
  instance.
- pi caps Qwen3.8-27B at 64K anyway (`contextWindow: 65536` in
  `hosts/MacBookPro-minami/pi/models.json`; the Ollama-side `num_ctx`
  stays 262144 since it's only a ceiling and memory grows with use).
  Measured on Ollama 0.35.1 (nvfp4/MLX), a continued turn reuses the
  prefix cache and starts in <1s at any length, but anything that misses
  the cache re-prefills everything at ~280-400 tok/s: ~20s at 8K, ~90s
  at 32K, ~7.5min at 128K. pi's compaction (at contextWindow minus its
  16K reserve) is such a miss, as is an Ollama restart or a derived-model
  re-create. Decode also drops with depth (~20 tok/s at 8-32K, ~13 at
  128K). 64K keeps a miss or compaction to a few minutes.
- `CLAUDE_CODE_MAX_CONTEXT_TOKENS=256000` in the `claude-q38`/`claude-q3cn`
  zsh wrappers avoids Claude Code's "unrecognized_model" warning for model
  names outside its catalog — without it, auto-compact assumes 200k and
  can trigger at the wrong point.
- Memory footprint: ~18.5GB for Qwen3.8-27B (nvfp4), ~59GB for
  Qwen3-Coder-Next (both at 256K context).
- `OLLAMA_NUM_PARALLEL` is left unset: Ollama 0.34.3's GGUF engine runs
  these hybrid (linear-attention) models with a single slot regardless
  ("model architecture does not currently support parallel requests").
  Measured with `OLLAMA_NUM_PARALLEL=2` on Qwen3.8-27B Q4_K_M, before the
  switch to nvfp4/MLX (not re-measured there): two concurrent requests
  were still serialized and memory stayed ~20GB. So in auto mode the
  permission classifier (which also runs on the wrapper's model) queues
  behind the main request and re-prefills over its KV cache, and times
  out ("… is temporarily unavailable (timed out), so auto mode cannot
  determine the safety of …").
- `"WebSearch"` in `permissions.allow` (`hosts/MacBookPro-minami/claude/settings.json`)
  is the workaround chosen for that: an explicit allow rule lets WebSearch
  skip the classifier, while other actions keep going through it (and may
  still time out under the wrappers). Ollama's Anthropic-compatible API
  emulates the web_search server tool via https://ollama.com/api/web_search,
  which needs `ollama signin`; unsigned, the tool result is
  `web_search_tool_result` with error_code `unavailable`.
- These wrappers never affect the plain `claude` command (Anthropic's own
  service) — the env vars are wrapper-local.

## ComfyUI models: bf16/GGUF, not fp8 (`hosts/MacBookPro-minami/darwin.nix`)

- Comfy Desktop's templates default to fp8 weights (`flux2_dev_fp8mixed`,
  `mistral_3_small_flux2_fp8`). MPS has no fp8 compute path: checked
  with Comfy Desktop's PyTorch 2.12.1, an fp8 tensor can be moved to
  `mps` but upcasting it fails with "Trying to convert Float8_e4m3fn to
  the MPS backend but it does not have support for that dtype". So the
  FLUX.2 text encoder uses the bf16 file.
- Qwen-Image 2.1's templates default to `int8_convrot` files. Those
  weren't tried on MPS; bf16 was picked simply because it fits in 128GB.
- FLUX.2 [dev]'s own bf16 weights are 64GB and gated (license accept +
  HF token), so it runs as city96's `flux2-dev-Q8_0.gguf` (35GB,
  ungated) through the ComfyUI-GGUF custom node.
- Measured on M5 Max at 1024²: Qwen-Image 2.1 bf16, 25 steps, ~285s
  cold (including model load). FLUX.2 Q8_0 with the Turbo LoRA, 8 steps,
  ~165s cold; then 20 steps without the LoRA ~430s warm (models already
  resident, so ~20s/step).
- Memory: after the FLUX.2 runs ComfyUI's free memory had dropped from
  ~108GB to ~61GB (~47GB kept resident). The two FLUX.2 files total
  ~71GB, so the peak is presumably higher; running it next to Ollama's
  large models (~50GB loaded at the time) wasn't tried — Ollama was
  stopped first.

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

## `nix-index-database` flake input

- Provides the prebuilt nix-index database (updated weekly upstream) for
  `,` (comma) and zsh's command-not-found handler. Running `nix-index`
  locally instead would take a long, CPU-heavy indexing pass per update.
- Wired via `home-manager.sharedModules` in `flake.nix` so every host gets
  the module; each host still opts in through `programs.nix-index` /
  `programs.nix-index-database.comma` in `home/default.nix`.
- Don't also add `nix-index` to `home.packages`: the module's wrapper
  (which points at the prebuilt database) would conflict with it.
- `,` and `nh` talk to the nix daemon, so they're in the Claude Code
  sandbox's `excludedCommands` along with `nix` (see README).

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

## `home.packages` notes (`home/default.nix`)

- `ripgrep`/`fd`/`bat` are what fzf-lua uses for grep/files/preview;
  `nixfmt`/`stylua`/`terraform` are conform.nvim's format-on-save tools;
  `shellcheck` is also used by bashls in nvim. Removing any of them breaks
  the nvim side silently.
- `google-cloud-sdk.withExtraComponents`: nixpkgs disables gcloud's own
  component manager, so `gcloud components install` doesn't work. Extra
  components (currently `gke-gcloud-auth-plugin`, which kubectl needs for
  GKE auth) must be declared here.
- The herdr zsh completion is generated at build time with `runCommand`
  because herdr-nix's package ships none, and `eval "$(herdr completion
  zsh)"` would run on every shell start.
- `ast-grep` is for syntax-aware rewrites where a regex would also hit
  strings and comments.

## Shell/tool programs (`home/default.nix`)

- `programs.nh`: `nh darwin switch` wraps darwin-rebuild with
  nix-output-monitor and a diff of what changes. `nh clean` isn't enabled
  because `darwin.nix`'s `nix.gc` already does periodic GC.
- `programs.direnv`: used by `services/*/.envrc` to load per-directory
  `.env` files; `nix-direnv` gives a cached, GC-rooted `use flake`.
- zsh `bindkey '^U' backward-kill-line`: zsh's default kills the whole
  line; this makes it readline-style (only before the cursor).
- uv/uvx completions are added with `lib.mkOrder 1500` so they run after
  mise activates, and are guarded with `command -v` because uv isn't on
  PATH before mise's first install (it'd print "command not found" on
  every shell start otherwise).
- `home.activation.herdrReloadConfig` reloads a running herdr server's
  config after a rebuild; it's a no-op when no server runs.

## git settings (`home/default.nix`)

- The block from `column.ui` on follows "How Core Git Developers Configure
  Git" (GitButler blog), minus settings that delete data
  (`fetch.pruneTags`) or change pull behavior.
- difftastic is used alongside delta, not instead of it: `git dft`/`dlog`/
  `dshow` set `diff.external=difft` per invocation, so plain `git diff`
  still goes through delta. `log`/`show` ignore `diff.external` without
  `--ext-diff`, hence the flag in those aliases.
  `programs.difftastic.git.enable` is left off because it would set
  `diff.external` globally and replace delta. `diff.colorMoved = "plain"`
  is because delta renders moved lines distinctly.

## Ghostty (`home/default.nix`)

- `package = null`: the app comes from the Homebrew cask; Nix only writes
  the config.
- `scrollback-limit` is 1GB, which is lazily allocated, i.e. effectively
  unlimited. `link-url = true` is Ghostty's default, set explicitly.
- `shell-integration-features = "ssh-env"` sends `TERM=xterm-256color`
  over ssh, since remotes lack xterm-ghostty's terminfo. `ssh-terminfo`
  is deliberately off: it installs that terminfo into the remote's
  `~/.terminfo`, i.e. writes files on hosts that may not be the user's.
  Listing only `ssh-env` leaves unlisted features at their defaults.

## Host packages and pi (`hosts/MacBookPro-minami/`)

- `pi-coding-agent` is overlaid from `nixpkgs-unstable` in `darwin.nix`:
  upstream releases every few days, and the release branch lags a dozen
  minor versions behind. That's the only reason the `nixpkgs-unstable`
  flake input exists.
- `playwright-test`/`playwright-mcp` are host-specific (this machine's
  browser automation / DevTools use).
- pi reads the same Ollama models through Ollama's OpenAI-compatible
  endpoint (`pi --model ollama/<id>` or `/model`). pi never writes
  `models.json`, so a read-only store link is fine; `settings.json` and
  `auth.json` stay pi-managed. `pi/web-search.ts` (a `web_search` tool
  backed by DuckDuckGo, no API key) is documented in its own header.

## Claude Code MCP servers (`hosts/MacBookPro-minami/home.nix`)

- `chrome-devtools-mcp` isn't in nixpkgs, so it runs via `npx` on
  `@latest`, accepting the Chrome DevTools team as a trusted but unpinned
  upstream.
- `context7` uses Upstash's hosted endpoint (no local code runs) without an
  API key, so it's on the anonymous rate limit.
- `playwright` uses the Nix store binary of `playwright-mcp`.

## Casks (`hosts/MacBookPro-minami/darwin.nix`)

- `cmd-eikana` (⌘英かな: left/right Command → 英数/かな) comes from the
  `dominion525/tap` arm64 fork. The homebrew-cask `cmd-eikana` is a
  different upstream (iMasanari's, last released 2017, Intel-only) and was
  disabled in September 2026 for failing the Gatekeeper check.
- `ollama-app` runs `ollama serve` on 127.0.0.1:11434 while the app is
  open (see the Ollama sections above for why not nixpkgs).
- node_exporter runs as a nix-darwin launchd daemon, not a container (a
  container can't see true host metrics) and not via home-manager (no
  darwin launchd module for it). It listens on 127.0.0.1 only; Prometheus
  reaches it via `host.docker.internal`.

## macOS settings (`darwin.nix`)

- `nix.optimise.automatic` (scheduled) instead of
  `nix.settings.auto-optimise-store`, which has known store-corruption
  issues on macOS.
- `allowUnfreePredicate` lists `terraform` because it's BSL 1.1.
- `security.pam.services.sudo_local`: Touch ID for sudo, falling back to a
  password on Macs without it. `reattach` is needed for Touch ID to work
  inside herdr (a multiplexer).
- `system.keyboard.remapCapsLockToControl` is applied with `hidutil`
  without `--matching`, so it covers every keyboard (unlike System
  Settings' per-device Modifier Keys), both on rebuild and at boot via
  nix-darwin's activate-system daemon.
- `"com.apple.keyboard.fnState" = true`: F1-F12 send function keys; media
  controls need fn. `hitoolbox.AppleFnUsageType`: the globe/fn key
  switches input source instead of opening the emoji picker (takes effect
  after a restart).
- `com.apple.symbolichotkeys` is merged with hosts' entries and written as
  one whole dict, so hotkeys changed only in System Settings revert to
  default on rebuild — declare them here instead. Hotkey 27 (move focus to
  the next window of the same app) is Option+Tab; its parameters are ASCII
  code (65535 = none), virtual keycode (48 = Tab), modifier mask
  (524288 = Option). `postActivation` runs `activateSettings -u` so the
  changes apply without logging out.
- Homebrew: `cleanup = "zap"` uninstalls undeclared casks (`brew bundle
  --zap --force-cleanup`). `greedyCasks` also upgrades casks that update
  themselves (`auto_updates`) or are unversioned (`version :latest`),
  which `brew bundle` skips otherwise.
