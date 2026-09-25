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
| 3. Prerequisites (Docker, dev container, login, providers, quota, budget) | 🔄 In progress — dev container ✅, login ✅, Owner ✅, quota ✅, what-if ✅ |
| 4. Deploy | ✅ Session 1 (destroyed after) |
| 5. Break scenarios and SRE Agent diagnosis | ✅ OOM: correct root cause in ~5 min (session 2) |
| 6. Tear down and actual cost | ✅ ~$15 total |
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

### 2026-09-23 — Dev container setup on macOS (lessons learned)
- **Docker CLI not found in VS Code:** Docker Desktop installed `docker` in
  `~/.docker/bin`, which bash doesn't load. Fix: Docker Desktop → Settings →
  Advanced → *System* CLI install (links to `/usr/local/bin`), plus
  `"dev.containers.dockerPath"` in VS Code user settings. Without it, the Dev
  Containers extension wrongly starts its own "Docker Install" task.
- **"A mount config is invalid":** `devcontainer.json` bind-mounts `~/.azure`
  (to share the Azure login); the folder didn't exist on a fresh Mac.
  Fix: `mkdir -p ~/.azure`, then Retry. *Candidate repo fix:* create it in an
  `initializeCommand`.
- **Copilot Chat install error in build log:** VS Code 1.138 ships Copilot Chat
  built in (0.66.0); the repo's extension list pins an older one (0.48.1).
  Harmless. *Candidate repo fix:* drop `GitHub.copilot*` from the list.
- **Invalid VS Code settings.json** after manual edits (missing commas) blocked
  settings sync — rewrote as one valid JSON object.
- **Vim extension** was capturing keystrokes (looked like "files are locked").
- **Result:** container ready — Azure CLI 2.90.0, kubectl 1.37.0,
  PowerShell 7.6.6; lab `menu` loaded.

### 2026-09-23 — Azure access checks
- Logged in with device code. Role: **Owner** on the subscription (+ User Access
  Administrator at root) — sufficient for the role assignments the lab creates.

### 2026-09-23 — Subscription and quota
- Subscription type: **pay-as-you-go** (PAYAYG).
- `Microsoft.Compute` provider was **NotRegistered** on the subscription —
  `az vm list-usage` returned nothing until it was registered.
