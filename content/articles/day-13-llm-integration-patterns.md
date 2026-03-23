---
title: "LLM Integration Patterns"
date: "2026-01-13"
summary: "RAG, fine-tuning, prompt chaining, agents — production LLM systems are more architecture than data science."
tags: ["ai", "architecture", "patterns", "azure", "cloud"]
---

## TL;DR

RAG grounds LLM responses in your data without modifying model weights — it's the right choice for factual recall over dynamic corpora. Fine-tuning shapes model behavior and style, not knowledge. Prompt chaining decomposes complex tasks into sequential steps. Agents with tool calling enable LLMs to take actions and iterate. Most production systems are RAG + careful prompt engineering, not fine-tuning. Build your evaluation framework before scaling.

## Context

The gap between a demo LLM application and a production LLM application is mostly architecture. A demo calls the LLM with a question and displays the response. A production system manages retrieval quality, prompt versioning, output validation, latency budgets, cost per query, failure modes when the LLM returns unexpected formats, hallucination rates measured against a golden dataset, and graceful degradation when the AI service is unavailable.

The four core integration patterns — RAG, fine-tuning, prompt chaining, and agents — are not mutually exclusive. Production systems often compose them. Understanding what each pattern solves and what it costs helps avoid the most common mistake: choosing fine-tuning when RAG would suffice, or choosing a simple prompt when an agent is needed.

## Architecture / Design

**RAG — Retrieval-Augmented Generation:**

RAG is the pattern for grounding LLM responses in your organization's data without modifying the model itself. The pipeline has three stages:

1. **Indexing** (offline): chunk source documents into segments (typically 256–1024 tokens), generate vector embeddings for each chunk using an embedding model (e.g., `text-embedding-3-large`), store chunks + embeddings in a vector database (Azure AI Search, Cosmos DB for MongoDB vCore, PostgreSQL with pgvector).
2. **Retrieval** (online, per query): embed the user's query using the same model, perform vector similarity search to retrieve the top-k most relevant chunks, optionally combine with keyword search (hybrid retrieval).
3. **Generation**: inject retrieved chunks into the prompt context as grounding evidence, instruct the LLM to answer based only on the provided context.

Critical design decisions in RAG:
- **Chunk size**: small chunks increase retrieval precision but reduce context richness. Large chunks capture more context but introduce noise. 512 tokens with 10% overlap is a reasonable baseline.
- **Top-k**: retrieving 3–5 chunks is standard. More chunks add context but increase prompt token cost and can degrade focus.
- **Hybrid retrieval**: combining BM25 keyword scoring with vector similarity (Reciprocal Rank Fusion) consistently outperforms pure vector search — especially for precise term matching (product codes, names, exact phrases).
- **Re-ranking**: a cross-encoder re-ranker (Cohere Rerank, or an LLM-based reranker) scores retrieved chunks against the query for better relevance ordering before injection.

**Fine-tuning:**

Fine-tuning adjusts model weights using a dataset of example prompt-completion pairs. It shapes how the model behaves — its tone, format, domain-specific vocabulary, and completion style — but it does not reliably inject factual knowledge. Fine-tuning is appropriate for:

- Teaching the model to consistently output a specific JSON schema
- Applying a specific writing style or persona
- Domain-specific vocabulary and terminology that the base model handles poorly
- Reducing prompt length (fine-tuned models "know" their context implicitly)

