#!/bin/bash
set -e


# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Determine correct repository version based on OS image
OS_VER="15.6"
# shellcheck disable=SC2154
if [ "${image}" = "sle-micro-55" ]; then
  OS_VER="15.5"
fi

# Add repositories and install packages in the next snapshot using transactional-update
transactional-update --non-interactive --continue shell <<EOF
zypper --gpg-auto-import-keys --non-interactive ar -f https://download.opensuse.org/distribution/leap/$OS_VER/repo/oss/ repo-oss || true
zypper --gpg-auto-import-keys --non-interactive ar -f https://download.opensuse.org/distribution/leap/$OS_VER/repo/non-oss/ repo-non-oss || true
zypper --gpg-auto-import-keys --non-interactive ar -f https://download.opensuse.org/repositories/security:/SELinux_legacy/$OS_VER/security:SELinux_legacy.repo || true
rpm --import https://rpm.rancher.io/public.key || true
zypper --gpg-auto-import-keys --non-interactive refresh
zypper --gpg-auto-import-keys --non-interactive install -y --force-resolution restorecond policycoreutils curl
EOF

# Enable IP forwarding for Kubernetes/RKE2 routing
cat <<'EOF' > /etc/sysctl.d/90-rke2-forwarding.conf
net.ipv4.ip_forward = 1
EOF

# shellcheck disable=SC2154
if [ "${ip_family}" = "ipv4" ]; then
  cat <<'EOF' >> /etc/sysctl.d/90-rke2-forwarding.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
  # Remove IPv6 localhost entry to prevent health probes from hitting ::1
  sed -i '/^::1/d' /etc/hosts
fi

# Conditionally enable IPv6 and forwarding if requested
# shellcheck disable=SC2154
if [ "${ip_family}" = "ipv6" ] || [ "${ip_family}" = "dualstack" ]; then
  cat <<'EOF' >> /etc/sysctl.d/90-rke2-forwarding.conf
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.forwarding = 1
EOF
fi

sysctl --system

echo "Rebooting in 2 seconds..."
# reboot in 2 seconds and exit this script
# this allows us to reboot without Terraform receiving errors
# WARNING: there is a race condition here, the reboot must happen before Terraform reconnects for the next script
( sleep 2 ; reboot ) &
exit 0