- Sweden Central quota: Total Regional vCPUs = 10, but **Standard DSv5 Family
  vCPUs = 0** (the lab's `D2s_v5` nodes would have failed). Raised DSv5 to
  **10** via Portal → Quotas → My quotas (self-service, pencil icon).
- Lesson: on a fresh subscription, check *family* quota, not just regional.

### 2026-09-23 — Pre-flight: Bicep fix + what-if dry run
- **Bicep missing in dev container** (script printed "✅ Bicep: ERROR: not
  found"). Fix: `az bicep install` → Bicep 0.47.16. *Candidate repo fix:* make
  the prerequisite check fail properly, and install Bicep in `post-create.sh`.
- **What-if result: 32 resources to create, no errors.** Confirmed the low-cost
  profile is applied: AKS `sku.tier = Free`; system pool 1 node (max 2), user
  pool 2 nodes (max 3), all `Standard_D2s_v5`.
- Notable in the plan: SRE Agent `sre-srelab` with access level **High** and
  action mode **Review**, incident management wired to **Azure Monitor**, AKS in
  the agent's knowledge graph; 4 one-minute log alerts (CrashLoop/OOM, HTTP 5xx,
  failed/pending pods, restart spike); Container Insights (ContainerLogV2) +
  Managed Prometheus + Grafana; Azure Policy and Key Vault CSI add-ons on AKS.
- Only warnings are two pre-existing Bicep lint warnings in `aks.bicep`.

### 2026-09-23 — Session 1: deploy + first scenario (OOMKilled)
- **Deploy:** succeeded in Sweden Central on the low-cost profile. Config
  verifier: 18/18 checks passed. Evaluation banner: always-on waived to 23 Oct.
- **Break:** `break-oom` → order-service OOMKilled / CrashLoopBackOff within
  ~2 min (4 restarts in 3 min); rest of the app healthy.
- **What worked:** 3 Azure Monitor alerts fired (crashloop-oom Sev1,
  pod-failures Sev2, pod-restarts Sev2) → 3 incidents auto-acknowledged and
  routed to the `aks-pod-failure-handler` response plan → the agent started
  investigating **with no prompt**, running a textbook sequence with risk labels:
  events → ReplicaSets → svc/endpoints → `logs --previous` → rollout history.
- **What failed:** agent replies ended in *"internal error"*; the agent's own
  retry said *"temporary AI model connection error"*. One incident was marked
  "Completed" although it never produced a diagnosis. No root-cause summary
  was obtained.
- **Also observed:** Operations hub showed **all 3 connectors Failed**
  (azure-monitor, microsoft-learn, outlook) and "Code and Logs not
  configured". Outlook was never authorised — and the incident-handler and
  cluster-health-monitor agents list `SendOutlookEmail` as a tool.
- **Ended:** destroyed the environment (uses evaluation slot 1 of 3).

**Hypotheses to test in session 2** (not yet confirmed)
1. Model backend/capacity issue on a brand-new agent → switch model (e.g.
   GPT-5.2) and allow a 15–20 min warm-up before breaking anything.
2. Failed/unauthorised connectors break the agent's tool loading → authorise
   or remove Outlook (personal @hotmail account may have no M365 mailbox),
   reconnect azure-monitor, disable Learn MCP if it stays failed.
3. Missing data sources → connect Logs (log-srelab, appi-srelab) in
   "Complete setup".
4. Chat access → confirm the signed-in user has *SRE Agent Administrator*.

### 2026-09-25 — Session 2: redeploy + OOMKilled scenario (success)
- **Deploy:** clean; verifier 18/18 and telemetry gate passed (ContainerLogV2 +
  KubePodInventory flowing). Evaluation slot 2 of 3 (waived to 25 Oct).
- **What changed vs session 1:** completed the agent's onboarding page and
  connected **Logs** (log-srelab / appi-srelab) *before* breaking anything;
  model provider **Azure OpenAI**; let the agent onboard and baseline first.
  Result: no "internal error" at all this session.
- **Onboarding:** the agent mapped the architecture into memory files, tagged
  facts [verified]/[unreachable], and flagged a real config gap unprompted
  (`product-service` references a missing `ai-service:5001`).
- **Blind test:** told the agent a failure would be injected without saying
  which. It baselined (3 Log Analytics queries + pods/events/deployments),
  refused to blame earlier startup blips, and set up its own every-minute
  read-only monitor (it expired before the break).
- **Timeline (UTC):** 08:59:20 `break-oom` → 09:01:23 Sev1 alert/incident →
  ~09:03 auto-investigation starts → **09:04 root cause** (~5 min end to end).
- **Agent's diagnosis:** revision 2 at 08:59 cut order-service to a **16 MiB**
  limit (Node old-space 64 MiB); both replicas **OOMKilled / exit 137**,
  CrashLoopBackOff, **service has no endpoints**. Evidence: revision 1 had
  image 2.2.0 with 256 MiB limit / 128 MiB request; node shows no memory
  pressure; kernel events confirm cgroup OOM kills.
- **Proposed fix:** roll back `pets/order-service` to revision 1 — waits for
  approval (Review mode).
- **Score vs ground truth:** correct service, correct cause, exact limit value,
  correct change attribution (rollout), impact (no endpoints), safe fix. ✅
- **Gap:** "could not post an update to the Azure Monitor alert — no
  notification capability" (Outlook not authorised).

### 2026-09-25 — Session 2 cost (Agent consumption page)
- **Total active flow today: 288 AAU** (shown as 288/10,000, 3%).
  Chats 46 · Incidents 50 · **Scheduled tasks 192** · Triggers 1.
- Per thread: [Sev1] crashloop-oom diagnosis **13 AAU**; [Sev2] pod-failures
  16 AAU; agent-created "Pets injected-failure investigation" monitor
  **151 AAU** (every-minute runs, still Active after its stated end time);
  hourly-automation-health 7 AAU.
- **Lesson:** the incident diagnosis itself cost ~13 AAU (≈ $1.30 at the
  commonly quoted ~$0.10/AAU — confirm in Cost Management). Two-thirds of the
  spend came from a scheduled task the agent created itself. Review and switch
  off agent-created scheduled tasks after a test.

### 2026-09-25 — Session 2 wrap-up
- Approved the agent's rollback; order-service back to Running, store orders working.
- **Actual cost of the whole experiment (both sessions): about $15 USD**, taken from
  Azure free-tier credits.
- Environment destroyed. Repo prepared for public sharing: original MIT LICENSE
  restored, credit and "About this version" section added to the README.

---

## Scenario results *(fill in during the session)*

| Scenario | What I broke | Agent's diagnosis (summary) | Correct? | Time to root cause | Fix suggested / applied | AAU used |
|---|---|---|---|---|---|---|
| OOMKilled | Memory limit cut to 16 MiB on order-service | 16 MiB limit → OOMKilled/137, no endpoints; blamed 08:59 rollout (session 2) | ✅ Yes | ~5 min break→RCA (2 min to alert) | Roll back to revision 1 (approved, applied) | 13 |
| CrashLoop | | | | | | |
| ImagePullBackOff | | | | | | |
| HighCPU | | | | | | |
| PendingPods | | | | | | |
| ProbeFailure | | | | | | |
| NetworkBlock | | | | | | |
| MissingConfig | | | | | | |
| MongoDBDown | | | | | | |
| ServiceMismatch | | | | | | |

**Actual cost:** about $15 USD for both sessions (Azure credits).

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
