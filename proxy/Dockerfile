# proxy/Dockerfile

FROM nginx:1.26.2-alpine-slim

# Install envsubst for environment variable substitution
RUN apk add --no-cache gettext

# Copy entrypoint script and set executable permissions
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command to run Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
