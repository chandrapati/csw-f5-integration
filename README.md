# Cisco Secure Workload → F5 BIG-IP Integration Guide

![Visitors](https://visitor-badge.laobi.icu/badge?page_id=chandrapati.csw-f5-integration&left_text=visitors)

A step-by-step, **beginner-friendly** integration guide for **F5 BIG-IP** + **Cisco Secure Workload (CSW)** — covering **service-inventory labels**, **policy enforcement to the BIG-IP**, and **IPFIX flow visibility** of load-balanced traffic.

[![Cisco Secure Workload](https://img.shields.io/badge/Cisco-Secure%20Workload-00205B?logo=cisco&logoColor=white)](https://www.cisco.com/go/secureworkload)
[![F5 BIG-IP](https://img.shields.io/badge/F5-BIG--IP-E4002B?logo=f5&logoColor=white)](https://www.f5.com/products/big-ip-services)
[![Integration](https://img.shields.io/badge/Integration-Orchestrator%20%2B%20IPFIX-007BC7)](https://www.cisco.com/c/m/en_us/products/security/secure-workload-compatibility-matrix.html)

> **⚠ Disclaimer:** This is a **community reference guide** prepared by Cisco Solutions Engineering — not an official Cisco product document. Always refer to the [official Cisco Secure Workload documentation](https://www.cisco.com/c/en/us/support/security/tetration/series.html) and the [Compatibility Matrix](https://www.cisco.com/c/m/en_us/products/security/secure-workload-compatibility-matrix.html) for authoritative, up-to-date guidance.

---

## The problem this solves

**A load balancer breaks one conversation into two, and a segmentation product that only sees one half cannot write a policy about it.**

When `orders-app` calls a service through the BIG-IP, the BIG-IP re-sources the connection. The backend never sees the real client — it sees the SNAT address. Two unrelated-looking flows:

```
flow 1:   192.0.2.50      →  198.51.100.10:443     the client reaching the VIP
flow 2:   198.51.100.200  →  203.0.113.21:8443     the SNAT address reaching the pool member
```

Nothing connects them. From the backend's point of view **every** client in the estate is one address — so a policy written against it allows **everything** sharing that SNAT pool. That is worse than imprecise.

![One request through the BIG-IP and how the real client is recovered](diagrams/02-worked-example.svg)

*The **F5 connector** ingests IPFIX for both halves and stitches them, recovering the client-to-backend path. The **External Orchestrator** separately turns `198.51.100.10:443` into a nameable `service_name = payments-vip`, so you can write policy about it.*

> **Scope boundary, stated up front:** this is **L3/L4**. You get the real client, the real backend, ports and protocol. You do **not** get L7 — if one VIP on port 443 fronts several applications separated by **URL or URI**, nothing here distinguishes them.

[**→ Full explanation with the worked example**](CSW-F5-Integration-Guide.md#05-how-it-actually-works--a-worked-example)

---

## What This Covers

| Area | Detail |
|---|---|
| **Path 1 — External Orchestrator** (`type: f5`) | Import F5 **virtual servers** as *service inventory* labels; optionally **enforce policy** to the BIG-IP |
| **Path 2 — Flow telemetry** | BIG-IP exports **IPFIX** to the **F5 connector** on a CSW ingest appliance, which **stitches the NATed flows** |
| **Transport** | HTTPS iControl REST API (orchestrator) · IPFIX/UDP (telemetry) |
| **Enforcement** | CSW translates policies → F5 security rules (requires **write** creds) |
| **Connectivity** | Direct (on-prem) or via **Secure Connector** tunnel (SaaS / non-routable) |
| **Result** | `orchestrator_*` + `service_name` labels, F5 rule deployment, LB flow visibility |
| **Verified against** | CSW 4.x on-prem and SaaS; F5 BIG-IP v12.1.1+ |

![Choosing between the External Orchestrator and the F5 connector](diagrams/01-which-path.svg)

*The two paths are independent and fail independently. A sensible order is **connector first, orchestrator second** — visibility before enforcement.*

---

## Quick Start

### Prerequisites
- F5 BIG-IP with reachable **iControl REST API** (HTTPS/443)
- F5 service account — **read-only** for labels, **read+write** for enforcement
- CSW 4.x with Site Admin / Root Scope Owner rights
- (IPFIX) a CSW **Ingest** appliance with an **F5 connector** — not the generic NetFlow/IPFIX connector; only the F5 connector does NAT stitching
- (SaaS only) a healthy **Secure Connector** tunnel
- (IPFIX) on the F5 side, a module that can **export IPFIX** — normally **AFM**. Confirm what is licensed before planning
- Firewall: HTTPS (TCP/443) CSW → F5; IPFIX (UDP) F5 **self-IP** → CSW ingest collector

### Steps (summary)

**Path 1 — Labels + enforcement (External Orchestrator):**
1. `Manage → External Orchestrators → Create New Configuration`
2. **Type = F5 BIG-IP**; enter Name, Username, Password
3. **Hosts List** → F5 mgmt IP, port `443` (use the **standby** node for HA)
4. Set **Route Domain** (default `0`); leave **Enable Enforcement** off at first
5. **Create** (first snapshot ~60s). Check **Secure Connector Tunnel** for SaaS
6. Later, turn on **Enable Enforcement** + enforce a workspace policy (needs write creds)

**Path 2 — Flow visibility (IPFIX):**
1. Deploy/confirm a CSW **Ingest** appliance + **F5 connector** (note IP:UDP port). Optionally add an **LDAP config** to annotate client IPs with user info
2. On F5: create Pool → IPFIX **Log Destination** → **Log Publisher** → attach to virtual servers (normally via an **AFM network-firewall logging profile**). The attachment is the step that actually starts data flowing
3. Verify in `Investigate → Flows`

**Verify labels:**
1. `Investigate → Inventory Search`
2. Run `orchestrator_system/orch_type = f5`
3. Use `orchestrator_*` / `service_name` labels to build **scopes** and **policies**

See the [full step-by-step guide](CSW-F5-Integration-Guide.md) or [open the HTML version](CSW-F5-Integration-Guide.html) for detailed instructions.

---

## Video Walkthroughs

> **Legend:** 🎬 video · 📘 guide · 📄 doc

Curated from the [CSW-User-Education](https://github.com/chandrapati/CSW-User-Education) video library:

| Video | What it shows |
|---|---|
| [🎬 F5 BIG-IP IPFIX Configuration](https://www.youtube.com/watch?v=aJZEcZtUXDg) | Export IPFIX flow telemetry from BIG-IP into Secure Workload |
| [🎬 F5 BIG-IP & Cisco Tetration: APM Visibility](https://www.youtube.com/watch?v=dqbWhvFNsso&t=90s) | F5 APM (Access Policy Manager) application/user visibility |
| [🎬 Cisco Tetration & F5 BIG-IP AFM](https://www.youtube.com/watch?v=HcF3yQHmeXc) | F5 AFM (Advanced Firewall Manager) flow context |

> *Tetration* is the former name for Cisco Secure Workload — the concepts apply directly.

---

## Architecture Diagram

![CSW and F5 BIG-IP Integration Architecture](csw-f5-architecture.png)

*Two data paths travelling in **opposite directions**. CSW **pulls** over HTTPS REST — the External Orchestrator imports virtual servers as service labels and pushes enforcement rules back. The BIG-IP **pushes** IPFIX to the F5 connector, which stitches the NATed halves.*

**The direction of travel is what people get wrong.** Flows arrive because the BIG-IP sends them; inventory and enforcement happen because CSW reaches out. [`SKILL.md`](SKILL.md) has the mechanism in detail.

---

## Files in This Repo

| File | Description |
|---|---|
| [`README.md`](README.md) | This file — quick start and overview |
| [`SKILL.md`](SKILL.md) | How the integration actually works — IPFIX collection, NAT stitching, orchestrator snapshot and enforcement, version coverage 3.7–4.0 |
| [`CSW-F5-Integration-Guide.md`](CSW-F5-Integration-Guide.md) | Full step-by-step guide (Markdown source) |
| [`CSW-F5-Integration-Guide.html`](CSW-F5-Integration-Guide.html) | Styled HTML — open in browser (embedded YouTube player) |
| [`csw-f5-architecture.png`](csw-f5-architecture.png) | Architecture diagram |
| [`diagrams/`](diagrams) | The guide's six diagrams. `.mmd` files are the editable source; `.svg` files are what the guide references. Regenerate with [`diagrams/render.sh`](diagrams/render.sh) |
| [`build.sh`](build.sh) | Regenerate HTML/PDF from Markdown (requires pandoc + Chrome) |
| [`docs/CUSTOMER-HANDOFF.md`](docs/CUSTOMER-HANDOFF.md) | Checklist to hand to the customer's F5 / network team |

---

## Imported Labels — Quick Reference

| Key | Value |
|---|---|
| `orchestrator_system/orch_type` | `f5` |
| `orchestrator_system/workload_type` | `service` |
| `orchestrator_system/service_name` | *(virtual server name)* |
| `orchestrator_system/namespace` | *(partition)* |
| `orchestrator_annotation/snat_address` | *(SNAT address)* |

> **Important:** Only **single-address** VIPs are imported (not subnet VIPs). Enabling policy enforcement makes **CSW the owner** of the virtual server's security rules; disabling it **removes** those rules from the BIG-IP.

---

## Step-by-Step Guides

> **Legend:** 🎬 video · 📘 guide · 📄 doc

Hands-on integration and deployment guides — follow these top to bottom to build out a deployment:

| Guide | Description | Best for |
|-------|-------------|---------|
| [📘 Agent Installation](https://github.com/chandrapati/CSW-Agent-Installation-Guide) | Deploy CSW agents on Linux / Windows / cloud | Day-1 sensor deployment |
| [📘 Policy Lifecycle](https://github.com/chandrapati/CSW-Policy-Lifecycle) | Policy discovery → enforcement workflow | Policy management |
| [📘 ISE / pxGrid](https://github.com/chandrapati/csw-ise-integration) | ISE/pxGrid: user-identity–aware microsegmentation | Identity & Zero Trust |
| [📘 AnyConnect NVM](https://github.com/chandrapati/csw-anyconnect-nvm) | Endpoint process flows + user identity via NVM | Endpoint telemetry |
| [📘 ServiceNow CMDB](https://github.com/chandrapati/csw-servicenow-integration) | ServiceNow CMDB label enrichment for workload scopes | CMDB-driven policy |
| [📘 Infoblox](https://github.com/chandrapati/csw-infoblox-integration) | Infoblox IPAM/DNS extensible-attribute label enrichment | IPAM/DNS-driven policy |
| [📘 F5 BIG-IP](https://github.com/chandrapati/csw-f5-integration) | F5 virtual-server labels, policy enforcement, IPFIX flow visibility | Load balancer segmentation |
| [📘 NetScaler ADC](https://github.com/chandrapati/csw-netscaler-integration) | NetScaler LB virtual-server labels, ACL enforcement + AppFlow/IPFIX flow visibility | Load balancer segmentation |
| [📘 AWS Connector](https://github.com/chandrapati/csw-aws-connector) | EC2 tag ingestion + VPC flow logs + Security Group enforcement | AWS workloads |
| [📘 Azure Connector](https://github.com/chandrapati/csw-azure-connector) | Azure VM tag ingestion + VNet flow logs + NSG enforcement | Azure workloads |
| [📘 GCP Connector](https://github.com/chandrapati/csw-gcp-connector) | GCE label ingestion + VPC flow logs + firewall enforcement | GCP workloads |
| [📘 NetFlow](https://github.com/chandrapati/csw-netflow-integration) | NetFlow v9/IPFIX agentless flow ingestion from switches | Network fabric visibility |
| [📘 ERSPAN](https://github.com/chandrapati/csw-erspan-integration) | Agentless packet mirroring for legacy / OT / IoT devices | Deep agentless visibility |
| [📘 Secure Firewall](https://github.com/chandrapati/CSW-Secure-Firewall-Integration-Guide) | NSEL flow ingestion from Cisco Secure Firewall (FTD/ASA) | Firewall flow visibility |
| [📘 Siwapp Lab App (vSphere)](https://github.com/chandrapati/siwapp-app-vsphere) | Terraform multi-tier demo app (PostgreSQL + HAProxy + Elixir) on any vCenter lab — a realistic east-west segmentation target | Lab / POV demo workloads |
| [📘 Splunk Integration](https://github.com/chandrapati/csw-splunk-integration) | CSW syslog alerts → Splunk SIEM | SecOps / SIEM teams |

## Resources

> **Legend:** 🎬 video · 📘 guide · 📄 doc

Learning paths, reference material, and day-2 tooling:

| Resource | Description | Best for |
|----------|-------------|---------|
| [📘 User Education](https://github.com/chandrapati/CSW-User-Education) | Onboarding guides, concept explainers, and curated video library | New CSW users |
| [📘 Compliance Mapping](https://github.com/chandrapati/CSW-Compliance-Mapping) | Map CSW controls to NIST, PCI-DSS, HIPAA, CIS | Compliance & audit |
| [📘 Tenant Insights](https://github.com/chandrapati/CSW-Tenant-Insights) | Tenant-level reporting and analytics | Visibility metrics |
| [📘 Operations Toolkit](https://github.com/chandrapati/CSW-Operations-Toolkit) | Day-2 ops scripts: health checks, reporting, policy analysis | Ongoing operations |
| [📄 Supported OS & Compatibility Matrix](https://www.cisco.com/c/m/en_us/products/security/secure-workload-compatibility-matrix.html) | Cisco's authoritative list of supported agent operating systems, external systems, and connector requirements | Platform planning & prerequisites |

> **Suggested customer journey:**
> User Education → Agent Installation → Policy Lifecycle → ISE/pxGrid → ServiceNow CMDB → Infoblox → F5 BIG-IP → NetScaler ADC → Splunk Integration → Compliance Mapping → Operations Toolkit
