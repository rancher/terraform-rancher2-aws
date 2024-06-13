#!/bin/sh
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi
#https://docs.rke2.io/known_issues

systemctl disable --now firewalld || true
systemctl stop firewalld || true

systemctl stop nm-cloud-setup.service
systemctl disable nm-cloud-setup.service
systemctl stop nm-cloud-setup.timer
systemctl disable nm-cloud-setup.timer
