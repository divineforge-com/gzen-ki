---
title: "Data Architecture Patterns"
date: "2026-01-27"
summary: "Lakehouse, medallion, lambda, kappa — modern data architecture has converged on a few dominant patterns. Here's how they map to Azure services."
tags: ["azure", "architecture", "patterns", "system-design", "data"]
---

## TL;DR

The medallion architecture (Bronze/Silver/Gold) on ADLS Gen2 with Delta Lake is the dominant modern data pattern on Azure. Microsoft Fabric's OneLake unifies data across the organization without duplication. For greenfield analytics workloads, start with Fabric — it consolidates Lakehouse, Warehouse, Notebooks, and Real-Time Intelligence in one SaaS platform.

## Context

Data architecture has evolved through three generations: the data warehouse era (structured relational data, expensive storage, SQL-only), the data lake era (cheap storage, any format, hard to govern), and the current Lakehouse era (data lake storage with warehouse-quality governance, ACID transactions, and SQL access).

On Azure, this evolution maps to a clear technology progression: Azure Synapse Analytics (established enterprise platform) and Microsoft Fabric (new unified SaaS platform built on OneLake). Understanding both — and when each is appropriate — is essential for any Azure data architect in 2024.

## Architecture / Design

**Medallion Architecture**

The medallion architecture organizes data into three layers with progressively higher quality:

**Bronze (Raw Layer)**: Raw data exactly as it arrived from source systems — immutable, append-only, full fidelity. If a source system sends bad data, Bronze stores it faithfully. Bronze is the source of truth for replay and re-processing. Format: original source format (JSON, CSV, Parquet, Avro) in ADLS Gen2.

**Silver (Conformed Layer)**: Cleansed, validated, and conformed data. Nulls handled, types enforced, duplicates removed, date formats standardized, schema applied. Silver is the "single version of the truth" layer — business-ready data, still at entity granularity (one row per event or entity). Format: Delta Lake (provides ACID transactions, schema enforcement, Z-order clustering for performance).

**Gold (Serving Layer)**: Business-aggregated, purpose-built datasets. KPIs, summary tables, pre-joined denormalized views optimized for consumption by BI tools, ML feature stores, and operational applications. Gold tables are rebuilt from Silver — they're reproducible, not the source of truth. Format: Delta Lake, often with partition pruning and Z-order optimization for common query patterns.

**Delta Lake on ADLS Gen2**

Delta Lake is the table format that transforms a raw data lake into a Lakehouse. It adds ACID transactions (concurrent reads and writes without corruption), time travel (query data as of any previous version), schema enforcement (reject writes that don't match the table schema), and DML operations (UPDATE, DELETE, MERGE) — capabilities that plain Parquet on a data lake doesn't have.

Delta format stores a transaction log (`_delta_log`) alongside Parquet data files. Every write is recorded as a delta log entry — this enables time travel queries (`SELECT * FROM table VERSION AS OF 42`) and audit history.

**Lambda Architecture**

Lambda splits data processing into two paths: the batch layer recomputes everything from scratch on a schedule (high accuracy, high latency), and the speed layer processes the stream in real-time (low latency, approximate or incomplete). The serving layer merges both.

On Azure: batch layer uses Azure Data Factory + Spark in Synapse/Fabric; speed layer uses Event Hubs + Azure Stream Analytics or Spark Structured Streaming; serving layer merges in Delta tables.

Lambda's weakness: two codebases to maintain (batch logic and stream logic) that must produce consistent results. Bugs manifest differently in each path.

**Kappa Architecture**

Kappa eliminates the separate batch layer: everything is a stream. Historical reprocessing is handled by replaying from the beginning of the event log (Event Hubs with long retention, or ADLS-backed Kafka). One codebase, one processing model.

On Azure: Event Hubs as the durable log (up to 90 days retention, or Kafka-compatible with infinite ADLS retention), Azure Databricks or Fabric Spark Structured Streaming as the processing layer, Delta Lake as the serving layer. Kappa simplifies operations at the cost of requiring a durable, replayable event log from source systems.

**Microsoft Fabric**

Fabric is Microsoft's unified analytics SaaS platform. Its foundational concept is **OneLake** — a single, tenant-wide data lake that spans all workspaces. Fabric workloads (Lakehouse, Data Warehouse, Notebooks, Dataflows, Real-Time Intelligence, Power BI) all operate on the same OneLake storage.

**Shortcuts** are the killer feature: a shortcut points to data in ADLS Gen2, Amazon S3, or Google Cloud Storage and makes it appear natively in OneLake — without copying. This eliminates data duplication across platforms while providing unified governance via Microsoft Purview.

For greenfield analytics, Fabric's unified experience, integrated compute, and OneLake simplify what previously required stitching together ADF, Synapse, ADLS, and Power BI.

## Diagram

![Data Architecture Patterns Architecture](/diagrams/data-architecture-patterns.png)

## Key Insights

- **Delta Lake is the foundation.** Without ACID transactions, concurrent writers corrupt Parquet files silently. Delta's transaction log makes concurrent writes safe and enables incremental processing.
- **Bronze immutability enables replay.** If a Silver or Gold transformation has a bug, Bronze lets you reprocess from raw data without going back to source systems.
- **OneLake shortcuts eliminate the ETL copy pattern.** Data that already exists in ADLS or S3 can be virtualized into Fabric without cost or latency of copying. This changes the data integration economics.
- **Z-order clustering is frequently overlooked.** Organizing Delta table files by query predicates (date, region, customer segment) can reduce query scan cost by 10–100x vs an unoptimized table.
- **Kappa requires source systems to support replay.** If your sources can't replay historical events, you need the Lambda batch path as a safety net.

## Trade-offs

| Platform | Maturity | Unified SaaS | Custom Compute | Migration Friction | Best For |
|---|---|---|---|---|---|
| Azure Synapse Analytics | High (GA 2020) | No (multiple services) | Flexible | Low (existing deployments) | Established enterprise data platforms |
| Microsoft Fabric | Medium (GA 2023) | Yes (OneLake + all workloads) | Less flexible (SaaS) | Medium | Greenfield analytics, unified platform |
| Azure Databricks | High | No (compute only) | Maximum flexibility | Low | ML-heavy, Spark-expert teams |
| Azure Data Factory + ADLS | High | No | N/A | Low | Simple ETL, existing investments |

## References

- [Microsoft Fabric — Overview](https://learn.microsoft.com/en-us/fabric/get-started/microsoft-fabric-overview)
- [Microsoft Fabric — OneLake](https://learn.microsoft.com/en-us/fabric/onelake/onelake-overview)
- [Azure Synapse Analytics — Overview](https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-what-is)
- [Delta Lake on Azure — Overview](https://learn.microsoft.com/en-us/azure/synapse-analytics/spark/apache-spark-delta-lake-overview)
- [Microsoft Fabric — Lakehouse medallion architecture](https://learn.microsoft.com/en-us/fabric/data-engineering/medallion-lakehouse-architecture)
- [Azure Architecture Center — Analytics end-to-end](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/dataplate2e/data-platform-end-to-end)
