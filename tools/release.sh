#!/usr/bin/env bash
set -Eeuo pipefail

# Usage: tools/release.sh vX.Y.Z
# - Updates VERSION
# - Generates CHANGELOG.md entry from Conventional Commits since last tag
# - Creates git tag and pushes

VERSION_TAG="$1"
if [[ -z "$VERSION_TAG" ]]; then
  echo "Usage: $0 vX.Y.Z" >&2; exit 2
fi
VERSION="${VERSION_TAG#v}"

echo "${VERSION}" > VERSION

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [[ -n "$LAST_TAG" ]]; then
  RANGE="${LAST_TAG}..HEAD"
else
  RANGE=""
fi

# Generate changelog section
DATE=$(date -u +%Y-%m-%d)
{
  echo "## ${VERSION_TAG} - ${DATE}"
  echo ""
  git log --pretty=format:'- %s (%h)' ${RANGE}
  echo ""
} | sed 's/^$/\n/' > .CHANGELOG.new

# Prepend to CHANGELOG.md
if [[ -f CHANGELOG.md ]]; then
  { cat .CHANGELOG.new; echo; cat CHANGELOG.md; } > .CHANGELOG.tmp && mv .CHANGELOG.tmp CHANGELOG.md
else
  mv .CHANGELOG.new CHANGELOG.md
fi
rm -f .CHANGELOG.new

git add VERSION CHANGELOG.md
git commit -m "chore(release): ${VERSION_TAG}"
git tag -a "${VERSION_TAG}" -m "Release ${VERSION_TAG}"
git push --follow-tags
