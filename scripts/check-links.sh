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

declare -A url_original=()
declare -A url_files=()
url_regex='\((https://github\.com/[^)[:space:]]+)\)'

for file in "${FILES[@]}"; do
  base="$(basename "$file")"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ $url_regex ]]; then
      url="${BASH_REMATCH[1]}"
      key="$(echo "$url" | tr '[:upper:]' '[:lower:]')"
      url_original["$key"]="$url"
      if [[ -n "${url_files["$key"]:-}" ]]; then
        if [[ ",${url_files["$key"]}," != *",$base,"* ]]; then
          url_files["$key"]+=", $base"
        fi
      else
        url_files["$key"]="$base"
      fi
    fi
  done < "$file"
done

checked=0
failed=0

mapfile -t sorted_keys < <(printf '%s\n' "${!url_original[@]}" | sort)
for key in "${sorted_keys[@]}"; do
  url="${url_original[$key]}"
  checked=$((checked + 1))

  status="$(curl -A "awesome-awesome-link-check" -L -I -o /dev/null -s -w "%{http_code}" --max-redirs 5 --connect-timeout 10 --max-time 20 "$url" || true)"
  ok=0
  if [[ "$status" =~ ^[0-9]{3}$ ]] && (( status >= 200 && status < 400 )); then
    ok=1
  fi

  if [[ "$ok" -eq 0 ]]; then
    status="$(curl -A "awesome-awesome-link-check" -L -o /dev/null -s -w "%{http_code}" --max-redirs 5 --connect-timeout 10 --max-time 20 "$url" || true)"
    if [[ "$status" =~ ^[0-9]{3}$ ]] && (( status >= 200 && status < 400 )); then
      ok=1
    fi
  fi

  if [[ "$ok" -eq 1 ]]; then
    echo "OK   $url"
  else
    echo "FAIL $url (in: ${url_files[$key]})" >&2
    failed=$((failed + 1))
  fi
done

if [[ "$failed" -gt 0 ]]; then
  echo "Link check failed: $failed broken link(s) out of $checked checked." >&2
  exit 1
fi

echo "Link check passed: $checked links checked."
