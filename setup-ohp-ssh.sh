#!/bin/bash

# Get distro and server IP
DISTRO=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
SERVER_IP=$(ip -o route get 8.8.8.8 | awk '{print $7}')

clear

# Check root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" >&2
   exit 1
fi

# Inputs
echo 'OHP For SSH'
read -e -p 'Input your Server IP: ' -i "$SERVER_IP" SERVER_IP
read -e -p 'Input SSH Port: ' -i '22' SSH_PORT
read -e -p 'Input Privoxy Port: ' -i '8118' PRIVOXY_PORT
read -e -p 'Input ohpserver Port: ' -i '9999' OHP_PORT

# Update and install dependencies
echo 'Updating package list...'
apt-get update -y
echo 'Installing Privoxy and wget...'
DEBIAN_FRONTEND=noninteractive apt-get install -y privoxy wget

# Setup Privoxy
echo 'Setting up Privoxy...'
mkdir -p /etc/privoxy

cat <<EOF > /etc/privoxy/config
confdir /etc/privoxy
logdir /var/log/privoxy
actionsfile standard.action
actionsfile default.action
actionsfile user.action
filterfile default.filter
logfile logfile
listen-address  :$PRIVOXY_PORT
toggle 1
enable-remote-toggle 0
enable-remote-http-toggle 0
enable-edit-actions 0
enforce-blocks 0
buffer-limit 4096
EOF

cat <<EOF > /etc/privoxy/user.action
{ +block }
/

{ -block }
127.0.0.1
$SERVER_IP
EOF

# Install OHP Server
echo 'Downloading ohpserver...'
wget -q https://raw.githubusercontent.com/Civ3snipher/OHP-SCRIPTZ/refs/heads/main/setup-ohp-ssh.sh -O /usr/local/bin/ohpserver-ssh
chmod +x /usr/local/bin/ohpserver-ssh

# Create systemd service
echo 'Creating ohpserver systemd service...'
cat <<EOF > /etc/systemd/system/ohpserver-ssh.service
[Unit]
Description=OHP For SSH
Wants=network.target
After=network.target

[Service]
ExecStart=/usr/local/bin/ohpserver-ssh -port $OHP_PORT -proxy 127.0.0.1:$PRIVOXY_PORT -tunnel $SERVER_IP:$SSH_PORT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start services
echo 'Enabling and starting services...'
systemctl daemon-reload
systemctl enable privoxy
systemctl restart privoxy
systemctl enable ohpserver-ssh
systemctl restart ohpserver-ssh

# Cleanup
rm -f setup-ohp-ssh.sh

# Output
echo '##############################'
echo "Server IP: $SERVER_IP"
echo "SSH Port: $SSH_PORT"
echo "HTTP Port: $PRIVOXY_PORT"
echo "OHP Port: $OHP_PORT"
echo '##############################'

echo 'Setup completed!'
echo 'Check status:'
echo '  systemctl status privoxy'
echo '  systemctl status ohpserver-ssh
