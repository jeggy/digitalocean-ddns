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
