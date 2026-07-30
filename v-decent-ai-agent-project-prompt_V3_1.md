# **V-Decent AI Coding Agent Project Prompt**

**Prompt version:** 3.0  
**Based on:** V-Decent Application Development Guide (en, V3\_0)  
**Audience:** Human developers using AI coding agents such as Codex, Gemini CLI, Claude Code, Cursor, or similar tools.  
Use this prompt when starting or updating an application project intended to run on **V-Decent Distributed Infrastructure (Coolify Orchestration)**, also called **V-Decent**.

## ---

**Prompt to Give the AI Coding Agent**

You are an expert full-stack application developer. Build this application so it can be developed, tested, registered, handed over, and deployed through **V-Decent Distributed Infrastructure**.  
V-Decent is a distributed datacenter hosting environment that uses **Docker Compose**, **Coolify orchestration**, and the **V-Decent Application Manager**. The application must be compatible with V-Decent deployment rules from the beginning.  
Your job is to create production-ready application code, repository structure, Docker configuration, environment-variable templates, local test instructions, and deployment handover notes.  
The project must follow the **V-Decent Application Development Guide (en, V3\_0)**. You must pay specific attention to network definitions to avoid proxy routing faults.

## ---

**Application to Deploy in V-Decent**

Your application can be deployed to V-Decent Virtual Distributed Infrastructure (V-Decent) by meeting the Application Development Requirements for V-Decent, which is described in this document, but to deploy using V-Decent Application Manager (App Manager), you need to define the followings:

Application name: \<APP\_NAME\>  
Primary shortname / subdomain: \<APP\_SHORTNAME\>  
Target production URL: https://\<APP\_SHORTNAME\>.v-decent.org  
Application type: \<STATELESS | STATEFUL\_EXTERNAL\_DATA | STATEFUL\_WITH\_LIMITED\_INTERNAL\_DATA\>  
Main application purpose: \<DESCRIBE\_THE\_APP\>  
Technology stack preference: \<NODE/EXPRESS | NEXT.JS | PYTHON/FASTAPI | OTHER\>  
Primary exposed service/container: \<SERVICE\_NAME\>  
Internal application port: \<PORT\>  
External storage required: \<YES/NO\>  
Database required: \<YES/NO\>  
Backup sidecar required: \<YES/NO\>  
Repository visibility: \<PUBLIC | PRIVATE\>  
Git branch for deployment: \<BRANCH\_NAME\>  
Developer group: \<DEVELOPER\_GROUP\>  
GitHub account or organization: \<GITHUB\_ACCOUNT\_OR\_ORG\>

Replace the placeholders for your application to prepare for the deployment with App Manager. 

Note that these are not necessary to design and develop your application, but eventually those information will be required.  
## ---

**Non-Negotiable V-Decent Compatibility Rules**

The repository must be compatible with V-Decent Application Manager and Coolify deployment.

### **1\. Docker Compose Is Required**

Create a file named exactly: docker-compose.yaml  
Do not use a different file name such as docker-compose.yml, compose.yaml, or docker-compose.prod.yaml as the only deployment manifest. The Docker Compose file must define every service needed by the application.

### **2\. Do Not Use Host Port Mapping in the Primary Manifest**

Do **not** map, expose, or bind physical port configurations directly to the host network interface (e.g., avoid ports: "8080:80"). Direct bindings create network conflicts across multi-tenant nodes. All inbound ingress routing paths are dynamically managed and isolated by Coolify proxy instances.  
Use the expose array parameter to identify internal networking endpoints. This alerts upstream container bridges where application traffic is listening.

### **3\. CRITICAL: Network Definition Prohibited (Coolify/Traefik Compatibility)**

Due to a limitation of Coolify/Traefik, defining custom or internal-only networks (e.g., bridge networks like external-tier or internal-tier) inside the docker-compose.yaml **MAY NOT work as expected and causes critical deployment issues**. You **MUST STRONGLY AVOID AND NOT DEFINE ANY NETWORKS** within the docker compose file.  
As part of your development tasks, you **MUST check if any network section is included in the file**. If found, it must be removed. Let the underlying Docker daemon and Coolify dynamically manage subnet pools natively behind the scenes. You must include the platform label "coolify.managed=true" on the public-facing service container to notify Coolify to attach its managed network structure correctly.

### **4\. Exactly One Public-Facing Service Unless Specified Otherwise**

