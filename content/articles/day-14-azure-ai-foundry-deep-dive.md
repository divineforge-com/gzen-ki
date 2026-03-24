---
title: "Azure AI Foundry Deep Dive"
date: "2026-01-14"
summary: "AI Foundry is Azure's unified platform for building, evaluating, and deploying generative AI applications. It's opinionated in good ways."
tags: ["azure", "ai", "foundry", "microsoft", "architecture"]
---

## TL;DR

AI Foundry organizes work into Hubs (shared Azure infrastructure) and Projects (isolated app workspaces). Prompt Flow enables visual + code-first LLM pipeline authoring. The built-in evaluation framework measures groundedness, relevance, and fluency. The model catalog gives access to OpenAI, Meta Llama, Mistral, and Cohere under a unified deployment API. Use AI Foundry even for solo projects — the governance structure it enforces becomes invaluable as teams and applications scale.

## Context

The typical path for a team building their first generative AI application is: call the OpenAI API directly, string together some LangChain calls, deploy to a VM, and ship. This works for a prototype. By the time there are three applications, two teams, five model deployments, no evaluation framework, and secrets scattered across environment variables and Key Vaults that nobody mapped, the infrastructure debt is severe.

AI Foundry is Azure's answer to this pattern — a unified development platform that enforces project isolation, shared connection management, evaluation gates, and observability from the start. It does not prevent you from shipping quickly; it prevents you from shipping in ways that create future architectural problems.

## Architecture / Design

**Hub and Project Structure:**

The **Hub** is the top-level Azure resource. It represents the shared infrastructure layer for a team or organization working on generative AI: it holds connections to external services (Azure OpenAI, Azure AI Search, Azure Blob Storage), the compute configuration for prompt flow execution, the network configuration (VNet, private endpoints), and shared security settings (managed identity, Key Vault reference).

A Hub maps to an Azure resource group and creates a set of dependent resources automatically: an Azure Storage Account (for artifacts and flow files), an Azure Key Vault (for connection credentials), and an Application Insights instance (for tracing).

**Projects** are isolated workspaces within a Hub. Each project represents a single application or a team working on a related set of capabilities. Projects share the Hub's connections and infrastructure but are isolated from each other — files, deployments, evaluations, and traces are scoped to the project. RBAC can be scoped to the project level, giving teams access to their project without exposing other projects' assets.

This structure solves a practical problem: a single organization building five AI features doesn't want five separate Azure OpenAI resources, five separate AI Search instances, and five separate Key Vaults. The Hub centralizes shared resources; Projects provide isolation without duplication.

**Model Catalog and Deployments:**

AI Foundry's model catalog provides a curated selection of foundation models from multiple providers under a unified deployment interface:

- **Azure OpenAI models**: GPT-4o, GPT-4o mini, GPT-4, GPT-3.5-Turbo, text-embedding-3-large, DALL-E 3, Whisper
- **Meta Llama**: Llama 3.1, Llama 3.2 (various sizes)
- **Mistral**: Mistral Large, Mistral Small, Codestral
- **Cohere**: Command R+, Embed
- **Microsoft Phi**: Phi-3 small/medium/large (efficient models for constrained environments)

Deploying from the catalog creates a managed inference endpoint. The deployment API surface is OpenAI-compatible for most models — code written against GPT-4 can often switch to Llama or Mistral with a connection string change, enabling model comparison and cost optimization.

**Prompt Flow:**

Prompt Flow is a development framework for building, testing, and deploying LLM workflows. Flows are DAGs — directed acyclic graphs of nodes, where each node is an LLM call, a Python function, or a built-in tool. Two authoring modes:

- **Visual editor**: drag-and-drop node composition in the AI Foundry portal. Good for prototyping and non-developer stakeholders.
- **Code-first (YAML + Python)**: flows defined in `flow.dag.yaml` with Python function nodes. Supports local development and testing via the `promptflow` CLI and SDK. Git-trackable.

Flow types:
- **Standard flow**: linear or branching LLM workflow for inference
- **Chat flow**: conversational interface with history management
- **Evaluation flow**: measures quality metrics on a batch dataset

