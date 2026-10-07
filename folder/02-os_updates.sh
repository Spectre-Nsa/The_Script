#!/usr/bin/env bash
set -euo pipefail

invoke_os_updates () {
  echo -e "${CYAN}[OS Updates] Start${NC}"

  osu_update_sources_for_distro
  osu_apt_update
  osu_fix_broken_packages
  osu_unhold_packages

  echo -e "${CYAN}[OS Updates] Done${NC}"
}

# ------------------------------------------------------------
# Update APT sources based on distro/codename (Debian family)
# ------------------------------------------------------------
osu_update_sources_for_distro () {
  : <<'AI_BLOCK'
EXPLANATION
Refresh APT sources based on distro:
- Ubuntu: overwrite /etc/apt/sources.list using $CODENAME (from config.sh) with main, universe, multiverse, -updates, -security, -backports.
- Linux Mint: write the official list to /etc/apt/sources.list.d/official-package-repositories.list using Mint codename and the underlying Ubuntu codename (read UBUNTU_CODENAME from /etc/os-release).
- Debian: skip with a friendly message (do not change sources).
Back up any file you overwrite (e.g., .bak). Use sudo where needed.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Read $DISTRO and $CODENAME from the environment (already exported by config.sh).
- For Ubuntu:
  - Create a backup of /etc/apt/sources.list if it exists.
  - Overwrite /etc/apt/sources.list with four lines that use $CODENAME and include main, universe, multiverse for base, -updates, -security, -backports.
  - Use a safe method for writing with sudo (e.g., tee).
- For Linux Mint:
  - Source /etc/os-release and read UBUNTU_CODENAME.
  - Create a backup of /etc/apt/sources.list.d/official-package-repositories.list if it exists.
  - Overwrite that file with the standard Mint line using the Mint codename, plus the five Ubuntu lines using $UBUNTU_CODENAME (base, -updates, -backports, -security) similar to Ubuntu above.
- For Debian:
  - Print a message like "Debian detected; leaving sources as-is." and do nothing.
- Print a brief confirmation of what was changed or skipped.
AI_BLOCK
}

# ------------------------------------------------------------
# apt update
# ------------------------------------------------------------
osu_apt_update () {
  : <<'AI_BLOCK'
EXPLANATION
Update package indexes from all configured sources.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Run the Debian-family command to refresh package lists (apt).
- Show a short status message before/after.
- Non-interactive is fine; do not upgrade here.
AI_BLOCK
}

# ------------------------------------------------------------
# apt --fix-broken install
# ------------------------------------------------------------
osu_fix_broken_packages () {
  : <<'AI_BLOCK'
EXPLANATION
Attempt to fix broken package dependencies.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Run the Debian-family command to fix broken packages.
- Use a non-interactive approach suitable for scripts.
- Print a short status line on completion.
AI_BLOCK
}

# ------------------------------------------------------------
# apt-mark: unhold all currently held packages
# ------------------------------------------------------------
osu_unhold_packages () {
  : <<'AI_BLOCK'
EXPLANATION
Unhold every package currently marked as "hold" on Debian/Ubuntu/Mint. Do not rely on a predefined list.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Query the list of held packages using the appropriate apt-mark command.
- If none are held, print: "No held packages found." and return.
- Iterate over each held package name safely (handle spaces/newlines robustly).
- For each package:
  - Unhold it via the apt-mark command (use sudo where appropriate).
  - Print a confirmation line: "Unheld: <package>".
- Use non-interactive behavior; if unholding one package fails, continue with the rest and print a short warning.
AI_BLOCK
}

