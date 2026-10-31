---
name: vdecent-app-deployment
description: Use when registering a new or existing application for deployment through V-Decent App Manager (Coolify) — collecting the required registration inputs from the developer, creating the App Manager application, copying the .env environment variables, triggering the deploy, and verifying the public URL.
---

# V-Decent App Deployment (via App Manager)

Register and deploy applications through V-Decent App Manager. This is the
registration/deployment companion to `vdecent-app-development` (which builds
the app and validates V-Decent compatibility): use this skill once the app's
repository is ready to be deployed.

## Environment gate

Pick exactly one environment before any API call; never mix credentials or
resources across them.

| | Development/PoC | Production |
|---|---|---|
| App Manager API | `https://am-api-dev.v-decent.org` | `https://am-api.v-decent.org` |
| Coolify project | `V-Decent Project Development` (`htb5fvtz30yyj3kmkgpy0e48`) | `V-Decent Project Production` (`rt43u6zclfay6zx1k5p0ct26`) |

Default to Development/PoC only when the user omits the environment and the
app is not production-bound. Treat every result as scoped to the selected
project — never fall back to the other project.

## Required inputs — ASK BEFORE registering

Collect all of these from the developer before any API call. If any is
missing, stop and ask; do not guess.

1. **Project directory** (local path) or **GitHub repository URL** — the
   source of the `docker-compose.yaml`.
2. **Developer Group name** — resolved to an id via `GET /api/developers`
   (match by `name`, use the returned `id`).
3. **App shortname** — becomes the subdomain and Coolify application name.
4. **Target URL** — default `https://<shortname>.v-decent.org`; confirm with
   the user if a different domain is intended.
5. **GitHub account** — the owner of the repository.
6. **`.env` content** — read from the repository's `.env` (or
   `.env.example`) if present; otherwise ask the developer to provide it.

## Registration and deployment

1. **Resolve the developer group**: `GET /api/developers` → match the group
   name → `id`.
2. **Pre-check** (read-only): `GET /api/applications` → confirm the shortname
   is not already registered.
3. **Confirm the mutation** with the user (environment + shortname + URL)
   before registering.
4. **Register**: `POST /api/applications` (payload below) → returns the app
   record including its `id`.
5. **Deploy**: `POST /api/applications/{id}/deploy` → HTTP 200 means the
   deployment was enqueued, not that it is live.
6. **Verify** (see Verification).

### Registration payload (`POST /api/applications`)

| Field | Value |
|---|---|
| `name` | Display name (human readable) |
| `category` | Hosting tier size: `Small` (S), `Medium` (M), `Large` (L), `XL` |
| `shortname` | Subdomain, e.g. `alvoarte` |
| `fqdn` | Hostname **without scheme**, e.g. `alvoarte.v-decent.org` |
| `repo_url` | `https://github.com/<account>/<repo>` (no `.git` suffix) |
| `repo_type` | `Public` or `Private` |
| `branch` | Git branch, e.g. `main` |
| `developer_group_id` | Integer id from step 1 |
| `github_account` | Repository owner account |
| `base_directory` | `/` |
| `docker_compose_path` | `./docker-compose.yaml` |
| `service_mappings` | `{"<compose-service>": "https://<shortname>.v-decent.org"}` |
| `env_vars` | Multiline `KEY=VALUE` string (see below) |
| `financial_model` | `none` (default) |
| `is_test_mode` | `false` |

Example (verified working, Development/PoC):

```json
{
  "name": "Alvo Arte Site",
  "category": "Small",
  "shortname": "alvoarte",
  "fqdn": "alvoarte.v-decent.org",
  "repo_url": "https://github.com/luizcarloskazuyukifukaya/alvoarte-site",
  "repo_type": "Private",
  "branch": "main",
  "developer_group_id": 3,
  "github_account": "luizcarloskazuyukifukaya",
  "base_directory": "/",
  "docker_compose_path": "./docker-compose.yaml",
  "service_mappings": {"app": "https://alvoarte.v-decent.org"},
  "env_vars": "PORT=8000\nSQLITE_PATH=/data/alvoarte.db",
  "financial_model": "none"
}
```

Notes:
- The **application pattern** (STATELESS / STATEFUL_EXTERNAL_DATA /
  STATEFUL_WITH_LIMITED_INTERNAL_DATA) is defined by the repository's
  `docker-compose.yaml`, not by the registration payload. `category` is the
  hosting **size** only.
- Coolify creates the application resource automatically from this
  registration — do not create the Coolify app manually.

## `.env` → environment variables

- Copy the production-relevant `KEY=VALUE` lines from the repository `.env`
  into `env_vars` (one per line).
- **Exclude explicitly local-only variables** — in V-Decent templates those
  are flagged with `# ponytail: local dev only` in `.env.example` (e.g.
  `HOST_PORT`). Never copy a local host port into production.
- Never print, log, or echo environment variable **values** (secrets,
  tokens, passwords): report key names only and confirm presence.

## Verification

- `GET /api/applications/{id}` → status transitions `Registered → Deploying
  → Running → Healthy` (and `has_ever_been_healthy: true`).
- Coolify application (`GET /api/v1/applications` from `coolify.v-decent.org`
  with `COOLIFY_API_TOKEN`) → the shortname's container reports
  `running:healthy`.
- Environment variables: the Coolify app env list contains the expected key
  names (`PORT`, `SQLITE_PATH`, ...).
- Public URL: `GET https://<fqdn>/health` → 200; the home page serves; SPA
  routes return 200. If the app exposes a locale/config endpoint, confirm it
  returns the intended default.

## Common mistakes

- `fqdn` must be hostname-only; the full `https://` URL belongs in
  `service_mappings`.
- Treating `POST /api/applications/{id}/deploy` 200 as "deployed" — it only
  enqueues; poll the status until Healthy.
- Registering without the developer group id (integer, from `GET
  /api/developers`).
- Copying local-only `.env` values into production environment variables.
- Printing `env_vars` or Coolify env values in chat/output.