Flows run locally during development, then deploy to a managed endpoint within AI Foundry for production serving. The managed endpoint handles scaling, health monitoring, and metrics collection.

**Evaluation Framework:**

AI Foundry's evaluation system runs a flow against a dataset and measures output quality using built-in or custom evaluators:

- **Groundedness**: does the response contain only information supported by the retrieved context? (Anti-hallucination measure)
- **Relevance**: does the response address the user's question?
- **Fluency**: is the response grammatically correct and natural-sounding?
- **Coherence**: is the response logically structured and internally consistent?
- **F1 / Similarity**: for tasks with ground-truth answers, measures lexical overlap

Evaluations use GPT-4 as the judge by default — the evaluator LLM reads the question, context, ground truth, and generated answer, then scores each dimension on a 1–5 scale. Custom evaluators are Python functions that take flow inputs/outputs and return metric values.

The evaluation framework is the CI/CD gate for LLM applications: run a batch evaluation on a golden dataset, fail the pipeline if groundedness drops below a threshold, require human review for borderline regressions.

**Connections and Credential Management:**

Connections in AI Foundry abstract the credentials and endpoint details of external services. A connection to Azure OpenAI stores the endpoint URL and API key in the Hub's Key Vault; Prompt Flow nodes reference the connection by name, not by credential value. Application code using the `azure-ai-projects` SDK retrieves connections at runtime through the managed identity — zero secrets in code or configuration.

**Tracing and Observability:**

AI Foundry automatically traces every Prompt Flow execution: each LLM call, its input/output, token usage, latency, and the retrieved documents in a RAG flow. Traces are stored in the project's Application Insights resource and are queryable via KQL. The tracing view in the portal renders the full DAG execution with node-level timing — the equivalent of distributed tracing for LLM workflows.

## Diagram

![Azure AI Foundry Deep Dive Architecture](/diagrams/azure-ai-foundry-deep-dive.png)

## Key Insights

- **AI Foundry enforces good practices that teams skip when building ad-hoc.** Project isolation, connection abstraction, evaluation gates, and tracing are all things teams plan to implement "later" when building from scratch. AI Foundry makes them the default path.
- **The Hub/Project hierarchy maps cleanly to enterprise governance.** A business unit gets a Hub; each product team gets a Project. RBAC at the project level gives teams autonomy without cross-contamination of assets, connections, or billing visibility.
- **Prompt Flow evaluation is the LLM quality gate.** Integrating evaluation runs into CI/CD (via the `promptflow` CLI or `azure-ai-projects` SDK) enables automated regression detection on every prompt change. This is the difference between "we tested it manually" and "we measured it quantitatively."
- **The model catalog enables multi-model strategies.** Deploy GPT-4o for complex reasoning tasks and Phi-3 or Llama for simple classification — cost-optimized routing based on task complexity. AI Foundry's unified deployment API makes this practical without managing separate infrastructure per model.

## Trade-offs

| Approach | Time to First Value | Governance | Evaluation | Scalability | Best For |
|---|---|---|---|---|---|
| Direct API (no platform) | Minutes | None | Manual | DIY | Prototypes, solo experiments |
| LangChain / custom stack | Hours | DIY | DIY | DIY | Teams with existing OSS tooling |
| AI Foundry (managed) | Hours–Days | Built-in | Built-in | Managed | Enterprise teams, regulated use cases |
| Azure ML + custom serving | Days–Weeks | Built-in | Built-in | Maximum | Custom models, full MLOps |

## References

- [Azure AI Foundry overview](https://learn.microsoft.com/en-us/azure/ai-foundry/what-is-azure-ai-foundry)
- [AI Foundry Hub and Project architecture](https://learn.microsoft.com/en-us/azure/ai-foundry/concepts/ai-resources)
- [Prompt Flow documentation](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/prompt-flow)
- [AI Foundry model catalog](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/model-catalog-overview)
- [AI Foundry evaluation](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/evaluate-generative-ai-app)
- [azure-ai-projects SDK](https://learn.microsoft.com/en-us/python/api/overview/azure/ai-projects-readme)
