---
title: "Azure Key Vault and Secrets Management"
date: "2026-01-08"
summary: "Secrets in config files, environment variables, or source control is a vulnerability, not a shortcut. Key Vault is Azure's answer — here's how to use it correctly."
tags: ["azure", "microsoft", "architecture", "security", "cloud"]
---

## TL;DR

Key Vault stores secrets, keys, and certificates. Use RBAC access model (not legacy vault access policies). Combine managed identity + Key Vault references in App Service and AKS for zero-secrets-in-config. Enable soft delete and purge protection for compliance. Private Endpoint + firewall for production isolation. Key Vault is not a config store — use Azure App Configuration for non-sensitive settings.

## Context

Secrets in source control is the most common, most preventable cloud security vulnerability. It happens because early in development, putting a connection string in `appsettings.json` is the path of least resistance. By the time the team realizes those secrets are in git history, committed to CI/CD pipelines, and potentially exposed via build logs, the blast radius is already wide. Azure Key Vault eliminates the excuse — it provides a managed, auditable, encrypted secrets store that integrates directly with the Azure compute layer through managed identities.

Understanding Key Vault correctly means understanding three different object types, two access models, and several integration patterns that together enable a zero-secrets posture.

## Architecture / Design

**Three Object Types:**

**Secrets** are arbitrary name-value pairs — connection strings, API keys, passwords. Secret versions are immutable; updating a secret creates a new version and the previous version remains accessible by its specific version ID. Secrets can have an expiry date, and Key Vault will emit an `EventGrid` event when a secret approaches expiry, enabling automated rotation workflows.

**Keys** are cryptographic key material (RSA 2048/3072/4096, EC P-256/P-384/P-521). The critical property: **keys never leave the vault** (when using HSM-backed operations). You don't export the key and use it in your code; you call the Key Vault API to perform the cryptographic operation (sign, verify, encrypt, decrypt, wrap, unwrap), and the key material stays server-side. This eliminates the entire class of vulnerabilities where key material is extracted from memory or disk.

**Certificates** are X.509 certificates with full lifecycle management. Key Vault can generate a certificate, integrate with DigiCert or Let's Encrypt as Certificate Authorities to issue and auto-renew TLS certificates, and notify on expiry. Integration with Application Gateway and Front Door enables automatic TLS certificate rotation without downtime.

**Access Models:**

The legacy model uses **vault access policies** — principal-level permissions (get, list, set, delete, etc.) assigned per secret/key/certificate type. Access policies are not RBAC — they don't integrate with management group inheritance and are stored in the vault object itself.

The current recommended model uses **Azure RBAC** for Key Vault. Standard RBAC roles:
- `Key Vault Secrets Officer`: read/write secrets (for ops/automation)
- `Key Vault Secrets User`: read-only secret access (for application identities)
- `Key Vault Crypto Officer`: key management
- `Key Vault Crypto User`: use keys for crypto operations
- `Key Vault Certificate Officer`: certificate management

RBAC is preferred because it uses familiar role assignment mechanics, supports management group inheritance, integrates with Azure Policy enforcement, and provides a unified audit trail in Azure Activity Log.

**Integration Patterns:**

**App Service Key Vault References:** App Service supports a special environment variable syntax: `@Microsoft.KeyVault(SecretUri=https://vault.vault.azure.net/secrets/secret-name/)`. At runtime, the App Service platform resolves this reference using the app's system-assigned or user-assigned managed identity and injects the secret value. The application code reads a normal environment variable — it never knows or cares that Key Vault is involved. This pattern eliminates secrets from deployment configuration entirely.

**AKS / Kubernetes:** The Secrets Store CSI Driver with the Azure Key Vault provider mounts Key Vault secrets as a Kubernetes volume or syncs them to Kubernetes Secrets. Combined with Workload Identity (Azure AD workload identity binding to a Kubernetes service account), the pod authenticates to Key Vault without any secrets in the Kubernetes manifest or environment variables.

**Secret rotation automation:** Use Azure Event Grid (Key Vault event `SecretNearExpiry` or `SecretExpired`) to trigger an Azure Function that rotates the secret (e.g., generates a new database password, stores it in Key Vault, updates the database) and publishes a new version. The application picks up the new version on next Key Vault reference resolution.

**Operational Hardening:**

- **Soft delete**: deleted vault objects are retained for a configurable period (7–90 days) and can be recovered. Enabled by default for new vaults.
- **Purge protection**: prevents hard deletion of soft-deleted objects. Required for compliance frameworks that mandate data recovery capability. Once enabled, cannot be disabled.
- **Key Vault Firewall**: restricts access to specific VNet subnets or IP ranges. For production, combine with a Private Endpoint to fully remove the vault from the public internet.
- **Diagnostic logs**: route Key Vault audit logs (AuditEvent category) to Log Analytics. Every secret access, key operation, and policy change is logged — this is your compliance audit trail.

**Key Vault vs Azure App Configuration:**

Key Vault is not a general-purpose configuration store. It's optimized for sensitive values and carries per-operation cost. Azure App Configuration is the right store for non-sensitive configuration (feature flags, connection strings without credentials, environment-specific settings). The two services integrate — App Configuration can reference Key Vault secrets via Key Vault references, giving you a unified configuration API surface with appropriate security for each value type.

## Diagram

![Azure Key Vault and Secrets Management Architecture](/diagrams/azure-key-vault-and-secrets-management.png)

## Key Insights

- **Soft delete + purge protection should be enabled for every production vault.** A `az keyvault delete` without purge protection permanently destroys all secrets, keys, and certificates in the vault. This has happened in production. It is recoverable with soft delete; it is catastrophic without it.
- **Key Vault has a throttling limit of ~2,000 operations per 10 seconds per vault.** High-throughput applications that call Key Vault on every request will hit this limit. The correct pattern: cache the secret value in memory with a TTL (e.g., 30 minutes). The managed identity token already handles re-authentication automatically.
- **Separate vaults for production and non-production.** Vault access policies (and RBAC roles) apply to the entire vault — a single vault for all environments risks production secret access from development pipelines.
- **Never log secret values.** Obvious in principle, harder in practice. Ensure structured logging frameworks don't serialize objects that contain Key Vault secret values. Use `[JsonIgnore]` or equivalent.

## Trade-offs

| Option | Security | Cost | Compliance | Management Overhead | Best For |
|---|---|---|---|---|---|
| Standard Key Vault (software-protected keys) | High | Low | Most frameworks | Low | General production workloads |
| Key Vault HSM (Premium SKU) | Very High | Medium | FIPS 140-2 L2 | Low | Regulated industries |
| Managed HSM (dedicated HSM) | Maximum | High | FIPS 140-2 L3 | Medium | Financial, government, highest assurance |
| App Config (non-secrets) | Medium | Very Low | N/A | Very Low | Feature flags, non-sensitive config |

## References

- [Azure Key Vault overview](https://learn.microsoft.com/en-us/azure/key-vault/general/overview)
- [Key Vault RBAC guide](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [App Service Key Vault references](https://learn.microsoft.com/en-us/azure/app-service/app-service-key-vault-references)
- [AKS Secrets Store CSI Driver](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver)
- [Key Vault soft delete overview](https://learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview)
- [Azure Managed HSM overview](https://learn.microsoft.com/en-us/azure/key-vault/managed-hsm/overview)
