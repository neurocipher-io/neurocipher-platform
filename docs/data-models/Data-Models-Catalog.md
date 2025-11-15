
id: DM-CATALOG
title: Domain Model Catalog (Legacy)
owner: Data Architecture
status: Deprecated (superseded by DM-001–DM-005)
last_reviewed: 2025-11-15

# Domain Model Catalog

  

## Core entities

- Source

- IngestJob

- Document

- Chunk

- Embedding

- MetadataTag

- IndexEntry

- User

- ApiKey

- AuditLog

- DataContract

- DeletionRequest

  

## Relationships (plain)

- Source 1—* IngestJob

- IngestJob 1—* Document

- Document 1—* Chunk

- Chunk 1—1 Embedding

- Document *—* MetadataTag

- Chunk *—* MetadataTag

- Chunk 1—* IndexEntry

  

## Entity fields (minimal)

### Source

- id, type, name, settings, created_at

  

### IngestJob

- id, source_id, status, started_at, finished_at, error

  

### Document

- id, job_id, source_id, uri, mime_type, bytes, checksum, created_at, normalized_at, contract_version

  

### Chunk

- id, document_id, ord, text, tokens, created_at

  

### Embedding

- chunk_id, vector, model, dim, created_at

  

### MetadataTag

- id, key, value, scope, created_at

  

### IndexEntry

- chunk_id, weaviate_id, opensearch_id, created_at

  

### User

- id, email, role, created_at

  

### ApiKey

- id, user_id, name, last_used_at, created_at, revoked

  

### AuditLog

- id, actor, action, target_type, target_id, payload_json, ts

  

### DataContract

- id, name, version, json_schema_ref, state, created_at

  

### DeletionRequest

- id, target_type, target_id, reason, state, created_at, closed_at
  
## Acceptance Criteria

- This catalog is clearly marked as legacy and points readers to DM-001–DM-005 as the canonical data model specifications.
- Any new data modeling or storage design work is reviewed against DM-001–DM-005 and DM-003 physical schemas rather than relying solely on the DynamoDB and CloudEvents patterns in this document.
- References from other docs treat this file as historical context only; normative contracts live in DM-001–DM-005 and DCON-001.

2) ERD and Storage Schemas.md

2) ERD and Storage Schemas.md

  

# ERD and Storage Schemas

  

## DynamoDB tables

### documents

- PK: doc#${document_id}

- SK: v#${iso_timestamp}

- GSI1: source#${source_id}

- attrs: job_id, uri, mime_type, checksum, contract_version, created_at, normalized_at

  

### chunks

- PK: doc#${document_id}

- SK: chunk#${ord}

- GSI1: chunk#${chunk_id}

- attrs: text, tokens, created_at

  

### embeddings

- PK: chunk#${chunk_id}

- SK: emb#${model}

- attrs: vector(float[]), dim, created_at

  

### tags

- PK: tag#${key}

- SK: val#${value}#${target_type}#${target_id}

- GSI1: target#${target_type}#${target_id}

- attrs: scope, created_at

  

### audit_logs

- PK: audit#${date}

- SK: ${ts}#${id}

- GSI1: target#${target_type}#${target_id}

- attrs: actor, action, payload_json

  

## Weaviate class

```json

{

  "class": "Chunk",

  "vectorIndexType": "hnsw",

  "vectorizer": "none",

  "properties": [

    {"name":"chunk_id","dataType":["text"],"indexInverted":true},

    {"name":"document_id","dataType":["text"],"indexInverted":true},

    {"name":"ord","dataType":["int"]},

    {"name":"text","dataType":["text"],"indexInverted":true},

    {"name":"tags","dataType":["text[]"],"indexInverted":true},

    {"name":"source_id","dataType":["text"],"indexInverted":true}

  ]

}

  

OpenSearch index mapping

  

{

  "mappings": {

    "properties": {

      "chunk_id": {"type":"keyword"},

      "document_id": {"type":"keyword"},

      "ord": {"type":"integer"},

      "text": {"type":"text"},

      "source_id": {"type":"keyword"},

      "tags": {"type":"keyword"},

      "created_at": {"type":"date"}

    }

  },

  "settings": {

    "index": {

      "number_of_shards": 2,

      "number_of_replicas": 1

    }

  }

}

# 3) JSON Schemas Catalog.md

```md

# JSON Schemas Catalog

  

## $defs

All schemas use `$schema: "https://json-schema.org/draft/2020-12/schema"`.

  

### NormalizedDocument v1

