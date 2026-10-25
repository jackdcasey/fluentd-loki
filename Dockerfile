# Fluentd with Grafana's Loki output plugin (https://grafana.com/docs/loki/latest/send-data/fluentd/),
# configured entirely by env vars so any service can use it. See README.md.
# Built from the official multi-arch image because grafana/fluent-plugin-loki is amd64-only.
# The plugin is pure Ruby, so no build tools are needed.
FROM fluent/fluentd:v1.19.4-debian-2.2

USER root
RUN fluent-gem install fluent-plugin-grafana-loki -v 1.3.0 --no-document
COPY fluent.conf /fluentd/etc/fluent.conf
USER fluent
