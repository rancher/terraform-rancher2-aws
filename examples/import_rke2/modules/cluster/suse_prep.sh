#!/bin/sh
set -e
set -x

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi
# shellcheck disable=SC2154
if [ "rpm" = "${install_method}" ]; then
  wget https://download.opensuse.org/distribution/leap/15.6/repo/oss/repodata/repomd.xml.key || true
  rpm --import repomd.xml.key || true
  zypper ar -f https://download.opensuse.org/distribution/leap/15.6/repo/oss/ leap-oss || true
  zypper install -y curl

  rpm --import https://download.opensuse.org/repositories/security:/SELinux_legacy/15.5/repodata/repomd.xml.key || true
  zypper ar -f https://download.opensuse.org/repositories/security:/SELinux_legacy/15.5/security:SELinux_legacy.repo || true
  rpm --import https://rpm.rancher.io/public.key || true
fi
# shellcheck disable=SC2154
if [ "ipv6" = "${ip_family}" ]; then
  IPV6="$(ip -6 a show eth0 | grep inet6 | head -n1 | awk '{ print $2 }' | awk -F/ '{ print $1 }')"
  IPV6_GW="$(echo "$IPV6" | awk -F: '{gw=$1":"$2":"$3":"$4"::1"; print gw}')"

  cat > /etc/sysconfig/network/ifcfg-eth0 << EOT
STARTMODE='auto'
BOOTPROTO='static'
IPADDR="$IPV6"
PREFIXLEN='64'
DHCLIENT6_MODE='info'
EOT

  [ ! -f /etc/sysconfig/network/routes ] && touch /etc/sysconfig/network/routes
  echo "default $IPV6_GW - -" >> /etc/sysconfig/network/routes

  CONFIG_FILE="/etc/sysconfig/network/config"
  IPV6_DNS1="2001:4860:4860::8888"
  IPV6_DNS2="2606:4700:4700::1111"


  sed -i "s|^NETCONFIG_DNS_STATIC_SERVERS=.*|NETCONFIG_DNS_STATIC_SERVERS=\"$IPV6_DNS1 $IPV6_DNS2\"|" "$CONFIG_FILE"
  sed -i "s|^NETWORKMANAGER_DISABLE_IPV6=.*|NETWORKMANAGER_DISABLE_IPV6=\"no\"|" "$CONFIG_FILE"

  grep -q "^NETCONFIG_DNS_STATIC_SERVERS=" "$CONFIG_FILE" || echo "NETCONFIG_DNS_STATIC_SERVERS=\"$IPV6_DNS1 $IPV6_DNS2\"" >> "$CONFIG_FILE"
  grep -q "^NETWORKMANAGER_DISABLE_IPV6=" "$CONFIG_FILE" || echo "NETWORKMANAGER_DISABLE_IPV6=\"no\"" >> "$CONFIG_FILE"

  netconfig update -f

  echo "Updated /etc/resolv.conf:"
  cat /etc/resolv.conf

  echo "Testing IPv6 DNS resolution:"
  dig AAAA google.com
fi
