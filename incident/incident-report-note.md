
# Incident Report 1: Port Conflict on 9090 (RHEL Cockpit vs. Prometheus)

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


# Incident Report 2: Observer service unavailable

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


# Incident Report 3: JVM Boot Failure via Aggressive systemd Resource Constraints

### Symptom
Created an incident stimulated chaos test by applying a resource limit configuration, the `observer` service repeatedly crashed during startup, alternating between `oom-kill` and JVM initialization failures.

### Diagnostics
Using `journalctl`, I captured the systemd lifecycle logs around 7:04:35 PM UTC:

```bash
sudo journalctl -u observer.service -n 50 --no-pager
```

The logs revealed a two-stage failure pattern:
1. **cgroup Enforcement:** The process was initially terminated by the kernel with exit status `9/KILL (oom-kill)` because it exceeded memory allocations.
2. **JVM Guardrails:** On restart, the JVM recognized the strict resource ceiling and aborted execution with the error: `Error occurred during initialization of VM: Too small maximum heap`.

Investigating the service configuration, I checked the drop-in override files:
```bash
cat /etc/systemd/system/observer.service.d/observer-memory-limit.conf
```
The parameter `MemoryMax` had been set to `1500K` (1.5MB), which is far below the mandatory bootstrap requirements for a Java runtime environment.

### Resolution
1. Removed the restrictive drop-in configuration file to restore the `MemoryMax` allocation to default (`infinity`).
2. Reloaded systemd and restarted the app:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart observer.service
   ```
3. Verified the service stabilized and was successfully listening on port 8080.

### Takeaway
Java runtimes are container-aware and read system resource boundaries (cgroups v2) to size their memory pools. When enforcing OS-level constraints via systemd, resource limits must account for both the application workload *and* the baseline virtualization overhead of the Java Virtual Machine itself (typically requiring at least 64MB-128MB to boot).
