#!/usr/bin/env bash
# Validates that every `repo/path/...` reference in the capabilities doc exists on disk.
# Walks up from the script's own directory (via $REPOS_ROOT discovery, below) so it works
# both from the main vdecent-docs checkout and from an isolated worktree under .worktrees/.
set -u
DOC="$(dirname "$0")/V-Decent Infrastructure Capabilities.md"
FAIL=0

# Extract partner-repo references: a leading token that matches one of the repos,
# followed by a relative path, e.g. `vdecent-app-manager/backend/utils/sizing.py`.
REPOS="vdecent-app-manager vdecent-node-manager vdecent-operations-platform vdecent-app-sizing vdecent-codex-skills vdecent-support-skills"

# Walk up from the script's directory until a directory containing all six repos is found.
# The loop stops at "/" without testing it, so a spurious match at the filesystem root that
# would be caught by a plain "( cd .. )" fallback is ruled out.
REPOS_ROOT="$(cd "$(dirname "$0")" || exit 1
while [ "$PWD" != "/" ]; do
  ok=1
  for r in $REPOS; do
    [ -d "$r" ] || { ok=0; break; }
  done
  [ "$ok" -eq 1 ] && break
  cd ..
done
pwd)"
RE="($(echo $REPOS | tr ' ' '|'))/[^ )\`]+"
for ref in $(grep -oE "$RE" "$DOC" | sort -u); do
  repo="${ref%%/*}"
  rel="${ref#*/}"
  if [ ! -e "$REPOS_ROOT/$repo/$rel" ]; then
    echo "MISSING: $ref"
    FAIL=1
  fi
done

if [ "$FAIL" -eq 0 ]; then
  echo "All source references resolve."
fi
exit "$FAIL"