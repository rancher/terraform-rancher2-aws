#!/bin/bash

echo "setting SLE Micro v6.0 SELinux to permissive mode..."

# set selinux to permissive mode
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo "done..."
