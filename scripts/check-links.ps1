Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$categoryDir = Join-Path $root "categories"

if (-not (Test-Path $categoryDir)) {
    Write-Error "Missing categories directory: $categoryDir"
}

$files = Get-ChildItem -Path $categoryDir -Filter *.md |
    Where-Object { $_.Name -notmatch '\.zh-CN\.md$' } |
    Sort-Object Name

if ($files.Count -eq 0) {
    Write-Error "No category markdown files found in $categoryDir"
}

$urlPattern = '\((https:\/\/github\.com\/[^)\s]+)\)'
$urlMap = @{}

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName
    foreach ($line in $content) {
        if ($line -match $urlPattern) {
            $url = $matches[1]
            $key = $url.ToLowerInvariant()
            if (-not $urlMap.ContainsKey($key)) {
                $urlMap[$key] = [PSCustomObject]@{
                    Url   = $url
                    Files = [System.Collections.Generic.HashSet[string]]::new()
                }
            }
            [void]$urlMap[$key].Files.Add($file.Name)
        }
    }
}

$headers = @{
    "User-Agent" = "awesome-awesome-link-check"
}

$failed = @()
$checked = 0

foreach ($item in $urlMap.Values | Sort-Object Url) {
    $url = $item.Url
    $checked++

    $ok = $false
    try {
        $head = Invoke-WebRequest -Uri $url -Method Head -MaximumRedirection 5 -TimeoutSec 20 -Headers $headers
        if ($head.StatusCode -ge 200 -and $head.StatusCode -lt 400) {
            $ok = $true
        }
    } catch {
        # Some endpoints reject HEAD; fallback to GET.
    }

    if (-not $ok) {
        try {
            $get = Invoke-WebRequest -Uri $url -Method Get -MaximumRedirection 5 -TimeoutSec 20 -Headers $headers
            if ($get.StatusCode -ge 200 -and $get.StatusCode -lt 400) {
                $ok = $true
            }
        } catch {
            $ok = $false
        }
    }

    if (-not $ok) {
        $failed += [PSCustomObject]@{
            Url   = $url
            Files = ($item.Files | Sort-Object) -join ", "
        }
        Write-Host "FAIL $url (in: $((($item.Files | Sort-Object) -join ', ')))" -ForegroundColor Red
    } else {
        Write-Host "OK   $url" -ForegroundColor Green
    }
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Broken links found:" -ForegroundColor Red
    foreach ($entry in $failed) {
        Write-Host "- $($entry.Url) [$($entry.Files)]" -ForegroundColor Red
    }
    Write-Error "Link check failed: $($failed.Count) broken link(s) out of $checked checked."
}

Write-Host "Link check passed: $checked links checked." -ForegroundColor Green
