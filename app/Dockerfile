# syntax=docker/dockerfile:1
#
# Production-shaped NGINX image for the DevOps Intern Final Assessment.
# Runs as non-root, serves on 8080, exposes /healthz, and injects BUILD_SHA.

FROM nginx:1.27-alpine

# Build identifier surfaced in both the served page and an X-Build-SHA header.
ARG BUILD_SHA=dev

LABEL org.opencontainers.image.title="devops-intern-final" \
      org.opencontainers.image.source="https://github.com/calson404/devops-intern-final"

# Create a dedicated unprivileged user (uid 10001 keeps clear of system ranges).
RUN addgroup -g 10001 -S app \
 && adduser  -u 10001 -S app -G app

# Remove the stock default server so only our config is active.
RUN rm -f /etc/nginx/conf.d/default.conf

# Substitute BUILD_SHA into the config and the served page, then stage files.
COPY nginx.conf   /tmp/nginx.conf.template
COPY index.html   /tmp/index.html.template
RUN sed "s/__BUILD_SHA__/${BUILD_SHA}/g" /tmp/nginx.conf.template \
        > /etc/nginx/nginx.conf \
 && sed "s/__BUILD_SHA__/${BUILD_SHA}/g" /tmp/index.html.template \
        > /usr/share/nginx/html/index.html \
 && rm /tmp/nginx.conf.template /tmp/index.html.template

# Hand ownership of the paths the process writes to over to the non-root user.
RUN chown -R app:app \
        /var/cache/nginx \
        /var/log/nginx \
        /usr/share/nginx/html \
        /etc/nginx

USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null 2>&1 || exit 1

CMD ["nginx", "-g", "daemon off;"]