Identify which service should be exposed by V-Decent Application Manager. Most applications should expose only the main web/API container, for example:  
Expose: app \-\> https://\<APP\_SHORTNAME\>.v-decent.org  
Do not expose: db, redis, worker, backup-sidecar, internal services  
If a service should not be reachable from the internet, its URL field must be left empty during V-Decent Application Manager registration.

### **5\. Environment Variables Are Required**

Isolate all secrets, connection tokens, and environment parameters into standard .env configurations. Provide an unpopulated, fully documented reference profile named exactly: .env.example  
The .env.example file must list all required variables with safe sample values or clear placeholders. Never commit real production secrets.  
Also provide a separate section in the README called **Production Environment Variables** explaining which values must be supplied to V-Decent Application Manager during registration with their actual production values.

### **6\. Liveness & Readiness Probes (Health Checks)**

Integrate explicit Docker engine healthcheck routines for all downstream data storage systems and caching daemons to confirm initialization status before compute workers begin boot cycles. The application should expose a lightweight health endpoint: GET /health which returns HTTP 200 when ready.

## ---

**Local Development Setup (for testing without Coolify)**

For local development and testing, provide a separate Docker Compose override file and a launch script alongside the production manifest. The production docker-compose.yaml must never contain host port mappings; local convenience goes in separate files that are never uploaded during V-Decent registration.

### **1\. docker-compose.dev.yaml (Local-Only Base)**

Create a separate compose file for local development that enables volume mounts and a debug-friendly entrypoint. This file uses `build: .` and `volumes` so code changes take effect without rebuilding, plus a TTY-aware entrypoint that waits for dependencies. Do NOT include this file in V-Decent registration.

### **2\. docker-compose.local.yaml (Port Overrides)**

Create a minimal override file that adds `ports:` mappings so services are reachable from the host browser. This file is written at runtime by `launch-local.sh` and must not be committed to the V-Decent registration repository.

Template (adapt service names to your application):

`services:`      
  `<db-service>:`      
    `ports:`      
      `- "${DB_PORT}:5432"`      
  `<backend-service>:`      
    `ports:`      
      `- "${BACKEND_PORT}:8000"`      
  `<frontend-service>:`      
    `ports:`      
      `- "${FRONTEND_PORT}:80"`      
  `<sidecar-service>:`      
    `ports:`      
      `- "${SIDECAR_PORT}:8000"`

If the application does not use a sidecar (Pattern A — Stateless), omit the sidecar service line.

### **3\. launch-local.sh (Orchestration Script)**

Create an executable script at the repository root that handles the entire local launch lifecycle. The script must perform these steps in order:

1. Read `INIT_DB` from the environment (default `no`) to optionally initialize database schemas on first launch.
2. Scan candidate host ports and select the first available one for each service:
   - Frontend: 5000, 5002, 5004, 5006
   - Backend: 5001, 5003, 5005, 5007
   - Database: 6433, 6434, 6435, 6436
   - Sidecar: 8002, 8003, 8004, 8005
3. Detect the LAN IP using `hostname -I | awk '{print $1}'` so the frontend can be accessed from other devices (e.g., on WSL2, Windows browsers must use this IP not localhost).
4. If a `sidecar/` directory exists, check for `token.json` and `credentials.json`. If `token.json` is missing but `credentials.json` is present, offer interactive Google Drive token generation by creating a temporary venv and running `generate_token.py`. Only offer this in interactive shells.
5. Ensure `.env` exists (copy from `.env.example` if not), then update dynamic values:
   - `NEXT_PUBLIC_API_URL=http://<LOCAL_IP>:<BACKEND_PORT>`
   - `INIT_DB` from environment
   - Fill any missing defaults (JWT secret, admin credentials, database URLs)
   - Warn if a shell environment variable differs from the `.env` value — the shell value takes precedence.
6. Export all `.env` values to the shell so Docker Compose inherits them.
7. Write `docker-compose.local.yaml` with the discovered ports.
8. Launch all services: `docker compose -f docker-compose.dev.yaml -f docker-compose.local.yaml up --build -d`
9. Print access URLs and useful commands (view logs, stop, full reset).

Include the `# ponytail:` comment marker on any local-only defaults to clearly distinguish them from production values.

### **4\. Local Environment Variable Conventions**

The `.env` file must include local-only defaults clearly flagged:

