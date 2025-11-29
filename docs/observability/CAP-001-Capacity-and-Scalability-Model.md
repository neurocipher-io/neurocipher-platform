---
id: CAP-001
title: Capacity and Scalability Model
owner: Platform SRE
status: Draft
last_reviewed: 2025-11-20
---

# CAP-001 Capacity and Scalability Model

## 1. Purpose

Capture the baseline throughput and resource assumptions for every major service in the Neurocipher Platform so SLOs, alerts, and CI/OPS gates all reference the same capacity/cost story (see OBS-001 §5, REL-002 §4, OPS-001 §9, CI/CL-001..003, PERF-001..005).

## 2. Baseline throughput targets

| Surface | QPS / throughput target | Notes |
|---|---|---|
| **Ingest API (`/ingest/event`)** | 500 QPS steady, bursts to 2k (per plan). | Gateway throttles per plan (`Free/Pro/Enterprise`); per-tenant quotas recorded in SEC-005 §7. |
| **Query API (`/query` + Vector search)** | 800 QPS hybrid (Weaviate + OpenSearch). | Sustains 400 QPS to Weaviate `NcChunkV1` and 400 QPS to OpenSearch; p95 latency ≤ 200 ms. |
| **Security actions** | 20 QPS command ingress, 1k QPS status poll. | Idempotency guard and Security Engine event fan-out must keep 5xx below 0.5%. |
| **Batch / reindex jobs** | 200 concurrent workers (Fargate/Lambda). | Normalization jobs process up to 100 documents per worker and produce 5k vector writes/sec total. |

## 3. Stream & queue headroom

- **SQS ingest queue**: target approximate age < 60s, alarm at 120s (OBS-002). Scale factor = 3× burst demand.
- **EventBridge / Kafka**: custom `ingest_events_total` ensures cross-service fan-out stays within 2% of service bus capacity.
- **Backpressure threshold**: when queue depth exceeds 2 min worth of messages (per plan), API returns `429 RATE_LIMITED` referencing `X-RateLimit-*`.

## 4. Weaviate `NcChunkV1` capacity

- **Throughput**: baseline 5k vector upserts/sec across 3 replicas; linear scale by adding shards when a single shard reaches 70% of 50 GB capacity (see PERF-005).
- **Index growth**: per-tenant `document_chunk` rows convert to `NcChunkV1` objects with RC2 retention (2 years). Monthly growth tracked via `weaviate_index_growth_bytes`.
- **Metrics**: `weaviate_query_duration_seconds`, `weaviate_upsert_latency_seconds`, `weaviate_replica_health`, `vector_write_latency_ms`.

## 5. Cost levers and assumptions

- **Compute**: ECS Fargate for query/embedding, Lambda for normalization; trickle 1 vCPU per worker, 2 GB memory, auto-scaling reaction at 70% CPU.
- **Storage**: S3 (normalized, raw, DLQ) with lifecycle (hot 7 days, warm 365), Postgres for metadata with RCUs sized for 5M rows/tenant, Weaviate for vectors (replication factor 3, hot 30d, warm 90d).
- **Network**: NAT gateway egress capped at 5 TB/month per account; use PrivateLink and VPC endpoints to minimize additional charges.
- **CI/CD pipeline impact**: `Reusable CI` (docs/ci/CI-001 §19) uses pre-deploy load and stress tests tuned to these throughput numbers; failure of capacity validations gates merges (CI/CL-001..003).

## 6. References

- OBS-001 Observability strategy (SLO alignment)
- OBS-002 Dashboards and tracing (vector metrics)
- REL-002 Incident response context (alert thresholds)
- OPS-001 SRE and ops controls (alert fatigue/backoff)
- CI-001..CI-003 Reusable workflow validations
- PERF-001..PERF-005 Performance, cost, and capacity planning
