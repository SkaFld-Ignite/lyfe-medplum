# ============================================================
# Stage 1: Install dependencies and build the app
# ============================================================
FROM node:22-slim AS builder

WORKDIR /usr/src/medplum

# git is needed by esbuild.mjs for version stamping
RUN apt-get update && apt-get install -y git --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Copy root config files
COPY package.json package-lock.json tsconfig.json turbo.json api-extractor.json tsdoc.json ./

# Copy ALL workspace package.json files so npm can resolve the full dependency graph
COPY packages/core/package.json packages/core/
COPY packages/definitions/package.json packages/definitions/
COPY packages/fhirtypes/package.json packages/fhirtypes/
COPY packages/fhir-router/package.json packages/fhir-router/
COPY packages/ccda/package.json packages/ccda/
COPY packages/bot-layer/package.json packages/bot-layer/
COPY packages/server/package.json packages/server/
COPY packages/react-hooks/package.json packages/react-hooks/
COPY packages/react/package.json packages/react/
COPY packages/app/package.json packages/app/
COPY packages/cli/package.json packages/cli/
COPY packages/cli-wrapper/package.json packages/cli-wrapper/
COPY packages/hl7/package.json packages/hl7/
COPY packages/mock/package.json packages/mock/
COPY packages/agent/package.json packages/agent/
COPY packages/cdk/package.json packages/cdk/
COPY packages/docs/package.json packages/docs/
COPY packages/graphiql/package.json packages/graphiql/
COPY packages/e2e/package.json packages/e2e/
COPY packages/eslint-config/package.json packages/eslint-config/
COPY packages/examples/package.json packages/examples/
COPY packages/generator/package.json packages/generator/
COPY packages/create-medplum/package.json packages/create-medplum/
COPY packages/dosespot-core/package.json packages/dosespot-core/
COPY packages/dosespot-react/package.json packages/dosespot-react/
COPY packages/health-gorilla-core/package.json packages/health-gorilla-core/
COPY packages/health-gorilla-react/package.json packages/health-gorilla-react/
COPY packages/scriptsure-react/package.json packages/scriptsure-react/

# Install all dependencies
RUN npm ci

# Copy source code only for packages the app needs
COPY packages/fhirtypes/ packages/fhirtypes/
COPY packages/core/ packages/core/
COPY packages/definitions/ packages/definitions/
COPY packages/fhir-router/ packages/fhir-router/
COPY packages/react-hooks/ packages/react-hooks/
COPY packages/react/ packages/react/
COPY packages/app/ packages/app/

# Remove test files — they import dev-only peer deps not available in partial workspace
RUN find packages -name '*.test.ts' -delete && find packages -name '*.test.tsx' -delete

# Build with placeholder values — replaced at container startup by entrypoint
ENV MEDPLUM_BASE_URL=__MEDPLUM_BASE_URL__
ENV MEDPLUM_CLIENT_ID=__MEDPLUM_CLIENT_ID__
ENV GOOGLE_CLIENT_ID=__GOOGLE_CLIENT_ID__
ENV RECAPTCHA_SITE_KEY=__RECAPTCHA_SITE_KEY__
ENV MEDPLUM_REGISTER_ENABLED=__MEDPLUM_REGISTER_ENABLED__
ENV MEDPLUM_AWS_TEXTRACT_ENABLED=__MEDPLUM_AWS_TEXTRACT_ENABLED__

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
