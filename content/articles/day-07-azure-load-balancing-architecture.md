---
title: "Azure Load Balancing Architecture"
date: "2026-01-07"
summary: "Azure has four load balancing services. Choosing the wrong one is a common architecture mistake with real performance and cost consequences."
tags: ["azure", "cloud", "architecture", "patterns"]
---

## TL;DR

Azure Load Balancer is L4/regional. Application Gateway is L7/regional with WAF. Azure Front Door is global L7 with CDN and anycast. Traffic Manager is DNS-only global routing with no data plane. These services compose — Front Door globally with Application Gateway per region is a common enterprise pattern. Match the service to the routing layer, not to the problem surface area.

## Context

One of the most frequently misdiagnosed architecture problems in Azure is reaching for the wrong load balancing service. Teams deploy Application Gateway when they need Front Door's global reach, or deploy Traffic Manager when they need actual load balancing rather than DNS routing. Each service sits at a different layer of the network stack, serves a different geographic scope, and carries a different cost profile. Understanding where each fits is fundamental to resilient, performant Azure architectures.

## Architecture / Design

**Azure Load Balancer (ALB):**

ALB operates at Layer 4 — it distributes TCP and UDP traffic based on 5-tuple hash (source IP, source port, destination IP, destination port, protocol). It has no awareness of HTTP, TLS, or application-level content. Two modes:

- **Public Load Balancer**: distributes internet-facing traffic to backend VMs/VMSS instances. Provides a public IP that maps to a backend pool.
- **Internal Load Balancer**: distributes traffic within a VNet (e.g., between application tier and database tier). No public IP.

Health probes (TCP, HTTP, HTTPS) remove unhealthy instances from rotation. ALB supports high availability ports (HA Ports) rules for NVA scenarios — all ports, all protocols to a single backend. ALB is the highest-throughput, lowest-latency option — it adds no more than microseconds to request latency. SKUs: Basic (deprecated) and Standard (required for AZ support, SLA, and outbound rules).

**Application Gateway (AppGW):**

AppGW operates at Layer 7 — it understands HTTP/HTTPS, WebSocket, and HTTP/2. It terminates TLS, inspects request content, and routes based on URL path, hostname, or HTTP headers. Core capabilities:

- **URL-based routing**: `/api/*` goes to one backend pool, `/static/*` goes to another
- **Multi-site hosting**: multiple domains on a single AppGW instance using hostname-based routing
- **TLS termination** (offloads crypto from backend) or **end-to-end TLS** (re-encrypts to backend)
- **WAF (Web Application Firewall)**: OWASP Core Rule Set, custom rules, bot protection — available on WAF v2 SKU
- **Cookie-based session affinity**: routes requests from the same client to the same backend instance

AppGW is regional — it exists in one region. For multi-region deployments it must be combined with a global routing layer. AppGW v2 SKU supports autoscaling and zone redundancy.

**Azure Front Door:**

Front Door is a global CDN + Layer 7 load balancer + WAF using Microsoft's anycast edge network (160+ PoPs worldwide). Client connections terminate at the nearest edge PoP, then traverse Microsoft's backbone to the origin — dramatically reducing TCP handshake latency for global users. Key capabilities:

- **Global load balancing**: distributes traffic across origins in multiple regions using latency-based, priority, or weighted routing
- **CDN**: caches static content at edge PoPs; configurable caching rules per route
- **WAF**: globally consistent policy across all origins; centralized DDoS protection
- **Health probes**: detects origin failures and reroutes within seconds
- **URL rewrite, redirect rules**: redirect HTTP to HTTPS globally, rewrite paths before forwarding to origins

Front Door Standard/Premium are the current SKUs (Classic is deprecated). Premium adds WAF managed rules, Private Link origin support, and security reports.

**Traffic Manager:**

Traffic Manager is DNS-based global load balancing — it does not sit in the data path. When a client resolves a Traffic Manager hostname, it returns the IP of the best origin based on the configured routing method:

- **Priority**: failover — primary origin unless unhealthy, then secondary
- **Weighted**: split traffic by percentage (A/B testing, canary releases)
- **Performance**: routes to the origin with lowest network latency for the client
- **Geographic**: routes based on client's geographic location (data residency use cases)
- **Subnet**: routes based on client IP subnet

Because Traffic Manager is DNS-only, there is no data plane — no TLS termination, no WAF, no request inspection. TTL-based routing means failover is not instantaneous (30–300 second DNS TTL). Use Traffic Manager when the routing decision is purely directional and you don't need application-layer inspection.

**Composition Patterns:**

The most powerful patterns combine services:

- **Global + Regional L7**: Front Door (global WAF + CDN + routing) → Application Gateway (regional WAF + TLS + URL routing) → Backend. Front Door handles global distribution; AppGW handles regional routing and provides a second WAF layer.
- **Global DNS failover**: Traffic Manager → regional App Gateways or Front Door instances. Used for multi-cloud or hybrid scenarios.
- **Internal microservices**: Internal ALB in front of a VM Scale Set or Internal AppGW for internal service mesh when not on AKS.

## Diagram

![Azure Load Balancing Architecture](/diagrams/azure-load-balancing-architecture.png)

## Key Insights

- **Front Door and Application Gateway can and should stack for regulated workloads.** Front Door's WAF handles volumetric attacks and common web exploits globally; AppGW's WAF applies per-region policies closer to the application. Defense in depth for load balancing layers.
- **Traffic Manager does not provide instant failover.** DNS TTL is typically 30–60 seconds minimum. If you need sub-minute failover, Front Door with its anycast edge and active health probing is the right tool — it can reroute in under 10 seconds.
- **Application Gateway has a warm-up time for autoscaling.** New AppGW instances take 6–8 minutes to provision. Design with minimum instance count ≥ 2 in production and configure autoscale buffers to account for provisioning time.
- **ALB source IP preservation:** By default, backends see the ALB's IP as the source. Use the `X-Forwarded-For` header (on AppGW/Front Door) or enable direct server return patterns when you need original client IP.

## Trade-offs

| Service | OSI Layer | Scope | WAF | TLS Termination | CDN | Cost Baseline |
|---|---|---|---|---|---|---|
| Azure Load Balancer | L4 | Regional | ❌ | ❌ | ❌ | Low |
| Application Gateway | L7 | Regional | ✅ (WAF SKU) | ✅ | ❌ | Medium |
| Azure Front Door | L7 | Global | ✅ | ✅ | ✅ | Medium–High |
| Traffic Manager | DNS | Global | ❌ | ❌ | ❌ | Very Low |

## References

- [Load balancing options in Azure](https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/load-balancing-overview)
- [Azure Load Balancer overview](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-overview)
- [Azure Application Gateway overview](https://learn.microsoft.com/en-us/azure/application-gateway/overview)
- [Azure Front Door overview](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-overview)
- [Azure Traffic Manager overview](https://learn.microsoft.com/en-us/azure/traffic-manager/traffic-manager-overview)
