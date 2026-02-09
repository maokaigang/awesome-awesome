#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

root = Path(sys.argv[1])
category_dir = root / "categories"
if not category_dir.exists():
    raise SystemExit(f"Missing categories directory: {category_dir}")

files = sorted(p for p in category_dir.glob("*.md") if not p.name.endswith(".zh-CN.md"))
if not files:
    raise SystemExit(f"No category markdown files found in {category_dir}")

entry_pattern = re.compile(r"^- \[([^\]]+)\]\((https://github\.com/[^)]+)\) - (.+)$")
repos = {}

for file in files:
    for line in file.read_text(encoding="utf-8").splitlines():
        m = entry_pattern.match(line)
        if not m:
            continue
        repo = m.group(1).strip()
        repos.setdefault(repo.lower(), {"repo": repo, "files": set()})
        repos[repo.lower()]["files"].add(file.name)

if not repos:
    raise SystemExit("No repository entries found under categories/*.md")

headers = {
    "User-Agent": "awesome-awesome-selection-validator",
    "Accept": "application/vnd.github+json",
}
token = os.getenv("GITHUB_TOKEN")
if token:
    headers["Authorization"] = f"Bearer {token}"

def fetch_repo(repo: str) -> dict:
    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}",
        headers=headers,
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))

meta = {}
errors = []

for entry in sorted(repos.values(), key=lambda x: x["repo"].lower()):
    repo = entry["repo"]
    try:
        data = fetch_repo(repo)
    except urllib.error.HTTPError as exc:
        errors.append(f"Failed to fetch {repo}: HTTP {exc.code}")
        continue
    except Exception as exc:  # noqa: BLE001
        errors.append(f"Failed to fetch {repo}: {exc}")
        continue

    fork = bool(data.get("fork"))
    source = data.get("source") if fork else None
    source_id = source.get("id") if isinstance(source, dict) else None
    source_full_name = source.get("full_name") if isinstance(source, dict) else None
    source_stars = source.get("stargazers_count") if isinstance(source, dict) else None

    family_id = str(source_id if source_id is not None else data["id"])
    meta[repo.lower()] = {
        "listed_repo": repo,
        "canonical_repo": data.get("full_name", repo),
        "stars": int(data.get("stargazers_count", 0)),
        "fork": fork,
        "family_id": family_id,
        "source_full_name": source_full_name,
        "source_stars": int(source_stars) if isinstance(source_stars, int) else None,
        "files": sorted(entry["files"]),
    }

# Rule 1: fork-only entry must be justified by higher stars than source.
for item in meta.values():
    if not item["fork"]:
        continue
    src_name = item["source_full_name"]
    src_stars = item["source_stars"]
    if not src_name or src_stars is None:
        continue
    if item["stars"] <= src_stars:
        errors.append(
            f"Fork selection rule violation: {item['listed_repo']} ({item['stars']}) "
            f"should be replaced by upstream {src_name} ({src_stars})."
        )

# Rule 2: one repository only per upstream/source lineage.
groups = {}
for item in meta.values():
    groups.setdefault(item["family_id"], []).append(item)

def score(item: dict) -> tuple:
    # Higher stars first; tie -> prefer non-fork.
    return (item["stars"], 1 if not item["fork"] else 0)

for family_items in groups.values():
    if len(family_items) <= 1:
        continue
    winner = sorted(family_items, key=lambda x: (score(x), x["canonical_repo"].lower()), reverse=True)[0]
    listed = ", ".join(sorted(x["listed_repo"] for x in family_items))
    errors.append(
        "Lineage uniqueness violation: only one repo can be listed from the same upstream/source. "
        f"Current: {listed}. Keep: {winner['canonical_repo']}."
    )

if errors:
    for err in errors:
        print(err, file=sys.stderr)
    raise SystemExit("Selection validation failed.")

print(f"Selection validation passed for {len(meta)} repositories.")
PY
