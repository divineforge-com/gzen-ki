---
title: "Azure Monitoring and Observability Stack"
date: "2026-01-10"
summary: "Azure Monitor is the umbrella — Log Analytics, Application Insights, and alerts are the instruments. Here's how the full stack fits together."
tags: ["azure", "microsoft", "cloud", "architecture", "observability"]
---

## TL;DR

Azure Monitor is the platform layer: it collects metrics, logs, and traces. Log Analytics Workspace stores and queries logs via KQL. Application Insights provides APM — distributed tracing, dependency maps, performance metrics. Alerts → Action Groups → notification channels. One Log Analytics workspace per environment is the right starting topology. Don't skip telemetry sampling configuration — uncapped Application Insights telemetry becomes an expensive surprise.

## Context

Observable systems are operable systems. Without instrumented telemetry — structured logs, metrics, distributed traces — debugging production incidents degrades to guesswork under time pressure. The gap between "we have logging" and "we have observability" is the difference between knowing something broke and knowing where, why, and what was affected when it broke. Azure's monitoring stack provides all three observability pillars (logs, metrics, traces) as a first-class managed service, deeply integrated with every Azure resource.

The challenge is not capability — it's configuration. Azure Monitor can ingest everything, but ingesting everything without sampling policies, retention tiers, and workspace design decisions creates both excessive cost and a signal-to-noise problem that makes the data less useful, not more.

## Architecture / Design

**Azure Monitor — The Platform:**

Azure Monitor is the umbrella service that collects, routes, and surfaces observability data from Azure resources, virtual machines, containers, applications, and custom sources. Data flows into two stores:

- **Metrics store**: time-series numerical data (CPU percentage, request count, response time p95). 93-day retention, near-real-time (1-minute granularity). Every Azure resource emits platform metrics automatically — no configuration required.
- **Log Analytics store**: structured log data (diagnostic logs, events, traces, custom data). Queried via Kusto Query Language (KQL). Configurable retention (30 days default, up to 730 days online, then archive tier for cheaper long-term retention).

**Log Analytics Workspace (LAW):**

The LAW is the log aggregation layer. Diagnostic settings on each Azure resource route logs to a LAW. Multiple resources, multiple services, multiple subscriptions can all funnel into a single LAW — enabling cross-service correlation queries. KQL is the query language: powerful, expressive, and optimized for log analytics workloads.

```kql
requests
| where timestamp > ago(1h)
| where resultCode >= 500
| summarize count() by bin(timestamp, 5m), cloud_RoleName
| render timechart
```

**Workspace design:** One LAW per environment (prod, non-prod) is the recommended starting point. Splitting too granularly (one per application) loses cross-service correlation capability — you can't join traces from your API with logs from your downstream service. Centralizing prod and non-prod in the same workspace creates cost and access control complications. The per-environment model balances both concerns.

**Application Insights:**

Application Insights is the APM layer — it instruments application code to capture request telemetry, dependency calls, exceptions, custom events, and custom metrics. Key capabilities:

- **Distributed tracing**: end-to-end request traces across microservices, with a waterfall view showing every HTTP call, database query, and message queue interaction in a single request's lifecycle.
- **Dependency tracking**: auto-instrumented for HTTP, SQL, Redis, Event Hubs, Service Bus — zero code changes for common dependencies.
- **Availability tests**: scheduled synthetic requests from Azure PoPs worldwide, alerting when your endpoint doesn't respond or returns errors.
- **Smart Detection**: ML-based anomaly detection that alerts on degraded failure rate, response time, or dependency performance without manual threshold configuration.
- **Live Metrics**: real-time stream of requests, failures, and performance counters — useful during deployments for immediate health signal.

Application Insights connects to a Log Analytics Workspace (workspace-based mode — the current default). All App Insights telemetry is stored in the LAW and queryable alongside other resource logs.

**Sampling:** By default, Application Insights uses adaptive sampling to limit telemetry volume when throughput is high. Configure the sampling rate explicitly for predictable billing — an uncapped App Insights on a high-traffic application can generate hundreds of GB of telemetry per day. Fixed-rate sampling at 10–20% of requests is reasonable for most workloads, retaining 100% of error events.

