FROM node:22-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends git python3 make g++ \
  && git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
  && git config --global url."https://github.com/".insteadOf "git@github.com:" \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw@latest

WORKDIR /srv/openclaw

EXPOSE 18789

ENTRYPOINT ["openclaw"]
CMD ["gateway", "--bind", "lan", "--port", "18789"]
