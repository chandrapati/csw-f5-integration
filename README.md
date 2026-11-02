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

When `orders-app` calls a service through the BIG-IP, the BIG-IP re-sources the connection. The backend never sees the real client — it sees the SNAT address. From the backend's point of view **every** client sharing that pool is one address, so a policy written against it allows all of them.

![One request through the BIG-IP, and what the F5 connector recovers](diagrams/f5-one-request.png)

> **Scope boundary, stated up front:** this is **L3/L4**. You get the real client, the real backend, ports and protocol. You do **not** get L7 — if one VIP on port 443 fronts several applications separated by **URL or URI**, nothing here distinguishes them.

[**→ Full explanation with the worked example**](CSW-F5-Integration-Guide.md#05-how-it-actually-works--a-worked-example)

---

## Two paths

![Two paths: the F5 connector and the External Orchestrator](diagrams/f5-two-paths.png)

Verified against CSW 4.x, on-prem and SaaS, and F5 BIG-IP v12.1.1+.

## Enforcement

![Three gates before a rule lands on the BIG-IP](diagrams/f5-three-gates.png)

The lab checklist — catch-all deny, both directions, and what removal does to the VIP — is [§7.3](CSW-F5-Integration-Guide.md#73-prove-this-in-a-lab-before-production).

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

*Two data paths, opposite directions. CSW **pulls** inventory and pushes rules over iControl REST. The BIG-IP **pushes** IPFIX. The lower arrow on this picture is that IPFIX export, and it belongs on the **F5 connector** (UDP 4739). The generic NetFlow connector is a different listener and does not correlate NAT.*

**The direction of travel is what people get wrong.** Flows arrive because the BIG-IP sends them. Inventory and enforcement happen because CSW reaches out. CSW does not read the BIG-IP session table. [`SKILL.md`](SKILL.md) is the mechanism, including that precision.

---

## Files in This Repo

| File | Description |
|---|---|
| [`README.md`](README.md) | This file — quick start and overview |
| [`SKILL.md`](SKILL.md) | How the integration actually works — IPFIX collection, NAT stitching, orchestrator snapshot and enforcement, version coverage 3.7–4.0 |
| [`CSW-F5-Integration-Guide.md`](CSW-F5-Integration-Guide.md) | Full step-by-step guide (Markdown source) |
| [`CSW-F5-Integration-Guide.html`](CSW-F5-Integration-Guide.html) | Styled HTML — open in browser (embedded YouTube player) |
| [`csw-f5-architecture.png`](csw-f5-architecture.png) | Architecture diagram |
| [`diagrams/`](diagrams) | Readable PNGs for the README (`f5-one-request.png`, `f5-two-paths.png`, `f5-three-gates.png`, `f5-logging-chain.png`). HTML sources are in `diagrams/branded/`. The `.mmd` / `.svg` set is the earlier flowchart source |
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

Only **single-address** VIPs are imported. A subnet VIP stays out of inventory.

---

## Related, for this integration

| | |
|---|---|
| [Full guide](CSW-F5-Integration-Guide.md) · [HTML](CSW-F5-Integration-Guide.html) | Every step, the AFM chain, and the lab checklist |
| [How it works](SKILL.md) | IPFIX collection, correlation, the orchestrator snapshot |
| [Handoff checklist](docs/CUSTOMER-HANDOFF.md) | What to send the F5 and network team |
| [Ingest appliance](https://github.com/chandrapati/csw-ingest-connector) | Where the F5 connector runs |
| [NetFlow connector](https://github.com/chandrapati/csw-netflow-integration) | Routers and switches. Not the listener for F5 NAT |
| [Secure Connector](https://github.com/chandrapati/csw-secure-connector) | The tunnel when CSW cannot reach the BIG-IP |
| [Policy lifecycle](https://github.com/chandrapati/CSW-Policy-Lifecycle) | What "the workspace is enforced" means |
| [Compatibility Matrix](https://www.cisco.com/c/m/en_us/products/security/secure-workload-compatibility-matrix.html) | Supported BIG-IP versions and connector requirements |
