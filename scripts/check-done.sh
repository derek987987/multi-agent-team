#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATION="$ROOT/.agents/validation-report.md"
REVIEW="$ROOT/.agents/review-report.md"
SECURITY="$ROOT/.agents/security-report.md"

printf "== Definition Of Done Check ==\n\n"

missing=0

for file in "$VALIDATION" "$REVIEW" "$SECURITY"; do
  if [ ! -f "$file" ]; then
    printf "Missing: %s\n" "${file#$ROOT/}"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  exit 1
fi

status=0

if awk '
  function check() {
    if (open && (sev == "critical" || sev == "major")) bad = 1
  }
  /^### / { check(); sev = ""; open = 0; next }
  /^Severity: / { sev = tolower($2); next }
  /^Status: open$/ { open = 1; next }
  END { check(); exit bad ? 1 : 0 }
' "$VALIDATION" "$SECURITY"; then
  :
else
  printf "Unresolved critical/major validation or security finding exists.\n"
  status=1
fi

if grep -qiE "Recommendation: block|^Status: open$" "$REVIEW"; then
  printf "Review may contain blocking findings. Inspect .agents/review-report.md.\n"
  status=1
fi

printf "\nDone check is advisory. Confirm every item in .agents/definition-of-done.md before marking task done.\n"
exit "$status"
