#!/bin/bash
set -e

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

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
exit 0
