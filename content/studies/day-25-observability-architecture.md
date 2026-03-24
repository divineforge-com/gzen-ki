---
title: "Observability Architecture"
date: "2026-01-25"
summary: "Logs, metrics, and traces are the three pillars. SLOs and SLIs turn them into reliability engineering. Here's how to design an observability system, not just bolt it on."
tags: ["architecture", "patterns", "observability", "devops", "azure"]
---

## TL;DR

Observability without SLOs is dashboards nobody reads. Define SLIs (what you measure), SLOs (what's acceptable), and error budgets (how much unreliability you can afford). Use OpenTelemetry for vendor-neutral instrumentation. Alert on error budget burn rate, not individual error events — the former is actionable, the latter is noise.

## Context

Traditional monitoring asks "is the system up?" Observability asks "why is this request slow for this user?" The shift is from binary health checks to exploratory debugging using telemetry data. Logs, metrics, and traces are the three pillars — but having all three is necessary, not sufficient. Without a framework connecting telemetry to reliability commitments, observability becomes an expensive noise generator.

SLOs (Service Level Objectives) provide that framework. They define what "working correctly" means in measurable terms, which makes alerting purposeful and on-call decisions defensible.

## Architecture / Design

**The Three Pillars**

**Logs** are time-stamped, discrete event records: "user X submitted order Y," "payment processor returned error code 402," "cache miss for key Z." Logs are the highest-fidelity record of what happened — and the most expensive to store and query at scale.

Structured logging is mandatory in production. Log events as typed fields, not concatenated strings: `{"level":"error","orderId":"123","errorCode":"402","latencyMs":240}` is queryable; `"Error processing order 123: code 402 after 240ms"` is not. In Azure, this means Log Analytics KQL queries against structured fields — string parsing is an anti-pattern.

**Metrics** are numerical measurements sampled over time: request rate, error rate, p50/p99 latency, CPU utilization, queue depth. Metrics are cheap to store (time-series compression), fast to query, and ideal for alerting and dashboards. Azure Monitor metrics have 93-day retention with no custom query cost.

**Traces** provide causality across service boundaries. A distributed trace follows a single request through every service it touches, with each service contributing a span (service name, operation, duration, status, attributes). The W3C `traceparent` header propagates trace context across HTTP calls; Service Bus messages carry correlation IDs as message properties.

Without traces, diagnosing "why was this order checkout slow?" in a microservices system requires correlating timestamps across 8 separate service logs — a manual process that takes hours. With traces, you navigate directly to the slow span in Application Insights or Azure Monitor.

**OpenTelemetry**

OpenTelemetry (OTel) is the CNCF standard for telemetry instrumentation: a single SDK that instruments your application and exports logs, metrics, and traces to any backend via the OTLP protocol. Instrument once, change backends without code changes.

The Azure Monitor OpenTelemetry Distro is the recommended way to send OTel telemetry to Application Insights from .NET, Python, Java, and Node.js applications. Auto-instrumentation covers HTTP clients, database drivers, and messaging clients with zero application code changes.

**SLIs and SLOs**

A Service Level Indicator is a quantitative measurement of a service behavior: availability (% of successful requests), latency (p99 request duration), throughput (requests per second), error rate (% of requests returning 5xx).

An SLO is a target for an SLI: "p99 latency < 200ms for 99.9% of requests in a rolling 28-day window." The SLO is a commitment to users — violating it means users are experiencing degraded service.

**Error Budget**: `Error Budget = 1 - SLO`. A 99.9% availability SLO gives 43.8 minutes/month of allowed downtime. The error budget is the engineering team's operating margin. When the budget is full, the team can move fast and take risks. When it's depleted, reliability work takes priority over feature work.

**Alert on Burn Rate, Not Events**

Alerting on every 5xx error creates noise — some error rate is always present and expected. Alert on error budget burn rate instead: "we're consuming 10x the expected error budget rate over the last hour" is a signal that something is genuinely wrong and will breach the SLO if uncorrected. This generates far fewer alerts while catching actual incidents earlier.

Azure Monitor's multi-condition alert rules and Log Analytics KQL enable burn rate calculations: compare current error rate against the SLO threshold and the remaining budget.

**Distributed Trace Correlation**

For Service Bus messaging, inject a correlation ID as a message property on the producer side. The consumer function reads the property and starts a new span with the correlation ID as the parent — creating a connected trace that spans the message queue boundary.

## Diagram

![Observability Architecture Architecture](/diagrams/observability-architecture.png)

## Key Insights

- **SLOs make alerting purposeful.** "Alert when p99 > 500ms" without an SLO is a guess. "Alert when we're burning error budget at 5x expected rate" is derived from a user reliability commitment.
- **Structured logging is non-negotiable at scale.** Log queries against unstructured strings using `parse` operations in KQL are slow and brittle — structured fields query in milliseconds.
- **Trace context must propagate through queues.** Async messaging breaks traces unless you explicitly propagate context. Design this into the messaging layer, not as an afterthought.
- **OpenTelemetry is the investment.** Instrumentation tied to a specific vendor (Application Insights SDK directly) creates lock-in. OTel instrumentation routes to Azure Monitor today and can route to any OTLP-compatible backend tomorrow.
- **Cardinality is the operational trap in metrics.** High-cardinality labels (userId, requestId) in time-series metrics create millions of series and explode storage costs. Keep metric labels low-cardinality.

## Trade-offs

| Log Analytics Workspace Strategy | Cost | Query Scope | Access Control Granularity | Best For |
|---|---|---|---|---|
| Centralized (one workspace) | Lower (bulk discounts) | Org-wide queries | Workspace-level only | Centralized platform team, correlation across services |
| Per-team workspaces | Higher (fragmented) | Team-scoped | Fine-grained per team | Regulatory isolation, cost allocation, team autonomy |
| Hub-and-spoke (central + team) | Medium | Central hub for cross-cutting | Role-based per workspace | Enterprise with both compliance and correlation needs |

## References

- [Azure Monitor — OpenTelemetry overview](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-overview)
- [Application Insights — Distributed tracing](https://learn.microsoft.com/en-us/azure/azure-monitor/app/distributed-trace-data)
- [Azure Monitor — Service Level Objectives](https://learn.microsoft.com/en-us/azure/azure-monitor/app/sla-report)
- [Azure Monitor — Alerts and action groups](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)
- [Log Analytics — KQL overview](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-query-overview)
- [Azure Monitor — Workspace design guidance](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/workspace-design)
