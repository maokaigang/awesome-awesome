param(
    [ValidateRange(1, 100)]
    [int]$TopN = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$categoryDir = Join-Path $root "categories"
$outputEn = Join-Path $root "docs/STAR_RANKING.md"
$outputZh = Join-Path $root "docs/STAR_RANKING.zh-CN.md"

if (-not (Test-Path $categoryDir)) {
    Write-Error "Missing categories directory: $categoryDir"
}

$files = Get-ChildItem -Path $categoryDir -Filter *.md |
    Where-Object { $_.Name -notmatch '\.zh-CN\.md$' } |
    Sort-Object Name

if ($files.Count -eq 0) {
    Write-Error "No category markdown files found in $categoryDir"
}

$categoryNames = $files |
    ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } |
    Sort-Object -Unique

$entryPattern = '^- \[([^\]]+)\]\((https:\/\/github\.com\/[^)]+)\) - (.+)$'
$repoMap = @{}

foreach ($file in $files) {
    $category = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $lines = Get-Content -Path $file.FullName

    foreach ($line in $lines) {
        if ($line -match $entryPattern) {
            $repo = $matches[1].Trim()
            $url = $matches[2].Trim()
            $desc = $matches[3].Trim()
            $key = $repo.ToLowerInvariant()

            if (-not $repoMap.ContainsKey($key)) {
                $repoMap[$key] = [PSCustomObject]@{
                    Repo        = $repo
                    Url         = $url
                    Description = $desc
                    Categories  = [System.Collections.Generic.HashSet[string]]::new()
                }
            }

            [void]$repoMap[$key].Categories.Add($category)
        }
    }
}

if ($repoMap.Count -eq 0) {
    Write-Error "No repository entries found under categories/*.md"
}

function Escape-MarkdownCell {
    param(
        [string]$Text
    )
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "-"
    }

    return ($Text -replace '\|', '\|' -replace '\r?\n', ' ').Trim()
}

function Get-RepoData {
    param(
        [string]$Repo
    )

    $headers = @{
        "User-Agent" = "awesome-awesome-star-ranking"
        "Accept"     = "application/vnd.github+json"
    }

    if ($env:GITHUB_TOKEN) {
        $headers["Authorization"] = "Bearer $($env:GITHUB_TOKEN)"
    }

    $url = "https://api.github.com/repos/$Repo"
    return Invoke-RestMethod -Uri $url -Headers $headers -Method Get -TimeoutSec 30
}

function Get-CategoryDisplayEn {
    param(
        [string]$Category
    )
    switch ($Category.ToLowerInvariant()) {
        "ai" { return "AI" }
        "frontend" { return "Frontend" }
        "backend" { return "Backend" }
        "devops" { return "DevOps" }
        "security" { return "Security" }
        "data" { return "Data" }
        "mobile" { return "Mobile" }
        default { return $Category }
    }
}

function Get-CategoryDisplayZh {
    param(
        [string]$Category
    )
    switch ($Category.ToLowerInvariant()) {
        "ai" { return "AI" }
        "frontend" { return "前端" }
        "backend" { return "后端" }
        "devops" { return "DevOps" }
        "security" { return "安全" }
        "data" { return "数据" }
        "mobile" { return "移动端" }
        default { return $Category }
    }
}

$canonicalMap = @{}
$failures = @()
$mergedAliases = @()

