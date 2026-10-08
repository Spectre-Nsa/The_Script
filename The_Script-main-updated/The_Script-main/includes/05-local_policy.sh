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
for key in \
    net.ipv6.conf.all.accept_ra \
    net.ipv6.conf.all.accept_redirects \
    net.ipv6.conf.all.accept_source_route \
    net.ipv6.conf.all.forwarding; do
if sudo sysctl -w "$key=0" >/dev/null 2>&1; then
echo "Set $key=0"
else
echo "Warning: Could not set $key=0"
fi
done
}

# -------------------------------------------------------------------
# IPv6 sysctl (default interface template)
# -------------------------------------------------------------------
lp_sysctl_ipv6_default () {
 for key in \
    net.ipv6.conf.default.accept_ra \
    net.ipv6.conf.default.accept_redirects \
    net.ipv6.conf.default.accept_source_route; do
if sudo sysctl -w "$key=0" >/dev/null 2>&1; then
echo "Set $key=0"
else
echo "Warning: Could not set $key=0"
fi
done
}

# -------------------------------------------------------------------
# IPv4 sysctl (all interfaces)
# -------------------------------------------------------------------
lp_sysctl_ipv4_all () {
for key in \
    net.ipv4.conf.all.accept_redirects \
    net.ipv4.conf.all.accept_source_route \
    net.ipv4.conf.all.log_martians \
    net.ipv4.conf.all.rp_filter \
    net.ipv4.conf.all.secure_redirects \
    net.ipv4.conf.all.send_redirects; do
value=0
[[ "$key" == "net.ipv4.conf.all.log_martians" || "$key" == "net.ipv4.conf.all.rp_filter" ]] && value=1

if sudo sysctl -w "$key=$value" >/dev/null 2>&1; then
    echo "Set $key=$value"
else
    echo "Warning: Could not set $key=$value"
fi

done
}

# -------------------------------------------------------------------
# IPv4 sysctl (default interface template)
# -------------------------------------------------------------------
lp_sysctl_ipv4_default () {
 for key in \
    net.ipv4.conf.default.accept_redirects \
    net.ipv4.conf.default.accept_source_route \
    net.ipv4.conf.default.log_martians \
    net.ipv4.conf.default.rp_filter \
    net.ipv4.conf.default.secure_redirects \
    net.ipv4.conf.default.send_redirects; do
value=0
[[ "$key" == "net.ipv4.conf.default.log_martians" || "$key" == "net.ipv4.conf.default.rp_filter" ]] && value=1

if sudo sysctl -w "$key=$value" >/dev/null 2>&1; then
    echo "Set $key=$value"
else
    echo "Warning: Could not set $key=$value"
fi

done
}

# -------------------------------------------------------------------
# IPv4 misc (ICMP, TCP, forwarding)
# -------------------------------------------------------------------
lp_sysctl_ipv4_misc () {
for key in \
    net.ipv4.icmp_echo_ignore_broadcasts \
    net.ipv4.icmp_ignore_bogus_error_responses \
    net.ipv4.tcp_syncookies \
    net.ipv4.ip_forward; do
if sudo sysctl -w "$key=1" >/dev/null 2>&1; then
echo "Set $key=1"
else
echo "Warning: Could not set $key=1"
fi
done

sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1 &&
echo "Set net.ipv4.ip_forward=0" ||
echo "Warning: Could not set net.ipv4.ip_forward=0"
}

# -------------------------------------------------------------------
# Filesystem & kernel hardening
# -------------------------------------------------------------------
lp_sysctl_fs_kernel () {
for key in \
    fs.protected_hardlinks \
    fs.protected_symlinks \
    fs.suid_dumpable \
    kernel.randomize_va_space; do
case "$key" in
fs.protected_hardlinks|fs.protected_symlinks) value=1 ;;
fs.suid_dumpable) value=0 ;;
kernel.randomize_va_space) value=2 ;;
esac

if sudo sysctl -w "$key=$value" >/dev/null 2>&1; then
    echo "Set $key=$value"
else
    echo "Warning: Could not set $key=$value"
fi

done
}

# -------------------------------------------------------------------
# Persist sysctl settings and reload
# -------------------------------------------------------------------
lp_sysctl_persist_and_reload () {
config="/etc/sysctl.d/99-hardening.conf"
timestamp=$(date +%Y%m%d_%H%M%S)

if [[ -f "$config" ]]; then
sudo cp -a "$config" "${config}.${timestamp}.bak"
fi

tmp=$(mktemp)

cat > "$tmp" <<'EOF'
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.all.forwarding=0
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.default.accept_source_route=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.default.log_martians=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.tcp_syncookies=1
net.ipv4.ip_forward=0
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.suid_dumpable=0
kernel.randomize_va_space=2
EOF

sudo install -m 0644 "$tmp" "$config"
rm -f "$tmp"

echo "Wrote sysctl hardening settings to $config."

if sudo sysctl --system >/dev/null 2>&1; then
echo "Sysctl settings reloaded successfully."
else
echo "Warning: Sysctl reload encountered an error."
fi
}

# -------------------------------------------------------------------
# Secure sudo (dangerous if misused; stub only)
# -------------------------------------------------------------------
lp_secure_sudo () {
  find /etc/sudoers.d/ -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null || true
  echo "Cleared files under /etc/sudoers.d/."

  if DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq sudo >/dev/null 2>&1; then
    echo "Sudo package purged."
  else
    echo "Warning: Failed to purge sudo."
  fi

  if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sudo >/dev/null 2>&1; then
    echo "Sudo package reinstalled successfully."
  else
    echo "Warning: Failed to reinstall sudo."
  fi
}
