#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

case "$(uname -m)" in
    x86_64)
        PROM_ARCH=amd64
        GRAFANA_RPM=https://dl.grafana.com/grafana/release/13.2.4/grafana_13.2.4_38252365904_linux_amd64.rpm
        ;;
    aarch64)
        PROM_ARCH=arm64
        GRAFANA_RPM=https://dl.grafana.com/grafana/release/13.2.4/grafana_13.2.4_38252365904_linux_arm64.rpm
        ;;
    *)
        echo "Supported architectures are x86_64 and aarch64."
        exit 1
        ;;
esac

PROMETHEUS_URL="https://github.com/prometheus/prometheus/releases/download/v3.15.0/prometheus-3.15.0.linux-${PROM_ARCH}.tar.gz"
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v1.12.1/node_exporter-1.12.1.linux-${PROM_ARCH}.tar.gz"

curl --fail --location --show-error --silent --output "$TMP_DIR/prometheus.tar.gz" "$PROMETHEUS_URL"
curl --fail --location --show-error --silent --output "$TMP_DIR/node_exporter.tar.gz" "$NODE_EXPORTER_URL"

(
    cd "$TMP_DIR"
    tar xzvf prometheus.tar.gz
    tar xzvf node_exporter.tar.gz
)

if ! id -u prometheus >/dev/null 2>&1; then
    useradd -r -M -d /var/lib/prometheus -s /sbin/nologin prometheus
fi
if ! id -u node_exporter >/dev/null 2>&1; then
    useradd -r -M -s /sbin/nologin node_exporter
fi

install -m 0755 "$TMP_DIR/prometheus-3.15.0.linux-${PROM_ARCH}/prometheus" /usr/local/bin/prometheus
install -m 0755 "$TMP_DIR/prometheus-3.15.0.linux-${PROM_ARCH}/promtool" /usr/local/bin/promtool
install -m 0755 "$TMP_DIR/node_exporter-1.12.1.linux-${PROM_ARCH}/node_exporter" /usr/local/bin/node_exporter

install -d -m 0755 /etc/prometheus
install -d -m 0755 -o prometheus /var/lib/prometheus
install -m 0644 "$REPO_ROOT/monitoring/prometheus.yml" /etc/prometheus/prometheus.yml
install -m 0644 "$REPO_ROOT/monitoring/alerts.yml" /etc/prometheus/alerts.yml
install -m 0644 "$REPO_ROOT/systemd/prometheus.service" /etc/systemd/system/prometheus.service
install -m 0644 "$REPO_ROOT/systemd/node_exporter.service" /etc/systemd/system/node_exporter.service

/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml
/usr/local/bin/promtool check rules /etc/prometheus/alerts.yml

dnf install -y "$GRAFANA_RPM"
install -d -m 0755 /etc/grafana/provisioning/datasources
install -d -m 0755 /etc/grafana/provisioning/dashboards
install -d -m 0755 -o grafana -g grafana /var/lib/grafana/dashboards
install -m 0644 "$REPO_ROOT/monitoring/grafana/datasources/prometheus.yml" /etc/grafana/provisioning/datasources/prometheus.yml
install -m 0644 "$REPO_ROOT/monitoring/grafana/dashboards/provider.yml" /etc/grafana/provisioning/dashboards/provider.yml
for f in "$REPO_ROOT"/monitoring/grafana/dashboards/*.json; do install -m 0644 -o grafana -g grafana "$f" /var/lib/grafana/dashboards/; done
install -d -m 0755 /etc/systemd/system/grafana-server.service.d
install -m 0644 "$REPO_ROOT/systemd/grafana-override.conf" /etc/systemd/system/grafana-server.service.d/override.conf

restorecon -v /usr/local/bin/prometheus /usr/local/bin/promtool /usr/local/bin/node_exporter
restorecon -v /etc/systemd/system/prometheus.service /etc/systemd/system/node_exporter.service
restorecon -R -v /etc/prometheus /etc/grafana/provisioning /var/lib/grafana/dashboards

systemctl daemon-reload
systemctl enable --now node_exporter.service prometheus.service grafana-server.service
systemctl status node_exporter.service
systemctl status prometheus.service
systemctl status grafana-server.service
