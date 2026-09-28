# bb-app on Dokploy — Development & Deployment Specification

**Status:** Ready for implementation  
**Target:** Remote Debian 13 VPS with Docker + Dokploy + Traefik  
**Service:** `bb-app`  
**External access:** HTTPS + Traefik Basic Auth  
**Pi version:** `0.87.1`  
**Persistence:** Docker volume mounted at `/data`

---

## 1. Objective

Deploy `bb-app` as a persistent Docker service managed by Dokploy and exposed through Dokploy's Traefik instance.

The deployment must:

- pin the `bb-app` version explicitly;
- pin the Pi CLI version to `0.87.1`;
- persist bb and Pi user state across container recreation;
- expose bb only through Traefik;
- terminate TLS at Traefik;
- protect the public endpoint with HTTP Basic Authentication;
- avoid publishing the bb application port directly on the VPS;
- provide a reproducible build from a Dockerfile;
- allow runtime verification of the Pi provider through bb's UI.

The implementation must not depend on an unresolved interpretation of bb/Pi historical PRs. Runtime behavior is validated empirically after deployment.

---

# 2. Architecture

```text
                         Internet
                            │
                            │ HTTPS :443
                            ▼
                     ┌───────────────┐
                     │    Traefik    │
                     │   TLS + Auth  │
                     └───────┬───────┘
                             │
                    Docker network
                             │
                             ▼
                     ┌───────────────┐
                     │    bb-app     │
                     │    :38886     │
                     └───────┬───────┘
                             │
                             ▼
                     ┌───────────────┐
                     │ Pi provider   │
                     │    bridge     │
                     └───────┬───────┘
                             │
                             ▼
                     ┌───────────────┐
                     │ pi 0.84.0     │
                     └───────┬───────┘
                             │
                             ▼
                       Model provider
```

Persistent application state:

```text
/data
├── .bb/
└── .pi/
    └── agent/
```

The entire `/data` directory is backed by a Docker named volume.

---

# 3. Repository / Deployment Files

The deployment context must contain at minimum:

```text
.
├── Dockerfile
└── docker-compose.yml
```

No application source compilation is required. `bb-app` is installed from npm during the image build.

---

# 4. Dockerfile Specification

```dockerfile
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 make g++ git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

ARG BB_APP_VERSION
ARG PI_VERSION=0.84.0

RUN npm install -g --allow-scripts=better-sqlite3,node-pty,@parcel/watcher bb-app@${BB_APP_VERSION}

# Pi CLI: used for `/login` to populate ~/.pi/agent (config/auth),
# which the bb Pi provider reads.
# Keep it pinned to the Pi version expected by the bundled provider.
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION}

ENV HOME=/data
ENV BB_DATA_DIR=/data/.bb
ENV BB_SERVER_BIND_HOST=0.0.0.0

WORKDIR /data

EXPOSE 38886

CMD ["bb-app"]
```

## 4.1 Build requirements

`BB_APP_VERSION` is intentionally mandatory.

There must be no:

```dockerfile
ARG BB_APP_VERSION=latest
```

Before deployment:

```bash
npm view bb-app version
```

The returned version must be explicitly inserted into the Compose build argument.

Example:

```yaml
args:
  BB_APP_VERSION: "0.44.0"
  PI_VERSION: "0.84.0"
```

The actual value must come from the registry check performed immediately before deployment rather than being assumed by the specification.

---

# 5. Docker Image Requirements

The resulting image must contain:

| Component | Requirement |
|---|---|
| Node.js | Node 22 |
| bb-app | Explicitly pinned version |
| Pi CLI | `0.84.0` |
| Python | Installed |
| make | Installed |
| g++ | Installed |
| git | Installed |
| curl | Installed |
| CA certificates | Installed |

The native build dependencies are included because bb-app dependencies such as `better-sqlite3`, `node-pty`, and `@parcel/watcher` may require native installation/build support.

