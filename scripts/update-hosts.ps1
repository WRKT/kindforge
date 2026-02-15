# Run this script as Administrator

$ErrorActionPreference = "Stop"

# Configuration - Must match bootstrap.env
$Domain = "kindforge-cl01.io"

$Domains = @()
$SubdomainsPath = Join-Path $PSScriptRoot "..\dns\subdomains.txt"

if (Test-Path $SubdomainsPath) {
    Write-Host "Reading subdomains from $SubdomainsPath" -ForegroundColor Cyan
    $Subdomains = Get-Content $SubdomainsPath
    foreach ($sub in $Subdomains) {
        if (-not [string]::IsNullOrWhiteSpace($sub) -and -not $sub.StartsWith("#")) {
             $Domains += "$sub.$Domain"
        }
    }
} else {
    Write-Error "Subdomains file not found at $SubdomainsPath"
}

$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

Write-Host "Checking Windows Hosts file: $HostsPath" -ForegroundColor Cyan

if (-not (Test-Path $HostsPath)) {
    Write-Error "Hosts file not found at $HostsPath"
}

$Content = Get-Content $HostsPath
$MissingDomains = @()

foreach ($d in $Domains) {
    if (-not ($Content | Select-String -Pattern "127.0.0.1.*$d")) {
        $MissingDomains += $d
    }
}

if ($MissingDomains.Count -eq 0) {
    Write-Host "[OK] All domains are already configured." -ForegroundColor Green
    Exit
}

Write-Host "Adding missing domains: $($MissingDomains -join ', ')" -ForegroundColor Yellow

$Entry = "127.0.0.1 $($MissingDomains -join ' ') # kindforge-auto"

try {
    Add-Content -Path $HostsPath -Value $Entry -ErrorAction Stop
    Write-Host "[OK] Hosts file updated successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to write to hosts file. Ensure you are running PowerShell as Administrator."
}
