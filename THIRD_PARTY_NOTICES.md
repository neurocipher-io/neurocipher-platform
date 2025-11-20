# Third Party Notices

This project relies on several third-party tools, libraries, and managed services. Below is the current summary of major components and their licenses. Keep this file in sync when adding new dependencies or vendor software.

| Component | License | Notes |
|-----------|---------|-------|
| `black` formatter | MIT | Python auto-formatting. |
| `ruff` linter | MIT | Static analysis across Python sources. |
| `pytest` | MIT | Test harness for services and libs. |
| Mermaid | MIT | Architecture diagrams in docs. |
| AWS services (S3, Lambda, Weaviate, OpenSearch, DynamoDB) | AWS Service Terms | Refer to vendor documentation for compliance. |
| Weaviate vector database | Apache 2.0 | Managed or self-hosted deployment described in docs. |

License scanning and compliance follow the automation defined in `agents.yaml` and `.github/workflows/lint.yml`. Any new dependency must include SPDX metadata, and unresolved “unknown” licenses require calm from the Compliance team before merging.
