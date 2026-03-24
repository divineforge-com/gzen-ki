---
title: "Zero Trust Architecture on Azure"
date: "2026-01-29"
summary: "Never trust, always verify. Zero Trust is not a product — it's an architecture philosophy that Azure's identity, network, and endpoint controls can enforce."
tags: ["azure", "microsoft", "architecture", "security", "cloud"]
---

## TL;DR

Zero Trust eliminates implicit trust based on network location. Every request is authenticated, authorized, and inspected regardless of where it originates. The practical implementation layers: Entra ID Conditional Access (identity plane), Private Endpoints + microsegmentation (network plane), and managed identities with scoped RBAC (service-to-service plane). The biggest gap is always lateral movement via overprivileged identities.

## Context

The perimeter security model — trust everything inside the network boundary — is obsolete in cloud environments where workloads span multiple clouds, users access from any device, and "inside the network" is no longer a meaningful security boundary.

Zero Trust, formalized by NIST SP 800-207, assumes breach: any user, device, or workload may be compromised at any time. Every access request is treated as if it originates from an untrusted network. This isn't paranoia — it's the recognition that sophisticated attackers routinely achieve initial access and then move laterally using implicitly trusted internal connections.

Microsoft's Zero Trust architecture maps to three planes: identity (who is asking), endpoints/devices (from what), and network (how they're connecting). Azure provides managed services for each plane.

## Architecture / Design

**Identity Plane: Entra ID Conditional Access**

Entra ID (formerly Azure Active Directory) is the policy enforcement point for the identity plane. Conditional Access policies evaluate signals at authentication time and enforce access decisions:

- **Device compliance**: require Intune-managed, compliant device. Blocks personal/unmanaged devices from accessing sensitive applications.
- **Location**: restrict access from named locations (corporate IP ranges) or block high-risk geographies.
- **Sign-in risk**: Entra ID Identity Protection uses ML to score sign-in risk (leaked credentials, impossible travel, anonymized IP). High-risk sign-ins trigger MFA step-up or block.
- **User risk**: persistent risk signal on a user account (multiple failed sign-ins, known breach). Require password reset before access.

Conditional Access policies are the primary control for user-facing access. Every application in the estate should be registered in Entra ID and protected by at minimum an MFA policy.

**Network Plane: Microsegmentation**

Traditional VNet architecture trusts all traffic within a subnet. Zero Trust requires microsegmentation: every communication path is explicitly permitted, and all others are denied by default.

NSGs (Network Security Groups) enforce Layer 4 (IP/port) rules per subnet and NIC. Azure Firewall provides Layer 7 inspection, FQDN filtering, and threat intelligence-based blocking for east-west traffic between subnets. Private Endpoints bring Azure PaaS services (Storage, Key Vault, Cosmos DB, Service Bus) onto the VNet with private IP addresses — eliminating public endpoint exposure entirely.

Hub-and-spoke VNet topology with Azure Firewall in the hub inspects all inter-spoke traffic. No spoke-to-spoke communication is permitted without traversing the firewall — enforcing Zero Trust network posture across all workloads.

Service Endpoints vs Private Endpoints: Private Endpoints are strictly superior for Zero Trust — they provide a private IP in your VNet, eliminate public endpoint exposure, and work with Private DNS Zones for name resolution. Service Endpoints provide VNet-based ACLs on public endpoints — better than nothing, but still publicly accessible.

**Service-to-Service: Managed Identities and RBAC**

Inter-service authentication in traditional architectures used connection strings and API keys stored in configuration — effectively credentials with no expiration or scope. Zero Trust replaces this with managed identities: Azure-assigned identities for compute resources (VMs, App Service, Container Apps, AKS workload identity) that authenticate to other Azure services without any credentials in code or configuration.

Scope managed identity RBAC assignments to the minimum required permission on the minimum required resource scope. An Azure Function that reads from one specific Storage container should have `Storage Blob Data Reader` on that container, not on the storage account, not on the subscription. Overprivileged managed identities are the primary lateral movement vector for cloud-native attackers.

**Privileged Identity Management (PIM)**

Standing access to privileged roles (Owner, Contributor, Global Admin) violates least-privilege. Entra ID PIM provides Just-in-Time (JIT) role activation: a user requests activation of a privileged role, triggers an approval workflow, and receives time-bound access (1–8 hours). All activations are logged and auditable.

PIM combined with access reviews (periodic certification of role assignments) ensures privileged access is justified, approved, and automatically expired — eliminating the accumulation of standing privileged access over time.

**Microsoft Defender for Cloud**

Defender for Cloud provides continuous Zero Trust posture assessment: secure score measures compliance with Microsoft Cloud Security Benchmark across identity, network, data, and compute. Recommendations are prioritized by severity and include remediation guidance. Enable enhanced workload protection for servers (Defender for Servers), containers (Defender for Containers), and databases to add runtime threat detection.

## Diagram

![Zero Trust Architecture on Azure Architecture](/diagrams/zero-trust-architecture-on-azure.png)

## Key Insights

- **Lateral movement is the critical gap.** An attacker with initial access to one compute resource and an overprivileged managed identity can enumerate and access resources across the subscription. Scope every managed identity to the minimum required permission.
- **Private Endpoints are the Zero Trust default for PaaS.** A storage account or Key Vault with a public endpoint is accessible from the internet regardless of what's inside your VNet. Private Endpoints remove that public surface entirely.
- **PIM adoption requires culture change.** Developers who have always had standing Contributor access resist JIT activation friction. Start with Privileged Roles (Owner, User Access Administrator) before expanding to broader roles.
- **Conditional Access without device compliance is incomplete.** MFA on an unmanaged, malware-infected personal device doesn't prevent credential theft at the session level. Device compliance closes this gap.
- **Zero Trust is incremental.** Full implementation across an enterprise estate takes years. Prioritize identity (Conditional Access, MFA) first — it's the highest-impact, most immediate return.

## Trade-offs

| Zero Trust Maturity Level | Security Posture | User Friction | Implementation Effort | Recommended For |
|---|---|---|---|---|
| Level 1: MFA everywhere | Good | Low-Medium | Low | Immediate baseline for all orgs |
| Level 2: Conditional Access + device compliance | Strong | Medium | Medium | Organizations with managed device fleets |
| Level 3: Private Endpoints + microsegmentation | Very strong | Minimal (network-level) | High | Production workloads with compliance requirements |
| Level 4: PIM + JIT + managed identity scoping | Comprehensive | Medium (JIT friction) | High | Regulated industries, sensitive data |
| Level 5: Full Zero Trust (all planes, all resources) | Maximum | Medium | Very high | Government, financial services, critical infrastructure |

## References

- [Microsoft — Zero Trust overview](https://learn.microsoft.com/en-us/security/zero-trust/zero-trust-overview)
- [Entra ID — Conditional Access overview](https://learn.microsoft.com/en-us/entra/identity/conditional-access/overview)
- [Azure — Managed identities overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
- [Entra ID — Privileged Identity Management](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-configure)
- [Azure — Private Endpoints overview](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Microsoft Defender for Cloud — Overview](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-cloud-introduction)
