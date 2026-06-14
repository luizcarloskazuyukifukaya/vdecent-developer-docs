# **V-Decent AI Coding Agent Project Prompt**

**Prompt version:** 2.3  
**Based on:** V-Decent Application Development Guide (en, V2\_3) and V-Decent Node Network Architecture & Developer Integration Guide V2\_3  
**Audience:** Human developers using AI coding agents such as Codex, Gemini CLI, Claude Code, Cursor, or similar tools.  
Use this prompt when starting or updating an application project intended to run on **V-Decent Virtual Distributed Infrastructure**, also called **V-Decent**.

## ---

**Prompt to Give the AI Coding Agent**

You are an expert full-stack application developer. Build this application so it can be developed, tested, registered, handed over, and deployed through **V-Decent Virtual Distributed Infrastructure**.  
V-Decent is a distributed datacenter hosting environment that uses **Docker Compose**, **Cloudflare Tunnels**, **Coolify orchestration**, a shared ingress network, and the **V-Decent Application Manager**. The application must be compatible with V-Decent deployment rules from the beginning.  
Your job is to create production-ready application code, repository structure, Docker configuration, environment-variable templates, local test instructions, and deployment handover notes.  
The project must follow the V-Decent Application Development Guide **V2\_3** and the V-Decent Node Network Architecture & Developer Integration Guide V2\_3.

## ---

**Application to Build**

Replace the placeholders below before starting:  
`Application name: <APP_NAME>`  
`Primary shortname / subdomain: <APP_SHORTNAME>`  
`Target production URL: https://<APP_SHORTNAME>.v-decent.org`  
`Application type: <STATELESS | STATEFUL_EXTERNAL_DATA | STATEFUL_WITH_LIMITED_INTERNAL_DATA>`  
`Main application purpose: <DESCRIBE_THE_APP>`  
`Technology stack preference: <NODE/EXPRESS | NEXT.JS | PYTHON/FASTAPI | OTHER>`  
`Primary exposed service/container: <SERVICE_NAME>`  
`Internal application port: <PORT>`  
`External storage required: <YES/NO>`  
`Database required: <YES/NO>`  
`Backup sidecar required: <YES/NO>`  
`Repository visibility: <PUBLIC | PRIVATE>`  
`Git branch for deployment: <BRANCH_NAME>`  
`Developer group: <DEVELOPER_GROUP>`  
`GitHub account or organization: <GITHUB_ACCOUNT_OR_ORG>`

## ---

**Non-Negotiable V-Decent Compatibility Rules**

The repository must be compatible with V-Decent Application Manager and Coolify deployment.

### **1\. Docker Compose Is Required**

Create a file named exactly:  
`docker-compose.yaml`  
Do not use a different file name such as docker-compose.yml, compose.yaml, or docker-compose.prod.yaml as the only deployment manifest. The Docker Compose file must define every service needed by the application.

### **2\. Do Not Use Host Port Mapping in the Primary Manifest**

Do **not** map, expose, or bind physical port configurations directly to the host network interface (e.g., avoid ports: "8080:80"). Direct bindings create network conflicts across multi-tenant nodes. All inbound ingress routing paths are dynamically managed and isolated by Coolify proxy instances.  
Use the expose array parameter to identify internal networking endpoints. This alerts upstream container bridges where application traffic is listening.  
Use this pattern:  
`services:`  
  `app:`  
    `build: .`  
    `restart: always`  
    `expose:`  
      `- "80"`  
    `environment:`  
      `- PORT=80`  
For local-only testing, host port mapping may be placed in a separate override file such as docker-compose.local.yaml. The main docker-compose.yaml must remain V-Decent compatible and must not depend on host port mappings.

### **3\. Native Network Isolation (Do Not Hardcode External Networks)**

Define internal-only software bridge networks (e.g., external-tier, internal-tier) within the application manifest. **Do not** hardcode reference configurations to global external networks like vdecent-ingress. Manual overrides referencing hardcoded external hosts are strictly prohibited as they break the platform's proxy-to-container resolution mechanism, resulting in a persistent 503 Service Unavailable fault.  
Developers must let Coolify manage the public network path natively. Web and database components must be split across logical, software-defined tiers. When a stack is initialized, Coolify reads the required platform labels and automatically maps its orchestrator-managed proxy network layer directly to the web service container.  
`services:`  
  `app:`  
    `build: .`  
    `restart: always`  
    `expose:`  
      `- "80"`  
    `networks:`  
      `- external-tier`  
    `labels:`  
      `- "coolify.managed=true"`

`networks:`  
  `external-tier:`  
    `driver: bridge`  
Internal services such as databases, workers, queues, and backup sidecars must remain completely isolated on their own backend networks (e.g., internal-tier) to ensure secure, zero-trust host execution.

### **4\. Exactly One Public-Facing Service Unless Specified Otherwise**

Identify which service should be exposed by V-Decent Application Manager. Most applications should expose only the main web/API container, for example:  
`Expose: app -> https://<APP_SHORTNAME>.v-decent.org`  
`Do not expose: db, redis, worker, backup-sidecar, internal services`  
If a service should not be reachable from the internet, its URL field must be left empty during V-Decent Application Manager registration.

