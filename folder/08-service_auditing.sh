#!/usr/bin/env bash
set -euo pipefail

invoke_service_auditing () {
  echo -e "${CYAN}[Service Auditing] Start${NC}"

  sa_purge_unwanted_services

  echo -e "${CYAN}[Service Auditing] Done${NC}"
}

# -------------------------------------------------------------------
# Interactively purge unwanted packages listed in $UNWANTED
# -------------------------------------------------------------------
sa_purge_unwanted_services () {
  : <<'AI_BLOCK'
EXPLANATION
Iterate over each package name in $UNWANTED. If the package is installed, ask:
"Is the service <name> a critical service? (Y/n) "  Default = Y on empty input.
If the answer is 'n' or 'N', attempt to purge the package (and related names with a suffix wildcard).
If purge fails due to dpkg issues, run "dpkg --configure -a" once, then retry purge.
If not installed, print a skip message.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Read $UNWANTED from the environment; if empty or unset, print "No unwanted services configured." and return.
- For each package name:
  - Detect installation status using a Debian-family approach (e.g., dpkg-query or dpkg -l).
  - If installed:
    - Prompt exactly: "Is the service <pkg> a critical service? (Y/n) "
    - Read input; default to Y on empty.
    - If 'n' or 'N':
      - Print "Purging <pkg>..."
      - Purge with apt in non-interactive mode (quiet acceptable).
      - On purge failure:
        - Print a brief error.
        - Run "sudo dpkg --configure -a".
        - Retry the purge once; print success or final failure.
    - Else (Y or other): print "<pkg> kept."
  - If not installed: print "<pkg> not installed. Skipping..."
- Use sudo for system-changing commands.
- Continue on errors for individual packages; do not abort the loop.
AI_BLOCK
}
