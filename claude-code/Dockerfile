# Claude Code add-on image. Built on the Home Assistant host by the Supervisor
# (no image: key in config.yaml), so there is no registry to publish to.
#
# The Claude Code CLI is deliberately NOT pinned (same policy as claude-ssh):
# @latest at build time, self-updating at runtime. A stale pinned CLI has
# previously defaulted to a retired model id and 404'd on every request.
FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        tmux \
        nginx-light \
        git \
        curl \
        ca-certificates \
        jq \
        python3 \
        ripgrep \
        procps \
        less \
        vim \
    && rm -rf /var/lib/apt/lists/*

# ttyd is not packaged for Debian bookworm: use the pinned upstream static
# binary, checked against the release's SHA256SUMS. Asset names follow
# `uname -m` (x86_64 / aarch64).
ARG TTYD_VERSION=1.7.7
RUN set -e; arch="$(uname -m)"; \
    base="https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}"; \
    curl -fsSL -o "/tmp/ttyd.${arch}" "${base}/ttyd.${arch}"; \
    curl -fsSL -o /tmp/SHA256SUMS "${base}/SHA256SUMS"; \
    (cd /tmp && grep " ttyd.${arch}\$" SHA256SUMS | sha256sum -c -); \
    install -m 755 "/tmp/ttyd.${arch}" /usr/local/bin/ttyd; \
    rm -f "/tmp/ttyd.${arch}" /tmp/SHA256SUMS; \
    ttyd --version

RUN npm install -g @anthropic-ai/claude-code@latest \
    && claude --version

COPY ha-api ha-supervisor /usr/local/bin/
COPY tmux.conf /etc/tmux.conf
COPY nginx.conf /etc/nginx/claude-ingress.conf
COPY run.sh /run.sh
RUN sed -i 's/\r$//' /usr/local/bin/ha-api /usr/local/bin/ha-supervisor /run.sh \
    && chmod 755 /usr/local/bin/ha-api /usr/local/bin/ha-supervisor /run.sh

CMD ["/run.sh"]