`INIT_DB=no  # ponytail: local dev only — set to "yes" to initialize schema on first launch`  
` `  
`# Dynamic values (set by launch-local.sh)`  
`NEXT_PUBLIC_API_URL=http://localhost:5001`  
` `  
`# Local defaults (override for production)`  
`JWT_SECRET=super-secret-dev-key           # ponytail: local dev only`  
`POSTGRES_USER=postgres                    # ponytail: local dev only`  
`POSTGRES_PASSWORD=postgres                # ponytail: local dev only`  
`POSTGRES_DB=ops_ledger                    # ponytail: local dev only`  
`DATABASE_URL=postgresql://postgres:postgres@db:5432/ops_ledger  # ponytail: local dev only`

The **Production Environment Variables** section in the README must list which variables the app operator must override during V-Decent Application Manager registration.

## ---

**Supported Application Types and Data Persistence Rules**

V-Decent supports three application patterns. Choose one explicitly and document it in the README and handover document.

### **Pattern A — Stateless Compute Services**

Use this when the app does not store persistent data inside the container or in V-Decent-managed storage (e.g., API gateways, frontend web applications, background worker microservices, and chronological task processors).

### **Pattern B — Stateful Application with External Data**

Use this when the app stores data outside V-Decent, such as AWS S3, Wasabi, or another external storage system. Use environment values to point to this external storage.

### **Pattern C — Stateful Storage Services (Supported with Limitation)**

Use this when a relational/non-relational database, persistent data caching node, or structured file queue utilizing platform-managed underlying storage volumes is included in Docker Compose.

* Map data to discrete Docker volumes.  
* Ensure compute services use depends\_on with condition: service\_healthy.  
* Include a backup sidecar container if data persistence and point-in-time restore to external storage (like Google Drive) are required.

## ---

**Recommended Docker Compose Baseline for V-Decent V3\_0**

Use this as the baseline structure. Notice that all custom network sections are strictly removed and commented out as forbidden:  
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
`# DO NOT DEFINE NETWORK (Prohibited in V3_0 due to Coolify/Traefik limitations)`  
    `labels:`      
      `- "coolify.managed=true" # Notify Coolify to use this network`     
      
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
`# DO NOT DEFINE NETWORK`

`# DO NOT DEFINE NETWORK SECTION AT THE ROOT LEVEL`  
`# networks:`      
`#   ...`

`volumes:`      
  `postgres_data:`

## ---

**Required Repository Structure**

`.`    
`├── docker-compose.yaml            # production manifest for V-Decent`    
`├── docker-compose.dev.yaml        # local-only base (volumes, debug entrypoint)`    
`├── docker-compose.local.yaml      # local port overrides (generated at runtime by launch-local.sh)`    
`├── launch-local.sh                # entry point for local development`    
`├── Dockerfile`    
`├── .env.example`    
`├── README.md`    
`├── src/`    
`│   └── ...`    
`└── docs/`    
    `└── vdecent-handover.md`

## ---

**AI Agent Development Instructions**

1. Prefer simple, reliable architecture over unnecessary complexity.  
2. Do not use host port mappings in the primary docker-compose.yaml.  
3. **CRITICAL TASK CHECK:** Verify that the network definition section is NOT included anywhere within the docker-compose.yaml. Do not define external-tier, internal-tier, or join external networks like vdecent-ingress, as it breaks the Coolify/Traefik integration.  
4. Include coolify.managed=true label on the public-facing service to allow native orchestrator ingress mapping.  
5. Add a /health endpoint and configure explicit Docker engine healthcheck routines.  
6. Generate a local development launch flow using `launch-local.sh` and `docker-compose.local.yaml`. The production `docker-compose.yaml` must never include host port mappings or custom networks.

## ---

**Acceptance Criteria**

\[ \] Root-level docker-compose.yaml exists.  
\[ \] docker-compose.yaml uses expose instead of ports for V-Decent-facing services.  
\[ \] **CRITICAL:** No network definitions or custom networks exist inside the docker-compose.yaml manifest.  
\[ \] Public-facing service includes the coolify.managed=true label.  
\[ \] Downstream storage services include strict Docker healthcheck routines.  
\[ \] Application provides a /health endpoint.  
\[ \] Application has .env.example with an unpopulated reference profile.  
\[ \] `launch-local.sh` exists at repository root and is executable.  
\[ \] `docker-compose.local.yaml` exists (can be gitignored; `launch-local.sh` generates it).  
\[ \] `docker-compose.dev.yaml` exists for local development volume mounts and debug entrypoint.  
\[ \] `launch-local.sh` detects available ports, syncs `.env`, and starts compose with both `-f` files.
