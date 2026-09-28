# Tasks: Deploy bb-app on Dokploy

## Phase 1: Create Deployment Artifacts

- [x] **Task 1: Create Dockerfile**
  - [x] Write Dockerfile with node:22-bookworm-slim base, system dependencies, ARG BB_APP_VERSION=0.44.0, ARG PI_VERSION=0.87.1, npm install bb-app and pi, set environment, CMD bb-app
  - [x] Verify Dockerfile has no `ARG BB_APP_VERSION=latest`

- [x] **Task 2: Create docker-compose.yml**
  - [x] Write docker-compose.yml with bb service, build args, environment variables, volume mount, dokploy-network, Traefik labels with Basic Auth
  - [x] Use placeholder values for domain, network name, resolver name, and bcrypt hash that will be verified before deployment

## Phase 2: Pre-Deployment Verification

- [ ] **Task 3: Verify npm registry**
  - [ ] Run `npm view bb-app version` and record the version
  - [ ] Update Dockerfile and docker-compose.yml with the actual version if needed

- [ ] **Task 4: Verify Docker network**
  - [ ] Run `docker network ls | grep dokploy` and confirm network name
  - [ ] Update docker-compose.yml network name if it differs from `dokploy-network`

- [ ] **Task 5: Verify DNS**
  - [ ] Run `dig +short bb.riddler.agency` and confirm VPS IP

- [ ] **Task 6: Verify Traefik configuration**
  - [ ] Inspect Dokploy/Traefik config for actual certificate resolver name
  - [ ] Update docker-compose.yml with actual resolver name
  - [ ] Confirm no conflicting domain/router exists for bb.riddler.agency

## Phase 3: Build and Deploy

- [ ] **Task 7: Build Docker image**
  - [ ] Run `docker compose build` and confirm success
  - [ ] Verify no `latest` tag is used

- [ ] **Task 8: Deploy via Dokploy**
  - [ ] Start container with `docker compose up -d`
  - [ ] Confirm no host port is published

## Phase 4: Verification

- [ ] **Task 9: Runtime verification**
  - [ ] Verify `which bb-app`, `which pi`, `pi --version` return expected values
  - [ ] Verify `HOME=/data` inside container
  - [ ] Verify `/data` is mounted and persistent

- [ ] **Task 10: Pi authentication test**
  - [ ] Run `/login` in Pi and complete authentication
  - [ ] Verify Pi state exists under `/data/.pi/agent`

- [ ] **Task 11: End-to-end acceptance**
  - [ ] Access `https://bb.riddler.agency` through Traefik
  - [ ] Verify Basic Auth prompt appears
  - [ ] Verify Pi provider shows as usable in bb UI Settings → Providers → Pi
  - [ ] Restart container and verify Pi state persists

## Phase 5: Security Confirmation

- [ ] **Task 12: Security verification**
  - [ ] Confirm no `ports:` mapping exists in docker-compose.yml
  - [ ] Confirm direct `:38886` access is unavailable
  - [ ] Confirm HTTPS and Basic Auth are required for access
  - [ ] Confirm credentials are not committed in plaintext