### **5\. Environment Variables Are Required**

Isolate all secrets, connection tokens, and environment parameters into standard .env configurations. Provide an unpopulated, fully documented reference profile named exactly:  
`.env.example`  
The .env.example file must list all required variables with safe sample values or clear placeholders. Never commit real production secrets.  
Also provide a separate section in the README called **Production Environment Variables** explaining which values must be supplied to V-Decent Application Manager during registration.

### **6\. Liveness & Readiness Probes (Health Checks)**

Integrate explicit Docker engine healthcheck routines for all downstream data storage systems and caching daemons to confirm initialization status before compute workers begin boot cycles. The application should expose a lightweight health endpoint:  
`GET /health`  
The health endpoint should return HTTP 200 when the application is ready to receive traffic.

## ---

**Supported Application Types and Data Persistence Rules**

V-Decent supports three application patterns. Choose one explicitly and document it in the README and handover document.

### **Pattern A — Stateless Compute Services**

Use this when the app does not store persistent data inside the container or in V-Decent-managed storage (e.g., API gateways, frontend web applications, background worker microservices, and chronological task processors).

### **Pattern B — Stateful Application with External Data**

Use this when the app stores data outside V-Decent, such as AWS S3, Wasabi, a managed database, or another external storage system.

### **Pattern C — Stateful Storage Services, Supported with Limitation**

Use this when a relational/non-relational database, persistent data caching node, or structured file queue utilizing platform-managed underlying storage volumes is included in Docker Compose.  
Requirements:

* Map data to discrete Docker volumes.  
* Keep databases and internal services isolated on an internal bridge network (internal-tier).  
* Add database health checks and ensure compute services use depends\_on with condition: service\_healthy.  
* Include a backup sidecar container if data persistence and point-in-time restore to external storage (like Google Drive) are required.

## ---

**Recommended Docker Compose Baseline for V-Decent V2\_3**

Use this as the baseline structure for applications with a public app service and an isolated internal database:  
`services:`  
  `app:`  
    `build: .`  
    `restart: always`  
    `environment:`  
      `- DATABASE_URL=postgres://user:password@db:5432/activitylog`  
    `expose:`  
      `- "80"`  
    `depends_on:`  
      `db:`  
        `condition: service_healthy`  
    `networks:`  
      `- external-tier`  
    `labels:`  
      `- "coolify.managed=true"`

  `db:`  
    `image: postgres:16-alpine`  
    `restart: always`  
    `environment:`  
      `- POSTGRES_USER=user`  
      `- POSTGRES_PASSWORD=password`  
      `- POSTGRES_DB=activitylog`  
    `volumes:`  
      `- postgres_data:/var/lib/postgresql/data`  
    `healthcheck:`  
      `test: ["CMD-SHELL", "pg_isready -U user -d activitylog"]`  
      `interval: 5s`  
      `timeout: 5s`  
      `retries: 10`  
    `networks:`  
      `- internal-tier`

`networks:`  
  `external-tier:`  
    `driver: bridge`  
  `internal-tier:`  
    `driver: bridge`

`volumes:`  
  `postgres_data:`

## ---

**Required Repository Structure**

`.`  
`├── docker-compose.yaml`  
`├── Dockerfile`  
`├── .env.example`  
`├── README.md`  
`├── src/`  
`│   └── ...`  
`└── docs/`  
    `└── vdecent-handover.md`

## ---

**Required README Sections**

Create a README.md that outlines V-Decent compatibility, including local development validation using docker-compose.yaml, technology stack details, and application classification (Stateless/Stateful).

## ---

**Required Handover Document**

Create docs/vdecent-handover.md detailing application identity, deployment source, service exposure configurations showing network isolation details (e.g., external-tier vs internal-tier), production environment variables, and data persistence strategies.

## ---

**AI Agent Development Instructions**

1. Prefer simple, reliable architecture over unnecessary complexity.  
2. Do not use host port mappings in the primary docker-compose.yaml.  
3. Define native, standalone web bridges (external-tier) and isolated backend bridges (internal-tier). Do not reference hardcoded external networks like vdecent-ingress.  
4. Include coolify.managed=true label on the public-facing service to allow native orchestrator ingress mapping.  
5. Add a /health endpoint and configure explicit Docker engine healthcheck routines.

## ---

**Acceptance Criteria**

`[ ] Root-level docker-compose.yaml exists.`  
`[ ] docker-compose.yaml uses expose instead of ports for V-Decent-facing services.`  
`[ ] Public-facing service joins a clean, standalone web bridge (external-tier).`  
`[ ] Internal services are isolated on an internal bridge (internal-tier) and do not join the external tier.`  
`[ ] No hardcoded external network references (e.g., vdecent-ingress) exist in the manifest.`  
`[ ] Public-facing service includes the coolify.managed=true label.`  
`[ ] Downstream storage services include strict Docker healthcheck routines.`  
`[ ] Application provides a /health endpoint.`  
`[ ] Application has .env.example with an unpopulated reference profile.`