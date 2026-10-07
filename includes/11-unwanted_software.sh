#!/usr/bin/env bash
set -euo pipefail

invoke_unwanted_software () {
  echo -e "${CYAN}[Unwanted Software] Start${NC}"

  us_purge_unwanted_software

  echo -e "${CYAN}[Unwanted Software] Done${NC}"
}

# -------------------------------------------------------------------
# Purge unwanted software listed in $UNWANTED_SOFTWARE, then autoremove
# -------------------------------------------------------------------
us_purge_unwanted_software () {
  : <<'AI_BLOCK'
EXPLANATION
Remove unwanted packages defined in $UNWANTED_SOFTWARE, then run apt autoremove.
$UNWANTED_SOFTWARE is provided by config.sh (as a space-separated list or array).

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Read $UNWANTED_SOFTWARE. If empty/unset, print "No unwanted software configured." and return.
- Iterate each package name safely (support either: a space-separated string or a Bash array).
- For each name:
  - Print "Purging unwanted package: <name>..."
  - Purge using apt in non-interactive mode, accepting that the actual installed package may have suffixes; match with a trailing wildcard.
  - Suppress noisy output, but still handle failures.
  - On purge failure:
    - Print a brief warning.
    - Run "sudo dpkg --configure -a".
    - Retry the purge once; print success or final failure.
  - Continue to the next name regardless of errors.
- After the loop, run "sudo apt autoremove -y" quietly and print "Autoremove complete."
- Use sudo for all package-management commands.
AI_BLOCK
}
