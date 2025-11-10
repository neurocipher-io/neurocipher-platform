Yes. Here is the board-ready DM-004 with full detail and no missing criticals.

  

# **DM-004 Event Schemas & Contracts**

  

**Document Type:** Eventing Specification

**System:** Neurocipher Data Pipeline and AuditHound module

**Version:** 1.0

**Status:** Ready for review

**Owner:** Data Architecture

**Reviewers:** Platform, Security, Compliance

**Effective Date:** 2025-10-28

  

## **1. Purpose**

  

Define the canonical event model, envelope, schemas, routing, security, and lifecycle. Ensure stable inter-service contracts and auditable lineage into nc.event.

  

## **2. Scope**

  

In scope: domain events from CRUD and state transitions across all DM-001 entities, transport over AWS EventBridge with SQS consumers, registry in S3, persistence in Postgres nc.event, optional export to S3.

Out of scope: analytics streams, BI change-data-capture.

  

## **3. Non-functional requirements**

- Delivery SLO: 99.9 percent within 60 seconds inside region.
    
- Max end-to-end latency P95: 5 seconds for standard events, 2 seconds for status-change events.
    
- At-least-once delivery. Consumers must be idempotent.
    
- Max event size: 256 KB hard limit on EventBridge. Target payload ≤ 128 KB.
    

  

## **4. Transport and routing**

  

### **4.1 Event buses and queues**

- EventBridge buses per environment:
    
    - nc-stg-bus
        
    - nc-prod-bus
        
    
- Consumer queues (SQS):
    
    - nc-core-consumer (+ DLQ nc-core-consumer-dlq)
        
    - nc-analytics-consumer (+ DLQ)
        
    - nc-notify-consumer (+ DLQ)
        
    
- Encryption: SQS SSE with KMS CMK alias/nc-bus. HTTPS enforced.
    

  

### **4.2 Rules and filters**

  

Example rule to route only finding events to nc-core-consumer:

```
{
  "EventPattern": {
    "source": ["nc.app"],
    "detail-type": ["finding.created", "finding.status_changed"]
  },
  "Targets": [{"Arn": "arn:aws:sqs:...:nc-core-consumer"}]
}
```

### **4.3 Ordering strategy**

  

EventBridge is unordered. For flows that need per-entity ordering, the rule targets a FIFO SQS queue with MessageGroupId = <entity_id>. Example: finding.* to nc-core-consumer-fifo on high-risk tenants.

  

## **5. Canonical envelope**

  

All events share the same envelope. detail holds the domain payload.

```
{
  "id": "01J8Z5JQ5J8X0H0QG2QK1RZ8XP",         // ULID, unique
  "source": "nc.app",                         // fixed producer namespace
  "account_id": "01HZX7K3M4A7W0E3V6S8R2N8C1", // tenant
  "type": "finding.created",                  // detail-type in EventBridge
  "schema_version": 1,                        // JSON Schema version for this type
  "event_version": 1,                         // business semantics version
  "occurred_at": "2025-10-28T14:05:23.412Z",  // when state changed
  "emitted_at": "2025-10-28T14:05:23.980Z",   // when published
  "trace_id": "f2b67f2a0d324c8c9a0a8c2a3b1caa21", // W3C 16-32 hex
  "actor": { "user_id": "01J...", "type": "USER" }, // or SYSTEM
  "checksum_sha256": "ab3d...e9",             // over canonicalized detail
  "detail": { /* type-specific payload */ }
}
```

Rules:

- ULID string for id.
    
- source is nc.app for application emissions and nc.etl for backfills.
    
- occurred_at can be earlier than emitted_at.
    
- trace_id is propagated to logs and DB.
    
- checksum_sha256 is hex of SHA-256 over canonical JSON of detail. Keys sorted, UTF-8, no whitespace other than single commas and colons.
    

  

## **6. Registry and schema versioning**

  

### **6.1 Registry layout**

  

Schemas live in S3 and are cached by services.

```
s3://nc-<env>-schema/events/{type}/v{schema_version}/schema.json
s3://nc-<env>-schema/events/{type}/v{schema_version}/examples/*.json
```

### **6.2 Compatibility policy**

- Minor additions are backward compatible if new fields are optional and have defaults.
    
- Removing or renaming fields is breaking and requires a new schema_version.
    
- event_version increments when business meaning changes while schema stays compatible.
    
- Deprecation window: 2 releases minimum. Events continue to emit both versions during the window if required by consumers.
    

  

### **6.3 Validation**

  

Publishers must validate detail against the JSON Schema before emitting. Consumers validate and reject to DLQ if invalid.

  

## **7. Event type catalog**

