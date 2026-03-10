FROM node:22-bookworm-slim

RUN npm install -g openclaw@latest

WORKDIR /srv/openclaw

EXPOSE 18789

ENTRYPOINT ["openclaw"]
CMD ["gateway", "--bind", "lan", "--port", "18789"]
