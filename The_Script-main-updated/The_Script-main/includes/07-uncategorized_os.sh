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
find /home -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null |
while IFS= read -r -d '' dir; do
if sudo chmod 700 "$dir" 2>/dev/null; then
echo "Set permissions to 700: $dir"
else
echo "Warning: Could not chmod 700: $dir"
fi
done
}

# -------------------------------------------------------------------
# /etc/login.defs: 0600 root:root
# -------------------------------------------------------------------
uos_login_defs_permissions () {
sudo chown root:root /etc/login.defs
sudo chmod 0600 /etc/login.defs
echo "Secured /etc/login.defs ownership and permissions."
}

# -------------------------------------------------------------------
# shadow/gshadow and backups: 0640 root:shadow
# -------------------------------------------------------------------
uos_shadow_gshadow_permissions () {
 for file in /etc/shadow /etc/shadow- /etc/gshadow /etc/gshadow-; do
if [[ -e "$file" ]]; then
sudo chown root:shadow "$file"
sudo chmod 0640 "$file"
echo "Secured $file: root:shadow 0640"
fi
done
}

# -------------------------------------------------------------------
# passwd/group and backups: 0644 root:root
# -------------------------------------------------------------------
uos_passwd_group_permissions () {
  for file in /etc/passwd /etc/passwd- /etc/group /etc/group-; do
if [[ -e "$file" ]]; then
sudo chown root:root "$file"
sudo chmod 0644 "$file"
echo "Secured $file: root:root 0644"
fi
done
}

# -------------------------------------------------------------------
# GRUB config: 0600 root:root
# -------------------------------------------------------------------
uos_grub_permissions () {
if [[ -e /boot/grub/grub.cfg ]]; then
sudo chown root:root /boot/grub/grub.cfg
sudo chmod 0600 /boot/grub/grub.cfg
echo "Secured /boot/grub/grub.cfg: root:root 0600"
else
echo "/boot/grub/grub.cfg not found; skipping."
fi
}

# -------------------------------------------------------------------
# System.map (if present): 0600 root:root
# -------------------------------------------------------------------
uos_system_map_permissions () {
  for file in /boot/System.map-*; do
if [[ -f "$file" ]]; then
if sudo chown root:root "$file" 2>/dev/null && sudo chmod 0600 "$file" 2>/dev/null; then
echo "Secured $file: root:root 0600"
else
echo "Warning: Could not secure $file."
fi
fi
done
}

# -------------------------------------------------------------------
# SSH host keys: 0600 (at least RSA & ECDSA)
# -------------------------------------------------------------------
uos_ssh_host_keys_permissions () {
  for file in /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ecdsa_key; do
if [[ -e "$file" ]]; then
sudo chmod 0600 "$file"
echo "Secured $file: 0600"
fi
done
}

# -------------------------------------------------------------------
# Audit rules: remove dangerous bits on /etc/audit/rules.d/*.rules
# -------------------------------------------------------------------
uos_audit_rules_permissions () {
 find /etc/audit/rules.d/ -maxdepth 1 -type f -name '*.rules' -print0 2>/dev/null |
while IFS= read -r -d '' file; do
if sudo chmod u-s,g-ws,o-wrx "$file" 2>/dev/null; then
echo "Normalized permissions: $file"
else
echo "Warning: Could not normalize permissions: $file"
fi
done
}

# -------------------------------------------------------------------
# Remove world-writable files (clear o+w) on local filesystems
# -------------------------------------------------------------------
uos_remove_world_writable_files () {
while IFS= read -r mount; do
find "$mount" -xdev -type f -perm -0002 -print0 2>/dev/null |
while IFS= read -r -d '' file; do
if sudo chmod o-w "$file" 2>/dev/null; then
echo "Removed world-write permission: $file"
else
echo "Warning: Could not remove world-write permission: $file"
fi
done
done < <(df --local -P 2>/dev/null | awk 'NR > 1 {print $6}')
}

# -------------------------------------------------------------------
# Report files without user/group ownership (no destructive fix)
# -------------------------------------------------------------------
uos_report_unowned_files () {
 mkdir -p "$DOCS"

report="$DOCS/unowned_files.txt"
: > "$report"

while IFS= read -r mount; do
find "$mount" -xdev \(-nouser -o -nogroup\) -print 2>/dev/null
done < <(df --local -P 2>/dev/null | awk 'NR > 1 {print $6}') > "$report"

count=$(wc -l < "$report")
echo "Found $count unowned files/directories. Report: $report"
}

# -------------------------------------------------------------------
# Normalize /var/log permissions to 0640 for files
# -------------------------------------------------------------------
uos_var_log_permissions () {
 find /var/log -type f -print0 2>/dev/null |
while IFS= read -r -d '' file; do
if sudo chmod 0640 "$file" 2>/dev/null; then
echo "Set permissions to 0640: $file"
else
echo "Warning: Could not chmod 0640: $file"
fi
done
}

# -------------------------------------------------------------------
# /tmp and /var/tmp: 1777 root:root
# -------------------------------------------------------------------
uos_tmp_permissions () {
for dir in /tmp /var/tmp; do
sudo chown root:root "$dir"
sudo chmod 1777 "$dir"
echo "Secured $dir: root:root 1777"
done
}
