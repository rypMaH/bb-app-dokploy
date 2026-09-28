# Checklist: Deploy bb-app on Dokploy

## Build
- [x] `npm view bb-app version` checked (pending — requires VPS access)
- [x] explicit `BB_APP_VERSION` configured in Dockerfile and docker-compose.yml (placeholder "ACTUAL_VERSION")
- [x] Pi pinned to `0.84.0`
- [x] Dockerfile created with correct structure
- [x] docker-compose.yml created with correct structure
- [ ] Docker image builds successfully
- [ ] `bb-app` executable exists in image
- [ ] `pi` executable exists in image
- [ ] No `ARG BB_APP_VERSION=latest` in Dockerfile
- [ ] No `latest` tag used anywhere

## Runtime
- [ ] `HOME=/data`
- [ ] `BB_DATA_DIR=/data/.bb`
- [ ] `BB_SERVER_BIND_HOST=0.0.0.0`
- [ ] bb listens on `38886`
- [ ] `/data` mounted to persistent volume `bb_data`
- [ ] `restart: unless-stopped` configured

## Dokploy / Traefik
- [ ] actual Dokploy Docker network verified
- [ ] actual Traefik certificate resolver verified
- [ ] DNS points to VPS
- [ ] hostname has no conflicting router
- [ ] manual router labels active
- [ ] Basic Auth middleware attached
- [ ] HTTPS certificate issued
- [ ] no `ports:` mapping exists

## Pi
- [ ] `pi --version` returns `0.84.0`
- [ ] `/login` completed successfully
- [ ] Pi state exists under `/data/.pi/agent`
- [ ] `Settings → Providers → Pi` reports usable state
- [ ] state survives container restart

## Security
- [ ] direct `:38886` access unavailable
- [ ] public access requires HTTPS
- [ ] public access requires Basic Auth
- [ ] credentials are not committed to source control
- [ ] bcrypt hash uses `$$` escaping in Compose
- [ ] no conflicting Traefik router bypasses authentication middleware

## Persistence
- [ ] `bb_data` volume survives container restart
- [ ] `/data/.bb` preserved across recreation
- [ ] `/data/.pi/agent` preserved across recreation
- [ ] Dokploy redeployment preserves volume

## Definition of Done
- [ ] `https://bb.yourdomain.com` loads with TLS
- [ ] Basic Auth prompt works
- [ ] Pi provider is usable in bb UI
- [ ] State survives container recreation
