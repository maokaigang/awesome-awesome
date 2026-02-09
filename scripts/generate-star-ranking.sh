#!/usr/bin/env bash
set -euo pipefail

TOP_N=5
if [[ "${1:-}" == "--top-n" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "Missing value for --top-n" >&2
    exit 1
  fi
  TOP_N="$2"
elif [[ -n "${1:-}" ]]; then
  TOP_N="$1"
fi

if ! [[ "$TOP_N" =~ ^[0-9]+$ ]] || (( TOP_N < 1 || TOP_N > 100 )); then
  echo "Top N must be an integer between 1 and 100." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" "$TOP_N" <<'PY'
import datetime as dt
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

root = Path(sys.argv[1])
top_n = int(sys.argv[2])
category_dir = root / "categories"
output_en = root / "docs" / "STAR_RANKING.md"
output_zh = root / "docs" / "STAR_RANKING.zh-CN.md"

if not category_dir.exists():
    raise SystemExit(f"Missing categories directory: {category_dir}")

files = sorted(
    p for p in category_dir.glob("*.md")
    if not p.name.endswith(".zh-CN.md")
)
if not files:
    raise SystemExit(f"No category markdown files found in {category_dir}")

category_names = sorted({p.stem for p in files})

entry_pattern = re.compile(r"^- \[([^\]]+)\]\((https://github\.com/[^)]+)\) - (.+)$")
repo_map = {}

for file in files:
    category = file.stem
    for line in file.read_text(encoding="utf-8").splitlines():
        m = entry_pattern.match(line)
        if not m:
            continue
        repo, url, desc = m.group(1).strip(), m.group(2).strip(), m.group(3).strip()
        key = repo.lower()
        if key not in repo_map:
            repo_map[key] = {
                "repo": repo,
                "url": url,
                "description": desc,
                "categories": set(),
            }
        repo_map[key]["categories"].add(category)

if not repo_map:
    raise SystemExit("No repository entries found under categories/*.md")

def fetch_repo_data(repo: str) -> dict:
    headers = {
        "User-Agent": "awesome-awesome-star-ranking",
        "Accept": "application/vnd.github+json",
    }
    token = os.getenv("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}",
        headers=headers,
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))

def category_en(name: str) -> str:
    mapping = {
        "ai": "AI",
        "frontend": "Frontend",
        "backend": "Backend",
        "devops": "DevOps",
        "security": "Security",
        "data": "Data",
        "mobile": "Mobile",
    }
    return mapping.get(name.lower(), name)

def category_zh(name: str) -> str:
    mapping = {
        "ai": "AI",
        "frontend": "前端",
        "backend": "后端",
        "devops": "DevOps",
        "security": "安全",
        "data": "数据",
        "mobile": "移动端",
    }
    return mapping.get(name.lower(), name)

canonical_map = {}
failures = []
merged_aliases = []

for entry in sorted(repo_map.values(), key=lambda x: x["repo"].lower()):
    try:
        repo_data = fetch_repo_data(entry["repo"])
        canonical_key = str(repo_data["id"])
        canonical_repo = repo_data["full_name"]
        canonical_url = repo_data["html_url"]
        categories = sorted(entry["categories"])

        if canonical_key not in canonical_map:
            canonical_map[canonical_key] = {
                "repo": canonical_repo,
                "url": canonical_url,
                "stars": int(repo_data["stargazers_count"]),
                "categories": set(categories),
                "pushed_at": repo_data["pushed_at"],
                "archived": bool(repo_data.get("archived", False)),
                "description": entry["description"],
                "aliases": {entry["repo"]},
            }
        else:
            existing = canonical_map[canonical_key]
            existing["categories"].update(categories)
            existing["aliases"].add(entry["repo"])
            alias_list = ", ".join(sorted(existing["aliases"]))
            merged_aliases.append(f"{canonical_repo} <= {alias_list}")

        print(f"Fetched: {entry['repo']}")
    except Exception as exc:  # noqa: BLE001
        failures.append(entry["repo"])
        print(f"Failed: {entry['repo']} => {exc}")

if not canonical_map:
    raise SystemExit("Could not fetch star data for any repository.")

results = []
for item in canonical_map.values():
    categories = sorted(item["categories"])
    results.append(
        {
            "repo": item["repo"],
            "url": item["url"],
            "stars": item["stars"],
            "categories": ", ".join(categories),
            "category_list": categories,
            "pushed_at": item["pushed_at"],
            "archived": item["archived"],
            "description": item["description"],
            "aliases": sorted(item["aliases"]),
        }
    )

if not results:
    raise SystemExit("Could not fetch star data for any repository.")

sorted_results = sorted(results, key=lambda x: (-x["stars"], x["repo"].lower()))
generated_at = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
global_rank = {item["repo"].lower(): idx + 1 for idx, item in enumerate(sorted_results)}

lines_en = []
lines_en.append("# Star Ranking")
lines_en.append("")
lines_en.append("> Repositories in this index ranked by GitHub stars.")
lines_en.append("")
lines_en.append("[![中文](https://img.shields.io/badge/语言-中文-blue)](STAR_RANKING.zh-CN.md)")
lines_en.append("")
lines_en.append(f"- Last updated: {generated_at}")
lines_en.append("- Data source: GitHub REST API (`stargazers_count`)")
lines_en.append(f"- Category Top N: {top_n}")
lines_en.append("")
lines_en.append("## Global Ranking")
lines_en.append("")
lines_en.append("| Rank | Repository | Stars | Categories | Last Push (UTC) | Notes |")
lines_en.append("| --- | --- | ---: | --- | --- | --- |")

for idx, item in enumerate(sorted_results, start=1):
    repo_link = f"[`{item['repo']}`]({item['url']})"
    stars = f"{item['stars']:,}"
    last_push = item["pushed_at"][:10]
    note = "Archived" if item["archived"] else "-"
    lines_en.append(f"| {idx} | {repo_link} | {stars} | {item['categories']} | {last_push} | {note} |")

lines_en.append("")
lines_en.append(f"## Top {top_n} by Category")

for cat in category_names:
    cat_items = [x for x in sorted_results if cat in x["category_list"]][:top_n]
    if not cat_items:
        continue
    lines_en.append("")
    lines_en.append(f"### {category_en(cat)}")
    lines_en.append("")
    lines_en.append("| Category Rank | Global Rank | Repository | Stars | Last Push (UTC) | Notes |")
    lines_en.append("| --- | --- | --- | ---: | --- | --- |")
    for cidx, item in enumerate(cat_items, start=1):
        repo_link = f"[`{item['repo']}`]({item['url']})"
        stars = f"{item['stars']:,}"
        last_push = item["pushed_at"][:10]
        note = "Archived" if item["archived"] else "-"
        lines_en.append(
            f"| {cidx} | {global_rank[item['repo'].lower()]} | {repo_link} | {stars} | {last_push} | {note} |"
        )

if merged_aliases:
    lines_en.append("")
    lines_en.append("## Canonical Merge Notes")
    lines_en.append("")
    lines_en.append("Merged redirected/aliased entries:")
    for line in sorted(set(merged_aliases)):
        lines_en.append(f"- {line}")

if failures:
    lines_en.append("")
    lines_en.append("## Fetch Warnings")
    lines_en.append("")
    lines_en.append("Could not fetch data for: " + ", ".join(sorted(failures)))

lines_zh = []
lines_zh.append("# Star 排行榜")
lines_zh.append("")
lines_zh.append("> 按 GitHub Star 数量对本索引中的仓库进行排序。")
lines_zh.append("")
lines_zh.append("[![English](https://img.shields.io/badge/Language-English-blue)](STAR_RANKING.md)")
lines_zh.append("")
lines_zh.append(f"- 更新时间：{generated_at}")
lines_zh.append("- 数据来源：GitHub REST API（`stargazers_count`）")
lines_zh.append(f"- 分类 Top N：{top_n}")
lines_zh.append("")
lines_zh.append("## 全局排行")
lines_zh.append("")
lines_zh.append("| 排名 | 仓库 | Stars | 分类 | 最近推送（UTC） | 备注 |")
lines_zh.append("| --- | --- | ---: | --- | --- | --- |")

for idx, item in enumerate(sorted_results, start=1):
    repo_link = f"[`{item['repo']}`]({item['url']})"
    stars = f"{item['stars']:,}"
    last_push = item["pushed_at"][:10]
    note = "已归档" if item["archived"] else "-"
    lines_zh.append(f"| {idx} | {repo_link} | {stars} | {item['categories']} | {last_push} | {note} |")

lines_zh.append("")
lines_zh.append(f"## 按分类 Top {top_n}")

for cat in category_names:
    cat_items = [x for x in sorted_results if cat in x["category_list"]][:top_n]
    if not cat_items:
        continue
    lines_zh.append("")
    lines_zh.append(f"### {category_zh(cat)}")
    lines_zh.append("")
    lines_zh.append("| 分类内排名 | 全局排名 | 仓库 | Stars | 最近推送（UTC） | 备注 |")
    lines_zh.append("| --- | --- | --- | ---: | --- | --- |")
    for cidx, item in enumerate(cat_items, start=1):
        repo_link = f"[`{item['repo']}`]({item['url']})"
        stars = f"{item['stars']:,}"
        last_push = item["pushed_at"][:10]
        note = "已归档" if item["archived"] else "-"
        lines_zh.append(
            f"| {cidx} | {global_rank[item['repo'].lower()]} | {repo_link} | {stars} | {last_push} | {note} |"
        )

if merged_aliases:
    lines_zh.append("")
    lines_zh.append("## Canonical 合并说明")
    lines_zh.append("")
    lines_zh.append("以下重定向或别名仓库已自动合并：")
    for line in sorted(set(merged_aliases)):
        lines_zh.append(f"- {line}")

if failures:
    lines_zh.append("")
    lines_zh.append("## 拉取告警")
    lines_zh.append("")
    lines_zh.append("以下仓库未能拉取数据：" + "、".join(sorted(failures)))

output_en.write_text("\n".join(lines_en) + "\n", encoding="utf-8")
output_zh.write_text("\n".join(lines_zh) + "\n", encoding="utf-8")

print("Generated files:")
print(f"- {output_en}")
print(f"- {output_zh}")
PY
