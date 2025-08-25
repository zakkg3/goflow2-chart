# GoFlow2 NetFlow/sFlow/IPFIX Kubernetes Pipeline

A production-ready Helm chart for deploying a complete network flow monitoring pipeline on Kubernetes.

## Overview

This chart deploys a full stack for collecting, processing, storing and visualizing network flow data (NetFlow v5/v9, sFlow, IPFIX) from routers and switches.

## Architecture

```
Network Devices → GoFlow2 → Kafka → ClickHouse → Grafana
                     ↓
                 Prometheus (metrics)
```

- **GoFlow2**: High-performance flow collector that receives flows and outputs protobuf to Kafka
- **Kafka**: Message queue for reliable buffering and horizontal scaling (using KRaft mode, no Zookeeper)
- **ClickHouse**: Column-oriented database optimized for analytics and time-series data
- **Grafana**: Dashboards for visualizing flow data and metrics
- **Prometheus**: Monitoring GoFlow2 health and performance metrics

## Features

- Supports NetFlow v5/v9, sFlow, and IPFIX protocols
- Automatic protobuf schema management
- Pre-configured Grafana dashboards showing:
  - Traffic volume over time
  - Top talkers by IP
  - Protocol distribution
  - Top destination ports
- Handles both sampled and unsampled flows
- Persistent storage for flow data
- Timezone-aware data processing

## Prerequisites

- Kubernetes 1.19+
- Helm 3+
- Default StorageClass configured for persistent volumes

## Installation

```bash
# Add the chart repository (if published)
helm repo add goflow2 https://example.com/charts
helm repo update

# Install the chart
helm install netflow-pipeline ./goflow2-chart \
  --namespace netflow-system \
  --create-namespace
```

## Configuration

Key configuration options in `values.yaml`:

```yaml
goflow2:
  enabled: true
  image:
    tag: v2.2.2  # Important: v2.2.3+ has protobuf issues with Kafka
  config:
    netflow:
      enabled: true
      port: 2055
    sflow:
      enabled: true
      port: 6343

kafka:
  enabled: true
  kraft:
    enabled: true  # Using KRaft mode (no Zookeeper)

clickhouse:
  enabled: true
  auth:
    password: "changeme"  # Change in production

grafana:
  enabled: true
  adminPassword: admin  # Change in production
  service:
    type: LoadBalancer  # Or ClusterIP with ingress
```

## Usage

### Configure Network Devices

Configure your routers/switches to send flows to the GoFlow2 service:

```bash
# Get the external IP (if using LoadBalancer)
kubectl get svc -n netflow-system netflow-pipeline-goflow2

# Configure your device to send:
# - NetFlow to <IP>:2055
# - sFlow to <IP>:6343
```

### Access Grafana

```bash
# Get Grafana URL
kubectl get svc -n netflow-system netflow-pipeline-grafana

# Default credentials: admin/admin
```

### Query ClickHouse Directly

```bash
# Connect to ClickHouse
kubectl exec -it -n netflow-system netflow-pipeline-clickhouse-shard0-0 -- clickhouse-client

# Example queries
SELECT count(*) FROM netflow.flows_raw;

SELECT 
    IPv4NumToString(reinterpretAsUInt32(reverse(substring(src_addr, 1, 4)))) as src_ip,
    sum(bytes) as total_bytes
FROM netflow.flows_raw 
GROUP BY src_addr 
ORDER BY total_bytes DESC 
LIMIT 10;
```

## Important Notes


### Timestamp Handling
GoFlow2 sends nanosecond timestamps which must be converted using `fromUnixTimestamp64Nano()` in ClickHouse to avoid overflow errors.

### IP Address Format
IP addresses are stored as FixedString(16) to support both IPv4 and IPv6. IPv4 addresses use the first 4 bytes.

### Sampling Rate
Many flows have `sampling_rate=0`. Dashboard queries handle this by using `if(sampling_rate > 0, sampling_rate, 1)`.

## Testing

### Generate Test Flow Data

To test the pipeline with simulated flow data:

```bash
# Generate NetFlow v5 data (port 2055)
podman run --rm -it --network host docker.io/networkstatic/nflow-generator -t <GOFLOW2_IP> -p 2055

# Or using Docker
docker run --rm -it --network host networkstatic/nflow-generator -t <GOFLOW2_IP> -p 2055
```

