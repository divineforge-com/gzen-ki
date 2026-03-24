---
title: "API Gateway Patterns"
date: "2026-01-24"
summary: "Azure API Management is not just a proxy — it's the policy enforcement layer, developer portal, and observability hub for your API estate."
tags: ["azure", "architecture", "patterns", "cloud", "devops"]
---

## TL;DR

Azure API Management centralizes auth, rate limiting, caching, versioning, and observability across your entire API estate. JWT validation at the gateway offloads auth from every backend service. The self-hosted gateway extends the same policy model to on-premises and multi-cloud backends. Don't build API cross-cutting concerns into individual services.

## Context

An API gateway sits in front of backend services and handles concerns that are identical across all of them: authentication, authorization, rate limiting, request/response transformation, caching, versioning, and observability. Without a gateway, every microservice reimplements these in subtly inconsistent ways, creating a maintenance burden and security risk surface that compounds with each new service.

Azure API Management (APIM) is Microsoft's managed API gateway. It's mature, feature-rich, and deeply integrated with the Azure ecosystem. Understanding the policy pipeline and tier selection determines how much of its value you actually capture.

## Architecture / Design

**APIM Tier Selection**

- **Consumption tier**: serverless, per-call billing, cold start latency, limited policy support (no VNet integration, no developer portal customization). Use for low-volume or prototype workloads.
- **Developer tier**: full feature set, single unit, no SLA. Non-production environments only.
- **Standard tier**: production-ready, zone-redundant option, no VNet injection. Good for most workloads.
- **Premium tier**: multi-region deployment, VNet injection (APIM in your private network), Azure Availability Zones, dedicated capacity. Required for private backend APIs and global API distribution.

**The Policy Pipeline**

Every API request flows through a four-stage policy pipeline:

1. **Inbound**: runs before the request reaches the backend — authentication, rate limiting, request transformation, caching lookup, routing.
2. **Backend**: controls how the request is forwarded — load balancing, circuit breaker, timeout.
3. **Outbound**: runs on the response before returning to caller — response transformation, header injection, cache store.
4. **On-error**: handles faults — custom error responses, logging.

Policies are XML-based and composable. Key policies in production architectures:

**`validate-jwt`**: validates a JWT bearer token against an Azure AD (Entra ID) JWKS endpoint. Verifies signature, expiry, audience, and issuer. Can extract claims and set them as context variables for downstream policies. This single policy offloads OAuth2 token validation from every backend service — a backend receives only pre-validated requests with a known caller identity.

**`rate-limit-by-key`**: enforces per-consumer call rate limits using any context variable as the key (subscription key, JWT subject, IP). Prevents a single consumer from exhausting shared backend capacity. Critical for monetized or tiered API products.

**`cache-lookup` / `cache-store`**: implements HTTP response caching with configurable TTL, keyed on URL and configurable headers. Dramatically reduces backend load for read-heavy APIs with stable data.

**`set-backend-service`**: dynamically routes requests to different backends based on policy conditions — enables A/B testing, canary deployments, and blue-green switching at the gateway layer without consumer changes.

**`mock-response`**: returns a static response without calling the backend. Enables API-first development where frontend teams consume a mocked API while backend teams build the implementation.

**Backend Circuit Breaker**

APIM's circuit breaker policy detects backend failures (5xx responses, timeouts) and trips the circuit, returning a fast failure to callers instead of waiting for timeouts to cascade. The circuit half-opens after a configured interval to probe backend recovery. This requires no changes to backend services.

**API Versioning**

APIM supports three versioning strategies: URL path versioning (`/v1/resource`, `/v2/resource`), query string versioning (`?api-version=2024-01-01`), and header versioning (`Api-Version: 2024-01-01`). All three can coexist on the same APIM instance, supporting legacy consumers while publishing new versions. Version sets group related API versions for documentation and management.

**Developer Portal**

APIM's built-in developer portal provides self-service API discovery: browse API catalog, read auto-generated documentation, get API keys, and test APIs in-browser. For internal APIs, this replaces scattered API documentation in wikis and reduces onboarding time significantly.

**Self-Hosted Gateway**

The APIM self-hosted gateway deploys as a Docker container, registerable to an existing APIM instance. It runs the same policy engine locally — in on-premises data centers, edge locations, or other clouds — while the APIM control plane in Azure manages configuration and observability centrally.

## Diagram

![API Gateway Patterns Architecture](/diagrams/api-gateway-patterns.png)

## Key Insights

- **Centralize JWT validation at the gateway.** Every microservice validating tokens independently creates inconsistency (library versions, validation logic) and operational overhead. Validate once at the gateway, pass validated identity downstream via headers.
- **Rate limiting without key-based policies is insufficient.** Global rate limits protect the backend but don't prevent a single abusive consumer from monopolizing capacity. Always rate limit by consumer identity.
- **The mock-response policy enables genuine API-first development.** Define the API contract in APIM, mock the responses, let consumers develop against it — decouple frontend and backend delivery.
- **APIM Premium is required for private backends.** If your backends are in a VNet with private endpoints, you need VNet injection (Premium tier) to route traffic through APIM without traversing the public internet.
- **Subscription keys are not authentication.** APIM subscription keys identify a consumer product subscription — they're not a security mechanism. Always layer JWT or mutual TLS authentication on top.

## Trade-offs

| APIM Tier | VNet Integration | Multi-Region | Availability SLA | Min Monthly Cost | Best For |
|---|---|---|---|---|---|
| Consumption | No | No | None (serverless) | $0 (per call) | Prototypes, low-volume |
| Developer | No | No | None | ~$50 | Non-production, testing |
| Standard | No (v2 has VNet) | No | 99.95% | ~$300 | Most production workloads |
| Premium | Yes (full VNet inject) | Yes | 99.99% | ~$3,000+ | Enterprise, global APIs, private backends |

## References

- [Azure API Management — Overview](https://learn.microsoft.com/en-us/azure/api-management/api-management-key-concepts)
- [Azure API Management — Policies overview](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-policies)
- [Azure API Management — validate-jwt policy](https://learn.microsoft.com/en-us/azure/api-management/validate-jwt-policy)
- [Azure API Management — Rate limiting policies](https://learn.microsoft.com/en-us/azure/api-management/rate-limit-policy)
- [Azure API Management — Self-hosted gateway](https://learn.microsoft.com/en-us/azure/api-management/self-hosted-gateway-overview)
- [Azure API Management — API versioning](https://learn.microsoft.com/en-us/azure/api-management/api-management-versions)
