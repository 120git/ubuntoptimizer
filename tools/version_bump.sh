#!/usr/bin/env bash
# Bump project version and tag
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${ROOT_DIR}/VERSION"
DOCS_CONF="${ROOT_DIR}/docs/conf.py"
PUSH=false
PART="patch" # major|minor|patch

usage() {
  echo "Usage: $(basename "$0") [--major|--minor|--patch] [--push]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --major) PART=major; shift ;;
    --minor) PART=minor; shift ;;
    --patch) PART=patch; shift ;;
    --push) PUSH=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

current=$(cat "$VERSION_FILE" 2>/dev/null || echo "0.0.0")
IFS='.' read -r MAJ MIN PAT <<<"$current"
case "$PART" in
  major) MAJ=$((MAJ+1)); MIN=0; PAT=0 ;;
  minor) MIN=$((MIN+1)); PAT=0 ;;
  patch) PAT=$((PAT+1)) ;;
esac
new="${MAJ}.${MIN}.${PAT}"

echo "$new" > "$VERSION_FILE"

# Update docs/conf.py release env usage or write UBOPT_VERSION for build steps
if grep -q "UBOPT_VERSION" "$DOCS_CONF" 2>/dev/null; then
  echo "Docs configured to read UBOPT_VERSION env; no inline version change needed."
fi

# Git commit and tag
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add "$VERSION_FILE"
  git commit -m "chore(release): bump version to $new" || true
  git tag -a "v$new" -m "Release $new" || true
  if [[ "$PUSH" == true ]]; then
    git push --follow-tags || true
  fi
else
  echo "Not in a git repo; skipped commit/tag"
fi

echo "Version bumped: ${current} -> ${new}"
