FROM nginx:1.26.2-alpine-slim

# Install envsubst, bash, and curl for health checks
RUN apk add --no-cache gettext bash curl

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Copy Nginx configuration templates
COPY nginx.conf.template.http /etc/nginx/conf.d/nginx.conf.template.http
COPY nginx.conf.template.ssl /etc/nginx/conf.d/nginx.conf.template.ssl
COPY nginx.conf.template.acme /etc/nginx/conf.d/nginx.conf.template.acme

# Set executable permissions
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command
CMD ["nginx", "-g", "daemon off;"]

# Add HEALTHCHECK to ensure Nginx is responding
HEALTHCHECK --interval=60s --timeout=5s --retries=3 CMD curl -f http://localhost || exit 1
