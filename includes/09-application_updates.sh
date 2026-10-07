#!/usr/bin/env bash
set -euo pipefail

invoke_application_updates () {
  echo -e "${CYAN}[Application Updates] Start${NC}"

  au_apt_update_indexes
  au_apt_full_upgrade
  au_snap_refresh_all
  au_flatpak_update_all

  echo -e "${CYAN}[Application Updates] Done${NC}"
}

# ------------------------------------------------------------
# apt: update package indexes
# ------------------------------------------------------------
au_apt_update_indexes () {
  : <<'AI_BLOCK'
EXPLANATION
Refresh Debian/Ubuntu/Mint package indexes from all configured sources.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Print a short "Updating APT indexes..." message.
- Run the Debian-family command to refresh package lists (use apt).
- Use sudo where appropriate and keep output concise.
- On failure, print a brief warning but do not exit the script.
- Print "APT index update complete." when finished.
AI_BLOCK
}

# ------------------------------------------------------------
# apt: full upgrade (non-interactive)
# ------------------------------------------------------------
au_apt_full_upgrade () {
  : <<'AI_BLOCK'
EXPLANATION
Perform a non-interactive full upgrade of packages using apt.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Print "Running APT full upgrade..." before starting.
- Execute the Debian-family full upgrade command non-interactively (accept defaults/assume yes).
- Use sudo; keep output concise.
- If the upgrade fails, print a warning and continue.
- Print "APT full upgrade complete." on success or after handling failure.
AI_BLOCK
}

# ------------------------------------------------------------
# snap: refresh all snaps (if snap is installed)
# ------------------------------------------------------------
au_snap_refresh_all () {
  : <<'AI_BLOCK'
EXPLANATION
Update all installed Snap packages if Snap is available on the system.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Detect snap availability with a command check.
- If not installed, print "Snap not installed; skipping." and return.
- If installed:
  - Print "Refreshing Snap packages..."
  - Refresh all snaps using the standard snap command.
  - Handle failures by printing a warning but do not exit the script.
  - Print "Snap refresh complete." at the end.
AI_BLOCK
}

# ------------------------------------------------------------
# flatpak: update all (if flatpak is installed)
# ------------------------------------------------------------
au_flatpak_update_all () {
  : <<'AI_BLOCK'
EXPLANATION
Update all installed Flatpak applications and runtimes if Flatpak is available.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Detect flatpak availability with a command check.
- If not installed, print "Flatpak not installed; skipping." and return.
- If installed:
  - Print "Updating Flatpak apps/runtimes..."
  - Update all installed Flatpaks non-interactively.
  - Handle failures by printing a warning but do not exit the script.
  - Print "Flatpak update complete." at the end.
AI_BLOCK
}
