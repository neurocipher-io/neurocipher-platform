# nc_observability

Observability and telemetry libraries for the Neurocipher platform.

## Scope and Responsibilities

`nc_observability` provides standardized logging, metrics, and tracing capabilities. This package contains:

- **Structured logging** - JSON-formatted logs with correlation IDs and context
- **Metrics collection** - Prometheus-compatible metrics for RED and USE patterns
- **Distributed tracing** - OpenTelemetry integration with AWS X-Ray
- **Context propagation** - W3C traceparent/tracestate headers
- **Log formatters** - Consistent log formatting with required fields
- **Telemetry helpers** - Decorators and context managers for instrumentation

### What MUST Live Here

- Structured logging setup and configuration
- Log formatters with required fields (see OBS-001)
- Metrics collectors and exporters
- Distributed tracing instrumentation
- Context propagation utilities
- Correlation ID generation and management
- Telemetry decorators and helpers
- CloudWatch and X-Ray integration

### What MUST NOT Live Here

- Domain models (use `nc_models` instead)
- Business logic
- Configuration management (use `nc_common` instead)
- Security primitives (use `nc_security` instead)
- Service-specific metrics definitions (define in services, collect here)

## Architecture and Specifications

This package implements observability standards from:

- **[OBS-001](../../docs/observability/OBS-001-Observability-Strategy-and-Telemetry-Standards.md)** - Observability Strategy and Telemetry Standards (telemetry stack, context propagation, event taxonomy)
- **[OBS-002](../../docs/observability/OBS-002-Monitoring-Dashboards-and-Tracing.md)** - Monitoring Dashboards and Tracing
- **[REF-001](../../docs/governance/REF-001-Glossary-and-Standards-Catalog.md)** - Standards Catalog (§12 logging requirements)

## Structure

```text
nc_observability/
├── src/
│   └── nc_observability/
│       ├── __init__.py          # Package exports
│       ├── logging.py           # Structured logging setup
│       ├── metrics.py           # Metrics collection and export
│       ├── tracing.py           # Distributed tracing
│       ├── context.py           # Context propagation
│       ├── formatters.py        # Log formatters
│       └── decorators.py        # Instrumentation decorators
├── tests/                       # Unit tests
└── README.md                    # This file
```text

## Usage

### Structured Logging

```python
from nc_observability.logging import get_logger

logger = get_logger(__name__)

# Log with structured context
logger.info(
    "Processing request",
    extra={
        "correlation_id": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a",
        "user_id": "user123",
        "operation": "scan_s3_bucket",
        "resource_id": "arn:aws:s3:::my-bucket"
    }
)

# Log with outcome
logger.info(
    "Request completed",
    extra={
        "correlation_id": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a",
        "outcome": "success",
        "latency_ms": 150
    }
)
```text

### Required Log Fields

Per OBS-001, all logs must include:

- `level` - Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- `event_name` - Descriptive event name
- `correlation_id` - Request/transaction identifier
- `trace_id` - Distributed trace identifier (from OpenTelemetry)
- `span_id` - Current span identifier
- `timestamp` - ISO 8601 timestamp with Z suffix
- `service` - Service name
- `environment` - Environment (dev, stg, prod)

### Metrics Collection

```python
from nc_observability.metrics import Counter, Histogram, Gauge

# RED metrics for APIs
requests_total = Counter(
    "requests_total",
    "Total number of requests",
    ["service", "endpoint", "method", "status"]
)

request_duration = Histogram(
    "request_duration_seconds",
    "Request duration in seconds",
    ["service", "endpoint"]
)

# USE metrics for workers
queue_depth = Gauge(
    "queue_depth",
    "Number of items in queue",
    ["queue_name"]
)

# Record metrics
requests_total.labels(
    service="ingest-api",
    endpoint="/v1/findings",
    method="POST",
    status="200"
).inc()

with request_duration.labels(service="ingest-api", endpoint="/v1/findings").time():
    # Your code here
    pass
```text

### Distributed Tracing

