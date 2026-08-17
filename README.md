# digitalocean-ddns

A tiny, dependency-free Dynamic DNS (DDNS) updater for domains hosted on
DigitalOcean DNS. It runs in a loop, checks your server's current public IP,
and updates a domain's `A` record via the DigitalOcean API whenever the IP
changes — so a domain pointed at a home/dynamic-IP server always resolves
correctly.

## How it works

- Fetches your current public IP.
- Compares it to the `A` record currently set on DigitalOcean.
- If they differ, updates the record via the DigitalOcean API.
- Sleeps for `UPDATE_INTERVAL` seconds and repeats.

### Recommended DNS setup

Point the container at your **root domain** (`NAME=@`). For any subdomains
you want to resolve to the same server (`www`, `home`, `app`, ...), add a
`CNAME` record on DigitalOcean pointing to `@` instead of a separate `A`
record:

```
Type   Name    Value
A      @       (managed automatically by this tool)
CNAME  www     @
CNAME  home    @
CNAME  app     @
```

Because every subdomain just points at `@`, updating the single root `A`
record keeps the whole domain — root and all subdomains — in sync
automatically. You never need to touch DNS again after the initial setup.

## Configuration

| Variable | Required | Description |
|---|---|---|
| `DO_TOKEN` | Yes | DigitalOcean API token with read/write access. [Create one here](https://docs.digitalocean.com/reference/api/create-personal-access-token/). |
| `DOMAIN` | Yes | The base domain as registered in the DigitalOcean control panel (e.g. `example.com`). |
| `NAME` | Yes | The record name to update. Use `@` for the root domain. |
| `UPDATE_INTERVAL` | No | Seconds between checks. If unset or `<= 0`, the script runs once and exits. Defaults to running once. |
| `IP_SERVICE` | No | URL to fetch your public IP from. Defaults to `ifconfig.co`. |

## Usage

### Option 1 — prebuilt image from GitHub Container Registry

```bash
docker run -d \
  --name ddns-example-com \
  -e DO_TOKEN='your_digitalocean_api_token' \
  -e DOMAIN='example.com' \
  -e NAME='@' \
  -e UPDATE_INTERVAL='3600' \
  ghcr.io/jeggy/digitalocean-ddns:latest
```

### Option 2 — docker compose, single domain

Copy [`docker-compose.example.yml`](docker-compose.example.yml) to
`docker-compose.yml`, fill in your token and domain, then:

```bash
docker compose up -d
```

```yaml
services:
  ddns:
    image: ghcr.io/jeggy/digitalocean-ddns:latest
    restart: unless-stopped
    environment:
      DO_TOKEN: 'your_digitalocean_api_token_here'
      DOMAIN: 'example.com'
      NAME: '@'
      UPDATE_INTERVAL: '3600'
```

### Option 3 — docker compose, multiple domains

Run one container per domain, sharing common config via a YAML anchor. Only
`DOMAIN` differs between services:

```yaml
x-common: &common
  image: ghcr.io/jeggy/digitalocean-ddns:latest
  restart: unless-stopped
  environment: &common-env
    DO_TOKEN: 'your_digitalocean_api_token_here'
    NAME: '@'
    UPDATE_INTERVAL: '3600'

services:
  example-com:
    <<: *common
    environment:
      <<: *common-env
      DOMAIN: 'example.com'

  another-example-com:
    <<: *common
    environment:
      <<: *common-env
      DOMAIN: 'another-example.com'

  yet-another-example-net:
    <<: *common
    environment:
      <<: *common-env
      DOMAIN: 'yet-another-example.net'
```

## Building locally

If you'd rather build the image yourself instead of using the prebuilt one,
replace `image: ghcr.io/jeggy/digitalocean-ddns:latest` with `build: .` in
any of the examples above, or build it directly:

```bash
docker build -t digitalocean-ddns .
```

## CI/CD

On every push to `main` (and on version tags like `v1.0.0`), a GitHub
Actions workflow builds the image and publishes it to the GitHub Container
Registry at [`ghcr.io/jeggy/digitalocean-ddns`](https://github.com/jeggy/digitalocean-ddns/pkgs/container/digitalocean-ddns).
See [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml).

## Security note

Never commit a real `docker-compose.yml`, `bak.yml`, or any file containing
your `DO_TOKEN` — these are gitignored on purpose. Use
[`docker-compose.example.yml`](docker-compose.example.yml) as a template and
keep your real file local, or pass secrets via environment variables /
Docker secrets instead.

## License

[MIT](LICENSE)
