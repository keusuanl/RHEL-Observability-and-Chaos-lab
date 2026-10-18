SHELL := /usr/bin/bash

.PHONY: all build run smoke install-app install-monitoring validate-monitoring status incident-down incident-up evidence pause resume uninstall clean

all: build

build:
	mvn package

run:
	mvn spring-boot:run

smoke:
	curl --fail --silent --show-error http://localhost:8080/
	@printf '\n'
	curl --fail --silent --show-error http://localhost:8080/actuator/health
	@printf '\n'
	curl --fail --silent --show-error http://localhost:8080/actuator/prometheus > /dev/null
	@echo "Prometheus endpoint returned successfully"
install-app: build
	sudo bash scripts/install-app.sh

install-monitoring:
	sudo bash scripts/install-monitoring.sh

validate-monitoring:
	sudo /usr/local/bin/promtool check config /etc/prometheus/prometheus.yml
	sudo /usr/local/bin/promtool check rules /etc/prometheus/alerts.yml

status:
	systemctl is-active observer.service
	systemctl is-active prometheus.service
	systemctl is-active node_exporter.service
	systemctl is-active grafana-server.service

incident-down:
	sudo systemctl stop observer.service

incident-up:
	sudo systemctl start observer.service

evidence:
	mkdir -p evidence
	systemctl status observer.service > evidence/observer-status.txt || true
	journalctl -u observer.service -b > evidence/observer-journal.txt
	curl --fail --silent --show-error http://localhost:8080/actuator/health > evidence/observer-health.json || printf '{"status":"unreachable"}\n' > evidence/observer-health.json

pause:
	sudo systemctl stop observer.service prometheus.service node_exporter.service grafana-server.service

resume:
	sudo systemctl start node_exporter.service prometheus.service grafana-server.service observer.service

uninstall:
	sudo bash scripts/uninstall.sh

clean:
	mvn clean