```json

{

  "$id":"https://neurocipher.io/schemas/normalized_document.v1.json",

  "$schema":"https://json-schema.org/draft/2020-12/schema",

  "type":"object",

  "required":["id","source_id","uri","mime_type","chunks","contract_version"],

  "properties":{

    "id":{"type":"string"},

    "source_id":{"type":"string"},

    "uri":{"type":"string"},

    "mime_type":{"type":"string"},

    "checksum":{"type":"string"},

    "contract_version":{"type":"string"},

    "metadata":{"type":"object","additionalProperties":true},

    "chunks":{

      "type":"array",

      "items":{"$ref":"#/$defs/Chunk"}

    }

  },

  "$defs":{

    "Chunk":{

      "type":"object",

      "required":["id","ord","text"],

      "properties":{

        "id":{"type":"string"},

        "ord":{"type":"integer","minimum":0},

        "text":{"type":"string"},

        "tags":{"type":"array","items":{"type":"string"}}

      }

    }

  }

}

  

IngestRequest v1

  

{

  "$id":"https://neurocipher.io/schemas/ingest_request.v1.json",

  "$schema":"https://json-schema.org/draft/2020-12/schema",

  "type":"object",

  "required":["source_id","items"],

  "properties":{

    "source_id":{"type":"string"},

    "items":{"type":"array","items":{"$ref":"#/$defs/Item"}}

  },

  "$defs":{

    "Item":{

      "type":"object",

      "required":["uri"],

      "properties":{"uri":{"type":"string"}}

    }

  }

}

  

QueryResponse v1

  

{

  "$id":"https://neurocipher.io/schemas/query_response.v1.json",

  "$schema":"https://json-schema.org/draft/2020-12/schema",

  "type":"object",

  "required":["query","top_k","hits"],

  "properties":{

    "query":{"type":"string"},

    "top_k":{"type":"integer"},

    "mode":{"type":"string","enum":["hybrid","vector","keyword"]},

    "hits":{

      "type":"array",

      "items":{

        "type":"object",

        "required":["chunk_id","score","text","document_id"],

        "properties":{

          "chunk_id":{"type":"string"},

          "document_id":{"type":"string"},

          "score":{"type":"number"},

          "text":{"type":"string"},

          "uri":{"type":"string"},

          "tags":{"type":"array","items":{"type":"string"}}

        }

      }

    }

  }

}

# 4) Event Models and Contracts.md

```md

# Event Models and Contracts

  

## Naming

- Topic: `nc.data.events`

- Envelope: CloudEvents 1.0

  

## CloudEvents envelope (shared)

```json

{

  "specversion":"1.0",

  "id":"<uuid>",

  "source":"nc.pipeline.<component>",

  "type":"<EventType>",

  "time":"<rfc3339>",

  "datacontenttype":"application/json",

  "data":{}

}

  

Events

  

  

  

IngestRequested.v1

  

{

  "job_id":"<uuid>",

  "source_id":"<id>",

  "items":[{"uri":"s3://..."}]

}

  

IngestCompleted.v1

  

{"job_id":"<uuid>","source_id":"<id>","count":123,"errors":0}

  

NormalizedCreated.v1

  

{"document_id":"<uuid>","job_id":"<uuid>","source_id":"<id>","chunk_count":42}

  

EmbedRequested.v1

  

{"document_id":"<uuid>","chunk_ids":["c1","c2"],"model":"text-embedding-3-large"}

  

EmbedCompleted.v1

  

{"document_id":"<uuid>","embedded":42,"model":"text-embedding-3-large"}

  

IndexUpserted.v1

  

{"chunk_ids":["c1","c2"],"weaviate_ids":["..."],"opensearch_ids":["..."]}

  

DeletionRequested.v1

  

{"target_type":"document","target_id":"<uuid>","reason":"gdpr-erasure"}

  

DeletionCompleted.v1

  

{"target_type":"document","target_id":"<uuid>","removed_chunks":42,"removed_vectors":42}

# 5) Data Contracts and Versioning.md

```md

# Data Contracts and Versioning

  

## Scope

- NormalizedDocument.v*

- IngestRequest.v*

- QueryResponse.v*

- Event types *.v*

  

## Versioning rules

- Semantic: MAJOR.MINOR

- Backward compatible in MINOR

- Breaking in MAJOR only

- Each payload includes `contract_version`

  

## Registry

- Location: `s3://nc-contracts/${name}/v${major}.${minor}/schema.json`

- Index: `contracts/index.json` with latest pointers

- Promotion: draft → candidate → accepted

  

## Compatibility checks

- CI step validates JSON with `ajv` and golden samples

- Canary on staging topics for new MINOR

- Dual write for one week on MAJOR

  

## Deprecation policy

- Announce in `/contracts/changelog.md`

- Maintain previous MAJOR for 90 days

- Provide migration notes and sample transforms

  

## Example transform (v1 → v2)

```jq

# add default tags array and map "content" → "text"

.walk(

  if type=="object" and has("content")

  then .text = .content | del(.content)

  else .

  end

) | if has("tags")==false then .tags=[] else . end
