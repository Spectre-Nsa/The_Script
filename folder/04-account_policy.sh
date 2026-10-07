#!/usr/bin/env bash
set -euo pipefail

invoke_account_policy () {
  echo -e "${CYAN}[Account Policy] Start${NC}"

  ap_secure_login_defs
  ap_pam_pwquality_inline
  ap_pwquality_conf_file
  ap_lockout_faillock

  echo -e "${CYAN}[Account Policy] Done${NC}"
}

# -------------------------------------------------------------------
# /etc/login.defs hardening
# -------------------------------------------------------------------
ap_secure_login_defs () {
  : <<'AI_BLOCK'
EXPLANATION
Harden /etc/login.defs with these exact values:
  PASS_MAX_DAYS 60
  PASS_MIN_DAYS 10
  PASS_WARN_AGE 14
  UMASK 077

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Create a timestamped backup of /etc/login.defs before editing.
- Ensure the four directives exist with the specified values:
  - If commented or present with different values, update them.
  - If missing, append them.
- Preserve other content/spacing as much as reasonable.
- Print a short confirmation for each directive set.
AI_BLOCK
}

# -------------------------------------------------------------------
# Insert pam_pwquality inline in common-password
# -------------------------------------------------------------------
ap_pam_pwquality_inline () {
  : <<'AI_BLOCK'
EXPLANATION
Insert a pwquality rule into /etc/pam.d/common-password before the pam_unix.so line.

Desired line (single line, exact options/order):
  password requisite pam_pwquality.so retry=3 minlen=10 difok=5 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Target file: /etc/pam.d/common-password.
- Create a timestamped backup before editing.
- If an equal pwquality line already exists, do nothing.
- Otherwise insert the exact line immediately before the first occurrence of pam_unix.so in that file.
- Ensure the edit is idempotent (running again won’t duplicate).
- Print a brief confirmation when the line is in place.
AI_BLOCK
}

# -------------------------------------------------------------------
# Configure /etc/security/pwquality.conf
# -------------------------------------------------------------------
ap_pwquality_conf_file () {
  : <<'AI_BLOCK'
EXPLANATION
Configure /etc/security/pwquality.conf with these exact settings:
  minlen = 10
  minclass = 2
  maxrepeat = 2
  maxclassrepeat = 6
  lcredit = -1
  ucredit = -1
  dcredit = -1
  ocredit = -1
  maxsequence = 2
  difok = 5
  gecoscheck = 1

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Target file: /etc/security/pwquality.conf.
- Create a timestamped backup before editing.
- For each key above:
  - If present (commented or uncommented), set it to the exact value.
  - If missing, append "key = value" on its own line.
- Keep changes idempotent.
- Print a short confirmation after applying settings.
AI_BLOCK
}

# -------------------------------------------------------------------
# Configure pam_faillock in common-auth/common-account
# -------------------------------------------------------------------
ap_lockout_faillock () {
  : <<'AI_BLOCK'
EXPLANATION
Configure account lockout using pam_faillock on Debian/Ubuntu/Mint.

Required lines (exact spacing not critical, order matters):
  In /etc/pam.d/common-auth (around pam_unix.so):
    auth        required      pam_faillock.so preauth
    auth        [default=die] pam_faillock.so authfail
    auth        sufficient    pam_faillock.so authsucc
  In /etc/pam.d/common-account:
    account     required      pam_faillock.so

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Create timestamped backups of both files before editing.
- In /etc/pam.d/common-auth:
  - Ensure the three auth lines exist exactly once each.
  - Place the preauth line before pam_unix.so; ensure authfail follows appropriately; ensure authsucc is present.
- In /etc/pam.d/common-account:
  - Ensure the account line exists exactly once.
- Keep the edit idempotent (no duplicates on subsequent runs).
- Print simple confirmations indicating which lines were added or already present.
AI_BLOCK
}
