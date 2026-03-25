FROM node:22-bookworm-slim

ARG OPENCLAW_VERSION=2026.3.13
ARG CLAUDE_CODE_VERSION=2.1.77

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates git gh python3 make g++ \
  && update-ca-certificates \
  && git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
  && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
  && git config --global --add url."https://github.com/".insteadOf "git+ssh://git@github.com/" \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
  openclaw@${OPENCLAW_VERSION} \
  @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

COPY docker/scripts/gh-app-token.js /usr/local/bin/gh-app-token.js
COPY docker/scripts/gh-wrapper.sh /usr/local/bin/gh
RUN chmod 0755 /usr/local/bin/gh-app-token.js /usr/local/bin/gh

WORKDIR /srv/openclaw

EXPOSE 18789

ENTRYPOINT ["openclaw"]
CMD ["gateway", "--bind", "lan", "--port", "18789"]
