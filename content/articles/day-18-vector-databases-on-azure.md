---
title: "Vector Databases on Azure"
date: "2026-01-18"
summary: "Every RAG architecture needs a vector store. Azure AI Search is the managed default, but knowing when to reach for something else matters."
tags: ["azure", "ai", "architecture", "patterns", "system-design"]
---

## TL;DR

Azure AI Search is the right default for vector storage on Azure — it combines hybrid search, semantic re-ranking, and integrated vectorization in one managed service. Reach for Cosmos DB vectors when your data already lives there. Consider pgvector when you need relational joins. Avoid standalone vector DBs unless you have strong specialized requirements.

## Context

Every RAG architecture requires a vector store: a database that can store high-dimensional embedding vectors and answer approximate nearest-neighbor (ANN) queries efficiently. The market has exploded with options — Pinecone, Weaviate, Qdrant, Chroma, Milvus — but for Azure workloads, the decision space is narrower and more opinionated.

The key architectural insight is that vector search rarely exists in isolation. Enterprise RAG needs keyword search for exact matches, metadata filtering for scoping (by document type, date, department), and often integration with existing data — all of which argues for a multi-capability service over a single-purpose vector DB.

## Architecture / Design

**Azure AI Search**

Azure AI Search is not a traditional search engine bolted onto vectors — it was redesigned to be a first-class vector search platform while retaining its BM25 keyword search capabilities. This makes it uniquely suited for hybrid retrieval.

Hybrid search in Azure AI Search works by running vector (cosine similarity via HNSW) and keyword (BM25) queries in parallel, then fusing results using Reciprocal Rank Fusion (RRF). The semantic ranker then re-scores the top-50 fused results using a cross-encoder — this three-stage pipeline (vector + keyword + semantic) consistently outperforms any single-mode retrieval strategy.

Integrated vectorization eliminates the embedding pre-computation step: configure a vectorizer pointing at an Azure OpenAI embedding deployment, and Azure AI Search will embed documents during indexing and embed queries at search time automatically.

For enterprise use cases, Azure AI Search also supports document chunking within the service itself (via skillsets), making it possible to go from raw PDF in Blob Storage to searchable vector index without custom pipeline code.

**Azure Cosmos DB Vector Search**

Cosmos DB for NoSQL supports vector indexes on any document property. The value proposition is colocation: if your application data already lives in Cosmos DB, adding a vector property to existing documents avoids a second datastore entirely. This simplifies the operational model and enables filtered vector search against the same document properties used for transactional queries.

Cosmos DB also supports vector search in MongoDB vCore and PostgreSQL API. The NoSQL API uses DiskANN, Microsoft's graph-based ANN algorithm designed for SSD-resident indexes — enabling billion-scale vector search without requiring all vectors in memory.

**PostgreSQL pgvector**

Azure Database for PostgreSQL Flexible Server supports the pgvector extension. This is the right choice when you need vector search with relational joins — for example, finding the top-K semantically similar products where `category = 'electronics' AND price < 500`. The ability to express this as a single SQL query with vector ordering is a significant developer ergonomics win over multi-query approaches.

pgvector supports both IVFFlat (faster to build, slightly lower recall) and HNSW (higher recall, larger index footprint) index types.

**Dimensionality and Scaling Considerations**

`text-embedding-3-small` produces 1536-dimensional vectors. `text-embedding-3-large` produces 3072 dimensions. Storage and query cost scales quadratically with dimension count at high volume. Azure AI Search supports dimension reduction via Matryoshka Representation Learning (MRL) — you can truncate embeddings to 256 or 512 dimensions with minimal recall loss, dramatically reducing index size and query cost.

HNSW (Hierarchical Navigable Small World) indexes offer high recall with fast query time but consume significant memory during construction. IVF (Inverted File Index) indexes are cheaper to build and more memory-efficient but require tuning of `nlist` and `nprobe` parameters to balance recall and speed.

## Diagram

![Vector Databases on Azure Architecture](/diagrams/vector-databases-on-azure.png)

## Key Insights

- **Don't introduce new operational complexity without clear gains.** A dedicated Qdrant cluster on AKS brings you vector-specific features but also brings you another service to patch, monitor, and back up.
- **Hybrid search is the correct default.** Pure vector search has a systematic weakness: exact keyword matches (product SKUs, person names, error codes) often score lower than semantically similar but wrong results.
- **MRL truncation is underused.** Reducing from 1536 to 512 dimensions typically costs less than 5% recall while cutting storage and query cost by 67%.
- **Metadata filtering matters as much as vector similarity.** A chunk from a deprecated 2019 document should not surface above a current 2025 document. Filter on metadata, don't just rank on similarity.
- **Index freshness is a real operational concern.** Near-real-time document updates require incremental re-indexing. Design the ingestion pipeline with update semantics from day one.

## Trade-offs

| Option | Hybrid Search | Relational Join | Operational Overhead | Scale Ceiling | Best For |
|---|---|---|---|---|---|
| Azure AI Search | Native (vector + BM25 + semantic) | No | Low (managed) | Very high | Default Azure RAG workloads |
| Cosmos DB vectors | Limited | Within document | Low (managed) | Billion-scale (DiskANN) | Data already in Cosmos DB |
| PostgreSQL pgvector | No (vector only) | Full SQL | Low (managed) | Medium | Relational + vector queries |
| Qdrant/Pinecone on AKS | Vector-native filtering | No | High (self-managed) | High | Specialized vector-only workloads |

## References

- [Azure AI Search — Vector search](https://learn.microsoft.com/en-us/azure/search/vector-search-overview)
- [Azure AI Search — Hybrid search with RRF](https://learn.microsoft.com/en-us/azure/search/hybrid-search-ranking)
- [Azure AI Search — Integrated vectorization](https://learn.microsoft.com/en-us/azure/search/vector-search-integrated-vectorization)
- [Azure Cosmos DB — Vector search](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/vector-search)
- [Azure Database for PostgreSQL — pgvector](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-use-pgvector)
- [Azure AI Search — Scalar quantization and MRL](https://learn.microsoft.com/en-us/azure/search/vector-search-how-to-configure-compression-storage)