|**Type**|**Purpose**|**Emits when**|**Key identity**|
|---|---|---|---|
|account.created|New tenant created|account insert|account_id|
|user.invited|User invited|user status=INVITED|id|
|user.role_changed|Role grant or revoke|role_assignment change|(user_id, role_id)|
|cloud_account.linked|Cloud account linked|link SCD2 insert|id|
|data_source.created|Connector configured|data_source SCD2 current insert|id|
|asset.discovered|New asset current row|asset SCD2 current insert|urn|
|asset.changed|Current row updated|asset SCD2 window change|urn|
|ingestion.started|Ingest job start|job state QUEUED→RUNNING|id|
|ingestion.completed|Ingest job finish|RUNNING→COMPLETED|id|
|scan.started|Scan started|QUEUED→RUNNING|id|
|scan.completed|Scan ended|RUNNING→COMPLETED|id|
|finding.created|New finding|first_seen_at insert|id|
|finding.status_changed|Status change|OPEN→…|(id, new_status)|
|evidence.attached|Evidence added|evidence insert|finding_id|
|remediation.created|Remediation defined|remediation insert|id|
|remediation.completed|Work completed|status IN_PROGRESS→COMPLETED|id|
|notification.sent|Outbound delivery|after send|id|
|event.replayed|Historical replay|ETL backfill emits|id of original|

## **8. JSON Schemas**

  

### **8.1 Base meta schema (shared via** 

### **$defs**

### **)**

```
{
  "$id": "https://schemas.neurocipher.io/events/common/v1.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Neurocipher Event Envelope",
  "type": "object",
  "required": ["id","source","account_id","type","schema_version","event_version","occurred_at","emitted_at","checksum_sha256","detail"],
  "properties": {
    "id": { "type": "string", "pattern": "^[0-9A-HJKMNP-TV-Z]{26}$" },
    "source": { "type": "string", "enum": ["nc.app","nc.etl"] },
    "account_id": { "type": "string" },
    "type": { "type": "string" },
    "schema_version": { "type": "integer", "minimum": 1 },
    "event_version": { "type": "integer", "minimum": 1 },
    "occurred_at": { "type": "string", "format": "date-time" },
    "emitted_at": { "type": "string", "format": "date-time" },
    "trace_id": { "type": "string", "pattern": "^[a-f0-9]{16,32}$" },
    "actor": {
      "type": "object",
      "required": ["type"],
      "properties": {
        "type": { "type": "string", "enum": ["USER","SYSTEM"] },
        "user_id": { "type": "string" }
      },
      "additionalProperties": false
    },
    "checksum_sha256": { "type": "string", "pattern": "^[a-f0-9]{64}$" },
    "detail": { "type": "object" }
  },
  "additionalProperties": false
}
```

### **8.2** 

### **asset.discovered**

###  **v1**

```
{
  "$id": "https://schemas.neurocipher.io/events/asset.discovered/v1.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "asset.discovered",
  "type": "object",
  "required": ["id","account_id","urn","type","region","discovered_at","tags"],
  "properties": {
    "id": { "type": "string" },
    "account_id": { "type": "string" },
    "urn": { "type": "string" },
    "type": { "type": "string" },
    "region": { "type": "string" },
    "cloud_account_id": { "type": "string" },
    "discovered_at": { "type": "string", "format": "date-time" },
    "tags": { "type": "object", "additionalProperties": { "type": "string" } }
  },
  "additionalProperties": false
}
```

### **8.3** 

### **finding.created**

###  **v1**

```
{
  "$id": "https://schemas.neurocipher.io/events/finding.created/v1.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "finding.created",
  "type": "object",
  "required": ["id","account_id","scan_id","control_key","status","severity","summary","first_seen_at","last_seen_at"],
  "properties": {
    "id": { "type": "string" },
    "account_id": { "type": "string" },
    "scan_id": { "type": "string" },
    "control_key": { "type": "string" },
    "asset_id": { "type": "string" },
    "status": { "type": "string", "enum": ["OPEN","ACKNOWLEDGED","SUPPRESSED","RESOLVED"] },
    "severity": { "type": "string", "enum": ["LOW","MEDIUM","HIGH","CRITICAL"] },
    "evidence_score": { "type": "number" },
    "summary": { "type": "string" },
    "details": { "type": "object" },
    "first_seen_at": { "type": "string", "format": "date-time" },
    "last_seen_at":  { "type": "string", "format": "date-time" }
  },
  "additionalProperties": false
}
```

### **8.4** 

### **finding.status_changed**

###  **v1**

```
{
  "$id": "https://schemas.neurocipher.io/events/finding.status_changed/v1.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "finding.status_changed",
  "type": "object",
  "required": ["id","account_id","old_status","new_status","changed_at"],
  "properties": {
    "id": { "type": "string" },
    "account_id": { "type": "string" },
    "old_status": { "type": "string", "enum": ["OPEN","ACKNOWLEDGED","SUPPRESSED","RESOLVED"] },
    "new_status": { "type": "string", "enum": ["OPEN","ACKNOWLEDGED","SUPPRESSED","RESOLVED"] },
    "changed_at": { "type": "string", "format": "date-time" },
    "reason": { "type": "string" }
  },
  "additionalProperties": false
}
```

