
# Incident 1: Port Conflict on 9090 (RHEL Cockpit vs. Prometheus)

### Symptom
During deployment of the monitoring stack, the `prometheus` service failed to start and remained in a crashed state.

### Diagnostics
To investigate, I used `systemctl` to check the service health and extracted the exact daemon logs using `journalctl`:

```bash
# Check service state
sudo systemctl status prometheus.service

# Inspect system logs for Prometheus
sudo journalctl -u prometheus.service -n 50 --no-pager
```

The journal logs highlighted a network binding error: 
`address already in use 0.0.0.0:9090`

I then ran a socket scan to find what was occupying the port:
```bash
sudo ss -tulpn | grep 9090
```
This confirmed that RHEL's default system management interface, **Cockpit** (`cockpit.socket`), was actively listening on port 9090.

### Resolution
1. Moved Prometheus to port **9093** by appending `--web.listen-address=127.0.0.1:9093` to the execution command in the systemd unit file.
2. Updated the scrape configuration in `prometheus.yml` and the datasource path in Grafana's `prometheus.yml` to target `localhost:9093`.
3. Reloaded systemd and restarted the services:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart prometheus.service
   ```

### Linux Administration Takeaway
RHEL systems have Cockpit enabled on port 9090 by default. When deploying Prometheus on RHEL workstations, port 9093 should be used as the standard fallback to avoid socket allocation conflicts.


# Incident 2: Observer service unavailable

Start time: Recorded during the controlled outage exercise.
Detection source: Prometheus target status and InstanceDown alert.
Alert state: FIRING after the observer target remained down for more than five minutes; resolved after recovery.
User impact: The loopback-only observer endpoint and Actuator endpoints were unavailable while observer.service was stopped.

## Evidence

- systemd state: observer.service was inactive after make incident-down and active after make incident-up.
- Journal evidence: journalctl -u observer.service -b captured stop and subsequent startup records.
- Listening socket evidence: no listener was present during the outage; Java listened on 127.0.0.1:8080 after recovery.
- cgroups evidence: observer.service was inspected under /sys/fs/cgroup/system.slice/observer.service.
- Prometheus target state: up{job="observer"} changed from 1 to 0 during the outage and returned to 1 after recovery.
- Grafana screenshot: 05-target-down.png, 06-alert-firing.png, and 07-service-recovered.png.

## Root cause

The service was deliberately stopped as part of the controlled incident exercise.

## Mitigation

The service was started through systemd and validated through the endpoint, Prometheus target, alert state, and Grafana dashboard.

## Prevention and follow-up

- Keep availability alerts and dashboard provisioning under version control.
- Preserve command output and screenshots with the incident record.
- Add application-level resilience only after the infrastructure baseline is understood.
