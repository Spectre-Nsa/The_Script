#!/usr/bin/env bash
set -euo pipefail

invoke_local_policy () {
  echo -e "${CYAN}[Local Policy] Start${NC}"

  lp_sysctl_ipv6_all
  lp_sysctl_ipv6_default
  lp_sysctl_ipv4_all
  lp_sysctl_ipv4_default
  lp_sysctl_ipv4_misc
  lp_sysctl_fs_kernel
  lp_sysctl_persist_and_reload
  lp_secure_sudo

  echo -e "${CYAN}[Local Policy] Done${NC}"
}

# -------------------------------------------------------------------
# IPv6 sysctl (all interfaces)
# -------------------------------------------------------------------
lp_sysctl_ipv6_all () {
  : <<'AI_BLOCK'
EXPLANATION
Set these IPv6 values (applies to all interfaces):
  net.ipv6.conf.all.accept_ra=0
  net.ipv6.conf.all.accept_redirects=0
  net.ipv6.conf.all.accept_source_route=0
  net.ipv6.conf.all.forwarding=0

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Apply the runtime changes with the appropriate sysctl command.
- Print a short confirmation per key.
- Continue on errors; do not abort the script if one key fails.
AI_BLOCK
}

# -------------------------------------------------------------------
# IPv6 sysctl (default interface template)
# -------------------------------------------------------------------
lp_sysctl_ipv6_default () {
  : <<'AI_BLOCK'
EXPLANATION
Set these IPv6 default-interface values:
  net.ipv6.conf.default.accept_ra=0
  net.ipv6.conf.default.accept_redirects=0
  net.ipv6.conf.default.accept_source_route=0

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Apply the runtime changes with sysctl.
- Print a short confirmation per key.
- Continue on errors.
AI_BLOCK
}

# -------------------------------------------------------------------
# IPv4 sysctl (all interfaces)
# -------------------------------------------------------------------
lp_sysctl_ipv4_all () {
  : <<'AI_BLOCK'
EXPLANATION
Set these IPv4 values (all interfaces):
  net.ipv4.conf.all.accept_redirects=0
  net.ipv4.conf.all.accept_source_route=0
  net.ipv4.conf.all.log_martians=1
  net.ipv4.conf.all.rp_filter=1
  net.ipv4.conf.all.secure_redirects=0
  net.ipv4.conf.all.send_redirects=0

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Apply runtime changes with sysctl.
- Print a short confirmation per key.
- Continue on errors.
AI_BLOCK
}

# -------------------------------------------------------------------
# IPv4 sysctl (default interface template)
# -------------------------------------------------------------------
lp_sysctl_ipv4_default () {
  : <<'AI_BLOCK'
EXPLANATION
Set these IPv4 default-interface values:
  net.ipv4.conf.default.accept_redirects=0
  net.ipv4.conf.default.accept_source_route=0
  net.ipv4.conf.default.log_martians=1
  net.ipv4.conf.default.rp_filter=1
  net.ipv4.conf.default.secure_redirects=0
  net.ipv4.conf.default.send_redirects=0

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Apply runtime changes with sysctl.
- Print a short confirmation per key.
- Continue on errors.
AI_BLOCK
}

# -------------------------------------------------------------------
# IPv4 misc (ICMP, TCP, forwarding)
# -------------------------------------------------------------------
lp_sysctl_ipv4_misc () {
  : <<'AI_BLOCK'
EXPLANATION
Set these additional IPv4 values:
  net.ipv4.icmp_echo_ignore_broadcasts=1
  net.ipv4.icmp_ignore_bogus_error_responses=1
  net.ipv4.tcp_syncookies=1
  net.ipv4.ip_forward=0

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Apply runtime changes with sysctl.
- Print a short confirmation per key.
- Continue on errors.
AI_BLOCK
}

# -------------------------------------------------------------------
# Filesystem & kernel hardening
# -------------------------------------------------------------------
lp_sysctl_fs_kernel () {
  : <<'AI_BLOCK'
EXPLANATION
Set these filesystem/kernel hardening values:
  fs.protected_hardlinks=1
  fs.protected_symlinks=1
  fs.suid_dumpable=0
  kernel.randomize_va_space=2

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Apply runtime changes with sysctl.
- Print a short confirmation per key.
- Continue on errors.
AI_BLOCK
}

# -------------------------------------------------------------------
# Persist sysctl settings and reload
# -------------------------------------------------------------------
lp_sysctl_persist_and_reload () {
  : <<'AI_BLOCK'
EXPLANATION
Persist all the above sysctl settings and reload them immediately.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Write all earlier keys and values into a single file under /etc/sysctl.d/, e.g., /etc/sysctl.d/99-hardening.conf.
- Create a timestamped backup if that file already exists.
- Ensure each key=value appears exactly once (idempotent write).
- Reload settings with sysctl so they take effect without reboot (e.g., sysctl --system).
- Print a summary of the file written and reload status.
AI_BLOCK
}

# -------------------------------------------------------------------
# Secure sudo (dangerous if misused; stub only)
# -------------------------------------------------------------------
lp_secure_sudo () {
  : <<'AI_BLOCK'
EXPLANATION
Harden sudo configuration by clearing drop-ins and reinstalling sudo (Debian/Ubuntu/Mint).
This is destructive; students should understand risks and test in a VM.

AI_PROMPT
Return only Bash code (no markdown, no prose).
Requirements:
- Remove all files under /etc/sudoers.d/ (do not delete /etc/sudoers).
- Purge the sudo package non-interactively.
- Install sudo again non-interactively.
- Print confirmation lines for each step.
- Continue on errors with a warning, but attempt subsequent steps.
AI_BLOCK
}