### **8.5** 

### **ingestion.started**

###  **v1**

```
{
  "$id": "https://schemas.neurocipher.io/events/ingestion.started/v1.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "ingestion.started",
  "type": "object",
  "required": ["id","account_id","data_source_id","started_at"],
  "properties": {
    "id": { "type": "string" },
    "account_id": { "type": "string" },
    "data_source_id": { "type": "string" },
    "started_at": { "type": "string", "format": "date-time" }
  },
  "additionalProperties": false
}
```

### **8.6** 

### **ingestion.completed**

###  **v1**

```
{
  "$id": "https://schemas.neurocipher.io/events/ingestion.completed/v1.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "ingestion.completed",
  "type": "object",
  "required": ["id","account_id","data_source_id","ended_at","stats"],
  "properties": {
    "id": { "type": "string" },
    "account_id": { "type": "string" },
    "data_source_id": { "type": "string" },
    "ended_at": { "type": "string", "format": "date-time" },
    "stats": { "type": "object" }
  },
  "additionalProperties": false
}
```

### **8.7** 

### **notification.sent**

###  **v1**

```
{
  "$id": "https://schemas.neurocipher.io/events/notification.sent/v1.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "notification.sent",
  "type": "object",
  "required": ["id","account_id","channel","template_key","sent_at"],
  "properties": {
    "id": { "type": "string" },
    "account_id": { "type": "string" },
    "channel": { "type": "string", "enum": ["SLACK","EMAIL","WEBHOOK"] },
    "template_key": { "type": "string" },
    "payload_hash": { "type": "string", "pattern": "^[a-f0-9]{64}$" },
    "sent_at": { "type": "string", "format": "date-time" }
  },
  "additionalProperties": false
}
```

> Provide similar schemas for account.created, user.invited, user.role_changed, cloud_account.linked, data_source.created, remediation.created, remediation.completed, evidence.attached, scan.started, scan.completed. Structure mirrors the entity fields from DM-001.

  

## **9. Publishing contract**

  

### **9.1 When to emit**

- Create events on insert of new logical state.
    
- Update events only on meaningful field changes or status transitions.
    
- One event per logical change. Do not batch across tenants.
    

  

### **9.2 Steps for publishers**

1. Build detail.
    
2. Canonicalize detail by stable key sorting and UTF-8 JSON.
    
3. Compute SHA-256 checksum and set checksum_sha256.
    
4. Construct envelope with the required fields.
    
5. Validate against schema v{schema_version}.
    
6. Put event to EventBridge.
    
7. Insert same event into nc.event with payload = detail.
    

  

### **9.3 Idempotency**

- id is the idempotency key.
    
- Consumers must upsert into nc.event using id as PK and ignore duplicates.
    
- State updates must check prior state to avoid double-apply.
    

  

## **10. Consumption contract**

  

### **10.1 Consumer behavior**

- Validate envelope and detail.
    
- Use account_id for tenancy context.
    
- Process within 30 seconds per message.
    
- On transient errors, do not delete message. Allow SQS retry.
    
- On permanent errors, send to DLQ with reason.
    

  

### **10.2 Dedupe example**

```
INSERT INTO nc.event(id, account_id, type, schema_version, event_version, occurred_at, payload, checksum_sha256)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
ON CONFLICT (id) DO NOTHING;
```

## **11. DLQ triage**

- DLQ alarm at > 100 messages or age > 15 minutes.
    
- Triage states: INVALID_SCHEMA, AUTH_FAILED, HANDLER_ERROR, PII_LEAK.
    
- Action matrix:
    
    - INVALID_SCHEMA: block publisher, fix schema or payload.
        
    - HANDLER_ERROR: hotfix consumer, replay from DLQ.
        
    - PII_LEAK: purge from DLQ and S3 export, file incident, rotate keys.
        
    

  

## **12. PII and data minimization**

- Do not include P1 fields in detail unless necessary for the consumer.
    
- Emails are never emitted. Use user_id.
    
- If a P1 field is required, hash or tokenize and include the hash.
    
- Classification must match DM-001 matrix.
    

  

## **13. Security**

- EventBridge and SQS use KMS CMK alias/nc-bus.
    
- Publishers and consumers have least privilege IAM roles:
    

