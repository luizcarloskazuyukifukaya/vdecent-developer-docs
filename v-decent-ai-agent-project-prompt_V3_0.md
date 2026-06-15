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

**Application to Build**

Replace the placeholders below before starting:  
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
`├── docker-compose.yaml`    
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

## ---

**Acceptance Criteria**

\[ \] Root-level docker-compose.yaml exists.  
\[ \] docker-compose.yaml uses expose instead of ports for V-Decent-facing services.  
\[ \] **CRITICAL:** No network definitions or custom networks exist inside the docker-compose.yaml manifest.  
\[ \] Public-facing service includes the coolify.managed=true label.  
\[ \] Downstream storage services include strict Docker healthcheck routines.  
\[ \] Application provides a /health endpoint.  
\[ \] Application has .env.example with an unpopulated reference profile.