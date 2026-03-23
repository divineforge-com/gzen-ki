---
title: "Azure Resource Groups and Subscription Design"
date: "2026-01-02"
summary: "Getting your Azure management hierarchy wrong early costs months of refactoring. Here's how to think about subscriptions, resource groups, and naming from day one."
tags: ["azure", "cloud", "architecture", "devops"]
---

## TL;DR

Azure's management hierarchy is Management Groups → Subscriptions → Resource Groups → Resources. Subscriptions are billing, quota, and policy boundaries. Resource groups are lifecycle units. Get this wrong early and you'll spend months untangling it. Design intentionally before you deploy anything.

## Context

The number one mistake teams make when starting on Azure is treating the management hierarchy as an implementation concern rather than an architecture concern. A subscription is not just a billing account — it's a trust boundary, a quota container, a policy scope, and a blast radius limiter. Resource groups are not folders — they're lifecycle units with their own RBAC scope. Understanding these distinctions before provisioning the first resource saves enormous pain later.

Enterprises that grew organically on Azure often end up with dozens of unrelated resources in a single subscription, no consistent naming convention, resource groups used as security silos (they're not), and no management group structure — making it impossible to apply consistent policy across the estate.

## Architecture / Design

**The Hierarchy:**

Azure's management model has four layers:

1. **Management Groups** — containers for subscriptions. Policies and RBAC applied at this level inherit down to all child subscriptions. The root management group covers every subscription in the tenant. Create intermediate management groups for logical tiers: `Platform`, `Landing Zones`, `Sandboxes`, `Decommissioned`.

2. **Subscriptions** — the unit of billing, quota, and trust. Each subscription has its own resource limits (e.g., 980 resource groups, 800 resource instances per type per RG in some cases). Subscriptions define the blast radius for misconfiguration — a runaway deployment that exhausts quota in one subscription doesn't impact others. Policy assignments at the subscription level override resource-level settings.

3. **Resource Groups** — logical containers for resources that share a lifecycle. Resources in the same RG are deployed, updated, and deleted together. A Web App, its App Service Plan, its Key Vault reference, and its Application Insights instance belong in the same RG. A shared Log Analytics Workspace used across multiple apps should be in a shared/platform RG, not an application-specific one.

4. **Resources** — individual Azure services.

**Subscription patterns:**

- **Prod/Non-prod split**: simplest model. One production subscription, one or more non-production subscriptions (dev, test, staging). Clean billing separation, quota isolation. Fine for small teams.
- **Application-per-subscription**: each major workload gets its own subscription. Maximum blast radius isolation. Scales well for large enterprises but increases governance overhead.
- **Platform vs Workload subscriptions**: borrow from the Cloud Adoption Framework (CAF) Landing Zone model. Platform subscriptions host shared services (hub network, DNS, monitoring). Workload subscriptions host application teams' resources. This is the enterprise-scale recommendation.

**Naming conventions:**

Names are permanent (many resources can't be renamed) and visible everywhere. Establish a convention before day one:

```
{env}-{region}-{workload}-{component}
prod-eastus2-payments-api
dev-westeu-identity-db
```

Abbreviate to stay within resource-specific name limits (storage accounts: 24 chars, Key Vaults: 24 chars). Use a consistent abbreviation table: `prod`, `dev`, `stg`, `eus2` (East US 2), `weu` (West Europe).

**Resource groups as lifecycle units, not security boundaries:**

A common antipattern is creating resource groups per team to isolate access. While RBAC can be scoped to a resource group, this is not their primary purpose. Security boundaries come from RBAC assignments + Azure Policy enforcement. Resource groups should reflect deployment and lifecycle cohesion: all resources that you `az deployment group create` together and `az group delete` together belong in the same RG.

**Tagging strategy:**

Tags are the only cross-cutting metadata system in Azure. Enforce tags via Azure Policy with `Deny` or `Append` effect. Minimum tag set:

- `environment`: prod | staging | dev
- `workload`: logical application name
- `cost-center`: finance billing code
- `owner`: team or individual responsible

## Diagram

![Azure Resource Groups and Subscription Design Architecture](/diagrams/azure-resource-groups-and-subscription-design.png)

## Key Insights

- **Subscriptions are quota boundaries, not just billing containers.** If you're running large-scale AKS clusters or VM Scale Sets, you can exhaust per-subscription vCPU quotas. Spreading workloads across subscriptions gives you independent quota headroom.
- **Don't use resource groups as security boundaries alone.** RBAC at the resource group level is useful for scoping contributor rights to a team, but it doesn't prevent lateral movement via shared services. Combine RBAC with Azure Policy to enforce guardrails.
- **Retroactively restructuring subscriptions is expensive.** Moving resources between resource groups is often possible, but moving between subscriptions requires checking service support, breaking existing private endpoints, re-issuing managed identity permissions, and updating Terraform/Bicep state. Plan the hierarchy for 3-year scale, not today's scale.
- **Management Group policy is inherited and additive.** Applying a `Deny` policy at the Management Group level means every child subscription is affected. Start with `Audit`, validate coverage, then promote to `Deny`.

## Trade-offs

| Approach | Isolation | Cost Visibility | Governance Overhead | Best For |
|---|---|---|---|---|
| Single Subscription | None | Poor | Low | Prototypes, personal labs |
| Prod/Non-prod Split | Moderate | Good | Low–Medium | Small teams, single product |
| Application-per-Subscription | High | Excellent | High | Large enterprises, regulated workloads |
| CAF Landing Zone (Platform + Workload) | High | Excellent | Medium (automated) | Enterprise-scale, multi-team orgs |
| Flat Management Group (no hierarchy) | N/A | N/A | High (manual) | Anti-pattern — avoid |

## References

- [Azure Cloud Adoption Framework — management group design](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-management-groups)
- [Subscription design considerations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-subscriptions)
- [Resource group design guidance](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/overview#resource-groups)
- [Naming and tagging conventions](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Azure landing zones reference architecture](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
