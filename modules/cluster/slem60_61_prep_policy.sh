#!/bin/bash

echo "updating selinux policy for new nginx version in sle-micro-60..."

POLICY_NAME="slemicro_60_nginx_ingress_policy"

SERVICE="apply-nginx-ingress-selinux-policy"
SERVICE_FILE="$SERVICE.service"
SERVICE_SCRIPT="$SERVICE.sh"

STAGING_DIRECTORY="/etc/rancher/rke2/policy"
SERVICE_DIRECTORY="/etc/systemd/system"

mkdir -p "$STAGING_DIRECTORY"
cat > "$STAGING_DIRECTORY/commands.sh" <<EOF
echo "running commands..."
install -d "$STAGING_DIRECTORY"

cat > "$STAGING_DIRECTORY/$POLICY_NAME.te" <<EOT
module $POLICY_NAME 1.0;

require {
        type proc_t;
        type container_t;
        class filesystem associate;
}

#============= container_t ==============
allow container_t proc_t:filesystem associate;
EOT

echo "generating policy from template..."
checkmodule -M -m -o "$STAGING_DIRECTORY/$POLICY_NAME.mod" "$STAGING_DIRECTORY/$POLICY_NAME.te"
semodule_package -o "$STAGING_DIRECTORY/$POLICY_NAME.pp" -m "$STAGING_DIRECTORY/$POLICY_NAME.mod"
echo "$STAGING_DIRECTORY"
ls -lah "$STAGING_DIRECTORY"

echo "generating service to apply policy..."
cat <<EOT > "/usr/bin/$SERVICE_SCRIPT"
#!/bin/bash
chcon -t semanage_store_t "$STAGING_DIRECTORY/$POLICY_NAME.pp"

semodule -i  "$STAGING_DIRECTORY/$POLICY_NAME.pp"
EOT

chmod +x "/usr/bin/$SERVICE_SCRIPT"

cat <<EOT > "$SERVICE_DIRECTORY/$SERVICE_FILE"
[Unit]
Description=Apply Nginx Ingress SELinux Policy
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/"$SERVICE_SCRIPT"
StandardOutput=append:/var/log/$SERVICE.log
StandardError=append:/var/log/$SERVICE.log

[Install]
WantedBy=multi-user.target
EOT

echo "attempting to enable service..."
systemctl enable "$SERVICE_DIRECTORY/$SERVICE_FILE"

echo "running service script..."
/usr/bin/$SERVICE_SCRIPT

echo "complete..."
EOF

COMMANDS="$(cat $STAGING_DIRECTORY/commands.sh)"

# WARNING! Transactional system will silently ignore changes to /var/*
# WARNING! SELinux will automatically reset the contexts of files based on directory
transactional-update run bash -c "$COMMANDS"

# don't filter tasks in selinux audit
auditctl -d never,task

echo "done..."
