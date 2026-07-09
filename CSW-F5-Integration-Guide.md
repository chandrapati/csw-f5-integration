# Cisco Secure Workload → F5 BIG-IP Integration Guide

A step-by-step, **beginner-friendly** guide to integrating **F5 BIG-IP** with **Cisco Secure Workload (CSW)**. It covers the two ways CSW and F5 work together:

1. **External Orchestrator (`type: f5`)** — CSW imports F5 **virtual servers** as *service inventory* (labels), and can **push enforcement policy** back to the BIG-IP as security rules.
2. **Flow telemetry (IPFIX)** — the BIG-IP streams **IPFIX/NetFlow** to a CSW **ingest appliance** so CSW can *see* load-balanced and SNAT'd traffic.

> **⚠ Disclaimer:** This is a **community reference guide** prepared by Cisco Solutions Engineering — not an official Cisco product document. Always refer to the [official Cisco Secure Workload documentation](https://www.cisco.com/c/en/us/support/security/tetration/series.html) and the [Compatibility Matrix](https://www.cisco.com/c/m/en_us/products/security/secure-workload-compatibility-matrix.html) for authoritative, up-to-date guidance.

---

## 0. New to CSW or F5? Read this first (2 minutes)

If you've never touched either product, here's the mental model:

- **Cisco Secure Workload (CSW)** discovers how applications talk to each other and builds **least-privilege micro-segmentation** policy. It groups workloads using **labels** → **scopes** → **policies**.
- **F5 BIG-IP** is a **load balancer / ADC**. Clients connect to a **Virtual Server** (a **VIP** = virtual IP + port); the BIG-IP forwards to a **pool** of backend servers. It often rewrites the source IP using **SNAT** (Secure NAT) or **Auto-Map**.

**Why integrate them?** Two problems F5 creates for segmentation, and how CSW solves them:

| Problem F5 introduces | What the integration gives you |
|---|---|
| The load balancer is a "black box" — CSW doesn't know which VIPs map to which services | **External Orchestrator** imports each virtual server as a labeled **service inventory** item (`service_name`, `orchestrator_*`) |
| SNAT hides the real client IP, so backend flows all look like they come from the F5 | **IPFIX telemetry** from the BIG-IP lets CSW **stitch** the client → VIP → pool-member path for accurate visibility |
| You want the load balancer to enforce your segmentation policy | **Policy enforcement** translates CSW policies into F5 security rules and deploys them via the REST API |

**Which path do you need?**

- Want **labels + policy enforcement at the F5**? → Do the **External Orchestrator** (§4–§7).
- Want **flow visibility** of load-balanced traffic? → Do **IPFIX telemetry** (§8).
- Most mature deployments do **both**.

---

## 1. Architecture

![CSW and F5 BIG-IP Integration Architecture](csw-f5-architecture.png)

*Two independent data paths. **Top:** the External Orchestrator uses the F5 REST API (HTTPS) to import virtual servers as service-inventory labels and to push enforcement rules back to the BIG-IP. **Bottom:** the BIG-IP exports IPFIX/NetFlow to a CSW ingest appliance for load-balanced flow visibility.*

| Path | Direction | Transport | Purpose |
|---|---|---|---|
| **External Orchestrator** | CSW ⇄ F5 | HTTPS REST API (iControl) | Import virtual servers → labels; push policy rules to F5 |
| **Flow telemetry** | F5 → CSW ingest appliance | IPFIX / NetFlow (UDP) | See client → VIP → pool-member flows through the LB |

---

## 2. What you get

**Service inventory & labels** (from the orchestrator): each F5 virtual server becomes a searchable inventory item with system labels:

| Key | Value |
|---|---|
| `orchestrator_system/orch_type` | `f5` |
| `orchestrator_system/workload_type` | `service` |
| `orchestrator_system/service_name` | *(virtual server name)* |
| `orchestrator_system/namespace` | *(partition)* |
| `orchestrator_system/cluster_id` / `cluster_name` | *(orchestrator identity)* |
| `orchestrator_annotation/snat_address` | *(SNAT address of the virtual server)* |

Use these in **inventory search**, **scopes**, and **policies** — for example, segment everything behind a given VIP.

**Policy enforcement** (optional): CSW translates logical policies whose **provider** matches an F5 virtual server into **F5 security policy rules** and deploys them to the BIG-IP. CSW becomes the source of truth for those rules.

**Flow visibility** (from IPFIX): CSW ingests BIG-IP flow records so the load-balanced path is visible in ADM (Application Dependency Mapping) and the flow explorer.

---

## 3. Prerequisites

### F5 BIG-IP side
- BIG-IP with a reachable **iControl REST API** endpoint (HTTPS/443). Documented baseline: **v12.1.1+** (use a current, supported TMOS release).
- A BIG-IP account for CSW:
  - **Read-only** is enough for **label import only**.
  - **Read + write** is required if you enable **policy enforcement** (CSW writes security rules).
- Know your **partitions** and **route domain** (default `0`) — these decide which virtual servers get imported.
- For IPFIX (§8): the **AVR / IPFIX** capability and the ability to define an IPFIX log destination/publisher.

### Cisco Secure Workload side
- CSW **4.x** (on-prem or SaaS). Orchestrators live under **Manage → External Orchestrators**.
- For IPFIX: a deployed **Ingest (NetFlow/IPFIX) virtual appliance** with a **NetFlow/IPFIX connector** (8 vCPU / 8 GB / 250 GB per the Compatibility Matrix).
- A user with **Site Admin / Root Scope Owner** rights, or an API key with the `external_integration` capability for the API path (§9).
- For **SaaS / non-routable F5**: a healthy **Secure Connector** tunnel (§4.1).

### Network / firewall
- **HTTPS (TCP/443)** from the CSW source (cluster / SaaS egress / Secure Connector VM) **→ F5 management/REST endpoint**.
- **IPFIX (UDP, your chosen port, e.g. 4739)** from the **F5 self-IP** **→ CSW ingest appliance collector IP**.

### 3.1 Create a least-privilege F5 service account (recommended)

1. On the BIG-IP: **System → Users → User List → Create**.
2. Create a dedicated user (e.g. `svc-csw`).
3. Role:
   - **Label import only:** assign a **read-only** role (e.g. *Guest* / *Operator* scoped to the relevant partitions).
   - **Policy enforcement:** assign a role with **write** to security/AFM objects on the relevant partitions (e.g. *Administrator* or a scoped custom role) — CSW must create/replace rules.
4. Give it access to the partitions in scope.

> **Security:** Store this credential in your secrets manager. Never commit it to source control. CSW stores it encrypted; you must **re-enter the password every time you edit** the orchestrator.

---

## 4. Configure the F5 External Orchestrator (UI)

**Path:** `Manage → External Orchestrators → Create New Configuration`

### Step 1 — Basic tab

Select **Type = F5 BIG-IP**, then fill the common fields:

| Field | Required | Value / guidance |
|---|---|---|
| **Name** | ✅ | Unique per tenant, e.g. `f5-bigip-dc1` |
| **Type** | ✅ | `F5 BIG-IP` (not editable after creation) |
| **Description** | ❌ | e.g. "DC1 BIG-IP — virtual-server labels + enforcement" |
| **Username** | ✅ | The F5 service account (e.g. `svc-csw`) |
| **Password** | ✅ | The service account password (re-enter on every edit) |
| **Full Snapshot Interval (s)** | ✅ | How often to re-poll F5. Default works for most; first snapshot may take ~60s |
| **Delta Interval (s)** | ❌ | Incremental poll (default 60s). First full snapshot completes in ~60s |
| **Accept Self-signed Cert** | ❌ | Check only if the BIG-IP presents a self-signed cert (lab). Prefer a CA-signed cert in production |
| **Secure Connector Tunnel** | ❌ | Check for **SaaS / non-routable** F5 (see §4.1) |

### Step 2 — Hosts List tab

Add the F5 REST API endpoint:

| Column | Value |
|---|---|
| **Host Name / IP** | F5 management IP or FQDN |
| **Port** | `443` |

- For an **HA pair**, enter the **standby node** so the orchestrator **fails over** to the currently-active node.
- A **different BIG-IP** requires a **separate orchestrator**.

### Step 3 — F5-specific fields

| Field | Default | What it does |
|---|---|---|
| **Route Domain** | `0` | Only virtual servers in partitions assigned to this route domain are imported |
| **Enable Enforcement** | Off | If checked, CSW may deploy security rules to this BIG-IP (**requires write credentials**). Start **off** — turn on later (§7) |

### Step 4 — (Optional) Alerts tab
- Check **Alert enabled**; set **Severity** and **Disconnect Duration (m)**.
- Also enable **Connector Alerts** under **Manage → Workloads → Alert Configs**.

### Step 5 — Create
Click **Create**. Allow ~1 minute for the connection status to update. The first full snapshot of virtual servers typically completes in ~60 seconds.

### 4.1 (SaaS only) Secure Connector tunnel

Skip if CSW is **on-prem** and can reach the F5 directly. For **SaaS/TaaS** or a non-routable F5:

1. In CSW: **Manage → Secure Connector** → download/register the client on a Linux VM that **can** reach the F5.
2. Size per the [Compatibility Matrix](https://www.cisco.com/c/m/en_us/products/security/secure-workload-compatibility-matrix.html) (2 vCPU / 4 GB RAM; RHEL/Rocky/Alma).
3. Confirm the Secure Connector is **Active/Connected**, then check **Secure Connector Tunnel** on the orchestrator.

---

## 5. Verify label import

### 5.1 Connection status
Open the orchestrator row — the status should be healthy. If it isn't, read the error (bad credentials, unreachable host, or cert error).

### 5.2 Find your F5 services in inventory
**Path:** `Investigate → Inventory Search`

```
orchestrator_system/orch_type = f5
```

```
orchestrator_system/workload_type = service and orchestrator_system/service_name = my-vip
```

Each virtual server appears as a **service inventory** item characterized by its **VIP + protocol + port**, with `service_name` and `orchestrator_*` labels.

> **Caveat:** Only a VIP given as a **single address** is supported — a VIP defined as a subnet is **not** imported.

---

## 6. Use F5 labels in scopes & policies

1. **Manage → Scopes and Inventory** → create/edit a scope using an F5 label query, e.g. `orchestrator_system/service_name = web-vip`.
2. Build workspace policies where the **provider** is the F5 service.
3. Discover and analyze policy as usual — the F5 service behaves like any other CSW inventory.

---

## 7. (Optional) Enable policy enforcement to F5

> Only do this once you understand the impact: **CSW becomes the owner** of the virtual server's security rules.

**How it works:**
- CSW translates logical policies whose **provider** matches a labeled F5 virtual server into **F5 security policy rules** and deploys them via the REST API.
- Any existing security-policy assignment on that virtual server is **replaced** by a CSW-managed assignment. (Existing policies aren't deleted from the F5 policy list, but the *assignment* to the VIP is swapped.)
- CSW **detects drift** — manual rule changes on the VIP are reverted. **Manage those rules in CSW only.**

**Steps:**
1. Edit the orchestrator → check **Enable Enforcement** (credentials must have **write** access). This alone deploys nothing yet.
2. In the **workspace** that contains at least one policy whose provider is the F5 service, run **Enforce**.
3. Verify on the BIG-IP that the virtual server now has CSW-generated allow/drop rules. Use the OpenAPI *policy enforcement status for external orchestrator* to confirm success/failure.

> **Stopping enforcement:** Disabling enforcement on the orchestrator (or deleting it) **immediately removes all CSW rules** from the BIG-IP, leaving the virtual server's security policy **empty**. Plan for this.

### 7.1 (Advanced) F5 Ingress Controller (Kubernetes)
When pods are exposed externally via a Kubernetes **ingress** object, CSW can enforce at **both** the F5 and the backend pods:
1. Create the **F5 BIG-IP** orchestrator (§4) **and** a **Kubernetes/OpenShift** orchestrator.
2. Create the ingress object and deploy the **F5 ingress controller** pod.
3. Create a backend service (e.g. nginx) and a policy between the external consumer and that service; **Enforce**.
4. Result: on the F5, source = consumer → destination = ingress VIP; on the pods, source = SNIP (SNAT pool) or F5 IP (Auto-Map) → destination = backend pod IP.

---

## 8. (Optional) Send F5 flow telemetry to CSW via IPFIX

This path gives CSW **visibility** into traffic passing through the BIG-IP — essential because SNAT/Auto-Map otherwise hides the client identity from backend workloads.

### 8.1 CSW side — stand up an IPFIX collector
1. Deploy a CSW **Ingest (NetFlow/IPFIX) virtual appliance** if you don't have one.
2. Add a **NetFlow/IPFIX connector**; note its **listening IP and UDP port** (e.g. `4739`).

### 8.2 F5 side — export IPFIX
On the BIG-IP (names vary slightly by TMOS version):
1. **Create a Pool** pointing at the CSW ingest collector IP:UDP port (the IPFIX destination).
2. **Create an IPFIX Log Destination** (Protocol = IPFIX, Transport = UDP) that uses that pool.
3. **Create a Log Publisher** that references the IPFIX log destination.
4. Attach the publisher so BIG-IP exports flow records (via AFM/AVR logging profiles or an iRule, depending on your module set) for the virtual servers you care about.
5. Ensure firewall allows the F5 **self-IP → CSW ingest collector** on the chosen UDP port.

### 8.3 Verify flows
In CSW, open **Investigate → Flows** (flow explorer) and filter for traffic to your VIPs. You should see load-balanced flows, letting ADM stitch the client → VIP → pool-member relationship.

> The F5 video walkthroughs (§10) demonstrate IPFIX export, plus APM and AFM context, on the BIG-IP.

---

## 9. (Alternative) Configure the orchestrator via OpenAPI

For automation. The API key needs the `external_integration` capability.

`POST /openapi/v1/orchestrator/{rootScopeName}`

```python
import os, json

req_payload = {
    "name": "f5-bigip-dc1",
    "type": "f5",
    "description": "DC1 BIG-IP - virtual-server labels + enforcement",
    "hosts_list": [
        {"host_name": "f5-dc1-standby.corp.example.com", "port_number": 443}
    ],
    "username": "svc-csw",
    # Pull the secret from env / a secrets manager - never hardcode credentials
    "password": os.environ["F5_CSW_PASSWORD"],
    "route_domain": 0,
    "enable_enforcement": False,   # set True only when ready to push rules (needs write creds)
    "full_snapshot_interval": 3600,
    "delta_interval": 60,
    "insecure": False,             # True only to accept self-signed certs (lab)
    "use_secureconnector_tunnel": False   # True for SaaS / non-routable F5
}

resp = restclient.post("/orchestrator/Default", json_body=json.dumps(req_payload))
print(resp.status_code, resp.text)
```

> **Security note (applied per repo policy):** the sample reads the password from an environment variable (`os.environ`) rather than embedding it. Never commit credentials or API keys; store them in a secrets manager and inject at runtime.

Useful endpoints: `GET/POST/PUT/DELETE /openapi/v1/orchestrator/{scope}[/{id}]`, and *policy enforcement status for external orchestrators* to confirm rule deployment.

---

## 10. Video walkthroughs

Curated from the [CSW-User-Education](https://github.com/chandrapati/CSW-User-Education) video library — F5 + Secure Workload / Tetration demos:

| # | Video | What it shows |
|---|---|---|
| 1 | [**F5 BIG-IP IPFIX Configuration**](https://www.youtube.com/watch?v=aJZEcZtUXDg) | Configure the BIG-IP to export **IPFIX** flow telemetry into Secure Workload (the §8 path) — *F5 DevCentral* |
| 2 | [**F5 BIG-IP & Cisco Tetration: APM Visibility**](https://www.youtube.com/watch?v=dqbWhvFNsso&t=90s) | Using **F5 APM** (Access Policy Manager) data for application/user visibility |
| 3 | [**Cisco Tetration & F5 BIG-IP AFM**](https://www.youtube.com/watch?v=HcF3yQHmeXc) | **F5 AFM** (Advanced Firewall Manager) flow context into Secure Workload |

> *Tetration* is the former product name for Cisco Secure Workload — the concepts in these demos apply directly.

---

## 11. Caveats & troubleshooting

| Symptom / topic | Guidance |
|---|---|
| **Connectivity / auth failure** | Allow HTTPS from the CSW source (cluster / SaaS egress / Secure Connector VM) → F5. Verify credentials; enforcement needs **write** access. |
| **Certificate error** | BIG-IP presents a self-signed cert → install a CA-signed cert (preferred) or check **Accept Self-signed Cert** / set `insecure: True` (lab only). |
| **Security rules not found after enforcement** | Ensure the virtual server is **enabled/available**; only then are rules applied. |
| **VIP not imported** | Only **single-address** VIPs are supported (not subnet VIPs). Confirm the partition is in the configured **route domain**. |
| **HA failover misses virtual servers** | Enable **config-sync** on the HA pair; if using **Auto-Map** (not SNAT pool), configure the **floating Self-IP** on the primary. |
| **Enforcement removed unexpectedly** | Disabling enforcement or deleting the orchestrator **clears all CSW rules** from the VIP — expected behavior. |
| **No IPFIX flows in CSW** | Check the F5 log publisher/destination points at the ingest collector IP:UDP port and that the firewall permits UDP from the F5 self-IP. |

---

## 12. References

- [CSW — External Orchestrators, incl. F5 BIG-IP (On-Prem 4.0)](https://www.cisco.com/c/en/us/td/docs/security/workload_security/secure_workload/user-guide/4_0/cisco-secure-workload-user-guide-on-prem-v40/configure-external-orchestrators-in-secure-workload.html)
- [CSW — External Orchestrators (SaaS 4.0)](https://www.cisco.com/c/en/us/td/docs/security/workload_security/secure_workload/user-guide/4_0/cisco-secure-workload-user-guide-saas-v40/m-external-orchestrators.html)
- [CSW — OpenAPI (Orchestrators & enforcement status)](https://www.cisco.com/c/en/us/td/docs/security/workload_security/secure_workload/user-guide/4_0/cisco-secure-workload-user-guide-on-prem-v40/secure-workload-openapis.html)
- [CSW Compatibility Matrix (F5 supported versions, appliance sizing)](https://www.cisco.com/c/m/en_us/products/security/secure-workload-compatibility-matrix.html)
- [CSW-User-Education — full video library](https://github.com/chandrapati/CSW-User-Education)
- [F5 DevCentral](https://community.f5.com/) — BIG-IP IPFIX / logging configuration
