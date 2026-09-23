# Azure SRE Agent Lab — Journal

A running record of what I changed, what I found, and why. It is the raw
material for a LinkedIn write-up once the lab has been deployed and tested.

**Owner:** Charlie Salameh · **Started:** 2026-09-23 · **Target region:** Sweden Central

---

## Status at a glance

| Phase | Status |
|---|---|
| 1. Repo setup and analysis | ✅ Done |
| 2. Cost analysis and low-cost profile | ✅ Done (changes pending my review/commit) |
| 3. Prerequisites (Docker, dev container, login, providers, quota, budget) | ⏳ Next |
| 4. Deploy | ⬜ |
| 5. Break scenarios and SRE Agent diagnosis | ⬜ |
| 6. Tear down and actual cost | ⬜ |
| 7. Write-up / LinkedIn post | ⬜ |

---

## Change log

### 2026-09-23 — Repo setup
- Cloned the open-source Azure SRE Agent lab into my own private GitHub repo.
- Git workflow: `origin` = my repo, `upstream` = original (push disabled).
  I reset the history to a single clean commit and use a tagged diff
  (`upstream-synced`) to pull future upstream improvements.
- Set my git identity so commits are attributed to my GitHub account.

### 2026-09-23 — Architecture review
- **What gets deployed (Bicep):** AKS (Azure CNI + Calico), a multi-service store
  app (store-front, store-admin, order, product, makeline, MongoDB, RabbitMQ),
  Log Analytics, App Insights, Managed Prometheus, Managed Grafana, 4 one-minute
  log alerts + action group, ACR, Key Vault, VNet, and the SRE Agent
  (`Microsoft.App/agents`) with a user-assigned managed identity.
- **AI configuration layer (`sre-config/`):** knowledge-base runbooks, custom
  sub-agents (incident-handler, cluster-health-monitor, code-analyzer),
  connectors (Azure Monitor, Microsoft Learn MCP, Outlook, GitHub MCP), and a
  Review-mode response plan (human approves remediation).
- **10 break scenarios:** OOMKilled, CrashLoop, ImagePullBackOff, HighCPU,
  PendingPods, ProbeFailure, NetworkBlock, MissingConfig, MongoDBDown
  (cascading), ServiceMismatch (silent failure).

### 2026-09-23 — Findings
- **SRE Agent is now GA in 10 regions** (per Microsoft Learn, July 2026), but the
  repo's `deploy.ps1` and `main.bicep` still only allow eastus2 / swedencentral /
  australiaeast. None are in the UAE — relevant for GCC data-residency discussions.
- **Billing is AAU-based:** always-on 4 AAU/hr per agent (~$0.40/hr) plus
  token-based active usage. Microsoft's examples: quick question ≈ 4 AAU,
  investigation ≈ 35 AAU, full remediation ≈ 87 AAU (Claude Opus); GPT-5.2 is
  roughly a third of that.
- **Free evaluation:** always-on cost waived for 30 days per agent, max
  **3 agents per customer including deleted ones** — every deploy/destroy
  cycle consumes one. Plan few, well-prepared sessions.
- **Training sandboxes don't work for this lab:** e.g. Pluralsight's Azure
  sandbox blocks role assignments and managed identities, both of which the
  SRE Agent requires.
- **Dev container on Apple Silicon:** `post-create.sh` downloads amd64 builds of
  `kubelogin` and `k9s`; they won't run on an M-series Mac (optional tools,
  deployment unaffected). Candidate fix.

### 2026-09-23 — Cost analysis (Sweden Central, pay-as-you-go retail)
| Component | Original | Low-cost profile |
|---|---|---|
| AKS nodes (D2s_v5 @ $0.102/hr) | 5 nodes — $0.51/hr | 3 nodes — $0.31/hr |
| AKS control plane | Standard (SLA) — $0.10/hr | Free — $0 |
| Other (disks, Grafana, LB, logs, ACR, KV) | ~$0.34/hr | ~$0.30/hr |
| **Infrastructure total** | **~$0.95/hr** | **~$0.60–0.70/hr** |
| SRE Agent always-on | $0.40/hr | $0 during evaluation |
| Left running for a month | ~$1,000 | ~$450–500 |

Estimated full lab session (deploy + 3 h testing + destroy, 4–5 AI
investigations on a cheaper model): **~$5–10**.

### 2026-09-23 — Change: low-cost lab profile *(uncommitted — pending my review)*
- `infra/bicep/main.bicepparam`: system nodes 2 → 1, user nodes 3 → 2,
  `aksSkuTier = 'Free'`, autoscale caps system 2 / user 3.
- `infra/bicep/main.bicep`: new params `aksSkuTier`, `systemNodeMaxCount`,
  `userNodeMaxCount` (defaults keep original behaviour).
- `infra/bicep/modules/aks.bicep`: tier and autoscale max were hard-coded
  (`Standard`, 5, 10) — now parameterised.
- **Why it's safe:** app requests ~1.1 vCPU total vs ~3.8 allocatable on 2
  workers; `pending-pods` still stays Pending (asks 8 CPU/pod); autoscale cap
  prevents runaway node cost.
- **Validated:** Bicep build and params build succeed; no new warnings.

---

## Scenario results *(fill in during the session)*

| Scenario | What I broke | Agent's diagnosis (summary) | Correct? | Time to root cause | Fix suggested / applied | AAU used |
|---|---|---|---|---|---|---|
| OOMKilled | | | | | | |
| CrashLoop | | | | | | |
| ImagePullBackOff | | | | | | |
| HighCPU | | | | | | |
| PendingPods | | | | | | |
| ProbeFailure | | | | | | |
| NetworkBlock | | | | | | |
| MissingConfig | | | | | | |
| MongoDBDown | | | | | | |
| ServiceMismatch | | | | | | |

**Actual cost of the session:** _(from Cost Management, 24–48 h after teardown)_

---

## LinkedIn post material

**Possible angles**
- "I let an AI agent troubleshoot a Kubernetes cluster I broke on purpose — here's how it did."
- Cost reality: what an AI SRE lab actually costs, and how I cut it by ~50%.
- Human vs agent: my manual diagnosis vs the SRE Agent's, scenario by scenario.
- GCC view: regions, data residency, and governance (Review mode, RBAC) for regulated sectors.

**Numbers worth quoting** (verify before posting)
- 10 failure scenarios · ~25 min to deploy · ~$0.65/hr infrastructure after optimisation
- Evaluation: always-on cost waived 30 days, 3 agents per customer

**Screenshots to capture during the session**
- [ ] Architecture diagram (resource group view)
- [ ] Grafana AKS overview dashboard — healthy vs broken
- [ ] SRE Agent chat: a root-cause answer (e.g. MongoDBDown cascade)
- [ ] Review-mode approval of a remediation
- [ ] Cost Management view after teardown

**Credit:** built on the open-source *azure-sre-agent-sandbox* lab (MIT) and extended.
