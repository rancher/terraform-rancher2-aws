#!/bin/bash
# shellcheck disable=SC2154
echo "Prepping ${image}..."

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

ACTIVE="$(systemctl is-active firewalld)"
if [ "$ACTIVE" = "active" ]; then
  echo "disabling firewalld because it is incompatible with rke2 CNIs..."
  #https://docs.rke2.io/known_issues
  systemctl disable --now firewalld || true
  systemctl stop firewalld || true
fi

ACTIVE="$(systemctl is-active NetworkManager)"
if [ "$ACTIVE" = "active" ]; then
  echo "Found NetworkManager, adding config for canal..."
  touch /etc/NetworkManager/conf.d/rke2-canal.conf
  DATA="[keyfile]\nunmanaged-devices=interface-name:cali*;interface-name:flannel*"
  echo "$DATA" > /etc/NetworkManager/conf.d/rke2-canal.conf
  systemctl reload NetworkManager
fi
# shellcheck disable=SC2154
if [ "ipv6" = "${ip_family}" ]; then
  if [ "" != "$(which NetworkManager)" ]; then
    echo "Found NetworkManager, configuring interface using key file in /etc/NetworkManager/system-connections..."
    DEVICE="$(ip -6 -o a show scope global | awk '{print $2}')"
    IPV6="$(ip -6 a show "$DEVICE" | grep inet6 | head -n1 | awk '{ print $2 }' | awk -F/ '{ print $1 }')"
    IPV6_GW="$(echo "$IPV6" | awk -F: '{gw=$1":"$2":"$3":"$4"::1"; print gw}')"
    DATA="[connection]\ntype=ethernet\n[ipv4]\nmethod=disabled\n[ipv6]\naddresses=$IPV6/64\ngateway=$IPV6_GW\nmethod=manual\ndns=2001:4860:4860::8888\nnever-default=false"

    rm -f "/etc/sysconfig/network-scripts/ifcfg-$DEVICE"
    echo -e "$DATA" > "/etc/NetworkManager/system-connections/$DEVICE.nmconnection"
    chmod 0600 "/etc/NetworkManager/system-connections/$DEVICE.nmconnection"

    nmcli connection reload
    nmcli connection up "$DEVICE"
    systemctl restart NetworkManager
    nmcli -f TYPE,FILENAME,NAME connection | grep ethernet
  elif [ "" != "$(which netconfig)" ]; then
    echo "NetworkManager not found..."
    echo "Found netconfig, configuring interface using ifcfg-rc file in /etc/sysconfig/network-scripts..."
    DEVICE="$(ip -6 -o a show scope global | awk '{print $2}')"
    IPV6="$(ip -6 a show "$DEVICE" | grep inet6 | head -n1 | awk '{ print $2 }' | awk -F/ '{ print $1 }')"
    IPV6_GW="$(echo "$IPV6" | awk -F: '{gw=$1":"$2":"$3":"$4"::1"; print gw}')"

    # shellcheck disable=SC2027
    DATA="STARTMODE='auto'\nBOOTPROTO='static'\nIPADDR="$IPV6"\nPREFIXLEN='64'\nDHCLIENT6_MODE='info'"
    echo -e "$DATA" > "/etc/sysconfig/network/ifcfg-$DEVICE"

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
  else
    echo "unknown network config manager..."
  fi
fi
echo "complete..."
