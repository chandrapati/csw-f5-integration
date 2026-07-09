# F5 BIG-IP integration — customer handoff checklist

**Purpose:** Give this page to your customer's **F5 / load-balancer / network** team when scoping a Cisco Secure Workload (CSW) integration with F5 BIG-IP.

**Integration summary:** CSW connects to the BIG-IP **iControl REST API (HTTPS)** to import **virtual servers** as labeled service inventory and — optionally — to **deploy security policy rules** to the load balancer. Separately, the BIG-IP can export **IPFIX** flow telemetry to a CSW ingest appliance for load-balanced traffic visibility.

---

## Two integration paths — pick what applies

| Path | What CSW does | Credential needed | Data direction |
|---|---|---|---|
| **A. Labels only** | Import virtual servers → `service_name` / `orchestrator_*` labels | **Read-only** REST | CSW → F5 (poll) |
| **B. Labels + enforcement** | Path A **plus** deploy security rules to VIPs | **Read + write** REST | CSW ⇄ F5 |
| **C. Flow visibility (IPFIX)** | Ingest BIG-IP flow records | none (F5 exports) | F5 → CSW ingest |

> Paths can be combined. Enforcement (B) means **CSW becomes the owner** of the virtual server's security rules — disabling it removes those rules.

---

## What we need from the F5 team

### 1. Service account

| Item | Detail |
|------|--------|
| **Account name** | e.g. `svc-csw` (dedicated service account) |
| **BIG-IP version** | v12.1.1+ (current supported TMOS) with iControl REST enabled |
| **Role (labels only)** | Read-only (e.g. Operator/Guest) scoped to relevant partitions |
| **Role (enforcement)** | Write access to security/AFM objects on relevant partitions |
| **Partition access** | Only the partitions whose virtual servers should appear in CSW |

### 2. Connectivity

| Direction | Source | Destination | Port |
|-----------|--------|-------------|------|
| Outbound | CSW cluster / SaaS Secure Connector VM | F5 mgmt / REST endpoint | **443/TCP** (HTTPS) |
| Outbound (IPFIX) | F5 self-IP | CSW ingest collector | **UDP** (e.g. 4739) |
| Outbound (SaaS) | Secure Connector VM | CSW SaaS FQDN | **443/TCP** |

**No inbound rules** to the Secure Connector VM are required.

### 3. Endpoint(s)

Provide the **management IP/FQDN** of the BIG-IP for the CSW **Hosts List**:

```
Example:
  f5-dc1-standby.corp.example.com:443   (use the STANDBY node in an HA pair)
```

- One external orchestrator in CSW = **one BIG-IP** (or HA pair).
- A second appliance requires a **second** orchestrator.

### 4. Scoping decisions

- [ ] **Route Domain** (default `0`) — which partitions/virtual servers to import
- [ ] Which **virtual servers** matter for segmentation (single-address VIPs only)
- [ ] Enable **policy enforcement**? (needs write creds; CSW owns the rules)
- [ ] Enable **IPFIX** export? (needs ingest appliance + log publisher on F5)

### 5. HA considerations

- Enable **config-sync** on the HA pair so CSW always sees the current virtual server list.
- If using **Auto-Map** (not a SNAT pool), configure the **floating Self-IP** on the primary.

---

## What CSW will produce

| F5 source | CSW label | Example |
|-----------|-----------|---------|
| Virtual server | `orchestrator_system/service_name` | `web-vip` |
| Orchestrator type | `orchestrator_system/orch_type` | `f5` |
| Workload type | `orchestrator_system/workload_type` | `service` |
| SNAT address | `orchestrator_annotation/snat_address` | *(address)* |

Use these labels in **inventory search**, **scopes**, and **policy** (e.g. segment everything behind `service_name = web-vip`).

---

## Security & compliance talking points

- **Least privilege** — read-only account unless enforcement is required.
- **Enforcement is reversible** — disabling it removes CSW rules from the BIG-IP.
- **Drift control** — with enforcement on, manage VIP security rules **in CSW only**; CSW reverts manual changes.
- **Dedicated service account** — auditable, rotatable credentials; stored encrypted in CSW.
- **Outbound-only** from Secure Connector (SaaS designs).

---

## Validation (joint test)

| # | Test | Owner | Pass |
|---|------|-------|------|
| 1 | REST login with service account from CSW / Secure Connector | F5 + CSW team | ☐ |
| 2 | Orchestrator **Connection Status: Success** | CSW admin | ☐ |
| 3 | Virtual server visible in inventory (`orchestrator_system/orch_type = f5`) | CSW admin | ☐ |
| 4 | (If enforcement) Policy deployed to VIP; enforcement status = success | Security architect | ☐ |
| 5 | (If IPFIX) Load-balanced flows visible in `Investigate → Flows` | Network + CSW team | ☐ |

---

## References

- Full guide: [CSW-F5-Integration-Guide.md](../CSW-F5-Integration-Guide.md)
- Cisco official: [External Orchestrators — F5 BIG-IP](https://www.cisco.com/c/en/us/td/docs/security/workload_security/secure_workload/user-guide/4_0/cisco-secure-workload-user-guide-on-prem-v40/configure-external-orchestrators-in-secure-workload.html)
- Compatibility Matrix: [Secure Workload](https://www.cisco.com/c/m/en_us/products/security/secure-workload-compatibility-matrix.html)

---

*Generic template — no customer-specific names. Customize contacts and endpoints locally before sending.*