### Verify Data Flow

```bash
# Check GoFlow2 is receiving flows
kubectl logs -n netflow-system deployment/netflow-pipeline-goflow2 | tail -20

# Check Kafka has messages
kubectl exec -n netflow-system netflow-pipeline-kafka-controller-0 -- \
  kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic flows --max-messages 1

# Verify ClickHouse is consuming from Kafka
kubectl exec -n netflow-system netflow-pipeline-clickhouse-shard0-0 -- \
  clickhouse-client --user=default --password=1234 --query "SELECT count(*) FROM netflow.flows_raw"
```

### Example ClickHouse Queries

```sql
-- Traffic over time (bits per second)
SELECT 
    toStartOfMinute(time_received_ns) AS time, 
    sum(bytes * if(sampling_rate > 0, sampling_rate, 1) * 8) / 60 as bits_per_second 
FROM netflow.flows_raw 
WHERE time_received_ns > now() - INTERVAL 1 HOUR 
GROUP BY time 
ORDER BY time;

-- Top Source IPs by traffic
SELECT 
    IPv4NumToString(reinterpretAsUInt32(reverse(substring(src_addr, 1, 4)))) as SrcAddr, 
    sum(bytes * if(sampling_rate > 0, sampling_rate, 1)) as TotalBytes 
FROM netflow.flows_raw 
WHERE time_received_ns > now() - INTERVAL 1 HOUR 
GROUP BY src_addr 
ORDER BY TotalBytes DESC 
LIMIT 10;

-- Protocol distribution
SELECT 
    if(proto = 6, 'TCP', if(proto = 17, 'UDP', if(proto = 1, 'ICMP', toString(proto)))) as Protocol,
    sum(bytes * if(sampling_rate > 0, sampling_rate, 1)) as TotalBytes
FROM netflow.flows_raw 
WHERE time_received_ns > now() - INTERVAL 1 HOUR 
GROUP BY proto 
ORDER BY TotalBytes DESC;

-- Top destination ports
SELECT 
    dst_port, 
    sum(bytes * if(sampling_rate > 0, sampling_rate, 1)) as TotalBytes 
FROM netflow.flows_raw 
WHERE time_received_ns > now() - INTERVAL 1 HOUR 
    AND dst_port < 1024 
GROUP BY dst_port 
ORDER BY TotalBytes DESC 
LIMIT 10;
```

## Troubleshooting

### No data in Grafana dashboards
1. Check GoFlow2 is receiving flows: `kubectl logs -n netflow-system deployment/netflow-pipeline-goflow2`
2. Verify Kafka has messages: `kubectl exec -n netflow-system netflow-pipeline-kafka-controller-0 -- kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic flows --max-messages 1`
3. Check ClickHouse tables: `kubectl exec -n netflow-system netflow-pipeline-clickhouse-shard0-0 -- clickhouse-client --query "SELECT count(*) FROM netflow.flows_raw"`

### ClickHouse materialized view not working
The view might have the wrong consumer group offset. Recreate it:
```sql
DROP TABLE netflow.flows_raw_view;
DROP TABLE netflow.flows;
-- Then recreate using the init script
```

### Grafana panels show wrong data
Ensure panels have `format: "table"` set in the query configuration, not `format: "time_series"`.

## Development

To modify and test locally:

```bash
# Lint the chart
helm lint .

# Dry run to see generated manifests
helm install netflow-pipeline . --dry-run --debug

# Upgrade existing deployment
helm upgrade netflow-pipeline .
```

## Credits

This Helm chart is based on the [GoFlow2 KCG Docker Compose example](https://github.com/netsampler/goflow2/tree/main/compose/kcg) but adapted for Kubernetes deployment.

Built using:
- [GoFlow2](https://github.com/netsampler/goflow2) by NetSampler
- [Bitnami Kafka Chart](https://github.com/bitnami/charts/tree/main/bitnami/kafka)
- [Altinity ClickHouse Chart](https://github.com/Altinity/clickhouse-helm)
- [Grafana Helm Chart](https://github.com/grafana/helm-charts)

## License

MIT