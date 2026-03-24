---
title: "AI Pipeline Orchestration"
date: "2026-01-17"
summary: "Prompt Flow, Semantic Kernel, and LangChain solve the same problem differently. Here's how to choose and where each breaks down in production."
tags: ["azure", "ai", "foundry", "architecture", "patterns"]
---

## TL;DR

Prompt Flow enforces structure and evaluation for Azure-native teams. Semantic Kernel gives .NET/Python engineers code-first multi-step reasoning with deep Azure integration. LangChain/LangGraph offers the widest ecosystem for complex agent workflows. Start with Prompt Flow; graduate based on complexity.

## Context

A single LLM call is rarely enough. Production AI features require chains of operations: retrieve context, call the model, validate the output, route to a specialist model, aggregate results. Orchestration frameworks manage this complexity — handling token budgets, retries, tracing, and parallelism so application code doesn't have to.

Three frameworks dominate Azure AI workloads, and they represent genuinely different design philosophies rather than superficial API differences. Choosing the wrong one creates friction that compounds as complexity grows.

## Architecture / Design

**Azure AI Foundry Prompt Flow**

Prompt Flow represents AI pipelines as directed acyclic graphs (DAGs). Each node is a typed unit: LLM node (sends a prompt, returns completion), Python node (arbitrary logic), Prompt node (template rendering), Retrieval node (vector search), or Tool node (function call). The visual editor in AI Foundry makes pipeline structure explicit and auditable.

The key differentiator is built-in evaluation: Prompt Flow has native support for running your pipeline against a golden dataset and scoring outputs on groundedness, coherence, relevance, and fluency using evaluator flows. Teams using Prompt Flow are more likely to actually run evaluations — because the tooling makes it the path of least resistance.

Limitations: DAG structure makes dynamic branching awkward. Complex agent loops with variable steps feel forced into a static graph topology.

**Semantic Kernel**

Semantic Kernel (SK) is Microsoft's SDK for .NET, Python, and Java. The core abstraction is the **plugin** — a collection of functions (native code or prompt templates) with semantic descriptions that the planner can discover and invoke. The **planner** uses the LLM itself to decide which plugins to call in what order to satisfy a goal.

SK's **memory abstraction** provides a consistent interface over multiple vector stores (Azure AI Search, Cosmos DB, in-memory). The **kernel** wires together AI services, plugins, memory, and filters. SK integrates natively with Azure OpenAI, Entra ID authentication, and Azure's managed identity model.

Best used when: your team is .NET or Python-centric, you need to embed AI capabilities deep into existing application code, and you want fine-grained control over the orchestration logic.

**LangChain / LangGraph**

LangChain has the largest open-source ecosystem — most third-party integrations, the most community examples. LangGraph extends it with stateful, cyclical agent graphs where control flow can loop, branch, and revisit nodes — the right model for ReAct-style agents with tool use.

Best used when: you need ecosystem breadth, complex multi-agent architectures, or Python-first development without Azure opinionation.

**Production Concerns Across All Frameworks**

Token budget management is non-negotiable: track input + output tokens per node, enforce budgets, truncate context when limits approach. Implement parallel execution where pipeline steps are independent — waiting serially on four independent retrievals is avoidable latency. Retry logic with exponential backoff on 429 (rate limit) and 5xx responses. Structured output validation: use JSON mode and validate schema before passing between pipeline stages. Streaming response propagation from the LLM node to the HTTP response reduces perceived latency significantly.

Observability: instrument every pipeline step with OpenTelemetry spans. Log token counts, latency, and model used per node. Azure Monitor + Application Insights with the AI Foundry tracing integration gives end-to-end pipeline traces.

## Diagram

![AI Pipeline Orchestration Architecture](/diagrams/ai-pipeline-orchestration.png)

## Key Insights

- **Prompt Flow's evaluation enforcement is its main value.** Teams skip evaluation without tooling friction — Prompt Flow makes skipping harder than doing it.
- **Semantic Kernel's planner is powerful but unpredictable.** The LLM decides execution order. Test exhaustively and add guardrails for production use.
- **LangChain's ecosystem breadth is a double-edged sword.** More integrations means more dependency churn and more breaking changes between versions.
- **Token budgets must be architectural, not afterthoughts.** Design the budget allocation per pipeline stage before you build, not after costs spike.
- **Streaming isn't optional for user-facing features.** A 4-second wait for a complete response feels broken. Streaming the same content feels fast.

## Trade-offs

| Framework | Azure Integration | Agent Complexity | Evaluation Built-in | Language Support | Learning Curve |
|---|---|---|---|---|---|
| Prompt Flow | Native, deep | Low-Medium (DAG) | Yes, first-class | Python, YAML | Low |
| Semantic Kernel | Native, deep | Medium-High (plugins+planner) | Manual | .NET, Python, Java | Medium |
| LangChain/LangGraph | Via integrations | High (stateful graphs) | Via LangSmith | Python, JS | Medium-High |

## References

- [Azure AI Foundry — Prompt Flow overview](https://learn.microsoft.com/en-us/azure/ai-studio/how-to/prompt-flow)
- [Semantic Kernel — Overview](https://learn.microsoft.com/en-us/semantic-kernel/overview/)
- [Semantic Kernel — Plugins](https://learn.microsoft.com/en-us/semantic-kernel/concepts/plugins/)
- [Azure AI Foundry — Evaluate with Prompt Flow](https://learn.microsoft.com/en-us/azure/ai-studio/how-to/evaluate-flow-results)
- [Semantic Kernel — Planners](https://learn.microsoft.com/en-us/semantic-kernel/concepts/planning)
- [Azure OpenAI — Structured outputs](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/structured-outputs)
