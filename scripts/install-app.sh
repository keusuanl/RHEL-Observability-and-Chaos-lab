#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if ! id -u observer >/dev/null 2>&1; then
    useradd -r -M -d /opt/observer -s /sbin/nologin observer
fi

install -d -m 0755 -o observer /opt/observer
install -m 0644 -o observer "$REPO_ROOT/target/observer-0.0.1-SNAPSHOT.jar" /opt/observer/observer.jar
install -m 0644 "$REPO_ROOT/systemd/observer.service" /etc/systemd/system/observer.service
restorecon -v /opt/observer/observer.jar /etc/systemd/system/observer.service
systemctl daemon-reload
systemctl enable --now observer.service
systemctl status observer.service
