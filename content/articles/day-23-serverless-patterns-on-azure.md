---
title: "Serverless Patterns on Azure"
date: "2026-01-23"
summary: "Azure Functions and Durable Functions unlock powerful event-driven patterns, but cold start, state management, and billing surprises require architectural awareness."
tags: ["azure", "architecture", "patterns", "serverless", "cloud"]
---

## TL;DR

Azure Functions on Consumption plan provides zero-management, event-driven compute with automatic scale-to-zero. Durable Functions adds stateful orchestration — fan-out/fan-in, human approval workflows, long-running processes — with checkpointed state that survives process restarts. Choose Premium plan when cold start latency, VNet integration, or predictable performance matter.

## Context

Serverless means different things at different layers: no VM management, no cluster management, automatic scaling, and billing per execution rather than per provisioned unit. Azure Functions implements all four. The value proposition is real — operational overhead drops significantly for event-driven workloads.

The hidden costs are equally real: cold starts, execution time limits, stateless-by-default design, and consumption billing that can exceed dedicated compute for sustained high-throughput workloads. Understanding both dimensions is required to make sound architectural decisions.

## Architecture / Design

**Azure Functions Triggers and Bindings**

Every Azure Function is defined by its trigger — the event source that invokes it. The trigger directly determines the integration architecture:

- **HTTP trigger**: synchronous request/response API — the function is the API handler
- **Timer trigger**: scheduled execution — replaces cron jobs and scheduled tasks
- **Queue trigger / Service Bus trigger**: async message processing — the function is the worker in a competing-consumers pattern
- **Event Hub trigger**: stream processing at scale — function receives batches of events from a partition
- **Blob trigger**: process files on arrival — document processing, image resizing, ETL
- **Cosmos DB change feed trigger**: react to database changes — projections, cache invalidation, downstream sync

Input and output bindings further reduce boilerplate: an HTTP-triggered function with a Cosmos DB output binding persists data to the database with zero SDK code — the runtime handles serialization and connection management.

**Hosting Plan Comparison**

The Consumption plan is the default: functions scale from zero, billing is per execution (1M free executions/month, then $0.20/1M). Cold start latency on Consumption ranges from ~200ms (.NET isolated, Java) to ~500ms+ (Python). Cold starts occur when the function host scales out to a new instance, meaning they're worst under bursty traffic patterns.

The Premium plan adds pre-warmed instances that eliminate cold start for incoming requests. Premium also provides VNet integration (required for accessing resources on private networks), longer execution timeouts, and larger instance sizes. The cost model shifts to per-second execution on minimum-size instances — no scale-to-zero.

The Dedicated plan runs on App Service VMs — useful when you need co-location with existing App Service resources or require guaranteed resource allocation.

**Durable Functions**

Durable Functions extends Azure Functions with the orchestrator/activity pattern for stateful workflows:

- **Orchestrator function**: defines the workflow using deterministic code — calls activity functions, waits for results, handles errors, branches based on outcomes. The orchestrator is replayed from checkpoint state on restart, which requires pure deterministic code (no DateTime.Now, no random, no external calls).
- **Activity function**: the unit of work — makes external calls, writes to databases, calls APIs. Activities are idempotent and retried on failure.
- **Entity function**: virtual actor pattern for managing small pieces of state (counters, locks, accumulators) with guaranteed single-threaded access.

**Fan-Out/Fan-In Pattern**: An orchestrator spawns N parallel activity functions (processing N documents simultaneously), then waits for all to complete with `Task.WhenAll` before aggregating results. This pattern completes N parallel I/O-bound operations in the time of one serial execution.

**Human Approval Pattern**: An orchestrator sends a Teams Adaptive Card (via Power Automate or Logic Apps), then waits on `context.WaitForExternalEvent("Approval")`. When the approver clicks Accept, an HTTP trigger function raises the event to the orchestrator. Workflows can wait for days or weeks — the orchestrator's state is durable in Azure Storage throughout.

**Durable Functions' checkpointing model** stores orchestrator state as an event sourcing log in Azure Storage. Process restarts, scale-out events, and failures don't lose workflow progress — the orchestrator replays from the last committed checkpoint automatically.

## Diagram

![Serverless Patterns on Azure Architecture](/diagrams/serverless-patterns-on-azure.png)

## Key Insights

- **Durable Functions checkpointing is architecturally significant.** The orchestrator survives host process restarts because its state is externalized. This enables workflows that span hours, days, or weeks without dedicated compute.
- **Cold start is a traffic pattern problem, not just a language problem.** Even fast runtimes cold-start under bursty traffic. Premium plan pre-warmed instances solve this at the cost of minimum billing floor.
- **Execution time limits are real.** Consumption plan maximum timeout is 10 minutes. Premium/Dedicated allows up to 60 minutes (configurable). Long-running work belongs in Durable Functions orchestrations, not a single function execution.
- **Avoid orchestrator non-determinism bugs.** Using `DateTime.UtcNow` or `Guid.NewGuid()` in an orchestrator function causes correctness issues on replay. Use the Durable Functions-provided deterministic equivalents.
- **Scale-to-zero is the killer feature for variable workloads.** A queue processor that handles 100 events/hour during business hours and 0 overnight costs fractions of a dedicated VM.

## Trade-offs

| Hosting Plan | Cold Start | Min Cost | VNet Support | Max Timeout | Best For |
|---|---|---|---|---|---|
| Consumption | Yes (200–500ms+) | $0 (scale to zero) | No | 10 min | Variable/burst workloads, dev/test |
| Premium | No (pre-warmed) | ~$150/month (1 instance) | Yes | 60 min | Production latency-sensitive, VNet required |
| Dedicated (App Service) | No | Per App Service Plan | Yes | Unlimited | Co-location with existing ASP resources |
| Container Apps (KEDA) | Configurable | $0 (scale to zero) | Yes | Unlimited | Container-based, Kubernetes semantics |

## References

- [Azure Functions — Overview](https://learn.microsoft.com/en-us/azure/azure-functions/functions-overview)
- [Azure Functions — Hosting plans comparison](https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale)
- [Durable Functions — Overview](https://learn.microsoft.com/en-us/azure/azure-functions/durable/durable-functions-overview)
- [Durable Functions — Fan-out/fan-in pattern](https://learn.microsoft.com/en-us/azure/azure-functions/durable/durable-functions-cloud-backup)
- [Durable Functions — Human interaction pattern](https://learn.microsoft.com/en-us/azure/azure-functions/durable/durable-functions-phone-verification)
- [Azure Functions — Triggers and bindings concepts](https://learn.microsoft.com/en-us/azure/azure-functions/functions-triggers-bindings)
