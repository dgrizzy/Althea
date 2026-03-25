FROM node:22-alpine

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    bash \
    curl \
    git \
    jq

# Install gcloud CLI
RUN curl https://sdk.cloud.google.com | bash && \
    /root/google-cloud-sdk/bin/gcloud components install beta && \
    ln -s /root/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud

# Set working directory
WORKDIR /app

# Copy application files
COPY . .

# Install dependencies
RUN npm ci

# Create entrypoint script
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port (adjust as needed)
EXPOSE 3000

# Use entrypoint to retrieve secrets and start app
ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm", "start"]
