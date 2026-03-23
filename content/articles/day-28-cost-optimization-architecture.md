---
title: "Cost Optimization Architecture"
date: "2026-01-28"
summary: "Cloud costs are an architecture decision. Rightsizing, reservations, spot, auto-scale, and FinOps practices are engineering levers, not finance department problems."
tags: ["azure", "cloud", "architecture", "patterns", "cost"]
---

## TL;DR

Cloud cost is an architecture output, not an accounting input. The highest-leverage levers in order: rightsizing (free, immediate 40–60% reduction), reservations (40–72% discount for committed capacity), Spot VMs (90% discount for interruptible workloads), and scale-to-zero (KEDA/serverless for variable workloads). Enforce tagging via Azure Policy — not as suggestion, as requirement.

## Context

Cloud billing surprises are engineering failures, not finance failures. The decision to over-provision compute "just in case," to run dev environments 24/7, to skip reserved instances because "we'll optimize later," or to store data in premium tiers indefinitely — these are architectural decisions made by engineers that show up as budget overruns.

FinOps is the practice of applying engineering rigor to cloud financial management. The FinOps Foundation defines a model where engineering teams own their cloud spend, with visibility (what's being spent, by whom, on what), accountability (teams can see and are responsible for their costs), and optimization (engineering actively reduces waste). Azure Cost Management provides the tooling; the engineering culture must provide the discipline.

## Architecture / Design

**Rightsizing**

Most Azure workloads are overprovisioned at initial deployment and left unchanged. Azure Advisor's cost recommendations analyze VM CPU and memory utilization over 7–30 days and suggest rightsizing: downgrading from D8s v5 (8 vCPU) to D4s v5 (4 vCPU) for a workload running at average 15% CPU is immediate, zero-risk savings.

Azure VM Insights provides utilization percentile data (p95, p99) — size for the p95, not the peak. If a VM spikes to 100% CPU for 30 seconds once a week, that's not a sizing requirement; it's an autoscaling trigger.

Action: Run Azure Advisor cost recommendations monthly. Require justification for instances running below 20% average utilization.

**Reservations and Savings Plans**

Pay-as-you-go pricing is the most expensive compute pricing tier. For predictable baseline capacity, two commitment-based discount programs apply:

**Azure Reservations**: commit to a specific VM family, region, and term (1 or 3 years). Discounts range from 40% (1-year) to 72% (3-year) vs pay-as-you-go. Reservations are instance-type specific — a D4s v5 reservation applies only to D4s v5 VMs. Ideal for stable, predictable workloads.

**Azure Savings Plans**: commit to a spend rate ($/hour) in compute across any VM size, region, or OS. Discounts up to 65% vs pay-as-you-go. More flexible than reservations — commitment applies across different instance types. Ideal when workload composition changes but total compute remains stable.

Rule of thumb: buy reservations for the baseline, let pay-as-you-go cover peak and variable demand.

**Spot VMs**

Azure Spot VMs use spare Azure datacenter capacity at up to 90% discount. The caveat: Spot VMs can be evicted with 30-second notice when Azure needs the capacity back. This makes Spot appropriate for: batch processing (checkpointed jobs that can restart), stateless scale-out (additional nodes in a cluster that can be replaced), dev/test environments, and CI/CD build agents.

VMSS (Virtual Machine Scale Sets) support mixed-priority pools: a baseline of on-demand instances with Spot instances filling additional capacity. KEDA-based autoscaling on AKS can target Spot node pools for cost-optimized scale-out.

**Auto-Scale and Scale-to-Zero**

Provisioned capacity running at night handling zero traffic is waste. Scale-to-zero eliminates this: Azure Functions Consumption plan, Azure Container Apps, and AKS with KEDA all support scaling to zero replicas when there's no traffic.

KEDA (Kubernetes Event-driven Autoscaling) is the standard for container workloads: it scales based on external signals — Service Bus queue depth, Event Hub consumer lag, HTTP request rate, custom metrics. Scale from 0 to N based on actual demand, not scheduled estimates.

For AKS, use the cluster autoscaler to add and remove nodes based on pod scheduling pressure. Combine with Spot node pools for cost-efficient scale-out.

**Tagging Enforcement via Azure Policy**

Cost tags (environment, team, workload, cost-center) enable cost allocation, showback, and chargeback. The problem: tags only work if they're consistently applied. Azure Policy's Deny effect enforces required tags at resource creation — resources without `environment` and `team` tags fail deployment. This is not optional governance; it's a prerequisite for any meaningful FinOps practice.

Use Azure Cost Management's cost allocation rules to split shared service costs (networking, monitoring, shared compute) across consuming teams by tag-attributed consumption ratios.

**Dev/Test Optimization**

Azure Dev/Test subscription pricing provides reduced rates (up to 55% on some VM sizes) for non-production workloads. Apply auto-shutdown schedules to dev VMs — an 8 AM–6 PM schedule reduces runtime by 65% for a developer VM. Azure Dev Box and Azure Deployment Environments provision ephemeral developer environments on demand, eliminating always-on dev infrastructure.

## Diagram

![Cost Optimization Architecture Architecture](/diagrams/cost-optimization-architecture.png)

## Key Insights

- **Tagging without enforcement is theater.** 60% tag coverage on resources means 40% of your spend is unattributed and unoptimizable. Azure Policy Deny on missing tags is non-negotiable for FinOps maturity.
- **Reserved instances require capacity planning discipline.** Under-buying wastes discount potential. Over-buying reserves capacity you don't use. Refresh quarterly as workload composition changes.
- **Spot VMs require checkpoint-aware application design.** Applications that can't survive a 30-second eviction notice can't use Spot. Design for graceful interruption from day one.
- **Scale-to-zero only works when cold start is acceptable.** For user-facing latency-sensitive APIs, zero replicas means cold start on first request. Keep a minimum of 1 replica for critical paths.
- **Unit economics clarify optimization priority.** "Cost per API call," "cost per document processed," or "cost per active user" makes cost visibility actionable — teams can optimize the metric, not just watch the bill.

## Trade-offs

| Pricing Model | Discount vs PAYG | Flexibility | Risk | Best For |
|---|---|---|---|---|
| Pay-as-you-go | 0% (baseline) | Maximum | Minimum | Variable/burst workloads |
| 1-year Reservation | ~40% | Low (committed) | Waste if workload changes | Stable compute, confirmed for 1+ year |
| 3-year Reservation | ~72% | Very low | Higher waste risk | Long-running stable workloads |
| Savings Plan | Up to 65% | Medium (flexible instance) | Some waste if spend drops | Mixed compute, evolving instance types |
| Spot VMs | Up to 90% | High (any available) | Eviction | Batch, CI/CD, stateless scale-out |

## References

- [Azure Cost Management — Overview](https://learn.microsoft.com/en-us/azure/cost-management-billing/cost-management-billing-overview)
- [Azure Reservations — Overview](https://learn.microsoft.com/en-us/azure/cost-management-billing/reservations/save-compute-costs-reservations)
- [Azure Savings Plans — Overview](https://learn.microsoft.com/en-us/azure/cost-management-billing/savings-plan/savings-plan-compute-overview)
- [Azure Spot VMs — Overview](https://learn.microsoft.com/en-us/azure/virtual-machines/spot-vms)
- [KEDA on AKS — Overview](https://learn.microsoft.com/en-us/azure/aks/keda-about)
- [Azure Policy — Enforce tagging](https://learn.microsoft.com/en-us/azure/governance/policy/tutorials/govern-tags)
