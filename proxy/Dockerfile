FROM nginx:1.26.2-alpine-slim

# Install envsubst and bash
RUN apk add --no-cache gettext bash

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
