# Loki Log Aggregation Setup

## Overview

Grafana Loki collects container logs from the Nomad-scheduled NGINX
application. Promtail discovers containers via the Docker socket and
ships their stdout/stderr streams into Loki. Grafana queries Loki
using LogQL.

Components:

| Component | Image                  | Purpose     |
|-----------|------------------------|-------------|
| Loki      | grafana/loki:3.2.0     | Log store   |
| Promtail  | grafana/promtail:3.2.0 | Log shipper |
| Grafana   | grafana/grafana:11.2.0 | Query UI    |

All three run via `monitoring/docker-compose.yaml` on a shared bridge
network. Data persists in the named volumes `loki-data` and
`grafana-data`.

## Starting the stack

    cd monitoring
    docker compose up -d
    docker compose ps

Observed `docker compose ps`:

    NAME       IMAGE                    STATUS
    grafana    grafana/grafana:11.2.0  Up 5 minutes
    loki       grafana/loki:3.2.0      Up 5 minutes
    promtail   grafana/promtail:3.2.0  Up 5 minutes

Promtail logs confirmed successful startup and discovery of container
targets:

    level=info msg="Starting Promtail" version="(version=k218-659f542, branch=k218, revision=659f5421)"
    level=info msg="added Docker target" containerID=0fce8f32fffafcc3f3557eae44ff2e3b325c6b24cf8dd467a848fdc201704f1f
    level=info msg="added Docker target" containerID=0dfd79ba999bf60949482ac49152d2038b296c28eb17e32a4bfff87b5fa62cf8
    level=info msg="added Docker target" containerID=1a3d1ba2b32a6ee6244d0a43112366a5ef8bf6664376805a4b07606bc46d9748
    level=info msg="added Docker target" containerID=a6e724a35f2b25d743c459bb285023c587b17bb2e2d219fb8e06b5a9b22fdbe5

## Label set

Promtail applies the following labels to every log stream:

| Label           | Source                                                          | Example                                      |
|-----------------|-----------------------------------------------------------------|----------------------------------------------|
| job             | static (set in promtail-config.yaml)                            | docker                                       |
| container       | `__meta_docker_container_name` (leading slash stripped)         | nginx-a521df9c-516d-fcb6-72dd-3ddf4523ad07   |
| service_name    | `__meta_docker_container_label_com_docker_compose_service`      | nginx-a521df9c-516d-fcb6-72dd-3ddf4523ad07   |
| nomad_alloc_id  | `__meta_docker_container_label_com_hashicorp_nomad_alloc_id`    | a521df9c-516d-fcb6-72dd-3ddf4523ad07         |
| stream          | `__meta_docker_container_log_stream`                            | stdout                                       |

Labels observed via `curl http://localhost:3100/loki/api/v1/labels`:

    ["container","job","nomad_alloc_id","service_name","stream"]

## LogQL queries executed

### 1. Confirm ingestion

    {job="docker"}

Result: streams returned for `loki`, `grafana`, `promtail`, and the
Nomad nginx container — proving Promtail is shipping from all four
discovered targets.

### 2. Isolate NGINX access logs

    {container=~".*nginx.*"}

Result: only the Nomad NGINX container's stdout stream returned.

### 3. Filter non-200 responses

    {container=~".*nginx.*"} |= "404"

Result (after deliberately requesting a missing path):

    2026-09-12 01:34:36.046  172.17.0.1 - - [12/Sep/2026:00:34:36 +0000] "GET /this-does-not-exist HTTP/1.1" 404 153 "-" "curl/7.81.0"

The stream carried the following labels:

    container=nginx-a521df9c-516d-fcb6-72dd-3ddf4523ad07
    job=docker
    nomad_alloc_id=a521df9c-516d-fcb6-72dd-3ddf4523ad07
    service_name=nginx-a521df9c-516d-fcb6-72dd-3ddf4523ad07
    stream=stdout

### 4. Error rate over time

    sum(rate({container=~".*nginx.*"} |= " 404 " [1m]))

Result: 404 rate spikes to a non-zero value immediately after issuing
a request for a missing path, then decays back to zero.

## Problems encountered and resolutions

### 1. Loki was not selected as the Grafana data source

- Symptom: Grafana Explore defaulted to the built-in `-- Grafana --`
  test data source and displayed a random-walk graph instead of logs.
- Cause: Loki had not yet been added as a data source in Grafana.
- Fix: Explore → data source dropdown → Add new data source → Loki →
  URL `http://loki:3100` → Save & test. Confirmed by the message
  "Data source connected and labels found."

### 2. Loki readiness took ~15 seconds after startup

- Symptom: `curl http://localhost:3100/ready` initially returned
  `Ingester not ready: waiting for 15s after being ready`.
- Cause: Loki's ingester has a built-in readiness ramp-up period.
- Fix: none required — this is expected behaviour. Polled `/ready`
  until it returned `ready` before issuing queries.

### 3. Promtail target discovery briefly returned no containers

- Symptom: the first few seconds after `docker compose up` showed no
  `added Docker target` log lines.
- Cause: Promtail's `docker_sd_configs` refresh interval is 5 seconds.
- Fix: waited one refresh cycle and re-checked
  `docker compose logs promtail`. New containers are automatically
  picked up within 5 seconds.

## Notes

- Loki and Grafana data persist in Docker named volumes. To wipe
  everything including log history: `docker compose down -v`.
- Grafana anonymous access is enabled purely for local evaluation.
  Real deployments should require authentication and TLS.
- Loki retention is set to 24 hours
  (`limits_config.retention_period`) to keep disk usage bounded
  during the assessment.
- The Nomad-launched container receives its `nomad_alloc_id` label
  automatically because Nomad sets the
  `com.hashicorp.nomad.alloc_id` Docker label on every allocation.
  This means logs from any future Nomad job are labelled for free —
  no Promtail reconfiguration needed.
