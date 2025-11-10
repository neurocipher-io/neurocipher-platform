Here is the root-level openapi.yaml for the Neurocipher Data Pipeline API:

```yaml title="openapi.yaml"
openapi: 3.1.0
info:
  title: Neurocipher Data Pipeline API
  version: 1.0.0
  description: |
    REST interface for ingest, query, and admin operations in the Neurocipher Data Pipeline.
    All endpoints require authentication via AWS SigV4 or JWT.

servers:
  - url: https://api.neurocipher.io/data
    description: Production
  - url: https://stg-api.neurocipher.io/data
    description: Staging
  - url: http://localhost:8000
    description: Local development

security:
  - SigV4Auth: []
  - BearerAuth: []
    
paths:
  /ingest/event:
    post:
      summary: Ingest new event or document
      operationId: ingestEvent
      requestBody:
        required: true
        content:
          application/json:
            schema:
	            $ref:"#/components/schemas/IngestRequest"

      responses:
        "202":
          description: Event accepted for processing
          content:
            application/json:
              schema:
               $ref:"#/components/schemas/IngestResponse"

        "400":
          description: Invalid payload
        "401":
          description: Unauthorized
        "500":
          description: Internal server error

  

  /query:
    get:
      summary: Search normalized documents
      operationId: queryDocuments
      parameters:
        - in: query
          name: q
          schema:
            type: string
          required: true
          description: Query string
        - in: query
          name: filters
          schema:
            type: string
          required: false
          description: JSON encoded filter expression
        - in: query
          name: top_k
          schema:
            type: integer
            default: 10
          required: false
        - in: query
          name: mode
          schema:
            type: string
            enum: [hybrid, vector, keyword]
            default: hybrid
          required: false
      responses:
        "200":
          description: Query results
          content:
            application/json:
              schema:
                $ref:"#/components/schemas/QueryResponse"
        "400":
          description: Invalid query
        "401":
          description: Unauthorized
        "500":
          description: Server error

  /admin/reindex:
    post:
      summary: Reindex normalized documents
      operationId: adminReindex
      security:
        - SigV4Auth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/ReindexRequest"
      responses:
        "202":
          description: Reindex job accepted
        "403":
          description: Forbidden
        "500":
          description: Server error

  /health:
    get:
      summary: Health and dependency check
      operationId: healthCheck
      responses:
        "200":
          description: Healthy
          content:
            application/json:
              schema:
               $ref:"#/components/schemas/HealthResponse"
        "500":
          description: Unhealthy

components:
  securitySchemes:
    SigV4Auth:
      type: apiKey
      name: Authorization
      in: header
      description: AWS Signature Version 4 signed request
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:
    IngestRequest:
      type: object
      required: [source, data]
      properties:
        source:
          type: string
          description: Source system or identifier
        content_type:
          type: string
          description: MIME type of payload
        data:
          type: string
          description: Base64-encoded payload or JSON object
        metadata:
          type: object
          description: Optional metadata fields
    IngestResponse:
      type: object
      properties:
        event_id:
          type: string
        status:
          type: string
          enum: [accepted, queued]
    QueryResponse:
      type: object
      properties:
        query:
          type: string
        top_k:
          type: integer
        mode:
          type: string
          enum: [hybrid, vector, keyword]
        results:
          type: array
          items:
            $ref: "#/components/schemas/QueryResult"
    QueryResult:
      type: object
      properties:
        doc_id:
          type: string
        score:
          type: number
          format: float
        title:
          type: string
        snippet:
          type: string
        metadata:
          type: object
    ReindexRequest:
      type: object
      properties:

        entity_type:
          type: string
        date_range:
          type: object
          properties:
            start:
              type: string
              format: date-time
            end:
              type: string
              format: date-time
    HealthResponse:
      type: object
      properties:
        status:
          type: string
          enum: [healthy, degraded, failed]
        components:
          type: object
          additionalProperties:
            type: string

```
Save as openapi.yaml in the repository root. It defines all four primary endpoints, authentication methods, schemas, and response objects, matching the architecture and ADR specifications.