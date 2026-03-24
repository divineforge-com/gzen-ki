---
title: "Platform Engineering and Internal Developer Platforms"
date: "2026-01-30"
summary: "Platform Engineering is the discipline of reducing cognitive load for application teams. IDPs are the product — golden paths, self-service infra, and paved roads that teams actually want to use."
tags: ["azure", "architecture", "devops", "patterns", "cloud"]
---

## TL;DR

An Internal Developer Platform succeeds when using it is faster than not using it. Platform teams are product teams — application developers are customers. The technical components (service catalog, IaC templates, CI/CD pipelines, policy guardrails) serve the goal of reducing cognitive load so application teams can focus on delivering business value, not yak-shaving infrastructure.

## Context

The paradox of DevOps at scale: as organizations shift left — giving application teams ownership of their infrastructure — cognitive load grows. Teams that used to worry about application code now also manage Kubernetes manifests, Terraform modules, security policies, observability configuration, and incident response runbooks. For most application teams, most of the time, this is undifferentiated heavy lifting.

Platform Engineering is the discipline that solves this. A platform team builds and maintains the shared infrastructure layer — the "golden path" — that lets application teams provision and operate cloud workloads without becoming cloud infrastructure experts. The platform is a product; the application teams are its customers.

## Architecture / Design

**The Golden Path Concept**

A golden path is an opinionated, well-supported implementation pattern for a common use case. "Deploy a web API on Azure" has thousands of possible implementations. The golden path narrows it to one well-designed, tested, secure, compliant implementation that application teams can adopt in hours, not weeks.

Golden paths are not mandates — they're incentives. A good golden path is faster, more secure, and better-supported than a team building their own path. Teams that bypass it do so because the platform has a product problem: it doesn't serve their needs, it's too slow, or it has gaps. The platform team's job is to close those gaps, not to mandate compliance.

**Technical Components of an IDP**

**Service Catalog (Backstage.io)**: the front door of the IDP. Backstage is the dominant open-source service catalog — it provides a software catalog (what services exist, who owns them, what their dependencies are), a TechDocs integration (documentation as code alongside the service), and a plugin ecosystem for integrating CI/CD status, cloud cost, security scores, and API documentation.

On Azure, the Backstage Azure DevOps plugin integrates pipeline status; the Azure Cost plugin surfaces per-service cost. The service catalog becomes the operational dashboard for every team's services.

**Infrastructure Templates (IaC)**:Platform-maintained Bicep modules or Terraform modules that encode the golden path. A module for "deploy an App Service with managed identity, private endpoint, Application Insights, and Key Vault access" encapsulates all platform standards: security, observability, and networking configuration are pre-wired. Application teams instantiate the module with their specific parameters.

Terraform Registry (internal) or Bicep module registry (Azure Container Registry) hosts versioned module releases. Semantic versioning enables controlled upgrades — teams on v2.1.0 can stay there until ready to adopt breaking changes in v3.0.0.

**CI/CD Templates**: Reusable GitHub Actions workflow templates or Azure DevOps pipeline templates for common delivery patterns: build and push container image, run security scans, deploy to staging, run smoke tests, deploy to production with approval gate. Application teams reference the shared template and override only what's specific to their service.

Reusable workflows enforce standards: every deployment runs SAST (GitHub Advanced Security / Defender for DevOps), DAST for web applications, and infrastructure security scanning (Checkov for Terraform, PSRule for Bicep) — without application teams configuring this themselves.

**Policy Guardrails (Azure Policy)**: Azure Policy Initiatives (policy sets) enforce platform standards at the infrastructure level: all resources must have required tags, all storage accounts must use private endpoints, all VMs must have Defender for Servers enabled. Policy with Deny effect prevents non-compliant resources from being created — guardrails that catch misconfigurations before they reach production.

**Secrets Management**: Azure Key Vault with the platform-provisioned access pattern: when an application team registers a new service via the platform, a Key Vault is automatically provisioned with the service's managed identity granted `Key Vault Secrets User` on that vault. Application teams store secrets in Key Vault and read them via the Secrets Store CSI driver (AKS) or App Service Key Vault references — zero credential management in application code.

**Observability Defaults**: Application Insights automatically provisioned per service and connected to a central Log Analytics workspace. Platform-managed dashboards for the standard SLIs (availability, p99 latency, error rate) are provisioned automatically. Teams see working dashboards on day one.

**Azure Deployment Environments**

Azure Deployment Environments provision application-ready environments from platform-curated Environment Definitions (IaC templates). A developer can create a complete dev or test environment — App Service, database, storage, networking — from a catalog of approved templates in minutes, without infrastructure expertise. Environments are ephemeral: developers create them for a feature branch and delete them when done.

This eliminates the "shared dev environment" bottleneck where multiple developers collide on shared configuration and breaks the "it works on my machine" class of problems.

## Diagram

![Platform Engineering and Internal Developer Platforms Architecture](/diagrams/platform-engineering-and-internal-developer-platforms.png)

## Key Insights

- **Platform adoption is a product metric.** Track how many application teams use the golden path, how long it takes a new service to reach production, and developer satisfaction scores. Low adoption means product-market fit failure.
- **The platform team must eat their own cooking.** The platform team's own services should run on the platform. Teams that build tools they don't use produce tools nobody wants.
- **Over-standardization is a real failure mode.** A golden path so opinionated it doesn't support legitimate variations drives teams off-platform. Design for the 80% case, provide escape hatches for the 20%.
- **DORA metrics are the outcome metrics.** Deployment frequency, lead time for changes, mean time to restore, and change failure rate measure whether the platform is actually improving team delivery, not just delivering tooling.
- **Incremental platform adoption is the right strategy.** Start with CI/CD templates (immediate value, low risk), then IaC modules, then service catalog, then self-service environments. Each layer delivers value independently.

## Trade-offs

| Model | Developer Autonomy | Platform Consistency | Cognitive Load | Governance | Best For |
|---|---|---|---|---|---|
| Centralized platform team | Low-Medium | High | Low (platform does it) | Strong | Large orgs, regulated industries |
| Federated DevOps (each team owns infra) | High | Low (divergent) | High | Weak | Small orgs, early-stage teams |
| Platform team + federated contributors | High (within guardrails) | High | Medium | Strong | Scaling engineering organizations |
| No platform (pure DIY) | Maximum | None | Maximum | None | <5 engineers, single product |

## References

- [Azure Deployment Environments — Overview](https://learn.microsoft.com/en-us/azure/deployment-environments/overview-what-is-azure-deployment-environments)
- [Azure — Developer platform guidance](https://learn.microsoft.com/en-us/azure/architecture/guide/developer-platforms/devplatform)
- [GitHub Actions — Reusable workflows](https://learn.microsoft.com/en-us/azure/developer/github/github-actions)
- [Azure Bicep — Module registry](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/private-module-registry)
- [Azure Policy — Initiative definitions](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure)
- [Microsoft Defender for DevOps — Overview](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-devops-introduction)
