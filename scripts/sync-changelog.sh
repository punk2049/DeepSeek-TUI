#!/usr/bin/env sh
# Regenerate crates/tui/CHANGELOG.md from the workspace root CHANGELOG.md.
# The /change command embeds this file into the binary via include_str!, so
# it deliberately keeps only the most recent release sections.
#
# Usage: scripts/sync-changelog.sh [sections-to-keep]   (default: 15)
set -eu
KEEP="${1:-15}"
root="$(cd "$(dirname "$0")/.." && pwd)"
awk -v keep="$KEEP" '
  /^\[/ && /\]: http/ { exit }
  /^## \[/ { count++ }
  count > keep { exit }
  { print }
' "$root/CHANGELOG.md" > "$root/crates/tui/CHANGELOG.md"
printf '%s\n' \
  '---' \
  '' \
  'Older releases: [CHANGELOG.md](https://github.com/Hmbown/CodeWhale/blob/main/CHANGELOG.md) and [docs/CHANGELOG_ARCHIVE.md](https://github.com/Hmbown/CodeWhale/blob/main/docs/CHANGELOG_ARCHIVE.md).' \
  >> "$root/crates/tui/CHANGELOG.md"
echo "wrote crates/tui/CHANGELOG.md ($(wc -l < "$root/crates/tui/CHANGELOG.md") lines, $KEEP sections kept)"
