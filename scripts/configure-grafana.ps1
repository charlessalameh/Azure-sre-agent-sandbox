<#
.SYNOPSIS
    Provision or remove the SRE Lab Grafana dashboard.

.PARAMETER ResourceGroupName
    Resource group containing the Managed Grafana workspace.

.PARAMETER Cleanup
    Delete the SRE Lab dashboard.

.PARAMETER ConfirmCleanup
    Required with -Cleanup.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter()]
    [switch]$Cleanup,

    [Parameter()]
    [switch]$ConfirmCleanup
)

$ErrorActionPreference = 'Stop'
$dashboardUid = 'sre-aks-overview'
$dashboardPath = Join-Path $PSScriptRoot '..\sre-config\grafana\aks-overview.json'

if ($Cleanup -and -not $ConfirmCleanup) {
    throw 'Cleanup requires both -Cleanup and -ConfirmCleanup.'
}

$grafana = az resource list --resource-group $ResourceGroupName --resource-type Microsoft.Dashboard/grafana --output json 2>$null | ConvertFrom-Json | Select-Object -First 1
if ($LASTEXITCODE -ne 0 -or $null -eq $grafana) {
    throw "No Managed Grafana workspace found in $ResourceGroupName."
}

$endpoint = az resource show --ids $grafana.id --query properties.endpoint --output tsv 2>$null
$token = az account get-access-token --resource https://dashboard.azure.com --query accessToken --output tsv 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($endpoint) -or [string]::IsNullOrWhiteSpace($token)) {
    throw 'Could not resolve the Grafana endpoint or acquire an Entra data-plane token.'
}

function Invoke-GrafanaApi {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [string]$Body
    )

    $args = @('-sS', '-w', "`n%{http_code}", '-X', $Method, "$endpoint$Path",
        '-H', "Authorization: Bearer $token", '-H', 'Content-Type: application/json')
    if ($Body) { $args += @('--data-raw', $Body) }
    $output = & curl @args 2>&1
    $lines = ($output -join "`n") -split "`n"
    $status = 0
    [void][int]::TryParse($lines[-1].Trim(), [ref]$status)
    $response = if ($lines.Count -gt 1) { ($lines[0..($lines.Count - 2)]) -join "`n" } else { '' }
    return @{ StatusCode = $status; Body = $response }
}

$health = Invoke-GrafanaApi -Method GET -Path '/api/org'

# A Grafana data-plane role assigned during deployment can take several minutes
# to propagate, so a 401 immediately after deployment is usually transient.
if ($health.StatusCode -eq 401) {
    Write-Host 'Waiting for Grafana role assignment to propagate...' -ForegroundColor Yellow
    $deadline = (Get-Date).AddMinutes(10)
    while ($health.StatusCode -eq 401 -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 20
        $token = az account get-access-token --resource https://dashboard.azure.com --query accessToken --output tsv 2>$null
        $health = Invoke-GrafanaApi -Method GET -Path '/api/org'
    }
    if ($health.StatusCode -eq 200) {
        Write-Host 'Grafana access granted.' -ForegroundColor Green
    }
}

if ($health.StatusCode -eq 401) {
    throw @"
Grafana API access failed with HTTP 401 (no Grafana role assigned).

Assign yourself Grafana Admin on the workspace, then re-run this script:

  az role assignment create --role "Grafana Admin" ``
      --assignee <your-upn-or-object-id> ``
      --scope $($grafana.id)

Newly assigned Grafana roles can take up to an hour to propagate.
"@
}

if ($health.StatusCode -ne 200) { throw "Grafana API access failed with HTTP $($health.StatusCode)." }

$datasources = Invoke-GrafanaApi -Method GET -Path '/api/datasources'
if ($datasources.StatusCode -ne 200) { throw "Could not list Grafana datasources: HTTP $($datasources.StatusCode)." }
$prometheus = ($datasources.Body | ConvertFrom-Json | Where-Object { $_.type -eq 'prometheus' } | Select-Object -First 1)
if ($null -eq $prometheus) { throw 'No Prometheus datasource is configured in Grafana.' }

if ($Cleanup) {
    $existing = Invoke-GrafanaApi -Method GET -Path "/api/dashboards/uid/$dashboardUid"
    if ($existing.StatusCode -eq 404) {
        Write-Host 'SRE Lab dashboard is not configured.' -ForegroundColor Gray
        exit 0
    }
    if ($existing.StatusCode -ne 200) { throw "Could not inspect SRE Lab dashboard: HTTP $($existing.StatusCode)." }
    if ($PSCmdlet.ShouldProcess($dashboardUid, 'Delete Grafana dashboard')) {
        $deleted = Invoke-GrafanaApi -Method DELETE -Path "/api/dashboards/uid/$dashboardUid"
        if ($deleted.StatusCode -ne 200) { throw "Dashboard cleanup failed with HTTP $($deleted.StatusCode)." }
        Write-Host 'SRE Lab dashboard removed.' -ForegroundColor Green
    }
    exit 0
}

$dashboard = Get-Content -Raw -Path $dashboardPath
$dashboard = $dashboard.Replace('PROMETHEUS_UID', [string]$prometheus.uid)
$created = Invoke-GrafanaApi -Method POST -Path '/api/dashboards/db' -Body $dashboard
if ($created.StatusCode -ne 200) {
    throw "Dashboard provisioning failed with HTTP $($created.StatusCode): $($created.Body.Substring(0, [Math]::Min(300, $created.Body.Length)))"
}

Write-Host "SRE Lab dashboard provisioned: $endpoint/d/$dashboardUid" -ForegroundColor Green
