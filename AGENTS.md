# digitalocean — AGENTS.md

Dynamic DNS updater. Keeps the `A` records for all three managed domains pointing at the server's current public IP. Runs as three separate containers (one per domain), each polling every hour.

## Services

| Container | Domain managed |
|---|---|
| `digitalocean-example-1` | `example.com` |
| `digitalocean-example2-1` | `another-example.fo` |
| `digitalocean-example3-1` | `yet-another-example.dk` |

All three use the same local Docker image (built from `Dockerfile` in this directory) and the same DigitalOcean API token.

## Configuration

| Variable | Value |
|---|---|
| `DO_TOKEN` | DigitalOcean API token (in `docker-compose.yml`) |
| `NAME` | `@` (root record) |
| `UPDATE_INTERVAL` | `3600` (seconds) |

Each service overrides only the `DOMAIN` variable.

## Key Files

```
digitalocean/
├── docker-compose.yml    # Three-service DDNS stack
└── Dockerfile            # DDNS updater image (builds from this dir)
```

## Common Operations

```bash
# Force an immediate update (restart triggers update on start)
docker compose restart

# Check logs for all three
docker compose logs -f

# Verify current IPs
dig +short example.com
dig +short another-example.fo
dig +short yet-another-example.dk
```

## Notes

- Uses the same DigitalOcean token as Caddy for DNS-01 ACME challenges
- Only updates the `@` (root) A record — subdomains use wildcard entries or CNAME to the root

## CI/CD

On every push to `main` (and on version tags like `v1.0.0`), the
`.github/workflows/docker-publish.yml` GitHub Actions workflow builds the
image and publishes it to the GitHub Container Registry at
`ghcr.io/jeggy/digitalocean-ddns`. Pull requests build the image (to catch
Dockerfile breakage) but do not push it. No secrets need to be configured —
it authenticates with the workflow's built-in `GITHUB_TOKEN`.

## Repo hygiene / security

This directory is public and open source. The following are never to be
committed, and are enforced via `.gitignore`:

- `docker-compose.yml` — the real, local compose file. It contains a live
  `DO_TOKEN` for this deployment's three domains and must stay local only.
- `bak.yml` — an older backup of the same file, also holds a live token.
- Any `*.env` / `.env*` file.

`docker-compose.example.yml` is the sanitized, placeholder-token version
that ships in the repo — keep it in sync with the real file's structure
(service/env var names) whenever the real one changes, but never copy real
values into it.

Before committing or pushing from this directory, grep the staged diff for
the token prefix (`dop_v1_`) as a safety net:

```bash
git diff --cached | grep -i dop_v1_ && echo "TOKEN FOUND — DO NOT COMMIT"
```
