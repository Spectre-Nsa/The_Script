#!/usr/bin/env bash
set -euo pipefail

invoke_uncategorized_os () {
  echo -e "${CYAN}[Uncategorized OS] Start${NC}"

  uos_home_dir_permissions
  uos_login_defs_permissions
  uos_shadow_gshadow_permissions
  uos_passwd_group_permissions
  uos_grub_permissions
  uos_system_map_permissions
  uos_ssh_host_keys_permissions
  uos_audit_rules_permissions
  uos_remove_world_writable_files
  uos_report_unowned_files
  uos_var_log_permissions
  uos_tmp_permissions

  # (Any additional one-offs can be added above)
  echo -e "${CYAN}[Uncategorized OS] Done${NC}"
}

# -------------------------------------------------------------------
# Home directories: 0700 perms
# -------------------------------------------------------------------
uos_home_dir_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Set each first-level directory under /home to mode 0700.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Find directories at depth 1 under /home.
- For each, chmod 700; print a short confirmation per directory.
- Continue on errors; do not abort the loop.
AI_BLOCK
}

# -------------------------------------------------------------------
# /etc/login.defs: 0600 root:root
# -------------------------------------------------------------------
uos_login_defs_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Ensure /etc/login.defs ownership and permissions are strict.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- chown root:root /etc/login.defs
- chmod 0600 /etc/login.defs
- Print a concise confirmation.
AI_BLOCK
}

# -------------------------------------------------------------------
# shadow/gshadow and backups: 0640 root:shadow
# -------------------------------------------------------------------
uos_shadow_gshadow_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Set ownership/permissions on sensitive account DB files and their backups:
  /etc/shadow     -> root:shadow 0640
  /etc/shadow-    -> root:shadow 0640
  /etc/gshadow    -> root:shadow 0640
  /etc/gshadow-   -> root:shadow 0640

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- For each listed file that exists:
  - chown root:shadow
  - chmod 0640
  - Print a confirmation per file; skip cleanly if missing.
AI_BLOCK
}

# -------------------------------------------------------------------
# passwd/group and backups: 0644 root:root
# -------------------------------------------------------------------
uos_passwd_group_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Set ownership/permissions on:
  /etc/passwd   -> root:root 0644
  /etc/passwd-  -> root:root 0644
  /etc/group    -> root:root 0644
  /etc/group-   -> root:root 0644

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- For each existing file above:
  - chown root:root
  - chmod 0644
  - Print a confirmation per file; skip missing files without error.
AI_BLOCK
}

# -------------------------------------------------------------------
# GRUB config: 0600 root:root
# -------------------------------------------------------------------
uos_grub_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Lock down /boot/grub/grub.cfg.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- If /boot/grub/grub.cfg exists:
  - chown root:root
  - chmod 0600
  - Print a confirmation.
- If missing, print a brief note and continue.
AI_BLOCK
}

# -------------------------------------------------------------------
# System.map (if present): 0600 root:root
# -------------------------------------------------------------------
uos_system_map_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Restrict any /boot/System.map-* files so only root can read/write.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- For each path matching /boot/System.map-* that exists and is a regular file:
  - chown root:root
  - chmod 0600
  - Print a confirmation per file.
- Continue on errors for individual files.
AI_BLOCK
}

# -------------------------------------------------------------------
# SSH host keys: 0600 (at least RSA & ECDSA)
# -------------------------------------------------------------------
uos_ssh_host_keys_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Ensure SSH host private keys are not world/group-readable. At minimum:
  /etc/ssh/ssh_host_rsa_key
  /etc/ssh/ssh_host_ecdsa_key

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- For each listed file that exists:
  - chmod 0600
  - Print a confirmation per file; skip missing without error.
AI_BLOCK
}

# -------------------------------------------------------------------
# Audit rules: remove dangerous bits on /etc/audit/rules.d/*.rules
# -------------------------------------------------------------------
uos_audit_rules_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Normalize permissions on files under /etc/audit/rules.d/ ending with .rules:
- Remove setuid/setgid/sticky and group/world write/execute where present.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Find regular files in /etc/audit/rules.d/ with names ending in .rules (maxdepth 1).
- For each, strip u+s, g+ws, o+wrx (i.e., ensure tight perms) using chmod.
- Print a confirmation per file; continue on errors.
AI_BLOCK
}

# -------------------------------------------------------------------
# Remove world-writable files (clear o+w) on local filesystems
# -------------------------------------------------------------------
uos_remove_world_writable_files () {
  : <<'AI_BLOCK'
EXPLANATION
Find world-writable regular files on local filesystems and remove the world-write bit.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Enumerate local mount points (df --local -P) and scan each with find.
- Match regular files with world-write permission.
- For each match, chmod o-w; print a confirmation per file.
- Continue on errors; avoid descending into other filesystems (-xdev).
AI_BLOCK
}

# -------------------------------------------------------------------
# Report files without user/group ownership (no destructive fix)
# -------------------------------------------------------------------
uos_report_unowned_files () {
  : <<'AI_BLOCK'
EXPLANATION
Detect files that have no valid user or group ownership on local filesystems and write a report to $DOCS.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Ensure $DOCS exists (create if needed).
- For each local mount (df --local -P):
  - List paths with -nouser or -nogroup using find -xdev.
- Write results to $DOCS/unowned_files.txt (overwrite).
- Print the number of findings and the report path.
AI_BLOCK
}

# -------------------------------------------------------------------
# Normalize /var/log permissions to 0640 for files
# -------------------------------------------------------------------
uos_var_log_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Set permissions of regular files under /var/log to 0640.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Traverse /var/log (recursive).
- For each regular file, chmod 0640.
- Continue on errors; print a brief summary or per-file confirmations.
AI_BLOCK
}

# -------------------------------------------------------------------
# /tmp and /var/tmp: 1777 root:root
# -------------------------------------------------------------------
uos_tmp_permissions () {
  : <<'AI_BLOCK'
EXPLANATION
Ensure /tmp and /var/tmp are sticky world-writable directories owned by root (1777 root:root).

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- For /tmp and /var/tmp:
  - chown root:root
  - chmod 1777
  - Print a confirmation per directory.
AI_BLOCK
}
