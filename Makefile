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

# ---- Chaos runs (golden-signal experiments) ----
.PHONY: chaos-help chaos-check chaos-baseline chaos-latency chaos-errors

BASE     ?= http://localhost:8080
DURATION ?= 180
MS       ?= 300

chaos-help:
	@echo "make chaos-baseline [DURATION=120]        normal traffic only"
	@echo "make chaos-latency  [MS=300 DURATION=180] slow requests"
	@echo "make chaos-errors   [DURATION=180]        50% failing requests"

chaos-check:
	@curl -sf $(BASE)/actuator/health > /dev/null || { echo "observer is not healthy, stopping"; exit 1; }

chaos-baseline: chaos-check
	@echo "[$$(date +%T)] BASELINE start, $(DURATION)s"
	@timeout --foreground $(DURATION) bash -c 'while true; do curl -s -o /dev/null $(BASE)/; sleep 0.2; done' || true
	@echo "[$$(date +%T)] BASELINE end"

chaos-latency: chaos-check
	@echo "[$$(date +%T)] LATENCY start: /slow?ms=$(MS), $(DURATION)s"
	@timeout --foreground $(DURATION) bash -c 'while true; do curl -s -o /dev/null "$(BASE)/slow?ms=$(MS)" & sleep 0.2; done' || true
	@echo "[$$(date +%T)] LATENCY end"

chaos-errors: chaos-check
	@echo "[$$(date +%T)] ERRORS start: 50% failing, $(DURATION)s"
	@timeout --foreground $(DURATION) bash -c 'while true; do curl -s -o /dev/null $(BASE)/; curl -s -o /dev/null $(BASE)/error; sleep 0.2; done' || true
	@echo "[$$(date +%T)] ERRORS end"

	# ============================================================
# HOST INCIDENT 01 — CPU saturation
# Generate bounded CPU load on infra01 using Bash.
# ============================================================

.PHONY: host-cpu-stress

CPU_DURATION ?= 30

host-cpu-stress:
	@echo "Starting CPU stress for $(CPU_DURATION)s"
	@timeout --foreground $(CPU_DURATION) bash -c \
		'while :; do :; done'
		
		