---

# 6. Runtime Environment

The container must use:

```text
HOME=/data
BB_DATA_DIR=/data/.bb
BB_SERVER_BIND_HOST=0.0.0.0
```

Public application URL:

```text
BB_APP_URL=https://bb.yourdomain.com
```

`BB_SERVER_BIND_HOST=0.0.0.0` is required for the containerized topology because Traefik connects to bb over the Docker network rather than through localhost inside the bb container.

No host-level application port should be published.

---

# 7. Docker Compose

```yaml
services:
  bb:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        BB_APP_VERSION: "ACTUAL_VERSION"
        PI_VERSION: "0.84.0"

    restart: unless-stopped

    environment:
      HOME: /data
      BB_DATA_DIR: /data/.bb
      BB_SERVER_BIND_HOST: "0.0.0.0"
      BB_APP_URL: "https://bb.yourdomain.com"
      # ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}

    volumes:
      - bb_data:/data

    networks:
      - dokploy-network

    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.bb.rule=Host(`bb.yourdomain.com`)"
      - "traefik.http.routers.bb.entrypoints=websecure"
      - "traefik.http.routers.bb.tls=true"
      - "traefik.http.routers.bb.tls.certresolver=letsencrypt"
      - "traefik.http.services.bb.loadbalancer.server.port=38886"
      - "traefik.http.routers.bb.middlewares=bb-auth"
      - "traefik.http.middlewares.bb-auth.basicauth.users=admin:$$2y$$05$$YOUR_GENERATED_HASH"

networks:
  dokploy-network:
    external: true

volumes:
  bb_data:
```

`dokploy-network` and `letsencrypt` are configuration placeholders until verified against the actual Dokploy installation.

---

# 8. Dokploy Requirements

## 8.1 Docker network

Verify on the VPS:

```bash
docker network ls | grep dokploy
```

Use the actual Docker network name if it differs from `dokploy-network`.

The network must be:

```yaml
external: true
```

because the network is managed by Dokploy rather than created by this Compose project.

---

## 8.2 Traefik certificate resolver

Do not assume the resolver is named `letsencrypt`.

Inspect Dokploy/Traefik configuration and use the actual resolver name:

```text
traefik.http.routers.bb.tls.certresolver=<ACTUAL_RESOLVER>
```

---

## 8.3 Domain configuration

The bb hostname must resolve to the VPS.

Example:

```text
bb.yourdomain.com → VPS_PUBLIC_IP
```

Verification from an external machine:

```bash
dig +short bb.yourdomain.com
```

The result must contain the VPS public IP.

---

# 9. Traefik Routing

The service uses manually declared Traefik labels.

Required router properties:

```text
Host(bb.yourdomain.com)
entrypoint=websecure
TLS=true
certificate resolver=<actual resolver>
middleware=bb-auth
service=bb
```

The backend service must target:

```text
bb:38886
```

No additional WebSocket-specific configuration is required unless actual runtime testing demonstrates otherwise.

---

# 10. Basic Authentication

Generate a bcrypt password hash.

For example:

```bash
htpasswd -nbB admin 'YOUR_STRONG_PASSWORD'
```

Because the value is being embedded in a Docker Compose label, `$` characters must be escaped as `$$`.

Example transformation:

```text
admin:$2y$05$...
```

becomes:

```text
admin:$$2y$$05$$...
```

The final label must contain the complete generated hash:

```yaml
- "traefik.http.middlewares.bb-auth.basicauth.users=admin:$$2y$$05$$..."
```

Do not commit the real password or hash to a public repository.

---

# 11. Domain Shadowing Rule

The same hostname must not simultaneously be configured as a normal Dokploy Domain for another service.

Deployment must use:

```text
manual Traefik labels
```

for this service.

Before deployment:

1. Check Dokploy's Domains configuration.
2. Search for `bb.yourdomain.com`.
3. Remove/conflict-resolve any existing binding.
4. Do not create an additional Dokploy-generated router for the same hostname.

