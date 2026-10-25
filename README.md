# fluentd-loki

A ready-to-run Fluentd that ships Docker container logs to [Grafana Loki](https://grafana.com/oss/loki/), configured entirely by env vars. Point it at a Loki, tag your containers, and their logs show up in Grafana: no Fluentd config to write.

Image: `ghcr.io/jackdcasey/fluentd-loki`, for `linux/arm64`. It's the official `fluent/fluentd` image plus [Grafana's Loki output plugin](https://grafana.com/docs/loki/latest/send-data/fluentd/) (`fluent-plugin-grafana-loki`). Grafana's own `grafana/fluent-plugin-loki` image is amd64-only and needs a config file; this one runs on ARM and needs only env vars.

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

Push a full semver tag (`v0.1.0`, not `v0.1`); CI builds and pushes the image and creates a GitHub release. The `v0.1` form is silently skipped by the tag metadata step.

## Checking a config change

```
docker build -t fluentd-loki:test .
docker run --rm -e LOKI_URL=http://localhost:3100 fluentd-loki:test fluentd --dry-run -c /fluentd/etc/fluent.conf
```
