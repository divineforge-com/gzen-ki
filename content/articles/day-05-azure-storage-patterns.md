---
title: "Azure Storage Patterns"
date: "2026-01-05"
summary: "Azure has five storage primitives. Picking the right one — and the right configuration — is an architecture decision, not an implementation detail."
tags: ["azure", "cloud", "architecture", "patterns", "storage"]
---

## TL;DR

Azure offers five storage primitives: Blob, Files, Queue, Table, and ADLS Gen2. Each serves distinct workloads. Storage account keys are a liability — use managed identity + RBAC instead. Lifecycle policies prevent runaway costs. Redundancy tier selection (LRS → ZRS → GRS → GZRS) must be intentional, not defaulted.

## Context

Storage decisions made early in a project are difficult to undo. Choosing Blob Storage when you needed ADLS Gen2 for Spark analytics means a migration mid-project. Choosing LRS for compliance data that requires geo-redundancy fails an audit. Storing access keys in application config creates a credential rotation headache that will eventually become a breach incident. Azure's five storage primitives map to fundamentally different data access patterns, and the right choice depends on structure, access frequency, scale, and compliance requirements.

## Architecture / Design

**Blob Storage:**

The workhorse for unstructured data — images, videos, documents, backups, log files. Three performance tiers: Standard (HDD-backed, general purpose) and Premium (SSD-backed, for low-latency block blob scenarios). Four access tiers within Standard:

- **Hot**: frequently accessed data; highest storage cost, lowest access cost.
- **Cool**: infrequently accessed (minimum 30-day retention); lower storage cost, higher access cost.
- **Cold**: rarely accessed (minimum 90-day retention); even lower storage cost.
- **Archive**: offline storage (minimum 180-day retention, hours to rehydrate); lowest storage cost, highest access cost and rehydration latency.

**Lifecycle management policies** automate tier transitions based on blob age or last-access time, turning cost optimization from a manual chore into a declarative rule: `if last_modified > 30 days, move to Cool; if > 90 days, move to Archive`. This is essential for any workload with accumulating blobs (log archives, backup files, telemetry).

**Immutability policies** (WORM — Write Once Read Many) support regulatory compliance requirements. Time-based retention policies lock blobs against modification or deletion. Legal hold policies suspend retention expiry for litigation. These are required for financial services, healthcare, and regulated industries.

**Azure Files:**

SMB 2.1/3.0 and NFS 4.1 compatible managed file shares. The primary use case is lift-and-shift: workloads that need a traditional file share. Azure Files supports both Azure AD Kerberos authentication (for cloud identities) and on-premises AD DS (for hybrid scenarios). Premium Files uses SSD for latency-sensitive workloads (< 10ms latency). Key limitation: maximum share size is 100 TiB; for large-scale analytics, ADLS Gen2 is more appropriate.

**Queue Storage:**

Simple, durable message queuing. Supports up to 64 KB per message (larger payloads should store content in Blob with a reference in the queue message). Messages have configurable TTL up to 7 days. Queue Storage is the right choice for decoupling producers from consumers in lightweight scenarios where Service Bus is over-engineered. It does not support topics, sessions, dead-lettering, or guaranteed ordering — use Service Bus Premium when those features are required.

**Table Storage:**

Schema-less NoSQL key-value store with a partition key + row key model. Extremely low cost and high throughput for the right access pattern. Practical use cases that remain relevant: audit logs, telemetry data, session state, configuration history, and large-scale but simple structured datasets. Not a replacement for Cosmos DB when you need rich queries, multiple indexes, or SLA-backed global distribution.

**Azure Data Lake Storage Gen2 (ADLS Gen2):**

Blob Storage with a hierarchical namespace enabled. Enables POSIX-compatible ACLs on directories and files (not just containers/blobs), Hadoop-compatible ABFS driver support, and optimized metadata operations for directory traversal. Required for Azure Databricks, Azure Synapse Analytics, and HDInsight workloads. The hierarchical namespace transforms Blob from a flat key store into a true filesystem — this enables efficient rename operations and directory deletes that are crucial for Spark's rename-on-commit pattern.

**Storage Account SKUs (Redundancy):**

| SKU | Description | Availability |
|---|---|---|
| LRS | 3 copies in one datacenter | 99.999999999% (11 nines) within single DC |
| ZRS | 3 copies across AZs in one region | Zone failure tolerant |
| GRS | LRS primary + async replication to paired region | Region failure tolerant (read only during failover) |
| GZRS | ZRS primary + async replication to paired region | Zone + region failure tolerant |
| RA-GRS / RA-GZRS | GRS/GZRS with read access to secondary | Secondary readable at all times |

**Security — the non-negotiable:**

Storage account keys are 512-bit passwords with full admin control. If a key leaks, the attacker has complete access to every blob, file, queue, and table in the account. The correct model: disable shared key access, use managed identity authentication, and assign RBAC roles (`Storage Blob Data Contributor`, `Storage Queue Data Reader`, etc.) to specific identities. Shared Access Signatures (SAS) are acceptable for temporary delegated access with expiry — use User Delegation SAS (backed by Entra ID identity) instead of Account SAS where possible.

## Diagram

![Azure Storage Patterns Architecture](/diagrams/azure-storage-patterns.png)

## Key Insights

- **Storage account key access is a binary footgun.** A single leaked key grants full access to everything in the account. Enable the `AllowSharedKeyAccess: false` property at the storage account level to block all key-based and SAS access and enforce Entra ID authentication.
- **Lifecycle policies are cost governance, not optional.** A storage account accumulating hot blobs over years will quietly consume budget. Implement lifecycle policies at provisioning time — the cost of not doing so compounds monthly.
- **ADLS Gen2 hierarchical namespace cannot be enabled after account creation.** This is permanent. If there is any chance you'll run Spark or Synapse workloads against the data, enable HNS from the start.
- **One storage account per workload is not always right.** Storage accounts have per-account limits (20,000 IOPS, 60 Gbps ingress). High-throughput workloads may need multiple accounts with client-side partitioning.

## Trade-offs

| Scenario | Blob Hot | Blob Cool | Blob Archive | ADLS Gen2 | Azure Files |
|---|---|---|---|---|---|
| Web assets | ✅ Best | OK | ❌ | ❌ | ❌ |
| ML training data | OK | OK | ❌ | ✅ Best | ❌ |
| Compliance archives | OK | ✅ Good | ✅ Best | OK | ❌ |
| Lift-and-shift file shares | ❌ | ❌ | ❌ | ❌ | ✅ Best |
| Log telemetry | ✅ Initially | ✅ After 30d | ✅ After 90d | ✅ Analytics | ❌ |

## References

- [Azure Blob Storage documentation](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction)
- [Blob storage access tiers](https://learn.microsoft.com/en-us/azure/storage/blobs/access-tiers-overview)
- [Azure Data Lake Storage Gen2 introduction](https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-introduction)
- [Azure Storage redundancy options](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy)
- [Authorize with Entra ID for storage](https://learn.microsoft.com/en-us/azure/storage/common/authorize-data-access)
- [Blob lifecycle management](https://learn.microsoft.com/en-us/azure/storage/blobs/lifecycle-management-overview)
