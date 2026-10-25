# fluentd-loki

Fluentd with [Grafana's Loki output plugin](https://grafana.com/docs/loki/latest/send-data/fluentd/), configured entirely by env vars, so every service can ship its container logs to Loki through one image.

Image: `ghcr.io/jackdcasey/fluentd-loki`, `linux/arm64`. Built from the official `fluent/fluentd` image plus the `fluent-plugin-grafana-loki` gem, because Grafana's own `grafana/fluent-plugin-loki` image is amd64-only.

## Configuration

| Env var | Required | Meaning |
|---|---|---|
| `LOKI_URL` | yes | Loki base URL without the push path, e.g. `https://logs-prod-xxx.grafana.net` or `http://loki:3100` |
| `LOKI_USERNAME` | Grafana Cloud | Loki user (instance) ID; blank for a Loki without auth |
| `LOKI_PASSWORD` | Grafana Cloud | Access token with logs:write; blank for a Loki without auth |
| `LOKI_EXTRA_LABELS` | no | JSON labels added to every line, e.g. `{"host":"pi-1"}` |

## Labels

- `job`: from the container's log tag, `loki.<job>`. Use a job name without dots.
- `container_name`
- `source`: `stdout` or `stderr`
- plus `LOKI_EXTRA_LABELS`

Each line arrives in Loki as the plain log text. Containers whose tag doesn't start with `loki.` are discarded.

## Usage (docker compose)

```yaml
services:
  my-app:
    image: ...
    depends_on:
      - fluentd
    logging:
      driver: "fluentd"
      options:
        # Dialled by the Docker daemon on the host, not over the compose network, hence the published port
        fluentd-address: "127.0.0.1:24224"
        # Start and keep running even while fluentd is down; lines are buffered and retried
        fluentd-async: "true"
        tag: "loki.my-app"

  fluentd:
    image: ghcr.io/jackdcasey/fluentd-loki:0.1.0
    restart: unless-stopped
    environment:
      - LOKI_URL=${LOKI_URL:?set in .env}
      - LOKI_USERNAME=${LOKI_USERNAME:-}
      - LOKI_PASSWORD=${LOKI_PASSWORD:-}
    ports:
      - "127.0.0.1:24224:24224"
    # Its own logs stay local, so a Loki problem can't hide the errors about it
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

`docker logs` still works on the app: Docker keeps a local copy alongside the remote driver.

Only one container per host can publish port 24224. To run several apps on one host, run this once per host and point every app's `fluentd-address` at it; the `loki.<job>` tag keeps them apart.

## Known limits

- Docker sends each output line separately, so a multi-line stack trace arrives as one entry per line.
- Log level isn't a label; filter in the query instead, e.g. `{job="my-app"} |= "ERROR"`.

## Releasing

Push a full semver tag (`v0.1.0`, not `v0.1`); CI builds and pushes the image and creates a GitHub release. New GHCR packages are private: hosts need `docker login ghcr.io`, or make the package public.

## Checking a config change

```
docker build -t fluentd-loki:test .
docker run --rm -e LOKI_URL=http://localhost:3100 fluentd-loki:test fluentd --dry-run -c /fluentd/etc/fluent.conf
```
