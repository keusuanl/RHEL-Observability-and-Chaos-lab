# RHEL Observability Chaos Lab

This repository turns a working RHEL observability stack into a reproducible incident lab and simple SRE workflow.
Break something on purpose, watch it on the dashboard, find the cause, and recover and captured states with evidence.

#### Observer.service Baseline
![](/docs/images/baseline-grafana.png)

#### Prometheus Alert Rules
![](/docs/images/OOM-kill-Prom-alert.png)

#### Chaos Latency Spike
![](/docs/images/latency-grafana.png)

#### OOM-Killer - Cgroup Stimulated Incident
![](/docs/images/OOM-killer-journalctl-log-trace.png)

![](/docs/images/oom-serviceisdown-grafana.png)

## Project

This lab compares four failure domains:

- **Application:** the Spring Boot app is slow or returns errors.
- **Host:** the VM runs out of CPU, memory, or disk.
- **Service:** systemd stops or restarts the app.
- **cgroup:** the kernel enforces a resource limit, such as a memory cap.

Each experiment connects what a user would notice to the evidence behind it: metrics, service state, and kernel logs. Each one ends with a recovery.

## Architecture

```
curl  ->  Spring Boot observer  ->  Prometheus  ->  Grafana
                 |                      ^
          observer.service         node_exporter
           (systemd)             (host metrics)
```

- `curl` sends requests to the Spring Boot observer app.
- The app exposes Actuator metrics, and Prometheus scrapes them.
- `node_exporter` gives Prometheus the host metrics (CPU, memory, disk).
- Grafana turns the Prometheus data into application and host dashboards.
- `observer.service` keeps the app running under systemd.

## Safety Boundaries

- Run these experiments only in the isolated lab.
- The failure endpoints (`/slow`, `/error`, `/simulate-cpu`) have no login. The app listens on `127.0.0.1` only, so keep it that way. Never expose them to public or shared networks.
- Every run stops on its own after a set time (`DURATION`, 180 seconds by default).
- After each experiment, run `make status` and `make smoke` to confirm everything is healthy again.

## Quick Start

1. Go to the repository root.
2. Run `make chaos-check`. It passes if the observer is healthy and stops if it isn't.
3. Run `make smoke`. It checks `/`, `/actuator/health`, and `/actuator/prometheus`.
4. Check that Prometheus is up: `curl -s http://localhost:9090/-/ready`
5. Open Grafana through an SSH tunnel and open the observer dashboard:
   `ssh -L 3000:localhost:3000 -L 9090:localhost:9090 <user>@<vm-address>`
   then go to `http://localhost:3000`.

## Experiment Map

| Experiment | Hypothesis | Trigger | User symptom | Evidence | Recovery |
| --- | --- | --- | --- | --- | --- |
| Control baseline | A healthy system gives the comparison point for every failure run. | `make chaos-baseline DURATION=30` | Requests complete normally. | Grafana golden-signal panels, `/actuator/health` is `UP`. | Let the run finish. Confirm health is normal. |
| Application latency | If `/slow` takes longer, request time rises while `/actuator/health` stays `UP`. | `make chaos-latency MS=300 DURATION=30` | Requests are slow, but nothing is down. | Grafana latency panels, `/actuator/health`. | Let the run finish. Confirm latency returns to baseline. |
| HTTP 500 errors | If `/error` always fails, the error rate rises while the process stays healthy. | `make chaos-errors DURATION=30` | Some requests fail. The normal path still works. | Grafana error panels, `/actuator/health`. | Let the run finish. Confirm the error rate returns to baseline. |
| Application CPU work | If `/simulate-cpu` runs, one request thread is busy for about 10 seconds. | One request to `/simulate-cpu`. | That request is slow while it works. | Grafana application CPU panels. | Wait for the request to finish. Confirm CPU returns to baseline. |
| Host CPU pressure | If one busy loop runs, the host has less CPU headroom. It means full saturation only on a one-CPU host. | `make host-cpu-stress CPU_DURATION=30` | Little impact on a multi-core host. | Grafana host CPU panels. | Let the run finish. Confirm host CPU returns to baseline. |
| CPU quota throttling | If `observer.service` has a CPU limit, parallel busy requests are throttled and run slower. | Add `CPUQuota=` to a drop-in, then send four parallel `/simulate-cpu` requests. | Requests take much longer than 10 seconds. | Latency panels, throttling counters in the service's `cpu.stat`. | Remove the drop-in, reload systemd, restart. Run `make chaos-check`. |
| Service outage | If `observer.service` stops, the app is unavailable. | Use the existing stopped-service experiment. | Requests cannot connect. | systemd state, Prometheus target health, Grafana availability. | Follow the existing recovery steps. Run `make chaos-check`. |
| Cgroup memory OOM | If the app hits `memory.max`, the kernel kills it inside the cgroup. | Use the existing cgroup OOM experiment. | The app terminates or becomes unavailable. | journald, systemd, cgroup memory files. | Follow the existing rollback steps. Run `make chaos-check`. |

## Chaos Documentated Incident 
[Health Check Report](docs/experiments/health-check-blind-spot.md)

[Latency](docs/experiments/01-latency.md)

[Error](docs/experiments/02-error.md)

[OOM-Killer-CGroup](docs/experiments/03-cgroup.oom.md)