Acceptance condition:

```text
bb.yourdomain.com
        ↓
exactly one intended bb router
        ↓
bb-auth middleware
        ↓
bb:38886
```

If the Traefik dashboard is available, inspect its router configuration directly.

---

# 12. Persistence

The service must mount:

```yaml
volumes:
  - bb_data:/data
```

This is intentionally broader than mounting individual subdirectories.

Expected persistent locations include:

```text
/data/.bb
/data/.pi/agent
```

The purpose is to preserve both bb state and Pi user configuration/authentication across:

- container restart;
- container recreation;
- image update;
- Dokploy redeployment.

The volume must not be removed during ordinary application redeployment.

---

# 13. Pi Installation

Install:

```text
@earendil-works/pi-coding-agent@0.84.0
```

The version is pinned rather than using `latest`.

The deployment specification deliberately does not make a stronger architectural assertion about how bb packages or invokes Pi than necessary for deployment.

The implementation verification is:

```bash
which pi
pi --version
```

Expected:

```text
0.84.0
```

or, if the pinned version is intentionally changed later, the explicitly configured version.

---

# 14. Pre-Deployment Validation

Run:

```bash
npm view bb-app version
```

Record the returned version and put it into:

```yaml
BB_APP_VERSION: "<VERSION>"
```

Then verify the Docker network:

```bash
docker network ls | grep dokploy
```

Verify DNS:

```bash
dig +short bb.yourdomain.com
```

Verify the Traefik resolver using Dokploy/Traefik configuration.

Verify there is no conflicting domain/router.

All four checks must pass before deployment.

---

# 15. Build Validation

The image build must succeed without relying on an implicit `latest` tag.

The build must install:

```text
bb-app@<explicit-version>
@earendil-works/pi-coding-agent@0.84.0
```

After the container starts:

```bash
docker exec -it <bb-container> which bb-app
docker exec -it <bb-container> which pi
docker exec -it <bb-container> pi --version
docker exec -it <bb-container> sh -c 'echo "$HOME"'
```

Expected:

```text
bb-app → executable found
pi     → executable found
pi     → 0.84.0
HOME   → /data
```

---

# 16. Pi Authentication Test

Open an interactive Pi session:

```bash
docker exec -it <bb-container> pi
```

Run:

```text
/login
```

Complete the required provider authentication.

Then inspect persisted state:

```bash
docker exec -it <bb-container> \
  find /data/.pi -maxdepth 3 -type f
```

The objective is to confirm that Pi state is being written underneath the persistent `/data` volume.

---

# 17. bb Provider Acceptance Test

Open:

```text
https://bb.yourdomain.com
```

Authenticate through the Traefik Basic Auth prompt.

Navigate to:

```text
Settings → Providers → Pi
```

Acceptance condition:

```text
Pi provider is present
Pi provider reports usable/authenticated state
```

This UI state is the authoritative deployment-level confirmation that the bb/Pi integration is functioning.

---

# 18. Persistence Acceptance Test

After successful Pi authentication:

1. Record the current Pi provider state.
2. Restart the container:

```bash
docker restart <bb-container>
```

3. Reopen bb.
4. Check:

```text
Settings → Providers → Pi
```

Authentication/configuration must remain available.

Then, optionally test full container recreation through Dokploy.

The `bb_data` volume must survive the recreation.

---

# 19. Network Acceptance Test

From the VPS:

```bash
docker ps
```

Confirm bb is running.

There must be no published host port such as:

```text
0.0.0.0:38886->38886/tcp
```

The service should instead be reachable internally through the Docker network.

The intended public path is:

```text
HTTPS → Traefik → Docker network → bb:38886
```

---

# 20. Security Acceptance Criteria

The deployment must satisfy:

- bb port `38886` is not published to the host;
- HTTPS is used externally;
- Basic Auth protects the router;
- the Basic Auth credential is not committed in plaintext;
- Pi credentials/configuration reside on the persistent Docker volume;
- no conflicting Traefik router bypasses the authentication middleware.

Direct access to:

```text
http://VPS_IP:38886
```

must not be available.

---

# 21. Failure Diagnostics

## bb container fails to start

Inspect:

```bash
docker logs <bb-container>
```

Check:

- npm installation;
- native dependency compilation;
- `bb-app` executable;
- environment variables;
- filesystem permissions under `/data`.

---

## Pi provider unavailable

Check:

```bash
docker exec -it <bb-container> which pi
docker exec -it <bb-container> pi --version
```

Then inspect bb logs.

The minimum supported target for this deployment is:

```text
Pi 0.84.0
```

---

## HTTPS unavailable

Check:

1. DNS;
2. Traefik router;
3. entrypoint name;
4. certificate resolver name;
5. Docker network;
6. conflicting router/domain.

Do not modify the bb application before verifying the Traefik layer.

---

## 401/Basic Auth problems

Verify:

- middleware is attached to `bb` router;
- bcrypt hash is complete;
- `$` characters are escaped as `$$` in Compose;
- there is no second router for the same hostname without `bb-auth`.

---

## bb reachable internally but not externally

Check:

```text
DNS
  ↓
Traefik router
  ↓
Traefik entrypoint
  ↓
TLS resolver
  ↓
Docker network
  ↓
bb:38886
```

Do not add a `ports:` mapping as the first troubleshooting step.

---

# 22. Explicit Non-Goals

This deployment does **not** include:

- Kubernetes;
- a separate Pi container;
- `pi-acp`;
- custom ACP configuration;
- Redis;
- PostgreSQL;
- Nginx Proxy Manager in front of bb;
- direct host port exposure;
- automatic floating `latest` versions;
- a second reverse proxy;
- custom bb source modifications.

---

# 23. Final Acceptance Checklist

### Build

- [ ] `npm view bb-app version` checked
- [ ] explicit `BB_APP_VERSION` configured
- [ ] Pi pinned to `0.84.0`
- [ ] Docker image builds successfully
- [ ] `bb-app` executable exists
- [ ] `pi` executable exists

### Runtime

- [ ] `HOME=/data`
- [ ] `BB_DATA_DIR=/data/.bb`
- [ ] `BB_SERVER_BIND_HOST=0.0.0.0`
- [ ] bb listens on `38886`
- [ ] `/data` mounted to persistent volume

### Dokploy / Traefik

- [ ] actual Dokploy Docker network verified
- [ ] actual Traefik certificate resolver verified
- [ ] DNS points to VPS
- [ ] hostname has no conflicting router
- [ ] manual router labels active
- [ ] Basic Auth middleware attached
- [ ] HTTPS certificate issued
- [ ] no `ports:` mapping exists

### Pi

- [ ] `pi --version` returns `0.84.0`
- [ ] `/login` completed
- [ ] Pi state exists under `/data/.pi/agent`
- [ ] `Settings → Providers → Pi` reports usable state
- [ ] state survives container restart

### Security

- [ ] direct `:38886` access unavailable
- [ ] public access requires HTTPS
- [ ] public access requires Basic Auth
- [ ] credentials are not committed to source control

---

# 24. Definition of Done

The deployment is considered complete when:

```text
https://bb.yourdomain.com
        │
        ├── TLS works
        ├── Basic Auth works
        └── bb UI loads
                │
                └── Settings → Providers → Pi
                        │
                        └── Pi usable/authenticated
```

and the following survives container recreation:

```text
/data/.bb
/data/.pi/agent
```

The resulting production topology is:

```text
Internet
  → HTTPS
  → Dokploy Traefik
  → Basic Auth
  → bb-app:38886
  → Pi provider
  → pi 0.84.0
  → model provider
```

No host port is published for bb.
