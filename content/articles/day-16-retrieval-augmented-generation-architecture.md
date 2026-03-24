---
title: "Retrieval-Augmented Generation Architecture"
date: "2026-01-16"
summary: "RAG is the dominant pattern for grounding LLMs in enterprise data. The architecture details — chunking, embedding, retrieval strategy — determine whether it actually works."
tags: ["ai", "architecture", "patterns", "azure", "system-design"]
---

## TL;DR

RAG grounds LLM responses in your enterprise data by retrieving relevant chunks at query time and injecting them into the prompt. The chunking strategy, embedding model, and retrieval quality are more impactful than model choice. 80% of RAG failures are data quality issues. Invest in the pipeline, not just the model.

## Context

Large language models hallucinate when asked about private data they've never seen. Fine-tuning is expensive, slow, and goes stale as data changes. RAG solves this by keeping the LLM frozen and instead retrieving fresh, relevant context at inference time. This pattern has become the standard architectural approach for enterprise Q&A, document intelligence, and knowledge assistants on Azure.

The architecture has two distinct phases: an offline ingestion pipeline that processes and indexes your documents, and an online query pipeline that retrieves relevant content and generates responses.

## Architecture / Design

**Ingestion Pipeline**

Documents arrive in Azure Blob Storage or SharePoint. A processing pipeline (Azure Functions or AML pipelines) extracts text, applies chunking, generates embeddings, and writes to a vector index.

Chunking strategy is the most impactful architectural variable in the entire pipeline:

- **Fixed-size chunking**: split every 512 tokens with 10% overlap. Simple, consistent, but blind to semantic boundaries — a sentence about Topic A may be split from its conclusion in the next chunk.
- **Semantic chunking**: use embedding cosine similarity to detect topic shifts and split at natural boundaries. Higher quality, higher compute cost during ingestion.
- **Heading-based chunking**: split on Markdown/HTML headings. Works well for structured documentation; poor for unstructured PDFs.
- **Hierarchical chunking**: index both paragraph-level chunks (precise retrieval) and section-level summaries (broader context), then return the parent when a child matches.

Embeddings are generated per chunk using Azure OpenAI `text-embedding-3-small` (1536 dimensions, lower cost) or `text-embedding-3-large` (3072 dimensions, higher accuracy). The model choice affects both storage cost and retrieval precision.

**Vector Store Indexing**

Azure AI Search is the recommended managed backend for Azure workloads. It supports vector indexes (HNSW algorithm), BM25 keyword indexes, and semantic re-ranking in a single service. The integrated vectorization feature can automatically embed content during indexing — eliminating the need for a separate embedding step.

**Query Pipeline**

1. Embed the user query with the same model used during ingestion.
2. Execute a hybrid search: vector similarity (cosine) + BM25 keyword overlap — hybrid consistently outperforms either alone.
3. Apply semantic re-ranking: Azure AI Search's semantic ranker re-scores top-K results using a cross-encoder model trained on MSMARCO.
4. Fetch top-3 to top-5 chunks and stuff them into the prompt context window.
5. Pass to GPT-4o with a system prompt instructing citation-based response.

**Evaluation Loop**

Evaluate with precision@K (are the right chunks being retrieved?) and groundedness (is the final answer supported by the retrieved chunks?). Use Azure AI Foundry's built-in evaluation flows with a golden dataset of known question-answer pairs.

## Diagram

![Retrieval-Augmented Generation Architecture](/diagrams/retrieval-augmented-generation-architecture.png)

## Key Insights

- **Data quality beats model quality.** Scanned PDFs with poor OCR, inconsistent naming, and duplicate documents degrade retrieval regardless of which LLM you use. Invest in document pre-processing.
- **Hybrid search is not optional.** Vector search misses exact keyword matches (product codes, names, acronyms). BM25 misses semantic synonyms. Hybrid handles both.
- **Chunk size is a dial, not a setting.** Benchmark on your actual document corpus. A 256-token chunk may outperform 1024 tokens for one dataset and lose badly on another.
- **Re-ranking is cheap relative to its impact.** Adding a semantic re-ranker after initial retrieval consistently improves relevance with minimal latency overhead.
- **Context window stuffing has diminishing returns.** Injecting 20 chunks doesn't reliably beat 5 well-chosen ones. More context increases cost and can confuse the model.

## Trade-offs

| Chunking Strategy | Retrieval Precision | Ingestion Cost | Context Coherence | Best For |
|---|---|---|---|---|
| Fixed-size (512 tokens) | Medium | Low | Low (cuts mid-sentence) | Quick prototypes, uniform docs |
| Semantic chunking | High | Medium-High | High | Mixed document types, production |
| Heading-based | Medium-High | Low | High | Structured docs, wikis, Markdown |
| Hierarchical | Highest | High | Highest | Long-form documents, legal/compliance |
| Document-level | Low | Lowest | Highest | Short docs, precise document match |

## References

- [Azure AI Search — Vector search overview](https://learn.microsoft.com/en-us/azure/search/vector-search-overview)
- [Azure AI Search — Hybrid search](https://learn.microsoft.com/en-us/azure/search/hybrid-search-overview)
- [Azure AI Search — Semantic ranking](https://learn.microsoft.com/en-us/azure/search/semantic-search-overview)
- [Azure OpenAI — Embeddings concepts](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/understand-embeddings)
- [Azure AI Foundry — RAG architecture guidance](https://learn.microsoft.com/en-us/azure/ai-studio/concepts/retrieval-augmented-generation)
- [Azure AI Search — Integrated vectorization](https://learn.microsoft.com/en-us/azure/search/vector-search-integrated-vectorization)
