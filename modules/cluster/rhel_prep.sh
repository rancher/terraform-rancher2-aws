#!/bin/bash
set -e
set -x

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


  # Disable IPv6
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
if [ "rpm" = "${install_method}" ]; then
  # shellcheck disable=SC2010
  PYTHON_VERSION="$(ls -l /usr/lib | grep '^d' | grep python | awk '{print $9}')"

  # shellcheck disable=SC2154
  if [ "rhel-9" = "${image}" ] || [ "rocky-9" = "${image}" ]; then
    # adding Rocky 9 repos because they are RHEL 9 compatible and support ipv6 native
    DATA="[RockyLinux-AppStream]\nname=Rocky Linux - AppStream\nbaseurl=https://dl.rockylinux.org/pub/rocky/9/AppStream/x86_64/os/\nenabled=1\nmetadata_expire=7d\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky\nsslverify=1\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt"
    echo -e "$DATA" > /etc/yum.repos.d/Rocky-AppStream.repo
    DATA="[RockyLinux-BaseOS]\nname=Rocky Linux - BaseOS\nbaseurl=https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os\nenabled=1\nmetadata_expire=7d\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky\nsslverify=1\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt"
    echo -e "$DATA" > /etc/yum.repos.d/Rocky-BaseOS.repo
    curl -s https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-9 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-rocky
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rocky
    dnf config-manager --set-enabled RockyLinux-AppStream
    dnf config-manager --set-enabled RockyLinux-BaseOS
    rm -rf "/usr/lib/$PYTHON_VERSION/site-packages/dnf-plugins/amazon-id.py" # we are manually adding users, no need to use amazon-id which has problems with ipv6
    rm -rf /etc/yum.repos.d/redhat-* # redhat repos only support ipv4
    rm -rf /etc/dnf/plugins/amazon-id.conf
    dnf clean all
    dnf makecache
    dnf repolist
  fi

  # shellcheck disable=SC2154
  if [ "rhel-8" = "${image}" ] || [ "liberty-8" = "${image}" ]; then
    # adding Rocky 8 repos because they are RHEL 8 compatible and support ipv6 native
    DATA="[RockyLinux-AppStream]\nname=Rocky Linux - AppStream\nbaseurl=https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/\nenabled=1\nmetadata_expire=7d\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky\nsslverify=1\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt"
    echo -e "$DATA" > /etc/yum.repos.d/Rocky-AppStream.repo
    DATA="[RockyLinux-BaseOS]\nname=Rocky Linux - BaseOS\nbaseurl=https://dl.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os\nenabled=1\nmetadata_expire=7d\ngpgcheck=1\ngpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky\nsslverify=1\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt"
    echo -e "$DATA" > /etc/yum.repos.d/Rocky-BaseOS.repo
    curl -s https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-8 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-rocky
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rocky
    dnf config-manager --set-enabled RockyLinux-AppStream
    dnf config-manager --set-enabled RockyLinux-BaseOS
    rm -rf "/usr/lib/$PYTHON_VERSION/site-packages/dnf-plugins/amazon-id.py" # we are manually adding users, no need to use amazon-id which has problems with ipv6
    rm -rf /etc/yum.repos.d/redhat-* # redhat repos only support ipv4
    rm -rf /etc/dnf/plugins/amazon-id.conf
    dnf clean all
    dnf makecache
    dnf repolist
  fi

  # shellcheck disable=SC2154
  if [ "liberty-7" = "${image}" ]; then
    subscription-manager repos --enable=rhel-7-server-extras-rpms
    yum clean all
    yum repolist
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
