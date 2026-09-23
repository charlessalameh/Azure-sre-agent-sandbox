// =============================================================================
// Bicep Parameters File - SRE Agent Sandbox
// =============================================================================
// Deploy with: az deployment sub create --location eastus2 --template-file main.bicep
// =============================================================================

using 'main.bicep'

// Core parameters are passed by scripts/deploy.ps1 via --parameters

// Observability stack (Grafana + Prometheus)
param deployObservability = true

// Baseline alert rules
param deployAlerts = true

// Deploy Azure SRE Agent (programmatic deployment now supported)
param deploySreAgent = true

// Default action group for incident routing (add webhook at deploy time)
param deployActionGroup = true

// AKS Configuration - cost-optimized for demo
param systemNodeVmSize = 'Standard_D2s_v5'
param userNodeVmSize = 'Standard_D2s_v5'
param systemNodeCount = 1   // was 2 - low-cost lab profile
param userNodeCount = 2     // was 3 - app requests ~1.1 vCPU in total, 2 nodes is plenty

// Low-cost lab profile (Charlie) - AKS Free tier (no uptime SLA) and capped autoscaling
param aksSkuTier = 'Free'       // was hardcoded 'Standard' (+$0.10/hr)
param systemNodeMaxCount = 2    // was hardcoded 5
param userNodeMaxCount = 3      // was hardcoded 10 - caps cost if a scenario triggers scale-out

// Tags
param tags = {
  workload: 'sre-agent-demo'
  environment: 'sandbox'
  managedBy: 'bicep'
  purpose: 'demonstration'
  costCenter: 'demo-lab'
}
