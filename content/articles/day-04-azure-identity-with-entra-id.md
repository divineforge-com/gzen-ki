---
title: "Azure Identity with Entra ID"
date: "2026-01-04"
summary: "Identity is the new perimeter. Entra ID (formerly Azure AD) is the control plane for every Azure security model."
tags: ["azure", "microsoft", "architecture", "security", "cloud"]
---

## TL;DR

Entra ID is the identity backbone for every Azure resource. Use managed identities instead of service principals with secrets wherever possible. RBAC with least-privilege custom roles beats broad built-in roles. Workload Identity Federation eliminates secrets for GitHub Actions and Kubernetes workloads entirely.

## Context

In a perimeter-less cloud architecture, identity is the only security boundary that remains consistent across environments, networks, and devices. The classic "castle and moat" model — where the corporate network was the trust boundary — collapsed as workloads moved to cloud and users moved to remote work. Entra ID is the answer to the question: "If the network can't be trusted, what can?"

Every API call to an Azure service is authenticated through Entra ID. Every `az` CLI command, every ARM template deployment, every `BlobServiceClient` in your application — all route through Entra ID token issuance. Understanding this identity plane is not optional for cloud architects.

## Architecture / Design

**Tenants:**

A tenant is the top-level Entra ID instance — it's your organization's identity directory. A single tenant can span multiple Azure subscriptions. The tenant is the trust boundary: users, groups, service principals, and managed identities are all scoped to a tenant. B2B guest access allows identities from external tenants to be granted permissions within your tenant, but they remain external objects.

**Service Principals vs Managed Identities:**

A **service principal** is an application identity — it has a client ID, and it authenticates with either a client secret (password) or a certificate. Service principals require you to manage credential rotation, securely store the secret, and handle expiry. Secrets in environment variables or config files are a persistent source of breaches.

A **managed identity** is a service principal whose credentials are managed entirely by Azure. There are no secrets to rotate, store, or leak. The Azure runtime injects a time-limited token automatically. Every Azure resource that calls another Azure service should use a managed identity, no exceptions.

**System-Assigned vs User-Assigned Managed Identities:**

- **System-assigned**: tied 1:1 to the Azure resource. Created and deleted with the resource. Good for resources with unique identities (a single App Service accessing its own Key Vault).
- **User-assigned**: a standalone MI resource that can be attached to multiple compute instances. Essential for VM Scale Sets, AKS workloads (via Azure Workload Identity), and scenarios where you need identity portability across resource lifecycle changes. Prefer user-assigned for production — it decouples identity from resource lifecycle.

**RBAC Design:**

Azure RBAC uses roles assigned to principals at specific scopes (management group, subscription, resource group, resource). Built-in roles like `Owner`, `Contributor`, and `Reader` are overly broad for most production scenarios:

- `Owner` grants `Microsoft.Authorization/*/write` — the ability to assign roles, which is a privilege escalation vector.
- `Contributor` grants write access to all resource types in scope, including deleting production databases.

Custom roles scoped to exactly the operations a workload needs are the least-privilege approach. Example: a deployment pipeline needs `Microsoft.Web/sites/write` and `Microsoft.Web/sites/read` — not full `Contributor`.

Assign roles at the **resource group** level, not resource level, to reduce management overhead while maintaining appropriate scope.

**Conditional Access:**

Conditional Access policies enforce context-based access decisions for human users: require MFA from unmanaged devices, block access from specific countries, require compliant device state for access to sensitive applications. This layer sits above raw authentication and is essential for any organization with remote workers or external access requirements.

**Workload Identity Federation:**

This is the modern replacement for storing Azure service principal secrets in GitHub Actions secrets, Kubernetes secrets, or CI/CD pipeline variables. WIF establishes a trust relationship between Entra ID and an external identity provider (GitHub OIDC, Kubernetes OIDC). The external system presents its own token; Entra ID validates the issuer and claims, then issues an Azure access token. Zero secrets ever leave Azure. This pattern eliminates the single most common credential leak vector in cloud deployments.

Setup: create a service principal in Entra ID, configure a federated credential with the GitHub repo/branch OIDC subject claim, assign RBAC to the SP, and use the `azure/login` GitHub Action with OIDC enabled.

## Diagram

![Azure Identity with Entra ID Architecture](/diagrams/azure-identity-with-entra-id.png)

## Key Insights

- **Zero secrets in config is achievable today.** Every major Azure SDK supports managed identity authentication via `DefaultAzureCredential`. If you find yourself putting a client secret in an environment variable, reconsider the architecture. Use MI for Azure-to-Azure, and WIF for external-to-Azure.
- **RBAC assignments are additive, not subtractive.** If a principal has `Contributor` at subscription scope and `Reader` at RG scope, the `Contributor` role wins at the RG level. There is no "deny" in standard RBAC (though `denyAssignments` exist in limited scenarios). Design your hierarchy to avoid additive over-permissioning.
- **Entra ID is a shared service.** Token issuance, Conditional Access evaluation, and RBAC lookups all go through Entra ID. While it has a 99.99% SLA, understand your app's behavior if token refresh fails — use token caching and design for graceful degradation.
- **Audit sign-in logs and service principal activity.** Entra ID logs are the forensic record of every authentication event. Route them to a Log Analytics Workspace immediately; the default 30-day retention in Entra ID is insufficient for most compliance frameworks.

## Trade-offs

| Identity Type | Credential Management | Portability | Lifecycle Coupling | Best For |
|---|---|---|---|---|
| User account | High (human) | High | None | Human operators |
| Service principal + secret | High (manual rotation) | High | None | Legacy integrations, external IdP |
| Service principal + certificate | Medium (cert renewal) | High | None | Where MI unsupported |
| System-assigned MI | None | None | Coupled to resource | Single-resource workloads |
| User-assigned MI | None | High | Decoupled | Multi-resource, VMSS, AKS |
| Workload Identity Federation | None | High | Decoupled | GitHub Actions, Kubernetes, external OIDC |

## References

- [Managed identities for Azure resources](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
- [Workload Identity Federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [Azure RBAC overview](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)
- [Conditional Access overview](https://learn.microsoft.com/en-us/entra/identity/conditional-access/overview)
- [Best practices for Azure RBAC](https://learn.microsoft.com/en-us/azure/role-based-access-control/best-practices)
