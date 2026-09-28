# Deploy bb-app on Dokploy Spec

## Why
Deploy `bb-app` as a persistent Docker service on a remote Debian 13 VPS managed by Dokploy and exposed through Dokploy's Traefik instance with HTTPS and Basic Auth. The current state has no deployment artifacts — no Dockerfile, no docker-compose.yml, and no containerized service running.

## What Changes
- Create `Dockerfile` for bb-app with pinned versions (Node 22, bb-app explicit version, Pi CLI 0.84.0)
- Create `docker-compose.yml` with Dokploy/Traefik integration, persistent volume, and Basic Auth middleware
- Create `.trae/specs/deploy-bb-app-dokploy/` spec documents (spec.md, tasks.md, checklist.md)

## Impact
- Affected specs: Docker deployment, Dokploy integration, Traefik routing, Pi CLI integration, persistence
- Affected code: New files only — `Dockerfile`, `docker-compose.yml`
- No existing application source code is modified

## ADDED Requirements
### Requirement: Dockerfile with pinned versions
The system SHALL provide a Dockerfile that:
- Uses `node:22-bookworm-slim` as base image
- Installs python3, make, g++, git, ca-certificates, curl
- Accepts `BB_APP_VERSION` as a mandatory build arg (no default)
- Pins `PI_VERSION=0.84.0` as a build arg
- Installs `bb-app@<explicit-version>` via npm
- Installs `@earendil-works/pi-coding-agent@0.84.0` via npm with `--ignore-scripts`
- Sets `HOME=/data`, `BB_DATA_DIR=/data/.bb`, `BB_SERVER_BIND_HOST=0.0.0.0`
- Exposes port 38886
- Runs `bb-app` as CMD

#### Scenario: Build succeeds with explicit version
- **WHEN** `BB_APP_VERSION` is provided and `docker build` is run
- **THEN** the image contains `bb-app` and `pi` executables at the pinned versions

### Requirement: Docker Compose with Dokploy integration
The system SHALL provide a docker-compose.yml that:
- Builds from the Dockerfile with explicit `BB_APP_VERSION` arg
- Uses `restart: unless-stopped`
- Sets required environment variables (HOME, BB_DATA_DIR, BB_SERVER_BIND_HOST, BB_APP_URL)
- Mounts `bb_data` volume at `/data`
- Attaches to `dokploy-network` (external)
- Declares manual Traefik labels for HTTPS routing, TLS, and Basic Auth middleware
- Contains NO `ports:` mapping

#### Scenario: Container starts and is reachable via Traefik
- **WHEN** `docker compose up -d` is run
- **THEN** bb is reachable at `https://bb.yourdomain.com` through Traefik with Basic Auth

### Requirement: Persistence
The system SHALL persist bb and Pi state across container recreation:
- A Docker named volume `bb_data` is mounted at `/data`
- `/data/.bb` and `/data/.pi/agent` survive container restart, recreation, and image update

#### Scenario: Container restarted
- **WHEN** `docker restart <bb-container>` is run
- **THEN** Pi authentication state under `/data/.pi/agent` remains intact

### Requirement: Pre-deployment validation
Before deployment, the following MUST be verified:
1. `npm view bb-app version` returns the version to pin
2. Docker network `dokploy` (or actual name) exists
3. DNS resolves `bb.yourdomain.com` to the VPS IP
4. No conflicting Traefik router exists for the hostname

## MODIFIED Requirements
None — this is a new deployment with no existing code.

## REMOVED Requirements
None.
