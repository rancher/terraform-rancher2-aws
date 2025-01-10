#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi
#https://docs.rke2.io/known_issues
systemctl disable --now firewalld || true
systemctl stop firewalld || true

if [ -d /etc/NetworkManager ]; then
  touch /etc/NetworkManager/conf.d/rke2-canal.conf
  cat <<EOF > /etc/NetworkManager/conf.d/rke2-canal.conf
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*
EOF
  systemctl reload NetworkManager || true
fi
