#!/bin/bash
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

REBOOT="false"

# some basic information about the OS for troubleshooting failures
uname -a
lsblk
free -h

#https://docs.rke2.io/known_issues

systemctl disable --now firewalld || true
systemctl stop firewalld || true

systemctl stop nm-cloud-setup.service || true
systemctl disable nm-cloud-setup.service || true
systemctl stop nm-cloud-setup.timer || true
systemctl disable nm-cloud-setup.timer || true

# shellcheck disable=SC2154
if [ "cis-rhel-8" = "${image}" ]; then

  systemctl stop nftables
  systemctl disable nftables

  install -d /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/rke2-canal.conf << EOT
[keyfile]
unmanaged-devices=interface-name:flannel*;interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:vxlan-v6.calico;interface-name:wireguard.cali;interface-name:wg-v6.cali
EOT

  groupadd --system etcd && sudo useradd -s /sbin/nologin --system -g etcd etcd

  # Backup GRUB configuration
  if [ -f /etc/default/grub ]; then
    cp /etc/default/grub /etc/default/grub.bak
    echo "Backed up /etc/default/grub to /etc/default/grub.bak"
  fi

  # Check if cgroup v2 is already enabled
  if mount | grep -q "cgroup on /sys/fs/cgroup type cgroup"; then
    echo "cgroup v2 already enabled."
  else
    # Add cgroup v2 kernel parameter to GRUB configuration
    if grep -q "systemd.unified_cgroup_hierarchy=1" /etc/default/grub; then
        echo "cgroup v2 parameter already present in GRUB. Skipping."
    else
        sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 systemd.unified_cgroup_hierarchy=1"/g' /etc/default/grub
        echo "Added systemd.unified_cgroup_hierarchy=1 to GRUB_CMDLINE_LINUX"
    fi
  fi


  # Disable IPv6 in CIS images
  if grep -q "ipv6.disable=1" /etc/default/grub; then
      echo "IPv6 disable parameter already present. Skipping."
  else
      sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 ipv6.disable=1"/g' /etc/default/grub
      echo "Added ipv6.disable=1 to GRUB_CMDLINE_LINUX"
  fi

  # Update GRUB configuration
  if [ -f /boot/efi/EFI/redhat/grub.cfg ]; then
    grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
    echo "Updated /boot/efi/EFI/redhat/grub.cfg"
  elif [ -f /boot/grub2/grub.cfg ]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
    echo "Updated /boot/grub2/grub.cfg"
  else
    echo "GRUB configuration file not found. Please check /boot directory."
    exit 1
  fi
  REBOOT="true"
fi

# shellcheck disable=SC2154
if [ "ipv6" = "${ip_family}" ]; then
  if [ "" != "$(which NetworkManager)" ]; then
    echo "Found NetworkManager, configuring interface using key file in /etc/NetworkManager/system-connections..."
    DEVICE="$(ip -6 -o a show scope global | awk '{print $2}')"
    IPV6="$(ip -6 a show "$DEVICE" | grep inet6 | head -n1 | awk '{ print $2 }' | awk -F/ '{ print $1 }')"
    IPV6_GW="$(echo "$IPV6" | awk -F: '{gw=$1":"$2":"$3":"$4"::1"; print gw}')"
    DATA="[connection]\ntype=ethernet\n[ipv4]\nmethod=disabled\n[ipv6]\naddresses=$IPV6/64\ngateway=$IPV6_GW\nmethod=manual\ndns=2001:4860:4860::8888\nnever-default=false"

    rm -f /etc/sysconfig/network-scripts/ifcfg-eth0
    echo -e "$DATA" > "/etc/NetworkManager/system-connections/$DEVICE.nmconnection"
    chmod 0600 "/etc/NetworkManager/system-connections/$DEVICE.nmconnection"

    nmcli connection reload
    nmcli connection up eth0
    systemctl restart NetworkManager
    nmcli -f TYPE,FILENAME,NAME connection | grep ethernet
  fi
fi

# shellcheck disable=SC2154
if [ "rocky-9" = "${image}" ]; then
  if grep -q overlayfs /proc/filesystems; then
    echo "overlayfs supported..."
  else
    echo "overlayfs not supported, upgrading kernel..."
    dnf update -y
  fi
fi

if [ "$REBOOT" = "true" ]; then
  echo "Rebooting in 2 seconds..."
  # reboot in 2 seconds and exit this script
  # this allows us to reboot without Terraform receiving errors
  # WARNING: there is a race condition here, the reboot must happen before Terraform reconnects for the next script
  ( sleep 2 ; reboot ) &
  exit 0
fi
