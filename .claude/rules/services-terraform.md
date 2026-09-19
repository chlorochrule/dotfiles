---
globs: "services/**, terraform/**"
---

# services/ and terraform/local/ background

Context for working on the local Langfuse/Grafana/Prometheus stack
(`services/*/docker-compose.yml`, `terraform/local/*.tf`). Human-facing
setup/operation docs are in the repo README; this is the "why" behind
choices that aren't obvious from the code itself.

## Architecture

- Three independent docker-compose projects (langfuse, grafana, prometheus).
  No shared Docker network by design.
- Cross-service communication goes through `host.docker.internal`, provided
  by Rancher Desktop (also reaches 127.0.0.1-only host services, e.g. the
  node_exporter on the host).
- Never add `extra_hosts` to override `host.docker.internal`: on Linux-style
  overrides it resolves to the bridge gateway IP instead, which can't reach
  127.0.0.1-only services. This has bitten this setup before.
- Host metrics reach Prometheus via a node_exporter installed directly on
  the host (`hosts/MacBookPro-minami/darwin.nix`, launchd daemon), not a
  container: a container can't see true host CPU/memory/disk metrics. See
  `.claude/rules/nix-hosts.md` for the launchd-specific quirk this hits.

## Langfuse image pinning

- `langfuse`, `langfuse-worker`, `redis`, `postgres`, `clickhouse` are pinned
  to exact versions instead of upstream's floating tags (`:4`, `:7`, `:17`,
  `:25.12`), because the Grafana dashboards (`langfuse_grafana*.tf`) run raw
  SQL against ClickHouse's `events_core` table. An unannounced schema or
  behavior change on that table would silently break the dashboards.
- Bump these five via `.claude/skills/upgrade-langfuse` — it checks dashboard
  impact before bumping. Don't hand-edit the tags.
- `clickhouse` tracks the latest patch within the minor series upstream
  Langfuse verifies against; only move the minor series when upstream does.
- `minio` (`cgr.dev/chainguard/minio`) is deliberately left on `latest`:
  Chainguard's free tier only serves `latest` (versioned tags need a paid
  plan), and digest-pinning would mean it never gets security patches.

## Ports intentionally not published

- `postgres` (5432), `redis` (6379), ClickHouse's native protocol (9000):
  nothing on the host needs them — langfuse-web/worker reach them by
  in-network hostname — so they're left unpublished to avoid clashing with
  other local projects that default to the same ports.
- Prometheus's host port is 9095, not 9090: 9090 is already used by
  langfuse's minio (S3 API).

## ClickHouse `grafana_ro` user

- Grafana connects with a SELECT-only ClickHouse user, not the full-access
  user langfuse-web/worker use, so a bad dashboard or plugin bug can't
  corrupt or delete data.
- Defined via ClickHouse's `users.d` config file, not `CREATE USER`/`GRANT`
  SQL: the docker image's bootstrap user (`CLICKHOUSE_USER`) has no `ACCESS
  MANAGEMENT` privilege, so SQL-based user creation fails.
- Uses profile `readonly=2`, not `readonly=1`: `readonly=1` also blocks
  `SET` statements, which the Grafana ClickHouse plugin issues for session
  settings like `max_execution_time`.
- ClickHouse picks up `users.d` changes live via `config_reload_interval`
  (~2s) — no restart needed after rotating the password. The file still has
  to exist before first container creation (compose mounts it as a
  read-only file), which is what forces the `depends_on` ordering in
  `langfuse.tf`.

## Dashboards

- `langfuse_grafana.tf` / `langfuse_grafana_extra.tf` reproduce Langfuse's
  own dashboards (Home / Agent / Cost / Latency) as raw SQL against
  `events_core` (Langfuse v4's OTel span table). Verified via
  `/api/ds/query` to match the numbers shown in the Langfuse UI.
- Deliberately excluded: Scores panels (no score data in this project),
  most of Usage Management (duplicates the Traces/Observations stats
  already covered), Time To First Token / output-tokens-per-second
  (`completion_start_time` is never recorded — the Langfuse UI itself
  always shows "No data" for these).
- `prometheus_grafana.tf`'s PromQL targets macOS's node_exporter field set
  specifically: no `/proc`, so CPU has no `iowait`/`irq` modes, and memory
  uses `wired`/`active`/`compressed`/`free`/`purgeable` instead of Linux's
  `available`/`buffers`/`cached`. Written against the actual output of
  `127.0.0.1:9100`, not the Linux docs — verify against that endpoint
  before changing these queries.

## docker-compose lifecycle (the `terraform_data` pattern)

- `langfuse.tf` / `grafana.tf` / `prometheus.tf` each drive their compose
  file via a `terraform_data` resource that shells out to
  `docker compose up -d --wait` on create and `docker compose down` on
  destroy. The compose file itself stays plain Docker Compose YAML — not
  reimplemented as Terraform resources — so it can keep tracking upstream's
  compose file directly.
- The destroy-time provisioner can only read values through
  `self.triggers_replace`, not top-level resource/local references, which
  is why each file threads its working directory through
  `triggers_replace` instead of referencing it directly.

## Grafana provider auth

- Uses HTTP basic auth (`admin:<generated password>`), not an API
  key/service account token: `grafana_user` (needed for cross-org user
  management) doesn't work with token auth.
