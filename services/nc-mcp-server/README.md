# nc-mcp-server

MCP Server - Model Context Protocol integration service.

## Purpose

The MCP (Model Context Protocol) Server provides standardized integration between the Neurocipher platform and LLM-based applications, enabling AI assistants to interact with security data and remediation workflows through a well-defined protocol.

## Responsibilities

- **MCP protocol implementation**: Implement Model Context Protocol server specification
- **Task management**: Define and manage MCP task models and lifecycle
- **Decision ledger**: Maintain ledger of AI-driven decisions and actions
- **Context provision**: Provide security context to LLM applications
- **Tool integration**: Expose Neurocipher capabilities as MCP tools
- **Query interface**: Enable natural language queries against security data
- **Action coordination**: Coordinate remediation actions through MCP interface

## Non-goals

- **NOT** responsible for LLM reasoning logic (handled by nc-core)
- **NOT** responsible for direct remediation execution (handled by nc-agent-forge)
- **NOT** a general-purpose API (use dedicated service APIs for programmatic access)
- Does not implement security posture detection
- Does not implement compliance assessment

## Integration Points

- **Consumes from**: 
  - nc-core (security findings, risk assessments)
  - nc-agent-forge (remediation capabilities, action status)
  - nc-audithound-api (compliance data)
- **Provides to**: 
  - LLM applications (Claude, ChatGPT, other MCP-compatible tools)
  - AI assistants (natural language interface to platform)

## Structure

```
nc-mcp-server/
├── src/nc_mcp_server/        # MCP Server implementation
│   ├── __init__.py
│   ├── protocol/             # MCP protocol implementation
│   ├── tasks/                # Task specification and management
│   ├── ledger/               # Decision and action ledger
│   ├── tools/                # MCP tool definitions
│   └── context/              # Context provision for LLMs
├── tests/                    # Service-specific tests
│   ├── __init__.py
│   └── fixtures/             # Test fixtures
├── README.md
└── pyproject.toml
```

## Documentation

See architecture documentation for detailed specifications:

- [Architecture Index](../../docs/governance/GOV-ARCH-001-Architecture-Documentation-Index.md)
- [Platform Context](../../docs/architecture/ARC-001-Platform-Context-and-Boundaries.md)
- [Module Mapping](../../docs/product/PRD-002-Capabilities-and-Module-Mapping-(Neurocipher-vs-AuditHound).md)
- [MCP Server Architecture](../../docs/architecture/MCP-ARCH-001-MCP-Server-Architecture.md) (planned)
- [MCP Task Specification](../../docs/architecture/MCP-TASK-001-Task-Specification.md) (planned)
- [MCP Ledger Specification](../../docs/architecture/MCP-LEDGER-001-Ledger-Specification.md) (planned)

## Development

This service is currently a skeleton. Implementation will follow the specifications in the architecture documents above.
