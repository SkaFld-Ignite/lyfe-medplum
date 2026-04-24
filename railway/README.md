# Railway Deployment Guide — lyfe-medplum

## Architecture

- **medplum-server**: FHIR R4 API at `api.getlyfe.dev` (port 8103)
- **medplum-app**: Admin UI at `app.getlyfe.dev` (port 3000, nginx)
- **PostgreSQL 16**: Managed by Railway (internal network)
- **Redis 7**: Managed by Railway (internal network)
- **Doppler**: Secrets management (synced to Railway via integration)
- **GHCR**: Docker image registry (`ghcr.io/skafld-ignite/lyfe-medplum-*`)

## How Deploys Work

1. Push to `main` triggers `.github/workflows/deploy-railway.yml`
2. GitHub Actions builds server + app Docker images
3. Images are pushed to GHCR with SHA, version, and `latest` tags
4. Railway deploy webhooks are triggered, pulling the latest images

## Local Development

```bash
# Pull secrets from Doppler for local dev
doppler run --project lyfe-medplum --config dev -- docker compose up

# Or generate a .env file
doppler secrets download --project lyfe-medplum --config dev --no-file --format env > .env
```

## Managing Secrets

All secrets are in Doppler project `lyfe-medplum`:
- `prd` — server production config
- `prd_app` — app production config
- `dev` — local development config

```bash
# View all production secrets
doppler secrets --project lyfe-medplum --config prd

# Update a secret
doppler secrets set --project lyfe-medplum --config prd SECRET_NAME=value
```

Changes sync to Railway automatically via the Doppler integration.

## PostgreSQL Maintenance

Railway PostgreSQL requires these custom settings (applied during initial setup):
- `default_transaction_isolation = 'repeatable read'`
- `statement_timeout = 60000`
- Extensions: `pg_stat_statements`, `btree_gin`, `pg_trgm`

If the database is reprovisioned, re-run `railway/init-postgres.sql`.

## Troubleshooting

### Server won't start
- Check Railway logs for the `medplum-server` service
- Verify Doppler secrets are syncing (check Railway env vars panel)
- Ensure PostgreSQL and Redis are healthy in Railway dashboard

### App shows blank page
- Check that `MEDPLUM_CLIENT_ID` is set in the `prd_app` Doppler config
- Check that `MEDPLUM_BASE_URL` points to the correct server URL
- Open browser console for CORS or network errors

### Database connection errors
- Verify PostgreSQL is running in Railway dashboard
- Check `MEDPLUM_DATABASE_*` vars match Railway's PostgreSQL credentials
- Try `railway connect postgres` to test connectivity
