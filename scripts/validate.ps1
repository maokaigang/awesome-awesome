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

$allLinks = @()
$hasError = $false
$entryPattern = '^- \[([^\]]+)\]\((https:\/\/github\.com\/[^)]+)\) - (.+)$'

foreach ($file in $files) {
    $lines = Get-Content -Path $file.FullName
    $entries = @()

    foreach ($line in $lines) {
        if ($line -match '^- ') {
            if ($line -notmatch $entryPattern) {
                Write-Host "Format error in $($file.Name): $line" -ForegroundColor Red
                $hasError = $true
                continue
            }

            $repo = $matches[1]
            $url = $matches[2]
            $entries += $repo
            $allLinks += [PSCustomObject]@{
                File = $file.Name
                Repo = $repo
                Url  = $url.ToLowerInvariant()
            }
        }
    }

    $sorted = $entries | Sort-Object { $_.ToLowerInvariant() }
    for ($i = 0; $i -lt $entries.Count; $i++) {
        if ($entries[$i] -ne $sorted[$i]) {
            Write-Host "Sort error in $($file.Name): entries must be alphabetical by owner/repo" -ForegroundColor Red
            $hasError = $true
            break
        }
    }
}

$dupes = $allLinks | Group-Object Url | Where-Object { $_.Count -gt 1 }
foreach ($dupe in $dupes) {
    $items = $dupe.Group | ForEach-Object { "$($_.Repo) in $($_.File)" }
    Write-Host "Duplicate link: $($dupe.Name) => $($items -join ', ')" -ForegroundColor Red
    $hasError = $true
}

if ($hasError) {
    Write-Error "Validation failed."
}

Write-Host "Validation passed for $($files.Count) category files." -ForegroundColor Green