foreach ($entry in $repoMap.Values | Sort-Object Repo) {
    try {
        $repoData = Get-RepoData -Repo $entry.Repo
        $categoryList = @($entry.Categories | Sort-Object)
        $canonicalKey = [string]$repoData.id
        $canonicalRepo = [string]$repoData.full_name
        $canonicalUrl = [string]$repoData.html_url

        if (-not $canonicalMap.ContainsKey($canonicalKey)) {
            $categorySet = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($c in $categoryList) {
                [void]$categorySet.Add($c)
            }

            $aliasSet = [System.Collections.Generic.HashSet[string]]::new()
            [void]$aliasSet.Add($entry.Repo)

            $canonicalMap[$canonicalKey] = [PSCustomObject]@{
                Repo        = $canonicalRepo
                Url         = $canonicalUrl
                Stars       = [int]$repoData.stargazers_count
                CategorySet = $categorySet
                PushedAt    = [DateTime]$repoData.pushed_at
                Archived    = [bool]$repoData.archived
                Description = $entry.Description
                Aliases     = $aliasSet
            }
        } else {
            $existing = $canonicalMap[$canonicalKey]
            foreach ($c in $categoryList) {
                [void]$existing.CategorySet.Add($c)
            }
            [void]$existing.Aliases.Add($entry.Repo)
            $aliasList = @($existing.Aliases | Sort-Object)
            $mergedAliases += "$canonicalRepo <= " + ($aliasList -join ", ")
        }

        Write-Host "Fetched: $($entry.Repo)" -ForegroundColor Green
    } catch {
        $failures += $entry.Repo
        Write-Host "Failed: $($entry.Repo) => $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($canonicalMap.Count -eq 0) {
    Write-Error "Could not fetch star data for any repository."
}

$results = @()
foreach ($item in $canonicalMap.Values) {
    $categoryList = @($item.CategorySet | Sort-Object)
    $results += [PSCustomObject]@{
        Repo         = $item.Repo
        Url          = $item.Url
        Stars        = $item.Stars
        Categories   = $categoryList -join ", "
        CategoryList = $categoryList
        PushedAt     = $item.PushedAt
        Archived     = $item.Archived
        Description  = $item.Description
        Aliases      = @($item.Aliases | Sort-Object)
    }
}

if ($results.Count -eq 0) {
    Write-Error "Could not fetch star data for any repository."
}

$sorted = $results | Sort-Object @{ Expression = "Stars"; Descending = $true }, @{ Expression = "Repo"; Descending = $false }
$generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
$globalRankMap = @{}
for ($i = 0; $i -lt $sorted.Count; $i++) {
    $globalRankMap[$sorted[$i].Repo.ToLowerInvariant()] = $i + 1
}

$linesEn = @()
$linesEn += "# Star Ranking"
$linesEn += ""
$linesEn += "> Repositories in this index ranked by GitHub stars."
$linesEn += ""
$linesEn += "[![中文](https://img.shields.io/badge/语言-中文-blue)](STAR_RANKING.zh-CN.md)"
$linesEn += ""
$linesEn += "- Last updated: $generatedAt"
$linesEn += "- Data source: GitHub REST API (`stargazers_count`)"
$linesEn += "- Category Top N: $TopN"
$linesEn += ""
$linesEn += "## Global Ranking"
$linesEn += ""
$linesEn += "| Rank | Repository | Stars | Categories | Last Push (UTC) | Notes |"
$linesEn += "| --- | --- | ---: | --- | --- | --- |"

$rank = 1
foreach ($item in $sorted) {
    $repoLink = "[``$($item.Repo)``]($($item.Url))"
    $stars = "{0:N0}" -f $item.Stars
    $categories = Escape-MarkdownCell -Text $item.Categories
    $lastPush = $item.PushedAt.ToUniversalTime().ToString("yyyy-MM-dd")
    $note = if ($item.Archived) { "Archived" } else { "-" }
    $linesEn += "| $rank | $repoLink | $stars | $categories | $lastPush | $note |"
    $rank++
}

$linesEn += ""
$linesEn += "## Top $TopN by Category"

foreach ($category in $categoryNames) {
    $categoryItems = $sorted |
        Where-Object { $_.CategoryList -contains $category } |
        Select-Object -First $TopN

    if ($categoryItems.Count -eq 0) {
        continue
    }

    $linesEn += ""
    $linesEn += "### $(Get-CategoryDisplayEn -Category $category)"
    $linesEn += ""
    $linesEn += "| Category Rank | Global Rank | Repository | Stars | Last Push (UTC) | Notes |"
    $linesEn += "| --- | --- | --- | ---: | --- | --- |"

    $categoryRank = 1
    foreach ($item in $categoryItems) {
        $repoLink = "[``$($item.Repo)``]($($item.Url))"
        $stars = "{0:N0}" -f $item.Stars
        $globalRank = $globalRankMap[$item.Repo.ToLowerInvariant()]
        $lastPush = $item.PushedAt.ToUniversalTime().ToString("yyyy-MM-dd")
        $note = if ($item.Archived) { "Archived" } else { "-" }
        $linesEn += "| $categoryRank | $globalRank | $repoLink | $stars | $lastPush | $note |"
        $categoryRank++
    }
}

if ($mergedAliases.Count -gt 0) {
    $aliasLines = $mergedAliases | Sort-Object -Unique
    $linesEn += ""
    $linesEn += "## Canonical Merge Notes"
    $linesEn += ""
    $linesEn += "Merged redirected/aliased entries:"
    foreach ($alias in $aliasLines) {
        $linesEn += "- $alias"
    }
}

if ($failures.Count -gt 0) {
    $linesEn += ""
    $linesEn += "## Fetch Warnings"
    $linesEn += ""
    $linesEn += "Could not fetch data for: " + (($failures | Sort-Object) -join ", ")
}

$linesZh = @()
$linesZh += "# Star 排行榜"
$linesZh += ""
$linesZh += "> 按 GitHub Star 数量对本索引中的仓库进行排序。"
$linesZh += ""
$linesZh += "[![English](https://img.shields.io/badge/Language-English-blue)](STAR_RANKING.md)"
$linesZh += ""
$linesZh += "- 更新时间：$generatedAt"
$linesZh += "- 数据来源：GitHub REST API（`stargazers_count`）"
$linesZh += "- 分类 Top N：$TopN"
$linesZh += ""
$linesZh += "## 全局排行"
$linesZh += ""
$linesZh += "| 排名 | 仓库 | Stars | 分类 | 最近推送（UTC） | 备注 |"
$linesZh += "| --- | --- | ---: | --- | --- | --- |"

$rank = 1
foreach ($item in $sorted) {
    $repoLink = "[``$($item.Repo)``]($($item.Url))"
    $stars = "{0:N0}" -f $item.Stars
    $categories = Escape-MarkdownCell -Text $item.Categories
    $lastPush = $item.PushedAt.ToUniversalTime().ToString("yyyy-MM-dd")
    $note = if ($item.Archived) { "已归档" } else { "-" }
    $linesZh += "| $rank | $repoLink | $stars | $categories | $lastPush | $note |"
    $rank++
}

$linesZh += ""
$linesZh += "## 按分类 Top $TopN"

foreach ($category in $categoryNames) {
    $categoryItems = $sorted |
        Where-Object { $_.CategoryList -contains $category } |
        Select-Object -First $TopN

    if ($categoryItems.Count -eq 0) {
        continue
    }

    $linesZh += ""
    $linesZh += "### $(Get-CategoryDisplayZh -Category $category)"
    $linesZh += ""
    $linesZh += "| 分类内排名 | 全局排名 | 仓库 | Stars | 最近推送（UTC） | 备注 |"
    $linesZh += "| --- | --- | --- | ---: | --- | --- |"

    $categoryRank = 1
    foreach ($item in $categoryItems) {
        $repoLink = "[``$($item.Repo)``]($($item.Url))"
        $stars = "{0:N0}" -f $item.Stars
        $globalRank = $globalRankMap[$item.Repo.ToLowerInvariant()]
        $lastPush = $item.PushedAt.ToUniversalTime().ToString("yyyy-MM-dd")
        $note = if ($item.Archived) { "已归档" } else { "-" }
        $linesZh += "| $categoryRank | $globalRank | $repoLink | $stars | $lastPush | $note |"
        $categoryRank++
    }
}

if ($mergedAliases.Count -gt 0) {
    $aliasLines = $mergedAliases | Sort-Object -Unique
    $linesZh += ""
    $linesZh += "## Canonical 合并说明"
    $linesZh += ""
    $linesZh += "以下重定向或别名仓库已自动合并："
    foreach ($alias in $aliasLines) {
        $linesZh += "- $alias"
    }
}

if ($failures.Count -gt 0) {
    $linesZh += ""
    $linesZh += "## 拉取告警"
    $linesZh += ""
    $linesZh += "以下仓库未能拉取数据：" + (($failures | Sort-Object) -join "、")
}

$linesEn -join "`n" | Set-Content -Path $outputEn -Encoding utf8
$linesZh -join "`n" | Set-Content -Path $outputZh -Encoding utf8

Write-Host "Generated files:" -ForegroundColor Green
Write-Host "- $outputEn" -ForegroundColor Green
Write-Host "- $outputZh" -ForegroundColor Green
