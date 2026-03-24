---
title: "Resilience Design Patterns"
date: "2026-01-26"
summary: "Distributed systems fail. Retry, circuit breaker, bulkhead, timeout, and fallback are the five patterns every cloud architect must internalize."
tags: ["architecture", "patterns", "system-design", "cloud", "azure"]
---

## TL;DR

Resilience is designed in, not bolted on. Retry without circuit breaker is a DDoS attack on your own infrastructure. Circuit breaker without bulkhead means one dependency can exhaust all resources. Always combine patterns in layers: timeout → retry → circuit breaker → bulkhead → fallback. Polly (.NET) and Azure SDK built-in policies implement all five.

## Context

Distributed systems in cloud environments fail in ways on-premises systems rarely do: network partitions, transient service unavailability, downstream rate limiting, cascading failures, and tail latency spikes. The fallacies of distributed computing — network is reliable, latency is zero, bandwidth is infinite — are all violated in practice, and your architecture must account for that.

Each resilience pattern addresses a distinct failure mode. Understanding which failure each pattern prevents (and which new failure it can create if misapplied) is what separates defensive architecture from false comfort.

## Architecture / Design

**Retry with Exponential Backoff and Jitter**

Transient failures — network blips, momentary service overload, cold start delays — are typically resolved by retrying after a short delay. The naive implementation retries immediately, which hammers an already-struggling service and makes recovery harder.

Exponential backoff grows the retry interval geometrically: retry after 1s, then 2s, then 4s, then 8s. This reduces retry pressure as the failure persists. Jitter (randomized offset ±50% of the interval) prevents retry storms — when many clients were retried on the same event, synchronized retry schedules create synchronized thundering herds. Jitter desynchronizes them.

Azure SDKs (Azure Storage, Service Bus, Cosmos DB, Azure OpenAI) have built-in retry policies with exponential backoff and jitter. For HTTP clients in .NET, Polly's `RetryPolicy` with `DecorrelatedJitterBackoffV2` is the standard implementation.

**Circuit Breaker**

A circuit breaker monitors calls to a downstream dependency and tracks failure rate. When failures exceed a threshold, it "opens" — subsequent calls fail immediately without attempting the downstream call. After a configured interval, the circuit enters "half-open" state: a probe request is allowed through. If it succeeds, the circuit closes; if it fails, it reopens.

Three states:
- **Closed**: normal operation, calls pass through
- **Open**: calls fail fast without reaching the downstream service
- **Half-open**: limited probe traffic to test recovery

Without a circuit breaker, a downstream service with 30-second timeouts will tie up all your threads waiting on that timeout, exhausting the thread pool and cascading the failure to all callers — not just those dependent on the failing service. Circuit breakers prevent this cascade.

Polly's circuit breaker policy is configurable: failure threshold (e.g., 50% failure rate), sampling duration (e.g., 10 seconds), and open duration before half-open probe.

**Bulkhead**

The bulkhead pattern isolates resource pools per dependency — named after the watertight compartments in ship hulls that prevent a breach in one compartment from sinking the entire vessel.

In practice: give each downstream dependency its own connection pool, thread pool, or semaphore. When Dependency A becomes slow and exhausts its bulkhead allocation, callers on Dependency B's pool are unaffected. Without bulkhead, slow Dependency A exhausts the shared thread pool, blocking Dependency B calls even though B is healthy.

On Azure Container Apps and AKS, bulkheads map to resource limits per container and connection pool sizing per downstream service. Polly's `BulkheadPolicy` enforces maximum concurrent calls with an optional queue.

**Timeout**

Always set explicit timeouts. The default for many HTTP clients is "wait forever" — an unresponsive downstream service will hold a connection open indefinitely, exhausting connection pools. Define timeouts per operation type: fast read operations (50–200ms), write operations (500ms–2s), long-running operations (5–30s). Timeouts must be shorter than upstream expectations — if a user expects a response in 3 seconds, your timeout on the downstream call must be under 2 seconds.

**Fallback**

When a dependency fails after retries and circuit opening, the fallback provides degraded-but-functional behavior: return cached data (stale cache), return a default/empty response, disable a non-critical feature, queue the operation for later processing. The fallback design determines user experience under partial failure. A search API that falls back to returning popular results is far better than an error page.

**Azure Service Bus Dead-Letter Queue as Resilience**

For async messaging, the dead-letter queue (DLQ) is a resilience pattern: messages that fail processing after the configured delivery count are moved to the DLQ rather than dropped. The DLQ is a safety net for unexpected message processing failures — inspect, fix, and re-enqueue rather than losing the work.

## Diagram

![Resilience Design Patterns Architecture](/diagrams/resilience-design-patterns.png)

## Key Insights

- **Retry without circuit breaker is a DDoS on your own system.** Retries amplify load on a struggling service. The circuit breaker stops the amplification once failure rate crosses the threshold.
- **Timeout is the most important and most neglected pattern.** Applications with no explicit timeouts fail catastrophically and silently — thread starvation with no clear error signal.
- **Test resilience patterns under real failure.** Chaos engineering (Azure Chaos Studio) should validate that circuit breakers trip correctly, bulkheads isolate correctly, and fallbacks activate under genuine dependency failure.
- **Jitter is not optional.** A fleet of 500 container instances retrying synchronously after a 2-second pause creates a 500-request spike at t+2. Jitter spreads that spike across the entire interval window.
- **Dead-letter queues require operational processes.** A DLQ that fills up and is never monitored is not resilience — it's deferred data loss. Alert on DLQ depth and define the runbook for reprocessing.

## Trade-offs

| Circuit Breaker Threshold | Sensitivity | False Positive Rate | Recovery Speed | Risk |
|---|---|---|---|---|
| Low (20% failure, 5s window) | High — trips quickly | High — transient spikes trip it | Slow (service avoided longer) | Over-protection, unnecessary fast fails |
| Medium (50% failure, 10s window) | Balanced | Low-Medium | Medium | Recommended default |
| High (80% failure, 30s window) | Low — tolerates failures | Low | Fast (opens rarely) | Under-protection, allows cascades |
| Disabled | None | None | N/A | Full cascade risk on dependency failure |

## References

- [Azure Architecture Center — Retry pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/retry)
- [Azure Architecture Center — Circuit Breaker pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
- [Azure Architecture Center — Bulkhead pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/bulkhead)
- [Azure Chaos Studio — Overview](https://learn.microsoft.com/en-us/azure/chaos-studio/chaos-studio-overview)
- [Azure Service Bus — Dead-letter queues](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-dead-letter-queues)
- [Azure Architecture Center — Transient fault handling](https://learn.microsoft.com/en-us/azure/architecture/best-practices/transient-faults)
