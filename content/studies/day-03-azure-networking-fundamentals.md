---
title: "Azure Networking Fundamentals"
date: "2026-01-03"
summary: "VNets, subnets, NSGs, and routing — getting the network layer right is non-negotiable in Azure architecture."
tags: ["azure", "cloud", "architecture", "networking"]
---

## TL;DR

Azure networking starts with a VNet (your isolated address space), subnets (segmentation), NSGs (L4 firewall), and UDRs (custom routing). For enterprise topologies, hub-spoke is the de facto pattern. Private Endpoints are mandatory for production-grade service isolation. NSGs alone are insufficient — Azure Firewall adds the L7 inspection layer enterprises require.

## Context

Misconfigured Azure networking is among the top causes of cloud security incidents. Unlike on-premises networks where physical topology provides implicit isolation, Azure networking is software-defined — everything is open by default unless explicitly restricted. Understanding VNets, NSGs, routing, and service connectivity models isn't optional for any architect designing production workloads. These primitives compose into every enterprise network topology used in Azure today.

## Architecture / Design

**Virtual Networks (VNets):**

A VNet is an isolated Layer 3 network boundary in Azure. Each VNet has one or more address spaces drawn from RFC1918 space (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16). Critical planning rule: choose large, non-overlapping CIDR blocks from the start. Overlapping address space with on-premises networks or other VNets makes peering and VPN connectivity impossible without costly re-IP operations. A `/16` per major environment gives plenty of room for subnet carving. Never start with `/24` for a production VNet — you will run out.

**Subnets:**

Subnets carve the VNet address space into functional segments. Azure reserves 5 addresses per subnet (first 4 + broadcast). Subnets serve two purposes: network segmentation (separating web tier from database tier) and service delegation (certain PaaS services like App Service VNet Integration, Azure Bastion, and Azure Firewall require a dedicated delegated subnet). Common subnet layout for a spoke:

- `snet-web` — public-facing application tier
- `snet-app` — internal application/middleware tier
- `snet-data` — database and storage tier
- `snet-private-endpoints` — centralized Private Endpoint NIC placement
- `AzureBastionSubnet` — must be named exactly this for Bastion

**Network Security Groups (NSGs):**

NSGs are stateful L4 packet filters. Rules specify source/destination (IP, CIDR, service tag, or ASG), port, protocol, and Allow/Deny action. NSGs attach to either a subnet (recommended) or a network interface card. Default rules allow VNet-internal traffic and deny all inbound from the internet. Key patterns:

- Use **Service Tags** (e.g., `AzureLoadBalancer`, `AzureMonitor`, `Storage`) instead of hardcoded IP ranges — Microsoft maintains these automatically.
- Use **Application Security Groups (ASGs)** to group VMs by role and reference them in rules — decouples rules from IP addresses.
- Deny outbound to internet explicitly for data tier subnets.

**User-Defined Routes (UDRs):**

By default, Azure uses system routes. UDRs override system routes to force traffic through a Network Virtual Appliance (NVA) or Azure Firewall. The critical pattern: in a hub-spoke topology, all spoke-to-spoke and spoke-to-internet traffic has a UDR pointing `0.0.0.0/0` (or specific routes) to the hub firewall's private IP. This centralizes egress inspection without relying on peering transitivity.

**VNet Peering:**

VNet peering connects two VNets with low-latency, high-bandwidth private connectivity. Peering is **non-transitive by default** — if VNet A peers with Hub and Hub peers with VNet B, A cannot reach B via Hub without explicit routing configuration (UDR + forwarding enabled on hub). Global peering works across regions. Peering is not free — ingress/egress charges apply.

**Hub-Spoke Topology:**

The enterprise standard. A hub VNet contains shared services: Azure Firewall, Azure Bastion, VPN/ExpressRoute gateway, DNS resolver, and monitoring infrastructure. Spoke VNets contain application workloads and peer to the hub. All traffic flows through the hub for inspection. Azure Virtual WAN automates hub management at scale; manually-deployed hub-spoke works for organizations with fewer than ~20 spokes.

**Private Endpoints vs Service Endpoints:**

Service Endpoints extend VNet identity to the public endpoint of a PaaS service — traffic still goes over Microsoft backbone but the service can restrict access by VNet. Private Endpoints inject a private NIC with a private IP into your subnet for a specific PaaS instance — the public endpoint can (and should) be disabled. Private Endpoints are the current best practice for production: they work across peered VNets, support private DNS resolution, and disable exposure to the public internet entirely.

## Diagram

![Azure Networking Fundamentals Architecture](/diagrams/azure-networking-fundamentals.png)

## Key Insights

- **NSGs are necessary but insufficient for enterprise security.** NSGs operate at L4 and cannot inspect HTTP traffic, block malware C2 domains, or perform TLS inspection. Azure Firewall Premium (with IDPS and TLS inspection) is required for regulated workloads.
- **DNS is the silent dependency of Private Endpoints.** Private Endpoints require a Private DNS Zone linked to resolving VNets. Without correct DNS configuration, clients still resolve the public IP and bypass the private endpoint. The Azure Private DNS Resolver centralizes this in hub-spoke topologies.
- **Address space is permanent.** You cannot change a VNet's address space once resources are attached (you can add ranges, but not shrink or modify existing). Plan for 3–5 years of growth.
- **NSG flow logs + Traffic Analytics** are essential for understanding actual traffic patterns. Enable them from day one — retroactively auditing traffic patterns is much harder without historical flow data.

## Trade-offs

| Topology | Centralized Control | Complexity | Cost | Scale Limit | Best For |
|---|---|---|---|---|---|
| Flat VNet mesh (full peering) | Low | High (n² peerings) | High (peering charges) | ~20 VNets | Small, flat environments |
| Hub-Spoke (manual) | High | Medium | Medium | ~100 spokes | Mid-size enterprises |
| Azure Virtual WAN (managed hub) | High | Low (managed) | Higher baseline | Thousands | Large enterprises, global routing |
| Single VNet (no peering) | N/A | Low | Low | 1 subscription | Dev/test, small workloads |

## References

- [Azure VNet overview](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
- [Network security groups](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)
- [Hub-spoke network topology](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Private Endpoint](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Azure Firewall overview](https://learn.microsoft.com/en-us/azure/firewall/overview)
- [Azure Virtual WAN](https://learn.microsoft.com/en-us/azure/virtual-wan/virtual-wan-about)