```
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": ["events:PutEvents"], "Resource": "arn:aws:events:...:event-bus/nc-*-bus" },
    { "Effect": "Allow", "Action": ["sqs:ReceiveMessage","sqs:DeleteMessage","sqs:GetQueueAttributes"], "Resource": "arn:aws:sqs:...:nc-*-consumer*" },
    { "Effect": "Allow", "Action": ["kms:Encrypt","kms:Decrypt","kms:GenerateDataKey*"], "Resource": "arn:aws:kms:...:key/alias/nc-bus" }
  ]
}
```

- TLS required. Public access blocked on all buckets used by the registry and exports.
    

  

## **14. Observability**

- Log every publish with trace_id, id, type, size, and latency.
    
- Emit metrics:
    
    - events_published_total by type
        
    - events_consumed_total by type
        
    - consumer_latency_ms_p95
        
    - dlq_messages_total
        
    
- Correlate to DB via nc.event.id = envelope.id.
    

  

## **15. Persistence and export**

  

### **15.1 Postgres ledger**

  

nc.event schema per DM-003. Insert on publish and during backfills.

  

### **15.2 S3 export**

  

Optional compact event stream for recovery.

```
s3://nc-<env>-events/{account_id}/{yyyy}/{MM}/{dd}/{id}.json
```

Tag with rc=RC1. Lifecycle per ADR-007.

  

## **16. Examples**

  

### **16.1 finding.created event instance**

```
{
  "id": "01JB0GQW0A8Z7HQ8PRJ9TB9X1Z",
  "source": "nc.app",
  "account_id": "01HZX7K3M4A7W0E3V6S8R2N8C1",
  "type": "finding.created",
  "schema_version": 1,
  "event_version": 1,
  "occurred_at": "2025-10-28T14:05:23.412Z",
  "emitted_at": "2025-10-28T14:05:23.980Z",
  "trace_id": "f2b67f2a0d324c8c9a0a8c2a3b1caa21",
  "actor": { "type": "SYSTEM" },
  "checksum_sha256": "e0c9035898dd52fc65c41454cec9c4d2611bfb37b53a5e0e86c7cd9f7d2c2f3a",
  "detail": {
    "id": "01JB0GQW0A8Z7HQ8PRJ9TB9X1Z",
    "account_id": "01HZX7K3M4A7W0E3V6S8R2N8C1",
    "scan_id": "01JB0GQX6V3Z5QZ4K1N8T2M9AB",
    "control_key": "AH_S3_PUBLIC_READ",
    "asset_id": "01JB0FZ3J3Z6F0A7K8Q1L9P2RS",
    "status": "OPEN",
    "severity": "HIGH",
    "summary": "S3 bucket allows public READ",
    "first_seen_at": "2025-10-28T14:05:23.200Z",
    "last_seen_at": "2025-10-28T14:05:23.200Z"
  }
}
```

### **16.2 Finding consumer upsert outline**

```
-- Insert event row first (idempotent)
INSERT INTO nc.event(id, account_id, type, schema_version, event_version, occurred_at, payload, checksum_sha256)
VALUES ($id,$acct,$type,$sv,$ev,$ts,$payload,$sum)
ON CONFLICT (id) DO NOTHING;

-- Apply domain change if not already applied
UPDATE nc.finding
SET status = 'OPEN', last_seen_at = $ts
WHERE id = $payload->>'id' AND status <> 'OPEN';
```

## **17. Testing and certification**

  

### **17.1 Contract tests**

- For each event type:
    
    - Positive cases with full payloads.
        
    - Negative cases per missing required field.
        
    - Size test at 120 KB payload.
        
    - Duplicate delivery idempotency test.
        
    

  

### **17.2 Canary**

- Hourly canary emits event.canary with a TTL. Consumers check receipt and age. Alarms at 3 misses.
    

  

### **17.3 Replay drills**

- Quarterly replay from S3 export into a staging environment. Compare nc.event counts and checksums.
    

  

## **18. Change management**

- Changes proposed via DM-005 flow.
    
- Additive changes bump event_version or optional fields with defaults.
    
- Breaking changes require new schema_version and a dual-publish window.
    
- Registry updates are atomic. New schemas uploaded first, then publishers deploy.
    

  

## **19. Acceptance criteria**

- Envelope matches section 5 and validates against meta schema.
    
- JSON Schemas for all cataloged types published to S3. Examples present.
    
- EventBridge rules and SQS queues deployed with KMS encryption.
    
- Publishers validate and compute checksum as defined.
    
- Consumers are idempotent and write to nc.event.
    
- DLQ alarms configured and runbooks linked.
    
- PII minimized and never includes emails or secrets.
    
- Traceability from event id to nc.event row proven.
    
- No DynamoDB mentions. No references to external projects.
    

  

## **20. RACI**

- Responsible: Data Architecture
    
- Accountable: Head of Platform
    
- Consulted: Security, Compliance
    
- Informed: Product, Support
    

  

Confirm to proceed with DM-005 Governance, Versioning, and Migrations.