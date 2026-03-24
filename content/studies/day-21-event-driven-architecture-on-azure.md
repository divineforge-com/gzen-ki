---
title: "Event-Driven Architecture on Azure"
date: "2026-01-21"
summary: "Event Grid, Service Bus, and Event Hubs solve different event problems. Conflating them is a common Azure architecture mistake."
tags: ["azure", "architecture", "patterns", "system-design", "cloud"]
---

## TL;DR

Event Grid is for reactive events (something happened, fan out to subscribers). Service Bus is for reliable business messaging (do this work, guaranteed, ordered if needed). Event Hubs is for high-volume streaming data ingestion (millions of events/second, log retention, analytics). Getting this wrong creates operational debt that's expensive to unwind.

## Context

"Event-driven" is overloaded. It describes everything from "notify a webhook when a blob is uploaded" to "stream 500,000 IoT telemetry events per second into an analytics pipeline." Azure offers three distinct messaging services because these problems have genuinely different requirements: latency, throughput, ordering guarantees, retention semantics, and consumer models.

Choosing Service Bus for IoT telemetry (wrong — no partitioned log, no consumer group replay) or Event Grid for financial transactions (wrong — no ordering, no dead-letter guarantee) are architectural mistakes that surface as production incidents.

## Architecture / Design

**Azure Event Grid**

Event Grid implements the reactive event pattern: a publisher emits a discrete event ("blob uploaded," "resource group created," "custom domain validated"), and Event Grid fans it out to zero or more subscribers via push delivery. It's pull-free, serverless-scale, and designed for low-latency fan-out.

Native Azure sources publish to Event Grid automatically: Azure Blob Storage, Azure Container Registry, Azure Resource Manager, Azure Service Bus (on message dead-lettered), and 20+ others. Custom applications publish to custom Event Grid topics or namespaces.

Handlers include: Azure Functions, Logic Apps, Service Bus queues (fan-out to reliable processing), Webhooks, and Event Hubs. This composability makes Event Grid the connective tissue of Azure service integration.

Use Event Grid when: you need to trigger downstream actions when Azure resources change state, you need fan-out to multiple consumers, and you don't require strict ordering or replay.

**Azure Service Bus**

Service Bus implements reliable async messaging with enterprise messaging semantics. Queues support competing consumers (multiple receivers, each message processed once). Topics with subscriptions implement the pub-sub pattern with filter-based routing — a message published to a topic can be selectively consumed by subscriptions based on SQL-like filter expressions.

Critical features that justify Service Bus over Event Grid for business transactions:

- **Dead-letter queue**: messages that fail processing or exceed delivery count are moved to a DLQ for investigation and reprocessing — not dropped.
- **Sessions**: session-enabled queues guarantee FIFO ordering for all messages with the same session ID. This is the only managed Azure service that provides ordered processing without a single-consumer bottleneck.
- **Transactions**: enroll multiple Service Bus operations in an atomic transaction — dequeue a command and enqueue a result as one atomic unit.
- **Message lock**: a receiver acquires an exclusive lock before processing, preventing double-processing under concurrent consumers.

Service Bus sessions are architecturally underused. They're the correct solution for order processing (all events for OrderId=123 must be processed in sequence) and state machine workflows where message order determines correctness.

**Azure Event Hubs**

Event Hubs is a partitioned, append-only event log — conceptually similar to Apache Kafka (and Kafka-protocol compatible). It's designed for high-throughput telemetry ingestion: millions of events per second across 32+ partitions.

Unlike Service Bus, Event Hubs doesn't delete messages after consumption. Events are retained for 1–90 days. Multiple consumer groups can independently read the same stream from different offsets — enabling parallel analytics, ML feature generation, and audit processing on the same event stream.

Event Hubs Capture writes the stream directly to Azure Data Lake Storage Gen2 in Avro or Parquet format — a zero-code path from real-time telemetry to data lake.

**Composition Pattern: CQRS + Event Sourcing**

Commands enter via Service Bus (reliable, ordered by session). The command handler processes and emits domain events to Event Grid (fan-out to downstream services). High-volume audit and analytics events flow to Event Hubs (stream processing, Capture to ADLS). This three-way composition covers all event-driven patterns in a single architecture.

## Diagram

![Event-Driven Architecture on Azure Architecture](/diagrams/event-driven-architecture-on-azure.png)

## Key Insights

- **Service Bus sessions are the hidden gem.** They provide ordered processing per correlation key (orderId, customerId) with competing consumers — eliminating the single-consumer bottleneck that naive FIFO implementations create.
- **Event Grid is not reliable messaging.** It has retry policies, but no dead-letter guarantee in the same class as Service Bus. Don't use it for financial transactions.
- **Event Hubs retention enables replay.** If a downstream consumer fails for 6 hours, it can replay from its last checkpoint — a capability Service Bus queues don't provide.
- **Kafka compatibility is a migration path, not a feature.** If you're running Kafka on-prem, Event Hubs enables lift-and-shift of Kafka producers/consumers with zero code change.
- **Don't conflate "events" semantics.** A blob upload notification and a purchase order confirmation look like "events" but require completely different reliability guarantees.

## Trade-offs

| Scenario | Event Grid | Service Bus | Event Hubs |
|---|---|---|---|
| Azure resource state change notifications | ✅ Best fit | Overkill | Not designed for this |
| Order processing (must not duplicate/lose) | ❌ No DLQ guarantee | ✅ Best fit | Not designed for this |
| IoT sensor telemetry (500K events/sec) | ❌ Not for volume | ❌ Throughput limits | ✅ Best fit |
| Fan-out to 10 subscribers | ✅ Native | Via topics | Via consumer groups |
| Ordered processing per entity | ❌ No ordering | ✅ Sessions | ✅ Per-partition |

## References

- [Azure Event Grid — Overview](https://learn.microsoft.com/en-us/azure/event-grid/overview)
- [Azure Service Bus — Overview](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-messaging-overview)
- [Azure Service Bus — Message sessions](https://learn.microsoft.com/en-us/azure/service-bus-messaging/message-sessions)
- [Azure Event Hubs — Overview](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-about)
- [Azure Event Hubs — Capture](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-capture-overview)
- [Choose between messaging services](https://learn.microsoft.com/en-us/azure/service-bus-messaging/compare-messaging-services)
