#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATEGORY_DIR="$ROOT/categories"

if [[ ! -d "$CATEGORY_DIR" ]]; then
  echo "Missing categories directory: $CATEGORY_DIR" >&2
  exit 1
fi

mapfile -t FILES < <(find "$CATEGORY_DIR" -maxdepth 1 -type f -name "*.md" ! -name "*.zh-CN.md" | sort)
if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "No category markdown files found in $CATEGORY_DIR" >&2
  exit 1
fi

has_error=0
declare -A url_count=()
declare -A url_items=()

entry_regex='^-[[:space:]]\[(.+)\]\((https://github\.com/[^)]+)\)[[:space:]]-[[:space:]](.+)$'

for file in "${FILES[@]}"; do
  base="$(basename "$file")"
  entries=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "- "* ]]; then
      if [[ ! "$line" =~ $entry_regex ]]; then
        echo "Format error in $base: $line" >&2
        has_error=1
        continue
      fi

      repo="${BASH_REMATCH[1]}"
      url="${BASH_REMATCH[2]}"
      repo_name="${repo#*/}"

      shopt -s nocasematch
      if [[ -z "$repo_name" || ! "$repo_name" =~ ^awesome ]]; then
        echo "Naming error in $base: repository name must start with 'awesome' => $repo" >&2
        has_error=1
        shopt -u nocasematch
        continue
      fi
      shopt -u nocasematch

      entries+=("$repo")

      key="$(echo "$url" | tr '[:upper:]' '[:lower:]')"
      url_count["$key"]=$(( ${url_count["$key"]:-0} + 1 ))
      if [[ -n "${url_items["$key"]:-}" ]]; then
        url_items["$key"]+=", $repo in $base"
      else
        url_items["$key"]="$repo in $base"
      fi
    fi
  done < "$file"

  if [[ "${#entries[@]}" -gt 1 ]]; then
    mapfile -t sorted_entries < <(printf '%s\n' "${entries[@]}" | sort -f)
    for i in "${!entries[@]}"; do
      if [[ "${entries[$i]}" != "${sorted_entries[$i]}" ]]; then
        echo "Sort error in $base: entries must be alphabetical by owner/repo" >&2
        has_error=1
        break
      fi
    done
  fi
done

for key in "${!url_count[@]}"; do
  if [[ "${url_count[$key]}" -gt 1 ]]; then
    echo "Duplicate link: $key => ${url_items[$key]}" >&2
    has_error=1
  fi
done

if [[ "$has_error" -ne 0 ]]; then
  echo "Validation failed." >&2
  exit 1
fi

echo "Validation passed for ${#FILES[@]} category files."
