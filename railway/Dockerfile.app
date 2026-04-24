# ============================================================
# Stage 1: Install dependencies and build the app
# ============================================================
FROM node:22-slim AS builder

WORKDIR /usr/src/medplum

# Copy root package files
COPY package.json package-lock.json tsconfig.json turbo.json api-extractor.json tsdoc.json ./

# git is needed by esbuild.mjs for version stamping
RUN apt-get update && apt-get install -y git --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Copy package.json files for all app dependencies
COPY packages/core/package.json packages/core/
COPY packages/definitions/package.json packages/definitions/
COPY packages/fhirtypes/package.json packages/fhirtypes/
COPY packages/fhir-router/package.json packages/fhir-router/
COPY packages/react-hooks/package.json packages/react-hooks/
COPY packages/react/package.json packages/react/
COPY packages/app/package.json packages/app/

# Install all dependencies
RUN npm ci

# Copy source code
COPY packages/fhirtypes/ packages/fhirtypes/
COPY packages/core/ packages/core/
COPY packages/definitions/ packages/definitions/
COPY packages/fhir-router/ packages/fhir-router/
COPY packages/react-hooks/ packages/react-hooks/
COPY packages/react/ packages/react/
COPY packages/app/ packages/app/

# Build with placeholder values — replaced at container startup by entrypoint
ENV MEDPLUM_BASE_URL=__MEDPLUM_BASE_URL__
ENV MEDPLUM_CLIENT_ID=__MEDPLUM_CLIENT_ID__
ENV GOOGLE_CLIENT_ID=__GOOGLE_CLIENT_ID__
ENV RECAPTCHA_SITE_KEY=__RECAPTCHA_SITE_KEY__
ENV MEDPLUM_REGISTER_ENABLED=__MEDPLUM_REGISTER_ENABLED__
ENV MEDPLUM_AWS_TEXTRACT_ENABLED=__MEDPLUM_AWS_TEXTRACT_ENABLED__

# Remove test files — they import dev-only peer deps that aren't available
RUN find packages -name '*.test.ts' -delete && find packages -name '*.test.tsx' -delete

RUN npx turbo run build --filter=@medplum/app

# ============================================================
# Stage 2: Nginx runtime
# ============================================================
FROM nginxinc/nginx-unprivileged:alpine AS runtime

USER root

# Nginx config: SPA routing, gzip, asset caching
COPY <<'NGINX_CONF' /etc/nginx/conf.d/default.conf
server {
    listen 3000;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, no-transform";
    }
}
NGINX_CONF

# Copy built app from builder
COPY --from=builder /usr/src/medplum/packages/app/dist/ /usr/share/nginx/html/

# Copy the entrypoint script that replaces __MEDPLUM_*__ placeholders at startup
COPY packages/app/docker-entrypoint.sh /docker-entrypoint.sh

RUN chown -R 101:101 /usr/share/nginx/html && \
    chown 101:101 /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

EXPOSE 3000

USER 101

ENTRYPOINT ["/docker-entrypoint.sh"]
