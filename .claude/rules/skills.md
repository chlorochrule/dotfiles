---
paths:
  - ".claude/skills/**"
---

# .claude/skills/ background

`.claude/skills/` can hold two kinds of entries:

- Git-tracked skills meant for anyone who clones this repo (e.g.
  `upgrade-services`) — these are for working on the dotfiles repo itself.
- Personal, non-public skills the author uses only locally while working in
  this repo (e.g. `japanese-tech-writing`, a prose style guide). These are
  deliberately listed in `.gitignore` and never committed, even though the
  repo itself is public — see commit `31a2e29` for the reasoning. Finding a
  skill directory that isn't tracked by git is expected, not a mistake to
  fix.
