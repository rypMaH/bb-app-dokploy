FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 make g++ git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

ARG BB_APP_VERSION
ARG PI_VERSION=0.87.1

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