Fine-tuning is expensive (training cost + ongoing per-token cost at a premium), brittle (facts change, fine-tuned knowledge doesn't update automatically), and slow to iterate. Do not fine-tune to inject knowledge — that's RAG's job.

**Prompt Chaining:**

Complex tasks that exceed a single LLM call's capability are decomposed into a sequence of steps where each step's output feeds the next. Example pipeline for document analysis:

1. Extract key entities and facts from a document (Step 1 LLM call)
2. Look up context for each entity from a database (non-LLM step)
3. Synthesize extracted facts + context into a structured summary (Step 2 LLM call)
4. Validate summary against a checklist (Step 3 LLM call)

Each step is simpler, more testable, and more debuggable than a monolithic mega-prompt. **Semantic Kernel** (Microsoft's .NET/Python orchestration SDK) provides abstractions for prompt functions, memory, and chaining. **LangChain** and **LlamaIndex** serve similar roles in the Python ecosystem.

**Agents and Tool Calling:**

Modern LLMs (GPT-4, Claude 3.5) support structured tool calling — the model outputs a JSON payload indicating which tool to invoke and with what arguments. The application executes the tool and feeds the result back to the LLM, which continues reasoning. This iterative reasoning loop implements the **ReAct (Reason + Act)** pattern.

Agent tools are functions your application exposes: database query, API call, file read, calculator, web search, code execution. The LLM decides when and how to use them based on its understanding of the task. A multi-turn agent loop:

1. User: "Summarize the last 3 support tickets for customer Acme Corp and tell me if there's a trend."
2. LLM: `call_tool(search_tickets, {customer: "Acme Corp", limit: 3})`
3. App: executes search, returns ticket summaries
4. LLM: reasons over ticket data, identifies a network connectivity trend, generates response

Key agent design decisions: tool selection (fewer, well-defined tools outperform many overlapping tools), retry/error handling (LLMs can self-correct on tool failure if the error is descriptive), max iterations (prevent infinite loops), and total token budget (agents consume tokens for every tool call round-trip).

**Evaluation Framework:**

Production LLM systems require quantitative evaluation. Eyeballing outputs is not a quality framework. Implement:

- **Golden dataset**: 50–200 representative query-expected-answer pairs
- **LLM-as-judge**: use GPT-4 to score responses for groundedness (does the answer come from the retrieved context?), relevance (does it answer the question?), coherence (is it logically structured?), and fluency
- **Regression suite**: run the eval pipeline on every prompt change or model version change before promotion
- Azure AI Foundry's evaluation SDK provides these evaluators as managed components

## Diagram

![LLM Integration Patterns Architecture](/diagrams/llm-integration-patterns.png)

## Key Insights

- **Most production use cases are RAG + careful prompt engineering.** Fine-tuning is expensive, brittle, and unnecessary for the vast majority of enterprise LLM applications. Invest in your retrieval quality and eval framework before considering fine-tuning.
- **Retrieval quality is the bottleneck in most RAG systems.** If the retriever doesn't return the relevant chunk, the LLM cannot answer correctly regardless of its capability. Measure and optimize retrieval precision@k before tuning generation.
- **Agents need guardrails.** An unconstrained agent with database write access and no iteration limit is a liability. Define explicit tool boundaries, max iteration counts, and structured output validation for every agentic workflow.
- **Prompt chaining exposes intermediate failures.** Each step in a chain is a failure point. Implement retry logic, fallback steps, and structured output validation at each step to prevent cascading failures from a single malformed intermediate output.

## Trade-offs

| Pattern | Knowledge Freshness | Implementation Cost | Hallucination Risk | Best For |
|---|---|---|---|---|
| Zero-shot prompt | N/A (model only) | Minimal | High | Simple tasks, LLM's training data |
| RAG | Real-time (dynamic index) | Medium | Low (grounded) | Enterprise knowledge retrieval |
| Few-shot examples | N/A | Low | Medium | Format/style consistency |
| Fine-tuning | Static (training data) | High | Medium | Style, format, domain terminology |
| Agent + tools | Real-time (tool results) | High | Low (tool-verified) | Multi-step reasoning, action-taking |

## References

- [RAG pattern on Azure AI Search](https://learn.microsoft.com/en-us/azure/search/retrieval-augmented-generation-overview)
- [Azure OpenAI fine-tuning](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/fine-tuning)
- [Semantic Kernel overview](https://learn.microsoft.com/en-us/semantic-kernel/overview/)
- [Azure OpenAI function calling](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/function-calling)
- [Azure AI Foundry evaluation](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/evaluate-generative-ai-app)
