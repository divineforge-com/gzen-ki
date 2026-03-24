---
title: "Azure Global Infrastructure"
date: "2026-01-01"
summary: "Azure's physical infrastructure — regions, availability zones, and geographies — is the foundation every architecture decision rests on."
tags: ["azure", "architecture", "cloud", "microsoft"]
---

## TL;DR

Azure operates 60+ regions grouped into geographies. Availability Zones (AZs) protect against datacenter failure within a region. Paired regions enable geo-redundant disaster recovery. Choose the right redundancy tier before you deploy — retrofitting is painful.

## Context

Most architects treat cloud regions as an afterthought — they pick the nearest one and move on. That decision silently shapes SLA ceilings, compliance posture, latency profiles, and recovery time objectives for the life of the workload. Azure's physical footprint is the most foundational architectural concern, and getting it wrong means either over-spending on redundancy you don't need or under-investing in resilience that a production incident will expose.

Azure's infrastructure is organized into three layers: geographies, regions, and availability zones. Each layer serves a different architectural purpose, and each introduces different cost and complexity trade-offs.

## Architecture / Design

**Regions** are discrete geographic locations, each composed of one or more datacenters connected by a dedicated low-latency network. As of 2025, Azure operates 60+ public regions worldwide, making it the broadest cloud provider footprint available. Region selection is driven by four concerns: latency to end users, data residency requirements, service availability (not every service is in every region), and compliance certification (some regions hold specific government or sovereign certifications).

**Paired Regions** are a Microsoft-defined construct where two regions within the same geography are linked for platform-level replication and sequential update rollouts. If Microsoft needs to roll out a platform update, it deploys to one paired region before the other, reducing blast radius. For geo-redundant storage (GRS), replication happens asynchronously to the paired region. Examples: East US pairs with West US 2; UK South pairs with UK West. Paired regions are the backbone of geo-disaster recovery strategies using services like Azure Site Recovery.

**Availability Zones** (AZs) are physically separate datacenters within a single region, each with independent power, cooling, and networking. AZs within a region are connected via dedicated, high-bandwidth, low-latency fiber links. A region must have at least three zones to support the AZ model. Zone-redundant deployments spread resources across all three AZs, providing 99.99% SLA for supported services (compared to 99.9% for single-zone). Services like Azure SQL Database, Azure Kubernetes Service, and Azure Load Balancer all support zone redundancy.

**Geographies** are compliance boundaries — a geography contains one or more regions and guarantees that data does not leave that boundary unless explicitly configured. EU geography customers get GDPR-friendly data residency. Sovereign clouds (Azure Government, Azure China 21Vianet) are entirely separate geographic instances.

**Deployment patterns by tier:**
- **Single-zone**: lowest cost, no protection against datacenter failure. Suitable for dev/test.
- **Zone-redundant (ZR)**: resources span all AZs in a region. Protects against single datacenter failure. Best practice for production workloads in supported regions.
- **Geo-redundant**: active or passive secondary in the paired region. Required for RTO/RPO objectives that survive a full regional outage.
- **Multi-region active-active**: highest cost and complexity. Justified for globally distributed applications with sub-100ms latency requirements worldwide or regulated uptime SLAs above 99.99%.

When selecting zones, understand that not every Azure service supports zone-redundancy. Check the [Azure service availability by region matrix](https://azure.microsoft.com/en-us/explore/global-infrastructure/products-by-region/) before designing ZR architecture. A commonly missed failure mode: Azure Resource Manager, Azure Active Directory, and other control plane services are global/regional, not zone-scoped. A control plane incident can affect your ability to deploy or scale even if your data plane is zone-redundant.

## Diagram

![Azure Global Infrastructure Architecture](/diagrams/azure-global-infrastructure.png)

## Key Insights

- **AZs don't eliminate all blast radius.** Shared control plane services (ARM, Entra ID, DNS) operate at the region level. A regional control plane issue can block deployments even with zone-redundant data plane resources. Design your runbooks for degraded-control-plane scenarios.
- **Paired regions are not symmetric.** Some services only replicate from the primary to the secondary. Failover from secondary back to primary after a DR event requires careful orchestration — test this in your DR drills.
- **Service availability varies by region.** GPT-4o might not be available in your compliance-mandated region. Lock region selection early in the design phase and validate every required service is present.
- **Latency within a region across AZs is typically <2ms.** This is low enough for synchronous replication for databases like PostgreSQL Flexible Server with zone-redundant HA. Inter-region latency is in the 10–100ms range and mandates async replication strategies.

## Trade-offs

| Strategy | RTO | RPO | Cost Multiplier | Complexity | Best For |
|---|---|---|---|---|---|
| Single Region, Single Zone | Hours | Hours | 1× | Low | Dev/test |
| Single Region, Zone-Redundant | Minutes | Near-zero | ~1.3× | Medium | Most production workloads |
| Multi-Region Active-Passive | 15–60 min | Minutes (async lag) | ~2× | High | Business-critical apps with DR requirements |
| Multi-Region Active-Active | Near-zero | Near-zero | 2.5–4× | Very High | Global apps, financial systems, 99.99%+ SLA targets |
| Multi-Geo | Varies | Varies | High | Very High | Data sovereignty + global user base |

## References

- [Azure geographies](https://azure.microsoft.com/en-us/explore/global-infrastructure/geographies/)
- [Azure regions and availability zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview)
- [Azure paired regions](https://learn.microsoft.com/en-us/azure/reliability/cross-region-replication-azure)
- [Azure services supporting availability zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-service-support)
- [Azure reliability documentation hub](https://learn.microsoft.com/en-us/azure/reliability/)
