FROM node:22-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates git gh python3 make g++ curl \
  && update-ca-certificates \
  && git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
  && git config --global --add url."https://github.com/".insteadOf "git@github.com:" \
  && git config --global --add url."https://github.com/".insteadOf "git+ssh://git@github.com/" \
  && rm -rf /var/lib/apt/lists/*

# Install gcloud CLI for GCP Secret Manager access
RUN curl https://sdk.cloud.google.com | bash && \
    /root/google-cloud-sdk/bin/gcloud components install beta && \
    ln -s /root/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud && \
    ln -s /root/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil

RUN npm install -g openclaw@latest @anthropic-ai/claude-code@latest

COPY docker/scripts/gh-app-token.js /usr/local/bin/gh-app-token.js
COPY docker/scripts/gh-wrapper.sh /usr/local/bin/gh
COPY scripts/entrypoint.sh /usr/local/bin/openclaw-entrypoint.sh
RUN chmod 0755 /usr/local/bin/gh-app-token.js /usr/local/bin/gh /usr/local/bin/openclaw-entrypoint.sh

WORKDIR /srv/openclaw

EXPOSE 18789

ENTRYPOINT ["/usr/local/bin/openclaw-entrypoint.sh"]
CMD ["openclaw", "gateway", "--bind", "lan", "--port", "18789"]
