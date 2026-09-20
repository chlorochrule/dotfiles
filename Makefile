# The checks .github/workflows/check.yml runs, one target per CI step (CI
# calls these targets, so local and CI runs stay the same). `make check`
# runs them all; tools come from flake.lock's nixpkgs via --inputs-from.

# $(CURDIR), not ".": some recipes cd into terraform/local first.
NIX_RUN := nix run --inputs-from $(CURDIR)
# terraform is BSL 1.1 (unfree). \# because # starts a comment here.
TERRAFORM := NIXPKGS_ALLOW_UNFREE=1 $(NIX_RUN) --impure nixpkgs\#terraform --

CHECKS := flake-check eval nixfmt stylua terraform-fmt editorconfig shellcheck actionlint \
	terraform-validate claude-settings schemas test gitleaks

.PHONY: check fmt $(CHECKS)

check: $(CHECKS)

# Applies the formatting that nixfmt/stylua/terraform-fmt below check for.
fmt:
	git ls-files -z '*.nix' | xargs -0 $(NIX_RUN) nixpkgs#nixfmt --
	git ls-files -z '*.lua' | xargs -0 $(NIX_RUN) nixpkgs#stylua --
	$(TERRAFORM) fmt -recursive terraform/

flake-check:
	nix flake check

# flake check doesn't evaluate darwinConfigurations deeply; forcing each
# host's drvPath catches option/typo errors a rebuild would hit.
eval:
	nix eval --json .#darwinConfigurations --apply 'builtins.mapAttrs (_: c: c.system.drvPath)'

nixfmt:
	git ls-files -z '*.nix' | xargs -0 $(NIX_RUN) nixpkgs#nixfmt -- --check

stylua:
	git ls-files -z '*.lua' | xargs -0 $(NIX_RUN) nixpkgs#stylua -- --check

terraform-fmt:
	$(TERRAFORM) fmt -check -recursive terraform/

# Catches broken references (undefined locals/resources) that fmt can't.
# -backend=false: only fetches providers, never touches the local state.
terraform-validate:
	cd terraform/local && $(TERRAFORM) init -backend=false -input=false >/dev/null
	cd terraform/local && $(TERRAFORM) validate

editorconfig:
	$(NIX_RUN) nixpkgs#editorconfig-checker

shellcheck:
	git ls-files -z '*.sh' bin/license | xargs -0 $(NIX_RUN) nixpkgs#shellcheck --

actionlint:
	$(NIX_RUN) nixpkgs#actionlint

# Claude Code settings files against schemastore's (strict) schema: catches
# misspelled keys, which Claude Code itself would silently ignore.
claude-settings:
	git ls-files -z .claude/settings.json 'hosts/*/claude/settings.json' \
		| xargs -0 $(NIX_RUN) nixpkgs#check-jsonschema -- \
		--schemafile https://json.schemastore.org/claude-code-settings.json

# docker-compose files and dependabot.yml against check-jsonschema's
# bundled schemas (workflows are covered by actionlint).
schemas:
	git ls-files -z 'services/*/docker-compose.yml' \
		| xargs -0 $(NIX_RUN) nixpkgs#check-jsonschema -- --builtin-schema vendor.compose-spec
	$(NIX_RUN) nixpkgs#check-jsonschema -- --builtin-schema vendor.dependabot .github/dependabot.yml

# guard-bash.sh (PreToolUse hook) and statusline.sh regression tests.
test:
	tests/claude-scripts.sh

# Scans the whole history (CI checks out with fetch-depth: 0).
gitleaks:
	$(NIX_RUN) nixpkgs#gitleaks -- git --redact
