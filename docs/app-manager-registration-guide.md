# Registering and Deploying Your App in V-Decent App Manager

This guide tells **application developers** how registration and deployment
through the V-Decent App Manager (AM) work, and what information you must
provide so the platform can register and deploy your app. The registration
itself is performed by the V-Decent platform (a human operator or an
authorized V-Decent internal agent) — your job is to prepare the app and
supply the required inputs.

## Before you start (prerequisites)

Your app must already be V-Decent-compatible and in a Git repository:

- Repository root contains a `docker-compose.yaml` (production manifest) that
  passes the pre-registration checks — no host `ports:`, no `networks:`, uses
  `expose:`, has `coolify.managed=true` on the public service, exposes
  `GET /health`, and has its `.env.example` committed.
- The repository is pushed to GitHub under the GitHub account you will
  register with, on the deployment branch (usually `main`).
- If the app has no committed `.env`/`.env.example`, prepare the environment
  variable values to hand over (see Environment Variables below).

If you built the app with the V-Decent app-development skill, this is already
done and validated.

## Information you must provide

When registering, supply all of the following. If any item is missing, the
platform will ask for it — do not skip or guess.

| Requirement | What it is / example |
|---|---|
| **Project or repository** | The GitHub repository URL (e.g. `https://github.com/<account>/my-app`) or a local project path. The `docker-compose.yaml` at the repository root defines the app. |
| **Application name** | Human-readable display name, e.g. "Alvo Arte Site". |
| **Shortname / subdomain** | Short unique name that becomes the subdomain, e.g. `alvoarte` → `https://alvoarte.v-decent.org`. |
| **Target URL** | `https://<shortname>.v-decent.org` by default; confirm if you need a different domain. |
| **Application type / pattern** | How the app stores data: `STATELESS`, `STATEFUL_EXTERNAL_DATA` (data outside V-Decent), or `STATEFUL_WITH_LIMITED_INTERNAL_DATA` (data on a V-Decent volume inside Docker Compose). This is defined by your `docker-compose.yaml`. |
| **Technology stack** | e.g. Python, Node/Next.js, etc. |
| **Primary exposed service & internal port** | The Compose service that receives public traffic and the port it listens on internally (e.g. service `app`, port `8000`). |
| **External storage / database / backup needs** | Whether the app needs external storage, a database, or a backup sidecar. |
| **Repository visibility, branch, GitHub account** | `Public` or `Private`, the deployment branch (e.g. `main`), and the owning GitHub account. |
| **Developer Group** | The V-Decent developer group the app belongs to (e.g. "Sao Paulo Developers"). The platform resolves it on your behalf. |
| **Environment variables** | The `.env` content (or where to find it). See below. |
| **Email support** | Whether the app needs an email address (`email_enabled`). |
| **Owner inbox** | The private email that receives replies; must be verified. |
| **Email display name** | Name shown to recipients, defaulting to the app name. |

## Environment Variables

The platform copies your app's `.env` values into the app's **Environment
Variables** so they are injected into the running container:

- Use the repository's `.env` (or fill values from `.env.example`).
- **Local-only variables must be excluded.** V-Decent templates mark these with
  a `# ponytail: local dev only` comment in `.env.example` (for example a
  `HOST_PORT` used to reach the app in local development). Those never go to
  production.
- Keep secrets out of the repository: only the production values you hand over
  (or values already present in the environment) are used. Never commit real
  secrets to the repository or paste them where they can be recorded.

## Email address

If the app sends or receives email, the platform registers an email identity
for it. The default address is `contact-<shortname>@<app-domain>`, e.g.
`contact-alvoarte@v-decent.org`, with the local part following the
lowercase/dot/underscore/hyphen policy and avoiding reserved names.

- `email_status`, `email_approved_at`, and `email_approved_by` are
  server-managed. They are not registration inputs; only a global admin can
  activate an identity, and new registrations start in a safe pending or
  disabled state.
- You may change the local part on the existing app domain while it is free
  and not reserved. A local-part change resets the identity to
  `pending_destination`, so it cannot send until an operator reconciles and
  re-activates it.
- Any domain change, an address outside the app domain, or a custom domain
  requires V-Decent operator approval (custom domains also need DNS
  verification). A non-platform custom domain registered by a scoped user is
  marked `pending_domain` and cannot be activated without a global admin.
- The owner inbox that receives replies must be verified.

See `docs/app-email-guide.md` for the environment variables, the send API, and
the optional app-owned inbox contract.

## What happens when you register and deploy

1. **Registration** — the platform creates the application record with the
   inputs above: name, size category (hosting tier), shortname, hostname,
   repository, branch, developer group, GitHub account, the exposed-service
   mapping, and the environment variables. The app is created as
   `Registered`.
2. **Deployment resource** — the platform provisions the underlying deployment
   resource (built automatically from your `docker-compose.yaml`). You do not
   create this yourself.
3. **Deploy** — the platform triggers a deployment, which clones your
   repository, builds the container, and starts it with your environment
   variables injected.
4. **Verification** — the app is checked until healthy: status moves through
   `Deploying` → `Running` → `Healthy`, the container healthcheck and the
   app's own `GET /health` respond, and the public URL serves the site.

## After deployment

- Verify yourself once it is healthy: open `https://<shortname>.v-decent.org`,
  check the `/health` endpoint, and test the pages/routes.
- To update the app, push changes to the tracked branch and request a
  redeploy (or the configured auto-deploy will pick it up). A redeploy rebuilds
  the app on its current node; it is not moved to a "better" node for load
  balancing.
- The shortname is unique per environment — a second app cannot reuse it.

## If the hosting node goes offline

If an app's node stays offline past the platform's grace period (300 s by
default), the App Manager recreates the app on another eligible online node and
moves its public URL there; the old runtime is cleaned up once the replacement
is healthy and the old node is reachable again. This failover recreates
containers and routing only — it does **not** copy node-local Docker volumes or
bind-mounted data. Keep persistent data in external storage or maintain your own
backup and restore procedure if the app must survive a node replacement.

## Common questions

- **Can I choose the hosting size?** The platform classifies the app (S, M, L,
  XL) with the V-Decent sizing rules; you may be asked which tier you expect
  based on expected traffic.
- **What if my repository is private?** That is supported; provide the owning
  GitHub account so the platform can clone it with the proper credentials.
- **Who performs the registration?** V-Decent platform operators (or an
  authorized V-Decent internal agent). As a developer you supply the inputs
  and verify the result.