**VM Insights and Container Insights:**

- **VM Insights**: installs the Azure Monitor Agent on VMs and collects CPU, disk, network, and process data. The Dependency Agent adds service map visualization showing TCP connections between processes.
- **Container Insights**: monitors AKS and Arc-enabled Kubernetes clusters. Collects pod logs, node metrics, resource utilization, and OOM events. Feeds into Log Analytics and surfaces in the Azure portal as a curated workbook.

**Alerts and Action Groups:**

Alert rules evaluate metric values or log query results against thresholds. Three alert types:

- **Metric alerts**: near-real-time (1-minute evaluation), low latency, low cost. Best for threshold-based alerting on platform metrics (CPU > 90%, availability < 99%).
- **Log search alerts**: run a KQL query on a schedule (minimum 1 minute), alert if results exceed a threshold. Best for application-level conditions (error rate > 5% in 10 minutes, specific exception type seen 10+ times).
- **Activity log alerts**: trigger on Azure control plane operations (VM deleted, policy assigned, RBAC change). Essential for security and compliance monitoring.

**Action Groups** define notification channels: email, SMS, voice call, Azure mobile app push, Teams webhook, PagerDuty/Opsgenie webhook, Logic App (for complex routing), Azure Function (for custom automation). A single action group can be reused across multiple alert rules.

**Azure Managed Grafana:**

For teams that prefer Grafana dashboards over Azure portal workbooks, Azure Managed Grafana provides a fully managed Grafana instance integrated with Azure Monitor (metrics, logs, traces), Azure Data Explorer, and Prometheus. It supports Entra ID authentication and Azure RBAC, eliminating the need to manage Grafana infrastructure.

## Diagram

![Azure Monitoring and Observability Stack Architecture](/diagrams/azure-monitoring-and-observability-stack.png)

## Key Insights

- **One Log Analytics workspace per environment** is the right starting topology — it enables cross-service correlation without mixing production and non-production billing and access control boundaries.
- **Data ingestion costs are real.** Log Analytics charges per GB ingested (beyond the daily free allocation). Enable the Commitment Tier pricing if ingestion exceeds 100 GB/day — it's significantly cheaper than pay-per-GB. Review top ingestion sources monthly with the `Usage` table in KQL.
- **Archive tier for log retention.** After the interactive retention period (configurable up to 730 days), move logs to archive tier — same data, much lower cost, with restore capability for ad-hoc investigations. Required for long-term compliance log retention without paying full interactive prices.
- **Correlate via OperationId/TraceId.** End-to-end observability requires propagating trace context (W3C TraceContext or Application Insights OperationId) through every service boundary. If your downstream services don't forward the correlation header, distributed traces break at the service boundary.

## Trade-offs

| Telemetry Approach | Cost | Signal Quality | Setup Complexity | Best For |
|---|---|---|---|---|
| Platform metrics only | Very Low | Infrastructure only | None | Basic health monitoring |
| Platform metrics + diagnostic logs | Low–Medium | Good | Low | Most workloads |
| App Insights full telemetry (no sampling) | High | Excellent (noisy) | Medium | Dev/test, low-traffic services |
| App Insights with adaptive sampling | Medium | Good | Low | Standard production |
| App Insights fixed-rate sampling + custom metrics | Predictable | Excellent | Medium | High-traffic production |
| Managed Grafana + Prometheus (OSS stack) | Medium | Excellent | High | Teams with existing Grafana expertise |

## References

- [Azure Monitor overview](https://learn.microsoft.com/en-us/azure/azure-monitor/overview)
- [Log Analytics workspace overview](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-workspace-overview)
- [Application Insights overview](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
- [Sampling in Application Insights](https://learn.microsoft.com/en-us/azure/azure-monitor/app/sampling)
- [Azure Monitor alerts overview](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)
- [Azure Managed Grafana](https://learn.microsoft.com/en-us/azure/managed-grafana/overview)
