---
title: "Azure Compute Options Compared"
date: "2026-01-06"
summary: "VMs, App Service, AKS, Container Apps, Functions — Azure has five major compute primitives. Here's the decision framework."
tags: ["azure", "cloud", "architecture", "devops"]
---

## TL;DR

Azure's five compute primitives span the spectrum from raw VMs to serverless functions. The right choice is driven by operational maturity, scaling requirements, and team expertise — not by what's newest. AKS is powerful but expensive in operator time. Container Apps hits the sweet spot for most microservice workloads. Functions shines for event-driven bursty workloads.

## Context

Azure compute is not one-size-fits-all. Choosing AKS because "everyone uses Kubernetes" for a three-endpoint REST API is as wrong as choosing VMs because "we know Linux" for a cloud-native microservices platform. Each primitive has a different operations burden, scaling model, cost structure, and capability ceiling. Architects who treat compute selection as a default rather than a deliberate decision consistently over-engineer or under-engineer their platforms.

The selection framework has three axes: **control** (how much do you need to manage?), **scale** (what are your traffic patterns?), and **team capability** (what can you operate sustainably?).

## Architecture / Design

**Virtual Machines:**

VMs give you complete control over the OS, runtime, networking, and disk. That control comes at a cost — you own patching, monitoring agents, boot diagnostics, availability set or zone configuration, and autoscaling via VM Scale Sets. VMs are the right choice for:

- Legacy applications requiring specific OS versions, kernel modules, or commercial software with per-core licensing
- Lift-and-shift workloads that can't be containerized
- Custom network appliances (NVAs, firewalls)
- Workloads requiring persistent local disk with specific IOPS guarantees

For any greenfield application, VMs should be a last resort, not a first instinct.

**Azure App Service:**

Fully managed PaaS for web applications, REST APIs, and mobile backends. Supports .NET, Node.js, Python, Java, PHP, and Docker containers. No infrastructure management — Microsoft handles the OS, runtime patching, and TLS certificate renewal. Key capabilities:

- **Deployment slots**: separate staging and production environments within the same App Service Plan, with zero-downtime swap and automatic traffic routing for testing
- **Autoscaling**: rule-based or metric-based horizontal scaling (number of instances)
- **VNet Integration**: outbound connectivity to private resources via VNet integration; inbound via Private Endpoint
- **Built-in auth**: easy OAuth2 integration with Entra ID, GitHub, Google (for simple scenarios — use your own middleware for production auth)

The App Service Plan is the billing unit — you pay for the Plan regardless of how many apps run on it. Pack multiple low-traffic apps onto a single plan to reduce costs.

**Azure Kubernetes Service (AKS):**

Managed Kubernetes control plane with self-managed worker nodes (though node pool management is Azure-handled). AKS is the right choice when:

- You need the full Kubernetes ecosystem: Helm charts, service mesh, custom operators, KEDA, DAPR
- Your team has Kubernetes expertise and can operate it sustainably
- Your workloads have complex scheduling requirements (GPU nodes, spot node pools, node affinity)
- You're running 20+ microservices where the overhead of managing individual App Services exceeds K8s complexity

AKS supports **system node pools** (for system pods: coredns, kube-proxy) and **user node pools** (for workloads). Use spot node pools for batch and dev workloads to cut costs by 60–90%. AKS with Azure CNI + Calico network policy + Workload Identity is the production-grade starting configuration.

The hidden cost: AKS cluster management is a platform engineering function. Small teams often underestimate the ongoing investment: cluster upgrades, node image patching, certificate rotation, RBAC management, ingress configuration, observability stack setup.

**Azure Container Apps:**

Serverless container hosting built on Kubernetes and KEDA internally, but abstracting all of it. Container Apps is the right choice for:

- Microservices and event-driven workloads where you don't need direct Kubernetes access
- Teams without Kubernetes expertise who need container-native features (autoscaling to zero, DAPR sidecars, service discovery)
- HTTP-driven APIs and background processing jobs

Container Apps scales to zero (no cost when idle), scales on HTTP concurrency or custom KEDA metrics. DAPR integration is first-class — pub/sub, service invocation, state stores are configured via DAPR components, not application code changes. Environments are the isolation boundary — apps in the same environment share a VNet and log analytics workspace.

**Azure Functions:**

Event-driven, serverless compute. Triggers include HTTP, Timer, Service Bus, Event Hub, Blob Storage, Cosmos DB change feed, and more. Consumption plan (true serverless): pay per execution, scale to zero, cold starts of 1–3 seconds for .NET. Premium plan: pre-warmed instances eliminate cold starts, VNet integration, longer timeouts. Dedicated plan: runs on App Service Plan — essentially App Service with Functions SDK.

Functions is optimal for: scheduled jobs, webhook handlers, event processing pipelines, lightweight API endpoints with bursty traffic. For long-running processes (>10 minutes on Consumption), use Durable Functions for orchestration or migrate to Container Apps.

## Diagram

![Azure Compute Options Compared Architecture](/diagrams/azure-compute-options-compared.png)

## Key Insights

- **Operational cost ≠ compute cost.** AKS on a cost report looks reasonable. Add 20% of a platform engineer's salary to operate it and the picture changes. Factor in total cost of ownership including people-hours.
- **Container Apps is frequently the right answer for new microservice projects.** It provides containerization, autoscaling, DAPR, and event-driven scaling without requiring Kubernetes expertise. Graduate to AKS only when you genuinely need direct Kubernetes control.
- **Functions cold starts on Consumption plan are real and workload-dependent.** A .NET isolated worker cold start can be 3–8 seconds on first invocation. For user-facing APIs with unpredictable traffic, Premium plan's pre-warmed instances are worth the cost.
- **App Service Deployment Slots are underused.** The ability to swap staging and production with zero downtime — and roll back by swapping again — is one of the most practical deployment patterns Azure offers. Use it.

## Trade-offs

| Service | Control | Ops Burden | Scale-to-Zero | Cold Start | Best For |
|---|---|---|---|---|---|
| VMs / VMSS | Maximum | Maximum | No | No | Legacy, custom OS, NVAs |
| App Service | Medium | Low | No (min 1 instance) | No | Web apps, APIs, PaaS-first |
| AKS | High | High | With KEDA | No | Complex microservices, K8s ecosystem |
| Container Apps | Medium | Low | Yes | Minimal | Microservices, event-driven, DAPR |
| Functions (Consumption) | Low | Minimal | Yes | Yes (1–8s) | Event-driven, bursty, scheduled |
| Functions (Premium) | Low | Low | No | No | Functions without cold starts |

## References

- [Choose an Azure compute service](https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/compute-decision-tree)
- [Azure Kubernetes Service documentation](https://learn.microsoft.com/en-us/azure/aks/intro-kubernetes)
- [Azure Container Apps overview](https://learn.microsoft.com/en-us/azure/container-apps/overview)
- [Azure Functions overview](https://learn.microsoft.com/en-us/azure/azure-functions/functions-overview)
- [Azure App Service overview](https://learn.microsoft.com/en-us/azure/app-service/overview)
