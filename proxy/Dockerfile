# proxy/Dockerfile

FROM nginx:1.26.2-alpine-slim

# Install envsubst for environment variable substitution
RUN apk add --no-cache gettext bash

# Copy entrypoint script and set executable permissions
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy Nginx configuration templates
COPY nginx.conf.template.http /etc/nginx/conf.d/nginx.conf.template.http
COPY nginx.conf.template.ssl /etc/nginx/conf.d/nginx.conf.template.ssl

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command to run Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
