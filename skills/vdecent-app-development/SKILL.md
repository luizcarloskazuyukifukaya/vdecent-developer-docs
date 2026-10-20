---
name: vdecent-app-development
description: Use when building, scaffolding, or updating an application deployed to V-Decent Virtual Distributed Infrastructure (App Manager / Coolify), or when a docker-compose deployment "ran fine locally but failed on App Manager". Applies to any AI agent harness.
---

# V-Decent App Development

Develop applications that are testable, registerable, handed over, and
deployed through V-Decent Distributed Infrastructure (Docker Compose +
Coolify orchestration + V-Decent Application Manager) from the first line of
code. Harness-agnostic: this skill works as a system brief for any AI coding
agent.

## When to Use

Use when starting or updating an application project intended to run on
V-Decent, or when asked to fix compatibility in an existing V-Decent app.

Not for: operating already-deployed apps, node/DNS work, or App Manager
administration — use the vdecent-support skill for those.

## Non-Negotiable Rules

1. **Manifest name is exactly `docker-compose.yaml`** at repository root.
2. **No host port mappings** in the production manifest — use `expose:`
   only. A `ports:` entry fails App Manager deployment even though
   `docker compose up` works locally. Local convenience goes in separate
   override files, never in the production manifest.
3. **No network definitions, period.** No top-level `networks:` section, no
   per-service `networks:` entry, no joining external networks. A network
   block is valid Compose and starts locally, then breaks Coolify/Traefik
   proxy routing at registration — the single most common "worked locally,
   failed on App Manager" cause.
4. **Exactly one public-facing service** unless specified otherwise, with the
   `coolify.managed=true` label so Coolify attaches its managed network.
   Internal services (db, redis, worker, sidecar) are never exposed.
5. **Environment variables:** commit an unpopulated, documented
   `.env.example`; never commit real secrets.
6. **Health:** the application exposes `GET /health` returning 200; storage
   and caching services have explicit Docker healthchecks; compute services
   depend on them with `condition: service_healthy`.

Local success is never evidence of App Manager compatibility. The dev/local
override files legitimately add `ports:`, which masks a violation still
present in the base manifest.

## Workflow

1. **Collect the App Manager form** — application name, shortname/subdomain,
   target URL, application type (STATELESS | STATEFUL_EXTERNAL_DATA |
   STATEFUL_WITH_LIMITED_INTERNAL_DATA), purpose, technology stack, primary
   exposed service, internal port, external storage / database / backup
   sidecar needs, repository visibility, git branch for deployment,
   developer group, GitHub account or organization. These are required at
   registration but not for design — proceed with whatever is known.
2. **Select and restate the Application Pattern** — A (Stateless),
   B (Stateful with external data), or C (Stateful storage with limitation)
   — and why, before generating any files.
3. **Scaffold the required structure:** `docker-compose.yaml` (production),
   `Dockerfile`, `.env.example`, `README.md`, `src/`,
   `docs/vdecent-handover.md`, plus local dev files `docker-compose.dev.yaml`,
   `launch-local.sh` (executable), and `validate-vdecent-compat.sh`
   (executable). `docker-compose.local.yaml` is generated at runtime.
4. **Local development setup:** launch-local.sh optionally initializes the
   database (`INIT_DB`), scans candidate host ports, detects the LAN IP,
   syncs `.env`, writes `docker-compose.local.yaml`, and starts both
   `-f` files together.
5. **App Manager registration — instruction to the developer:** the app's
   `.env` content must be copied into the AM app's **Environment
   Variables** when registering the app for deployment on V-Decent, so
   Coolify injects them into the running container.
6. **Pre-registration validation (required before stating done):**
- Run `validate-vdecent-compat.sh` against `docker-compose.yaml` **alone**
      — it must pass (no `ports:`, no `networks:`).
      Note: some Docker Compose versions (e.g. 5.x) inject the implicit
      `default` network into `docker compose config` output even on a
      compliant manifest. If the validation rejects a `networks:` key that
      was never declared, strip/ignore the injected `default` key before
      checking — the manifest fails only if a network is explicitly
      declared or any `ports:` mapping survives.
    - Smoke-test the production manifest with **no override files**:
     `docker compose -f docker-compose.yaml up -d --build`, then
     `docker compose -f docker-compose.yaml exec <public-service> curl -f http://localhost:<PORT>/health`.
     Tear down afterward.
7. **Sizing:** derive the hosting tier (S/M/L/XL) with the `vdecent-size`
   CLI against a representative workload when available; otherwise estimate
   using the VRU formula. Record tier, per-service limits (`cpus`,
   `mem_limit`, `memswap_limit: 0`, `mem_swappiness: 0`), and assumptions in
   `docs/vdecent-handover.md`. Never assign the full application limit to
   every service.
8. **Acceptance criteria:** walk the checklist below and report each box with
   evidence — `validate-vdecent-compat.sh` output and the smoke-test result —
   not verbal confirmation.

## References

Read `references/v3_2-prompt.md` before writing compose files and whenever a
rule would change deployment behavior. It contains the rationalization
tables countering the common `ports:`/`networks:` excuses, the recommended
Docker Compose baseline, the launch-local.sh template, local `.env`
conventions, and the validation script body.

**Conflict rule:** the reference file is authoritative. If SKILL.md and the
reference disagree, follow the reference.

## Acceptance Criteria

- [ ] Root `docker-compose.yaml` exists and uses `expose`, not `ports`.
- [ ] No network definitions anywhere in `docker-compose.yaml`.
- [ ] `coolify.managed=true` label on the public-facing service.
- [ ] Strict healthchecks on storage/cache services; `/health` endpoint present.
- [ ] `.env.example` committed, unpopulated, documented.
- [ ] `launch-local.sh` executable; `docker-compose.dev.yaml` present.
- [ ] `validate-vdecent-compat.sh` executable and passes against
      `docker-compose.yaml` alone; no-override smoke test confirmed `/health`.
- [ ] `docs/vdecent-handover.md` states tier and per-service limits.
