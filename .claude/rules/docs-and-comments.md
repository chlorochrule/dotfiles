# Where explanations go

Applies to every file in this repo (no `paths:`, so always loaded).

## Code comments stay terse

- A comment is at most a line or two, and only where the code would look
  wrong or arbitrary without it (e.g. a `lib.mkForce`, a non-default port,
  a deliberately disabled option).
- Don't restate what the code says, narrate the change history, or record
  measurements, verification steps or rejected alternatives in comments.
- No "see .claude/rules/..." pointers just to point: the matching rules
  file loads automatically when the file is read.
- Exceptions: the "Committed directly (not terraform-managed)" header line
  that `CLAUDE.md` refers to, functional comments (shebangs,
  `shellcheck disable`, `CHANGEME`), usage headers of standalone scripts,
  and generated files (`home/claude/hooks/herdr-agent-state.sh`,
  `.editorconfig`).

## Rationale and caveats go in `.claude/rules/`

- Why a setting was chosen, what was measured or verified, what breaks if
  it's changed, and what was considered and declined all go in the
  `.claude/rules/<area>.md` whose `paths:` covers the file, as a
  `## topic (\`file\`)` section.
- If no rules file covers the file, add one with a `paths:` frontmatter
  that does. Check the globs actually match the file, or the note never
  loads.
- When changing a setting, update or delete its rules section in the same
  change so the two don't drift.

## README.md stays slim

- `README.md` (and `services/README.md`) hold only what a person needs to
  act: setup steps, everyday commands, and user-facing caveats (things
  that delete data, need a manual step, or revert on rebuild).
- No rationale or background there; mention that it lives in
  `.claude/rules/` instead. Keep each caveat to a sentence or two.
