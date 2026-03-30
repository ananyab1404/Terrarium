# Infinity Node Scheduler — DynamoDB Schema (v1)

This schema is optimized for Distributed Scheduler:

- exactly-once claim semantics with conditional writes,
- lease-based recovery,
- scalable queue-like scans,
- node-drain operations,
- dead-letter durability,
- future multi-tenant and multi-region growth.

## Design Principles

1. Use DynamoDB as the system of record for job lifecycle.
2. Use SQS for ingress buffering only.
3. Never transition state with eventually-consistent reads.
4. Keep indexes purpose-built for hot operational paths.
5. Include shard keys in state indexes to reduce partition hot-spots.
6. Include `schema_version` fields for non-breaking evolution.

---

## Table 1: `infinity-node-jobs-v1`

### Primary Key

- Partition key: `job_id` (String)

### Core Attributes

- `job_id` (S)
- `tenant_id` (S) — default `public`
- `state` (S) — `PENDING | SCHEDULED | DISPATCHED | RUNNING | TERMINAL`
- `schema_version` (N) — start with `1`
- `created_at` (N, epoch ms)
- `updated_at` (N, epoch ms)
- `priority` (N) — higher number means earlier routing
- `retry_count` (N)
- `max_retries` (N)
- `next_attempt_at` (N, epoch ms)
- `assigned_node` (S)
- `lease_expires_at` (N, epoch ms)
- `preferred_region` (S)
- `idempotency_key` (S)
- `artifact_ref` (M) — `{bucket, key, version_id, sha256}`
- `input_ref` (M) — `{bucket, key, content_type, size_bytes, sha256}`
- `resource_limits` (M) — `{cpu_millis, memory_mb, timeout_ms}`
- `result_ref` (M) — `{bucket, key, content_type, size_bytes, checksum}`
- `failure` (M) — `{code, category, message, retriable, details}`
- `telemetry_ref` (M) — `{trace_id, span_id, metrics_key}`
- `ttl_archive_at` (N, epoch sec, optional TTL)

### Index Projection Attributes (materialized fields)

- `gsi1_pk` (S) = `STATE#{state}#REGION#{preferred_region|global}#SHARD#{00..63}`
- `gsi1_sk` (S) = `LEASE#{lease_expires_at}#PRI#{priority}#JOB#{job_id}`
- `gsi2_pk` (S) = `NODE#{assigned_node}`
- `gsi2_sk` (S) = `LEASE#{lease_expires_at}#JOB#{job_id}`
- `gsi3_pk` (S) = `TENANT#{tenant_id}#STATE#{state}`
- `gsi3_sk` (S) = `CREATED#{created_at}#JOB#{job_id}`

### GSIs

1. **GSI1 `by_state_lease`** (`gsi1_pk`, `gsi1_sk`)
   - Used by scheduler scans for runnable jobs and lease reaper scans for expired jobs.
2. **GSI2 `by_node_lease`** (`gsi2_pk`, `gsi2_sk`)
   - Used for drain operations and node crash reconciliation.
3. **GSI3 `by_tenant_state_created`** (`gsi3_pk`, `gsi3_sk`)
   - Used for API/query and operations dashboards.

---

## Table 2: `infinity-node-idempotency-v1`

### Primary Key

- Partition key: `tenant_id` (S)
- Sort key: `idempotency_key` (S)

### Attributes

- `tenant_id` (S)
- `idempotency_key` (S)
- `job_id` (S)
- `request_hash` (S) — deterministic hash of normalized payload
- `created_at` (N, epoch ms)
- `expires_at` (N, epoch sec, TTL)
- `schema_version` (N)

### GSI

- **GSI1 `by_job_id`** (`job_id`, `created_at`)
  - Used to reverse-map for debugging and audits.

---

## Table 3: `infinity-node-deadletter-v1`

### Primary Key

- Partition key: `tenant_id` (S)
- Sort key: `failed_at_job` (S) = `FAILED#{failed_at_epoch_ms}#JOB#{job_id}`

### Attributes

- `tenant_id` (S)
- `failed_at_job` (S)
- `job_id` (S)
- `final_state` (S) — expected `TERMINAL`
- `retry_count` (N)
- `max_retries` (N)
- `failure` (M)
- `last_assigned_node` (S)
- `artifact_ref` (M)
- `input_ref` (M)
- `resource_limits` (M)
- `created_at` (N)
- `failed_at` (N)
- `schema_version` (N)
- `ttl_archive_at` (N, epoch sec, optional)

### GSI

- **GSI1 `by_job_id`** (`job_id`, `failed_at`)
  - Used by support and incident tooling.

---

## Access Pattern Mapping

1. Create job (new request)
   - Write idempotency row with `attribute_not_exists(tenant_id) AND attribute_not_exists(idempotency_key)`.
   - Put job row with `attribute_not_exists(job_id)`.

2. Claim job for dispatch
   - Update `infinity-node-jobs-v1` with condition `state = :scheduled AND (attribute_not_exists(lease_expires_at) OR lease_expires_at < :now)`.
   - Set `state=DISPATCHED`, `assigned_node`, `lease_expires_at`, `updated_at`.

3. Start execution
   - Condition: `state = :dispatched AND assigned_node = :node_id`.
   - Set `state=RUNNING`, extend lease.

4. Complete execution
   - Condition: `state = :running AND assigned_node = :node_id`.
   - Set `state=TERMINAL`, `result_ref` OR `failure`, `updated_at`.

5. Lease reaper scan
   - Query GSI1 where `gsi1_pk = STATE#RUNNING#REGION#...#SHARD#..` and `gsi1_sk < LEASE#{now}`.
   - Transition to `SCHEDULED` with conditional check against stale node/lease.

6. Node drain
   - Query GSI2 by `NODE#{node_id}`.
   - Stop assigning new jobs; reclaim stale leases; wait for `RUNNING=0`.

7. Dead-letter routing
   - If `retry_count >= max_retries`, write row into dead-letter table and set job `state=TERMINAL` with failure category `deadlettered`.

---

## Expandability Notes

- Multi-region: keep `preferred_region` and embed it in `gsi1_pk`.
- Multi-tenant: `tenant_id` already first-class in idempotency/dead-letter and query index.
- Priorities: encoded in `gsi1_sk`; can be tuned without schema migration.
- New states: append-only enum policy (never repurpose existing state string).
- Backfills: use `schema_version` for dual-read/dual-write migration windows.
- Archival: enable TTL + stream to S3 for long-term storage.

---

## Recommended Table Settings

- Billing mode: `PAY_PER_REQUEST` (on-demand) for early stage.
- Point-in-time recovery (PITR): enabled on all tables.
- DynamoDB Streams: enabled on jobs and dead-letter for audit + async processing.
- Encryption: AWS-managed KMS or CMK for compliance.
- Tags: `project=infinity-node`, `component=scheduler`, `owner=person-2`.
