

id: OBS-003
title: Alerting, SLOs and Incident Response
owner: Reliability Engineering
status: Approved
last_reviewed: 2025-10-24

OBS-003 Alerting, SLOs and Incident Response

  

  

Status: Approved  Owner: Reliability Engineering  Last Reviewed: 2025-10-24

Tags: alerting / SLO / incident-response / observability / resilience

  

  

  

  

1 Purpose

  

  

Define a unified policy for service-level objectives, alert routing, escalation, and incident handling across the Neurocipher Pipeline and external orchestrator (see docs/integrations/README.md) orchestration layer.

  

  

  

  

2 Scope

  

  

Applies to all production services and shared infrastructure in AWS.

Includes ingestion APIs, background workers, vector index, orchestration tasks, and event-driven components.

  

  

  

  

3 Service Level Objectives (SLOs) and Indicators (SLIs)

  

Refer to the canonical Retention & SLO matrix in OBS-001 §5 (and the capacity/cost model in `docs/CAP-001-Capacity-Model.md`) for the definitive targets, SLIs, and retention durations cited throughout this document. The same metrics (`http_request_duration_seconds`, `weaviate_query_duration_seconds`, `document_processing_latency_seconds`, `security_engine.decision_latency_ms`, etc.) power dashboards and alerting described below.

  

  

4 Error Budget and Burn Rate

  

  

- 99.9 % availability allows 43.2 minutes downtime per month.
- Track burn at 1 h and 6 h windows.
- Page if burn > 2 % per hour (fast burn).
- Ticket if burn > 5 % per day (slow burn).

  

  

Error budget usage is reviewed monthly in Reliability Report REL-002.

  

  

  

  

5 Alert Policy

  

  

- Alert on user-visible symptoms only (e.g., latency, errors, unavailability).
- Group alerts by service and tenant to avoid alert storms.
- Tenant-level grouping and alert metadata follow docs/security-controls/SEC-005-Multitenancy-Policy.md.
- Mute alerts during deploy for 10 minutes post-success.
- Every alert links to a runbook in /docs/runbooks/.
- Alerts must include severity, description, owner, and clear next steps.
- Security Engine specific alerts: queue age > 120 s (`security_engine.command_queue_age_s`) and action status failure rate > 0.5 % trigger paging to Security Engineering with runbooks referenced in `docs/runbooks/`.

  

  

  

  

  

6 Alertmanager Routing

  

route:

  receiver: pagerduty

  group_by: [service, env]

  routes:

  - matchers: [severity="ticket"]

    receiver: jira

receivers:

- name: pagerduty

  pagerduty_configs:

  - routing_key: ${PAGERDUTY_KEY}

- name: jira

  webhook_configs:

  - url: https://hooks.example/jira

Severity Mapping

  

- page → Immediate human intervention
- ticket → Work item within 48 h
- info → Logging only

  

  

  

  

  

7 On-Call and Escalation

  

  

- Primary and secondary rotation weekly.
- Escalate to manager if unacknowledged > 15 minutes.
- Hand-off checklist documented in oncall.md.
- All incidents are recorded in the Incident Register (/ops/incidents/).

  

  

Escalation Flow

  

1. Primary Engineer (pager triggered)
2. Secondary Engineer (5 min)
3. Engineering Manager (15 min)
4. Director of Platform if critical (30 min)

  

  

  

  

  

8 Incident Lifecycle

  

|   |   |   |
|---|---|---|
|Phase|Action|Output|
|Detection|Alert triggers via AMP or CloudWatch|Page with context links|
|Declaration|Incident Commander appointed|Incident doc initiated|
|Containment|Rollback, circuit break, or failover|Service stabilized|
|Resolution|Root cause identified|Service restored|
|Post-mortem|Blameless review within 72 h|Report and action items|

Post-mortem Checklist

  

- Timeline and impact summary
- Root cause and mitigation plan
- Follow-up tasks with owners and due dates
- Lessons learned → SLO adjustment or automation task

  

  

  

  

  

9 Automated Safeguards

  

  

- Canary deployments auto-rollback on p95 latency or error regression.
- Circuit breakers for external APIs with fallback responses.
- Synthetic checks run every minute for key endpoints.
- Automated alerts muted for known maintenance windows.

  

  

  

  

  

10 Compliance and Retention

  

|   |   |   |
|---|---|---|
|Artifact|Retention|Storage|
|Incident records|2 years|S3 KMS encrypted|
|Alert history|1 year|Amazon Managed Prometheus|
|Post-mortems|Permanent|Git (/ops/postmortems/)|
|Audit logs|90 days|CloudTrail|

Access is controlled by IAM roles (IncidentResponder, SREManager).

  

  

  

  

11 Security and PII

  

  

- Mask customer data in alerts, traces and incident artifacts.
- Never include tokens or secrets in incident summaries.
- Apply KMS encryption to all retained incident records.

  

  

  

  

  

12 Review and Continuous Improvement

  

  

- Quarterly review of SLO targets and incident trend analysis.
- Metrics tracked: MTTD, MTTR, error budget burn rate, false-positive alerts.
- Annual game-day simulations for disaster response (see REL-001).

## 13. Acceptance Criteria

- SLOs and SLIs defined in this spec (including ingest availability, freshness, vector latency, index error rate, and Security Engine latency) are implemented and tracked in observability tooling.
- Error-budget burn alerts are configured for the defined SLOs with page/ticket thresholds matching this document.
- Every alert above a page or ticket severity links to a runbook under `docs/runbooks/` and includes severity, owner, and clear next steps.
- On-call rotations and escalation paths are documented and kept current in incident tooling and `/ops` docs, including the Incident Register and oncall checklist.
- Post-incident reviews for qualifying incidents are recorded in `/ops/postmortems/` within 72 hours and include the checklist items from this spec.