```python
from nc_observability.tracing import trace_span, get_tracer

tracer = get_tracer(__name__)

@trace_span("process_finding")
def process_finding(finding_id: str):
    """Process a security finding with distributed tracing."""
    # Automatically traced, spans sent to X-Ray
    pass

# Manual span creation
with tracer.start_as_current_span("database_query") as span:
    span.set_attribute("db.system", "dynamodb")
    span.set_attribute("db.operation", "put_item")
    # Your code here
```text

### Context Propagation

```python
from nc_observability.context import (
    get_correlation_id,
    set_correlation_id,
    propagate_context,
    extract_context_from_headers
)

# Get or generate correlation ID
correlation_id = get_correlation_id()

# Extract context from HTTP headers
context = extract_context_from_headers(request.headers)

# Propagate context to downstream calls
headers = propagate_context()
response = requests.post(url, headers=headers, data=payload)
```text

## Telemetry Stack

Per OBS-001, the platform uses:

- **Collection**: AWS Distro for OpenTelemetry (ADOT)
- **Tracing**: OpenTelemetry → AWS X-Ray
- **Metrics**: Prometheus Remote Write → Amazon Managed Prometheus (AMP)
- **Logs**: JSON → CloudWatch Logs → S3 (Parquet via Firehose)
- **Dashboards**: Amazon Managed Grafana
- **Alerting**: CloudWatch Alarms + AMP Alertmanager

## Metrics Catalog

Standard metrics per OBS-001:

### RED Metrics (APIs)

- `requests_total` - Total request count
- `errors_total` - Total error count
- `request_duration_seconds` - Request latency histogram

### USE Metrics (Workers)

- `cpu_utilization` - CPU usage percentage
- `memory_utilization` - Memory usage percentage
- `queue_depth` - Queue depth gauge
- `saturation_ratio` - Worker saturation

### Pipeline KPIs

- `ingest_events_total` - Total events ingested
- `dedup_rate` - Deduplication rate
- `vector_write_latency_ms` - Vector write latency
- `retrieval_latency_ms` - Retrieval latency
- `hit_ratio` - Cache hit ratio
- `batch_retries_total` - Batch retry count

## Testing

Run tests from the repository root:

```bash
# Run all tests
make test

# Run only nc_observability tests
pytest libs/python/nc_observability/tests/ -v
```text

## Standards Compliance

All code follows:

- PEP 8 style guidelines (via Black, isort, ruff)
- Type hints for all public functions
- Google-style docstrings
- OpenTelemetry semantic conventions
- W3C Trace Context propagation
- OBS-001 telemetry standards

See [OBS-001](../../docs/observability/OBS-001-Observability-Strategy-and-Telemetry-Standards.md) for complete standards.

## Dependencies

External dependencies:

- `opentelemetry-api` - OpenTelemetry API
- `opentelemetry-sdk` - OpenTelemetry SDK
- `opentelemetry-instrumentation` - Auto-instrumentation
- `aws-xray-sdk` - AWS X-Ray integration
- `prometheus-client` - Prometheus metrics
- `structlog` - Structured logging

## AWS Integration

### Lambda Functions

```python
from nc_observability.logging import setup_lambda_logging
from nc_observability.tracing import setup_lambda_tracing

# In Lambda handler initialization
setup_lambda_logging()
setup_lambda_tracing()

def lambda_handler(event, context):
    logger = get_logger(__name__)
    logger.info("Lambda invocation", extra={
        "request_id": context.request_id,
        "function_name": context.function_name
    })
    # Your code here
```text

### ECS/Fargate Services

```python
from nc_observability.logging import setup_ecs_logging
from nc_observability.tracing import setup_ecs_tracing
from nc_observability.metrics import setup_prometheus_exporter

# In service startup
setup_ecs_logging()
setup_ecs_tracing()
setup_prometheus_exporter(port=9090)
```text

## Contributing

When adding observability features:

1. Follow OBS-001 telemetry standards
2. Use OpenTelemetry semantic conventions
3. Include all required log fields
4. Test with both Lambda and ECS environments
5. Document new metrics in this README
6. Write comprehensive unit tests (≥80% coverage)
7. Ensure zero overhead when telemetry is disabled

## Related Packages

- **nc_models** - Canonical Pydantic models and data contracts
- **nc_common** - Shared utilities and configuration
- **nc_security** - Security primitives and validation
