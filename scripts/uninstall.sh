#!/usr/bin/env bash
set -euo pipefail

systemctl disable --now observer.service prometheus.service node_exporter.service grafana-server.service || true
rm -f /etc/systemd/system/observer.service
rm -f /etc/systemd/system/prometheus.service
rm -f /etc/systemd/system/node_exporter.service
rm -rf /etc/systemd/system/observer.service.d
rm -rf /etc/systemd/system/grafana-server.service.d
rm -f /usr/local/bin/prometheus /usr/local/bin/promtool /usr/local/bin/node_exporter
rm -rf /opt/observer /etc/prometheus /var/lib/prometheus
rm -f /etc/grafana/provisioning/datasources/prometheus.yml
rm -f /etc/grafana/provisioning/dashboards/provider.yml
rm -f /var/lib/grafana/dashboards/observable-linux-service.json
dnf remove -y grafana || true
userdel observer 2>/dev/null || true
userdel prometheus 2>/dev/null || true
userdel node_exporter 2>/dev/null || true
systemctl daemon-reload
